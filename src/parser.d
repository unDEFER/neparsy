module parser;
import std.stdio;
import std.string;
import std.algorithm;
import styles.common;
import common;

struct IndentedLine
{
    int level;
    char[] line;
}

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
    size_t number;
}

int convert2neparsy(string input, string output, Style style)
{
    auto file = File(input); // Open for reading
    auto lines = file.byLine()            // Read lines
                 .map!parseIndent();

    writefln("%s", lines);

    StateEntry[] state;

    for(Style s = Style.Unknown; s < Style.LastStyle; s++)
    {
        if (s !in styledefs) continue;
        StyleDefinition styledef = styledefs[s];

        for(size_t r = 0; r < styledef.rules.length; r++)
        {
            Rule rule = styledef.rules[r];

            for(size_t t = 0; t < rule.tokens.length; t++)
            {
                Token token = rule.tokens[t];
            }
        }
    }

    return 0;
}
