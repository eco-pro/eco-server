module DB.BuildStatus.Queries exposing (..)

import AWS.Dynamo as Dynamo
import DB.BuildStatus.Table as StatusTable
import Elm.Project
import Packages.Config exposing (Config)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


fqTableName : String -> Conn Config model route msg -> String
fqTableName name conn =
    (Serverless.Conn.config conn).dynamoDbNamespace ++ "-" ++ name


ecoBuildStatusTableName : Conn Config model route msg -> String
ecoBuildStatusTableName conn =
    fqTableName "eco-buildstatus" conn


saveAllPackages :
    Posix
    -> List StatusTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> (Dynamo.Msg msg -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveAllPackages timestamp packages responseFn dynamoMsgFn conn =
    Dynamo.batchPut
        (ecoBuildStatusTableName conn)
        StatusTable.encode
        packages
        dynamoMsgFn
        responseFn
        conn


getLatestSeqNo : (Dynamo.QueryResponse StatusTable.Record -> msg) -> Conn Config model route msg -> ( Conn Config model route msg, Cmd msg )
getLatestSeqNo responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "latest"
                |> Dynamo.orderResults Dynamo.Reverse
                |> Dynamo.limitResults 1
    in
    Dynamo.query
        (ecoBuildStatusTableName conn)
        query
        StatusTable.decoder
        responseFn
        conn


saveLatestSeqNo : Posix -> Int -> (Dynamo.PutResponse -> msg) -> Conn Config model route msg -> ( Conn Config model route msg, Cmd msg )
saveLatestSeqNo timestamp seq responseFn conn =
    Dynamo.put
        (ecoBuildStatusTableName conn)
        StatusTable.encode
        { seq = seq
        , updatedAt = timestamp
        , status = StatusTable.Latest
        }
        responseFn
        conn


saveErrorSeqNo :
    Posix
    -> Int
    -> FQPackage
    -> StatusTable.ErrorReason
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveErrorSeqNo timestamp seq fqPackage errorReason responseFn conn =
    Dynamo.updateKey
        (ecoBuildStatusTableName conn)
        StatusTable.encodeKey
        StatusTable.encode
        { seq = seq
        , label = StatusTable.LabelNewFromRootSite
        }
        { seq = seq
        , updatedAt = timestamp
        , status =
            StatusTable.Error
                { fqPackage = fqPackage
                , errorReason = errorReason
                }
        }
        responseFn
        conn


saveReadySeqNo :
    Posix
    -> Int
    -> FQPackage
    -> Elm.Project.Project
    -> Url
    -> String
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveReadySeqNo timestamp seq fqPackage elmJson packageUrl md5 responseFn conn =
    Dynamo.updateKey
        (ecoBuildStatusTableName conn)
        StatusTable.encodeKey
        StatusTable.encode
        { seq = seq
        , label = StatusTable.LabelNewFromRootSite
        }
        { seq = seq
        , updatedAt = timestamp
        , status =
            StatusTable.Ready
                { fqPackage = fqPackage
                , elmJson = elmJson
                , packageUrl = packageUrl
                , md5 = md5
                }
        }
        responseFn
        conn


getLowestNewSeqNo : (Dynamo.QueryResponse StatusTable.Record -> msg) -> Conn Config model route msg -> ( Conn Config model route msg, Cmd msg )
getLowestNewSeqNo responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "new"
                |> Dynamo.limitResults 1
    in
    Dynamo.query
        (ecoBuildStatusTableName conn)
        query
        StatusTable.decoder
        responseFn
        conn


getNewSeqNo : Int -> (Dynamo.GetResponse StatusTable.Record -> msg) -> Conn Config model route msg -> ( Conn Config model route msg, Cmd msg )
getNewSeqNo seq responseFn conn =
    Dynamo.get
        (ecoBuildStatusTableName conn)
        StatusTable.encodeKey
        { seq = seq
        , label = StatusTable.LabelNewFromRootSite
        }
        StatusTable.decoder
        responseFn
        conn


loadPackagesSince :
    Int
    -> (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
loadPackagesSince seq responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "new"
                |> Dynamo.rangeKeyGreaterThan "seq" (Dynamo.int seq)
    in
    Dynamo.query
        (ecoBuildStatusTableName conn)
        query
        StatusTable.decoder
        responseFn
        conn
