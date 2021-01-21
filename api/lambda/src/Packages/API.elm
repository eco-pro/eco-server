port module Packages.API exposing (main)

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


type alias Msg =
    ()


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
    | Tags


routeParser : Url.Url -> Maybe Route
routeParser =
    oneOf
        [ map AllPackages (s "all-packages")
        , map AllPackagesSince (s "all-packages" </> s "since" </> Url.Parser.int)
        , map Tags (s "tags")
        ]
        |> Url.Parser.parse



-- Route processing.


router : Conn -> ( Conn, Cmd Msg )
router conn =
    case ( method conn, Debug.log "route" <| route conn ) of
        ( GET, AllPackages ) ->
            respond ( 405, textBody "Not found" ) conn

        ( GET, AllPackagesSince _ ) ->
            respond ( 404, textBody "Not found" ) conn

        ( _, _ ) ->
            respond ( 405, textBody "Method not allowed" ) conn



-- Side effects.


update : Msg -> Conn -> ( Conn, Cmd Msg )
update seed conn =
    ( conn, Cmd.none )
