module Packages.Table.Seq exposing (..)

import Elm.Project exposing (Project)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Time exposing (Posix)


type Status
    = Latest
    | NewFromRootSite
        { fqPackage : FQPackage
        }
    | Ready
        { fqPackage : FQPackage
        , elmJson : Project

        --, packageUrl : Url
        }
    | Error
        { fqPackage : FQPackage
        , errorMsg : String
        }


type Label
    = LabelLatest
    | LabelNewFromRootSite
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

        Ready _ ->
            LabelReady

        Error _ ->
            LabelError


labelToString : Label -> String
labelToString label =
    case label of
        LabelLatest ->
            "latest"

        LabelNewFromRootSite ->
            "new"

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

        Ready { fqPackage, elmJson } ->
            [ ( "fqPackage", FQPackage.encode fqPackage )
            , ( "elmJson", Elm.Project.encode elmJson )
            ]

        Error { fqPackage, errorMsg } ->
            [ ( "fqPackage", FQPackage.encode fqPackage )
            , ( "errorMsg", Encode.string errorMsg )
            ]


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

                    "ready" ->
                        Decode.succeed
                            (\fqp elmJson ->
                                Ready
                                    { fqPackage = fqp
                                    , elmJson = elmJson
                                    }
                            )
                            |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)
                            |> decodeAndMap (Decode.field "elmJson" Elm.Project.decoder)

                    _ ->
                        Decode.succeed
                            (\fqp errorMsg ->
                                Error
                                    { fqPackage = fqp
                                    , errorMsg = errorMsg
                                    }
                            )
                            |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)
                            |> decodeAndMap (Decode.field "errorMsg" Decode.string)
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
