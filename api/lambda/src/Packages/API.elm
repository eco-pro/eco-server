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
    = PassthroughAllPackages (Result Http.Error Decode.Value)
    | PassthroughAllPackagesSince (Result Http.Error (List FQPackage))
    | PassthroughElmJson (Result Http.Error Decode.Value)
    | PassthroughEndpointJson (Result Http.Error Decode.Value)
    | CheckSeqNo (Dynamo.GetResponse ElmSeqDynamoDBTable)
    | RefreshPackages Int (Result Http.Error ( Posix, List FQPackage ))
    | FetchedPackagesToUpdate Int Posix (List FQPackage) (Dynamo.BatchGetResponse ElmPackagesDynamoDBTable)
    | PackagesSaved Int Posix
    | SeqNoSaved Int


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case Debug.log "update" msg of
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
                Dynamo.Item record ->
                    ( conn
                    , RootSite.fetchAllPackagesSince 11450
                        -- record.seq
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages 11450)
                      --record.seq)
                    )

                Dynamo.ItemNotFound ->
                    ( conn
                    , RootSite.fetchAllPackagesSince 11450
                        |> Task.map2 Tuple.pair Time.now
                        |> Task.attempt (RefreshPackages 11450)
                    )

                Dynamo.Error dbErrorMsg ->
                    error dbErrorMsg conn

        RefreshPackages from result ->
            case result of
                Ok ( timestamp, packageList ) ->
                    case packageList of
                        [] ->
                            ( conn, Cmd.none )
                                |> andThen createdOk

                        _ ->
                            -- Load any existing packages that are in the list of new packages.
                            let
                                seqNo =
                                    List.length packageList + from

                                packageNames =
                                    List.map (\{ name } -> Elm.Package.toString name) packageList
                                        |> Set.fromList
                                        |> Set.toList
                                        |> List.map (\name -> { name = name })
                            in
                            ( conn, Cmd.none )
                                |> andThen
                                    (loadPackagesByName
                                        packageNames
                                        (FetchedPackagesToUpdate seqNo timestamp packageList)
                                    )

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        FetchedPackagesToUpdate seqNo timestamp newPackageList loadResult ->
            -- Save the updated package list to the table.
            -- This updates existing version lists with new versions
            -- OR creates a new package and version list if a package
            -- does not already exist.
            case loadResult of
                Dynamo.BatchGetItems [] ->
                    let
                        packageTableEntries =
                            packageListToElmPackageDyamoDBTable timestamp newPackageList
                    in
                    ( conn, Cmd.none )
                        |> andThen
                            (saveAllPackages
                                timestamp
                                packageTableEntries
                                (PackagesSaved seqNo timestamp |> always)
                            )

                Dynamo.BatchGetItems record ->
                    --( conn, Cmd.none )
                    Debug.todo "Packages fetched and there are existing items."

                Dynamo.BatchGetError dbErrorMsg ->
                    error dbErrorMsg conn

        -- let
        --     packageTableEntries =
        --         packageListToElmPackageDyamoDBTable timestamp newPackageList
        -- in
        -- ( conn, Cmd.none )
        --     |> andThen
        --         (saveAllPackages
        --             timestamp
        --             packageTableEntries
        --             (PackagesSaved seqNo timestamp |> always)
        --         )
        PackagesSaved seqNo timestamp ->
            ( conn, Cmd.none )
                |> andThen (saveSeqNo timestamp seqNo (SeqNoSaved seqNo |> always))

        SeqNoSaved seqNo ->
            -- Trigger the processing jobs to populate them all.
            -- Signal back to the caller that the request completed ok.
            ( conn, Cmd.none )
                |> andThen createdOk


andThen : (model -> ( model, Cmd msg )) -> ( model, Cmd msg ) -> ( model, Cmd msg )
andThen fn ( model, cmd ) =
    let
        ( nextModel, nextCmd ) =
            fn model
    in
    ( nextModel, Cmd.batch [ cmd, nextCmd ] )


saveAllPackages :
    Posix
    -> List ElmPackagesDynamoDBTable
    -> (Value -> Msg)
    -> Conn
    -> ( Conn, Cmd Msg )
saveAllPackages timestamp packages responseFn conn =
    Dynamo.batchPut
        (fqTableName "eco-elm-packages" conn)
        elmPackagesDynamoDBTableEncoder
        packages
        responseFn
        conn


loadPackagesByName :
    List ElmPackagesDynamoDBTableKey
    -> (Dynamo.BatchGetResponse ElmPackagesDynamoDBTable -> Msg)
    -> Conn
    -> ( Conn, Cmd Msg )
loadPackagesByName packageNames responseFn conn =
    Dynamo.batchGet
        (fqTableName "eco-elm-packages" conn)
        elmPackagesDynamoDBTableKeyEncoder
        packageNames
        elmPackagesDynamoDBTableDecoder
        responseFn
        conn


loadSeqNo : (Dynamo.GetResponse ElmSeqDynamoDBTable -> Msg) -> Conn -> ( Conn, Cmd Msg )
loadSeqNo responseFn conn =
    Dynamo.get
        (fqTableName "eco-elm-seq" conn)
        elmSeqDynamoDBTableKeyEncoder
        { label = "latest" }
        elmSeqDynamoDBTableDecoder
        responseFn
        conn


saveSeqNo : Posix -> Int -> (Value -> Msg) -> Conn -> ( Conn, Cmd Msg )
saveSeqNo timestamp seqNo responseDecoder conn =
    Dynamo.put
        (fqTableName "eco-elm-seq" conn)
        elmSeqDynamoDBTableEncoder
        { label = "latest"
        , seq = seqNo
        , updatedAt = timestamp
        }
        responseDecoder
        conn


createdOk : Conn -> ( Conn, Cmd Msg )
createdOk conn =
    respond ( 201, Body.empty ) conn


error : String -> Conn -> ( Conn, Cmd Msg )
error msg conn =
    respond ( 500, Body.text msg ) conn


packageListToElmPackageDyamoDBTable : Posix -> List FQPackage -> List ElmPackagesDynamoDBTable
packageListToElmPackageDyamoDBTable timestamp packages =
    let
        versionsByName =
            List.foldl
                (\{ name, version } accum ->
                    let
                        strName =
                            Elm.Package.toString name
                    in
                    Dict.update strName
                        (\maybeVal ->
                            case maybeVal of
                                Nothing ->
                                    [ version ] |> Just

                                Just versions ->
                                    version :: versions |> Just
                        )
                        accum
                )
                Dict.empty
                packages
    in
    Dict.foldl
        (\name versions accum ->
            { name = name
            , versions = versions
            , updatedAt = timestamp
            }
                :: accum
        )
        []
        versionsByName



-- DynamoDB Tables


fqTableName : String -> Conn -> String
fqTableName name conn =
    (Conn.config conn).dynamoDbNamespace ++ "-" ++ name


type alias ElmSeqDynamoDBTable =
    { label : String
    , seq : Int
    , updatedAt : Posix
    }


type alias ElmSeqDynamoDBTableKey =
    { label : String }


elmSeqDynamoDBTableEncoder : ElmSeqDynamoDBTable -> Value
elmSeqDynamoDBTableEncoder record =
    Encode.object
        [ ( "label", Encode.string record.label )
        , ( "seq", Encode.int record.seq )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


elmSeqDynamoDBTableDecoder : Decoder ElmSeqDynamoDBTable
elmSeqDynamoDBTableDecoder =
    Decode.succeed ElmSeqDynamoDBTable
        |> decodeAndMap (Decode.field "label" Decode.string)
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))


elmSeqDynamoDBTableKeyEncoder : ElmSeqDynamoDBTableKey -> Value
elmSeqDynamoDBTableKeyEncoder record =
    Encode.object
        [ ( "label", Encode.string record.label )
        ]


type alias ElmPackagesDynamoDBTable =
    { name : String
    , versions : List Elm.Version.Version
    , updatedAt : Posix
    }


type alias ElmPackagesDynamoDBTableKey =
    { name : String }


elmPackagesDynamoDBTableEncoder : ElmPackagesDynamoDBTable -> Value
elmPackagesDynamoDBTableEncoder record =
    Encode.object
        [ ( "name", Encode.string record.name )
        , ( "versions", Encode.list Elm.Version.encode record.versions )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


elmPackagesDynamoDBTableDecoder : Decoder ElmPackagesDynamoDBTable
elmPackagesDynamoDBTableDecoder =
    Decode.succeed ElmPackagesDynamoDBTable
        |> decodeAndMap (Decode.field "name" Decode.string)
        |> decodeAndMap (Decode.field "versions" (Decode.list Elm.Version.decoder))
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))


elmPackagesDynamoDBTableKeyEncoder : ElmPackagesDynamoDBTableKey -> Value
elmPackagesDynamoDBTableKeyEncoder record =
    Encode.object
        [ ( "name", Encode.string record.name )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
