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
import std.ascii: isDigit;
import std.conv;
import std.algorithm;
import std.range: repeat;
import std.array;
import std.string;
import std.file;

import color;

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
    BlockBE parentheses = BlockBE("(", ")", "\\", true);
    BlockBE braces = BlockBE("{", "}", "\\", true);
    string[] delimiters = [" ", "\t", "\n"];
    string sharp = "#";
    string at = "@";
    string dot = ".";
    string line, nline, newline;
    long numline = 1;
}

enum PostfixType
{
    Postfix = -1,
    Prefix = -2,
    InBrace = -3
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
    string[][2][2] texts;
    string[][2] indents;
    int indent;
    bool parentheses;
    BlockType bt;
    Expression[] arguments;
    Expression postop;
    Expression parent;
    ptrdiff_t index;
    ptrdiff_t focus_index;

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

    string getBlock(ref ParserState ps, BlockBE be)
    {
        string sline = ps.line;
        /*string sline = ps.nline;
        string empty_begin = sline[0..ps.line.ptr - sline.ptr];

        if ( !isSpaces(empty_begin) )
        {
            sline = ps.line;
        }*/

        assert(ps.line.startsWith(be.begin));
        ps.line = ps.line[be.begin.length .. $];

        bool escape;
        int nest;
        while (!ps.line.empty)
        {
            if (escape)
            {
                escape = false;
                ps.line.decodeFront();
            }
            else if ( !be.escape.empty && ps.line.startsWith(be.escape) )
            {
                escape = true;
                ps.line = ps.line[be.escape.length .. $];
            }
            else if ( be.nested && ps.line.startsWith(be.begin) )
            {
                nest++;
                ps.line = ps.line[be.begin.length .. $];
            }
            else if ( ps.line.startsWith(be.end) )
            {
                ps.line = ps.line[be.end.length .. $];
                if (be.end == "\n")
                {
                    nextLine(ps, 0, 0, false, "end block "~be.end);
                }
                if (nest == 0) return sline[0..ps.line.ptr - sline.ptr].idup;
                nest--;
            }
            else if (ps.line.startsWith("\n"))
            {
                ps.line.decodeFront();
                nextLine(ps, 0, 0, false, "block "~be.begin~" nl");
            }
            else
            {
                ps.line.decodeFront();
            }
        }

        return sline[0..ps.line.ptr - sline.ptr].idup;
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

    static bool startsWithDotBracket(ParserState ps)
    {
        while (!ps.line.empty)
        {
            if (ps.line[0] == ' ' || ps.line[0] == '\n')
            {
                ps.line = ps.line[1..$];
            }
            else break;
        }

        if (ps.line.startsWith(ps.dot))
        {
            ps.line = ps.line[ps.dot.length .. $];
            if (ps.line.startsWith(ps.dot))
            {
                ps.line = ps.line[ps.dot.length .. $];
            }
            return ps.line.startsWith(ps.parentheses.begin) || ps.line.startsWith(ps.braces.begin);
        }
        return false;
    }

    enum Label
    {
        Arguments = 0,
        Post,
        End
    }

    void calcIndent(long t = 0)
    {
        indent = 0;
        if (texts[t][0].length > 0)
        {
            foreach(dchar chr; texts[t][0][$-1])
            {
                if (chr == ' ')
                    indent++;
                else if (chr == '\t')
                    indent += 8;
                else break;
            }
        }
        //writefln("IND %s %s = %s", this, texts[t], indent);
    }

    void calcIndentRecursive(long t = 0)
    {
        calcIndent(t);

        foreach (ind, arg; arguments)
        {
            arg.calcIndentRecursive(t);
        }

        if (postop)
        {
            postop.calcIndentRecursive(t);
        }
    }

    void cutIndent(long t = 0)
    {
        Expression[] pp = [];
        {
            Expression p = this;
            while (p)
            {
                pp ~= p;
                Expression q;
                do
                {
                    q = p;
                    p = p.parent;
                }
                while (p && (q.index == PostfixType.Prefix || q.index == PostfixType.Postfix));
            }
        }

        foreach_reverse(par; pp[1..$])
        {
            if (indent >= par.indent)
                indent -= par.indent;
        }

        void handle_texts(long te)
        {
            foreach_reverse(par; pp)
            {
                foreach(i, ref line; texts[t][te])
                {
                    string li = line;
                    int sin = 0;
                    if (i > 0)
                    {
                        foreach(dchar chr; line)
                        {
                            if (sin >= par.indent)
                                break;
                            if (chr == ' ')
                            {
                                li = li[1..$];
                                sin++;
                            }
                            else if (chr == '\t')
                            {
                                li = li[1..$];
                                sin += 8;
                            }
                            else break;
                        }
                        //writefln("%s/%s[%s]: %s (%s)", this, par, te, [line, li, line[0..li.ptr - line.ptr]], par.indent);
                        par.indents[t] ~= line[0..li.ptr - line.ptr];
                    }

                    line = li;
                }
            }
        }

        if (index >= 0)
        {
            auto p = this;
            while (p.postop)
            {
                p = p.postop;
            }

            while (p.index < 0)
            {
                if (p.index == PostfixType.Prefix) p.cutIndent(t);
                p = p.parent;
            }
        }

        handle_texts(0);

        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.InBrace) p.cutIndent(t);
                p = p.postop;
            }
        }

        foreach (ind, arg; arguments)
        {
            arg.cutIndent(t);
        }

        handle_texts(1);

        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.Postfix) p.cutIndent(t);
                p = p.postop;
            }
        }

        /*if (!indents[t].empty)
        {
            writefln("%s. texts: %s", this, texts[t]);
            writefln("indent: %s", indent);
            writefln("indents: %s:%s", indents[t].length, indents[t]);
        }*/
    }

    void nextLine(ref ParserState ps, long t, long te, bool middle, string Debug)
    {
        auto lstr = ps.nline[0 .. ps.line.ptr - ps.nline.ptr].idup;

        auto nl = lstr.find("\n");
        assert(nl.empty || nl == "\n");

        if (texts[t][te].empty && ps.nline is ps.newline)
            texts[t][te] ~= ["", lstr];
        else if (texts[t][te].empty || texts[t][te].back.endsWith("\n"))
            texts[t][te] ~= [lstr];
        else
            texts[t][te].back ~= lstr;

        ps.nline = ps.line;
        if (lstr.endsWith("\n"))
            ps.numline++;
        if (!middle || lstr.endsWith("\n"))
            ps.newline = ps.line;
        //writefln("%s: %s. %s %% %s %s", Debug, this, [lstr], te, texts[t][te]);
    }

    static string[] concatTexts(string[] text, string[] add)
    {
        if (text.empty) return add;
        if (add.empty) return text;

        text.back ~= add.front;
        text ~= add[1..$];

        return text;
    }

    this(ref string file, ParserState ps, Expression parent = null, bool nofile = false)
    {
        ps.line = file;
        ps.nline = file;
        ps.newline = file;

        this(ps, parent, nofile);
        cutIndent();
        assert(ps.line.empty);
    }

    this(ref ParserState ps, Expression parent = null, bool nofile = false)
    {
        this.parent = parent;
        string sline = ps.line;

        if (parent is null)
        {
            if (!nofile)
            {
                bt = BlockType.File;
                while (!ps.line.empty)
                {
                    auto ne = new Expression(ps, this);
                    ne.index = arguments.length;
                    arguments ~= ne;
                }
                return;
            }
            else
            {
                ps.comments = [BlockBE("/*", "*/")];
                ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\"), BlockBE("`", "`")];
            }
        }
        else
        {
            texts[0][0] = parent.texts[0][1];
        }

        if (ps.comments.empty)
        {
            while (!ps.line.empty)
            {
                if ( ps.line.startsWith(ps.parentheses.begin) || ps.line.startsWith(ps.braces.begin) )
                {
                    if (ps.line !is sline)
                    {
                        operator = sline[0 .. ps.line.ptr - sline.ptr].idup;
                        if (texts[0][0].empty && ps.nline is ps.newline) texts[0][0] ~= "";
                        texts[0][0] ~= ps.nline[0 .. ps.line.ptr - ps.nline.ptr].idup;
                        calcIndent();
                        bt = BlockType.Comment;
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
                        ps.line.decodeFront();
                    }

                    nextLine(ps, 0, 0, false, "comment");
                }
            }
        }

        Init:
        while (startsWithDelimiter(ps))
        {
            bool nl = ps.line.startsWith("\n");
            ps.line.decodeFront();
            if (nl)
            {
                nextLine(ps, 0, 0, false, "init skip spaces");
            }
        }

        foreach(be; ps.comments)
        {
            if ( ps.line.startsWith(be.begin) )
            {
                operator = getBlock(ps, be);
                bt = BlockType.Comment;
                calcIndent();
                return;
            }
        }

        bool in_brackets;
        BlockBE brackets = ps.parentheses;

        if ( ps.line.startsWith(ps.parentheses.begin) )
        {
            in_brackets = true;
            brackets = ps.parentheses;
            parentheses = true;
        }
        else if ( ps.line.startsWith(ps.braces.begin) )
        {
            in_brackets = true;
            brackets = ps.braces;
            parentheses = false;
        }

        if (in_brackets)
        {
            ps.line = ps.line[brackets.begin.length .. $];
            arguments = [null];
            arguments.length = 0;
            assert(arguments !is null);
        }

        foreach(be; ps.strings)
        {
            if ( ps.line.startsWith(be.begin) )
            {
                operator = getBlock(ps, be);
                bt = BlockType.String;

                if (ps.line.startsWith(ps.sharp))
                {
                    ps.line = ps.line[ps.sharp.length .. $];
                    goto Sharp;
                }
                else if (ps.line.startsWith(ps.at))
                {
                    ps.line = ps.line[ps.at.length .. $];
                    goto At;
                }
                else goto Arguments;
            }
        }

        while (!ps.line.empty)
        {
            if (ps.line.startsWith(ps.parentheses.begin) || ps.line.startsWith(ps.braces.begin))
            {
                goto Arguments;
            }
            else if (ps.line.startsWith(ps.braces.escape))
            {
                ps.line = ps.line[ps.braces.escape.length .. $];
                dchar c = ps.line.decodeFront();
                operator ~= getEscape(c);
            }
            else if (startsWithDelimiter(ps))
            {
                goto Arguments;
            }
            else if (ps.line.startsWith(ps.parentheses.end) || ps.line.startsWith(ps.braces.end))
            {
                if (in_brackets && ps.line.startsWith(brackets.end))
                {
                    if (ps.nline !is ps.line)
                    {
                        nextLine(ps, 0, 0, true, "operator");
                    }
                    ps.line = ps.line[brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (startsWithDotBracket(ps))
            {
                if (in_brackets)
                    goto Arguments;
                else
                    goto Post;
            }
            else if (ps.line.startsWith(ps.sharp))
            {
                ps.line = ps.line[ps.sharp.length .. $];
                goto Sharp;
            }
            else if (ps.line.startsWith(ps.at))
            {
                ps.line = ps.line[ps.at.length .. $];
                goto At;
            }
            else
                operator ~= ps.line.decodeFront();
        }

        Sharp:
        while (!ps.line.empty)
        {
            if (ps.line.startsWith(ps.parentheses.begin) || ps.line.startsWith(ps.braces.begin))
            {
                goto Arguments;
            }
            else if (ps.line.startsWith(ps.braces.escape))
            {
                ps.line = ps.line[ps.braces.escape.length .. $];
                dchar c = ps.line.decodeFront();
                type ~= getEscape(c);
            }
            else if (startsWithDelimiter(ps))
            {
                goto Arguments;
            }
            else if (ps.line.startsWith(ps.parentheses.end) || ps.line.startsWith(ps.braces.end))
            {
                if (in_brackets && ps.line.startsWith(brackets.end))
                {
                    if (ps.nline !is ps.line)
                    {
                        nextLine(ps, 0, 0, true, "type");
                    }
                    ps.line = ps.line[brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (startsWithDotBracket(ps))
            {
                if (in_brackets)
                    goto Arguments;
                else
                    goto Post;
            }
            else if (ps.line.startsWith(ps.at))
            {
                ps.line = ps.line[ps.at.length .. $];
                goto At;
            }
            else
                type ~= ps.line.decodeFront();
        }

        At:
        while (!ps.line.empty)
        {
            if (ps.line.startsWith(ps.parentheses.end) || ps.line.startsWith(ps.braces.end))
            {
                if (in_brackets && ps.line.startsWith(brackets.end))
                {
                    if (ps.nline !is ps.line)
                    {
                        nextLine(ps, 0, 0, true, "label");
                    }
                    ps.line = ps.line[brackets.end.length .. $];
                    goto Post;
                }
                goto End;
            }
            else if (ps.line.startsWith(ps.braces.escape))
            {
                ps.line = ps.line[ps.braces.escape.length .. $];
                dchar c = ps.line.decodeFront();
                label ~= getEscape(c);
            }
            else if (ps.line.startsWith(ps.parentheses.begin) || ps.line.startsWith(ps.braces.begin))
            {
                goto Arguments;
            }
            else if (startsWithDelimiter(ps))
            {
                goto Arguments;
            }
            else if (startsWithDotBracket(ps))
            {
                if (in_brackets)
                    goto Arguments;
                else
                    goto Post;
            }
            else
                label ~= ps.line.decodeFront();
        }

        Arguments:
        if (type == "module")
        {
            switch(label)
            {
                case "D":
                case "Lexer":
                    ps.comments = [BlockBE("//", "\n"), BlockBE("/*", "*/"), BlockBE("/+", "+/", null, true)];
                    ps.strings = [BlockBE("\"", "\"", "\\"), BlockBE("'", "'", "\\"), BlockBE("`", "`")];
                    break;
                default:
                    break;
            }
        }

        if (!in_brackets && ps.nline !is ps.line)
        {
            nextLine(ps, 0, 0, true, "before arguments");
        }

        if ( startsWithDelimitersNL(ps) )
        {
            while (startsWithDelimiter(ps))
            {
                bool nl = ps.line.startsWith("\n");
                ps.line.decodeFront();
                if (nl) break;
            }
        }

        if (ps.nline !is ps.line)
        {
            nextLine(ps, 0, in_brackets ? 0 : 1, true, "before arguments");
        }

        if (in_brackets)
        {
            if (startsWithDotBracket(ps))
            {
                auto savetext = texts[0][1];
                texts[0][1] = [];

                while (!ps.line.empty)
                {
                    if (startsWithDelimiter(ps))
                    {
                        bool nl = ps.line.startsWith("\n");
                        ps.line.decodeFront();
                        if (nl)
                        {
                            nextLine(ps, 0, 1, false, "post in arguments");
                        }
                    }
                    else break;
                }

                assert(ps.line.startsWith(ps.dot));

                ps.line = ps.line[ps.dot.length .. $];
                auto ne = new Expression(ps, this, nofile);
                texts[0][1] = savetext;

                ne.index = PostfixType.InBrace;
                addPosts([ne]);
            }

            while (!ps.line.empty)
            {
                if ( ps.line.startsWith(brackets.end) )
                {
                    ps.line = ps.line[brackets.end.length .. $];
                    goto Post;
                }
                else if (startsWithDelimiter(ps))
                {
                    bool nl = ps.line.startsWith("\n");
                    ps.line.decodeFront();
                    if (nl)
                    {
                        nextLine(ps, 0, 1, false, "arguments");
                    }
                }
                else
                {
                    auto ne = new Expression(ps, this, nofile);

                    if (ne.operator == ps.dot && ne.arguments.empty)
                    {
                        ne.operator = "";
                    }
                    ne.index = arguments.length;
                    arguments ~= ne;

                    texts[0][1] = [];
                }
            }
            assert(0, "Not closed bracket");
        }

        if (ps.nline !is ps.line)
        {
            nextLine(ps, 0, 1, true, "after arguments");
        }

        Post:
        if ( startsWithDelimitersNL(ps) )
        {
            while (startsWithDelimiter(ps))
            {
                bool nl = ps.line.startsWith("\n");
                ps.line.decodeFront();
                if (nl) break;
            }
        }

        if (ps.nline !is ps.line)
        {
            nextLine(ps, 0, in_brackets ? 1 : 0, true, "before post");
        }

        if (startsWithDotBracket(ps))
        {
            auto savetext = texts[0][1];
            texts[0][1] = [];

            while (!ps.line.empty)
            {
                if (startsWithDelimiter(ps))
                {
                    bool nl = ps.line.startsWith("\n");
                    ps.line.decodeFront();
                    if (nl)
                    {
                        nextLine(ps, 0, 1, false, "post");
                    }
                }
                else break;
            }

            assert(ps.line.startsWith(ps.dot));

            ps.line = ps.line[ps.dot.length .. $];
            bool prefix;
            if (ps.line.startsWith(ps.dot))
            {
                prefix = true;
                ps.line = ps.line[ps.dot.length .. $];
            }
            auto ne = new Expression(ps, this, nofile);
            texts[0][1] = savetext;

            //writefln("this: %s %s", this.texts[0][0], this.texts[0][1]);
            //writefln("postop: %s %s", ne.texts[0][0], ne.texts[0][1]);
            if (prefix)
            {
                auto o = ne.operator;
                auto t = ne.type;
                auto l = ne.label;
                auto a = ne.arguments;
                auto p = ne.postop;
                auto q = this.postop;
                auto par = ne.parentheses;
                auto t1 = ne.texts[0][0];
                auto t2 = ne.texts[0][1];

                ne.operator = this.operator;
                ne.type = this.type;
                ne.label = this.label;
                ne.arguments = this.arguments;
                ne.postop = this.postop;
                ne.parentheses = this.parentheses;
                ne.texts[0][0] = this.texts[0][0];
                ne.texts[0][1] = this.texts[0][1];
                ne.calcIndent();

                this.operator = o;
                this.type = t;
                this.label = l;
                this.arguments = a;
                this.postop = p;
                this.parentheses = par;
                if (p) p.parent = this;
                if (q) q.parent = ne;
                this.texts[0][0] = t1;
                this.texts[0][1] = t2;

                foreach(arg; this.arguments)
                {
                    arg.parent = this;
                }

                foreach(arg; ne.arguments)
                {
                    arg.parent = ne;
                }
            }

            ne.index = (prefix ? PostfixType.Prefix : PostfixType.Postfix);
            addPosts([ne]);
        }

        End:
        if (ps.nline !is ps.line)
        {
            nextLine(ps, 0, in_brackets ? 1 : 0, true, "before end");
        }

        auto eline = ps.line;
        while (!eline.empty && (eline[0] == ' ' || eline[0] == '\n'))
        {
            bool nl = (eline[0] == '\n');
            eline = eline[1..$];
            if (nl)
            {
                nextLine(ps, 0, 1, true, "end nl");
                ps.line = eline;
            }
        }
        if (eline.empty) ps.line = eline;
        else if (operator.empty && type.empty && label.empty && arguments.empty)
        {
            auto handled_line = sline[0..ps.line.ptr - sline.ptr];
            writefln("%s (Line %s)", !handled_line.empty ? handled_line : (ps.line.length > 32 ? ps.line[0..32] : ps.line),
                    ps.numline);
            assert(0, "Empty operator");
        }

        if (ps.nline !is ps.line)
        {
            nextLine(ps, 0, 1, true, "end");
        }

        if (nofile)
        {
            texts[0] = [null, null];
        }
        else
        {
            calcIndent();
        }
    }

    this(string line, bool nofile = false)
    {
        this(line, ParserState.init, null, nofile);
    }

    void addChild(Expression c)
    {
        assert(c !is this);
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
        while (pp.postop !is null)
        {
            assert(pp.postop.parent is pp);
            pp = pp.postop;
        }
        foreach(i, c; cc)
        {
            assert(c !is pp);
            pp.postop = c;
            c.parent = pp;
            if (c.index >= 0) c.index = -1;
            pp = c;
        }
    }

    Expression getPostOpN(int n)
    {
        Expression pp = this.postop;
        while (pp !is null && n > 0)
        {
            pp = pp.postop;
            n--;
        }
        return pp;
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
        writefln("FIX %s, parent of %s. i = %s, index = %s", this, p, i, index);
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

    static string escape(string str, BlockBE be, bool space = true)
    {
        if (be.escape.empty) return str;

        string res;
        while (!str.empty)
        {
            if (str.startsWith(be.begin) || str.startsWith(be.end) || str.startsWith(be.escape) || space && str.startsWith(" "))
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

    string saveText(long ti = 0, bool fix = false)
    {
        long thi;
        string savestr, line, indstr;
        return saveText(savestr, line, indstr, thi, ti, [], fix);
    }

    string saveText(ref string savestr, ref string line, ref string indstr, out long thi, long ti, string[][] inds = [], bool fix = false)
    {
        long othi;

        string[][] indc = inds;
            
        if (index >= 0)
        {
            auto p = this;
            while (p.postop)
            {
                p = p.postop;
            }

            while (p.index < 0)
            {
                if (p.index == PostfixType.Prefix) 
                {
                    long oi;
                    p.saveText(savestr, line, indstr, oi, ti, indc, fix);
                    indc = indc[oi..$];
                    othi += oi;
                }
                p = p.parent;
            }
        }

        foreach(i, ind; indents[ti])
        {
            if (indc.length <= i) indc ~= (string[]).init;
            indc[i] ~= ind;
        }

        //writefln("%s, %s", texts[ti], indc);

        void handle_text(long te)
        {
            foreach (i, t; texts[ti][te])
            {
                if (i > 0)
                {
                    if (!indc.empty)
                    {
                        foreach(ind; indc[0])
                        {
                            if (fix)
                            {
                                if (ind.length > 1)
                                {
                                    indstr ~= ind;
                                }
                                else
                                {
                                    line ~= ind;
                                }
                            }
                            else
                            {
                                savestr ~= ind;
                            }
                        }
                        indc = indc[1..$];
                    }
                    thi++;
                }
                if (fix)
                {
                    line ~= t;
                    if (line.endsWith("\n"))
                    {
                        savestr ~= indstr ~ line;
                        indstr = "";
                        line = "";
                    }
                }
                else
                {
                    savestr ~= t;
                }
            }
        }

        handle_text(0);

        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.InBrace)
                {
                    long oi;
                    p.saveText(savestr, line, indstr, oi, ti, indc, fix);
                    indc = indc[oi..$];
                    thi += oi;
                }
                p = p.postop;
            }
        }

        foreach (arg; arguments)
        {
            long oi;
            arg.saveText(savestr, line, indstr, oi, ti, indc, fix);
            writefln("%s. %s: %s %s", this, arg, texts[ti], indents[ti]);
            indc = indc[oi..$];
            thi += oi;
        }

        handle_text(1);
        
        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.Postfix) 
                {
                    long oi;
                    p.saveText(savestr, line, indstr, oi, ti, indc, fix);
                    indc = indc[oi..$];
                    othi += oi;
                }
                p = p.postop;
            }
        }

        //writefln("%s %s %s/%s", this, texts[ti], indents[ti], thi);
        assert(indents[ti].length == thi, "Not used "~ (cast(long)indents[ti].length-thi).text ~" indent");

        thi += othi;

        return savestr;
    }

    int getNL(string[] texts)
    {
        int nl;
        foreach(t; texts)
        {
            if (t.endsWith("\n"))
            {
                nl++;
            }
        }
        return nl;
    }
    
    long getPayload(ref string[] texts)
    {
        long r;
        string[] nt;
        foreach(i, t; texts)
        {
            if (t == "" || t == "\n")
            {
                nt ~= t;
            }
            else if (t.endsWith("\n"))
            {
                nt ~= "\n";
                r = i; 
            }
            else
            {
                nt ~= "";
                r = i; 
            }
        }

        texts = nt;

        return r;
    }

    string getNLStr(string[] texts)
    {
        return '\n'.repeat(getNL(texts)).array;
    }

    static string[] splitNL(string str)
    {
        string[] ret = [""];
        
        foreach(dchar chr; str)
        {
            ret[$-1] ~= chr;
            if (chr == '\n')
                ret ~= string.init;
        }

        if (ret[$-1].empty) ret = ret[0 .. $-1];

        return ret;
    }

    void save()
    {
        ParserState ps;
        return save(ps);
    }

    void save(ref ParserState ps, long t = 0)
    {
        if (texts[0][0].empty)
        {
            texts[0][0] = texts[1][0];
            texts[0][1] = texts[1][1];
            indents[0] = indents[1];
        }

        string op = operator;
        string savestr, endstr;
        long pl1 = getPayload(texts[t][0]);
        long pl2 = getPayload(texts[t][1]);
        //writefln("BEG %s: %s", this, texts[t]);
        bool pnl2 = texts[t][1].length <= 1 ? false : texts[t][1].front.endsWith("\n");

        if (bt == BlockType.File)
        {            
        }
        else if (bt == BlockType.Comment)
        {
            auto nls = splitNL(op);
            long off = texts[t][0].length - nls.length;
            foreach(i, nl; nls)
            {
                texts[t][0][i+off] = nl;
            }
            //writefln("END %s: %s", this, texts[t]);
            return;
        }
        else if (bt == BlockType.String)
        {
            auto bbe = parentheses ? ps.parentheses : ps.braces;
            savestr ~= op ~ (this.type.empty ? "" : ps.sharp ~ escape(type, bbe)) ~ (this.label.empty ? "" : ps.at ~ escape(label, bbe));
        }
        else
        {
            auto bbe = parentheses ? ps.parentheses : ps.braces;
            op = escape(op, bbe);
            savestr ~= op ~ (this.type.empty ? "" : ps.sharp ~ escape(type, bbe)) ~ (this.label.empty ? "" : ps.at ~ escape(label, bbe));
        }

        if (savestr.empty && bt != BlockType.File)
            savestr = "#";

        if (!this.arguments.empty)
        {
            foreach(i, arg; this.arguments)
            {
                arg.save(ps, t);
            }

            if (bt != BlockType.File)
            {
                savestr = (indents[t].empty ? " " : "") ~
                    (index == PostfixType.Postfix || index == PostfixType.InBrace ? ps.dot : "") ~ 
                    (parentheses ? ps.parentheses.begin : ps.braces.begin) ~ savestr;
                endstr ~= (parentheses ? ps.parentheses.end : ps.braces.end) ~ 
                    (index == PostfixType.Prefix ? ps.dot ~ ps.dot : "");
            }
        }
        else if (arguments !is null || parentheses || index < 0)
        {
            savestr = (indents[t].empty ? " " : "") ~
                (index == PostfixType.Postfix || index == PostfixType.InBrace ? ps.dot : "") ~
                (parentheses ? ps.parentheses.begin : ps.braces.begin) ~ savestr;
            endstr ~=
                (parentheses ? ps.parentheses.end : ps.braces.end) ~ 
                (index == PostfixType.Prefix ? ps.dot ~ ps.dot : "");
        }
        else
        {
            savestr = (indents[t].empty ? " " : "") ~
                savestr;
        }

        if (index >= 0)
        {
            auto arg = postop;
            while (arg !is null)
            {
                arg.save(ps, t);
                arg = arg.postop;
            }
        }

        if (!texts[t][0].empty)
        {
            texts[t][0][pl1] = savestr ~ texts[t][0][pl1];
        }
        else
        {
            texts[t][0] = [savestr];
        }

        if (!texts[t][1].empty)
        {
            texts[t][1][pl2] = endstr ~ texts[t][1][pl2];
        }
        else
        {
            texts[t][1] = [endstr];
        }

        //writefln("END %s: %s", this, texts[t]);
        return;
    }

    struct DParms
    {
        int tab;
        string ptype,
               inner,
               prefix,
               postfix,
               ppostfix;

        string* instead,
               endinstead;
    }

    void saveD(DParms dp = DParms.init)
    {
        if (texts[1][0].empty && texts[1][1].empty && indents[1].empty)
        {
            texts[1][0] = texts[0][0];
            texts[1][1] = texts[0][1];
            indents[1] = indents[0];
        }

        //writefln("SD %s ptype=%s", this, dp.ptype);
        auto savetexts = texts[1];
        long pl1 = getPayload(texts[1][0]);
        long pl2 = getPayload(texts[1][1]);

        pl2 = 0;
        if (texts[1][1].length > 1 && texts[1][1][0].empty) pl2 = 1;

        string savestr;
        string endstr;

        string tabstr = "";
        bool negtab;
        if (dp.tab < 0)
        {
            negtab = true;
            dp.tab = -dp.tab;
        }

        if (dp.tab > 0) tabstr = ' '.repeat(dp.tab*4).array;

        bool handled = true;
        switch(dp.ptype)
        {
            case "struct":
            case "module":
            case "class":
            case "function":
            case "ctype":
            case "body":
                if (dp.ptype == "body" ? this.operator != "." : !this.type.empty && this.type != "constructor")
                {
                    handled = false;
                    break;
                }

                savestr ~= " " ~ this.operator;

                if (operator == ".")
                {
                    savestr = "";
                    auto ap = postop;
                    while (ap !is null)
                    {
                        if (ap.operator == "[]")
                        {
                            DParms dp1 = {dp.tab};
                            ap.saveD(dp1);

                            foreach(i3, arg3; arguments)
                            {
                                DParms dp2 = {-dp.tab-1, ptype: "ctype", prefix: i3 > 0 ? ", " : ""};
                                arg3.saveD(dp2);
                            }
                        }
                        else if (ap.operator == "=")
                        {
                            DParms dp1 = {-dp.tab-1};
                            ap.saveD(dp1);
                        }
                        else
                        {
                            DParms dp1 = {-dp.tab-1};
                            ap.saveD(dp1);
                            //writefln("%s -- %s-%s", savestr, index, arg.index);
                            if (ap.index < -1)
                                negtab = true;

                            DParms dp2 = {-dp.tab-1, ptype: "ctype"};
                            foreach(i3, arg3; arguments)
                            {
                                if (i3 == arguments.length - 1)
                                    dp2.postfix = ";";
                                else
                                    dp2.postfix = ",";

                                arg3.saveD(dp2);
                            }
                        }

                        ap = ap.postop;
                    }
                }
                else
                {
                    if (index >= 0)
                    {
                        auto ap = postop;
                        while (ap !is null)
                        {
                            if (ap.index < 0)
                            {
                                if (ap.operator == "[]")
                                {
                                    ap.saveD(DParms(dp.tab));
                                }
                                else if (ap.operator == "=")
                                {
                                    DParms dp1 = {-dp.tab-1};
                                    dp1.ppostfix = dp.postfix;
                                    if (dp.ptype != "function" && (index == parent.arguments.length-1 || parent.operator != "."))
                                    {
                                        dp1.ppostfix = ";";
                                    }
                                    ap.saveD(dp1);
                                    dp.postfix = "";
                                    negtab = true;
                                }
                                else
                                {
                                    ap.saveD(DParms(-dp.tab-1));
                                }
                            }
                            ap = ap.postop;
                        }
                    }

                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1};
                        if (dp.ptype == "function")
                        {
                            dp1.instead = &savestr;
                            dp1.endinstead = &endstr;
                            arg.saveD(dp1);
                        }
                        else
                        {
                            if (i == arguments.length - 1)
                                dp1.postfix = ";";
                            else
                                dp1.postfix = ",";

                            arg.saveD(dp1);
                        }
                    }
                }

                if (!negtab)
                {
                    endstr = ";";
                }
                break;

            case "enum":
                savestr ~= this.operator;
                if (index >= 0)
                {
                    auto arg = postop;
                    while (arg !is null)
                    {
                        DParms dp1 = {dp.tab+1, ptype: this.type, postfix: dp.postfix};
                        arg.saveD(dp1);
                        dp.postfix = "";
                        arg = arg.postop;
                    }
                }
                break;

            case "var":
                if (this.type == ".")
                    handled = false;
                else
                {
                    savestr ~= " " ~ this.operator;
                    if (!this.arguments.empty)
                    {
                        DParms dp1 = {-dp.tab-1, postfix: " ", instead: &savestr, endinstead: &endstr};
                        this.arguments[0].saveD(dp1);
                    }

                    if (index >= 0 && postop !is null)
                    {
                        DParms dp1 = {dp.tab, ptype: this.type};
                        postop.saveD(dp1);
                    }
                }
                break;

            case "import":
                savestr ~= this.operator;
                break;

            default:
                if (bt == BlockType.File)
                {            
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {dp.tab, ptype: this.type};
                        arg.saveD(dp1);
                    }
                }
                else handled = false;
                break;
        }
        
        if (!handled)
        {
            if (bt == BlockType.Comment)
            {
                auto nls = splitNL(this.operator);
                long off = texts[1][0].length - nls.length;
                foreach(i, nl; nls)
                {
                    texts[1][0][i+off] = nl;
                }
                //writefln("END %s: %s", this, texts[t]);
                return;
            }
            else switch(this.type)
            {
                case "module":
                    savestr ~= "module "~this.operator~";";
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {dp.tab, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    break;

                case "import":
                    string impstr = "import "~this.arguments[0].operator;
                    if (!arguments[0].arguments.empty)
                    {
                        impstr ~= ": ";
                        foreach (i, arg; arguments[0].arguments)
                        {
                            DParms dp1 = {dp.tab, ptype: this.type};
                            if (i > 0) dp1.prefix = ", ";
                            arg.saveD(dp1);

                            if (index >= 0 && arg.postop !is null)
                            {
                                DParms dp2 = {dp.tab, ptype: this.type, dp1.prefix = " = "};
                                arg.postop.saveD(dp2);
                            }
                        }
                    }
                    savestr = impstr;
                    endstr = ";";
                    break;

                case "enum":
                    savestr ~= "enum "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {dp.tab+1, ptype: this.type, postfix: ( i < this.arguments.length-1 ? ", " : "" )};
                        arg.saveD(dp1);
                    }
                    endstr ~= "}";
                    break;

                case "init":
                    savestr ~= " = "~this.operator;

                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    break;

                case ":":
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    savestr ~= this.type;
                    break;

                case "*":
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    savestr ~= this.type;
                    break;

                case "struct":
                    savestr ~= "struct "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {dp.tab+1, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    endstr = "}";
                    break;

                case "class":
                    savestr ~= "class "~this.operator;
                    if (arguments[0].type == "superclass")
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: " : "};
                        arguments[0].saveD(dp1);
                    }
                    savestr ~= " {";

                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type != "superclass")
                        {
                            DParms dp1 = {dp.tab+1, ptype: this.type};
                            arg.saveD(dp1);
                        }
                    }
                    endstr = "}";
                    break;

                case "function":
                    savestr ~=  " "~(this.operator.empty?"function":this.operator)~"(";

                    DParms dp1 = {-dp.tab-1, ptype: this.type};
                    this.postop.saveD(dp1);

                    auto post = postop.postop;
                    if (post !is null)
                    {
                        endstr ~= ")";
                        DParms dp2 = {-dp.tab-1, ptype: this.type, ppostfix: " "};
                        post.saveD(dp2);

                        post = post.postop;
                        while (post !is null)
                        {
                            post.saveD(dp2);
                            post = post.postop;
                        }
                    }
                    else if (!negtab)
                    {
                        endstr = ");";
                    }
                    else
                    {
                        endstr = ")";
                    }

                    {
                        foreach(i, arg; this.arguments)
                        {
                            DParms dp2 = {-dp.tab-1, this.type};
                            if (i < arguments.length - 1)
                                dp2.postfix = ", ";
                            arg.saveD(dp2);
                        }
                    }

                    break;

                case "body":
                    if (parentheses)
                        savestr ~= "{";
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {dp.tab+1, ptype: this.type};
                        arg.saveD(dp1);
                    }
                    if (parentheses)
                        endstr = "}";
                    break;

                case "return":
                case "break":
                case "continue":
                case "goto":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= " ";
                        foreach(i, arg; this.arguments)
                        {
                            DParms dp1 = {-dp.tab-1, ptype: this.type};
                            if (i < arguments.length - 1)
                                dp1.postfix = ", ";
                            arg.saveD(dp1);
                        }
                    }

                    if (!negtab)
                    {
                        if (!this.arguments.empty)
                            endstr = ";";
                        else
                            savestr ~= ";";
                    }
                    break;

                case "for":
                    savestr ~= this.type;
                    DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: " (", ppostfix: "; "};
                    DParms dp2 = {-dp.tab-1, ptype: this.type, prefix: "", ppostfix: "; "};
                    DParms dp3 = {-dp.tab-1, ptype: this.type, prefix: "", ppostfix: ") "};
                    this.arguments[0].saveD(dp1);
                    this.arguments[1].saveD(dp2);
                    this.arguments[2].saveD(dp3);
                    if (index >= 0 && postop !is null)
                    {
                        postop.saveD(DParms(dp.tab));
                    }
                    break;

                case "while":
                    savestr ~= this.type;
                    DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: " (", ppostfix: ") "};
                    this.arguments[0].saveD(dp1);
                    if (index >= 0 && postop !is null)
                    {
                        postop.saveD(DParms(dp.tab));
                    }
                    break;

                case "do":
                    savestr ~= this.type;
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: "while (", ppostfix: ");"};
                        arg.saveD(dp1);
                    }

                    if (index >= 0 && postop !is null)
                    {
                        DParms dp1 = {dp.tab+1, ptype: this.type};
                        postop.saveD(dp1);
                    }
                    break;

                case "foreach_reverse":
                case "foreach":
                    savestr ~= this.type ~ " (";
                    DParms dp1 = {-dp.tab-1, ptype: "foreach", prefix: "", ppostfix: ", "};
                    DParms dp2 = {-dp.tab-1, ptype: "foreach", prefix: "", ppostfix: "; "};
                    DParms dp3 = {-dp.tab-1, ptype: "foreach", prefix: "", ppostfix: ")"};
                    if (arguments[0].operator.empty)
                        dp1.ppostfix = "";
                    this.arguments[0].saveD(dp1);
                    this.arguments[1].saveD(dp2);
                    this.arguments[2].saveD(dp3);
                    if (index >= 0 && postop !is null)
                    {
                        DParms dp4 = {dp.tab, ptype: "foreach"};
                        postop.saveD(dp4);
                    }
                    break;

                case "if":
                    bool or_need = arguments[0].postop is null;
                    DParms dp1 = {dp.tab, ptype: this.type, prefix: "if (" ~ (!operator.empty ? operator~" == " : ""), ppostfix: or_need ? "" : ")"};
                    this.arguments[0].saveD(dp1);
                    foreach(i, arg; this.arguments[1..$])
                    {
                        if (arg.bt == BlockType.Comment)
                        {
                            DParms dp2 = {dp.tab, ptype: this.type};
                            arg.saveD(dp2);
                        }
                        else if (arg.type == "else")
                        {
                            DParms dp2 = {dp.tab, ptype: "else", prefix: "else "};
                            arg.saveD(dp2);
                            or_need = false;
                        }
                        else if (or_need)
                        {
                            or_need = arg.postop is null;
                            DParms dp2 = {dp.tab, ptype: this.type, prefix: " || " ~ (!operator.empty ? operator~" == " : ""), ppostfix: or_need ? "" : ")"};
                            arg.saveD(dp2);
                        }
                        else
                        {
                            or_need = arg.postop is null;
                            DParms dp2 = {dp.tab, ptype: this.type, prefix: "else if (" ~ (!operator.empty ? operator~" == " : ""), ppostfix: or_need ? "" : ")"};
                            arg.saveD(dp2);
                        }
                    }
                    break;

                case "switch":
                    savestr ~= "switch (" ~ (!operator.empty ? operator : dp.inner) ~ ")";
                    savestr ~= " {";
                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type == "default")
                        {
                            DParms dp1 = {dp.tab+1, ptype: "case", prefix: "default"};
                            arg.saveD(dp1);
                        }
                        else
                        {
                            DParms dp1 = {dp.tab+1, ptype: "case", prefix: "case "};
                            arg.saveD(dp1);
                        }
                    }
                    endstr ~= "}";
                    break;

                case "var":
                    savestr ~= " " ~ this.operator;

                    if (index >= 0)
                    {
                        auto ap = postop;
                        while (ap !is null)
                        {
                            //writefln("SD3 this=\"%s\", ap=\"%s\"", this, ap);
                            if (ap.operator == "[]")
                            {
                                ap.saveD(DParms(dp.tab));
                            }
                            else if (ap.type == "init")
                            {
                                ap.saveD(DParms(dp.tab));
                            }
                            else if (ap.operator == "=")
                            {
                                negtab = true;
                                DParms dp1 = {dp.tab, ppostfix: ";"};
                                ap.saveD(dp1);
                            }
                            else
                            {
                                DParms dp1 = {-dp.tab-1, ppostfix: " "};
                                ap.saveD(dp1);
                            }
                            ap = ap.postop;
                        }
                    }

                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ppostfix: " "};
                        arg.saveD(dp1);
                    }

                    if (!negtab)
                    {
                        endstr = ";";
                    }
                    break;

                case "alias":
                    savestr ~= this.type ~ " " ~ this.operator ~ " = ";

                    foreach(i, arg; this.arguments)
                    {
                        DParms dp1 = {-dp.tab-1, ppostfix: " "};
                        arg.saveD(dp1);
                    }

                    if (!negtab)
                    {
                        endstr = ";";
                    }
                    break;

                case "default":
                    savestr ~= ":";
                    if (index >= 0 && postop !is null)
                    {
                        DParms dp1 = {dp.tab, ptype: "op"};
                        postop.saveD(dp1);
                    }
                    break;

                case ".":
                    if (!arguments.empty)
                    {
                        foreach(i, arg; this.arguments)
                        {
                            string catchstr, ecatchstr;
                            DParms dp2 = {-dp.tab-1, ptype: "op", prefix: (i > 0) ? this.type : ""};
                            if (postop !is null && postop.type == "switch")
                            {
                                dp2.instead = &catchstr;
                                dp2.endinstead = &ecatchstr;
                            }
                            if (arg.type == "[")
                            {
                                dp2.prefix = "";
                            }
                            else if (arg.operator == "init")
                                savestr = "(" ~ savestr ~ ")";
                            arg.saveD(dp2);
                            if (postop !is null && postop.type == "switch")
                            {
                                savestr ~= catchstr;
                                endstr ~= ecatchstr;
                            }
                        }
                    }

                    if (dp.ptype == "case")
                    {
                        savestr ~= ":";
                    }

                    if (index >= 0 && postop !is null)
                    {
                        if (postop.type == "switch")
                        {
                            DParms dp1 = {dp.tab, ptype: "op", inner: savestr};
                            postop.saveD(dp1);
                            savestr = "";
                        }
                        else
                        {
                            DParms dp1 = {dp.tab, ptype: "op"};
                            postop.saveD(dp1);
                        }
                    }

                    if (dp.ptype != "if" && dp.ptype != "case" && !negtab && postop is null)
                    {
                        endstr = ";";
                    }
                    break;

                case "[":
                    savestr ~= "[";
                    if (!arguments.empty)
                    {
                        string sep = ", ";
                        if (arguments.length >= 3 && arguments[1].operator == "..") sep = "";
                        foreach(i, arg; this.arguments)
                        {
                            DParms dp2 = {-dp.tab-1, ptype: "op"};
                            if (i < arguments.length-1)
                                dp2.postfix = sep;
                            arg.saveD(dp2);
                        }
                    }
                    endstr ~= "]";

                    if (index >= 0 && postop !is null)
                    {
                        DParms dp1 = {dp.tab, ptype: "op"};
                        postop.saveD(dp1);
                    }

                    if (dp.ptype != "if" && !negtab && postop is null)
                    {
                        endstr ~= ";";
                    }
                    break;

                case "\"":
                    savestr ~= "\"";
                    string sep = " ";
                    foreach(i, arg; this.arguments)
                    {
                        DParms dp2 = {-dp.tab-1, ptype: "op"};
                        if (i < arguments.length-1)
                            dp2.postfix = sep;
                        arg.saveD(dp2);
                    }
                    endstr ~= "\"";

                    if (index >= 0 && postop !is null)
                    {
                        DParms dp2 = {dp.tab, ptype: "op"};
                        postop.saveD(dp2);
                    }

                    if (dp.ptype != "if" && !negtab && postop is null)
                    {
                        endstr ~= ";";
                    }
                    break;

                case "new":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        foreach(i, arg; this.arguments)
                        {
                            DParms dp2 = {-dp.tab-1, ptype: this.type};
                            if (i < arguments.length-1)
                                dp2.postfix = ", ";
                            arg.saveD(dp2);
                        }
                    }

                    if (index >= 0 && postop !is null)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: (postop.operator != "[]"?".":"")};
                        postop.saveD(dp1);
                    }

                    if (!negtab)
                    {
                        endstr = ";";
                    }
                    break;

                case "cast":
                    savestr ~= "(" ~ this.type;
                    if (!this.arguments.empty)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: "("};
                        this.arguments[0].saveD(dp1);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            DParms dp2 = {-dp.tab-1, ptype: this.type, prefix: ") ("};
                            arg.saveD(dp2);
                        }
                        endstr = "))";
                    }

                    if (dp.ptype == "case")
                    {
                        endstr ~= ":";
                    }

                    bool body_;
                    if (index >= 0 && postop !is null)
                    {
                        if (postop.type == "body")
                        {
                            DParms dp1 = {dp.tab, ptype: this.type};
                            postop.saveD(dp1);
                            body_ = true;
                        }
                        else if (postop.type == "switch")
                        {
                            DParms dp1 = {dp.tab, ptype: this.type, inner: savestr};
                            postop.saveD(dp1);
                            savestr = "";
                            body_ = true;
                        }
                        else
                        {
                            DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: (postop.operator != "[]"?".":"")};
                            postop.saveD(dp1);
                        }
                    }

                    if (dp.ptype != "if" && dp.ptype != "case" && !negtab && !body_)
                    {
                        endstr ~= ";";
                    }
                    break;

                case "noop":
                    savestr ~= "{}";
                    break;

                case "?":
                    if (arguments.length >= 3)
                    {
                        DParms dp1 = {-dp.tab-1, ptype: "op", prefix: "("};
                        DParms dp2 = {-dp.tab-1, ptype: "op", prefix: "?"};
                        DParms dp3 = {-dp.tab-1, ptype: "op", prefix: ":", postfix: ")"};

                        arguments[0].saveD(dp1);
                        arguments[1].saveD(dp2);
                        arguments[2].saveD(dp3);
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
                                if (arguments.length == 1)
                                    savestr ~= " "~this.operator~" ";
                                DParms dp1 = {-dp.tab-1, ptype: this.operator == "=" && arguments.length == 2?"var":"op"};
                                this.arguments[0].saveD(dp1);
                                foreach(i, arg; this.arguments[1..$])
                                {
                                    DParms dp2 = {-dp.tab-1, ptype: "op", prefix: " " ~ this.operator ~ " "};
                                    arg.saveD(dp2);
                                }
                                if (type == "type")
                                    savestr ~= this.operator;
                            }

                            if (parentheses)
                            {
                                savestr = "(" ~ savestr;
                                endstr = ")";
                            }

                            if (index >= 0 && postop !is null)
                            {
                                if (postop.type == "switch")
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop", inner: savestr};
                                    postop.saveD(dp1);
                                    savestr = "";
                                }
                                else
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop"};
                                    postop.saveD(dp1);
                                }
                            }

                            if (dp.ptype != "if" && !negtab && postop is null)
                            {
                                endstr = ";";
                            }
                            break;

                        case "++":
                        case "--":
                            if (type == "post")
                            {
                                DParms dp1 = {-dp.tab-1, ptype: "op", postfix: operator};
                                arguments[0].saveD(dp1);
                            }
                            else
                            {
                                DParms dp1 = {-dp.tab-1, ptype: "op", prefix: operator};
                                arguments[0].saveD(dp1);
                            }

                            if (dp.ptype != "if" && !negtab && postop is null)
                            {
                                endstr = ";";
                            }
                            break;

                        case "!":
                            savestr ~= this.operator;
                            if (!arguments.empty)
                            {
                                DParms dp1 = {-dp.tab-1, ptype: "op"};
                                this.arguments[0].saveD(dp1);
                            }

                            if (parentheses)
                            {
                                savestr = "(" ~ savestr;
                                endstr = ")";
                            }

                            if (index >= 0 && postop !is null)
                            {
                                if (postop.type == "switch")
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop", inner: savestr};
                                    postop.saveD(dp1);
                                    savestr = "";
                                }
                                else
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop"};
                                    postop.saveD(dp1);
                                }
                            }

                            if (dp.ptype != "if" && !negtab && postop is null)
                            {
                                endstr = ";";
                            }
                            break;

                        case "[]":

                            if (!this.arguments.empty)
                            {
                                if (type == "type")
                                {
                                    string of = "", ofe = "";
                                    string el = "", oel = "";
                                    DParms dp1 = {-dp.tab-1, ptype: this.type, instead: &of, endinstead: &ofe};
                                    this.arguments[0].saveD(dp1);
                                    if (this.arguments.length >= 2)
                                    {
                                        DParms dp2 = {-dp.tab-1, ptype: this.type, instead: &el, endinstead: &oel};
                                        this.arguments[1].saveD(dp2);
                                    }
                                    savestr ~= el~"["~of~"]";
                                }
                                else
                                {
                                    string sep = ", ";
                                    if (arguments.length >= 3 && arguments[1].operator == "..") sep = "";
                                    foreach(i, arg; this.arguments)
                                    {
                                        DParms dp2 = {-dp.tab-1, ptype: this.type};
                                        if (i < arguments.length-1)
                                            dp2.postfix = sep;
                                        arg.saveD(dp2);
                                    }
                                }
                            }

                            if (type != "type")
                            {
                                savestr = "[" ~ savestr;
                                endstr = "]";
                            }

                            if (index >= 0 && postop !is null)
                            {
                                if (postop.type == "switch")
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop", inner: savestr};
                                    postop.saveD(dp1);
                                    savestr = "";
                                }
                                else if (type == "type")
                                {
                                    DParms dp1 = {dp.tab, ptype: "op", postfix: " " ~ savestr};
                                    postop.saveD(dp1);
                                }
                                else
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop"};
                                    postop.saveD(dp1);
                                }
                            }

                            break;

                        case "false":
                        case "true":
                            savestr ~= this.operator;

                            if (index >= 0 && postop !is null)
                            {
                                if (index >= 0 && postop.type == "switch")
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop", inner: savestr};
                                    postop.saveD(dp1);
                                    savestr = "";
                                }
                                else
                                {
                                    DParms dp1 = {dp.tab, ptype: "postop"};
                                    postop.saveD(dp1);
                                }
                            }
                            break;

                        default:
                            if (dp.ptype == "postop") savestr ~= ".";

                            savestr ~= this.operator;
                            if (index < 0) savestr ~= " ";
                            if (!this.arguments.empty)
                            {
                                DParms dp1 = {-dp.tab-1, ptype: this.type};
                                if (arguments.length > 1)
                                    dp1.ppostfix = ", ";
                                this.arguments[0].saveD(dp1);
                                
                                if (arguments[0].operator == "!")
                                    savestr ~= "!(";
                                else
                                {
                                    savestr ~= "(";
                                }

                                foreach(i, arg; this.arguments[1..$])
                                {
                                    DParms dp2 = {-dp.tab-1, ptype: this.type};
                                    if (arg.type == "!")
                                    {
                                        if (i+2 < arguments.length)
                                            savestr ~= ")(";
                                        continue;
                                    }
                                    else if (i < arguments.length-2)
                                        dp2.ppostfix = ", ";
                                    arg.saveD(dp2);
                                }
                                endstr ~= ")";
                            }
                            else if (parentheses)
                            {
                                savestr ~= "()";
                            }

                            if (dp.ptype == "case")
                            {
                                savestr ~= ":";
                            }
                            //writefln("SD2 %s \"%s\"", this, savestr);

                            auto ap = postop;
                            if (index >= 0)
                            {
                                while (ap !is null)
                                {
                                    if (ap.type == "body")
                                    {
                                        DParms dp1 = {dp.tab, ptype: this.type};
                                        ap.saveD(dp1);
                                        negtab = true;
                                    }
                                    else if (ap.type == "switch")
                                    {
                                        DParms dp1 = {dp.tab, ptype: "ap", inner: savestr};
                                        ap.saveD(dp1);
                                        savestr = "";
                                        negtab = true;
                                    }
                                    else if (dp.ptype == "foreach")
                                    {
                                        DParms dp1 = {-dp.tab-1, ptype: this.type};
                                        ap.saveD(dp1);
                                    }
                                    else
                                    {
                                        DParms dp1 = {-dp.tab-1, ptype: this.type, prefix: (ap.operator != "[]"?".":"")};
                                        if (dp.ptype != "if" && dp.ptype != "case" && !negtab)
                                            dp1.postfix = ";";
                                        ap.saveD(dp1);
                                        negtab = true;
                                    }
                                    ap = ap.postop;
                                }
                            }

                            if (dp.ptype != "if" && dp.ptype != "case" && !negtab)
                            {
                                endstr ~= ";";
                            }
                            break;
                    }
                    break;
            }
        }

        if (type != "module" && !this.label.empty)
            savestr = this.label ~ ": " ~ savestr;

        exit:

        savestr = dp.prefix ~ savestr ~ dp.postfix;
        endstr ~= dp.ppostfix;

        if (dp.instead && dp.endinstead)
        {
            swap(savestr, *dp.instead);
            swap(endstr, *dp.endinstead);
        }
        
        if (!texts[1][0].empty)
        {
            texts[1][0][pl1] = savestr ~ texts[1][0][pl1];
        }
        else
        {
            texts[1][0] = [savestr];
        }

        if (!texts[1][1].empty)
        {
            texts[1][1][pl2] = endstr ~ texts[1][1][pl2];
        }
        else
        {
            texts[1][1] = [endstr];
        }

        writefln("OK %s %s (WAS %s) ptype=%s prefix=\"%s\" postfix=\"%s\" tab=%s",
                this, texts[1], savetexts, dp.ptype, dp.prefix, dp.postfix, dp.tab);
        return;
    }

    int fixIndent(long t = 0)
    {
        if (type == "module" || bt == BlockType.File)
            indent = 0;
        else if (index < 0)
            indent = 0;
        else
            indent = 4;

        auto tabstr = ' '.repeat(indent).array.idup;
        int ret;

        if (texts[t][0].empty && texts[t][1].empty)
        {
            if (type == "body" || type == "do")
            {
                texts[t] = [["\n", tabstr], ["\n", tabstr]];
                ret += 2;
            }
            else if (parent !is null && (parent.type == "body" || index >= 0 && parent.type == "do" || parent.type == "module" || parent.type == "class" || parent.type == "struct" || parent.type == "if" || parent.type == "switch" || parent.type == "enum" || parent.bt == BlockType.File))
            {
                if (type == "module")
                {
                    texts[t] = [[" "], []];
                }
                else if (type == "class" || type == "struct")
                {
                    texts[t] = [["\n", "\n", tabstr], ["\n", tabstr]];
                    ret += 3;
                }
                else if (type == "function")
                {
                    texts[t] = [["\n", "\n", tabstr], []];
                    ret += 2;
                }
                else if (type == "switch")
                {
                    texts[t] = [["\n", tabstr], ["\n", tabstr]];
                    ret += 2;
                }
                else
                {
                    texts[t] = [["\n", tabstr], []];
                    ret += 1;
                }
            }
            else
            {
                texts[t] = [[" "], []];
            }
        }
        else
        {
            if (texts[t][0].length > 1)
                ret += texts[t][0].length-1;
            if (texts[t][1].length > 1)
                ret += texts[t][1].length-1;
        }

        if (index >= 0)
        {
            auto p = this;
            while (p.postop)
            {
                p = p.postop;
            }

            while (p.index < 0)
            {
                if (p.index == PostfixType.Prefix) ret += p.fixIndent(t);
                p = p.parent;
            }
        }

        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.InBrace) ret += p.fixIndent(t);
                p = p.postop;
            }
        }

        foreach (arg; arguments)
        {
            ret += arg.fixIndent(t);
        }

        if (indents[t].length != ret)
            indents[t] = tabstr.repeat(ret).array;

        if (index >= 0)
        {
            auto p = postop;
            while (p)
            {
                if (p.index == PostfixType.Postfix) ret += postop.fixIndent(t);
                p = p.postop;
            }
        }

        return ret;

        /*if (!(type == "body" || parent !is null && (parent.type == "body" || parent.type == "module" || parent.type == "class" || parent.type == "struct" || parent.type == "if" || parent.type == "switch" || parent.type == "enum" || parent.bt == BlockType.File)))
        {
            indent = 1;
        }*/
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
        else if (operator == "nextChr")
        {
            code.addChild(this);
        }
        else if (type == "switch" && operator.empty)
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
        else if (parent.type == "switch" && parent.operator.empty)
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
        else if (type == "switch")
        {
            Expression ne = new Expression;
            ne.operator = operator;
            ne.type = type;

            code.addChild(ne);
            
            code = ne;
        }
        else if (parent.type == "switch")
        {
            Expression ne;
            if (postop)
            {
                ne = new Expression(operator~(!type.empty ? "#"~type : "")~".(#body)", true);
                ne.postop.index = postop.index;
            }
            else
            {
                ne = new Expression();
                ne.operator = operator;
            }

            code.addChild(ne);
            code = ne.postop;
        }
        else if (type == "while")
        {
            Expression ne;

            Expression back = new Expression("(= this back)", true);

            if (arguments.length <= 1)
            {
                if (arguments[0].operator == "!")
                {
                    ne = new Expression("(#do"~(!label.empty?"@"~label:"")~".(#body (= back this) nextChr) !)", true);
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne.arguments[0];
                }
                else
                {
                    ne = new Expression("(#do.(#body (= back this) nextChr))", true);
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne;
                }
            }
            else
            {
                ne = new Expression("(#do.(#body (= back this) nextChr) ||)", true);
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
        else if (type == "break")
        {
            Expression ne;
            ne = new Expression("#break", true);
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

    string toParentsString()
    {
        string ret = this.text();
        auto p = parent;
        while (p)
        {
            ret ~= " <== " ~ p.text();
            p = p.parent;
        }
        return ret;
    }
}
