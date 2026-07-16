/**
 * expression.d
 */

module expression;

import std.stdio;
import std.math;
import std.datetime;
import std.algorithm.searching;
import std.algorithm.mutation;
import std.conv;
import std.range.primitives;
import std.utf;
import std.algorithm;
import std.range: repeat;
import std.array;
import std.string;
import std.file;

import lexer;
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
    uint row = 1;
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
    int row;
    int block, level, levels;
    Expression center;
    bool hidden;

    Lexem operator_lexem;
    Lexem type_lexem;
    Lexem open_lexem, close_lexem;
    int nl1, nl2;

    Position start_pos_val, end_pos_val;
    bool start_pos_calc, end_pos_calc;

    Position start_pos()
    {
        if (start_pos_calc) return start_pos_val;
        Position pos = operator_lexem.start;
        if (pos.row == 0 || type_lexem.start.row > 0 && type_lexem.start < pos) pos = type_lexem.start;
        if (pos.row == 0 || open_lexem.start.row > 0 && open_lexem.start < pos) pos = open_lexem.start;
        
        foreach(arg; arguments)
        {
            Position spos = arg.start_pos();
            if (pos.row == 0 || spos.row > 0 && spos < pos) pos = spos;
        }

        start_pos_val = pos;
        start_pos_calc = true;
        return pos;
    }

    uint start_row()
    {
        return start_pos().row;
    }

    Position end_pos()
    {
        if (end_pos_calc) return end_pos_val;
        Position pos = operator_lexem.end;
        if (type_lexem.end > pos) pos = type_lexem.end;
        if (close_lexem.end > pos) pos = close_lexem.end;

        foreach(arg; arguments)
        {
            Position spos = arg.end_pos();
            if (spos > pos) pos = spos;
        }

        end_pos_val = pos;
        end_pos_calc = true;
        return pos;
    }

    uint end_row()
    {
        return end_pos().row;
    }

    string operator;
    string type;
    string label;

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

        Init:
        while (!line.empty && (line[0] == ' ' || line[0] == '\n'))
        {
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

        operator_lexem.text = operator;
        type_lexem.text = type;
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
        assert(p !is this);
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

    string save(bool inp = false)
    {
        ParserState ps;
        return save(ps, inp);
    }

    string lexem_lines(Lexem lexem, bool include_end = false)
    {
        return (lexem.text !is null && lexem.start.row > 0 ? ":" ~ lexem.start.row.text ~ ":" ~ lexem.start.col.text ~ 
                (include_end && lexem.end.row > 0 ? "-" ~ ":" ~ lexem.end.row.text ~ ":" ~ lexem.end.col.text : "") : "");
    }

    string save(ref ParserState ps, bool inp = false, int tab = 0, long[] cbr = null, bool force_brackets = false)
    {
        string savestr;

        uint srow = start_row();
        string prewhites = (srow > ps.row ? '\n'.repeat(srow - ps.row).array ~ ' '.repeat(tab*4).array : "").idup;
        if (srow > ps.row) ps.row = srow;

        if (bt == BlockType.File)
        {            
        }
        else if (bt == BlockType.Comment)
        {
            savestr = (srow > ps.row ? '\n'.repeat(srow - ps.row).array ~ ' '.repeat(tab*4).array : "").idup;
            if (srow > ps.row) ps.row = srow;

            if (inp)
            {
                savestr ~= lexem_lines(operator_lexem, true);
            }
            else
            {
                savestr ~= operator;
            }

            return savestr;
        }
        else if (bt == BlockType.String)
        {
            if (inp)
            {
                savestr ~= lexem_lines(operator_lexem, true);
            }
            else
            {
                savestr ~= operator;
            }
        }
        else
        {
            auto bbe = ps.brackets;
            if (inp)
            {
                savestr ~= lexem_lines(operator_lexem) ~ (this.type.empty ? "" : ps.sharp ~ lexem_lines(type_lexem)) ~ (open_lexem.text.empty && close_lexem.text.empty ? "" : "[" ~ lexem_lines(open_lexem) ~ "-" ~ lexem_lines(close_lexem) ~ "]" );
            }
            else
            {
                savestr ~= escape(operator, bbe) ~ (this.type.empty ? "" : ps.sharp ~ escape(type, bbe)) ~ (this.label.empty ? "" : ps.at ~ escape(label, bbe));
            }
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
                    savestr ~= arg.save(ps, inp, 0, br, false);
                else
                {
                    auto as = arg.save(ps, inp, tab+1, br, false);
                    if (as.startsWith(" ") || as.startsWith("\n"))
                        savestr ~= as;
                    else
                        savestr ~= " " ~ as;
                }
            }

            if (bt != BlockType.File)
            {
                uint erow = end_row();
                savestr = ps.brackets.begin ~ savestr ~ 
                    (erow > ps.row ? '\n'.repeat(erow - ps.row).array ~ ' '.repeat(tab*4).array : "").idup ~
                    ps.brackets.end;
                if (erow > ps.row) ps.row = erow;
            }
        }
        else if (force_brackets || arguments !is null)
        {
            uint erow = end_row();
            savestr = ps.brackets.begin ~ savestr ~
                (erow > ps.row ? '\n'.repeat(erow - ps.row).array ~ ' '.repeat(tab*4).array : "").idup ~
                ps.brackets.end;
            if (erow > ps.row) ps.row = erow;
        }
        else if (close_lexem.end.row > ps.row)
        {
            uint erow = end_row();
            savestr ~= ('\n'.repeat(erow - ps.row).array ~ ' '.repeat(tab*4).array).idup;
            if (erow > ps.row) ps.row = erow;
        }

        savestr = prewhites ~ savestr;

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

                savestr ~= ps.dot ~ arg.save(ps, inp, tab, null, true);
                arg = arg.postop;
                j++;
            }
        }

        return savestr;
    }

    static bool parse_position(ref string itext, out uint row, out uint col)
    {
        if (itext[0] != ':') return false;
        itext = itext[1..$];
        row = parse!(uint, string)(itext);

        if (itext[0] != ':') return false;
        itext = itext[1..$];
        col = parse!(uint, string)(itext);
        return true;
    }

    void merge_indent_info(ref Lexem a, ref Lexem i, ref Lexem ol, ref Lexem cl)
    {
        uint row, col;
        string itext = i.text;

        if (itext.empty) return;
        if ( parse_position(itext, row, col) )
        {
            a.start.row = row;
            a.start.col = col;
        }

        if (itext.empty) return;
        if (itext[0] == '-')
        {
            itext = itext[1..$];

            if ( parse_position(itext, row, col) )
            {
                a.end.row = row;
                a.end.col = col;
            }
        }

        if (itext.empty) return;
        if (itext[0] == '[')
        {
            itext = itext[1..$];

            if ( parse_position(itext, row, col) )
            {
                ol.text = "$";
                ol.start.row = row;
                ol.start.col = col;
            }

            if (itext[0] == '-')
            {
                itext = itext[1..$];

                if ( parse_position(itext, row, col) )
                {
                    cl.text = "$";
                    cl.start.row = row;
                    cl.start.col = col;
                    cl.end.row = row;
                    cl.end.col = col;
                }
            }
        }
    }

    void merge_inp(Expression inp)
    {
        merge_indent_info(operator_lexem, inp.operator_lexem, open_lexem, close_lexem);
        merge_indent_info(type_lexem, inp.type_lexem, open_lexem, close_lexem);

        foreach(i, arg; this.arguments)
        {
            arg.merge_inp(inp.arguments[i]);
        }

        if (postop !is null)
        {
            postop.merge_inp(inp.postop);
        }
    }

    string wrapWithSpaces(string str, string tabstr, ref Position pos)
    {
        return str;
    }

    string beforeSpaces(string tabstr, ref Position pos)
    {
        return "";
    }

    string afterSpaces(ref Position pos)
    {
        return "";
    }

    string saveD()
    {
         Position pos = Position(1, 1);
         string resstr;
         saveD(resstr, pos);
         return resstr;
    }

    void savePrint(ref string resstr, ref Position pos, string str, Position spos)
    {
        if (spos > pos)
        {
            resstr ~= '\n'.repeat(spos.row - pos.row).array.idup() ~ ' '.repeat(spos.col-(spos.row > pos.row ? 1 : pos.col)).array.idup();
            pos = spos;
        }

        resstr ~= str;
        pos.col += str.length;
    }

    string saveD(ref string resstr, ref Position pos, int tab = 0, Expression[] post = null, string ptype = null)
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
        writefln("%s %s %s %s => %s", tabstr, bt, this, start_pos(), end_pos());

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
                    arg.saveD(resstr, pos, -tab-1);
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
                                    savestr =  savestr ~ ap.saveD(resstr, pos, tab);

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(resstr, pos, -tab-1, null, "ctype");
                                    }
                                }
                                else if (ap.type == "init")
                                {
                                }
                                else
                                {
                                    savestr = ap.saveD(resstr, pos, -tab-1) ~ " " ~ savestr;
                                    //writefln("%s -- %s-%s", savestr, index, arg.index);

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(resstr, pos, -tab-1, null, "ctype");
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
                            savestr =  savestr ~ arg.saveD(resstr, pos, tab);
                        }
                        else if (arg.type == "init")
                        {
                    }
                        else
                        {
                            savestr = arg.saveD(resstr, pos, -tab-1) ~ " " ~ savestr;
                        }
                    }
                }

                savePrint(resstr, pos, this.operator, operator_lexem.start);

                foreach(arg; post ~ (postop is null ? [] : [postop]))
                {
                    if (arg.index == -1)
                    {
                        if (arg.type == "init")
                        {
                            savestr = savestr ~ arg.saveD(resstr, pos, tab);
                        }
                    }
                }

                savestr ~= poststr;

                if (!negtab)
                {
                    savePrint(resstr, pos, ";", pos);
                }
                break;

            case "enum":
                savestr ~= beforeSpaces(tabstr, pos) ~ this.operator;
                foreach(i, arg; post ~ (postop is null ? [] : [postop]))
                {
                    savestr =  savestr ~ arg.saveD(resstr, pos, tab);
                }
                savestr ~= afterSpaces(pos);
                break;

            case "var":
                if (this.type == ".")
                    handled = false;
                else
                {
                    if (!this.arguments.empty)
                        this.arguments[0].saveD(resstr, pos, -tab-1);

                    savePrint(resstr, pos, this.operator, operator_lexem.start);

                    if (postop !is null)
                    {
                        postop.saveD(resstr, pos, tab, null, this.type);
                    }
                }
                break;

            default:
                if (bt == BlockType.File)
                {
                    foreach(i, arg; this.arguments)
                    {
                        arg.saveD(resstr, pos, tab, null, this.type);
                    }
                }
                else handled = false;
                break;
        }

        if (!handled)
        {
            if (bt == BlockType.Comment)
            {
                savePrint(resstr, pos, this.operator, operator_lexem.start);
            }
            else if (bt == BlockType.String)
            {
                savePrint(resstr, pos, this.operator, operator_lexem.start);
            }
            else switch(this.type)
            {
                case "module":
                    savePrint(resstr, pos, "module ", type_lexem.start);
                    savePrint(resstr, pos, this.operator, operator_lexem.start);
                    savePrint(resstr, pos, ";", pos);

                    foreach(i, arg; this.arguments)
                    {
                        arg.saveD(resstr, pos, tab, null, this.type);
                    }
                    break;

                case "import":
                    savePrint(resstr, pos, "import ", type_lexem.start);
                    savePrint(resstr, pos, this.arguments[0].operator, this.arguments[0].operator_lexem.start);

                    if (!arguments[0].arguments.empty)
                    {
                        savePrint(resstr, pos, ": ", pos);
                        foreach (i, arg; arguments[0].arguments)
                        {
                            if (i > 0)
                            {
                                savePrint(resstr, pos, ", ", pos);
                            }
                            savePrint(resstr, pos, arg.operator, arg.operator_lexem.start);
                            if (arg.postop !is null)
                            {
                                savePrint(resstr, pos, " = ", pos);
                                savePrint(resstr, pos, arg.postop.operator, arg.postop.operator_lexem.start);
                            }
                        }
                    }
                    savePrint(resstr, pos, ";", pos);
                    break;

                case "enum":
                    savestr ~= beforeSpaces(tabstr, pos) ~ "enum "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(resstr, pos, tab+1, null, this.type) ~ ( i < this.arguments.length-1 ? ", " : "" );
                    }
                    savestr ~= tabstr ~ "}" ~ afterSpaces(pos);
                    break;

                case "init":
                    savestr ~= " = "~this.operator;

                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(resstr, pos, -tab-1, null, this.type);
                    }
                    break;

                case ":":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(resstr, pos, -tab-1, null, this.type);
                    }
                    savestr ~= this.type;
                    savestr = wrapWithSpaces(savestr, tabstr, pos);
                    break;

                case "*":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(resstr, pos, -tab-1, null, this.type);
                    }
                    savestr ~= this.type;
                    savestr = wrapWithSpaces(savestr, tabstr, pos);
                    break;

                case "struct":
                    savestr ~= beforeSpaces(tabstr, pos) ~ "struct "~this.operator~" {";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(resstr, pos, tab+1, null, this.type);
                    }
                    savestr ~= afterSpaces(pos) ~ tabstr ~ "}";
                    break;

                case "class":
                    savePrint(resstr, pos, "class ", type_lexem.start);
                    savePrint(resstr, pos, this.operator, operator_lexem.start);
                    if (arguments[0].type == "superclass")
                    {
                        savePrint(resstr, pos, " :", pos);
                        arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                    }
                    savePrint(resstr, pos, "{", open_lexem.start);

                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type != "superclass")
                        {
                            arg.saveD(resstr, pos, tab+1, null, this.type);
                        }
                    }
                    savePrint(resstr, pos, "}", close_lexem.start);
                    break;

                case "function":
                    this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                    savePrint(resstr, pos, " ", pos);
                    if (this.operator.empty)
                    {
                        savePrint(resstr, pos, "function", type_lexem.start);
                    }
                    else
                    {
                        savePrint(resstr, pos, this.operator, operator_lexem.start);
                    }
                    savePrint(resstr, pos, "(", open_lexem.start);

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
                        this.arguments[1].saveD(resstr, pos, -tab-1, getPost(1), this.type);
                    if (this.arguments.length > 2)
                    {
                        foreach(i, arg; this.arguments[2..$])
                        {
                            savePrint(resstr, pos, ",", pos);
                            arg.saveD(resstr, pos, -tab-1, getPost(i+2), this.type);
                        }
                    }
                    if (postop !is null)
                    {
                        savePrint(resstr, pos, ")", close_lexem.start);
                        postop.saveD(resstr, pos, tab, null, this.type);
                    }
                    else if (!negtab)
                    {
                        savePrint(resstr, pos, ");", close_lexem.start);
                    }
                    else
                    {
                        savePrint(resstr, pos, ")", close_lexem.start);
                    }
                    break;

                case "body":
                case "{":
                    if (this.arguments.length > 1 || open_lexem.start.row > 0 || type_lexem.start.row > 0)
                        savePrint(resstr, pos, "{", open_lexem.start.row > 0 ? open_lexem.start : type_lexem.start);
                    foreach(i, arg; this.arguments)
                    {
                        arg.saveD(resstr, pos, tab+1, null, this.type);
                    }
                    if (this.arguments.length > 1 || close_lexem.start.row > 0)
                        savePrint(resstr, pos, "}", close_lexem.start);
                    break;

                case "return":
                case "break":
                case "continue":
                case "goto":
                    savePrint(resstr, pos, type, type_lexem.start);
                    if (!this.arguments.empty)
                    {
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savePrint(resstr, pos, ", ", pos);
                            arg.saveD(resstr, pos, -tab-1, null, this.type);
                        }
                    }

                    if (!negtab)
                    {
                        savePrint(resstr, pos, ";", pos);
                    }
                    break;

                case "for":
                    savestr ~= beforeSpaces(tabstr, pos) ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[1].saveD(resstr, pos, -tab-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[2].saveD(resstr, pos, -tab-1, null, this.type) ~ ") ";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(resstr, pos, tab);
                    }
                    savestr ~= afterSpaces(pos);
                    break;

                case "while":
                    savestr ~= beforeSpaces(tabstr, pos) ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type) ~ ") ";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(resstr, pos, tab);
                    }
                    savestr ~= afterSpaces(pos);
                    break;

                case "do":
                    savePrint(resstr, pos, type, type_lexem.start);
                    if (postop !is null)
                    {
                        postop.saveD(resstr, pos, tab);
                    }
                    savePrint(resstr, pos, "while (", postop.postop.type_lexem.start);
                    postop.postop.saveD(resstr, pos, -tab-1, null, this.type);
                    savePrint(resstr, pos, ");", postop.postop.close_lexem.start);
                    break;

                case "foreach":
                    savestr ~= beforeSpaces(tabstr, pos) ~ this.type ~ " (";
                    if (!this.arguments[0].operator.empty)
                        savestr ~= this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type) ~ ", ";
                    savestr ~= this.arguments[1].saveD(resstr, pos, -tab-1, null, this.type) ~ "; ";
                    savestr ~= this.arguments[2].saveD(resstr, pos, -tab-1, null, this.type) ~ ")";
                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(resstr, pos, tab, null, this.type);
                    }
                    savestr ~= afterSpaces(pos);
                    break;

                case "if":
                    savePrint(resstr, pos, "if (", type_lexem.start);
                    if (!operator.empty)
                    {
                        savePrint(resstr, pos, operator ~ " == ", operator_lexem.start);
                    }

                    this.arguments[0].saveD(resstr, pos, tab, null, this.type);

                    bool or_need = arguments[0].postop is null;
                    ubyte else_if_quoted = 0;
                    foreach(i, arg; this.arguments[1..$])
                    {
                        if (arg.bt == BlockType.Comment)
                        {
                            arg.saveD(resstr, pos, tab, null, this.type);
                        }
                        else if (arg.type == "else")
                        {
                            savePrint(resstr, pos, "else", arg.type_lexem.start);
                            arg.saveD(resstr, pos, tab, null, "else");
                            or_need = false;
                        }
                        else if (arg.type == "quote")
                        {
                            if (arg.arguments.length > 0 && arg.arguments[0].operator == "else")
                            {
                                else_if_quoted++;
                                savePrint(resstr, pos, "else", arg.arguments[0].operator_lexem.start);
                            }
                            if (arg.arguments.length > 1 && arg.arguments[1].operator == "if")
                            {
                                else_if_quoted++;
                                savePrint(resstr, pos, "if", arg.arguments[1].operator_lexem.start);
                            }
                        }
                        else if (or_need)
                        {
                            savePrint(resstr, pos, " || ", pos);
                            if (!operator.empty)
                            {
                                savePrint(resstr, pos, operator ~ " == ", operator_lexem.start);
                            }
                            arg.saveD(resstr, pos, tab, null, this.type);
                            or_need = arg.postop is null;
                        }
                        else
                        {
                            if (else_if_quoted < 1)
                                savePrint(resstr, pos, "else ", type_lexem.start);
                            if (else_if_quoted < 2)
                                savePrint(resstr, pos, "if ", type_lexem.start);

                            savePrint(resstr, pos, "(", arg.open_lexem.start);
                            if (!operator.empty)
                            {
                                savePrint(resstr, pos, operator ~ " == ", operator_lexem.start);
                            }
                            arg.saveD(resstr, pos, tab, null, this.type);
                            or_need = arg.postop is null;
                            else_if_quoted = 0;
                        }
                    }
                    break;

                case "switch":
                    savePrint(resstr, pos, type, type_lexem.start);
                    savePrint(resstr, pos, "(", open_lexem.start);

                    foreach(i, arg; this.arguments)
                    {
                        arg.saveD(resstr, pos, -tab-1, null, this.type);
                    }

                    savePrint(resstr, pos, ")", close_lexem.start);

                    if (postop !is null)
                    {
                        postop.saveD(resstr, pos, tab, null, this.type);
                    }
                    break;

                case "var":
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
                                    }
                                    else if (arg.postop.type == "init")
                                    {
                                    }
                                    else
                                    {
                                        arg.postop.saveD(resstr, pos, -tab-1);
                                    }
                                }
                                else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index + arg.postop.index + 1)
                                    return "";
                            }
                        }
                    }
                    else if (postop !is null)
                    {
                        if (postop.index == -1)
                        {
                            if (postop.operator == "[]")
                            {
                            }
                            else if (postop.type == "init")
                            {
                            }
                            else
                            {
                                savestr = postop.saveD(resstr, pos, -tab-1) ~ " " ~ savestr;
                            }
                        }
                    }

                    foreach(i, arg; this.arguments)
                    {
                        arg.saveD(resstr, pos, -tab-1);
                    }

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
                                        arg.postop.saveD(resstr, pos, tab);
                                    }
                                    else if (arg.postop.type == "init")
                                    {
                                    }
                                    else
                                    {
                                    }
                                }
                                else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index + arg.postop.index + 1)
                                    return "";
                            }
                        }
                    }
                    else if (postop !is null)
                    {
                        if (postop.index == -1)
                        {
                            if (postop.operator == "[]")
                            {
                                postop.saveD(resstr, pos, tab);
                            }
                            else if (postop.type == "init")
                            {
                            }
                            else
                            {
                            }
                        }
                    }

                    foreach(i, arg; post ~ (postop is null ? [] : [postop]))
                    {
                        if (arg.index == -1)
                        {
                            if (arg.type == "init")
                            {
                                arg.saveD(resstr, pos, tab);
                            }
                        }
                    }

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
                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            savePrint(resstr, pos, ", ", pos);
                                            arg3.saveD(resstr, pos, -tab-1, null, "ctype");
                                        }
                                    }
                                    else if (arg.postop.type == "init")
                                    {
                                    }
                                    else
                                    {
                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            savePrint(resstr, pos, ", ", pos);
                                            arg3.saveD(resstr, pos, -tab-1, null, "ctype");
                                        }
                                    }
                                }
                                else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index + arg.postop.index + 1)
                                    return "";
                            }
                        }
                    }

                    savePrint(resstr, pos, operator, operator_lexem.start);

                    if (!negtab)
                    {
                        savePrint(resstr, pos, ";", pos);
                    }
                    break;

                case "case":
                case "default":
                    savePrint(resstr, pos, type, type_lexem.start);
                    if (arguments.length > 0)
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, "op");
                    savePrint(resstr, pos, ":", pos);
                    break;

                case ".":
                    if (!arguments.empty)
                    {
                        bool quoted_op;
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, "op");
                        foreach(i, arg; this.arguments[1..$])
                        {
                            if (arg.type == "quote" && arg.arguments[0].operator == this.type)
                            {
                                savePrint(resstr, pos, this.type, arg.arguments[0].operator_lexem.start);
                                quoted_op = true;
                            }
                            else
                            {
                                if (arg.type == "[")
                                {
                                    arg.saveD(resstr, pos, -tab-1, null, "op");
                                }
                                else if (arg.type == "init")
                                {
                                    //savestr = "(" ~ savestr ~ ")";
                                    if (!quoted_op)
                                        savePrint(resstr, pos, this.type, type_lexem.start);
                                    arg.saveD(resstr, pos, -tab-1, null, "op");
                                }
                                else
                                {
                                    if (!quoted_op)
                                        savePrint(resstr, pos, this.type, type_lexem.start);
                                    arg.saveD(resstr, pos, -tab-1, null, "op");
                                }
                                quoted_op = false;
                            }
                        }
                    }

                    if (ptype == "if" && postop !is null)
                    {
                        savePrint(resstr, pos, ")", pos);
                    }
                    else if (ptype == "case")
                    {
                        savePrint(resstr, pos, ":", pos);
                    }

                    if (postop !is null)
                    {
                        postop.saveD(resstr, pos, tab, null, "op");
                    }

                    if (ptype != "if" && ptype != "case" && !negtab && postop is null)
                    {
                        savePrint(resstr, pos, ";", pos);
                    }
                    break;

                case "[":
                    savePrint(resstr, pos, "[", open_lexem.start);
                    if (!arguments.empty)
                    {
                        bool quoted_sep;
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, "op");
                        string sep = ",";
                        foreach(i, arg; this.arguments[1..$])
                        {
                            if (arg.type == "quote" && arg.arguments[0].operator == sep)
                            {
                                savePrint(resstr, pos, sep, arg.arguments[0].operator_lexem.start);
                                quoted_sep = true;
                            }
                            else
                            {
                                if (arg.operator == "..") sep = "";
                                if (!quoted_sep && !sep.empty)
                                    savePrint(resstr, pos, sep, operator_lexem.start);
                                arg.saveD(resstr, pos, -tab-1, null, "op");
                                quoted_sep = false;
                            }
                        }
                    }
                    savePrint(resstr, pos, "]", close_lexem.start);

                    if (ptype == "if" && postop !is null)
                    {
                        savePrint(resstr, pos, ")", close_lexem.start);
                    }

                    if (postop !is null)
                    {
                        postop.saveD(resstr, pos, tab, null, "op");
                    }

                    if (ptype != "if" && !negtab && postop is null)
                    {
                        savePrint(resstr, pos, ";", pos);
                    }
                    break;

                case "\"":
                    savestr ~= "\"" ~ this.arguments[0].saveD(resstr, pos, -tab-1, null, "op");
                    string sep = " ";
                    foreach(i, arg; this.arguments[1..$])
                    {
                        savestr ~= sep ~ arg.saveD(resstr, pos, -tab-1, null, "op");
                    }
                    savestr ~= "\"";

                    if (ptype == "if" && postop !is null)
                    {
                        savestr ~= ") ";
                    }

                    if (postop !is null)
                    {
                        savestr ~= postop.saveD(resstr, pos, tab, null, "op");
                    }

                    if (ptype != "if" && !negtab && postop is null)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else")
                        savestr = wrapWithSpaces(savestr, tabstr, pos);
                    break;

                case "new":
                    savePrint(resstr, pos, this.type, type_lexem.start);
                    if (!this.arguments.empty)
                    {
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savePrint(resstr, pos, ",", pos);
                            arg.saveD(resstr, pos, -tab-1, null, this.type);
                        }
                    }

                    if (postop !is null)
                    {
                        if (postop.operator != "[]")
                            savePrint(resstr, pos, ".", pos);
                        postop.saveD(resstr, pos, -tab-1, null, this.type);
                    }

                    if (!negtab)
                    {
                        savePrint(resstr, pos, ";", pos);
                    }
                    break;

                case "cast":
                    savestr ~= "(" ~ this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= "(" ~ this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ") (" ~ arg.saveD(resstr, pos, -tab-1, null, this.type);
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
                            savestr ~= postop.saveD(resstr, pos, tab, null, this.type);
                            body_ = true;
                        }
                        else
                            savestr ~= (postop.operator != "[]"?".":"") ~ postop.saveD(resstr, pos, -tab-1, null, this.type);
                    }

                    if (ptype != "if" && ptype != "case" && !negtab && !body_)
                    {
                        savestr = savestr ~ ";";
                    }
                    if (ptype != "if" && ptype != "else" && ptype != "case")
                        savestr = wrapWithSpaces(savestr, tabstr, pos);
                    break;

                case "noop":
                    savestr ~= "{}";
                    if (!negtab)
                    {
                        savestr = wrapWithSpaces(savestr, tabstr, pos);
                    }
                    break;

                case "?":
                    if (arguments.length >= 3)
                    {
                        savestr ~= "(" ~ arguments[0].saveD(resstr, pos, -tab-1, null, "op") ~ " ? " ~ arguments[1].saveD(resstr, pos, -tab-1, null, "op") ~ " : " ~ arguments[2].saveD(resstr, pos, -tab-1, null, "op") ~ ")";
                    }
                    break;

                case "label":
                    if (!this.arguments.empty)
                    {
                        this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                    }
                    savePrint(resstr, pos, ":", pos);
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
                            if (!(!negtab && postop is null) && ptype == "op" && open_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, "(", open_lexem.start);
                            }

                            if (!arguments.empty)
                            {
                                if (type == "unary")
                                    savePrint(resstr, pos, operator, operator_lexem.start);

                                bool quoted_op;
                                this.arguments[0].saveD(resstr, pos, -tab-1, null, this.operator == "=" && arguments[0].type != "unary"?"var":"op");
                                foreach(i, arg; this.arguments[1..$])
                                {
                                    if (arg.type == "quote" && arg.arguments[0].operator == operator)
                                    {
                                        savePrint(resstr, pos, operator, arg.arguments[0].operator_lexem.start);
                                        quoted_op = true;
                                    }
                                    else
                                    {
                                        if (!quoted_op)
                                            savePrint(resstr, pos, operator, operator_lexem.start);
                                        arg.saveD(resstr, pos, -tab-1, null, "op");
                                        quoted_op = false;
                                    }
                                }

                                if (type == "type")
                                    savePrint(resstr, pos, operator, operator_lexem.start);
                            }

                            if (!(!negtab && postop is null) && ptype == "op" && close_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }

                            if (ptype == "if" && postop !is null && close_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }

                            if (postop !is null)
                            {
                                postop.saveD(resstr, pos, tab, null, "postop");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savePrint(resstr, pos, ";", pos);
                            }
                            break;

                        case "++":
                        case "--":
                            if (type == "post")
                            {
                                savestr = arguments[0].saveD(resstr, pos, -tab-1, null, "op") ~ operator;
                            }
                            else
                            {
                                savestr = operator ~ arguments[0].saveD(resstr, pos, -tab-1, null, "op");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savestr = savestr ~ ";";
                            }
                            if (ptype != "if" && ptype != "else")
                                savestr = wrapWithSpaces(savestr, tabstr, pos);
                            break;

                        case "!":
                            if (!(!negtab && postop is null) && ptype == "op" && open_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, "(", open_lexem.start);
                            }

                            savePrint(resstr, pos, this.operator, operator_lexem.start);
                            if (!arguments.empty)
                                this.arguments[0].saveD(resstr, pos, -tab-1, null, "op");

                            if (!(!negtab && postop is null) && ptype == "op" && close_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }

                            if (ptype == "if" && postop !is null && close_lexem.start.row > 0)
                            {
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }

                            if (postop !is null)
                            {
                                postop.saveD(resstr, pos, tab, null, "postop");
                            }

                            if (ptype != "if" && !negtab && postop is null)
                            {
                                savePrint(resstr, pos, ";", pos);
                            }
                            break;

                        case "[]":
                            if (postop !is null)
                            {
                                if (type == "type")
                                    postop.saveD(resstr, pos, tab, null, "op");
                            }

                            if (type != "type")
                                savePrint(resstr, pos, "[", open_lexem.start);

                            if (!this.arguments.empty)
                            {
                                this.arguments[0].saveD(resstr, pos, -tab-1, null, this.type);
                                if (type == "type")
                                {
                                    savePrint(resstr, pos, "[", open_lexem.start);
                                    if (this.arguments.length >= 2)
                                        this.arguments[1].saveD(resstr, pos, -tab-1, null, this.type);
                                    savePrint(resstr, pos, "]", close_lexem.start);
                                }
                                else
                                {
                                    string sep = ", ";
                                    foreach(i, arg; this.arguments[1..$])
                                    {
                                        if (arg.operator == "..") sep = "";
                                        savePrint(resstr, pos, sep, pos);
                                        arg.saveD(resstr, pos, -tab-1, null, this.type);
                                    }
                                }
                            }

                            if (type != "type")
                                savePrint(resstr, pos, "]", open_lexem.start);

                            if (postop !is null)
                            {
                                if (type == "type")
                                {}
                                else
                                    postop.saveD(resstr, pos, tab, null, "postop");
                            }

                            break;

                        case "false":
                        case "true":
                            savePrint(resstr, pos, operator, operator_lexem.start);

                            if (ptype == "if" && postop !is null)
                            {
                                savePrint(resstr, pos, ")", pos);
                            }

                            if (postop !is null)
                            {
                                savestr ~= postop.saveD(resstr, pos, tab, null, "postop");
                            }
                            break;

                        default:
                            if (ptype == "postop")
                            {
                                savePrint(resstr, pos, ".", pos);
                            }

                            savePrint(resstr, pos, operator, operator_lexem.start);
                            if (!this.arguments.empty)
                            {
                                bool first = true;
                                if (this.arguments[0].type == "!")
                                {
                                    savePrint(resstr, pos, "!(", this.arguments[0].type_lexem.start);
                                }
                                else
                                {
                                    savePrint(resstr, pos, "(", open_lexem.start);
                                }

                                foreach(i, arg; this.arguments)
                                {
                                    if (arg.type == "!")
                                    {
                                        if (i+2 < arguments.length)
                                        {
                                            first = false;
                                            savePrint(resstr, pos, ")(", pos);
                                        }
                                        continue;
                                    }
                                    else if (first)
                                    {
                                        first = false;
                                    }
                                    else
                                        savePrint(resstr, pos, ", ", pos);
                                    arg.saveD(resstr, pos, -tab-1, null, this.type);
                                }
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }
                            else if (arguments !is null || type == "funcall")
                            {
                                savePrint(resstr, pos, "()", open_lexem.start);
                            }

                            if (ptype == "if" && postop !is null)
                            {
                                savePrint(resstr, pos, ")", close_lexem.start);
                            }
                            else if (ptype == "case")
                            {
                                savePrint(resstr, pos, ":", pos);
                            }

                            bool body_;
                            if (postop !is null)
                            {
                                if (postop.type == "body")
                                {
                                    postop.saveD(resstr, pos, tab, null, this.type);
                                    body_ = true;
                                }
                                else if (ptype == "foreach")
                                {
                                    postop.saveD(resstr, pos, -tab-1, null, this.type);
                                }
                                else
                                {
                                    if (postop.operator != "[]")
                                    {
                                        savePrint(resstr, pos, ".", pos);
                                    }
                                    postop.saveD(resstr, pos, -tab-1, null, this.type);
                                }
                            }

                            if (ptype != "if" && ptype != "case" && !negtab && !body_)
                            {
                                savePrint(resstr, pos, ";", pos);
                            }
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
