module styles.common;

import common;

enum TokenType
{
    Keyword,
    Type,
    Variable,
    Expression,
    Statement,
    Id,
    Symbol
}

struct Token
{
    TokenType type;
    string name;
    string separator;
}

struct Rule
{
    string type;
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

struct StyleDefinition
{
    Style style;
    Rule[] rules;
    TypeMapEntry[] typemap;
    OperatorMapEntry[] opmap;
    bool disabled;
}

StyleDefinition[Style] styledefs;
