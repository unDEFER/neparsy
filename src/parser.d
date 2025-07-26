module parser;
import std.stdio;
import std.string;
import std.range;
import std.algorithm;
import styles.all;
import styles.common;
import styles.bitmaps;
import std.bitmanip;
import std.uni;
import common;

struct IndentedLine
{
    int level; // for using in Python-style
    char[] line;
}

// return number characters to skip
int get_num_spaces(char[] line)
{
    return line.startsWith("    ") ? 4 : line.startsWith("\t") ? 1 : 0;
}

char[] get_id(char[] line)
{
    if (line.length == 0 || !isAlpha(line[0])) return null;

    for (size_t i=1; i < line.length; i++)
    {
        if (!isAlphaNum(line[i])) return line[0..i];
    }

    return line;
}

char[] get_token(char[] lsplice, Token token, size_t t)
{
    if (lsplice.length == 0) return null;

    char[] token_string;

    final switch(token.type)
    {
        case TokenType.Keyword:
        case TokenType.Symbol:
            if ( lsplice.startsWith(token.name) )
            {
                token_string = lsplice[0..token.name.length];
            }
            break;

        case TokenType.Type:
        case TokenType.Variable:
        case TokenType.Id:
            token_string = get_id(lsplice);
            break;

        case TokenType.Expression:
            assert(t == 0, "Expression parsing not implemented");
            break;

        case TokenType.Statement:
            assert(t == 0, "Statement parsing not implemented");
            break;

        case TokenType.TokenGroupBegin:
            assert(t == 0, "TokenGroupBegin parsing not implemented");
            break;

        case TokenType.TokenGroupEnd:
            assert(t == 0, "TokenGroupEnd parsing not implemented");
            break;
    }

    return token_string;
}

IndentedLine parseIndent(char[] line)
{
    IndentedLine il;

    int num_spaces;
    while ((num_spaces = get_num_spaces(line)) > 0)
    {
        il.level++;
        line = line[num_spaces..$];
    }

    il.line = strip(line).dup();
    return il;
}

bool check_eof(ref char[] lsplice, IndentedLine[] lines, size_t row)
{
    while (lsplice.empty)
    {
        if (row >= lines.length)
            return true;
        lsplice = lines[++row].line;
    }

    return false;
}

struct StateEntry
{
    size_t rule;
    size_t token;
    size_t number; // for repeating tokens
    char[][] tokens;
    char[] rest_of_line;
    size_t row;
}

StateEntry[] state;
StateEntry[] new_state_candidates;

int convert2neparsy(string input, string output, Style style)
{
    bool[] styles = new bool[cast(size_t) Style.Unknown];

    if (style == Style.Unknown)
        styles[0..$] = true;
    else
        styles[style] = true;

    BitArray style_hypothesis = BitArray(styles);

    auto file = File(input); // Open for reading
    auto lines = file.byLine()            // Read lines
                 .map!parseIndent().array;

    StateEntry[] state;

    size_t row; // current line
    char[] lsplice = lines[row].line;
    StateEntry statement;
    StateEntry[] state_candidates_update;

    for(size_t r = 0; r < rules.length; r++)
    {
        if ((style_hypothesis & style_rules[r]).bitsSet.empty) continue;
        Rule rule = rules[r];

        size_t t = 0;
        Token token = rule.tokens[t];
        if (check_eof(lsplice, lines, row)) continue;
        char[] token_string = get_token(lsplice, token, t);

        if (!token_string.empty)
        {
            auto se = StateEntry(r, t+1, 0, [token_string], strip(lsplice[token_string.length..$]), row);
            if (se.token >= rule.tokens.length)
            {
                statement = se;
                goto StatementEnded;
            }
            new_state_candidates ~= se;
        }
    }

    while (!new_state_candidates.empty)
    {
        foreach(ref nsc; new_state_candidates)
        {
            Rule rule = rules[nsc.rule];

            lsplice = nsc.rest_of_line;
            row = nsc.row;
            size_t t = nsc.token;
            Token token = rule.tokens[t];
            if (check_eof(lsplice, lines, row)) continue;
            char[] token_string = get_token(lsplice, token, t);

            if (!token_string.empty)
            {
                nsc.token++;
                nsc.tokens ~= token_string;
                nsc.rest_of_line = strip(lsplice[token_string.length..$]);
                nsc.row = row;
                state_candidates_update ~= nsc;

                if (nsc.token >= rule.tokens.length)
                {
                    statement = nsc;
                    goto StatementEnded;
                }
            }
        }

        swap(state_candidates_update, new_state_candidates);
        state_candidates_update.length = 0;
    }

    assert(false, "Statement not parsed");

StatementEnded:
    
    style_hypothesis &= style_rules[statement.rule];
    writefln("parsed statement=%s, style_hypothesis=%s", statement, style_hypothesis);

    bool[] delimiters = new bool[statement_delimiters.length];
    delimiters[0..$] = true;
    BitArray delimiter_hypothesis = BitArray(delimiters);

    foreach(s; style_hypothesis.bitsSet)
    {
        shared StyleDefinition* sd = styledefs[cast(Style) s];
        delimiter_hypothesis &= cast() sd.maps.statement_delimiters;
    }

    string delimiter;
    foreach(d; delimiter_hypothesis.bitsSet)
    {
        lsplice = statement.rest_of_line;
        row = statement.row;
        if (check_eof(lsplice, lines, row)) continue;

        delimiter = statement_delimiters[d];
        if ( lsplice.startsWith(delimiter) )
        {
            lsplice = strip(lsplice[delimiter.length..$]);
            break;
        }
        delimiter = null;
    }

    if (!delimiter.empty)
    {
        writefln("Statement delimiter '%s' consumed successfully", delimiter);
    }

    return 0;
}
