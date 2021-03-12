module DB.BuildStatus.ByFQPackageIndex exposing (Key, encodeKey)

import DB.BuildStatus.Table
import Json.Encode as Encode exposing (Value)
import Elm.FQPackage as FQPackage exposing (FQPackage)


type alias Key =
    { fqPackage : FQPackage
    }


encodeKey : Key -> Value
encodeKey key =
    Encode.object [ ( "fqPackage", FQPackage.encode key.fqPackage ) ]
