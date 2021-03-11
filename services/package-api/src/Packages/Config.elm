module Packages.Config exposing (Config, configDecoder)

import Json.Decode as Decode exposing (Decoder)


type alias Config =
    { dynamoDbNamespace : String
    }


configDecoder : Decoder Config
configDecoder =
    Decode.field "DYNAMODB_NAMESPACE" Decode.string
        |> Decode.map Config
