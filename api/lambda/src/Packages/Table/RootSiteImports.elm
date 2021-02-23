module Packages.Table.RootSiteImports exposing
    ( Key
    , Record
    , decoder
    , encode
    , encodeKey
    )

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Time exposing (Posix)


type alias Record =
    { seq : Int
    , updatedAt : Posix
    , fqPackage : FQPackage
    }


type alias Key =
    { seq : Int
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "seq", Encode.int record.seq )
        , ( "fqPackage", FQPackage.encode record.fqPackage )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))
        |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)


encodeKey : Key -> Value
encodeKey key =
    Encode.object
        [ ( "seq", Encode.int key.seq ) ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
