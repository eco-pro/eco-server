port module Packages.API exposing (main)

import Dict exposing (Dict)
import Elm.Package
import Elm.Version
import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Maybe.Extra
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
import Url.Builder
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
    | NextJob
    | PackageElmJson
    | PackageLocation


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ map AllPackages (s "all-packages")
        , map AllPackagesSince (s "all-packages" </> s "since" </> Url.Parser.int)
        , map ElmJson
            (s "packages"
                </> Url.Parser.string
                </> Url.Parser.string
                </> Url.Parser.string
                </> s "elm.json"
            )
        , map EndpointJson
            (s "packages"
                </> Url.Parser.string
                </> Url.Parser.string
                </> Url.Parser.string
                </> s "endpoint.json"
            )
        , map Refresh (s "refresh")
        , map NextJob (s "nextjob")
        ]
        |> Url.Parser.parse


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        -- The original package site API
        ( GET, AllPackages ) ->
            ( conn, Cmd.none )
                |> andThen (loadPackagesSince 0 AllPackagesLoaded)

        ( POST, AllPackagesSince since ) ->
            ( conn, Cmd.none )
                |> andThen (loadPackagesSince since PackagesSinceLoaded)

        ( GET, ElmJson author name version ) ->
            ( conn, RootSite.fetchElmJson PassthroughElmJson author name version )

        ( GET, EndpointJson author name version ) ->
            ( conn, RootSite.fetchEndpointJson PassthroughEndpointJson author name version )

        -- The enhanced API
        ( GET, AllPackagesSince since ) ->
            ( conn, Cmd.none )
                |> andThen (loadPackagesSince since PackagesSinceLoaded)

        ( GET, Refresh ) ->
            getLatestSeqNo CheckSeqNo conn

        ( GET, NextJob ) ->
            getLowestNewSeqNo ProvideJobDetails conn

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


type Msg
    = DynamoMsg (Dynamo.Msg Msg)
    | PassthroughElmJson (Result Http.Error Decode.Value)
    | PassthroughEndpointJson (Result Http.Error Decode.Value)
    | CheckSeqNo (Dynamo.QueryResponse SeqTable.Record)
    | RefreshPackages Int (Result Http.Error ( Posix, List FQPackage ))
    | PackagesSave Int Posix Dynamo.PutResponse
    | SeqNoSave Int Dynamo.PutResponse
    | PackagesSinceLoaded (Dynamo.QueryResponse SeqTable.Record)
    | AllPackagesLoaded (Dynamo.QueryResponse SeqTable.Record)
    | ProvideJobDetails (Dynamo.QueryResponse SeqTable.Record)


customLogger : Msg -> String
customLogger msg =
    case msg of
        DynamoMsg _ ->
            "DynamoMsg"

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

        PackagesSinceLoaded _ ->
            "PackagesSinceLoaded"

        AllPackagesLoaded _ ->
            "AllPackagesLoaded"

        ProvideJobDetails _ ->
            "ProvideJobDetails"


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
                Dynamo.BatchGetItems [] ->
                    ( conn
                    , RootSite.fetchAllPackagesSince 0
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages 0)
                    )

                Dynamo.BatchGetItems (record :: _) ->
                    ( conn
                    , RootSite.fetchAllPackagesSince record.seq
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages record.seq)
                    )

                Dynamo.BatchGetError dbErrorMsg ->
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
                                                { seq = from + idx + 1
                                                , updatedAt = timestamp
                                                , status = SeqTable.NewFromRootSite { fqPackage = fqPackage }
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
                        |> andThen (saveLatestSeqNo timestamp seqNo (SeqNoSave seqNo))

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

        PackagesSinceLoaded loadResult ->
            case loadResult of
                Dynamo.BatchGetItems records ->
                    let
                        readyPackage status =
                            case status of
                                SeqTable.Ready { fqPackage } ->
                                    Just fqPackage

                                _ ->
                                    Nothing

                        jsonRecords =
                            records
                                |> List.map (.status >> readyPackage)
                                |> List.reverse
                                |> Maybe.Extra.values
                                |> Encode.list (FQPackage.toString >> Encode.string)
                    in
                    respond ( 200, Body.json jsonRecords ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        AllPackagesLoaded loadResult ->
            case loadResult of
                Dynamo.BatchGetItems records ->
                    let
                        readyPackage status =
                            case status of
                                SeqTable.Ready { fqPackage } ->
                                    Just fqPackage

                                _ ->
                                    Nothing

                        jsonRecords =
                            records
                                |> List.map (.status >> readyPackage)
                                |> List.reverse
                                |> Maybe.Extra.values
                                |> groupByName
                                |> Encode.dict identity (Encode.list Elm.Version.encode)

                        groupByName fqPackages =
                            List.foldl
                                (\{ name, version } accum ->
                                    Dict.update (Elm.Package.toString name)
                                        (\key ->
                                            case key of
                                                Nothing ->
                                                    [ version ] |> Just

                                                Just versions ->
                                                    version :: versions |> Just
                                        )
                                        accum
                                )
                                Dict.empty
                                fqPackages
                    in
                    respond ( 200, Body.json jsonRecords ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        ProvideJobDetails loadResult ->
            case loadResult of
                Dynamo.BatchGetItems [] ->
                    respond ( 404, Body.text "No job." ) conn

                Dynamo.BatchGetItems (record :: _) ->
                    case record.status of
                        SeqTable.NewFromRootSite { fqPackage } ->
                            let
                                job =
                                    { fqPackage = fqPackage
                                    , zipUrl =
                                        Url.Builder.crossOrigin
                                            "https://github.com"
                                            [ Elm.Package.toString fqPackage.name
                                            , "zipball"
                                            , Elm.Version.toString fqPackage.version
                                            ]
                                            []
                                    }

                                jobEncoder val =
                                    Encode.object
                                        [ ( "fqPackage", FQPackage.encode val.fqPackage )
                                        , ( "zipUrl", Encode.string val.zipUrl )
                                        ]
                            in
                            respond ( 200, Body.json (jobEncoder job) ) conn

                        _ ->
                            respond ( 404, Body.text "No job." ) conn

                Dynamo.BatchGetError dbErrorMsg ->
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


getLatestSeqNo : (Dynamo.QueryResponse SeqTable.Record -> Msg) -> Conn -> ( Conn, Cmd Msg )
getLatestSeqNo responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "latest"
                |> Dynamo.orderResults Dynamo.Reverse
                |> Dynamo.limitResults 1
    in
    Dynamo.query
        (fqTableName "eco-elm-seq" conn)
        query
        SeqTable.decoder
        responseFn
        conn


saveLatestSeqNo : Posix -> Int -> (Dynamo.PutResponse -> Msg) -> Conn -> ( Conn, Cmd Msg )
saveLatestSeqNo timestamp seqNo responseFn conn =
    Dynamo.put
        (fqTableName "eco-elm-seq" conn)
        SeqTable.encode
        { seq = seqNo
        , updatedAt = timestamp
        , status = SeqTable.Latest
        }
        responseFn
        conn


getLowestNewSeqNo : (Dynamo.QueryResponse SeqTable.Record -> Msg) -> Conn -> ( Conn, Cmd Msg )
getLowestNewSeqNo responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "new"
                |> Dynamo.limitResults 1
    in
    Dynamo.query
        (fqTableName "eco-elm-seq" conn)
        query
        SeqTable.decoder
        responseFn
        conn


loadPackagesSince :
    Int
    -> (Dynamo.QueryResponse SeqTable.Record -> Msg)
    -> Conn
    -> ( Conn, Cmd Msg )
loadPackagesSince seqNo responseFn conn =
    let
        query =
            Dynamo.partitionKeyEquals "label" "new"
                |> Dynamo.rangeKeyGreaterThan "seq" (Dynamo.int seqNo)
    in
    Dynamo.query
        (fqTableName "eco-elm-seq" conn)
        query
        SeqTable.decoder
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
