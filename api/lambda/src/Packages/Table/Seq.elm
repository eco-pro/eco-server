module Packages.Table.Seq exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Time exposing (Posix)


type Status
    = Latest
    | NewFromRootSite
        { fqPackage : FQPackage
        }
    | OutdatedPackage
    | ValidElmJson
    | Ready


type alias Record =
    { seq : Int
    , updatedAt : Posix
    , status : Status
    }


type alias Key =
    { label : String
    , seq : Int
    }


encode : Record -> Value
encode record =
    Encode.object
        [ ( "label", statusToLabel record.status |> Encode.string )
        , ( "seq", Encode.int record.seq )
        , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
        , ( "status", encodeStatus record.status )
        ]


statusToLabel : Status -> String
statusToLabel status =
    case status of
        Latest ->
            "latest"

        NewFromRootSite _ ->
            "new"

        OutdatedPackage ->
            "outdated"

        ValidElmJson ->
            "valid-elm-json"

        Ready ->
            "ready"


encodeStatus : Status -> Value
encodeStatus status =
    case status of
        Latest ->
            Encode.object []

        NewFromRootSite { fqPackage } ->
            Encode.object [ ( "fqPackage", FQPackage.encode fqPackage ) ]

        OutdatedPackage ->
            Encode.object []

        ValidElmJson ->
            Encode.object []

        Ready ->
            Encode.object []


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))
        |> decodeAndMap (Decode.field "status" statusDecoder)


statusDecoder : Decoder Status
statusDecoder =
    Debug.todo "statusDecoder"


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
