module Packages.Config exposing (Config, configDecoder)

import Json.Decode as Decode exposing (Decoder)


type alias Config =
    { buildStatusTable : String
    , buildStatusByFQPackageIndex : String
    , markersTable : String
    , rootSiteImportsTable : String
    }


configDecoder : Decoder Config
configDecoder =
    Decode.succeed Config
        |> decodeAndMap (Decode.field "buildStatusTable" Decode.string)
        |> decodeAndMap (Decode.field "buildStatusByFQPackageIndex" Decode.string)
        |> decodeAndMap (Decode.field "markersTable" Decode.string)
        |> decodeAndMap (Decode.field "rootSiteImportsTable" Decode.string)
        |> Decode.map (Debug.log "config")


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
