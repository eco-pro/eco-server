module DB.Markers.Queries exposing (Config, get, save)

import AWS.Dynamo as Dynamo
import DB.Markers.Table as MarkersTable
import Elm.FQPackage as FQPackage exposing (FQPackage)
import Elm.Project
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


type alias Config c =
    { c | markersTable : String }


ecoMarkersTableName : Conn (Config c) model route msg -> String
ecoMarkersTableName conn =
    (Serverless.Conn.config conn).markersTable


get :
    String
    -> (Dynamo.GetResponse MarkersTable.Record -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
get source responseFn conn =
    Dynamo.get
        (ecoMarkersTableName conn)
        MarkersTable.encodeKey
        { source = source }
        MarkersTable.decoder
        responseFn
        conn


save :
    MarkersTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
save record responseFn conn =
    Dynamo.put
        (ecoMarkersTableName conn)
        MarkersTable.encode
        record
        responseFn
        conn
