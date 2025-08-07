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

enum Rule ClikeEnum = Rule(RuleKind.Enum,
    [
        Token(TokenType.Keyword, "enum"),
        Token(TokenType.Id, "name"),
        Token(TokenType.Symbol, "{"),
        Token(TokenType.TokenGroupBegin, "values", StatementDelimiterType.Comma, 1),
        Token(TokenType.Id, "value_id"),
        Token(TokenType.TokenGroupBegin, null, StatementDelimiterType.None, 0, 1),
        Token(TokenType.Symbol, "="),
        Token(TokenType.Expression, "value"),
        Token(TokenType.TokenGroupEnd, null, StatementDelimiterType.None, 0, 1),
        Token(TokenType.TokenGroupEnd, "values", StatementDelimiterType.Comma, 1),
        Token(TokenType.Symbol, "}")
    ]);
