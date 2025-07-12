module styles.common;

import common;

enum TokenType
{
    Keyword,
    Type,
    Variable,
    Expression,
    Statement,
    Id, // not Type, not Variable, not Keyword, but what ???
    Symbol,
    TokenGroupBegin,
    TokenGroupEnd
}

struct Token
{
    TokenType type;
    string name;
    string separator;
    int mincount;
    int maxcount;
}

enum RuleType
{
    For,
    Foreach,
    While,
    DoWhile,
    Enum,
    Function,
    IfElse,
    Module
}

struct Rule
{
    RuleType type;
    Token[] tokens;
}

enum NikaType
{
    Number,
    Scalar,
    Array,
    Struct,
    Pack,
    Link,
    StrongLink,
    TreeEdge,
    GraphEdge,
    Vector,
    Matrix,
    Function,
    Delegate
}

struct TypeMapEntry
{
    string langType;
    NikaType nikaType;
    string[string] params; 
}

struct OperatorMapEntry
{
    string langOp;
    string nikaOp;
}

enum Arity
{
    Unary,
    Binary,
    Ternary
}

enum Associativity
{
    Left,
    Right,
    None
}

struct OperatorPrecedenceEntry
{
    string op;
    Arity arity;
    Associativity assoc;
    int priority;
    string pair;
}

struct StyleDefinition
{
    Style style;
    Rule[] rules;
    TypeMapEntry[] typemap;
    OperatorMapEntry[] opmap;
    OperatorPrecedenceEntry[] opprec;
    bool disabled;
}
