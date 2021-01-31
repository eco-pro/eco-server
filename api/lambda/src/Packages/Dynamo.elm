port module Packages.Dynamo exposing
    ( Msg, update
    , put, PutResponse(..)
    , get, GetResponse(..)
    , batchGet, BatchGetResponse(..)
    , batchPut
    , Query, QueryResponse, Order(..), query, partitionKeyEquals, limitResults, orderResults
    , dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort, dynamoQueryPort
    , dynamoResponsePort
    )

{-| A wrapper around the AWS DynamoDB Document API.


# TEA model.

@docs Msg, update


# Database Operations

@docs put, PutResponse
@docs get, GetResponse
@docs batchGet, BatchGetResponse
@docs batchPut

@docs Query, QueryResponse, Order, query, partitionKeyEquals, limitResults, orderResults


# Ports

@docs dynamoPutPort, dynamoGetPort, dynamoBatchPutPort, dynamoBatchGetPort, dynamoQueryPort
@docs @dopcs dynamoResponsePort

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Maybe.Extra
import Result.Extra
import Serverless exposing (InteropRequestPort, InteropResponsePort)
import Serverless.Conn exposing (Conn)
import Task.Extra



-- Port definitions.


port dynamoResponsePort : InteropResponsePort msg


port dynamoGetPort : InteropRequestPort Value msg


port dynamoPutPort : InteropRequestPort Value msg


port dynamoBatchGetPort : InteropRequestPort Value msg


port dynamoBatchPutPort : InteropRequestPort Value msg


port dynamoQueryPort : InteropRequestPort Value msg



-- Internal event handling.


type Msg msg
    = BatchPutLoop PutResponse String (Msg msg -> msg) (PutResponse -> msg) (List Value)


update : Msg msg -> Conn config model route msg -> ( Conn config model route msg, Cmd msg )
update msg conn =
    case msg of
        BatchPutLoop response table tagger responseFn remainder ->
            case response of
                PutOk ->
                    case remainder of
                        [] ->
                            ( conn, responseFn PutOk |> Task.Extra.message )

                        _ ->
                            let
                                ( nextConn, loopCmd ) =
                                    batchPutInner table
                                        tagger
                                        responseFn
                                        remainder
                                        conn
                            in
                            ( nextConn
                            , loopCmd
                            )

                PutError dbErrorMsg ->
                    ( conn, PutError dbErrorMsg |> responseFn |> Task.Extra.message )



-- Put a document in DynamoDB


type alias Put a =
    { tableName : String
    , item : a
    }


type PutResponse
    = PutOk
    | PutError String


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
        (putResponseDecoder >> responseFn)
        conn


putEncoder : (a -> Value) -> Put a -> Value
putEncoder encoder putOp =
    Encode.object
        [ ( "TableName", Encode.string putOp.tableName )
        , ( "Item", encoder putOp.item )
        ]


putResponseDecoder : Value -> PutResponse
putResponseDecoder val =
    let
        decoder =
            Decode.field "type_" Decode.string
                |> Decode.andThen
                    (\type_ ->
                        case type_ of
                            "Ok" ->
                                Decode.succeed PutOk

                            _ ->
                                Decode.field "errorMsg" Decode.string
                                    |> Decode.map PutError
                    )
    in
    Decode.decodeValue decoder val
        |> Result.mapError (Decode.errorToString >> PutError)
        |> Result.Extra.merge



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
        (getResponseDecoder decoder >> responseFn)
        conn


getEncoder : (k -> Value) -> Get k -> Value
getEncoder encoder getOp =
    Encode.object
        [ ( "TableName", Encode.string getOp.tableName )
        , ( "Key", encoder getOp.key )
        ]


getResponseDecoder : Decoder a -> Value -> GetResponse a
getResponseDecoder itemDecoder val =
    let
        decoder =
            Decode.field "type_" Decode.string
                |> Decode.andThen
                    (\type_ ->
                        case type_ of
                            "Item" ->
                                Decode.at [ "item", "Item" ] itemDecoder
                                    |> Decode.map GetItem

                            "ItemNotFound" ->
                                Decode.succeed GetItemNotFound

                            _ ->
                                Decode.field "errorMsg" Decode.string
                                    |> Decode.map GetError
                    )
    in
    Decode.decodeValue decoder val
        |> Result.mapError (Decode.errorToString >> GetError)
        |> Result.Extra.merge



-- Batch Put


type alias BatchPut a =
    { tableName : String
    , items : List a
    }


batchPut :
    String
    -> (a -> Value)
    -> List a
    -> (Msg msg -> msg)
    -> (PutResponse -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
batchPut table encoder vals tagger responseFn conn =
    batchPutInner table tagger responseFn (List.map encoder vals) conn


batchPutInner :
    String
    -> (Msg msg -> msg)
    -> (PutResponse -> msg)
    -> List Value
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
batchPutInner table tagger responseFn vals conn =
    let
        firstBatch =
            List.take 25 vals

        remainder =
            List.drop 25 vals
    in
    Serverless.interop
        dynamoBatchPutPort
        (batchPutEncoder { tableName = table, items = firstBatch })
        (\val ->
            BatchPutLoop (putResponseDecoder val) table tagger responseFn remainder |> tagger
        )
        conn


batchPutEncoder : BatchPut Value -> Value
batchPutEncoder putOp =
    let
        encodeItem item =
            Encode.object
                [ ( "PutRequest"
                  , Encode.object
                        [ ( "Item", item ) ]
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
        (batchGetResponseDecoder table decoder >> responseFn)
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


batchGetResponseDecoder : String -> Decoder a -> Value -> BatchGetResponse a
batchGetResponseDecoder tableName itemDecoder val =
    let
        decoder =
            Decode.field "type_" Decode.string
                |> Decode.andThen
                    (\type_ ->
                        case type_ of
                            "Item" ->
                                Decode.at [ "item", "Responses", tableName ] (Decode.list itemDecoder)
                                    |> Decode.map BatchGetItems

                            _ ->
                                Decode.field "errorMsg" Decode.string
                                    |> Decode.map BatchGetError
                    )
    in
    Decode.decodeValue decoder val
        |> Result.mapError (Decode.errorToString >> BatchGetError)
        |> Result.Extra.merge



-- Queries


type alias QueryResponse a =
    BatchGetResponse a


type Attribute
    = StringAttr String
    | NumberAttr Int


type KeyExpression
    = KeyExpression


type KeyCondition
    = Equals ( String, Attribute )
    | LessThan ( String, Attribute )
    | LessThenOrEqual ( String, Attribute )
    | GreaterThan ( String, Attribute )
    | GreaterThanOrEqual ( String, Attribute )
    | Between ( String, Attribute, Attribute )



-- a = b — true if the attribute a is equal to the value b
-- a < b — true if a is less than b
-- a <= b — true if a is less than or equal to b
-- a > b — true if a is greater than b
-- a >= b — true if a is greater than or equal to b
-- a BETWEEN b AND c — true if a is greater than or equal to b, and less than or equal to c.


type Order
    = Forward
    | Reverse


type alias Query =
    { partitionKey : ( String, Attribute )
    , rangeKeyCondition : Maybe KeyCondition
    , order : Order
    , limit : Maybe Int
    }


partitionKeyEquals : String -> String -> Query
partitionKeyEquals key val =
    { partitionKey = ( key, StringAttr val )
    , rangeKeyCondition = Nothing
    , order = Forward
    , limit = Nothing
    }


orderResults : Order -> Query -> Query
orderResults ord q =
    { q | order = ord }


limitResults : Int -> Query -> Query
limitResults limit q =
    { q | limit = Just limit }


query :
    String
    -> Query
    -> Decoder a
    -> (QueryResponse a -> msg)
    -> Conn config model route msg
    -> ( Conn config model route msg, Cmd msg )
query table q decoder responseFn conn =
    Serverless.interop
        dynamoQueryPort
        (queryEncoder table q)
        (queryResponseDecoder decoder >> responseFn)
        conn


queryEncoder : String -> Query -> Value
queryEncoder table q =
    let
        keyCond ( field, attr ) =
            case attr of
                StringAttr val ->
                    ( [ ( field, ":attr0" ) ], [ ( ":attr0", Encode.string val ) ] )

                NumberAttr val ->
                    ( [ ( field, ":attr0" ) ], [ ( ":attr0", Encode.int val ) ] )

        ( keyExpressions, attrVals ) =
            keyCond q.partitionKey

        keyExpressionsString =
            List.map
                (\( k, a ) -> k ++ " = " ++ a)
                keyExpressions
                |> String.join " AND "

        encodedAttrVals =
            Encode.object attrVals
    in
    [ ( "TableName", Encode.string table ) |> Just
    , ( "KeyConditionExpression", Encode.string keyExpressionsString ) |> Just
    , ( "ExpressionAttributeValues", encodedAttrVals ) |> Just
    , case q.order of
        Forward ->
            ( "ScanIndexForward", Encode.bool True ) |> Just

        Reverse ->
            ( "ScanIndexForward", Encode.bool False ) |> Just
    , Maybe.map (\limit -> ( "Limit", Encode.int limit )) q.limit
    ]
        |> Maybe.Extra.values
        |> Encode.object


queryResponseDecoder : Decoder a -> Value -> BatchGetResponse a
queryResponseDecoder itemDecoder val =
    let
        decoder =
            Decode.field "type_" Decode.string
                |> Decode.andThen
                    (\type_ ->
                        case type_ of
                            "Item" ->
                                Decode.at [ "item", "Items" ] (Decode.list itemDecoder)
                                    |> Decode.map BatchGetItems

                            _ ->
                                Decode.field "errorMsg" Decode.string
                                    |> Decode.map BatchGetError
                    )
    in
    Decode.decodeValue decoder val
        |> Result.mapError (Decode.errorToString >> BatchGetError)
        |> Result.Extra.merge
