module Packages.Table.Markers exposing
    ( Key
    , Label(..)
    , Record
    , decoder
    , encode
    , encodeKey
    )

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Posix)


type Label
    = Latest
    | ProcessedTo
    | Processing


type alias Record =
    { seq : Int
    , updatedAt : Posix
    , label : Label
    }


type alias Key =
    { label : Label
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "label", encodeLabel record.label )
        , ( "seq", Encode.int record.seq )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


encodeLabel : Label -> Value
encodeLabel label =
    case label of
        Latest ->
            Encode.string "latest"

        ProcessedTo ->
            Encode.string "processed-to"

        Processing ->
            Encode.string "processing"


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))
        |> decodeAndMap decodeLabel


decodeLabel : Decoder Label
decodeLabel =
    Decode.field "label" Decode.string
        |> Decode.andThen
            (\label ->
                case label of
                    "latest" ->
                        Decode.succeed Latest

                    "processed-to" ->
                        Decode.succeed ProcessedTo

                    "processing" ->
                        Decode.succeed Processing

                    _ ->
                        Decode.fail "Did not match valid label."
            )


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "label", encodeLabel record.label )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
