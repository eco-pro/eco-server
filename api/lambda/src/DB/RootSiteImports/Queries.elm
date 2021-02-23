module DB.RootSiteImports.Queries exposing (saveAllPackages)

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


saveAllPackages :
    Posix
    -> List RootSiteImportsTable.Record
    -> (Dynamo.PutResponse -> msg)
    -> (Dynamo.Msg msg -> msg)
    -> Conn Config model route msg
    -> ( Conn Config model route msg, Cmd msg )
saveAllPackages timestamp packages responseFn dynamoMsgFn conn =
    Dynamo.batchPut
        (rootSiteImportsTableName conn)
        RootSiteImportsTable.encode
        packages
        dynamoMsgFn
        responseFn
        conn
