module Parser.Types exposing (..)


type State
    = State (List Int)


emptyState : State
emptyState =
    State []


currentIndent : State -> Int
currentIndent (State xs) =
    List.head xs |> Maybe.withDefault 0


popIndent : State -> State
popIndent (State s) =
    State <| List.drop 1 s


pushIndent : Int -> State -> State
pushIndent x (State s) =
    State (x :: s)



-- AST


type alias File =
    { moduleDefinition : Module
    , imports : List Import
    , declarations : List Declaration
    }


type Module
    = NormalModule DefaultModuleData
    | PortModule DefaultModuleData
    | EffectModule EffectModuleData
    | NoModule


type alias DefaultModuleData =
    { moduleName : ModuleName
    , exposingList : Exposure Expose
    }


type alias EffectModuleData =
    { moduleName : ModuleName
    , exposingList : Exposure Expose
    , command : Maybe String
    , subscription : Maybe String
    }


type alias ModuleName =
    List String


type Declaration
    = FuncDecl Function
    | AliasDecl TypeAlias
    | TypeDecl Type
    | PortDeclaration FunctionSignature
    | InfixDeclaration Infix
    | Destructuring Pattern Expression


type InfixDirection
    = Left
    | Right


type alias Infix =
    { direction : InfixDirection, precedence : Int, operator : String }


type alias DocumentationComment =
    String


type Pattern
    = AllPattern
    | UnitPattern
    | CharPattern Char
    | StringPattern String
    | IntPattern Int
    | FloatPattern Float
    | TuplePattern (List Pattern)
    | RecordPattern (List String)
    | UnConsPattern Pattern Pattern
    | ListPattern (List Pattern)
    | VarPattern String
    | NamedPattern QualifiedNameRef (List Pattern)
    | QualifiedNamePattern QualifiedNameRef
    | AsPattern Pattern String
    | ParentisizedPattern Pattern


type QualifiedNameRef
    = QualifiedNameRef (List String) String



-- Functions


type alias FunctionSignature =
    { operatorDefinition : Bool
    , name : String
    , typeReference : TypeReference
    }


type alias FunctionDeclaration =
    { operatorDefinition : Bool
    , name : String
    , arguments : List Pattern
    , expression : Expression
    }


type alias Function =
    { documentation : Maybe DocumentationComment
    , signature : Maybe FunctionSignature
    , declaration : FunctionDeclaration
    }



-- Expressions


type Expression
    = UnitExpr
    | Application (List Expression)
    | OperatorApplication InfixDirection Expression Expression
    | FunctionOrValue String
    | IfBlock Expression Expression Expression
    | PrefixOperator String
    | Operator String
    | Integer Int
    | Floatable Float
    | Literal String
    | CharLiteral Char
    | TupledExpression (List Expression)
    | Parentesized Expression
    | LetBlock (List Declaration) Expression
    | CaseBlock Expression Cases
    | Lambda (List Pattern) Expression
    | RecordExpr (List ( String, Expression ))
    | ListExpr (List Expression)
    | QualifiedExpr ModuleName String
    | RecordAccess (List String)
    | RecordAccessFunction String
    | RecordUpdate String (List ( String, Expression ))
    | GLSLExpression String


type alias Case =
    ( Pattern, Expression )


type alias Cases =
    List Case



-- Type Referencing


type alias TypeAlias =
    { name : String, generics : List String, typeReference : TypeReference }


type alias Type =
    { name : String
    , generics : List String
    , cases : List ValueConstructor
    }


type alias ValueConstructor =
    { name : String
    , arguments : List TypeReference
    }


type TypeArg
    = Generic String
    | Concrete TypeReference


type TypeReference
    = GenericType String
    | Typed (List String) String (List TypeArg)
    | Unit
    | Tupled (List TypeReference)
    | Record RecordDefinition
    | GenericRecord String RecordDefinition
    | FunctionTypeReference TypeReference TypeReference


type alias RecordDefinition =
    { fields : List RecordField }


type alias RecordField =
    ( String, TypeReference )



-- Import


type alias Import =
    { moduleName : ModuleName, moduleAlias : Maybe ModuleName, exposingList : Exposure Expose }



-- Exposing


type Exposure a
    = None
    | All
    | Explicit (List a)


type ExposeList inner
    = ExposeAny
    | Specified (List inner)


type Expose
    = InfixExpose String
    | DefinitionExpose String
    | TypeExpose String (Exposure String)


type alias ExposeAny =
    ()