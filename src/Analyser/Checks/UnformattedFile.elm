module Analyser.Checks.UnformattedFile exposing (checker)

import Analyser.Checks.Base exposing (Checker)
import Analyser.Configuration exposing (Configuration)
import Analyser.FileContext exposing (FileContext)
import Analyser.Messages.Data as Data exposing (MessageData)
import Analyser.Messages.Schema as Schema


checker : Checker
checker =
    { check = scan
    , info =
        { key = "UnformattedFile"
        , name = "Unformatted File"
        , description = "File is not formatted correctly"
        , schema =
            Schema.schema
        }
    }


scan : FileContext -> Configuration -> List MessageData
scan fileContext _ =
    if fileContext.formatted then
        []
    else
        [ Data.init "Unformatted file" ]
