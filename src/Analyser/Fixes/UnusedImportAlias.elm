module Analyser.Fixes.UnusedImportAlias exposing (fixer)

import ASTUtil.Imports as Imports
import Analyser.Checks.UnusedImportAlias as UnusedImportAliasCheck
import Analyser.Fixes.Base exposing (Fixer, Patch(..))
import Analyser.Fixes.FileContent as FileContent
import Analyser.Messages.Data as Data exposing (MessageData)
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Module exposing (Import, Module(..))
import Elm.Syntax.Range as Syntax exposing (Range)


fixer : Fixer
fixer =
    Fixer (.key <| .info <| UnusedImportAliasCheck.checker) fix "Remove alias and format"


fix : ( String, File ) -> MessageData -> Patch
fix input messageData =
    case Data.getRange "range" messageData of
        Just range ->
            updateImport input range

        Nothing ->
            IncompatibleData


updateImport : ( String, File ) -> Range -> Patch
updateImport ( content, ast ) range =
    case Imports.findImportWithRange ast range of
        Just imp ->
            Patched (writeNewImport imp.range { imp | moduleAlias = Nothing } content)

        Nothing ->
            Error "Could not locate import for the target range"


writeNewImport : Syntax.Range -> Import -> String -> String
writeNewImport syntaxRange imp i =
    FileContent.replaceLines
        ( syntaxRange.start.row, syntaxRange.end.row )
        (Imports.naiveStringifyImport imp)
        i
