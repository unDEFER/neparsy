module styles.d;

import std.variant;
import styles.common;
import common;

enum Rule DModule = Rule(RuleKind.Module,
    [
        Token(TokenType.Keyword, "module"),
        Token(TokenType.Id, "name"),
    ]);

enum Rule DImport = Rule(RuleKind.Import,
    [
        Token(TokenType.Keyword, "import"),
        Token(TokenType.TokenGroupBegin, "module", StatementDelimiterType.Dot, 1),
        Token(TokenType.Id, "id"),
        Token(TokenType.TokenGroupEnd, "module", StatementDelimiterType.Dot, 1),
        Token(TokenType.TokenGroupBegin, null, StatementDelimiterType.None, 0, 1),
        Token(TokenType.Symbol, ":"),
        Token(TokenType.TokenGroupBegin, "imported_ids", StatementDelimiterType.Comma, 1),
        Token(TokenType.Id, "id"),
        Token(TokenType.TokenGroupEnd, "imported_ids", StatementDelimiterType.Comma, 1),
        Token(TokenType.TokenGroupEnd, null, StatementDelimiterType.None, 0, 1),
    ]);

shared StyleDefinition DDefinition = StyleDefinition(Style.D,
[
    RuleType.DModule,
    RuleType.DImport,
    RuleType.ClikeFor,
    RuleType.ClikeEnum,
],
[
    TypeMapEntry("short", NikaType.Number,
                ["range_min": "-32768",
                 "range_max": "32767",
                 "base": "10",
                 "point": "0",
                 "overflow": "error"]),

    TypeMapEntry("float", NikaType.Scalar,
                ["base": "2",
                 "precision": "23",
                 "exp_min": "-126",
                 "exp_max": "127",
                 "denormalization": "true"]),

    TypeMapEntry("double", NikaType.Scalar,
                ["base": "2",
                 "precision": "52",
                 "exp_min": "-1022",
                 "exp_max": "1023",
                 "denormalization": "true"])
],
[
    OperatorMapEntry("+", "+")
],
[
    OperatorPrecedenceEntry("+", Arity.Binary, Associativity.Left, 0)
],
[CommentType.COneLine, CommentType.CMultiLine, CommentType.DMultiLine],
[StringLiteralType.DoubleQuotes],
[StatementDelimiterType.Semicolon],
[StatementBracketType.C],
[FieldAccessSymbolType.Dot]);
