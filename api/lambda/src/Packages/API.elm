port module Packages.API exposing (main)

import AWS.Dynamo as Dynamo
import DB.BuildStatus.Queries as StatusQueries
import DB.BuildStatus.Table as StatusTable
import DB.Markers.Queries as MarkersQueries
import DB.Markers.Table as MarkersTable
import DB.RootSiteImports.Queries as RootSiteImportsQueries
import DB.RootSiteImports.Table as RootSiteImportsTable
import Dict exposing (Dict)
import Elm.Package
import Elm.Project
import Elm.Version
import Http
import Http.RootSite as RootSite
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Maybe.Extra
import Packages.Config as Config exposing (Config)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Parser exposing (Parser)
import Serverless
import Serverless.Conn as Conn exposing (method, request, respond, route)
import Serverless.Conn.Body as Body
import Serverless.Conn.Request as Request exposing (Method(..), Request, body)
import Set
import Task
import Task.Extra
import Time exposing (Posix)
import Tuple
import Url exposing (Url)
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
        { configDecoder = Config.configDecoder
        , initialModel = ()
        , parseRoute = routeParser
        , endpoint = router
        , update = update
        , interopPorts = [ Dynamo.dynamoResponsePort ]
        , requestPort = requestPort
        , responsePort = responsePort
        }



-- Route and query parsing.


type Route
    = AllPackages
    | AllPackagesSince Int
    | ElmJson String String String
    | EndpointJson String String String
    | Refresh
    | NextJob
    | PackageError Int
    | PackageReady Int


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
        , map Refresh (s "packages" </> s "refresh")
        , map NextJob (s "packages" </> s "nextjob")
        , map PackageError (s "packages" </> Url.Parser.int </> s "error")
        , map PackageReady (s "packages" </> Url.Parser.int </> s "ready")
        ]
        |> Url.Parser.parse


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        -- The original package site API
        ( GET, AllPackages ) ->
            ( conn, Cmd.none )
                |> andThen (StatusQueries.loadPackagesSince 0 AllPackagesLoaded)

        ( POST, AllPackagesSince since ) ->
            ( conn, Cmd.none )
                |> andThen (StatusQueries.loadPackagesSince since PackagesSinceLoaded)

        ( GET, ElmJson author name version ) ->
            ( conn, RootSite.fetchElmJson PassthroughElmJson author name version )

        ( GET, EndpointJson author name version ) ->
            ( conn, RootSite.fetchEndpointJson PassthroughEndpointJson author name version )

        -- The enhanced API
        ( GET, AllPackagesSince since ) ->
            ( conn, Cmd.none )
                |> andThen (StatusQueries.loadPackagesSince since PackagesSinceLoaded)

        ( GET, Refresh ) ->
            MarkersQueries.getLatestSeqNo CheckSeqNo conn

        ( GET, NextJob ) ->
            MarkersQueries.getLowestNewSeqNo ProvideJobDetails conn

        ( POST, PackageError seq ) ->
            MarkersQueries.getNewSeqNo seq (LoadedSeqNoState seq (updateAsError seq)) conn

        ( POST, PackageReady seq ) ->
            MarkersQueries.getNewSeqNo seq (LoadedSeqNoState seq (updateAsReady seq)) conn

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


type Msg
    = DynamoMsg (Dynamo.Msg Msg)
    | TimestampAndThen (Posix -> ( Conn, Cmd Msg )) Posix
    | PassthroughElmJson (Result Http.Error Decode.Value)
    | PassthroughEndpointJson (Result Http.Error Decode.Value)
    | CheckSeqNo (Dynamo.QueryResponse StatusTable.Record)
    | RefreshPackages Int (Result Http.Error ( Posix, List FQPackage ))
    | PackagesSave Int Posix Dynamo.PutResponse
    | PackagesSinceLoaded (Dynamo.QueryResponse StatusTable.Record)
    | AllPackagesLoaded (Dynamo.QueryResponse StatusTable.Record)
    | ProvideJobDetails (Dynamo.QueryResponse StatusTable.Record)
    | LoadedSeqNoState Int (StatusTable.Record -> Conn -> ( Conn, Cmd Msg )) (Dynamo.GetResponse StatusTable.Record)
    | SavedSeqNoState Int Dynamo.PutResponse


customLogger : Msg -> String
customLogger msg =
    case msg of
        DynamoMsg _ ->
            "DynamoMsg"

        TimestampAndThen _ _ ->
            "TimestampAndThen"

        PassthroughElmJson _ ->
            "PassthroughElmJson"

        PassthroughEndpointJson _ ->
            "PassthroughEndpointJson"

        CheckSeqNo _ ->
            "CheckSeqNo"

        RefreshPackages seq _ ->
            "RefreshPackages " ++ String.fromInt seq

        PackagesSave seq _ _ ->
            "PackagesSave " ++ String.fromInt seq

        PackagesSinceLoaded _ ->
            "PackagesSinceLoaded"

        AllPackagesLoaded _ ->
            "AllPackagesLoaded"

        ProvideJobDetails _ ->
            "ProvideJobDetails"

        LoadedSeqNoState _ _ _ ->
            "LoadedSeqNoState"

        SavedSeqNoState _ _ ->
            "SavedSeqNoState"


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

        TimestampAndThen msgFn timestamp ->
            msgFn timestamp

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
                    , RootSite.fetchAllPackagesSince 6557
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages 6557)
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
                                seq =
                                    List.length newPackageList + from

                                packageTableEntries =
                                    List.reverse newPackageList
                                        |> List.indexedMap
                                            (\idx fqPackage ->
                                                { seq = from + idx + 1
                                                , updatedAt = timestamp
                                                , fqPackage = fqPackage
                                                }
                                            )
                            in
                            ( conn, Cmd.none )
                                |> andThen
                                    (RootSiteImportsQueries.saveAllPackages
                                        timestamp
                                        packageTableEntries
                                        (PackagesSave seq timestamp)
                                        DynamoMsg
                                    )

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        PackagesSave seq timestamp res ->
            case res of
                Dynamo.PutOk ->
                    ( conn, Cmd.none )
                        |> andThen (MarkersQueries.saveLatestSeqNo timestamp seq (SavedSeqNoState seq))

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        PackagesSinceLoaded loadResult ->
            case loadResult of
                Dynamo.BatchGetItems records ->
                    let
                        readyPackage status =
                            case status of
                                StatusTable.Ready { fqPackage } ->
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
                                StatusTable.Ready { fqPackage } ->
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
                        StatusTable.NewFromRootSite { fqPackage } ->
                            let
                                job =
                                    { seq = record.seq
                                    , fqPackage = fqPackage
                                    , zipUrl =
                                        Url.Builder.crossOrigin
                                            "https://github.com"
                                            [ Elm.Package.toString fqPackage.name
                                            , "archive"
                                            , Elm.Version.toString fqPackage.version ++ ".zip"
                                            ]
                                            []
                                    , author =
                                        Elm.Package.toString fqPackage.name
                                            |> String.split "/"
                                            |> List.head
                                            |> Maybe.withDefault ""
                                    , name =
                                        Elm.Package.toString fqPackage.name
                                            |> String.split "/"
                                            |> List.tail
                                            |> Maybe.map List.head
                                            |> Maybe.Extra.join
                                            |> Maybe.withDefault ""
                                    , version = fqPackage.version
                                    }
                            in
                            respond ( 200, Body.json (encodeBuildJob job) ) conn

                        _ ->
                            respond ( 404, Body.text "No job." ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        LoadedSeqNoState seq recordFn getResponse ->
            case getResponse of
                Dynamo.GetItem record ->
                    recordFn record conn

                Dynamo.GetItemNotFound ->
                    error "Item not found." conn

                Dynamo.GetError dbErrorMsg ->
                    error dbErrorMsg conn

        SavedSeqNoState seq res ->
            case res of
                Dynamo.PutOk ->
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


withTimestamp : (Posix -> ( Conn, Cmd Msg )) -> Cmd Msg
withTimestamp fn =
    Time.now |> Task.perform (TimestampAndThen fn)


createdOk : Conn -> ( Conn, Cmd Msg )
createdOk conn =
    respond ( 201, Body.empty ) conn


error : String -> Conn -> ( Conn, Cmd Msg )
error msg conn =
    respond ( 500, Body.text msg ) conn


jsonError : Value -> Conn -> ( Conn, Cmd Msg )
jsonError json conn =
    respond ( 500, Body.json json ) conn


updateAsReady : Int -> StatusTable.Record -> Conn -> ( Conn, Cmd Msg )
updateAsReady seq record conn =
    case decodeJsonBody successReportDecoder conn of
        Ok { elmJson, packageUrl, md5 } ->
            case record.status of
                StatusTable.NewFromRootSite { fqPackage } ->
                    ( conn
                    , withTimestamp
                        (\posix ->
                            StatusQueries.saveReadySeqNo posix
                                seq
                                fqPackage
                                elmJson
                                packageUrl
                                md5
                                (SavedSeqNoState seq)
                                conn
                        )
                    )

                _ ->
                    error "Item with seq not found in correct state." conn

        Err decodeErrMsg ->
            case record.status of
                StatusTable.NewFromRootSite { fqPackage } ->
                    ( conn
                    , withTimestamp
                        (\posix ->
                            StatusQueries.saveErrorSeqNo posix
                                seq
                                fqPackage
                                (StatusTable.ErrorElmJsonInvalid decodeErrMsg)
                                (SavedSeqNoState seq)
                                conn
                        )
                    )

                _ ->
                    error "Item with seq not found in correct state." conn


updateAsError : Int -> StatusTable.Record -> Conn -> ( Conn, Cmd Msg )
updateAsError seq record conn =
    let
        errorMsgResult =
            decodeJsonBody errorReportDecoder conn
                |> Result.mapError (always StatusTable.ErrorOther)
    in
    case errorMsgResult of
        Ok errorReason ->
            case record.status of
                StatusTable.NewFromRootSite { fqPackage } ->
                    ( conn
                    , withTimestamp
                        (\posix ->
                            StatusQueries.saveErrorSeqNo posix
                                seq
                                fqPackage
                                errorReason
                                (SavedSeqNoState seq)
                                conn
                        )
                    )

                _ ->
                    error "Item with seq not found in correct state." conn

        Err decodeErrMsg ->
            jsonError (StatusTable.encodeErrorReason decodeErrMsg |> Encode.object) conn



-- Build Jobs


type alias BuildJob =
    { seq : Int
    , fqPackage : FQPackage
    , zipUrl : String
    , author : String
    , name : String
    , version : Elm.Version.Version
    }


encodeBuildJob : BuildJob -> Value
encodeBuildJob val =
    Encode.object
        [ ( "seq", Encode.int val.seq )
        , ( "fqPackage", FQPackage.encode val.fqPackage )
        , ( "zipUrl", Encode.string val.zipUrl )
        , ( "author", Encode.string val.author )
        , ( "name", Encode.string val.name )
        , ( "version", Elm.Version.encode val.version )
        ]



-- Success Report


type alias SuccessReport =
    { elmJson : Elm.Project.Project
    , packageUrl : Url
    , md5 : String
    }


successReportDecoder : Decoder SuccessReport
successReportDecoder =
    Decode.succeed SuccessReport
        |> decodeAndMap (Decode.field "elmJson" Elm.Project.decoder)
        |> decodeAndMap (Decode.field "packageUrl" decodeUrl)
        |> decodeAndMap (Decode.field "md5" Decode.string)



-- Error Report


type alias ErrorReport =
    StatusTable.ErrorReason


errorReportDecoder : Decoder ErrorReport
errorReportDecoder =
    StatusTable.errorReasonDecoder



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)


decodeUrl : Decoder Url.Url
decodeUrl =
    Decode.string
        |> Decode.map Url.fromString
        |> Decode.andThen
            (\maybeUrl ->
                case maybeUrl of
                    Nothing ->
                        Decode.fail "Not a valid URL."

                    Just val ->
                        Decode.succeed val
            )


decodeJsonBody : Decoder a -> Conn.Conn config model route msg -> Result String a
decodeJsonBody decoder conn =
    Conn.request conn
        |> Request.body
        |> Body.asJson
        |> Result.andThen
            (\val ->
                Decode.decodeValue decoder val
                    |> Result.mapError Decode.errorToString
            )
