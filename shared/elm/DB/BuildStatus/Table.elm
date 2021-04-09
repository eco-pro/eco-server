module DB.BuildStatus.Table exposing
    ( Archive
    , ErrorReason(..)
    , Key
    , Label(..)
    , Record
    , Status(..)
    , archiveDecoder
    , decoder
    , encode
    , encodeArchive
    , encodeErrorReason
    , encodeKey
    , errorReasonDecoder
    , getArchive
    , getElmJson
    , labelToString
    )

import Elm.Error
import Elm.FQPackage as FQPackage exposing (FQPackage)
import Elm.Project exposing (Project)
import Elm.Version exposing (Version)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Time exposing (Posix)
import Url exposing (Url)


type Status
    = Ready
        { fqPackage : FQPackage
        , elmJson : Project
        , archive : Archive
        }
    | Error
        { fqPackage : FQPackage
        , errorReason : ErrorReason
        }


type alias Archive =
    { url : Url
    , sha1ZipArchive : String
    , sha1PackageContents : String
    }


type ErrorReason
    = ErrorNoGithubPackage
    | ErrorPackageRenamed
    | ErrorElmJsonInvalid String
    | ErrorNotElmPackage
    | ErrorUnsupportedElmVersion
    | ErrorCompileTimeout
    | ErrorCompileFailed
        { compilerVersion : Version
        , reportJson : Value
        , compileLogUrl : Url
        , jsonReportUrl : Url
        , archive : Archive
        }
    | ErrorOther String


type Label
    = LabelReady
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
        Ready _ ->
            LabelReady

        Error _ ->
            LabelError


labelToString : Label -> String
labelToString label =
    case label of
        LabelReady ->
            "ready"

        LabelError ->
            "error"


encodeStatus : Status -> List ( String, Value )
encodeStatus status =
    case status of
        Ready { fqPackage, elmJson, archive } ->
            [ ( "fqPackage", FQPackage.encode fqPackage )
            , ( "elmJson", Elm.Project.encode elmJson )
            ]
                ++ encodeArchive archive

        Error { fqPackage, errorReason } ->
            [ ( "fqPackage", FQPackage.encode fqPackage )
            ]
                ++ encodeErrorReason errorReason


encodeErrorReason : ErrorReason -> List ( String, Value )
encodeErrorReason reason =
    case reason of
        ErrorNoGithubPackage ->
            [ ( "errorReason", Encode.string "no-github-package" ) ]

        ErrorPackageRenamed ->
            [ ( "errorReason", Encode.string "package-renamed" ) ]

        ErrorElmJsonInvalid decodeErrMsg ->
            [ ( "errorReason", Encode.string "elm-json-invalid" )
            , ( "errorMsg", Encode.string decodeErrMsg )
            ]

        ErrorNotElmPackage ->
            [ ( "errorReason", Encode.string "not-elm-package" ) ]

        ErrorUnsupportedElmVersion ->
            [ ( "errorReason", Encode.string "unsupported-elm-version" ) ]

        ErrorCompileTimeout ->
            [ ( "errorReason", Encode.string "compile-timeout" ) ]

        ErrorCompileFailed { compilerVersion, reportJson, compileLogUrl, jsonReportUrl, archive } ->
            [ ( "errorReason", Encode.string "compile-failed" )
            , ( "compilerVersion", Elm.Version.encode compilerVersion )
            , ( "reportJson", reportJson )
            , ( "compileLogUrl", encodeUrl compileLogUrl )
            , ( "jsonReportUrl", encodeUrl jsonReportUrl )
            ]
                ++ encodeArchive archive

        ErrorOther val ->
            [ ( "errorReason", Encode.string "other" )
            , ( "errorMsg", Encode.string val )
            ]


encodeArchive : Archive -> List ( String, Value )
encodeArchive archive =
    [ ( "url", encodeUrl archive.url )
    , ( "sha1ZipArchive", Encode.string archive.sha1ZipArchive )
    , ( "sha1PackageContents", Encode.string archive.sha1PackageContents )
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
                    "ready" ->
                        Decode.succeed
                            (\fqp elmJson archive ->
                                Ready
                                    { fqPackage = fqp
                                    , elmJson = elmJson
                                    , archive = archive
                                    }
                            )
                            |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)
                            |> decodeAndMap (Decode.field "elmJson" Elm.Project.decoder)
                            |> decodeAndMap archiveDecoder

                    _ ->
                        Decode.succeed
                            (\fqp errorReason ->
                                Error
                                    { fqPackage = fqp
                                    , errorReason = errorReason
                                    }
                            )
                            |> decodeAndMap (Decode.field "fqPackage" FQPackage.decoder)
                            |> decodeAndMap errorReasonDecoder
            )


errorReasonDecoder : Decoder ErrorReason
errorReasonDecoder =
    Decode.field "errorReason" Decode.string
        |> Decode.andThen
            (\reason ->
                case reason of
                    "no-github-package" ->
                        Decode.succeed ErrorNoGithubPackage

                    "package-renamed" ->
                        Decode.succeed ErrorPackageRenamed

                    "elm-json-invalid" ->
                        Decode.succeed (\errorMsg -> ErrorElmJsonInvalid errorMsg)
                            |> decodeAndMap (Decode.field "errorMsg" Decode.string)

                    "not-elm-package" ->
                        Decode.succeed ErrorNotElmPackage

                    "unsupported-elm-version" ->
                        Decode.succeed ErrorUnsupportedElmVersion

                    "compile-timeout" ->
                        Decode.succeed ErrorCompileTimeout

                    "compile-failed" ->
                        Decode.succeed
                            (\compilerVersion reportJson compileLogUrl jsonReportUrl archive ->
                                ErrorCompileFailed
                                    { compilerVersion = compilerVersion
                                    , reportJson = reportJson
                                    , compileLogUrl = compileLogUrl
                                    , jsonReportUrl = jsonReportUrl
                                    , archive = archive
                                    }
                            )
                            |> decodeAndMap (Decode.field "compilerVersion" Elm.Version.decoder)
                            |> decodeAndMap (Decode.field "reportJson" Decode.value)
                            |> decodeAndMap (Decode.field "compileLogUrl" decodeUrl)
                            |> decodeAndMap (Decode.field "jsonReportUrl" decodeUrl)
                            |> decodeAndMap archiveDecoder

                    "other" ->
                        Decode.succeed ErrorOther
                            |> decodeAndMap (Decode.field "errorMsg" Decode.string)

                    _ ->
                        Decode.fail "Unknown errorReason."
            )


archiveDecoder : Decoder Archive
archiveDecoder =
    Decode.succeed Archive
        |> decodeAndMap (Decode.field "url" decodeUrl)
        |> decodeAndMap (Decode.field "sha1ZipArchive" Decode.string)
        |> decodeAndMap (Decode.field "sha1PackageContents" Decode.string)


encodeKey : Key -> Value
encodeKey record =
    Encode.object
        [ ( "label", labelToString record.label |> Encode.string )
        , ( "seq", Encode.int record.seq )
        ]


getElmJson : Record -> Maybe Project
getElmJson record =
    case record.status of
        Ready { elmJson } ->
            Just elmJson

        _ ->
            Nothing


getArchive : Record -> Maybe Archive
getArchive record =
    case record.status of
        Ready { archive } ->
            Just archive

        Error { errorReason } ->
            case errorReason of
                ErrorCompileFailed { archive } ->
                    Just archive

                _ ->
                    Nothing



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
