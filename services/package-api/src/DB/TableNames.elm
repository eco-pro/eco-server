module DB.TableNames exposing (fqTableName)

import Packages.Config exposing (Config)
import Serverless.Conn exposing (Conn)


fqTableName : String -> Conn Config model route msg -> String
fqTableName name conn =
    (Serverless.Conn.config conn).dynamoDbNamespace ++ "-" ++ name
