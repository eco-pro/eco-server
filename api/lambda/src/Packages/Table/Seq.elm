module Packages.Table.Seq exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Time exposing (Posix)


type alias Record =
    { label : String
    , seq : Int
    , fqPackage : Maybe FQPackage
    , updatedAt : Posix
    }


type alias Key =
    { label : String
    , seq : Int
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "label", Encode.string record.label )
        , ( "seq", Encode.int record.seq )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        , ( "fqPackage"
          , case record.fqPackage of
                Nothing ->
                    Encode.null

                Just val ->
                    FQPackage.encode val
          )
        ]


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "label" Decode.string)
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "fqPackage" (Decode.maybe FQPackage.decoder))
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "label", Encode.string record.label )
        , ( "seq", Encode.int record.seq )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
