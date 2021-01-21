port module Packages.API exposing (main)

import Serverless
import Serverless.Conn exposing (respond, textBody)


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
