module Packages.Table.Seq exposing (..)

import Elm.Project exposing (Project)
import Elm.Version exposing (Version)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Time exposing (Posix)
import Url exposing (Url)


type Status
    = Latest
    | NewFromRootSite
        { fqPackage : FQPackage
        }
    | Ready
        { fqPackage : FQPackage
        , elmJson : Project
        , packageUrl : Url
        , md5 : String
        }
    | Error
        { fqPackage : FQPackage
        , errorReason : ErrorReason
        }


type ErrorReason
    = ErrorNoGithubPackage
    | ErrorPackageRenamed
    | ErrorElmJsonInvalid String
    | ErrorNotElmPackage
    | ErrorUnsupportedElmVersion
    | ErrorCompileFailed Version


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

        Ready { fqPackage, elmJson, packageUrl, md5 } ->
            [ ( "fqPackage", FQPackage.encode fqPackage )
            , ( "elmJson", Elm.Project.encode elmJson )
            , ( "packageUrl", encodeUrl packageUrl )
            , ( "md5", Encode.string md5 )
            ]

        Error { fqPackage, errorReason } ->
            [ ( "fqPackage", FQPackage.encode fqPackage ) ]
                ++ encodeErrorReason errorReason


encodeErrorReason : ErrorReason -> List ( String, Value )
encodeErrorReason reason =
    case reason of
        ErrorNoGithubPackage ->
            [ ( "errorReason", Encode.string "no-github-package" ) ]

        ErrorPackageRenamed ->
            [ ( "errorReason", Encode.string "package-renamed" ) ]

        ErrorElmJsonInvalid decodeErrorMsg ->
            [ ( "errorReason", Encode.string "elm-json-invalid" ) ]

        ErrorNotElmPackage ->
            [ ( "errorReason", Encode.string "not-elm-package" ) ]

        ErrorUnsupportedElmVersion ->
            [ ( "errorReason", Encode.string "unsupported-elm-version" ) ]

        ErrorCompileFailed version ->
            [ ( "errorReason", Encode.string "compile-failed" ) ]


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
                            (\fqp elmJson url md5 ->
                                Ready
                                    { fqPackage = fqp
                                    , elmJson = elmJson
                                    , packageUrl = url
                                    , md5 = md5
                                    }
                            )
                            |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)
                            |> decodeAndMap (Decode.field "elmJson" Elm.Project.decoder)
                            |> decodeAndMap (Decode.field "packageUrl" decodeUrl)
                            |> decodeAndMap (Decode.field "md5" Decode.string)

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


decodeUrl : Decoder Url.Url
decodeUrl =
    Decode.string
        |> Decode.map Url.fromString
        |> Decode.andThen
            (\maybeUrl ->
                case maybeUrl of
                    Nothing ->
                        Decode.fail "Not a valid URL."

                    Just val ->
                        Decode.succeed val
            )


encodeUrl : Url -> Value
encodeUrl url =
    Url.toString url
        |> Encode.string
