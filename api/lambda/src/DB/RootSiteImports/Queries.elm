module DB.RootSiteImports.Queries exposing (saveAllPackages)

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



-- RootSiteImports


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
