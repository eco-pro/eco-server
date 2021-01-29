port module Packages.Dynamo exposing
    ( Msg, Model, init, update
    , put, PutResponse(..)
    , get, GetResponse(..)
    , batchGet, BatchGetResponse(..)
    , batchPut
    , dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort
    , dynamoResponsePort
    )

{-| A wrapper around the AWS DynamoDB Document API.


# TEA model.

@docs Msg, Model, init, update


# Database Operations

@docs put, PutResponse
@docs get, GetResponse
@docs batchGet, BatchGetResponse
@docs batchPut


# Ports

@docs dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort
@docs @dopcs dynamoResponsePort

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Serverless exposing (InteropRequestPort, InteropResponsePort)
import Serverless.Conn exposing (Conn)


type Msg msg
    = BatchPutLoop (List Value) (Value -> msg)


type alias Model =
    ()


init : Model
init =
    ()


update : Msg msg -> Model -> ( Model, Cmd (Msg msg) )
update msg model =
    ( model, Cmd.none )



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


type PutResponse
    = PutOk
    | PutError String


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
    -> (PutResponse -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
put table encoder val responseFn conn =
    Serverless.interop
        dynamoPutPort
        (putEncoder encoder { tableName = table, item = val })
        (buildPutResponseMsg responseFn putResponseDecoder)
        conn


putResponseDecoder : Decoder PutResponse
putResponseDecoder =
    Decode.field "type_" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "Ok" ->
                        Decode.succeed PutOk

                    _ ->
                        Decode.succeed (PutError "error")
            )


buildPutResponseMsg : (PutResponse -> msg) -> Decoder PutResponse -> Value -> msg
buildPutResponseMsg responseFn decoder val =
    let
        result =
            Decode.decodeValue decoder val
                |> Result.map responseFn
                |> Result.mapError (Decode.errorToString >> PutError >> responseFn)
    in
    case result of
        Ok ok ->
            ok

        Err err ->
            err



-- Get a document from DynamoDB


type alias Get k =
    { tableName : String
    , key : k
    }


type GetResponse a
    = GetItem a
    | GetItemNotFound
    | GetError String


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
                            |> Decode.map GetItem

                    "ItemNotFound" ->
                        Decode.succeed GetItemNotFound

                    _ ->
                        Decode.succeed (GetError "error")
            )


buildGetResponseMsg : (GetResponse a -> msg) -> Decoder (GetResponse a) -> Value -> msg
buildGetResponseMsg responseFn decoder val =
    let
        result =
            Decode.decodeValue decoder val
                |> Result.map responseFn
                |> Result.mapError (Decode.errorToString >> GetError >> responseFn)
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


batchPut :
    String
    -> (a -> Value)
    -> List a
    -> (List a -> msg)
    -> (Value -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
batchPut table encoder vals loopFn responseFn conn =
    let
        firstBatch =
            List.take 25 vals

        remainder =
            List.drop 25 vals
    in
    Serverless.interop
        dynamoBatchPutPort
        (batchPutEncoder encoder { tableName = table, items = firstBatch })
        (\val ->
            case remainder of
                [] ->
                    responseFn val

                _ ->
                    loopFn remainder
        )
        conn


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



-- Batch Get


type alias BatchGet k =
    { tableName : String
    , keys : List k
    }


type BatchGetResponse a
    = BatchGetItems (List a)
    | BatchGetError String


batchGet :
    String
    -> (k -> Value)
    -> List k
    -> Decoder a
    -> (BatchGetResponse a -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
batchGet table encoder keys decoder responseFn conn =
    Serverless.interop
        dynamoBatchGetPort
        (batchGetEncoder encoder { tableName = table, keys = keys })
        (buildBatchGetResponseMsg responseFn (batchGetResponseDecoder table decoder))
        conn


batchGetEncoder : (k -> Value) -> BatchGet k -> Value
batchGetEncoder encoder getOp =
    Encode.object
        [ ( "RequestItems"
          , Encode.object
                [ ( getOp.tableName
                  , Encode.object
                        [ ( "Keys"
                          , Encode.list encoder getOp.keys
                          )
                        ]
                  )
                ]
          )
        ]


batchGetResponseDecoder : String -> Decoder a -> Decoder (BatchGetResponse a)
batchGetResponseDecoder tableName decoder =
    Decode.field "type_" Decode.string
        |> Decode.andThen
            (\type_ ->
                case type_ of
                    "Item" ->
                        Decode.at [ "item", "Responses", tableName ] (Decode.list decoder)
                            |> Decode.map BatchGetItems

                    _ ->
                        Decode.succeed (BatchGetError "error")
            )


buildBatchGetResponseMsg : (BatchGetResponse a -> msg) -> Decoder (BatchGetResponse a) -> Value -> msg
buildBatchGetResponseMsg responseFn decoder val =
    let
        result =
            Decode.decodeValue decoder val
                |> Result.map responseFn
                |> Result.mapError (Decode.errorToString >> BatchGetError >> responseFn)
    in
    case result of
        Ok ok ->
            ok

        Err err ->
            err
