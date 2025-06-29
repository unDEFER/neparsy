module parser;
import std.stdio;
import std.string;
import std.range;
import std.algorithm;
import styles.all;
import styles.common;
import std.bitmanip;
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

IndentedLine parseIndent(char[] line)
{
    IndentedLine il;

    int num_spaces;
    while ((num_spaces = get_num_spaces(line)) > 0)
    {
        il.level++;
        line = line[num_spaces..$];
    }

    il.line = strip(line);
    return il;
}

struct StateEntry
{
    Style style;
    size_t rule;
    size_t token;
    size_t number; // for repeating tokens
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

            switch(token.type)
            {
                case TokenType.Keyword:
                case TokenType.Symbol:
                    
                    if ( lsplice.startsWith(token.name) )
                    {
                        //StateEntry(s, r, t);
                    }

                    break;
                default:
                    break;
            }
        }
    }

    return 0;
}
