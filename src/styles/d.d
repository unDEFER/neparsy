module styles.d;

import std.variant;
import styles.common;
import common;

StyleDefinition DDefinition = StyleDefinition(Style.D,
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
                 "point_min": "-128",
                 "point_max": "127"])
]);
