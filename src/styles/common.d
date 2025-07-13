module styles.common;

import std.bitmanip;
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

enum RuleKind
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
    RuleKind kind;
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

struct TextSpan
{
    string begin;
    string end;
    string escape;
    bool nesting;
}

enum CommentType
{
    COneLine,
    CMultiLine,
}

enum TextSpan[] comments =
[
    TextSpan("//", "\n", null, false),
    TextSpan("/*", "*/", null, false),
];

enum StringLiteralType
{
    DoubleQuotes,
}

enum TextSpan[] string_literals =
[
    TextSpan("\"", "\"", "\\", false),
];

enum ArgumentDelimiterType
{
    Comma
}

enum string[] argument_delimiters = [","];

enum StatementDelimiterType
{
    Semicolon
}

enum string[] statement_delimiters = [";"];

struct StatementBrackets
{
    string begin;
    string end;
}

enum StatementBracketType
{
    C,
    Pascal
}

enum StatementBrackets[] statement_brackets =
[
    StatementBrackets("{","}"),
    StatementBrackets("begin","end"),
];

enum FieldAccessSymbolType
{
    Dot,
    CArrow,
}

enum string[] field_access_symbols = [".", "->"];

enum RuleType
{
    ClikeFor,
    DModule
}

struct StyleDefinition
{
    Style style;
    RuleType[] rules;
    TypeMapEntry[] typemap;
    OperatorMapEntry[] opmap;
    OperatorPrecedenceEntry[] opprec;
    CommentType[] comments;
    StringLiteralType[] string_literals;
    ArgumentDelimiterType[] argument_delimiters;
    StatementDelimiterType[] statement_delimiters;
    StatementBracketType[] statement_brackets;
    FieldAccessSymbolType[] field_access_symbols;

    StyleBitmaps maps;

    bool disabled;
}

struct StyleBitmaps
{
    BitArray rules;
    BitArray comments;
    BitArray string_literals;
    BitArray argument_delimiters;
    BitArray statement_delimiters;
    BitArray statement_brackets;
    BitArray field_access_symbols;
}
