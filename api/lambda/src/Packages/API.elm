port module Packages.API exposing (main)

import Dict exposing (Dict)
import Elm.Package
import Elm.Version
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.Dynamo as Dynamo
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Packages.RootSite as RootSite
import Packages.Table.Packages as PackagesTable
import Packages.Table.Seq as SeqTable
import Parser exposing (Parser)
import Serverless
import Serverless.Conn as Conn exposing (method, request, respond, route)
import Serverless.Conn.Body as Body
import Serverless.Conn.Request exposing (Method(..), Request, body)
import Set
import Task
import Time exposing (Posix)
import Tuple
import Url
import Url.Parser exposing ((</>), (<?>), int, map, oneOf, s, top)
import Url.Parser.Query as Query



-- Serverless program.


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg


type alias Conn =
    Conn.Conn Config () Route Msg


main : Serverless.Program Config () Route Msg
main =
    Serverless.httpApi
        { configDecoder = configDecoder
        , initialModel = ()
        , parseRoute = routeParser
        , endpoint = router
        , update = update
        , interopPorts = [ Dynamo.dynamoResponsePort ]
        , requestPort = requestPort
        , responsePort = responsePort
        }



--, Decode.map DynamoOk Decode.value
-- Configuration


type alias Config =
    { dynamoDbNamespace : String
    }


configDecoder : Decoder Config
configDecoder =
    Decode.field "DYNAMODB_NAMESPACE" Decode.string
        |> Decode.map Config



-- Route and query parsing.


type Route
    = AllPackages
    | AllPackagesSince Int
    | ElmJson String String String
    | EndpointJson String String String
    | Refresh


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ map AllPackages (s "all-packages")
        , map AllPackagesSince (s "all-packages" </> s "since" </> Url.Parser.int)
        , map ElmJson (s "packages" </> Url.Parser.string </> Url.Parser.string </> Url.Parser.string </> s "elm.json")
        , map EndpointJson (s "packages" </> Url.Parser.string </> Url.Parser.string </> Url.Parser.string </> s "endpoint.json")
        , map Refresh (s "refresh")
        ]
        |> Url.Parser.parse


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        -- The original package site API
        ( GET, AllPackages ) ->
            ( conn, RootSite.fetchAllPackages PassthroughAllPackages )

        ( POST, AllPackagesSince since ) ->
            ( conn, RootSite.fetchAllPackagesSince since |> Task.attempt PassthroughAllPackagesSince )

        ( GET, ElmJson author name version ) ->
            ( conn, RootSite.fetchElmJson PassthroughElmJson author name version )

        ( GET, EndpointJson author name version ) ->
            ( conn, RootSite.fetchEndpointJson PassthroughEndpointJson author name version )

        -- The enhanced API
        ( GET, AllPackagesSince since ) ->
            ( conn, RootSite.fetchAllPackagesSince since |> Task.attempt PassthroughAllPackagesSince )

        ( GET, Refresh ) ->
            loadSeqNo CheckSeqNo conn

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


type Msg
    = DynamoMsg (Dynamo.Msg Msg)
    | PassthroughAllPackages (Result Http.Error Decode.Value)
    | PassthroughAllPackagesSince (Result Http.Error (List FQPackage))
    | PassthroughElmJson (Result Http.Error Decode.Value)
    | PassthroughEndpointJson (Result Http.Error Decode.Value)
    | CheckSeqNo (Dynamo.GetResponse SeqTable.Record)
    | RefreshPackages Int (Result Http.Error ( Posix, List FQPackage ))
    | PackagesSave Int Posix Dynamo.PutResponse
    | SeqNoSave Int Dynamo.PutResponse


customLogger : Msg -> String
customLogger msg =
    case msg of
        DynamoMsg _ ->
            "DynamoMsg"

        PassthroughAllPackages _ ->
            "PassthroughAllPackages"

        PassthroughAllPackagesSince _ ->
            "PassthroughAllPackagesSince"

        PassthroughElmJson _ ->
            "PassthroughElmJson"

        PassthroughEndpointJson _ ->
            "PassthroughEndpointJson"

        CheckSeqNo _ ->
            "CheckSeqNo"

        RefreshPackages seqNo _ ->
            "RefreshPackages " ++ String.fromInt seqNo

        PackagesSave seqNo _ _ ->
            "PackagesSave " ++ String.fromInt seqNo

        SeqNoSave seqNo _ ->
            "SeqNoSave " ++ String.fromInt seqNo


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    let
        _ =
            Debug.log "update" (customLogger msg)
    in
    case msg of
        DynamoMsg innerMsg ->
            let
                ( nextConn, dynamoCmd ) =
                    Dynamo.update innerMsg conn
            in
            ( nextConn, dynamoCmd )

        PassthroughAllPackages result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        PassthroughAllPackagesSince result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json (Encode.list FQPackage.encode val) ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        PassthroughElmJson result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        PassthroughEndpointJson result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        CheckSeqNo loadResult ->
            case loadResult of
                Dynamo.GetItem record ->
                    ( conn
                    , RootSite.fetchAllPackagesSince record.seq
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages record.seq)
                    )

                Dynamo.GetItemNotFound ->
                    ( conn
                    , RootSite.fetchAllPackagesSince 0
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages 0)
                    )

                Dynamo.GetError dbErrorMsg ->
                    error dbErrorMsg conn

        RefreshPackages from result ->
            case result of
                Ok ( timestamp, newPackageList ) ->
                    case newPackageList of
                        [] ->
                            ( conn, Cmd.none )
                                |> andThen createdOk

                        _ ->
                            let
                                seqNo =
                                    List.length newPackageList + from

                                packageTableEntries =
                                    List.reverse newPackageList
                                        |> List.indexedMap
                                            (\idx fqPackage ->
                                                { label = "new"
                                                , seq = from + idx + 1
                                                , fqPackage = Just fqPackage
                                                , updatedAt = timestamp
                                                }
                                            )
                            in
                            ( conn, Cmd.none )
                                |> andThen
                                    (saveAllPackages
                                        timestamp
                                        packageTableEntries
                                        (PackagesSave seqNo timestamp)
                                    )

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        PackagesSave seqNo timestamp res ->
            case res of
                Dynamo.PutOk ->
                    ( conn, Cmd.none )
                        |> andThen (saveSeqNo timestamp seqNo (SeqNoSave seqNo))

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        SeqNoSave seqNo res ->
            case res of
                Dynamo.PutOk ->
                    -- Trigger the processing jobs to populate them all.
                    -- Signal back to the caller that the request completed ok.
                    ( conn, Cmd.none )
                        |> andThen createdOk

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn


andThen : (model -> ( model, Cmd msg )) -> ( model, Cmd msg ) -> ( model, Cmd msg )
andThen fn ( model, cmd ) =
    let
        ( nextModel, nextCmd ) =
            fn model
    in
    ( nextModel, Cmd.batch [ cmd, nextCmd ] )


saveAllPackages :
    Posix
    -> List SeqTable.Record
    -> (Dynamo.PutResponse -> Msg)
    -> Conn
    -> ( Conn, Cmd Msg )
saveAllPackages timestamp packages responseFn conn =
    Dynamo.batchPut
        (fqTableName "eco-elm-seq" conn)
        SeqTable.encode
        packages
        DynamoMsg
        responseFn
        conn


loadSeqNo : (Dynamo.GetResponse SeqTable.Record -> Msg) -> Conn -> ( Conn, Cmd Msg )
loadSeqNo responseFn conn =
    Dynamo.get
        (fqTableName "eco-elm-seq" conn)
        SeqTable.encodeKey
        { label = "latest"
        , seq = 0
        }
        SeqTable.decoder
        responseFn
        conn


saveSeqNo : Posix -> Int -> (Dynamo.PutResponse -> Msg) -> Conn -> ( Conn, Cmd Msg )
saveSeqNo timestamp seqNo responseFn conn =
    Dynamo.put
        (fqTableName "eco-elm-seq" conn)
        SeqTable.encode
        { label = "latest"
        , seq = seqNo
        , fqPackage = Nothing
        , updatedAt = timestamp
        }
        responseFn
        conn


loadPackagesSince :
    Int
    -> (Dynamo.QueryResponse PackagesTable.Record -> Msg)
    -> Conn
    -> ( Conn, Cmd Msg )
loadPackagesSince seqNo responseFn conn =
    let
        keyExpression =
            ()
    in
    Dynamo.query
        (fqTableName "eco-elm-packages" conn)
        Dynamo.keyExpression
        PackagesTable.decoder
        responseFn
        conn


createdOk : Conn -> ( Conn, Cmd Msg )
createdOk conn =
    respond ( 201, Body.empty ) conn


error : String -> Conn -> ( Conn, Cmd Msg )
error msg conn =
    respond ( 500, Body.text msg ) conn



-- DynamoDB Tables


fqTableName : String -> Conn -> String
fqTableName name conn =
    (Conn.config conn).dynamoDbNamespace ++ "-" ++ name
