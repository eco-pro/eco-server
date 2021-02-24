module DB.RootSiteImports.Queries exposing (getBySeq, saveAll)

import AWS.Dynamo as Dynamo
import DB.RootSiteImports.Table as RootSiteImportsTable
import DB.TableNames as TableNames
import Elm.Project
import Packages.Config exposing (Config)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Serverless.Conn exposing (Conn)
import Time exposing (Posix)
import Url exposing (Url)


rootSiteImportsTableName : Conn Config model route msg -> String
rootSiteImportsTableName conn =
    TableNames.fqTableName "eco-rootsiteimports" conn



-- RootSiteImports


saveAll :
    Posix
    -> List RootSiteImportsTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> (Dynamo.Msg msg -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
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
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
getBySeq seq responseFn conn =
    Dynamo.get
        (rootSiteImportsTableName conn)
        RootSiteImportsTable.encodeKey
        { seq = seq }
        RootSiteImportsTable.decoder
        responseFn
        conn
