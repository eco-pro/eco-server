module DB.Markers.Table exposing
    ( Key
    , Record
    , decoder
    , encode
    , encodeKey
    )

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Posix)


type alias Record =
    { source : String
    , latest : Int
    , processedTo : Int
    , processing : Int
    , updatedAt : Posix
    }


type alias Key =
    { source : String
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "source", Encode.string record.source )
        , ( "latest", Encode.int record.latest )
        , ( "processedTo", Encode.int record.processedTo )
        , ( "processing", Encode.int record.processing )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        ]


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "source" Decode.string)
        |> decodeAndMap (Decode.field "latest" Decode.int)
        |> decodeAndMap (Decode.field "processedTo" Decode.int)
        |> decodeAndMap (Decode.field "processing" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "source", Encode.string record.source )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
