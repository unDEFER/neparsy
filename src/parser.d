module parser;
import std.stdio;
import std.string;
import std.range;
import std.algorithm;
import styles.all;
import styles.common;
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

struct StateEntry
{
    Style style;
    size_t rule;
    size_t token;
    size_t number; // for repeating tokens
    char[][] tokens;
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
    size_t col; // current byte in line

    IndentedLine iline = lines[row];
    char[] lsplice = iline.line[col..$];

    for(Style s = Style.C; s < Style.Unknown; s++)
    {
        if (s !in styledefs) continue;
        if (!style_hypothesis[s]) continue;
        StyleDefinition styledef = styledefs[s];

        for(size_t r = 0; r < styledef.rules.length; r++)
        {
            Rule rule = styledef.rules[r];

            size_t t = 0;
            Token token = rule.tokens[t];
            size_t token_len;

            final switch(token.type)
            {
                case TokenType.Keyword:
                case TokenType.Symbol:
                    if ( lsplice.startsWith(token.name) )
                    {
                        token_len = token.name.length;
                    }
                    break;

                case TokenType.Type:
                case TokenType.Variable:
                case TokenType.Id:
                    char[] id = get_id(lsplice);
                    token_len = id.length;
                    break;

                case TokenType.Expression:
                    assert(false, "Expression parsing not implemented");
                    break;

                case TokenType.Statement:
                    assert(false, "Statement parsing not implemented");
                    break;

                case TokenType.TokenGroupBegin:
                    assert(false, "TokenGroupBegin parsing not implemented");
                    break;

                case TokenType.TokenGroupEnd:
                    assert(false, "TokenGroupEnd parsing not implemented");
                    break;
            }
                        
            if (token_len > 0)
            {
                new_state_candidates ~= StateEntry(s, r, t+1, 0, [lsplice[0..token_len]]);
            }
        }
    }

    writefln("new_state_candidates=%s", new_state_candidates);

    return 0;
}
