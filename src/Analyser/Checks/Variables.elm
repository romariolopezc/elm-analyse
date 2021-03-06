module Analyser.Checks.Variables exposing (UsedVariableContext, collect, unusedTopLevels, unusedVariables)

import ASTUtil.Inspector as Inspector exposing (Order(Inner, Post, Pre), defaultConfig)
import ASTUtil.Variables exposing (VariableType(Pattern), getLetDeclarationsVars, getTopLevels, patternToUsedVars, patternToVars, patternToVarsInner, withoutTopLevel)
import Analyser.FileContext exposing (FileContext)
import Dict exposing (Dict)
import Elm.Syntax.Base exposing (VariablePointer)
import Elm.Syntax.Expression exposing (Case, Expression(..), Function, Lambda, LetBlock, RecordUpdate)
import Elm.Syntax.File exposing (File)
import Elm.Syntax.Infix exposing (InfixDirection)
import Elm.Syntax.Pattern exposing (Pattern(..))
import Elm.Syntax.Range exposing (Range)
import Elm.Syntax.Ranged exposing (Ranged)
import Elm.Syntax.TypeAnnotation exposing (TypeAnnotation(Typed))
import Tuple3


type alias Scope =
    Dict String ( Int, VariableType, Range )


type alias ActiveScope =
    ( List String, Scope )


type UsedVariableContext
    = UsedVariableContext InneUsedVariableContext


type alias InneUsedVariableContext =
    { poppedScopes : List Scope
    , activeScopes : List ActiveScope
    }


unusedVariables : UsedVariableContext -> List ( String, VariableType, Range )
unusedVariables (UsedVariableContext x) =
    x.poppedScopes
        |> List.concatMap Dict.toList
        |> onlyUnused
        |> List.map (\( a, ( _, c, d ) ) -> ( a, c, d ))


unusedTopLevels : UsedVariableContext -> List ( String, VariableType, Range )
unusedTopLevels (UsedVariableContext x) =
    x.activeScopes
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault Dict.empty
        |> Dict.toList
        |> onlyUnused
        |> List.map (\( a, ( _, c, d ) ) -> ( a, c, d ))


onlyUnused : List ( String, ( Int, VariableType, Range ) ) -> List ( String, ( Int, VariableType, Range ) )
onlyUnused =
    List.filter (Tuple.second >> Tuple3.first >> (==) 0)


collect : FileContext -> UsedVariableContext
collect fileContext =
    UsedVariableContext <|
        Inspector.inspect
            { defaultConfig
                | onFile = Pre onFile
                , onFunction = Inner onFunction
                , onLetBlock = Inner onLetBlock
                , onLambda = Inner onLambda
                , onCase = Inner onCase
                , onOperatorApplication = Post onOperatorAppliction
                , onDestructuring = Post onDestructuring
                , onFunctionOrValue = Post onFunctionOrValue
                , onPrefixOperator = Post onPrefixOperator
                , onRecordUpdate = Post onRecordUpdate
                , onTypeAnnotation = Post onTypeAnnotation
            }
            fileContext.ast
            emptyContext


emptyContext : InneUsedVariableContext
emptyContext =
    { poppedScopes = [], activeScopes = [] }


addUsedVariable : String -> InneUsedVariableContext -> InneUsedVariableContext
addUsedVariable x context =
    { context | activeScopes = flagVariable x context.activeScopes }


popScope : InneUsedVariableContext -> InneUsedVariableContext
popScope x =
    { x
        | activeScopes = List.drop 1 x.activeScopes
        , poppedScopes =
            List.head x.activeScopes
                |> Maybe.map
                    (\( _, activeScope ) ->
                        if Dict.isEmpty activeScope then
                            x.poppedScopes
                        else
                            activeScope :: x.poppedScopes
                    )
                |> Maybe.withDefault x.poppedScopes
    }


pushScope : List ( VariablePointer, VariableType ) -> InneUsedVariableContext -> InneUsedVariableContext
pushScope vars x =
    let
        y : ActiveScope
        y =
            vars
                |> List.map (\( z, t ) -> ( z.value, ( 0, t, z.range ) ))
                |> Dict.fromList
                |> (,) []
    in
    { x | activeScopes = y :: x.activeScopes }


unMaskVariable : String -> InneUsedVariableContext -> InneUsedVariableContext
unMaskVariable k context =
    { context
        | activeScopes =
            case context.activeScopes of
                [] ->
                    []

                ( masked, vs ) :: xs ->
                    ( List.filter ((/=) k) masked, vs ) :: xs
    }


maskVariable : String -> InneUsedVariableContext -> InneUsedVariableContext
maskVariable k context =
    { context
        | activeScopes =
            case context.activeScopes of
                [] ->
                    []

                ( masked, vs ) :: xs ->
                    ( k :: masked, vs ) :: xs
    }


flagVariable : String -> List ActiveScope -> List ActiveScope
flagVariable k l =
    case l of
        [] ->
            []

        ( masked, x ) :: xs ->
            if List.member k masked then
                ( masked, x ) :: xs
            else if Dict.member k x then
                ( masked, Dict.update k (Maybe.map (Tuple3.mapFirst ((+) 1))) x ) :: xs
            else
                ( masked, x ) :: flagVariable k xs


onFunctionOrValue : String -> InneUsedVariableContext -> InneUsedVariableContext
onFunctionOrValue x context =
    addUsedVariable x context


onPrefixOperator : String -> InneUsedVariableContext -> InneUsedVariableContext
onPrefixOperator prefixOperator context =
    addUsedVariable prefixOperator context


onRecordUpdate : RecordUpdate -> InneUsedVariableContext -> InneUsedVariableContext
onRecordUpdate recordUpdate context =
    addUsedVariable recordUpdate.name context


onOperatorAppliction : ( String, InfixDirection, Ranged Expression, Ranged Expression ) -> InneUsedVariableContext -> InneUsedVariableContext
onOperatorAppliction ( op, _, _, _ ) context =
    addUsedVariable op context


onFile : File -> InneUsedVariableContext -> InneUsedVariableContext
onFile file context =
    getTopLevels file
        |> flip pushScope context


onFunction : (InneUsedVariableContext -> InneUsedVariableContext) -> Function -> InneUsedVariableContext -> InneUsedVariableContext
onFunction f function context =
    let
        used =
            List.concatMap patternToUsedVars function.declaration.arguments
                |> List.map .value

        postContext =
            context
                |> maskVariable function.declaration.name.value
                |> (\c ->
                        function.declaration.arguments
                            |> List.concatMap patternToVars
                            |> flip pushScope c
                            |> f
                            |> popScope
                            |> unMaskVariable function.declaration.name.value
                   )
    in
    List.foldl addUsedVariable postContext used


onLambda : (InneUsedVariableContext -> InneUsedVariableContext) -> Lambda -> InneUsedVariableContext -> InneUsedVariableContext
onLambda f lambda context =
    let
        preContext =
            lambda.args
                |> List.concatMap patternToVars
                |> flip pushScope context

        postContext =
            f preContext
    in
    postContext |> popScope


onLetBlock : (InneUsedVariableContext -> InneUsedVariableContext) -> LetBlock -> InneUsedVariableContext -> InneUsedVariableContext
onLetBlock f letBlock context =
    letBlock.declarations
        |> (getLetDeclarationsVars >> withoutTopLevel)
        |> flip pushScope context
        |> f
        |> popScope


onDestructuring : ( Ranged Pattern, Ranged Expression ) -> InneUsedVariableContext -> InneUsedVariableContext
onDestructuring ( pattern, _ ) context =
    List.foldl addUsedVariable
        context
        (List.map .value (patternToUsedVars pattern))


onCase : (InneUsedVariableContext -> InneUsedVariableContext) -> Case -> InneUsedVariableContext -> InneUsedVariableContext
onCase f caze context =
    let
        used =
            patternToUsedVars (Tuple.first caze) |> List.map .value

        postContext =
            Tuple.first caze
                |> patternToVarsInner False
                |> flip pushScope context
                |> f
                |> popScope
    in
    List.foldl addUsedVariable postContext used


onTypeAnnotation : Ranged TypeAnnotation -> InneUsedVariableContext -> InneUsedVariableContext
onTypeAnnotation ( _, t ) c =
    case t of
        Typed [] name _ ->
            addUsedVariable name c

        _ ->
            c
