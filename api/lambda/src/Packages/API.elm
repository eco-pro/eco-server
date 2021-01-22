port module Packages.API exposing (main)

import Http
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
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
    = FetchedAllPackages (Result Http.Error Decode.Value)
    | FetchedAllPackagesSince (Result Http.Error Decode.Value)
    | FetchedElmJson (Result Http.Error Decode.Value)
    | FetchedEndpointJson (Result Http.Error Decode.Value)


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
    | ElmJson String String String
    | EndpointJson String String String


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ map AllPackages (s "all-packages")
        , map AllPackagesSince (s "all-packages" </> s "since" </> Url.Parser.int)
        , map ElmJson (s "packages" </> Url.Parser.string </> Url.Parser.string </> Url.Parser.string </> s "elm.json")
        , map EndpointJson (s "packages" </> Url.Parser.string </> Url.Parser.string </> Url.Parser.string </> s "endpoint.json")
        ]
        |> Url.Parser.parse



-- Route processing.


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        ( GET, AllPackages ) ->
            ( conn, fetchAllPackages )

        ( POST, AllPackagesSince since ) ->
            ( conn, fetchAllPackagesSince since )

        ( GET, ElmJson author name version ) ->
            ( conn, fetchElmJson author name version )

        ( GET, EndpointJson author name version ) ->
            ( conn, fetchEndpointJson author name version )

        ( _, _ ) ->
            respond ( 405, Body.text "Method not allowed" ) conn



-- Side effects.


update : Msg -> Conn -> ( Conn, Cmd Msg )
update msg conn =
    case Debug.log "update" msg of
        FetchedAllPackages result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err err ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        FetchedAllPackagesSince result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        FetchedElmJson result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn

        FetchedEndpointJson result ->
            case result of
                Ok val ->
                    respond ( 200, Body.json val ) conn

                Err _ ->
                    respond ( 500, Body.text "Got error when trying to contact package.elm-lang.com." ) conn



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
    Http.post
        { url = packageUrl ++ "all-packages/since/" ++ String.fromInt since
        , expect = Http.expectJson FetchedAllPackagesSince Decode.value
        , body = Http.emptyBody
        }


fetchElmJson : String -> String -> String -> Cmd Msg
fetchElmJson author name version =
    Http.get
        { url = packageUrl ++ "packages/" ++ author ++ "/" ++ name ++ "/" ++ version ++ "/elm.json"
        , expect = Http.expectJson FetchedElmJson Decode.value
        }


fetchEndpointJson : String -> String -> String -> Cmd Msg
fetchEndpointJson author name version =
    Http.get
        { url = packageUrl ++ "packages/" ++ author ++ "/" ++ name ++ "/" ++ version ++ "/endpoint.json"
        , expect = Http.expectJson FetchedEndpointJson Decode.value
        }
