module Packages.RootSite exposing
    ( fetchAllPackages
    , fetchAllPackagesSince
    , fetchElmJson
    , fetchEndpointJson
    )

import Http
import Json.Decode as Decode


packageUrl : String
packageUrl =
    "https://package.elm-lang.org/"


fetchAllPackages : (Result Http.Error Decode.Value -> msg) -> Cmd msg
fetchAllPackages tagger =
    Http.get
        { url = packageUrl ++ "all-packages/"
        , expect = Http.expectJson tagger Decode.value
        }


fetchAllPackagesSince : (Result Http.Error Decode.Value -> msg) -> Int -> Cmd msg
fetchAllPackagesSince tagger since =
    Http.post
        { url = packageUrl ++ "all-packages/since/" ++ String.fromInt since
        , expect = Http.expectJson tagger Decode.value
        , body = Http.emptyBody
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
