module node;

import std.algorithm;
import std.range;
import std.utf;
import std.stdio;
import std.conv;
import std.ascii;
import core.stdc.stdlib;

import ifacenode;

struct OpenNode
{
    string operator;
}

struct AttrNode
{
    Node[string] attrs;
}

enum NodeType
{
    Parentheses = 0,
    Braces,
    Open,
    String,
    Attr,
    Comment,
    Text,
    File
}

struct BlockBE
{
    string begin;
    string end;
    string escape;
    bool nested;
}

struct ParserState
{
    BlockBE[] strings = [];
    BlockBE[] comments = [];
    BlockBE parentheses = BlockBE("(", ")", "\\", true);
    BlockBE braces = BlockBE("{", "}", "\\", true);
    BlockBE brackets = BlockBE("[", "]", "\\", true);
    string[] delimiters = [" ", "\t", "\n"];
    string line, nline;
    string filename;
    int errors;
    int numline = 1;
    bool nl = true;
    int indent;
}

class Node
{
    union
    {
        Node[] u_arguments;
        OpenNode u_o;
        AttrNode u_a;
    }

    union
    {
        Node[][2] u_texts;
        string[2] u_t;
    }

    ref Node[] arguments()
    {
        assert (type == NodeType.Parentheses || type == NodeType.Braces || type == NodeType.File,
                "no arguments property for "~type.text);
        return u_arguments;
    }

    ref OpenNode o()
    {
        assert (type == NodeType.Open || type == NodeType.String || type == NodeType.Comment ||
                type == NodeType.Text);
        return u_o;
    }

    ref AttrNode a()
    {
        assert (type == NodeType.Attr);
        return u_a;
    }

    ref Node[][2] texts()
    {
        assert (type == NodeType.Parentheses || type == NodeType.Braces || type == NodeType.File ||
                type == NodeType.Attr,
                "no texts property for "~type.text);
        return u_texts;
    }

    ref string[2] t()
    {
        assert (type == NodeType.Open || type == NodeType.String || type == NodeType.Comment ||
                type == NodeType.Text);
        return u_t;
    }

    int[2] indent;
    int[2] lines;

    Node parent;
    size_t index;

    NodeType type;
    IfaceNode *i;

    static dchar getEscape(dchar c)
    {
        switch (c)
        {
            case 'n':
                return '\n';
            case 'r':
                return '\r';
            case 't':
                return '\t';
            default:
                return c;
        }
    }

    void nextLine(ref ParserState ps)
    {
        ps.numline++;
        ps.indent = 0;
        ps.nl = true;
    }

    dchar nextChr(ref ParserState ps, size_t count = 0)
    {
        if (ps.line.startsWith(" "))
        {
            if (ps.nl) ps.indent++;
        }
        else if (ps.line.startsWith("\t"))
        {
            if (ps.nl) ps.indent += 8;
        }
        else if (ps.line.startsWith("\n"))
        {
            nextLine(ps);
        }
        else ps.nl = false;

        if (count == 0)
            return ps.line.decodeFront();
        else
            ps.line = ps.line[count .. $];

        return '\0';
    }

    string getBlock(ref ParserState ps, BlockBE be)
    {
        string sline = ps.line;

        assert(ps.line.startsWith(be.begin));
        ps.line = ps.line[be.begin.length .. $];

        bool escape;
        int nest;
        while (!ps.line.empty)
        {
            if (escape)
            {
                escape = false;
                nextChr(ps);
            }
            else if ( !be.escape.empty && ps.line.startsWith(be.escape) )
            {
                escape = true;
                nextChr(ps, be.escape.length);
            }
            else if ( be.nested && ps.line.startsWith(be.begin) )
            {
                nest++;
                nextChr(ps, be.begin.length);
            }
            else if ( ps.line.startsWith(be.end) )
            {
                nextChr(ps, be.end.length);
                if (nest == 0) return sline[0..ps.line.ptr - sline.ptr].idup;
                nest--;
            }
            else
            {
                nextChr(ps);
            }
        }

        return sline[0..ps.line.ptr - sline.ptr];
    }

    static bool startsWithDelimiter(ParserState ps)
    {
        foreach(dl; ps.delimiters)
        {
            if (ps.line.startsWith(dl))
                return true;
        }
        return false;
    }

    static bool isSpaces(string line)
    {
        foreach(dchar c; line)
        {
            if (c != ' ' && c != '\t')
                return false;
        }

        return true;
    }

    static bool startsWithDelimitersNL(ParserState ps)
    {
        while (startsWithDelimiter(ps))
        {
            if (ps.line.startsWith("\n"))
                return true;
            ps.line.decodeFront();
        }
        return false;
    }

    string skipTillNL(ref ParserState ps)
    {
        auto eline = ps.line;
        while (!eline.empty && (eline[0] == ' ' || eline[0] == '\n'))
        {
            bool nl = (eline[0] == '\n');
            eline = eline[1..$];
            if (nl)
            {
                ps.line = eline;
                nextLine(ps);
            }
        }
        return eline;
    }

    void addText(ref ParserState ps)
    {
        Node tn = new Node();
        tn.parent = this;
        tn.type = NodeType.Text;
        tn.t = [ps.nline[0 .. ps.line.ptr - ps.nline.ptr], []];
        ps.nline = ps.line;
        texts[0] ~= tn;

        tn.indent[0] = ps.indent;
        tn.lines[0] = cast(int) tn.t[0].count("\n");
    }

    this()
    {
    }

    this(string line, string filename = "")
    {
        this(line, ParserState.init, null, filename);
    }

    this(ref string file, ParserState ps, Node parent = null, string filename = null)
    {
        ps.filename = filename;
        ps.line = file;
        ps.nline = file;

        this(ps, parent, filename.empty);
        assert(ps.line.empty);
        if (ps.errors) exit(1);
        //Debug();
    }

    this(ref ParserState ps, Node parent = null, bool nofile = false)
    {
        this.parent = parent;
        int snumline = ps.numline;

        if (parent is null)
        {
            if (!nofile)
            {
                type = NodeType.File;
                texts = [[], []];
                while (!ps.line.empty)
                {
                    auto ne = new Node(ps, this);

                    ne.index = arguments.length;
                    if (ne.type != NodeType.Comment)
                        arguments ~= ne;
                    texts[0] ~= ne;
                }

                lines[0] = ps.numline - snumline;

                return;
            }
            else
            {
                ps.comments = [BlockBE("/*", "*/")];
                ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\"), BlockBE("`", "`")];
            }
        }

        if (ps.comments.empty && parent.type == NodeType.File)
        {
            while (!ps.line.empty)
            {
                if ( ps.line.startsWith(ps.parentheses.begin) ||
                        ps.line.startsWith(ps.braces.begin) ||
                        ps.line.startsWith(ps.brackets.begin) )
                {
                    if (ps.line !is ps.nline)
                    {
                        t = [ps.nline[0 .. ps.line.ptr - ps.nline.ptr], []];
                        ps.nline = ps.line;
                        type = NodeType.Comment;

                        lines[0] = ps.numline - snumline;

                        return;
                    }
                    goto Init;
                }
                else
                {
                    while (!ps.line.empty && !ps.line.startsWith("\n"))
                    {
                        ps.line.decodeFront();
                    }

                    if (!ps.line.empty)
                    {
                        nextChr(ps);
                    }
                }
            }
        }

        Init:
        while (startsWithDelimiter(ps))
        {
            nextChr(ps);
        }

        indent[0] = ps.indent;

        foreach(be; ps.comments)
        {
            if ( ps.line.startsWith(be.begin) )
            {
                getBlock(ps, be);
                skipTillNL(ps);
                type = NodeType.Comment;
                t = [ps.nline[0 .. ps.line.ptr - ps.nline.ptr], []];
                ps.nline = ps.line;

                lines[0] = ps.numline - snumline;

                return;
            }
        }

        bool in_brackets;
        BlockBE brackets = ps.parentheses;
        size_t bracket_line = ps.numline;
        size_t bracket_chr = ps.line.ptr - ps.nline.ptr + 1;

        if ( ps.line.startsWith(ps.parentheses.begin) )
        {
            in_brackets = true;
            brackets = ps.parentheses;
            type = NodeType.Parentheses;
        }
        else if ( ps.line.startsWith(ps.braces.begin) )
        {
            in_brackets = true;
            brackets = ps.braces;
            type = NodeType.Braces;
        }
        else if ( ps.line.startsWith(ps.brackets.begin) )
        {
            in_brackets = true;
            brackets = ps.brackets;
            type = NodeType.Attr;
            a = AttrNode();
        }

        if (in_brackets)
        {
            ps.line = ps.line[brackets.begin.length .. $];
            
            skipTillNL(ps);
            
            texts = [[], []];
            addText(ps);

            while (!ps.line.empty)
            {
                if ( ps.line.startsWith(brackets.end) )
                {
                    ps.line = ps.line[brackets.end.length .. $];

                    skipTillNL(ps);
                    addText(ps);

                    goto End;
                }
                else if (startsWithDelimiter(ps))
                {
                    nextChr(ps);
                }
                else
                {
                    size_t numline = ps.numline;
                    size_t chr = ps.line.ptr - ps.nline.ptr + 1;
                    auto ne = new Node(ps, this, nofile);

                    if (ne.type == NodeType.Open && ne.o.operator.empty)
                    {
                        size_t numchr = ps.line.ptr - ps.nline.ptr + 1;
                        stderr.writefln("%s(%s,%s): Unexpected %s", ps.filename, ps.numline, numchr, ps.line[0]);
                        stderr.writefln("%s(%s,%s): Not closed bracket %s", ps.filename, bracket_line, bracket_chr, brackets.begin);
                        exit(1);
                    }

                    if (ne.type == NodeType.Open && ne.o.operator == ".")
                    {
                        ne.o.operator = "";
                    }

                    if (type == NodeType.Attr)
                    {
                        if (ne.type == NodeType.Open)
                        {
                            ne.index = a.attrs.length;
                            a.attrs[ne.o.operator] = ne;
                        }
                        else if (ne.type != NodeType.Comment)
                        {
                            stderr.writefln("%s(%s,%s): Only open and comment parameters in [] permitted", ps.filename, numline, chr);
                            ps.errors++;
                        }
                    }
                    else
                    {
                        ne.index = arguments.length;
                        if (ne.type != NodeType.Comment)
                        {
                            arguments ~= ne;
                        }
                    }

                    texts[0] ~= ne;
                }
            }
            stderr.writefln("%s(%s,%s): Not closed bracket %s", ps.filename, bracket_line, bracket_chr, brackets.begin);
            ps.errors++;
        }
        else
        {
            type = NodeType.Open;
            o = OpenNode();

            foreach(be; ps.strings)
            {
                if ( ps.line.startsWith(be.begin) )
                {
                    o.operator = getBlock(ps, be);
                    type = NodeType.String;

                    goto Arguments;
                }
            }

            while (!ps.line.empty)
            {
                if (ps.line.startsWith(ps.parentheses.begin) ||
                        ps.line.startsWith(ps.braces.begin) ||
                        ps.line.startsWith(ps.brackets.begin) && !o.operator.startsWith("#") )
                {
                    goto Arguments;
                }
                else if (ps.line.startsWith(ps.braces.escape))
                {
                    nextChr(ps, ps.braces.escape.length);
                    dchar c = nextChr(ps);
                    o.operator ~= getEscape(c);
                }
                else if (startsWithDelimiter(ps))
                {
                    goto Arguments;
                }
                else if (ps.line.startsWith(ps.parentheses.end) ||
                        ps.line.startsWith(ps.braces.end) ||
                        ps.line.startsWith(ps.brackets.end) && !o.operator.startsWith("#") )
                {
                    goto Arguments;
                }
                else
                    o.operator ~= nextChr(ps);
            }

        Arguments:
            if (o.operator.startsWith("@") && !parent.arguments.empty && parent.arguments[0].o.operator == "#module")
            {
                switch(o.operator)
                {
                    case "@D":
                    case "@Lexer":
                        ps.comments = [BlockBE("//", "\n"), BlockBE("/*", "*/"), BlockBE("/+", "+/", null, true)];
                        ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\"), BlockBE("`", "`")];
                        break;
                    default:
                        break;
                }
            }

            skipTillNL(ps);

            t = [ps.nline[0 .. ps.line.ptr - ps.nline.ptr], []];
            ps.nline = ps.line;
        }

        End:

        lines[0] = ps.numline - snumline;

        auto eline = skipTillNL(ps);

        if (eline.empty) 
        {
            ps.line = eline;
            if (type == NodeType.Parentheses || type == NodeType.Braces)
            {
                addText(ps);
            }
        }
    }

    void Debug(size_t te = 0)
    {
        writefln("type %s", type);
        if (type == NodeType.Open || type == NodeType.String || type == NodeType.Text || type == NodeType.Comment)
        {
            if (type != NodeType.Text)
            {
                writefln("     OP %s", o.operator);
            }
            writefln("     TX %s", t[te]);
            writefln("     INDENT %s", indent[te]);
            writefln("     LINES %s", lines[te]);
        }
        else
        {
            writefln("     INDENT %s", indent[te]);
            writefln("     LINES %s", lines[te]);
            /*foreach(arg; arguments)
            {
                arg.Debug();
            }*/
            foreach(text; texts[te])
            {
                text.Debug(te);
            }
        }
    }

    override string toString()
    {
        return type.text ~ ":" ~ (type == NodeType.Open || type == NodeType.String ? o.operator : "") ~
            ((type == NodeType.Parentheses || type == NodeType.Braces) &&
             !arguments.empty && (arguments[0].type == NodeType.Open || arguments[0].type == NodeType.String) ?
             arguments[0].o.operator  : "");
    }

    string toText(size_t i = 0)
    {
        if (type == NodeType.Open || type == NodeType.String || type == NodeType.Text || type == NodeType.Comment) return t[i];
        
        string ret;
        foreach (text; texts[i])
        {
            ret ~= text.toText(i);
        }
        return ret;
    }

    void checkIndent(size_t i = 0)
    {
        auto real_lines = toText(i).count("\n");
        if (lines[i] != real_lines)
        {
            writefln("ERROR %s %s != %s", this, lines[i], real_lines);
        }

        if (type == NodeType.Open || type == NodeType.String || type == NodeType.Text || type == NodeType.Comment)
            return;
        
        if (type == NodeType.Attr)
        {
            foreach (arg; a.attrs)
            {
                arg.checkIndent(i);
            }
        }
        else
        {
            foreach (arg; arguments)
            {
                arg.checkIndent(i);
            }
        }
    }

    void calcLines(out int num_bargs, out int alines, size_t bt = 0, size_t t = 0)
    {
        if (type == NodeType.Attr)
        {
            foreach(attr; a.attrs)
            {
                num_bargs++;
                alines += attr.lines[t];
            }
        }
        else
        {
            foreach(arg; arguments)
            {
                if (arg.type == NodeType.Parentheses || arg.type == NodeType.Braces || arg.type == NodeType.Attr)
                {
                    num_bargs++;
                }
                alines += arg.lines[t];
            }
        }

        foreach(arg; texts[bt])
        {
            if (arg.type == NodeType.Comment)
            {
                alines += arg.lines[bt];
            }
        }
    }

    void genText(size_t bt = 0)
    {
        bool nl;
        copyIndent(bt, 0);
        genText(nl, bt);
    }

    void genText(ref bool nl, size_t bt = 0, int extralines = 0)
    {
        string str;

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 0) t[0] = t[bt];
            nl = t[0].endsWith("\n");
            return;
        }

        writefln("GT %s -- %s", this, extralines);
        
        //processIndent(nl, bt, str, rline, 0, bt);
        if (nl)
        {
            str = ' '.repeat(indent[0]).array.idup();
        }
        else if (index > 0)
            str = " ";

        if (type == NodeType.Open || type == NodeType.String)
        {
            assert(extralines == 0);
            if (o.operator.empty)
                str ~= ".";
            str ~= o.operator ~ '\n'.repeat(lines[0]).array.idup;

            t[0] = str;
            nl = (lines[0] > 0);
        }
        else
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0);

            extralines += lines[0] - alines;
            writefln("G2 %s - %s", lines[0], extralines);

            Node[] ntexts = [];
            if (type == NodeType.Parentheses)
            {
                str ~= "(";
            }
            else if (type == NodeType.Braces)
            {
                str ~= "{";
            }
            else if (type == NodeType.Attr)
            {
                str ~= "[";
            }

            int endnl;
            if (!str.empty && extralines > 0)
            {
                if (lines[0] != 2 && !(lines[0] > 2 && extralines == 1))
                {
                    endnl = 1;
                    extralines--;
                }

                if (lines[0] != 1 && extralines > 0 && !arguments.empty && (arguments[0].type == NodeType.Parentheses || arguments[0].type == NodeType.Braces))
                {
                    str ~= "\n";
                    extralines--;
                    nl = true;
                }
                else nl = false;
            }
            else
            {
                nl = false;
            }

            if (!str.empty)
            {
                Node tn = new Node();
                tn.parent = this;
                tn.type = NodeType.Text;
                tn.t[0] = str;
                tn.indent[0] = indent[0];
                ntexts ~= tn;
            }

            int perarg;
            if (num_bargs > 0)
            {
                perarg = extralines / num_bargs;
                endnl += extralines % num_bargs;
            }
            else endnl += extralines;

            if (type == NodeType.Attr)
            {
                alias orderByPlace = (x, y) => a.attrs[x].index < a.attrs[y].index;
                auto attributes = a.attrs.keys();
                attributes.sort!(orderByPlace)();

                size_t j;
                foreach(attr; attributes)
                {
                    auto arg = a.attrs[attr];
                    if (j < texts[bt].length)
                    {
                        auto a2 = texts[bt][j];
                        while (a2.index <= arg.index)
                        {
                            if (a2.type == NodeType.Comment)
                            {
                                a2.genText(nl);
                                ntexts ~= a2;
                            }
                            j++;
                            if (j >= texts[bt].length) break;
                            a2 = texts[bt][j];
                        }
                    }

                    arg.genText(nl);
                    ntexts ~= arg;
                }
            }
            else
            {
                size_t j;
                foreach(arg; arguments)
                {
                    auto a2 = texts[bt][j];
                    while (a2.index <= arg.index)
                    {
                        if (a2.type == NodeType.Comment)
                        {
                            a2.genText(nl);
                            ntexts ~= a2;
                        }
                        j++;
                        if (j >= texts[bt].length) break;
                        a2 = texts[bt][j];
                    }

                    int el;
                    if (arg.type == NodeType.Parentheses || arg.type == NodeType.Braces)
                        el = perarg;
                    arg.genText(nl, bt, el);
                    ntexts ~= arg;
                }
            }

            str = "";

            Node lnode = this;
            int lin = lines[0];

            if (nl)
            {
                str = ' '.repeat(indent[0]).array.idup();
            }

            if (type == NodeType.Parentheses)
            {
                str ~= ")";
            }
            else if (type == NodeType.Braces)
            {
                str ~= "}";
            }
            else if (type == NodeType.Attr)
            {
                str ~= "]";
            }

            if (endnl)
            {
                str ~= '\n'.repeat(endnl).array.idup();
            }
            nl = (endnl > 0);

            if (!str.empty)
            {
                Node tn = new Node();
                tn.parent = this;
                tn.type = NodeType.Text;
                tn.t[0] = str;
                tn.indent[0] = indent[0];
                ntexts ~= tn;
            }

            texts[0] = ntexts;
        }

        //endProcessIndent(nl, lastnode, rline);
    }

    string genLine(ref bool nl, string op)
    {
        auto ret = (nl ? ' '.repeat(indent[1]).array.idup() : "") ~ op ~ '\n'.repeat(lines[1]).array.idup();
        nl = (lines[1] > 0);
        return ret;
    }

    string genLine(ref bool nl, ptrdiff_t i, string prefix = "", string postfix = "")
    {
        string str;
        return genLine(nl, prefix ~ o.operator[i..$] ~ postfix);
    }

    Node genNode(ref bool nl, string op, int extralines = 0)
    {
        Node tn = new Node();
        tn.parent = this;
        tn.type = NodeType.Text;
        tn.lines[1] = extralines;
        tn.indent[1] = indent[1];
        tn.t[1] = tn.genLine(nl, op);

        return tn;
    }

    void copyIndent(size_t bt = 0, size_t t = 0)
    {
        if (bt == t) return;

        indent[t] = indent[bt];
        lines[t] = lines[bt];

        if (type == NodeType.Open || type == NodeType.String || type == NodeType.Text || type == NodeType.Comment)
            return;
        
        if (type == NodeType.Attr)
        {
            foreach (arg; a.attrs)
            {
                arg.copyIndent(bt, t);
            }
        }
        else
        {
            foreach (arg; arguments)
            {
                arg.copyIndent(bt, t);
            }
        }
    }

    void zeroLines(size_t t)
    {
        lines[t] = 0;

        if (type == NodeType.Open || type == NodeType.String || type == NodeType.Text || type == NodeType.Comment)
            return;
        
        if (type == NodeType.Attr)
        {
            foreach (arg; a.attrs)
            {
                arg.zeroLines(t);
            }
        }
        else
        {
            foreach (arg; arguments)
            {
                arg.zeroLines(t);
            }
        }
    }

    void genDText(size_t bt = 0)
    {
        bool nl = true;
        copyIndent(bt, 1);
        genDText(nl, bt);
        checkIndent(1);
    }

    void genDText(ref bool nl, size_t bt = 0, bool semicolon = false)
    {
        int extralines;
        string str = "";
        int rline;

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if (type == NodeType.Open || type == NodeType.String)
        {
            if (o.operator.startsWith("#"))
                t[1] = genLine(nl, 1, "", semicolon ? ";" : "");
            else
                t[1] = genLine(nl, 0, "", semicolon ? ";" : "");
        }
        else if ( type == NodeType.File )
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            int perarg;
            int lastarg;
            if (num_bargs > 0)
            {
                perarg = extralines / num_bargs;
                lastarg = perarg + extralines % num_bargs;
            }
            else lastarg = extralines;

            Node[] ntexts = [];

            size_t j = 0;
            foreach(k, arg; arguments)
            {
                auto a2 = texts[bt][j];
                while (a2.index <= arg.index)
                {
                    if (a2.type == NodeType.Comment)
                    {
                        a2.genDText(nl, bt);
                        ntexts ~= a2;
                    }
                    j++;
                    if (j >= texts[bt].length) break;
                    a2 = texts[bt][j];
                }
                
                auto ll = (k == arguments.length - 1 ? lastarg : perarg);
                
                arg.genDText(nl, bt, true);
                ntexts ~= arg;

                if (ll > 0)
                    ntexts ~= genNode(nl, "", ll);
            }

            texts[1] = ntexts;
        }
        else if ( (type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
                arguments[0].type == NodeType.Open )
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];
            size_t i;

            switch (arguments[0].o.operator)
            {
                case "#struct":
                case "#class":
                case "#enum":
                case "#module":
                case "#import":

                    if (arguments[0].o.operator == "#class")
                    {
                        foreach(j, arg; arguments[2..min(5, $)])
                        {
                            extralines += arg.lines[1];
                            arg.zeroLines(1);
                        }
                    }
                    else if (arguments[0].o.operator == "#struct")
                    {
                        foreach(j, arg; arguments[2..min(4, $)])
                        {
                            extralines += arg.lines[1];
                            arg.zeroLines(1);
                        }
                    }

                    if (arguments[0].o.operator == "#class")
                    {
                        arguments[3].genDTextAttrs(nl, bt);
                        ntexts ~= arguments[3];
                        i++;
                    }
                    else if (arguments[0].o.operator == "#struct")
                    {
                        arguments[2].genDTextAttrs(nl, bt);
                        ntexts ~= arguments[2];
                        i++;
                    }

                    arguments[0].t[1] = arguments[0].genLine(nl, 1);
                    ntexts ~= arguments[0];
                    i++;

                    bool sc = (arguments[0].o.operator == "#module" || arguments[0].o.operator == "#import");
                    arguments[1].t[1] = arguments[1].genLine(nl, 0, " ", sc ? ";" : "");
                    ntexts ~= arguments[1];
                    i++;

                    if (arguments[0].o.operator == "#module")
                    {
                        arguments[2].t[1] = "";
                        extralines += arguments[2].lines[1];
                        arguments[2].lines[1] = 0;
                        i++;
                    }

                    if (arguments[0].o.operator == "#class")
                    {
                        arguments[4].genDTextTemplateArgs(nl, bt);
                        ntexts ~= arguments[4];
                        i++;
                    }
                    else if (arguments[0].o.operator == "#struct")
                    {
                        arguments[3].genDTextTemplateArgs(nl, bt);
                        ntexts ~= arguments[3];
                        i++;
                    }

                    if (arguments[0].o.operator == "#class")
                    {
                        arguments[2].genDTextBaseClasses(nl, bt);
                        ntexts ~= arguments[2];
                        i++;
                    }

                    if (extralines > 0)
                    {
                        ntexts ~= genNode(nl, "", 1);
                        extralines--;
                    }

                    int perarg;
                    int lastarg;
                    if (arguments[0].o.operator == "#module" && num_bargs > 0)
                    {
                        perarg = extralines / num_bargs;
                        lastarg = perarg + extralines % num_bargs;
                    }
                    else lastarg = extralines;

                    if (arguments.length > i)
                    {
                        size_t j = 0;
                        foreach(k, arg; arguments[i..$])
                        {
                            auto a2 = texts[bt][j];
                            while (a2.index <= arg.index)
                            {
                                if (a2.type == NodeType.Comment)
                                {
                                    a2.genDText(nl, bt);
                                    ntexts ~= a2;
                                }
                                j++;
                                if (j >= texts[bt].length) break;
                                a2 = texts[bt][j];
                            }

                            auto ll = (k == arguments.length - i - 1 ? lastarg : perarg);

                            arg.genDText(nl, bt, true);
                            ntexts ~= arg;

                            if (ll > 0)
                            {
                                ntexts ~= genNode(nl, "", ll);
                            }
                        }
                    }

                    break;

                case "#var":

                    arguments[0].t[1] = "";
                    i++;

                    if (arguments.length > 3)
                    {
                        arguments[3].genDTextAttrs(nl, bt);
                        ntexts ~= arguments[3];
                    }
                    i++;

                    arguments[2].genDTextType(nl, bt);
                    ntexts ~= arguments[2];
                    i++;

                    auto arg = arguments[1];
                    if (arg.type == NodeType.Parentheses || arg.type == NodeType.Braces)
                    {
                        foreach (a2; arg.arguments)
                        {
                            a2.t[1] = " " ~ a2.o.operator;
                            ntexts ~= a2;
                        }
                    }
                    else
                    {
                        arg.t[1] = " " ~ arg.o.operator;
                        ntexts ~= arg;
                    }
                    i++;
                    nl = false;

                    if (arguments.length > 4)
                    {
                        ntexts ~= genNode(nl, " = ", 0);

                        arguments[4].genDTextExpr(nl, bt);
                        ntexts ~= arguments[4];
                    }

                    ntexts ~= genNode(nl, ";", extralines);

                    break;

                case "#function":

                    foreach(j, arg; arguments[3..min(6, $)])
                    {
                        extralines += arg.lines[1];
                        arg.zeroLines(1);
                    }

                    if (arguments.length > 4)
                    {
                        arguments[4].genDTextAttrs(nl, bt);
                        ntexts ~= arguments[4];
                    }

                    arguments[2].genDTextType(nl, bt);
                    ntexts ~= arguments[2];

                    arguments[1].t[1] = arguments[1].genLine(nl, 0, " ");
                    ntexts ~= arguments[1];

                    arguments[3].genDTextArguments(nl, bt);
                    ntexts ~= arguments[3];

                    if (arguments.length > 5)
                    {
                        arguments[5].genDTextAttrs(nl, bt, true);
                        ntexts ~= arguments[5];
                    }

                    if (extralines > 0)
                    {
                        ntexts ~= genNode(nl, "", 1);
                        extralines--;
                    }

                    if (arguments.length > 6)
                    {
                        arguments[6].genDText(nl, bt);
                        ntexts ~= arguments[6];
                    }

                    if (extralines > 0)
                        ntexts ~= genNode(nl, "", extralines);

                    break;

                case "#if":
                    arguments[0].t[1] = "";
                    extralines += arguments[0].lines[1];
                    arguments[0].lines[1] = 0;

                    int perarg;
                    int lastarg;
                    if (num_bargs > 0)
                    {
                        perarg = extralines / num_bargs;
                        lastarg = perarg + extralines % num_bargs;
                    }
                    else lastarg = extralines;

                    size_t j = 0;
                    foreach(k, arg; arguments[1..$])
                    {
                        auto a2 = texts[bt][j];
                        while (a2.index <= arg.index)
                        {
                            if (a2.type == NodeType.Comment)
                            {
                                a2.genDText(nl, bt);
                                ntexts ~= a2;
                            }
                            j++;
                            if (j >= texts[bt].length) break;
                            a2 = texts[bt][j];
                        }

                        auto ll = (k == arguments.length - 2 ? lastarg : perarg);

                        arg.genDTextCondition(nl, bt);
                        ntexts ~= arg;

                        if (ll > 0)
                            ntexts ~= genNode(nl, "", ll);
                    }

                    break;

                case "#for":
                    arguments[0].t[1] = arguments[0].genLine(nl, 1);
                    ntexts ~= arguments[0];

                    ntexts ~= genNode(nl, "(");

                    arguments[1].genDText(nl, bt);
                    ntexts ~= arguments[1];

                    //ntexts ~= genNode(nl, ";");

                    arguments[2].genDTextExpr(nl, bt);
                    ntexts ~= arguments[2];

                    ntexts ~= genNode(nl, ";");

                    arguments[3].genDTextExpr(nl, bt, ")");
                    ntexts ~= arguments[3];

                    i = 4;

                    int prenl, postnl;
                    if (extralines >= 2)
                    {
                        if (type == NodeType.Parentheses) prenl = 1;
                        postnl = 1;
                        extralines -= prenl + postnl;
                    }

                    int perarg;
                    int lastarg;
                    if (num_bargs > 0)
                    {
                        perarg = extralines / num_bargs;
                        lastarg = perarg + extralines % num_bargs;
                    }
                    else lastarg = extralines;

                    if (type == NodeType.Parentheses)
                    {
                        ntexts ~= genNode(nl, "{", prenl);
                    }
                    else if (prenl > 0)
                    {
                        ntexts ~= genNode(nl, "", prenl);
                    }

                    size_t j = 0;
                    foreach(k, arg; arguments[i..$])
                    {
                        auto a2 = texts[bt][j];
                        while (a2.index <= arg.index)
                        {
                            if (a2.type == NodeType.Comment)
                            {
                                a2.genDText(nl, bt);
                                ntexts ~= a2;
                            }
                            j++;
                            if (j >= texts[bt].length) break;
                            a2 = texts[bt][j];
                        }

                        auto ll = (k == arguments.length - i - 1 ? lastarg : perarg);

                        arg.genDText(nl, bt, true);
                        ntexts ~= arg;

                        if (ll > 0)
                            ntexts ~= genNode(nl, "", ll);
                    }

                    if (type == NodeType.Parentheses)
                    {
                        ntexts ~= genNode(nl, "}", postnl);
                    }
                    else if (postnl > 0)
                    {
                        ntexts ~= genNode(nl, "", postnl);
                    }

                    break;

                case "#foreach":
                    arguments[0].t[1] = arguments[0].genLine(nl, 1);
                    ntexts ~= arguments[0];

                    ntexts ~= genNode(nl, "(");

                    arguments[1].genDTextExpr(nl, bt);
                    if (!arguments[1].o.operator.empty)
                    {
                        ntexts ~= arguments[1];
                        ntexts ~= genNode(nl, ",");
                    }

                    arguments[2].genDTextExpr(nl, bt);
                    ntexts ~= arguments[2];

                    ntexts ~= genNode(nl, ";");

                    auto savelines = arguments[3].lines[bt];
                    arguments[3].zeroLines(1);
                    arguments[3].genDTextExpr(nl, bt);
                    ntexts ~= arguments[3];

                    ntexts ~= genNode(nl, ")", savelines);

                    i = 4;

                    int prenl, postnl;
                    
                    if (extralines > 0 && type == NodeType.Parentheses)
                    {
                        prenl = 1;
                        extralines--;
                    }

                    if (extralines > 0)
                    {
                        postnl = 1;
                        extralines--;
                    }

                    int perarg;
                    int lastarg;
                    if (num_bargs > 0)
                    {
                        perarg = extralines / num_bargs;
                        lastarg = perarg + extralines % num_bargs;
                    }
                    else lastarg = extralines;

                    writefln("GG %s lines=%s extralines=%s perarg=%s lastarg=%s, prenl=%s, postnl=%s",
                            this, lines[1], extralines, perarg, lastarg, prenl, postnl);

                    if (type == NodeType.Parentheses)
                    {
                        ntexts ~= genNode(nl, "{", prenl);
                    }
                    else if (prenl > 0)
                        ntexts ~= genNode(nl, "", prenl);

                    size_t j = 0;
                    foreach(k, arg; arguments[i..$])
                    {
                        auto a2 = texts[bt][j];
                        while (a2.index <= arg.index)
                        {
                            if (a2.type == NodeType.Comment)
                            {
                                a2.genDText(nl, bt);
                                ntexts ~= a2;
                            }
                            j++;
                            if (j >= texts[bt].length) break;
                            a2 = texts[bt][j];
                        }

                        auto ll = (k == arguments.length - i - 1 ? lastarg : perarg);

                        arg.genDText(nl, bt, true);
                        ntexts ~= arg;

                        if (ll > 0)
                            ntexts ~= genNode(nl, "", ll);
                    }

                    if (type == NodeType.Parentheses)
                    {
                        ntexts ~= genNode(nl, "}", postnl);
                    }
                    else if (postnl > 0)
                        ntexts ~= genNode(nl, "", postnl);

                    break;

                case "#return":
                    arguments[0].t[1] = arguments[0].genLine(nl, 1) ~ " ";
                    ntexts ~= arguments[0];

                    if (arguments.length > 1)
                    {
                        arguments[1].genDTextExpr(nl, bt);
                        ntexts ~= arguments[1];
                    }

                    ntexts ~= genNode(nl, ";", extralines);
                    break;

                default:
                    genDTextExpr(nl, bt);

                    texts[1] ~= genNode(nl, ";", extralines);
                    return;
            }

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
                (arguments[0].type == NodeType.Parentheses || arguments[0].type == NodeType.Braces))
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, "{", extralines > 0 ? 1 : 0);
                if (extralines > 0) extralines--;
            }

            size_t j = 0;
            foreach(arg; arguments)
            {
                auto a2 = texts[bt][j];
                while (a2.index < arg.index)
                {
                    if (a2.type == NodeType.Comment)
                    {
                        a2.genDText(nl, bt);
                        ntexts ~= a2;
                    }
                    a2 = texts[bt][++j];
                }
                arg.genDText(nl, bt, true);
                ntexts ~= arg;
            }

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, "}", extralines);
            }
            else if (extralines > 0)
            {
                ntexts ~= genNode(nl, "", extralines);
            }

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            genDTextExpr(nl, bt);

            texts[1] ~= genNode(nl, ";", extralines);
        }
    }

    void genDTextType(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if (type == NodeType.Open || type == NodeType.String)
        {
            t[1] = genLine(nl, 0);
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
            arguments[0].type == NodeType.Open &&
            arguments[0].o.operator == "#function")
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            arguments[2].genDTextType(nl, bt);
            ntexts ~= arguments[2];

            arguments[0].t[1] = arguments[0].genLine(nl, 1, " ");
            ntexts ~= arguments[0];
            nl = false;

            arguments[3].genDTextArguments(nl, bt);
            ntexts ~= arguments[3];
            if (extralines > 0)
                ntexts ~= genNode(nl, "", extralines);

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
            arguments[0].type == NodeType.Open &&
            arguments[0].o.operator == "#[]")
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];
            size_t i;

            arguments[2].t[1] = arguments[2].genLine(nl, 0);
            ntexts ~= arguments[2];
            i++;

            ntexts ~= genNode(nl, "[", 0);

            arguments[1].genDTextType(nl, bt);
            ntexts ~= arguments[1];
            i++;

            ntexts ~= genNode(nl, "]", extralines);

            texts[1] = ntexts;
        }
    }

    void genDTextArguments(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            ntexts ~= genNode(nl, "(", 0);

            foreach(i, arg; arguments)
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ");
                }

                arg.genDTextArgument(nl, bt);
                ntexts ~= arg;
            }

            ntexts ~= genNode(nl, ")", extralines);

            texts[1] = ntexts;
        }
    }

    void genDTextArgument(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        //processIndent(nl, str, rline, 1);

        if (type == NodeType.Open || type == NodeType.String)
        {
            t[1] = genLine(nl, 0, " ");
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
            arguments[0].type == NodeType.Open)
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];
            size_t i;

            arguments[1].genDTextType(nl, bt);
            ntexts ~= arguments[1];

            arguments[0].t[1] = arguments[0].genLine(nl, extralines, " ");
            ntexts ~= arguments[0];

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            Node[] ntexts = [];
            arguments[1].genDTextType(nl, bt);
            foreach(i, arg; arguments[0].arguments)
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ", 0);
                }

                ntexts ~= arguments[1];

                arg.genDTextArgument(nl, bt);
                ntexts ~= arg;
            }
            texts[1] = ntexts;
        }
    }

    void genDTextExpr(ref bool nl, size_t bt = 0, string postfix = "")
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        //processIndent(nl, str, rline, 1);

        if (type == NodeType.Open || type == NodeType.String)
            if (o.operator.startsWith("#"))
                t[1] = genLine(nl, 1);
            else
                t[1] = genLine(nl, 0);
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
            arguments[0].type == NodeType.Open && !arguments[0].o.operator.empty && arguments[0].o.operator == "#[]")
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;
            
            Node[] ntexts = [];

            ntexts ~= genNode(nl, "[", 0);

            arguments[0].t[1] = "";
            extralines += arguments[0].lines[bt];

            foreach(i, arg; arguments[1..$])
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ", 0);
                }

                arg.genDTextExpr(nl, bt);
                ntexts ~= arg;
            }

            ntexts ~= genNode(nl, "]" ~ postfix, extralines);

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty &&
            arguments[0].type == NodeType.Open && !arguments[0].o.operator.empty && !isAlphaNum(arguments[0].o.operator[0]))
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;
            
            Node[] ntexts = [];

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, "(", 0);
            }

            arguments[0].t[1] = arguments[0].genLine(nl, 0, " ", " ");
            if (arguments.length == 2)
            {
                ntexts ~= arguments[0];
                extralines += arguments[1].lines[bt];
            }
            else extralines += arguments[0].lines[bt];

            foreach(i, arg; arguments[1..$])
            {
                if (i > 0)
                {
                    ntexts ~= arguments[0];
                    nl = false;
                }

                arg.genDTextExpr(nl, bt);
                ntexts ~= arg;
            }

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, ")" ~ postfix, extralines);
            }
            else if (extralines > 0)
                ntexts ~= genNode(nl, postfix, extralines);

            texts[1] = ntexts;
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            arguments[0].genDText(nl, bt);
            ntexts ~= arguments[0];

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, "(", 0);
            }

            foreach(i, arg; arguments[1..$])
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ", 0);
                }

                arg.genDTextExpr(nl, bt);
                ntexts ~= arg;
            }

            if (type == NodeType.Parentheses)
            {
                ntexts ~= genNode(nl, ")", 0);
            }
            else if (extralines > 0)
                ntexts ~= genNode(nl, "", extralines);

            texts[1] = ntexts;
        }
    }

    void genDTextCondition(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if (type == NodeType.Open || type == NodeType.String)
        {
            if (o.operator == "#else")
                t[1] = genLine(nl, 1);
            else
                t[1] = genLine(nl, 0);
        }
        else if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            Node[] ntexts = [];

            if (arguments[0].type == NodeType.Open && arguments[0].o.operator == "#else")
            {
                arguments[0].genDTextCondition(nl, bt);
                ntexts ~= arguments[0];
            }
            else
            {
                string key;
                if (index == 1)
                {
                    key = "if";
                }
                else
                {
                    key = "else if";
                }

                ntexts ~= genNode(nl, key ~ " ");

                arguments[0].genDTextExpr(nl, bt);
                ntexts ~= arguments[0];
            }

            extralines += lines[bt] - arguments[0].lines[bt] - arguments[1].lines[bt];

            arguments[1].genDText(nl, bt);
            ntexts ~= arguments[1];

            if (extralines > 0)
                ntexts ~= genNode(nl, "", extralines);

            texts[1] = ntexts;
        }
    }

    void genDTextAttrs(ref bool nl, size_t bt = 0, bool right = false)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if (type == NodeType.Open || type == NodeType.String)
        {
            t[1] = genLine(nl, 0, right && !o.operator.empty ? " " : "", !right && !o.operator.empty ? " " : "");
            //writefln("THIS=%s, t[1]=%s", this, t[1]);
        }
        else if (type == NodeType.Attr)
        {
            //writefln("ATTR=%s, %s", this, a.attrs);
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            alias orderByPlace = (x, y) => a.attrs[x].index < a.attrs[y].index;
            auto attributes = a.attrs.keys();
            attributes.sort!(orderByPlace)();

            foreach(attr; attributes)
            {
                auto arg = a.attrs[attr];
                arg.genDTextAttrs(nl, bt, right);
                ntexts ~= arg;
            }

            if (extralines > 0)
                ntexts ~= genNode(nl, "", extralines);

            texts[1] = ntexts;
        }
        else assert(0, "Unreachable statement. Type="~type.text);
    }

    void genDTextTemplateArgs(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            ntexts ~= genNode(nl, "(", 0);

            foreach(i, arg; arguments)
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ");
                }

                arg.genDTextArgument(nl, bt);
                ntexts ~= arg;
            }

            ntexts ~= genNode(nl, ")", extralines);

            texts[1] = ntexts;
        }
    }

    void genDTextBaseClasses(ref bool nl, size_t bt = 0)
    {
        int extralines;
        string str = "";

        if (type == NodeType.Comment)
        {
            assert(extralines == 0);
            if (bt != 1) t[1] = t[bt];
            nl = t[1].endsWith("\n");
            return;
        }

        if ((type == NodeType.Parentheses || type == NodeType.Braces) && !arguments.empty)
        {
            int num_bargs;
            int alines;
            calcLines(num_bargs, alines, 0, 1);

            extralines += lines[1] - alines;

            Node[] ntexts = [];

            ntexts ~= genNode(nl, ":", 0);

            foreach(i, arg; arguments)
            {
                if (i > 0)
                {
                    ntexts ~= genNode(nl, ", ");
                }

                arg.genDTextArgument(nl, bt);
                ntexts ~= arg;
            }

            ntexts ~= genNode(nl, "", extralines);

            texts[1] = ntexts;
        }
    }
}

