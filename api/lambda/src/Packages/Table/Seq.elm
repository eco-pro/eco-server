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
        { fqPackage : FQPackage

        --, elmJson : Value
        }
    | Ready
        { fqPackage : FQPackage

        --, elmJson : Value
        --, packageUrl : Url
        }
    | Error


type Label
    = LabelLatest
    | LabelNewFromRootSite
    | LabelOutdatedPackage
    | LabelValidElmJson
    | LabelReady
    | LabelError


type alias Record =
    { seq : Int
    , updatedAt : Posix
    , status : Status
    }


type alias Key =
    { label : Label
    , seq : Int
    }


encode : Record -> Value
encode record =
    Encode.object
        ([ ( "label"
           , statusToLabel record.status
                |> labelToString
                |> Encode.string
           )
         , ( "seq", Encode.int record.seq )
         , ( "updatedAt", Encode.int (Time.posixToMillis record.updatedAt) )
         ]
            ++ encodeStatus record.status
        )


statusToLabel : Status -> Label
statusToLabel status =
    case status of
        Latest ->
            LabelLatest

        NewFromRootSite _ ->
            LabelNewFromRootSite

        OutdatedPackage ->
            LabelOutdatedPackage

        ValidElmJson _ ->
            LabelValidElmJson

        Ready _ ->
            LabelReady

        Error ->
            LabelError


labelToString : Label -> String
labelToString label =
    case label of
        LabelLatest ->
            "latest"

        LabelNewFromRootSite ->
            "new"

        LabelOutdatedPackage ->
            "outdated"

        LabelValidElmJson ->
            "valid-elm-json"

        LabelReady ->
            "ready"

        LabelError ->
            "error"


encodeStatus : Status -> List ( String, Value )
encodeStatus status =
    case status of
        Latest ->
            []

        NewFromRootSite { fqPackage } ->
            [ ( "fqPackage", FQPackage.encode fqPackage ) ]

        OutdatedPackage ->
            []

        ValidElmJson { fqPackage } ->
            [ ( "fqPackage", FQPackage.encode fqPackage ) ]

        Ready { fqPackage } ->
            [ ( "fqPackage", FQPackage.encode fqPackage ) ]

        Error ->
            []


decoder : Decoder Record
decoder =
    Decode.succeed Record
        |> decodeAndMap (Decode.field "seq" Decode.int)
        |> decodeAndMap (Decode.field "updatedAt" (Decode.map Time.millisToPosix Decode.int))
        |> decodeAndMap statusDecoder


statusDecoder : Decoder Status
statusDecoder =
    Decode.field "label" Decode.string
        |> Decode.andThen
            (\label ->
                case label of
                    "latest" ->
                        Decode.succeed Latest

                    "new" ->
                        Decode.field "fqPackage" FQPackage.decoder
                            |> Decode.map (\fqp -> NewFromRootSite { fqPackage = fqp })

                    "outdated" ->
                        Decode.succeed OutdatedPackage

                    "valid-elm-json" ->
                        Decode.field "fqPackage" FQPackage.decoder
                            |> Decode.map (\fqp -> ValidElmJson { fqPackage = fqp })

                    "ready" ->
                        Decode.field "fqPackage" FQPackage.decoder
                            |> Decode.map (\fqp -> Ready { fqPackage = fqp })

                    _ ->
                        Decode.succeed Error
            )


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "label", labelToString record.label |> Encode.string )
        , ( "seq", Encode.int record.seq )
        ]



-- Helpers


decodeAndMap : Decoder a -> Decoder (a -> b) -> Decoder b
decodeAndMap =
    Decode.map2 (|>)
