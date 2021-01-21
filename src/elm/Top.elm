module Top exposing (main)

-- Top level construction


main : Program () Model Msg
main =
    Platform.worker
        { init = \_ -> ( (), Cmd.none )
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


type alias Msg =
    Never


type alias Model =
    ()
