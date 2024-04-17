module parsing.treegen.astTypes;
import parsing.tokenizer.tokens : Token;
import tern.typecons.common : Nullable, nullable;

struct NameUnit
{
    dchar[][] names;
}

enum AstAction
{
    Keyword,                 // Standalong keywords Ex: import std.std.io;
    Scope,
    DefineFunction,
    DefineVariable,          // Ex: int x;
    AssignVariable,          // Ex: x = 5;
    
    SingleArgumentOperation, // Ex: x++, ++x, |x|, ||x||, -8
    DoubleArgumentOperation, // Ex: 9+10 

    Call,                    // Ex: foo(bar);

    Expression,              // Ex: (4+5*9)
    NamedUnit,               // Ex: std.io
    LiteralUnit,             // Ex: 6, 6L, "Hello world"

    TokenHolder              // A temporary Node that is yet to be parsed 
}

struct KeywordNodeData
{
    dchar[] keywordName;
    Token[] keywardArgs;
}

struct DefineFunctionNodeData
{
    dchar[][] precedingKeywords;
    dchar[][] suffixKeywords;
    NameUnit returnType;
    AstNode* functionScope;
}

struct DefineVariableNodeData
{
    dchar[][] precedingKeywords;
    NameUnit returnType;
    AstNode[] functionScope;
}
struct AssignVariableNodeData
{
    NameUnit[] name; // Name of variable(s) to assign Ex: x = y = z = 5;
    AstNode* value;
}

enum OperationVariety
{
    Increment,
    Decrement,
    AbsuluteValue,
    Magnitude,

    Add,
    Substract,
    Multiply,
    Divide,
    Mod,
    Pipe,

    BitwiseOr,
    BitwiseXor,
    BitwiseAnd,
    BitshiftLeft,
    BitshiftRight
}
struct SingleArgumentOperationNodeData
{
    OperationVariety pperationVariety;
    AstNode* value;
}
struct DoubleArgumentOperationNodeData
{
    OperationVariety pperationVariety;
    AstNode* left;
    AstNode* right;
}
struct CallNodeData
{
    NameUnit func;
    AstNode* args;
}

struct AstNode
{
    AstAction action;
    union
    {
        KeywordNodeData        keywordNodeData;        // Keyword
        AstNode[]              scopeContents;          // Scope
        DefineFunctionNodeData defineFunctionNodeData; // DefineFunction
        DefineVariableNodeData defineVariableNodeData; // DefineVariable
        AssignVariableNodeData assignVariableNodeData; // AssignVariable

        SingleArgumentOperationNodeData singleArgumentOperationNodeData; // SingleArgumentOperation
        DoubleArgumentOperationNodeData doubleArgumentOperationNodeData; // DoubleArgumentOperation
        CallNodeData           callNodeData;           // Call
        AstNode[]              expressionComponents;   // Expression
        NameUnit               namedUnit;              // NamedUnit
        Token[]                literalUnitCompenents;  // LiteralUnit
        Token                  tokenBeingHeld;         // TokenHolder
    }
}
