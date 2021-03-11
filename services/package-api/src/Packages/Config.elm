module Packages.Config exposing (Config, configDecoder)

import Json.Decode as Decode exposing (Decoder)


type alias Config =
    { buildStatusTable : String
    , markersTable : String
    , rootSiteImportsTable : String
    , buildQueue : String
    , buildService : String
    }


configDecoder : Decoder Config
configDecoder =
    Decode.succeed Config
        |> decodeAndMap (Decode.field "buildStatusTable" Decode.string)
        |> decodeAndMap (Decode.field "markersTable" Decode.string)
        |> decodeAndMap (Decode.field "rootSiteImportsTable" Decode.string)
        |> decodeAndMap (Decode.field "buildQueue" Decode.string)
        |> decodeAndMap (Decode.field "buildService" Decode.string)


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
