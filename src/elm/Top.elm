port module Top exposing (main)

-- Top level construction


main : Program () Model Msg
main =
    Platform.worker
        { init = \_ -> ()
        , update = \model _ -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


type alias Msg =
    Never


type alias Model =
    ()
