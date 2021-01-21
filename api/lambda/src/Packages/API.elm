port module Packages.API exposing (main)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Serverless
import Serverless.Conn exposing (jsonBody, method, request, respond, route, textBody)
import Serverless.Conn.Request exposing (Method(..), Request, asJson, body)
import Url
import Url.Parser exposing ((</>), (<?>), int, map, oneOf, s, top)
import Url.Parser.Query as Query


main : Serverless.Program () () () ()
main =
    Serverless.httpApi
        { configDecoder = Serverless.noConfig
        , initialModel = ()
        , parseRoute = Serverless.noRoutes
        , update = Serverless.noSideEffects
        , interopPorts = Serverless.noPorts
        , endpoint = respond ( 200, textBody "Hello Elm on serverless." )
        , requestPort = requestPort
        , responsePort = responsePort
        }


port requestPort : Serverless.RequestPort msg


port responsePort : Serverless.ResponsePort msg



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
