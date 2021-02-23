module DB.Markers.Queries exposing
    ( getLatestSeqNo
    , getLowestNewSeqNo
    , getNewSeqNo
    , saveLatestSeqNo
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


getLatestSeqNo :
    (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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


saveLatestSeqNo :
    Posix
    -> Int
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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


getLowestNewSeqNo :
    (Dynamo.QueryResponse StatusTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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


getNewSeqNo :
    Int
    -> (Dynamo.GetResponse StatusTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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
