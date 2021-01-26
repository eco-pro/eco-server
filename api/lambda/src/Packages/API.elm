port module Packages.API exposing (main)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Packages.Dynamo as Dynamo
import Packages.RootSite as RootSite
import Serverless
import Serverless.Conn exposing (method, request, respond, route)
import Serverless.Conn.Body as Body
import Serverless.Conn.Request exposing (Method(..), Request, body)
import Url
import Url.Parser exposing ((</>), (<?>), int, map, oneOf, s, top)
import Url.Parser.Query as Query



-- Serverless program.


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg


type alias Conn =
    Serverless.Conn.Conn () () Route


type Msg
    = PassthroughAllPackages (Result Http.Error Decode.Value)
    | PassthroughAllPackagesSince (Result Http.Error Decode.Value)
    | PassthroughElmJson (Result Http.Error Decode.Value)
    | PassthroughEndpointJson (Result Http.Error Decode.Value)
    | RefreshPackages (Result Http.Error Decode.Value)
    | DynamoOk Decode.Value


main : Serverless.Program () () Route Msg
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , parseRoute = routeParser
        , endpoint = router
        , update = update
        , interopPorts = [ ( Dynamo.dynamoOk, Decode.map DynamoOk Decode.value ) ]
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



-- Route processing.


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        ( GET, AllPackages ) ->
            ( conn, RootSite.fetchAllPackages PassthroughAllPackages )

        ( POST, AllPackagesSince since ) ->
            ( conn, RootSite.fetchAllPackagesSince PassthroughAllPackagesSince since )

        ( GET, ElmJson author name version ) ->
            ( conn, RootSite.fetchElmJson PassthroughElmJson author name version )

        ( GET, EndpointJson author name version ) ->
            ( conn, RootSite.fetchEndpointJson PassthroughEndpointJson author name version )

        ( GET, Refresh ) ->
            -- Query the table to see what we know about.
            -- If its empty, refresh since 0.
            -- If its got stuff, refresh since what we know about.
            ( conn, RootSite.fetchAllPackagesSince RefreshPackages 0 )

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


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
                    respond ( 200, Body.json val ) conn

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

        RefreshPackages result ->
            case result of
                Ok val ->
                    -- Save the package list to the table.
                    -- Trigger the processing jobs to populate them all.
                    ( conn, Cmd.none )
                        |> andThen saveAllPackages

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        DynamoOk _ ->
            ( conn, Cmd.none )
                |> andThen createdOk


andThen : (model -> ( model, Cmd msg )) -> ( model, Cmd msg ) -> ( model, Cmd msg )
andThen fn ( model, cmd ) =
    let
        ( nextModel, nextCmd ) =
            fn model
    in
    ( nextModel, Cmd.batch [ cmd, nextCmd ] )


saveAllPackages : Conn -> ( Conn, Cmd Msg )
saveAllPackages conn =
    ( conn, Serverless.interop Dynamo.upsertPackageSeq () conn )


createdOk : Conn -> ( Conn, Cmd Msg )
createdOk conn =
    respond ( 201, Body.empty ) conn
