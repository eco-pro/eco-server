module DB.Markers.Queries exposing
    ( getLatest
    , getProcessedTo
    , getProcessing
    , saveLatest
    , saveProcessedTo
    , saveProcessing
    )

import AWS.Dynamo as Dynamo
import DB.Markers.Table as MarkersTable
import DB.TableNames as TableNames
import Elm.Project
import Packages.Config exposing (Config)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


ecoMarkersTableName : Conn Config model route msg -> String
ecoMarkersTableName conn =
    TableNames.fqTableName "eco-markers" conn


get :
    MarkersTable.Label
    -> (Dynamo.GetResponse MarkersTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
get label responseFn conn =
    Dynamo.get
        (ecoMarkersTableName conn)
        MarkersTable.encodeKey
        { label = label }
        MarkersTable.decoder
        responseFn
        conn


save :
    MarkersTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
save record responseFn conn =
    Dynamo.put
        (ecoMarkersTableName conn)
        MarkersTable.encode
        record
        responseFn
        conn


getLatest :
    (Dynamo.GetResponse MarkersTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
getLatest responseFn conn =
    get MarkersTable.Latest responseFn conn


saveLatest :
    Posix
    -> Int
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveLatest timestamp seq responseFn conn =
    save
        { seq = seq
        , updatedAt = timestamp
        , label = MarkersTable.Latest
        }
        responseFn
        conn


getProcessedTo :
    (Dynamo.GetResponse MarkersTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
getProcessedTo responseFn conn =
    get MarkersTable.ProcessedTo responseFn conn


saveProcessedTo :
    Posix
    -> Int
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveProcessedTo timestamp seq responseFn conn =
    save
        { seq = seq
        , updatedAt = timestamp
        , label = MarkersTable.ProcessedTo
        }
        responseFn
        conn


getProcessing :
    (Dynamo.GetResponse MarkersTable.Record -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
getProcessing responseFn conn =
    get MarkersTable.Processing responseFn conn


saveProcessing :
    Posix
    -> Int
    -> (Dynamo.PutResponse -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveProcessing timestamp seq responseFn conn =
    save
        { seq = seq
        , updatedAt = timestamp
        , label = MarkersTable.Processing
        }
        responseFn
        conn
