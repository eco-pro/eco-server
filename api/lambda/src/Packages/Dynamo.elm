port module Packages.Dynamo exposing
    ( put
    , dynamoPutPort, dynamoGetPort, dynamoResponsePort
    )

{-| A wrapper around the AWS DynamoDB Document API.


# Database Operations

@docs put, get


# Ports

@docs dynamoPutPort, dynamoGetPort, dynamoResponsePort

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Serverless exposing (InteropRequestPort, InteropResponsePort)
import Serverless.Conn exposing (Conn)



-- Put a document in DynamoDB


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


put :
    (a -> Value)
    -> String
    -> a
    -> (Value -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
put encoder table val responseDecoder conn =
    Serverless.interop
        dynamoPutPort
        (putEncoder encoder { tableName = table, item = val })
        responseDecoder
        conn


port dynamoPutPort : InteropRequestPort Value msg



-- Get a document from DynamoDB


type alias Get k =
    { tableName : String
    , key : k
    }


getEncoder : (k -> Value) -> Get k -> Value
getEncoder encoder getOp =
    Encode.object
        [ ( "TableName", Encode.string getOp.tableName )
        , ( "Key", encoder getOp.key )
        ]


get :
    (k -> Value)
    -> String
    -> k
    -> Decoder a
    -> (a -> msg)
    -> (Value -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
get encoder table key decoder tagger responseDecoder conn =
    Serverless.interop
        dynamoGetPort
        (getEncoder encoder { tableName = table, key = key })
        responseDecoder
        conn


port dynamoGetPort : InteropRequestPort Value msg



-- Listen for results of DynamoDB operations.


port dynamoResponsePort : InteropResponsePort msg


{-| The possible DynamoDB operation responses.
-}
type Response
    = Item String Value
    | ItemNotFound String
    | KeyList (List String)
    | Error String
