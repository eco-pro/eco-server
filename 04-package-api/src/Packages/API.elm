port module Packages.API exposing (main)

import AWS.Dynamo as Dynamo
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
import Packages.Config as Config exposing (Config)
import Parser exposing (Parser)
import Result.Extra as RE
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


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ -- The original package site API
          map AllPackages (s "v1" </> s "all-packages")
        , map AllPackagesSince (s "v1" </> s "all-packages" </> s "since" </> Url.Parser.int)
        , map ElmJson
            (s "v1"
                </> s "packages"
                </> Url.Parser.string
                </> Url.Parser.string
                </> Url.Parser.string
                </> s "elm.json"
            )
        , map EndpointJson
            (s "v1"
                </> s "packages"
                </> Url.Parser.string
                </> Url.Parser.string
                </> Url.Parser.string
                </> s "endpoint.json"
            )
        ]
        |> Url.Parser.parse


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        -- The original package site API
        ( POST, AllPackages ) ->
            StatusQueries.getPackagesSince 0
                StatusTable.LabelReady
                (decodeStatusRecord >> ReadyPackagesLoaded)
                DynamoMsg
                conn

        ( GET, AllPackages ) ->
            StatusQueries.getPackagesSince 0
                StatusTable.LabelReady
                (decodeStatusRecord >> ReadyPackagesLoaded)
                DynamoMsg
                conn

        ( POST, AllPackagesSince since ) ->
            StatusQueries.getPackagesSince since
                StatusTable.LabelReady
                (decodeStatusRecord >> ReadyPackagesSinceLoaded since)
                DynamoMsg
                conn

        ( GET, AllPackagesSince since ) ->
            StatusQueries.getPackagesSince since
                StatusTable.LabelReady
                (decodeStatusRecord >> ReadyPackagesSinceLoaded since)
                DynamoMsg
                conn

        ( GET, ElmJson author name version ) ->
            FQPackage.fromStringParts author name version
                |> Maybe.map (\fqPackage -> StatusQueries.getPackage fqPackage BuildStatusForElmJson conn)
                |> Maybe.withDefault (respond ( 400, Body.text "Bad Package Reference" ) conn)

        ( GET, EndpointJson author name version ) ->
            FQPackage.fromStringParts author name version
                |> Maybe.map (\fqPackage -> StatusQueries.getPackage fqPackage BuildStatusForEndpoint conn)
                |> Maybe.withDefault (respond ( 400, Body.text "Bad Package Reference" ) conn)

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


decodeStatusRecord : Dynamo.QueryResponse Value -> Dynamo.QueryResponse StatusTable.Record
decodeStatusRecord queryResponse =
    case queryResponse of
        Dynamo.BatchGetItems items ->
            let
                decodedItems =
                    items
                        |> List.map (Decode.decodeValue StatusTable.decoder)
                        |> RE.combine
                        |> Result.mapError (Decode.errorToString >> Dynamo.BatchGetError)
            in
            case decodedItems of
                Ok vals ->
                    Dynamo.BatchGetItems vals

                Err err ->
                    err

        Dynamo.BatchGetError err ->
            Dynamo.BatchGetError err


type Msg
    = Noop
    | DynamoMsg (Dynamo.Msg Msg)
    | BuildStatusForElmJson (Dynamo.QueryResponse StatusTable.Record)
    | BuildStatusForEndpoint (Dynamo.QueryResponse StatusTable.Record)
    | ReadyPackagesSinceLoaded Int (Dynamo.QueryResponse StatusTable.Record)
    | ReadyPackagesLoaded (Dynamo.QueryResponse StatusTable.Record)
    | PackagesSinceLoaded (List StatusTable.Record) (Dynamo.QueryResponse StatusTable.Record)
    | AllPackagesLoaded (List StatusTable.Record) (Dynamo.QueryResponse StatusTable.Record)


customLogger : Msg -> String
customLogger msg =
    case msg of
        Noop ->
            "Noop"

        DynamoMsg _ ->
            "DynamoMsg"

        BuildStatusForElmJson _ ->
            "BuildStatusForElmJson"

        BuildStatusForEndpoint _ ->
            "BuildStatusForEndpoint"

        ReadyPackagesSinceLoaded _ _ ->
            "ReadyPackagesSinceLoaded"

        ReadyPackagesLoaded _ ->
            "ReadyPackagesLoaded"

        PackagesSinceLoaded _ _ ->
            "PackagesSinceLoaded"

        AllPackagesLoaded _ _ ->
            "AllPackagesLoaded"


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

        BuildStatusForElmJson result ->
            case result of
                Dynamo.BatchGetItems (status :: _) ->
                    StatusTable.getElmJson status
                        |> Maybe.map
                            (\project ->
                                respond
                                    ( 200
                                    , Body.json (Elm.Project.encode project)
                                    )
                                    conn
                            )
                        |> Maybe.withDefault (respond ( 404, Body.empty ) conn)

                Dynamo.BatchGetItems [] ->
                    respond ( 404, Body.empty ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        BuildStatusForEndpoint result ->
            case result of
                Dynamo.BatchGetItems (status :: _) ->
                    StatusTable.getArchive status
                        |> Maybe.map
                            (\archive ->
                                respond
                                    ( 200
                                    , Body.json
                                        (encodeEndpoint
                                            { url = archive.url
                                            , hash = archive.sha1ZipArchive
                                            }
                                        )
                                    )
                                    conn
                            )
                        |> Maybe.withDefault (respond ( 404, Body.empty ) conn)

                Dynamo.BatchGetItems [] ->
                    respond ( 404, Body.empty ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        ReadyPackagesSinceLoaded since loadResult ->
            case loadResult of
                Dynamo.BatchGetItems records ->
                    StatusQueries.getPackagesSince since
                        StatusTable.LabelError
                        (decodeStatusRecord >> PackagesSinceLoaded records)
                        DynamoMsg
                        conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        ReadyPackagesLoaded loadResult ->
            case loadResult of
                Dynamo.BatchGetItems records ->
                    StatusQueries.getPackagesSince 0
                        StatusTable.LabelError
                        (decodeStatusRecord >> AllPackagesLoaded records)
                        DynamoMsg
                        conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        PackagesSinceLoaded readyRecords loadResult ->
            case loadResult of
                Dynamo.BatchGetItems errorRecords ->
                    let
                        records =
                            List.append readyRecords errorRecords
                                |> List.map (\item -> ( item.seq, item ))
                                |> Dict.fromList
                                |> Dict.values

                        readyPackage status =
                            case status of
                                StatusTable.Ready { fqPackage } ->
                                    fqPackage

                                StatusTable.Error { fqPackage } ->
                                    fqPackage

                        jsonRecords =
                            records
                                |> List.map (.status >> readyPackage)
                                |> List.reverse
                                |> Encode.list (FQPackage.toString >> Encode.string)
                    in
                    respond ( 200, Body.json jsonRecords ) conn

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        AllPackagesLoaded readyRecords loadResult ->
            case loadResult of
                Dynamo.BatchGetItems errorRecords ->
                    let
                        records =
                            List.append readyRecords errorRecords
                                |> List.map (\item -> ( item.seq, item ))
                                |> Dict.fromList
                                |> Dict.values

                        readyPackage status =
                            case status of
                                StatusTable.Ready { fqPackage } ->
                                    fqPackage

                                StatusTable.Error { fqPackage } ->
                                    fqPackage

                        jsonRecords =
                            records
                                |> List.map (.status >> readyPackage)
                                |> List.reverse
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


andThen : (model -> ( model, Cmd msg )) -> ( model, Cmd msg ) -> ( model, Cmd msg )
andThen fn ( model, cmd ) =
    let
        ( nextModel, nextCmd ) =
            fn model
    in
    ( nextModel, Cmd.batch [ cmd, nextCmd ] )


error : String -> Conn -> ( Conn, Cmd Msg )
error msg conn =
    respond ( 500, Body.text msg ) conn



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


encodeUrl : Url -> Value
encodeUrl url =
    Url.toString url
        |> Encode.string
