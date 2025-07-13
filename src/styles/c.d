module styles.c;

import styles.common;

enum ClikeFor = 
    Rule(RuleKind.For,
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
    ]);

