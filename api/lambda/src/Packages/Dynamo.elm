port module Packages.Dynamo exposing
    ( put, get, batchPut, GetResponse(..)
    , dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort
    , dynamoResponsePort
    )

{-| A wrapper around the AWS DynamoDB Document API.


# Database Operations

@docs put, get, batchGet, batchPut, GetResponse


# Ports

@docs dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort
@docs @dopcs dynamoResponsePort

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Serverless exposing (InteropRequestPort, InteropResponsePort)
import Serverless.Conn exposing (Conn)



-- Port definitions.


port dynamoResponsePort : InteropResponsePort msg


port dynamoGetPort : InteropRequestPort Value msg


port dynamoPutPort : InteropRequestPort Value msg


port dynamoBatchGetPort : InteropRequestPort Value msg


port dynamoBatchPutPort : InteropRequestPort Value msg



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
    String
    -> (a -> Value)
    -> a
    -> (Value -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
put table encoder val responseDecoder conn =
    Serverless.interop
        dynamoPutPort
        (putEncoder encoder { tableName = table, item = val })
        responseDecoder
        conn



-- Get a document from DynamoDB


type alias Get k =
    { tableName : String
    , key : k
    }


type GetResponse a
    = Item a
    | ItemNotFound
    | Error String


get :
    String
    -> (k -> Value)
    -> k
    -> Decoder a
    -> (GetResponse a -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
get table encoder key decoder responseFn conn =
    Serverless.interop
        dynamoGetPort
        (getEncoder encoder { tableName = table, key = key })
        (buildGetResponseMsg responseFn (getResponseDecoder decoder))
        conn


getEncoder : (k -> Value) -> Get k -> Value
getEncoder encoder getOp =
    Encode.object
        [ ( "TableName", Encode.string getOp.tableName )
        , ( "Key", encoder getOp.key )
        ]


getResponseDecoder : Decoder a -> Decoder (GetResponse a)
getResponseDecoder decoder =
    Decode.field "type_" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "Item" ->
                        Decode.at [ "item", "Item" ] decoder
                            |> Decode.map Item

                    "ItemNotFound" ->
                        Decode.succeed ItemNotFound

                    _ ->
                        Decode.succeed (Error "error")
            )


buildGetResponseMsg : (GetResponse a -> msg) -> Decoder (GetResponse a) -> Value -> msg
buildGetResponseMsg responseFn decoder val =
    let
        result =
            Decode.decodeValue decoder val
                |> Result.map responseFn
                |> Result.mapError (Decode.errorToString >> Error >> responseFn)
    in
    case result of
        Ok ok ->
            ok

        Err err ->
            err



-- Batch Put


type alias BatchPut a =
    { tableName : String
    , items : List a
    }


batchPutEncoder : (a -> Value) -> BatchPut a -> Value
batchPutEncoder encoder putOp =
    let
        encodeItem item =
            Encode.object
                [ ( "PutRequest"
                  , Encode.object
                        [ ( "Item", encoder item ) ]
                  )
                ]
    in
    Encode.object
        [ ( "RequestItems"
          , Encode.object
                [ ( putOp.tableName
                  , Encode.list encodeItem putOp.items
                  )
                ]
          )
        ]


batchPut :
    String
    -> (a -> Value)
    -> List a
    -> (Value -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
batchPut table encoder vals responseDecoder conn =
    Serverless.interop
        dynamoBatchPutPort
        (batchPutEncoder encoder { tableName = table, items = Debug.log "vals to encode" vals } |> Debug.log "encoded vals")
        responseDecoder
        conn
