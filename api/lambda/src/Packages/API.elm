port module Packages.API exposing (main)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Serverless
import Serverless.Conn exposing (jsonBody, method, request, respond, route, textBody)
import Serverless.Conn.Request exposing (Method(..), Request, asJson, body)
import Url
import Url.Parser exposing ((</>), (<?>), int, map, oneOf, s, top)
import Url.Parser.Query as Query



-- Serverless program.


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg


type alias Conn =
    Serverless.Conn.Conn () () Route


type Msg
    = FetchedAllPackages (Result Http.Error Decode.Value)
    | FetchedAllPackagesSince (Result Http.Error Decode.Value)


main : Serverless.Program () () Route Msg
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , parseRoute = routeParser
        , endpoint = router
        , update = update
        , interopPorts = Serverless.noPorts
        , requestPort = requestPort
        , responsePort = responsePort
        }



-- Route and query parsing.


type Route
    = AllPackages
    | AllPackagesSince Int


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ map AllPackages (s "all-packages")
        , map AllPackagesSince (s "all-packages" </> s "since" </> Url.Parser.int)
        ]
        |> Url.Parser.parse



-- Route processing.


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        ( GET, AllPackages ) ->
            ( conn, fetchAllPackages )

        ( GET, AllPackagesSince since ) ->
            ( conn, fetchAllPackagesSince since )

        ( _, _ ) ->
            respond ( 405, textBody "Method not allowed" ) conn



-- Side effects.


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case Debug.log "update" msg of
        FetchedAllPackages result ->
            case result of
                Ok val ->
                    respond ( 200, jsonBody val ) conn

                Err err ->
                    respond ( 500, textBody "Got error when trying to contact package.elm-lang.com." ) conn

        FetchedAllPackagesSince result ->
            case result of
                Ok val ->
                    respond ( 200, jsonBody val ) conn

                Err _ ->
                    respond ( 500, textBody "Got error when trying to contact package.elm-lang.com." ) conn



-- Pass through to package.elm-lang.org


packageUrl : String
packageUrl =
    "https://package.elm-lang.org/"


fetchAllPackages : Cmd Msg
fetchAllPackages =
    Http.get
        { url = packageUrl ++ "all-packages/"
        , expect = Http.expectJson FetchedAllPackages Decode.value
        }


fetchAllPackagesSince : Int -> Cmd Msg
fetchAllPackagesSince since =
    Http.get
        { url = packageUrl ++ "all-packages/since/" ++ String.fromInt since
        , expect = Http.expectJson FetchedAllPackagesSince Decode.value
        }
