module parser;
import std.stdio;
import std.string;
import std.algorithm;
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

int convert2neparsy(string input, string output, Style style)
{
    auto file = File(input); // Open for reading
    auto lines = file.byLine()            // Read lines
                 .map!parseIndent();      // Split into words

    writefln("%s", lines);

    return 0;
}
