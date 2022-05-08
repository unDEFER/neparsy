/**
 * expression.d
 */

module expression;

import std.stdio;
import std.math;
import std.datetime;
import std.algorithm.searching;
import std.algorithm.mutation;
import std.range.primitives;
import std.utf;
import std.algorithm;
import std.range: repeat;
import std.array;
import std.string;
import std.file;

import iface;

struct BlockBE
{
    string begin;
    string end;
    string escape;
    bool nested;
}

enum BlockType
{
    Code = 0,
    String,
    Comment,
    File
}

struct ParserState
{
    BlockBE[] strings = [];
    BlockBE[] comments = [];
    BlockBE brackets = BlockBE("(", ")", "\\", true);
    string sharp = "#";
    string at = "@";
    string dot = ".";
}

class Expression
{
    real x = 0, y = 0;
    real r1, r2, r3;
    real d1, d2;
    real a1, a2;
    real arat;
    real brat;
    real[] pw, mw;
    Color c;
    int line;
    int block, level, levels;
    Expression center;
    bool hidden;

    string operator;
    string type;
    string label;
    int nl1, nl2;
    BlockType bt;
    Expression[] arguments;
    Expression postop;
    Expression parent;
    long index;
    long focus_index;

    real r() { return c.r; }
    real g() { return c.g; }
    real b() { return c.b; }
    real a() { return c.a; }

    this()
    {
    }

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

    static string readEscaped(string line, string escChar)
    {
        string res = "";
        bool escape;

        while (!line.empty)
        {
            if (escape)
            {
                escape = false;
                dchar c = line.decodeFront();
                res ~= getEscape(c);
            }
            else if ( line.startsWith(escChar) )
            {
                escape = true;
                line = line[escChar.length .. $];
            }
            else
            {
                res ~= line.decodeFront();
            }
        }

        return res;
    }

    string getBlock(ref char[] line, BlockBE be)
    {
        char[] sline = line;
        assert(line.startsWith(be.begin));
        line = line[be.begin.length .. $];

        bool escape;
        int nest;
        while (!line.empty)
        {
            if (escape)
            {
                escape = false;
                line.decodeFront();
            }
            else if ( !be.escape.empty && line.startsWith(be.escape) )
            {
                escape = true;
                line = line[be.escape.length .. $];
            }
            else if ( be.nested && line.startsWith(be.begin) )
            {
                nest++;
                line = line[be.begin.length .. $];
            }
            else if ( line.startsWith(be.end) )
            {
                line = line[be.end.length .. $];
                if (nest == 0) return sline[0..line.ptr - sline.ptr].idup;
                nest--;
            }
            else
            {
                line.decodeFront();
            }
        }

        return sline[0..line.ptr - sline.ptr].idup;
    }

    BlockBE getBE()
    {
        BlockBE be = BlockBE(operator);
        foreach(arg; arguments)
        {
            switch(arg.type)
            {
                case "end":
                    be.end = arg.operator;
                    break;
                case "escape":
                    be.escape = arg.operator;
                    break;
                case "nested":
                    be.nested = true;
                    break;
                default:
                    break;
            }
        }

        return be;
    }

    static bool startsWithDotBracket(char[] line, ParserState ps)
    {
        if (line.startsWith(ps.dot))
        {
            line = line[ps.dot.length .. $];
            while (!line.empty && (line[0] == ' ' || line[0] == '\n'))
            {
                line.decodeFront();
            }
            return line.startsWith(ps.brackets.begin);
        }
        return false;
    }

    this(ref char[] line, ParserState ps = ParserState.init, Expression parent = null, bool nofile = false)
    {
        if (parent is null)
        {
            if (!nofile)
            {
                bt = BlockType.File;
                while (!line.empty)
                {
                    auto ne = new Expression(line, ps, this);
                    ne.parent = this;
                    ne.index = arguments.length;
                    arguments ~= ne;
                }
                return;
            }
            else
            {
                ps.comments = [BlockBE("/*", "*/")];
                ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\")];
            }
        }
        else
        {
            nl1 = parent.nl2;
        }

        if (ps.comments.empty)
        {
            char[] sline = line;

            while (!line.empty)
            {
                if ( line.startsWith(ps.brackets.begin) )
                {
                    if (line !is sline)
                    {
                        operator = sline[0 .. line.ptr - sline.ptr].idup;
                        bt = BlockType.Comment;
                        return;
                    }
                    goto Init;
                }
                else
                {
                    while (!line.empty && !line.startsWith("\n"))
                    {
                        line.decodeFront();
                    }

                    if (!line.empty)
                    {
                        line.decodeFront();
                    }
                    nl1++;
                }
            }
        }

        Init:
        while (!line.empty && (line[0] == ' ' || line[0] == '\n'))
        {
            if (line[0] == '\n')
                nl1++;
            line = line[1..$];
        }

        foreach(be; ps.comments)
        {
            if ( line.startsWith(be.begin) )
            {
                operator = getBlock(line, be);
                bt = BlockType.Comment;
                return;
            }
        }

        bool in_brackets;
        BlockBE brackets = ps.brackets;

        if ( line.startsWith(ps.brackets.begin) )
        {
            line = line[ps.brackets.begin.length .. $];
            in_brackets = true;
            arguments = [null];
            arguments.length = 0;
            assert(arguments !is null);
        }

        foreach(be; ps.strings)
        {
            if ( line.startsWith(be.begin) )
            {
                operator = getBlock(line, be);
                bt = BlockType.String;

                if (line.startsWith(ps.sharp))
                {
                    line = line[ps.sharp.length .. $];
                    goto Sharp;
                }
                else if (line.startsWith(ps.at))
                {
                    line = line[ps.at.length .. $];
                    goto At;
                }
                else goto Arguments;
            }
        }

        while (!line.empty)
        {
            if (line.startsWith(ps.brackets.begin))
            {
                goto Arguments;
            }
            else if (line.startsWith(ps.brackets.escape))
            {
                line = line[ps.brackets.escape.length .. $];
                dchar c = line.decodeFront();
                operator ~= getEscape(c);
            }
            else if (line[0] == ' ' || line[0] == '\n')
            {
                goto Arguments;
            }
            else if (line.startsWith(ps.brackets.end))
            {
                if (in_brackets)
                {
                    line = line[ps.brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (!in_brackets && startsWithDotBracket(line, ps))
            {
                goto Post;
            }
            else if (line.startsWith(ps.sharp))
            {
                line = line[ps.sharp.length .. $];
                goto Sharp;
            }
            else if (line.startsWith(ps.at))
            {
                line = line[ps.at.length .. $];
                goto At;
            }
            else
                operator ~= line.decodeFront();
        }

        Sharp:
        while (!line.empty)
        {
            if (line.startsWith(ps.brackets.begin))
            {
                goto Arguments;
            }
            else if (line.startsWith(ps.brackets.escape))
            {
                line = line[ps.brackets.escape.length .. $];
                dchar c = line.decodeFront();
                type ~= getEscape(c);
            }
            else if (line[0] == ' ' || line[0] == '\n')
            {
                goto Arguments;
            }
            else if (line.startsWith(ps.brackets.end))
            {
                if (in_brackets)
                {
                    line = line[ps.brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (!in_brackets && startsWithDotBracket(line, ps))
            {
                goto Post;
            }
            else if (line.startsWith(ps.at))
            {
                line = line[ps.at.length .. $];
                goto At;
            }
            else
                type ~= line.decodeFront();
        }

        At:
        while (!line.empty)
        {
            if (line.startsWith(ps.brackets.end))
            {
                if (in_brackets)
                {
                    line = line[ps.brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (line.startsWith(ps.brackets.escape))
            {
                line = line[ps.brackets.escape.length .. $];
                dchar c = line.decodeFront();
                label ~= getEscape(c);
            }
            else if (line.startsWith(ps.brackets.begin))
            {
                goto Arguments;
            }
            else if (line[0] == ' ' || line[0] == '\n')
            {
                goto Arguments;
            }
            else if (!in_brackets && startsWithDotBracket(line, ps))
            {
                goto Post;
            }
            else
                label ~= line.decodeFront();
        }

        Arguments:
        if (type == "module")
        {
            switch(label)
            {
                case "D":
                case "Lexer":
                    ps.comments = [BlockBE("//", "\n"), BlockBE("/*", "*/"), BlockBE("/+", "+/", null, true)];
                    ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\")];
                    break;
                default:
                    break;
            }
        }

        if (in_brackets)
        {
            while (!line.empty)
            {
                if ( line.startsWith(ps.brackets.end) )
                {
                    line = line[ps.brackets.end.length .. $];
                    goto Post;
                }
                else if (line[0] == ' ' || line[0] == '\n')
                {
                    if (line[0] == '\n') nl2++;
                    line = line[1..$];
                }
                else
                {
                    auto ne = new Expression(line, ps, this);

                    if (ne.operator == ps.dot && !ne.arguments.empty)
                    {
                        foreach(arg; ne.arguments)
                        {
                            arg.parent = this;
                            arg.index += arguments.length;
                        }

                        arguments ~= ne.arguments;

                        if (ne.postop !is null)
                        {
                            ne.postop.parent = arguments[$-1];
                            ne.postop.index = -ne.arguments.length;
                        }

                        arguments[$-1].postop = ne.postop;
                    }
                    else
                    {
                        ne.parent = this;
                        ne.index = arguments.length;
                        arguments ~= ne;
                    }

                    nl2 = 0;
                }
            }
            assert(0, "Not closed bracket");
        }

        Post:
        if (startsWithDotBracket(line, ps))
        {
            line = line[ps.dot.length .. $];
            auto ne = new Expression(line, ps, this);
            ne.parent = this;
            ne.index = -1;
            postop = ne;
        }

        End:
        auto eline = line;
        while (!eline.empty && (eline[0] == ' ' || eline[0] == '\n'))
        {
            eline = eline[1..$];
        }
        if (eline.empty) line = eline;
    }

    this(string line, bool nofile = false)
    {
        char[] l = line.dup;
        this(l, ParserState.init, null, nofile);
        assert(l.empty);
    }

    void addChild(Expression c)
    {
        c.parent = this;
        c.index = arguments.length;
        arguments ~= c;
    }

    void addChilds(Expression[] cc)
    {
        foreach(i, c; cc)
        {
            c.parent = this;
            c.index = arguments.length + i;
        }

        arguments ~= cc;
    }

    void addPosts(Expression[] cc)
    {
        Expression pp = this;
        while (pp.postop !is null) pp = pp.postop;
        foreach(i, c; cc)
        {
            pp.postop = c;
            c.parent = pp;
            if (c.index >= 0) c.index = -1;
            pp = c;
        }
    }

    Expression popChild()
    {
        if (arguments.empty) return null;
        auto ret = arguments[$-1];
        arguments = arguments[0..$-1];
        return ret;
    }

    void fixParents(Expression p = null, long i = 0)
    {
        parent = p;
        assert(i >= 0 && index >= 0 || i < 0 && index <= 0);
        if (index >= -1)
            index = i;

        foreach (ind, arg; arguments)
        {
            arg.fixParents(this, ind);
        }

        if (postop !is null)
        {
            postop.fixParents(this, -1);
        }
    }

    static string escape(string str, BlockBE be, bool space = true, bool dot = true)
    {
        if (be.escape.empty) return str;

        string res;
        while (!str.empty)
        {
            if (str.startsWith(be.begin) || str.startsWith(be.end) || str.startsWith(be.escape) || space && str.startsWith(" ") || dot && str.startsWith("."))
            {
                res ~= be.escape;
                res ~= str.decodeFront();
            }
            else if (str.startsWith("\n"))
            {
                res ~= be.escape;
                res ~= "n";
                str.decodeFront();
            }
            else if (str.startsWith("\r"))
            {
                res ~= be.escape;
                res ~= "r";
                str.decodeFront();
            }
            else if (str.startsWith("\t"))
            {
                res ~= be.escape;
                res ~= "t";
                str.decodeFront();
            }
            else
            {
                res ~= str.decodeFront();
            }
        }

        return res;
    }

    string save()
    {
        ParserState ps;
        return save(ps);
    }

    string save(ref ParserState ps, int tab = 0, long[] cbr = null, bool force_brackets = false)
    {
        string op = operator;
        string savestr;

        if (bt == BlockType.File)
        {            
        }
        else if (bt == BlockType.Comment)
        {
            return (nl1 > 0 ? '\n'.repeat(nl1).array ~ ' '.repeat(tab*4).array : "").idup ~ op;
        }
        else if (bt == BlockType.String)
        {
            savestr ~= op;
        }
        else
        {
            auto bbe = ps.brackets;
            op = escape(op, bbe);
            savestr ~= op ~ (this.type.empty ? "" : ps.sharp ~ escape(type, bbe)) ~ (this.label.empty ? "" : ps.at ~ escape(label, bbe));
        }

        if (savestr.empty && bt != BlockType.File)
            savestr = ps.dot;

        if (!this.arguments.empty)
        {
            long[] a, b, c;
            foreach(i, arg; this.arguments)
            {
                auto arg2 = arg.postop;
                long j;
                while (arg2 !is null)
                {
                    if (arg2.index < -1)
                    {
                        a ~= i+arg2.index+1;
                        b ~= i;
                        c ~= j;
                    }

                    arg2 = arg2.postop;
                    j++;
                }
            }

            foreach(i, arg; this.arguments)
            {
                foreach(m; a)
                {
                    if (m == i)
                    {
                        savestr ~= " " ~ ps.brackets.begin ~ ps.dot;
                    }
                }
                
                long[] br;
                foreach(j, m; b)
                {
                    if (m == i)
                    {
                        br ~= c[j];
                    }
                }

                if (bt == BlockType.File)
                    savestr ~= arg.save(ps, 0, br, false);
                else
                {
                    auto as = arg.save(ps, tab+1, br, false);
                    if (as.startsWith(" ") || as.startsWith("\n"))
                        savestr ~= as;
                    else
                        savestr ~= " " ~ as;
                }
            }

            if (bt != BlockType.File)
            {
                savestr = ps.brackets.begin ~ savestr ~ 
                    (nl2 > 0 ? '\n'.repeat(nl2).array ~ ' '.repeat(tab*4).array : "").idup ~
                    ps.brackets.end;
            }
        }
        else if (force_brackets || arguments !is null)
        {
            savestr = ps.brackets.begin ~ savestr ~
                (nl2 > 0 ? '\n'.repeat(nl2).array ~ ' '.repeat(tab*4).array : "").idup ~
                ps.brackets.end;
        }
        else if (nl2 > 0)
        {
            savestr ~= ('\n'.repeat(nl2).array ~ ' '.repeat(tab*4).array).idup;
        }

        savestr = (nl1 > 0 ? '\n'.repeat(nl1).array ~ ' '.repeat(tab*4).array : "").idup ~ savestr;

        if (index >= 0)
        {
            long cj = 0;

            auto arg = postop;
            long j;
            while (arg !is null)
            {
                if (cj < cbr.length && cbr[cj] == j)
                {
                    savestr ~= ps.brackets.end;
                    cj++;
                }

                savestr ~= ps.dot ~ arg.save(ps, tab, null, true);
                arg = arg.postop;
                j++;
            }
        }

        return savestr;
    }

    string wrapWithSpaces(string str, string tabstr)
    {
        return (nl1 > 0 ? '\n'.repeat(nl1).array ~ tabstr : "").idup ~ str ~ (nl2 > 0 ? '\n'.repeat(nl2).array : "").idup;
    }

    string beforeSpaces(string tabstr)
    {
        return (nl1 > 0 ? '\n'.repeat(nl1).array ~ tabstr : "").idup;
    }

    string afterSpaces()
    {
        return (nl2 > 0 ? '\n'.repeat(nl2).array : "").idup;
    }

    string saveD(int tab = 0, Expression[] post = null, string ptype = null, string inner = null)
    {
        string savestr;
        string tabstr = "";
        bool negtab;
        if (tab < 0)
        {
            negtab = true;
            tab = -tab;
        }

        if (tab > 0) tabstr = ' '.repeat(tab*4).array;

        bool handled = true;
        switch(ptype)
        {
            case "struct":
            case "module":
            case "class":
            case "function":
            case "ctype":
                if (!this.type.empty && this.type != "constructor")
                {
                    handled = false;
                    break;
                }

                foreach(i, arg; this.arguments)
                {
                    if (ptype == "function")
                    {
                        savestr = arg.saveD(-tab-1) ~ " " ~ savestr;
                    }
                    else
                    {
                        savestr ~= arg.saveD(-tab-1) ~ " ";
                    }
                }

                string poststr = "";
                if (parent !is null && index >= 0 && parent.arguments.length > index)
                {
                    foreach(i, arg; parent.arguments[index..$])
                    {
                        auto ap = arg.postop;
                        while (ap !is null)
                        {
                            //writefln("%s -- %s (%s == %s)", this, ap.index, arg.index + ap.index + 1, this.index);
                            if (arg.index + ap.index + 1 == this.index)
                            {
                                if (ap.operator == "[]")
                                {
                                    savestr =  savestr ~ ap.saveD(tab);

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(-tab-1, null, "ctype");
                                    }
                                }
                                else if (ap.type == "init")
                                {
                                }
                                else
                                {
                                    savestr = ap.saveD(-tab-1) ~ " " ~ savestr;
                                    //writefln("%s -- %s-%s", savestr, index, arg.index);

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(-tab-1, null, "ctype");
                                    }
                                }
                            }
                            else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index + ap.index + 1)
                                return "";

                            ap = ap.postop;
                        }
                    }
                }
                else
                foreach(arg; post ~ (postop is null ? [] : [postop]))
                {
                    if (arg.index == -1)
                    {
                        if (arg.operator == "[]")
                        {
                            savestr =  savestr ~ arg.saveD(tab);
                        }
                        else if (arg.type == "init")
                        {
                        }
                        else
                        {
                            savestr = arg.saveD(-tab-1) ~ " " ~ savestr;
                        }
                    }
                }

                savestr ~= this.operator;

                foreach(arg; post ~ (postop is null ? [] : [postop]))
                {
                    if (arg.index == -1)
                    {
                        if (arg.type == "init")
                        {
                            savestr = savestr ~ arg.saveD(tab);
                        }
                    }
                }

                savestr ~= poststr;

                if (!negtab)
                {
                    savestr = savestr ~ ";";
                }
                savestr = wrapWithSpaces(savestr, tabstr);
                break;

            case "enum":
                savestr ~= beforeSpaces(tabstr) ~ this.operator;
                foreach(i, arg; post ~ (postop is null ? [] : [postop]))
                {
                    savestr =  savestr ~ arg.saveD(tab);
                }
                savestr ~= afterSpaces();
                break;

            case "var":
                if (this.type == ".")
                    handled = false;
                else
                {
                    savestr ~= this.operator;
                    if (!this.arguments.empty)
                        savestr = this.arguments[0].saveD(-tab-1) ~ " " ~ savestr;

                    if (postop !is null)
                    {
                        savestr = postop.saveD(tab, null, this.type) ~ " " ~ savestr;
                    }
                }
                savestr = wrapWithSpaces(savestr, tabstr);
                break;

            default:
                if (bt == BlockType.File)
                {            
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab, null, this.type);
                    }
                }
                else handled = false;
                break;
        }
        
        if (!handled)
        {
            if (bt == BlockType.Comment)
            {
                savestr ~= this.operator;
                savestr = wrapWithSpaces(savestr, tabstr);
            }
            else switch(this.type)
            {
                case "module":
                    savestr ~= beforeSpaces(tabstr) ~ "module "~this.operator~";";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab, null, this.type);
                    }
                    savestr ~= afterSpaces();
                    break;

                case "import":
                    string impstr = "import "~this.arguments[0].operator;
                    if (!arguments[0].arguments.empty)
                    {
                        impstr ~= ": ";
                        foreach (i, arg; arguments[0].arguments)
                        {
                            if (i > 0) impstr ~= ", ";
                            impstr ~= arg.operator;
                            if (arg.postop !is null)
                            {
                                impstr ~= " = " ~ arg.postop.operator;
                            }
                        }
                    }
                    impstr ~= ";";
                    savestr ~= wrapWithSpaces(impstr, tabstr);
                    break;

                case "enum":
                    savestr ~= beforeSpaces(tabstr) ~ "enum "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type) ~ ( i < this.arguments.length-1 ? ", " : "" );
                    }
                    savestr ~= tabstr ~ "}" ~ afterSpaces();
                    break;

                case "init":
                    savestr ~= " = "~this.operator;

                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-tab-1, null, this.type);
                    }
                    break;

                case ":":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-tab-1, null, this.type);
                    }
                    savestr ~= this.type;
                    savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "*":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-tab-1, null, this.type);
                    }
                    savestr ~= this.type;
                    savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "struct":
                    savestr ~= beforeSpaces(tabstr) ~ "struct "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= afterSpaces() ~ tabstr ~ "}";
                    break;

                case "class":
                    savestr ~= beforeSpaces(tabstr) ~ "class "~this.operator;
                    if (arguments[0].type == "superclass")
                        savestr ~= " : " ~ arguments[0].saveD(-tab-1, null, this.type);
                    savestr ~= " {";

                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type != "superclass")
                            savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= afterSpaces() ~ tabstr ~ "}";
                    break;

                case "function":
                    savestr ~= beforeSpaces(tabstr) ~ this.arguments[0].saveD(-tab-1, null, this.type) ~" "~(this.operator.empty?"function":this.operator)~"(";

                    long[] a, b, c;
                    foreach(i, arg; this.arguments)
                    {
                        if (arg.postop !is null)
                        {
                            if (arg.postop.index < -1)
                            {
                                a ~= i+arg.postop.index+1;
                                b ~= i;
                                c ~= 0;
                            }
                        }
                    }

                    Expression[] getPost(long i)
                    {
                        Expression[] e;
                        
                        foreach(j, f; a)
                        {
                            if (i >= f && i < b[j])
                                e ~= this.arguments[b[j]].postop;
                        }

                        return e;
                    }

                    if (this.arguments.length > 1)
                        savestr ~= this.arguments[1].saveD(-tab-1, getPost(1), this.type);
                    if (this.arguments.length > 2)
                    {
                        foreach(i, arg; this.arguments[2..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-tab-1, getPost(i+2), this.type);
                        }
                    }
                    if (postop !is null)
                    {
                        savestr ~= ")";
                        savestr ~= postop.saveD(tab, null, this.type);
                    }
                    else if (!negtab)
                    {
                        savestr ~= ");";
                    }
                    else
                    {
                        savestr ~= ")";
                    }
                    break;

                case "body":
                    savestr ~= beforeSpaces(tabstr) ~ "{";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= afterSpaces() ~ tabstr ~ "}";
                    break;

                case "return":
                case "break":
                case "continue":
                case "goto":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= " " ~ this.arguments[0].saveD(-tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-tab-1, null, this.type);
                        }
                    }

                    if (!negtab)
                    {
                        savestr = savestr ~ ";";
                    }
                    savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "for":
                    savestr ~= beforeSpaces(tabstr) ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(-tab-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[1].saveD(-tab-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[2].saveD(-tab-1, null, this.type) ~ ") ";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab);
                    }
                    savestr ~= afterSpaces();
                    break;

                case "while":
                    savestr ~= beforeSpaces(tabstr) ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(-tab-1, null, this.type) ~ ") ";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab);
                    }
                    savestr ~= afterSpaces();
                    break;

                case "do":
                    savestr ~= beforeSpaces(tabstr) ~ this.type;
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab);
                    }
                    savestr ~= "while (" ~ this.arguments[0].saveD(-tab-1, null, this.type) ~ ");" ~ afterSpaces();
                    break;

                case "foreach":
                    savestr ~= beforeSpaces(tabstr) ~ this.type ~ " (";
                    if (!this.arguments[0].operator.empty)
                        savestr ~= this.arguments[0].saveD(-tab-1, null, this.type) ~ ", ";
                    savestr ~= this.arguments[1].saveD(-tab-1, null, this.type) ~ "; ";
                    savestr ~= this.arguments[2].saveD(-tab-1, null, this.type) ~ ")";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab, null, this.type);
                    }
                    savestr ~= afterSpaces();
                    break;

                case "if":
                    savestr ~= beforeSpaces(tabstr) ~ arguments[0].beforeSpaces(tabstr) ~ "if (" ~ (!operator.empty ? operator~" == " : "") ~ this.arguments[0].saveD(tab, null, this.type) ~ arguments[0].afterSpaces();
                    bool or_need = arguments[0].postop is null;
                    foreach(i, arg; this.arguments[1..$])
                    {
                        if (arg.bt == BlockType.Comment)
                        {
                            savestr ~= arg.beforeSpaces(tabstr) ~ arg.saveD(tab, null, this.type) ~ arg.afterSpaces();
                        }
                        else if (arg.type == "else")
                        {
                            savestr ~= arg.beforeSpaces(tabstr) ~ "else " ~ arg.saveD(tab, null, "else") ~ arg.afterSpaces();
                            or_need = false;
                        }
                        else if (or_need)
                        {
                            savestr ~= arg.beforeSpaces(tabstr) ~ " || " ~ (!operator.empty ? operator~" == " : "") ~ arg.saveD(tab, null, this.type) ~ arg.afterSpaces();
                            or_need = arg.postop is null;
                        }
                        else
                        {
                            savestr ~= arg.beforeSpaces(tabstr) ~ "else if (" ~ (!operator.empty ? operator~" == " : "") ~ arg.saveD(tab, null, this.type) ~ arg.afterSpaces();
                            or_need = arg.postop is null;
                        }
                    }
                    savestr ~= afterSpaces();
                    break;

                case "switch":
                    savestr ~= beforeSpaces(tabstr) ~ "switch (" ~ (!operator.empty ? operator : inner) ~ ")";
                    savestr ~= " {";
                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type == "default")
                            savestr ~= arg.beforeSpaces(tabstr) ~ "    default" ~ arg.saveD(tab+1, null, "case") ~ arg.afterSpaces();
                        else
                            savestr ~= arg.beforeSpaces(tabstr) ~ "    case " ~ arg.saveD(tab+1, null, "case") ~ arg.afterSpaces();
                    }
                    savestr ~= afterSpaces() ~ tabstr ~ "}";
                    break;

                case "var":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-tab-1) ~ " ";
                    }

                    string poststr = "";
                    if (parent !is null && index >= 0 && parent.arguments.length > index)
                    {
                        foreach(i, arg; parent.arguments[index..$])
                        {
                            if (arg.postop !is null)
                            {
                                //writefln("%s -- %s (%s == %s)", this, arg2.app_args, arg.index - arg2.app_args + 1, this.index);
                                if (arg.index + arg.postop.index + 1 == this.index)
                                {
                                    if (arg.postop.operator == "[]")
                                    {
                                        savestr =  savestr ~ arg.postop.saveD(tab);

                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            poststr ~= ", " ~ arg3.saveD(-tab-1, null, "ctype");
                                        }
                                    }
                                    else if (arg.postop.type == "init")
                                    {
                                    }
                                    else
                                    {
                                        savestr = arg.postop.saveD(-tab-1) ~ " " ~ savestr;

                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            poststr ~= ", " ~ arg3.saveD(-tab-1, null, "ctype");
                                        }
                                    }
                                }
                                else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index + arg.postop.index + 1)
                                    return "";
                            }
                        }
                    }
                    else
                    if (postop !is null)
                    {
                        if (postop.index == -1)
                        {
                            if (postop.operator == "[]")
                            {
                                savestr =  savestr ~ postop.saveD(tab);
                            }
                            else if (postop.type == "init")
                            {
                            }
                            else
                            {
                                savestr = postop.saveD(-tab-1) ~ " " ~ savestr;
                            }
                        }
                    }

                    savestr ~= " " ~ this.operator;

                    foreach(i, arg; post ~ (postop is null ? [] : [postop]))
                    {
                        if (arg.index == -1)
                        {
                            if (arg.type == "init")
                            {
                                savestr = savestr ~ arg.saveD(tab);
                            }
                        }
                    }

                    savestr ~= poststr;

                    if (!negtab)
                    {
                        savestr = savestr ~ ";";
                    }
                    savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "default":
                    savestr ~= ":";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab, null, "op");
                    }
                    break;

                case ".":
                    if (!arguments.empty)
                    {
                        savestr ~= this.arguments[0].saveD(-tab-1, null, "op");
                        foreach(i, arg; this.arguments[1..$])
                        {
                            auto next = arg.saveD(-tab-1, null, "op");
                            if (next[0] == '[')
                                savestr ~= next;
                            else if (next == "init")
                                savestr = "(" ~ savestr ~ ")" ~ this.type ~ next;
                            else
                                savestr ~= this.type ~ next;
                        }
                    }

                    if (ptype == "if" && postop !is null)
                    {
                        savestr ~= ") ";
                    }
                    else if (ptype == "case")
                    {
                        savestr ~= ":";
                    }

                    if (postop !is null)
                    {
                        if (postop.type == "switch")
                            savestr = postop.saveD(tab, null, "op", savestr);
                        else
                            savestr ~= postop.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && ptype != "case" && !negtab && postop is null)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else" && ptype != "case")
                        savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "[":
                    savestr ~= "[";
                    if (!arguments.empty)
                    {
                        savestr ~= this.arguments[0].saveD(-tab-1, null, "op");
                        string sep = ", ";
                        foreach(i, arg; this.arguments[1..$])
                        {
                            if (arg.operator == "..") sep = "";
                            savestr ~= sep ~ arg.saveD(-tab-1, null, "op");
                        }
                    }
                    savestr ~= "]";

                    if (ptype == "if" && postop !is null)
                    {
                        savestr ~= ") ";
                    }

                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && !negtab && postop is null)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else")
                        savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "\"":
                    savestr ~= "\"" ~ this.arguments[0].saveD(-tab-1, null, "op");
                    string sep = " ";
                    foreach(i, arg; this.arguments[1..$])
                    {
                        savestr ~= sep ~ arg.saveD(-tab-1, null, "op");
                    }
                    savestr ~= "\"";

                    if (ptype == "if" && postop !is null)
                    {
                        savestr ~= ") ";
                    }

                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && !negtab && postop is null)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else")
                        savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "new":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= " " ~ this.arguments[0].saveD(-tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-tab-1, null, this.type);
                        }
                    }

                    if (postop !is null)
                    {
                        savestr ~= (postop.operator != "[]"?".":"") ~ postop.saveD(-tab-1, null, this.type);
                    }

                    if (!negtab)
                    {
                        savestr = savestr ~ ";";
                    }
                    savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "cast":
                    savestr ~= "(" ~ this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= "(" ~ this.arguments[0].saveD(-tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ") (" ~ arg.saveD(-tab-1, null, this.type);
                        }
                        savestr ~= "))";
                    }

                    if (ptype == "if" && postop !is null)
                    {
                        savestr ~= ") ";
                    }
                    else if (ptype == "case")
                    {
                        savestr ~= ":";
                    }

                    bool body_;
                    if (postop !is null)
                    {
                        if (postop.type == "body")
                        {
                            savestr ~= postop.saveD(tab, null, this.type);
                            body_ = true;
                        }
                        else if (postop.type == "switch")
                        {
                            savestr = postop.saveD(tab, null, "postop", savestr);
                            body_ = true;
                        }
                        else
                            savestr ~= (postop.operator != "[]"?".":"") ~ postop.saveD(-tab-1, null, this.type);
                    }

                    if (ptype != "if" && ptype != "case" && !negtab && !body_)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else" && ptype != "case")
                        savestr = wrapWithSpaces(savestr, tabstr);
                    break;

                case "noop":
                    savestr ~= "{}";
                    if (!negtab)
                    {
                        savestr = wrapWithSpaces(savestr, tabstr);
                    }
                    break;

                case "?":
                    if (arguments.length >= 3)
                    {
                        savestr ~= "(" ~ arguments[0].saveD(-tab-1, null, "op") ~ " ? " ~ arguments[1].saveD(-tab-1, null, "op") ~ " : " ~ arguments[2].saveD(-tab-1, null, "op") ~ ")";
                    }
                    break;
                
                default:
                    switch (this.operator)
                    {
                        case "+":
                        case "-":
                        case "*":
                        case "/":
                        case "^":
                        case "^^":
                        case "~":
                        case "%":
                        case "&":
                        case "&&":
                        case "|":
                        case "||":
                        case "=":
                        case "+=":
                        case "-=":
                        case "*=":
                        case "/=":
                        case "~=":
                        case "==":
                        case "!=":
                        case "<":
                        case ">":
                        case "<=":
                        case ">=":
                        case "is":
                        case "!is":
                        case "in":
                        case "!in":
                            if (!arguments.empty)
                            {
                                if (type == "unary")
                                    savestr ~= this.operator;
                                savestr ~= this.arguments[0].saveD(-tab-1, null, this.operator == "=" && arguments[0].type != "unary"?"var":"op");
                                foreach(i, arg; this.arguments[1..$])
                                {
                                    savestr ~= " " ~ this.operator ~ " " ~ arg.saveD(-tab-1, null, "op");
                                }
                                if (type == "type")
                                    savestr ~= this.operator;
                            }

                            if (!(!negtab && postop is null) && ptype == "op")
                            {
                                savestr = "(" ~ savestr ~ ")";
                            }

                            if (ptype == "if" && postop !is null)
                            {
                                savestr ~= ") ";
                            }

                            if (postop !is null)
                            {
                                if (postop.type == "switch")
                                    savestr = postop.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= postop.saveD(tab, null, "postop");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savestr = savestr ~ ";";
                            }
                            if (ptype != "if" && ptype != "else")
                                savestr = wrapWithSpaces(savestr, tabstr);
                            break;

                        case "++":
                        case "--":
                            if (type == "post")
                            {
                                savestr = arguments[0].saveD(-tab-1, null, "op") ~ operator;
                            }
                            else
                            {
                                savestr = operator ~ arguments[0].saveD(-tab-1, null, "op");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savestr = savestr ~ ";";
                            }
                            if (ptype != "if" && ptype != "else")
                                savestr = wrapWithSpaces(savestr, tabstr);
                            break;

                        case "!":
                            savestr ~= this.operator;
                            if (!arguments.empty)
                                savestr ~= " " ~ this.arguments[0].saveD(-tab-1, null, "op");

                            if (!(!negtab && postop is null) && ptype == "op")
                            {
                                savestr = "(" ~ savestr ~ ")";
                            }

                            if (ptype == "if" && postop !is null)
                            {
                                savestr ~= ") ";
                            }

                            if (postop !is null)
                            {
                                if (postop.type == "switch")
                                    savestr = postop.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= postop.saveD(tab, null, "postop");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savestr = savestr ~ ";";
                            }
                            if (ptype != "if" && ptype != "else")
                                savestr = wrapWithSpaces(savestr, tabstr);
                            break;

                        case "[]":

                            if (!this.arguments.empty)
                            {
                                savestr ~= this.arguments[0].saveD(-tab-1, null, this.type);
                                if (type == "type")
                                {
                                    string of = "";
                                    if (this.arguments.length >= 2)
                                        of = this.arguments[1].saveD(-tab-1, null, this.type);
                                    savestr ~= "["~of~"]";
                                }
                                else
                                {
                                    string sep = ", ";
                                    foreach(i, arg; this.arguments[1..$])
                                    {
                                        if (arg.operator == "..") sep = "";
                                        savestr ~= sep ~ arg.saveD(-tab-1, null, this.type);
                                    }
                                }
                            }

                            if (type != "type")
                                savestr = "[" ~ savestr ~ "]";

                            if (postop !is null)
                            {
                                if (postop.type == "switch")
                                    savestr = postop.saveD(tab, null, "postop", savestr);
                                else if (type == "type")
                                    savestr = postop.saveD(tab, null, "op") ~ " " ~ savestr;
                                else
                                    savestr ~= postop.saveD(tab, null, "postop");
                            }

                            break;

                        case "false":
                        case "true":
                            savestr ~= this.operator;

                            if (ptype == "if" && postop !is null)
                            {
                                savestr ~= ") ";
                            }

                            if (postop !is null)
                            {
                                if (postop.type == "switch")
                                    savestr = postop.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= postop.saveD(tab, null, "postop");
                            }
                            break;

                        default:
                            if (ptype == "postop") savestr ~= ".";

                            savestr ~= this.operator;
                            if (!this.arguments.empty)
                            {
                                bool first = true;
                                auto f = this.arguments[0].saveD(-tab-1, null, this.type);
                                
                                if (f == "!")
                                    savestr ~= "!(";
                                else
                                {
                                    savestr ~= "(" ~ f;
                                    first = false;
                                }

                                foreach(i, arg; this.arguments[1..$])
                                {
                                    if (arg.type == "!")
                                    {
                                        if (i+2 < arguments.length)
                                        {
                                            first = false;
                                            savestr ~= ")(";
                                        }
                                        continue;
                                    }
                                    else if (first)
                                        first = false;
                                    else
                                        savestr ~= ", ";
                                    savestr ~= arg.saveD(-tab-1, null, this.type);
                                }
                                savestr ~= ")";
                            }
                            else if (arguments !is null)
                            {
                                savestr ~= "()";
                            }

                            if (ptype == "if" && postop !is null)
                            {
                                savestr ~= ") ";
                            }
                            else if (ptype == "case")
                            {
                                savestr ~= ":";
                            }

                            bool body_;
                            if (postop !is null)
                            {
                                if (postop.type == "body")
                                {
                                    savestr ~= postop.saveD(tab, null, this.type);
                                    body_ = true;
                                }
                                else if (postop.type == "switch")
                                {
                                    savestr = postop.saveD(tab, null, "postop", savestr);
                                    body_ = true;
                                }
                                else if (ptype == "foreach")
                                {
                                    savestr = postop.saveD(-tab-1, null, this.type) ~ " " ~ savestr;
                                }
                                else
                                    savestr ~= (postop.operator != "[]"?".":"") ~ postop.saveD(-tab-1, null, this.type);
                            }

                            if (ptype != "if" && ptype != "case" && !negtab && !body_)
                            {
                                savestr = savestr ~ ";";
                            }
                            if (ptype != "if" && ptype != "else" && ptype != "case")
                                savestr = wrapWithSpaces(savestr, tabstr);
                            break;
                    }
                    break;
            }
        }

        if (type != "module" && !this.label.empty)
            savestr = this.label ~ ": " ~ savestr;

        return savestr;
    }

    void fixIndent()
    {
        if (type == "body")
        {
            nl1 = 1;
            nl2 = 1;
        }
        else if (parent !is null && (parent.type == "body" || parent.type == "module" || parent.type == "class" || parent.type == "struct" || parent.type == "if" || parent.type == "switch" || parent.type == "enum" || parent.bt == BlockType.File))
        {
            if (type == "module")
            {
                nl1 = 0;
                nl2 = 0;
            }
            else if (type == "class" || type == "struct")
            {
                nl1 = 2;
                nl2 = 1;
            }
            else if (type == "function")
            {
                nl1 = 2;
                nl2 = 0;
            }
            else if (type == "switch")
            {
                nl1 = 1;
                nl2 = 1;
            }
            else
            {
                nl1 = 1;
                nl2 = 0;
            }
        }
        else
        {
            nl1 = 0;
            nl2 = 0;
        }

        foreach (arg; arguments)
        {
            arg.fixIndent();
        }

        if (postop !is null)
        {
            postop.fixIndent();
        }
    }

    void findBlocks (ref Expression code, ref Expression lexemTypes, ref Expression lexer)
    {
        if (type == "code") code = this;
        else if (type == "enum" && operator == "LexemType") lexemTypes = this;
        else if (type == "struct" && operator == "Lexer") lexer = this;

        if (code !is null && lexemTypes !is null && lexer !is null) return;

        foreach (arg; arguments)
        {
            arg.findBlocks(code, lexemTypes, lexer);
        }

        if (postop !is null)
        {
            postop.findBlocks(code, lexemTypes, lexer);
        }
    }

    void replace(Expression ne)
    {
        ne.parent = this.parent;
        ne.index = this.index;
        ne.x = this.x;
        ne.y = this.y;
        ne.r1 = this.r1;
        ne.r2 = this.r2;
        ne.center = this.center;
        if (this.parent !is null)
        {
            if (index >= 0)
            {
                this.parent.arguments[this.index] = ne;
            }
            else
            {
                this.parent.postop = ne;
            }
        }
    }

    void addAfter(Expression ne)
    {
        ne.parent = this.parent;
        ne.index = this.index+1;
        ne.x = this.x;
        ne.y = this.y;
        ne.r1 = this.r1;
        ne.r2 = this.r2;
        ne.center = this.center;
        foreach(arg; this.parent.arguments[this.index+1..$])
        {
            arg.index++;
        }
        this.parent.arguments = this.parent.arguments[0..this.index+1] ~ ne ~ this.parent.arguments[this.index+1..$];
    }

    void toLexer(Expression code, bool main)
    {
        assert(code !is null);
        if (operator == "save")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back2 this)", true);
            code.addChild(ne);
        }
        else if (operator == "back")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" this back2)", true);
            code.addChild(ne);
        }
        else if (type == "switch")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back this)", true);
            code.addChild(ne);

            ne = new Expression("(nextChr)", true);
            code.addChild(ne);

            ne = new Expression("(#if)", true);
            code.addChild(ne);
            
            code = ne;
            assert(code !is null);
        } 
        else if (parent.type == "switch")
        {
            Expression ne;
            if (operator.startsWith("is"))
            {
                ne = new Expression("("~operator~" chr).(#body)", true);
            }
            else if (operator == "!" && arguments[0].operator.startsWith("is"))
            {
                ne = new Expression("(! (#. chr "~arguments[0].operator~")).(#body)", true);
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(== chr "~operator~").(#body)", true);
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(! (#. "~operator~" (find chr) empty)).(#body)", true);
            }
            else if (type == "\"")
            {
                ne = new Expression("(! (#. replace_this (find chr) empty)).(#body)", true);
                auto dc = this.deepcopy;
                ne.arguments[0].arguments[0].replace(dc);
                dc.postop = null;
            }
            else if (type == "default")
            {
                ne = new Expression("(true).(#body (= this back))", true);
            }
            else
            {
                writefln("%s#%s", operator, type);
                assert(0);
            }

            if (postop is null && (code.arguments.empty || code.arguments[$-1].operator != "||" || !code.arguments[$-1].postop.arguments.empty))
            {
                Expression ne2 = new Expression("(||).(#body)", true);

                ne.postop = null;
                ne2.addChild(ne);
                code.addChild(ne2);
            }
            else if (!code.arguments.empty && code.arguments[$-1].operator == "||" && code.arguments[$-1].postop.arguments.empty)
            {
                auto co = code.arguments[$-1];
                ne.postop = null;
                co.addChild(ne);
                if (postop !is null)
                {
                    code = co.postop;
                    assert(code !is null);
                }
            }
            else
            {
                code.addChild(ne);
                code = ne.postop;
                assert(code !is null);
            }
        }
        else if (type == "while")
        {
            Expression ne;

            Expression back = new Expression("(= this back)", true);

            if (arguments.length <= 1)
            {
                if (arguments[0].operator == "!")
                {
                    ne = new Expression("(#do"~(!label.empty?"@"~label:"")~" !).(#body (= back this) nextChr)", true);
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne.arguments[0];
                }
                else
                {
                    ne = new Expression("(#do).(#body (= back this) nextChr)", true);
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne;
                }
            }
            else
            {
                ne = new Expression("(#do ||).(#body (= back this) nextChr)", true);
                code.addChild(ne);
                code.addChild(back);
                
                code = ne.arguments[0];
            }

        } 
        else if (parent.type == "while" && operator != "!" || (parent.operator == "||" || parent.operator == "!") && parent.parent.type == "while")
        {
            Expression ne;
            if (operator.startsWith("is"))
            {
                ne = new Expression("("~operator~" chr)", true);
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(== chr "~operator~")", true);
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(! (#. "~operator~" (find chr) empty))", true);
            }
            else if (type == "\"")
            {
                ne = new Expression("(! (#. replace_this (find chr) empty))", true);
                auto dc = this.deepcopy;
                ne.arguments[0].arguments[0].replace(dc);
                dc.postop = null;
            }
            else
            {
                writefln("%s#%s", operator, type);
                assert(0);
            }

            code.addChild(ne);
        }
        else if (parent.type == "goto")
        {
            Expression ne = new Expression("(#goto "~operator~")", true);
            code.addChild(ne);
        }
        else if (parent.type == "return")
        {
            Expression ne;
            
            if (main)
            {
                ne = new Expression("(= type (#. LexemType "~operator~"))", true);
                code.addChild(ne);
            }

            ne = new Expression("(#return)", true);
            code.addChild(ne);
        }
        else if (operator == "--" || operator == "++")
        {
            code.addChild(this);
            return;
        }

        foreach (arg; arguments)
        {
            arg.toLexer(code, main);
        }

        if (postop !is null)
        {
            postop.toLexer(code, main);
        }
    }

    void toLexer(Expression code, Expression lexer, ref bool[string] lTypes)
    {
        if (type == "return" && arguments.length > 0)
        {
            lTypes[arguments[0].operator] = true;
        }

        if (type == "function")
        {
            if (operator == "Start")
            {
                Expression main = new Expression();
                if (postop !is null)
                {
                    postop.toLexer(main, true);
                }

                if (!main.arguments.empty)
                {
                    code.replace(main.arguments[0]);
                    foreach(arg; main.arguments[1..$])
                    {
                        code.addAfter(arg);
                        code = arg;
                    }
                }
            }
            else
            {
                Expression func = new Expression("("~operator~"#function void).(#body (back#var Lexer) (back2#var Lexer))", true);
                if (postop !is null)
                {
                    postop.toLexer(func.postop, false);
                }

                lexer.addChild(func);
            }
        }

        foreach (arg; arguments)
        {
            arg.toLexer(code, lexer, lTypes);
        }

        if (postop !is null)
        {
            postop.toLexer(code, lexer, lTypes);
        }
    }

    Expression toLexer()
    {
        Expression code, lexemTypes, lexer;
        string text = readText("lexer_templ.np");
        Expression ret = new Expression(text);
        ret.findBlocks(code, lexemTypes, lexer);
        assert(lexemTypes !is null);
        assert(code !is null);

        ret.operator = "lexer_synth.np";
        ret.arguments[0].operator = "lexer_synth";

        bool[string] lTypes = (bool[string]).init;

        toLexer(code, lexer, lTypes);

        foreach(ltype, _; lTypes)
        {
            auto ne = new Expression;
            ne.operator = ltype;
            lexemTypes.addChild(ne);
        }

        return ret;
    }

    static char[] readFile(string filename)
    {
        auto file = File(filename);
        char[] mod;
        foreach(line; file.byLine())
        {
            line = strip(line);
            if ( !mod.empty && mod[$-1] != ' ')
            {
                mod ~= ' ';
            }

            if (line == ".")
            {
                line = ". ".dup;
            }

            mod ~= line;
        }

        return mod;
    }

    Expression deepcopy()
    {
        Expression copy = new Expression();
        copy.operator = operator;
        copy.type = type;
        copy.label = label;
        copy.parent = parent;
        copy.index = index;
        copy.center = center;
        copy.hidden = hidden;
        copy.level = level;
        copy.levels = levels;
        copy.bt = bt;
        
        copy.x = x;
        copy.y = y;
        copy.r1 = r1;
        copy.r2 = r2;
        copy.r3 = r3;
        copy.a1 = a1;
        copy.a2 = a2;

        foreach(arg; arguments)
        {
            copy.arguments ~= arg.deepcopy();
            copy.arguments[$-1].parent = copy;
        }

        if (postop !is null)
        {
            copy.postop = postop.deepcopy();
            copy.postop.parent = copy;
        }

        return copy;
    }

    Expression movecopy()
    {
        auto copy = deepcopy();

        if (index >= 0)
        {
            copy.index++;
            foreach(arg; parent.arguments[index+1..$])
            {
                arg.index++;
            }
            parent.arguments = parent.arguments[0..index+1] ~ copy ~ parent.arguments[index+1..$];
        }

        return copy;
    }

    override string toString()
    {
        return operator ~ (!type.empty ? "#" ~ type : "") ~ (!label.empty ? "@" ~ label : "");
    }
}
