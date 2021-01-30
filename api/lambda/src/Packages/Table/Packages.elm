module Packages.Table.Packages exposing (..)

import Elm.Package
import Elm.Version
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Posix)


type alias Record =
    { name : Elm.Package.Name
    , version : Elm.Version.Version
    , updatedAt : Posix
    }


type alias Key =
    { name : Elm.Package.Name
    , version : Elm.Version.Version
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "name", Elm.Package.encode record.name )
        , ( "version", Elm.Version.encode record.version )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "name" Elm.Package.decoder)
        |> decodeAndMap (Decode.field "version" Elm.Version.decoder)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "name", Elm.Package.encode record.name )
        , ( "version", Elm.Version.encode record.version )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
