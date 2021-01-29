module Packages.Interop exposing (Model, lift)


type alias Interop innerMsg msg =
    { seqNo : Int
    , context : Dict Int (Value -> innerMsg)
    , create : (innerMsg -> msg) -> (Value -> innerMsg) -> Model innerMsg msg -> ( Int, Model innerMsg msg )
    , consume : Int -> Model innerMsg msg -> ( Maybe (Value -> msg), Model innerMsg msg )
    }


lift : (a -> b) -> Interop innerMsg a -> Interop innerMsg b
lift fn model =
    { seqNo = model.seqNo
    , context = model.context
    , create = ()
    , consume = ()
    }
