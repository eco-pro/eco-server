module Packages.FQPackage exposing
    ( FQPackage
    , decoder
    , encode
    , fromString
    , toString
    )

import Elm.Package exposing (Name)
import Elm.Version exposing (Version)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


type alias FQPackage =
    { name : Elm.Package.Name
    , version : Elm.Version.Version
    }


fromString : String -> Maybe FQPackage
fromString string =
    case String.split "@" string of
        [ nameStr, versionStr ] ->
            case ( Elm.Package.fromString nameStr, Elm.Version.fromString versionStr ) of
                ( Just name, Just version ) ->
                    { name = name
                    , version = version
                    }
                        |> Just

                _ ->
                    Nothing

        _ ->
            Nothing


toString : FQPackage -> String
toString fqPackage =
    Elm.Package.toString fqPackage.name
        ++ "@"
        ++ Elm.Version.toString fqPackage.version


{-| Turn a `Name` into a string for use in `elm.json`
-}
encode : FQPackage -> Encode.Value
encode name =
    Encode.string (toString name)


{-| Decode the module name strings that appear in `elm.json`
-}
decoder : Decoder FQPackage
decoder =
    Decode.andThen decoderHelp Decode.string


decoderHelp : String -> Decoder FQPackage
decoderHelp string =
    case fromString string of
        Just fqPackage ->
            Decode.succeed fqPackage

        Nothing ->
            Decode.fail "I need a valid package name and version like \"elm/core@1.0.0\""
