module DB.RootSiteImports.Queries exposing (Config, getBySeq, saveAll)

import AWS.Dynamo as Dynamo
import DB.RootSiteImports.Table as RootSiteImportsTable
import Elm.FQPackage as FQPackage exposing (FQPackage)
import Elm.Project
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


type alias Config c =
    { c | rootSiteImportsTable : String }


rootSiteImportsTableName : Conn (Config c) model route msg -> String
rootSiteImportsTableName conn =
    (Serverless.Conn.config conn).rootSiteImportsTable



-- RootSiteImports


saveAll :
    Posix
    -> List RootSiteImportsTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> (Dynamo.Msg msg -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
saveAll timestamp packages responseFn dynamoMsgFn conn =
    Dynamo.batchPut
        (rootSiteImportsTableName conn)
        RootSiteImportsTable.encode
        packages
        dynamoMsgFn
        responseFn
        conn


getBySeq :
    Int
    -> (Dynamo.GetResponse RootSiteImportsTable.Record -> msg)
    -> Conn (Config c) model route msg
    -> ( Conn (Config c) model route msg, Cmd msg )
getBySeq seq responseFn conn =
    Dynamo.get
        (rootSiteImportsTableName conn)
        RootSiteImportsTable.encodeKey
        { seq = seq }
        RootSiteImportsTable.decoder
        responseFn
        conn
