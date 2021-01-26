module Packages.RootSite exposing
    ( fetchAllPackages
    , fetchAllPackagesSince
    , fetchElmJson
    , fetchEndpointJson
    )

import Http exposing (Response)
import Json.Decode as Decode exposing (Decoder)
import Packages.FQPackage as FQPackage exposing (FQPackage)
import Task exposing (Task)


packageUrl : String
packageUrl =
    "https://package.elm-lang.org/"


fetchAllPackages : (Result Http.Error Decode.Value -> msg) -> Cmd msg
fetchAllPackages tagger =
    Http.get
        { url = packageUrl ++ "all-packages/"
        , expect = Http.expectJson tagger Decode.value
        }


fetchAllPackagesSince : Int -> Task Http.Error (List FQPackage)
fetchAllPackagesSince since =
    Http.task
        { method = "POST"
        , headers = []
        , url = packageUrl ++ "all-packages/since/" ++ String.fromInt since
        , body = Http.emptyBody
        , resolver = jsonResolver (Decode.list FQPackage.decoder)
        , timeout = Nothing
        }


fetchElmJson : (Result Http.Error Decode.Value -> msg) -> String -> String -> String -> Cmd msg
fetchElmJson tagger author name version =
    Http.get
        { url = packageUrl ++ "packages/" ++ author ++ "/" ++ name ++ "/" ++ version ++ "/elm.json"
        , expect = Http.expectJson tagger Decode.value
        }


fetchEndpointJson : (Result Http.Error Decode.Value -> msg) -> String -> String -> String -> Cmd msg
fetchEndpointJson tagger author name version =
    Http.get
        { url = packageUrl ++ "packages/" ++ author ++ "/" ++ name ++ "/" ++ version ++ "/endpoint.json"
        , expect = Http.expectJson tagger Decode.value
        }



-- Helpers


jsonResolver : Decoder a -> Http.Resolver Http.Error a
jsonResolver decoder =
    let
        decodeResponse response =
            case response of
                Http.BadUrl_ url ->
                    Err (Http.BadUrl url)

                Http.Timeout_ ->
                    Err Http.Timeout

                Http.NetworkError_ ->
                    Err Http.NetworkError

                Http.BadStatus_ metadata body ->
                    Err (Http.BadStatus metadata.statusCode)

                Http.GoodStatus_ metadata body ->
                    case Decode.decodeString decoder body of
                        Ok value ->
                            Ok value

                        Err err ->
                            Err (Http.BadBody (Decode.errorToString err))
    in
    decodeResponse |> Http.stringResolver
