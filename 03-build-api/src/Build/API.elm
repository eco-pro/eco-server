port module Build.API exposing (main)

import AWS.Dynamo as Dynamo
import Build.Config as Config exposing (Config)
import DB.BuildStatus.Queries as StatusQueries
import DB.BuildStatus.Table as StatusTable
import DB.Markers.Queries as MarkersQueries
import DB.Markers.Table as MarkersTable
import DB.RootSiteImports.Queries as RootSiteImportsQueries
import DB.RootSiteImports.Table as RootSiteImportsTable
import Dict exposing (Dict)
import Elm.FQPackage as FQPackage exposing (FQPackage)
import Elm.Package
import Elm.Project
import Elm.Version
import Http
import Http.RootSite as RootSite
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Maybe.Extra
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


startElm19 : Int
startElm19 =
    6557



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
    = Refresh
    | NextJob
    | SpecificJob Int
    | PackageError Int
    | PackageReady Int


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ -- The root site build job API
          map Refresh (s "root-site" </> s "packages" </> s "refresh")
        , map NextJob (s "root-site" </> s "packages" </> s "nextjob")
        , map SpecificJob (s "root-site" </> s "packages" </> s "job" </> Url.Parser.int)
        , map PackageError (s "root-site" </> s "packages" </> Url.Parser.int </> s "error")
        , map PackageReady (s "root-site" </> s "packages" </> Url.Parser.int </> s "ready")
        ]
        |> Url.Parser.parse


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        -- The root site build job API
        ( GET, Refresh ) ->
            MarkersQueries.get "package-elm-org" CheckSeqNo conn

        ( GET, NextJob ) ->
            MarkersQueries.get "package-elm-org"
                (GetMarkerAndThen
                    (\record innerConn ->
                        RootSiteImportsQueries.getBySeq (record.processedTo + 1)
                            (SaveJobState record)
                            innerConn
                    )
                )
                conn

        ( GET, SpecificJob seq ) ->
            RootSiteImportsQueries.getBySeq seq
                (GetRootSiteImportAndThen
                    (\{ fqPackage } innerConn ->
                        respond ( 200, Body.json (jobResponse seq fqPackage |> encodeBuildJob) ) innerConn
                    )
                )
                conn

        ( POST, PackageError seq ) ->
            RootSiteImportsQueries.getBySeq seq (GetRootSiteImportAndThen (updateAsError seq)) conn

        ( POST, PackageReady seq ) ->
            RootSiteImportsQueries.getBySeq seq (GetRootSiteImportAndThen (updateAsReady seq)) conn

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


type Msg
    = Noop
    | DynamoMsg (Dynamo.Msg Msg)
    | TimestampAndThen (Posix -> ( Conn, Cmd Msg )) Posix
    | GetRootSiteImportAndThen (RootSiteImportsTable.Record -> Conn -> ( Conn, Cmd Msg )) (Dynamo.GetResponse RootSiteImportsTable.Record)
    | GetMarkerAndThen (MarkersTable.Record -> Conn -> ( Conn, Cmd Msg )) (Dynamo.GetResponse MarkersTable.Record)
    | CheckSeqNo (Dynamo.GetResponse MarkersTable.Record)
    | RefreshPackages MarkersTable.Record (Result Http.Error ( Posix, List FQPackage ))
    | SkipBelowElm19Job (List RootSiteImportsTable.Record) MarkersTable.Record Posix Dynamo.PutResponse
    | PackagesSave MarkersTable.Record Posix Dynamo.PutResponse
    | SaveJobState MarkersTable.Record (Dynamo.GetResponse RootSiteImportsTable.Record)
    | ProvideJobDetails RootSiteImportsTable.Record Dynamo.PutResponse
    | SavedSeqNoState Dynamo.PutResponse
    | MarkJobComplete Int Posix Dynamo.PutResponse


customLogger : Msg -> String
customLogger msg =
    case msg of
        Noop ->
            "Noop"

        DynamoMsg _ ->
            "DynamoMsg"

        TimestampAndThen _ _ ->
            "TimestampAndThen"

        GetRootSiteImportAndThen _ _ ->
            "GetRootSiteImportAndThen"

        GetMarkerAndThen _ _ ->
            "GetMarkerAndThen"

        CheckSeqNo _ ->
            "CheckSeqNo"

        RefreshPackages _ _ ->
            "RefreshPackages"

        PackagesSave _ _ _ ->
            "PackagesSave"

        SkipBelowElm19Job _ _ _ _ ->
            "SkipBelowElm19Job"

        SaveJobState _ _ ->
            "SaveJobState"

        ProvideJobDetails _ _ ->
            "ProvideJobDetails"

        SavedSeqNoState _ ->
            "SavedSeqNoState"

        MarkJobComplete _ _ _ ->
            "MarkJobComplete"


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    let
        _ =
            Debug.log "update" (customLogger msg)
    in
    case msg of
        Noop ->
            ( conn, Cmd.none )

        DynamoMsg innerMsg ->
            let
                ( nextConn, dynamoCmd ) =
                    Dynamo.update innerMsg conn
            in
            ( nextConn, dynamoCmd )

        TimestampAndThen msgFn timestamp ->
            msgFn timestamp

        GetRootSiteImportAndThen recordFn getResponse ->
            withDynamoGet recordFn getResponse conn

        GetMarkerAndThen recordFn getResponse ->
            withDynamoGet recordFn getResponse conn

        CheckSeqNo loadResult ->
            case loadResult of
                Dynamo.GetItemNotFound ->
                    ( conn
                    , RootSite.fetchAllPackagesSince 0
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt
                            (RefreshPackages
                                { source = "package-elm-org"
                                , latest = 0
                                , processedTo = startElm19
                                , processing = startElm19
                                , updatedAt = Time.millisToPosix 0
                                }
                            )
                    )

                Dynamo.GetItem record ->
                    ( conn
                    , RootSite.fetchAllPackagesSince record.latest
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages record)
                    )

                Dynamo.GetError dbErrorMsg ->
                    error dbErrorMsg conn

        RefreshPackages record result ->
            case result of
                Ok ( timestamp, newPackageList ) ->
                    case newPackageList of
                        [] ->
                            ( conn, Cmd.none )
                                |> andThen createdOk

                        _ ->
                            let
                                seq =
                                    List.length newPackageList + record.latest

                                packageTableEntries =
                                    List.reverse newPackageList
                                        |> List.indexedMap
                                            (\idx fqPackage ->
                                                { seq = record.latest + idx + 1
                                                , updatedAt = timestamp
                                                , fqPackage = fqPackage
                                                }
                                            )
                            in
                            ( conn, Cmd.none )
                                |> andThen
                                    (RootSiteImportsQueries.saveAll
                                        timestamp
                                        packageTableEntries
                                        (SkipBelowElm19Job packageTableEntries { record | latest = seq } timestamp)
                                        DynamoMsg
                                    )

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        SkipBelowElm19Job newPackages record timestamp res ->
            case res of
                Dynamo.PutOk ->
                    let
                        packagesBelowElm19 =
                            newPackages
                                |> List.filter (\{ seq } -> seq <= startElm19)
                                |> List.map
                                    (\{ seq, fqPackage } ->
                                        { seq = seq
                                        , updatedAt = timestamp
                                        , status =
                                            StatusTable.Error
                                                { fqPackage = fqPackage
                                                , errorReason = StatusTable.ErrorUnsupportedElmVersion
                                                }
                                        }
                                    )
                    in
                    case packagesBelowElm19 of
                        [] ->
                            MarkersQueries.save { record | updatedAt = timestamp } SavedSeqNoState conn

                        packages ->
                            StatusQueries.saveAll
                                timestamp
                                packages
                                (PackagesSave record timestamp)
                                DynamoMsg
                                conn

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        PackagesSave record timestamp res ->
            case res of
                Dynamo.PutOk ->
                    MarkersQueries.save { record | updatedAt = timestamp } SavedSeqNoState conn

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        SaveJobState markerRecord loadResult ->
            case loadResult of
                Dynamo.GetItemNotFound ->
                    respond ( 404, Body.text "No job." ) conn

                Dynamo.GetItem rootSiteImportRecord ->
                    ( conn
                    , withTimestamp
                        (\posix ->
                            MarkersQueries.save
                                { markerRecord
                                    | processing = markerRecord.processedTo + 1
                                    , updatedAt = posix
                                }
                                (ProvideJobDetails rootSiteImportRecord)
                                conn
                        )
                    )

                Dynamo.GetError dbErrorMsg ->
                    error dbErrorMsg conn

        ProvideJobDetails { seq, fqPackage } putResult ->
            case putResult of
                Dynamo.PutOk ->
                    let
                        job =
                            jobResponse seq fqPackage
                    in
                    respond ( 200, Body.json (encodeBuildJob job) ) conn

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        SavedSeqNoState res ->
            case res of
                Dynamo.PutOk ->
                    ( conn, Cmd.none )
                        |> andThen createdOk

                Dynamo.PutError dbErrorMsg ->
                    error dbErrorMsg conn

        MarkJobComplete seq posix res ->
            case res of
                Dynamo.PutOk ->
                    MarkersQueries.get "package-elm-org"
                        (GetMarkerAndThen
                            (\record innerConn ->
                                MarkersQueries.save
                                    { record
                                        | processedTo = seq
                                        , updatedAt = posix
                                    }
                                    SavedSeqNoState
                                    conn
                            )
                        )
                        conn

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


withDynamoGet : (a -> Conn -> ( Conn, Cmd Msg )) -> Dynamo.GetResponse a -> Conn -> ( Conn, Cmd Msg )
withDynamoGet recordFn getResponse conn =
    case getResponse of
        Dynamo.GetItem record ->
            recordFn record conn

        Dynamo.GetItemNotFound ->
            respond ( 404, Body.text "Item not found." ) conn

        Dynamo.GetError dbErrorMsg ->
            error dbErrorMsg conn


createdOk : Conn -> ( Conn, Cmd Msg )
createdOk conn =
    respond ( 201, Body.empty ) conn


error : String -> Conn -> ( Conn, Cmd Msg )
error msg conn =
    respond ( 500, Body.text msg ) conn


jsonError : Value -> Conn -> ( Conn, Cmd Msg )
jsonError json conn =
    respond ( 500, Body.json json ) conn


updateAsReady : Int -> RootSiteImportsTable.Record -> Conn -> ( Conn, Cmd Msg )
updateAsReady seq record conn =
    case decodeJsonBody successReportDecoder conn of
        Ok { elmJson, archive } ->
            ( conn
            , withTimestamp
                (\posix ->
                    StatusQueries.saveReady posix
                        seq
                        record.fqPackage
                        elmJson
                        archive
                        (MarkJobComplete seq posix)
                        conn
                )
            )

        Err decodeErrMsg ->
            ( conn
            , withTimestamp
                (\posix ->
                    StatusQueries.saveError posix
                        seq
                        record.fqPackage
                        (StatusTable.ErrorElmJsonInvalid decodeErrMsg)
                        (MarkJobComplete seq posix)
                        conn
                )
            )


updateAsError : Int -> RootSiteImportsTable.Record -> Conn -> ( Conn, Cmd Msg )
updateAsError seq record conn =
    let
        errorMsgResult =
            decodeJsonBody errorReportDecoder conn
                |> Result.mapError StatusTable.ErrorOther
    in
    case errorMsgResult of
        Ok errorReason ->
            ( conn
            , withTimestamp
                (\posix ->
                    StatusQueries.saveError posix
                        seq
                        record.fqPackage
                        errorReason
                        (MarkJobComplete seq posix)
                        conn
                )
            )

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


jobResponse : Int -> FQPackage -> BuildJob
jobResponse seq fqPackage =
    { seq = seq
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



-- Success Report


type alias SuccessReport =
    { elmJson : Elm.Project.Project
    , archive : StatusTable.Archive
    }


successReportDecoder : Decoder SuccessReport
successReportDecoder =
    Decode.succeed SuccessReport
        |> decodeAndMap (Decode.field "elmJson" Elm.Project.decoder)
        |> decodeAndMap StatusTable.archiveDecoder



-- Error Report


type alias ErrorReport =
    StatusTable.ErrorReason


errorReportDecoder : Decoder ErrorReport
errorReportDecoder =
    StatusTable.errorReasonDecoder



-- Package Endpoint


type alias Endpoint =
    { url : Url
    , hash : String
    }


encodeEndpoint : Endpoint -> Value
encodeEndpoint endpoint =
    Encode.object
        [ ( "url", encodeUrl endpoint.url )
        , ( "hash", Encode.string endpoint.hash )
        ]



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


encodeUrl : Url -> Value
encodeUrl url =
    Url.toString url
        |> Encode.string


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
