port module Packages.Dynamo exposing (dynamoOk, upsertPackageSeq)

import Json.Encode as JE
import Serverless


port upsertPackageSeq : Serverless.InteropRequestPort () msg


port dynamoOk : Serverless.InteropResponsePort msg
