module DB.BuildStatus.Queries exposing
    ( Config
    , getPackage
    , getPackagesSince
    , saveAll
    , saveError
    , saveReady
    )

import AWS.Dynamo as Dynamo
import DB.BuildStatus.ByFQPackageIndex as FQPackageIndex
import DB.BuildStatus.Table as StatusTable
import Elm.FQPackage as FQPackage exposing (FQPackage)
import Elm.Project
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


type alias Config c =
    { c
        | buildStatusTable : String
        , buildStatusByFQPackageIndex : String
    }


ecoBuildStatusTableName : Conn (Config c) model route msg -> String
ecoBuildStatusTableName conn =
    (Serverless.Conn.config conn).buildStatusTable


ecoBuildStatusByFQPackageIndexName : Conn (Config c) model route msg -> String
ecoBuildStatusByFQPackageIndexName conn =
    (Serverless.Conn.config conn).buildStatusByFQPackageIndex


saveError :
    Posix
    -> Int
    -> FQPackage
    -> StatusTable.ErrorReason
    -> (Dynamo.PutResponse -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
saveError timestamp seq fqPackage errorReason responseFn conn =
    save
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


saveReady :
    Posix
    -> Int
    -> FQPackage
    -> Elm.Project.Project
    -> StatusTable.Archive
    -> (Dynamo.PutResponse -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
saveReady timestamp seq fqPackage elmJson archive responseFn conn =
    save
        { seq = seq
        , updatedAt = timestamp
        , status =
            StatusTable.Ready
                { fqPackage = fqPackage
                , elmJson = elmJson
                , archive = archive
                }
        }
        responseFn
        conn


save :
    StatusTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
save record responseFn conn =
    Dynamo.put
        (ecoBuildStatusTableName conn)
        StatusTable.encode
        record
        responseFn
        conn


saveAll :
    Posix
    -> List StatusTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> (Dynamo.Msg msg -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
saveAll timestamp packages responseFn dynamoMsgFn conn =
    Dynamo.batchPut
        (ecoBuildStatusTableName conn)
        StatusTable.encode
        packages
        dynamoMsgFn
        responseFn
        conn


getPackagesSince :
    Int
    -> StatusTable.Label
    -> (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
getPackagesSince seq label responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" (StatusTable.labelToString label)
                |> Dynamo.rangeKeyGreaterThan "seq" (Dynamo.int seq)
    in
    Dynamo.query
        (ecoBuildStatusTableName conn)
        query
        StatusTable.decoder
        responseFn
        conn


getPackage :
    FQPackage
    -> (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
getPackage fqPackage responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "fqPackage" (FQPackage.toString fqPackage)
    in
    Dynamo.queryIndex
        (ecoBuildStatusTableName conn)
        (ecoBuildStatusByFQPackageIndexName conn)
        query
        StatusTable.decoder
        responseFn
        conn
