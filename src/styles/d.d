module styles.d;

import std.variant;
import styles.common;
import common;

enum ClikeRules = 
[
    Rule("for",
    [
        Token(TokenType.Keyword, "for"),
        Token(TokenType.Symbol, "("),
        Token(TokenType.Expression, "init"),
        Token(TokenType.Symbol, ";"),
        Token(TokenType.Expression, "cond"),
        Token(TokenType.Symbol, ";"),
        Token(TokenType.Expression, "incr"),
        Token(TokenType.Symbol, ")"),
        Token(TokenType.Statement, "body"),
    ])
];

enum DDefinition = StyleDefinition(Style.D,
    ClikeRules,
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
]);
