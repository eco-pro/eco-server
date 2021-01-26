port module Packages.Dynamo exposing (dynamoOk, put)

import Json.Encode as Encode exposing (Value)
import Serverless exposing (InteropRequestPort, InteropResponsePort)
import Serverless.Conn exposing (Conn)


type alias Put a =
    { tableName : String
    , item : a
    }


putEncoder : (a -> Value) -> Put a -> Value
putEncoder encoder putOp =
    Encode.object
        [ ( "TableName", Encode.string putOp.tableName )
        , ( "Item", encoder putOp.item )
        ]


put : (a -> Value) -> String -> a -> Conn config model route -> Cmd msg
put encoder table val conn =
    Serverless.interop dynamoPut (putEncoder encoder { tableName = table, item = val }) conn


port dynamoPut : InteropRequestPort Value msg


port dynamoOk : InteropResponsePort msg
