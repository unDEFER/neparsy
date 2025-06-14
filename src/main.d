/**
 * main.d
 */

module main;

import std.stdio;
import std.array;
import std.string;
import std.conv;
import std.typecons : Flag, Yes, No;
import std.algorithm.searching;
import std.math.traits;
import std.math;
import std.algorithm;
import std.uni;
import std.file;
import common;
import parser;

Style[string] name2style = ["C": Style.C, "C++": Style.CPP, "D": Style.D, "Java": Style.Java, "Rust": Style.Rust, "Python": Style.Python];

void usage(string execname)
{
    stderr.writefln("usage: %s [--style <Language Name>] <source> <destination> -- for converting to/from neparsy format\n"
            ~"where neparsy-files must have '.np' extension\n"
            ~"Supported styles: C/C++/D/Java/Rust/Python", execname);
}

int main(string[] args)
{
    string execname = args[0];

    if (args.length < 3 || args[1] == "-h" || args[1] == "--help")
    {
        usage(execname);
        return 1;
    }

    Style style;

    if (args[1] == "-s" || args[1] == "--style")
    {
        if (args.length < 5)
        {
            stderr.writefln("Not enough arguments");
            usage(execname);
            return 1;
        }
        
        if (args[2] !in name2style)
        {
            stderr.writefln("Unknown style %s", args[2]);
            usage(execname);
            return 1;
        }

        style = name2style[args[2]];

        args = args[2..$];
    }

    string input = args[1];
    string output = args[2];

    if ((input.endsWith(".np")?1:0) + (output.endsWith(".np")?1:0) != 1)
    {
        stderr.writefln("Exactly one of files must has .np-suffix");
        usage(execname);
        return 1;
    }

    if (input.endsWith(".np"))
    {
        writefln("OK. Here we will convert neparsy-file %s to %s with %s style", input, output, style);
    }
    else //if (output.endsWith(".np"))
    {
        return convert2neparsy(input, output, style);
    }

    return 0;
}

