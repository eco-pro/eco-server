module DB.BuildStatus.Queries exposing
    ( loadPackagesSince
    , saveErrorSeqNo
    , saveReadySeqNo
    )

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
