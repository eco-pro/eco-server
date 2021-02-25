module DB.BuildStatus.Queries exposing
    ( getPackagesSince
    , saveError
    , saveReady
    )

import AWS.Dynamo as Dynamo
import DB.BuildStatus.Table as StatusTable
import DB.TableNames as TableNames
import Elm.Project
import Packages.Config exposing (Config)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


ecoBuildStatusTableName : Conn Config model route msg -> String
ecoBuildStatusTableName conn =
    TableNames.fqTableName "eco-buildstatus" conn


saveError :
    Posix
    -> Int
    -> FQPackage
    -> StatusTable.ErrorReason
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
save record responseFn conn =
    Dynamo.put
        (ecoBuildStatusTableName conn)
        StatusTable.encode
        record
        responseFn
        conn


getPackagesSince :
    Int
    -> StatusTable.Label
    -> (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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
