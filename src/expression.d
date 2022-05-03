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

import iface;

struct BlockBE
{
    string begin;
    string end;
    string escape;
    bool nested;
}

struct ParserState
{
    BlockBE strings = BlockBE("\"", "\"", "\\", false);
    BlockBE comments = BlockBE("//", "\n", null, false);
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
    BlockBE bbe = BlockBE("(", ")", "\\", true);
    string sharp = "#", at = "@", dot = ".";
    long app_args;
    Expression[] comments;
    Expression[] arguments;
    Expression[] post_operations;
    Expression parent;
    long index;
    long focus_index;
    bool post;

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
        assert(line.startsWith(be.begin));
        line = line[be.begin.length .. $];

        string res = "";

        bool escape;
        int nest;
        while (!line.empty)
        {
            if (escape)
            {
                escape = false;
                dchar c = line.decodeFront();
                res ~= getEscape(c);
            }
            else if ( !be.escape.empty && line.startsWith(be.escape) )
            {
                escape = true;
                //res ~= line[0..be.escape.length];
                line = line[be.escape.length .. $];
            }
            else if ( be.nested && line.startsWith(be.begin) )
            {
                nest++;
                res ~= line[0..be.begin.length];
                line = line[be.begin.length .. $];
            }
            else if ( line.startsWith(be.end) )
            {
                line = line[be.end.length .. $];
                if (nest == 0) return res;
                nest--;
            }
            else
            {
                res ~= line.decodeFront();
            }
        }

        return res;
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

    this(ref char[] line, ParserState ps = ParserState.init)
    {
        Init:
        while (!line.empty && (line[0] == ' ' || line[0] == '\n'))
        {
            line = line[1..$];
        }

        if ( line.startsWith(ps.comments.begin) )
        {
            auto ne = new Expression;
            ne.operator = getBlock(line, ps.comments);
            ne.type = "comment";
            ne.bbe = ps.comments;

            ne.sharp = ps.sharp;
            ne.at = ps.at;
            ne.dot = ps.dot;

            comments ~= ne;
            goto Init;
        }

        sharp = ps.sharp;
        at = ps.at;
        dot = ps.dot;

        bool in_brackets;
        string dot_bracket = ps.dot ~ ps.brackets.begin;
        BlockBE brackets = ps.brackets;
        if ( line.startsWith(ps.strings.begin) )
        {
            operator = getBlock(line, ps.strings);
            type = "string";
            bbe = ps.strings;
            goto Post;
        }

        if ( line.startsWith(ps.brackets.begin) )
        {
            line = line[ps.brackets.begin.length .. $];
            in_brackets = true;
            bbe = ps.brackets;
        }
        else bbe = BlockBE(null, null, null, false);

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
                line = line[1..$];
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
            else if (!in_brackets && line.startsWith(dot_bracket))
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
                line = line[1..$];
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
            else if (!in_brackets && line.startsWith(dot_bracket))
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
                line = line[1..$];
                goto Arguments;
            }
            else if (!in_brackets && line.startsWith(dot_bracket))
            {
                goto Post;
            }
            else
                label ~= line.decodeFront();
        }

        Arguments:
        if (in_brackets)
        {
            while (!line.empty)
            {
                if ( line.startsWith(ps.brackets.end) )
                {
                    line = line[ps.brackets.end.length .. $];
                    break;
                }
                else if (line[0] == ' ' || line[0] == '\n')
                {
                    line = line[1..$];
                }
                else
                {
                    auto ne = new Expression(line, ps);

                    bool processed;

                    switch (ne.type)
                    {
                        case "strings":
                            ps.strings = ne.getBE();
                            processed = true;
                            break;
                        case "comments":
                            ps.comments = ne.getBE();
                            processed = true;
                            break;
                        case "sharp":
                            ps.sharp = ne.operator;
                            processed = true;
                            break;
                        case "at":
                            ps.at = ne.operator;
                            processed = true;
                            break;
                        case "dot":
                            ps.dot = ne.operator;
                            processed = true;
                            break;
                        case "end":
                            if (type == "brackets" && ne.index == 0)
                            {
                                ps.brackets.begin = operator;
                                ps.brackets.end = ne.operator;
                                operator = ps.dot;
                                processed = true;
                            }
                            break;
                        case "escape":
                            if (type == "brackets" && ne.index == 1)
                            {
                                ps.brackets.escape = ne.operator;
                                processed = true;
                            }
                            break;
                        default:
                            if (type == "brackets" && ne.operator.empty && ne.type.empty && ne.label.empty && ne.arguments.empty && ne.post_operations.empty)
                            {
                                ps.brackets = brackets;
                                processed = true;
                            }
                            break;
                    }

                    if (ne.operator == ps.dot && !ne.arguments.empty)
                    {
                        foreach(arg; ne.arguments)
                        {
                            arg.parent = this;
                            arg.index += arguments.length;
                        }

                        arguments ~= ne.arguments;

                        foreach(arg; ne.post_operations)
                        {
                            arg.parent = arguments[$-1];
                            arg.index += arguments[$-1].post_operations.length;
                            arg.app_args = ne.arguments.length;
                        }

                        arguments[$-1].post_operations ~= ne.post_operations;
                    }
                    else if (!processed)
                    {
                        ne.parent = this;
                        ne.index = arguments.length;
                        arguments ~= ne;
                    }
                }
            }
        }

        Post:
        if (line.startsWith(dot_bracket))
        {
            line = line[ps.dot.length .. $];
            auto ne = new Expression(line, ps);
            ne.parent = this;
            ne.post = true;
            ne.app_args = 1;
            post_operations ~= ne;
        }

        End:
        while (!line.empty && (line[0] == ' ' || line[0] == '\n'))
        {
            line = line[1..$];
        }
    }

    this(string line)
    {
        char[] l = line.dup;
        this(l);
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

    Expression popChild()
    {
        if (arguments.empty) return null;
        auto ret = arguments[$-1];
        arguments = arguments[0..$-1];
        return ret;
    }

    void fixBbe()
    {
        if (arguments.empty && bbe.begin == "(")
            bbe = BlockBE(null, null, null, false);

        foreach (ind, arg; arguments)
        {
            arg.fixBbe();
        }

        foreach (ind, arg; post_operations)
        {
            arg.fixBbe();
        }
    }

    void fixParents(Expression p = null, long i = 0, bool ps = false)
    {
        parent = p;
        index = i;
        post = ps;
        if (ps && app_args == 0) app_args = 1;

        foreach (ind, arg; arguments)
        {
            arg.fixParents(this, ind);
        }

        foreach (ind, arg; post_operations)
        {
            arg.fixParents(this, ind, true);
        }
    }

    string save()
    {
        ParserState ps;
        return save(ps);
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

    string save(ref ParserState ps, int tab = 0, long[] cbr = null, bool force_brackets = false)
    {
        string op = operator;
        string prestr, poststr;
        string savestr;

        BlockBE obr = ps.brackets;

        foreach(j, arg; comments)
        {
            prestr ~= arg.save(ps, tab+1, null, false);
        }

        if (ps.sharp != sharp)
        {
            prestr ~= ps.brackets.begin ~ sharp ~ ps.sharp ~ "sharp" ~ ps.brackets.end ~ " ";
            ps.sharp = sharp;
        }
        if (ps.at != at)
        {
            prestr ~= ps.brackets.begin ~ at ~ ps.sharp ~ "at" ~ ps.brackets.end ~ " ";
            ps.at = at;
        }
        if (ps.dot != dot)
        {
            prestr ~= ps.brackets.begin ~ dot ~ ps.sharp ~ "dot" ~ ps.brackets.end ~ " ";
            ps.dot = dot;
        }

        if (type == "comment")
        {
            op = bbe.begin ~ escape(op, bbe, false) ~ bbe.end;
            if (ps.comments != bbe)
            {
                ps.comments = bbe;
                prestr ~= ps.brackets.begin ~ bbe.begin ~ ps.sharp ~ "comments " ~ escape(bbe.end, ps.brackets) ~ ps.sharp ~ "end";
                if (!bbe.escape.empty) prestr ~= " " ~ bbe.escape ~ ps.sharp ~ "escape";
                if (bbe.nested) prestr ~= " " ~ ps.sharp ~ "escape";
                prestr ~= ps.brackets.end ~ " ";
            }
            savestr ~= op;
        }
        else if (type == "string")
        {
            op = bbe.begin ~ escape(op, bbe, false) ~ bbe.end;
            if (ps.strings != bbe)
            {
                ps.strings = bbe;
                prestr ~= ps.brackets.begin ~ bbe.begin ~ ps.sharp ~ "strings " ~ bbe.end ~ ps.sharp ~ "end";
                if (!bbe.escape.empty) prestr ~= " " ~ bbe.escape ~ ps.sharp ~ "escape";
                if (bbe.nested) prestr ~= " " ~ ps.sharp ~ "escape";
                prestr ~= ps.brackets.end ~ " ";
            }
            savestr ~= op;
        }
        else
        {
            op = escape(op, bbe);
            if (ps.brackets != bbe && !bbe.begin.empty)
            {
                prestr ~= ps.brackets.begin ~ bbe.begin ~ ps.sharp ~ "brackets " ~ bbe.end ~ ps.sharp ~ "end" ~ " ";
                poststr = " " ~ bbe.begin ~ bbe.end ~ ps.brackets.end;

                ps.brackets = bbe;
            }
            savestr ~= op ~ (this.type.empty ? "" : ps.sharp ~ escape(type, bbe)) ~ (this.label.empty ? "" : ps.at ~ escape(label, bbe));
            if (!bbe.begin.empty)
                force_brackets = true;
        }

        if (savestr.empty)
            savestr = ps.dot;

        if (!this.arguments.empty)
        {
            long[] a, b, c;
            foreach(i, arg; this.arguments)
            {
                foreach(j, arg2; arg.post_operations)
                {
                    if (arg2.app_args > 1)
                    {
                        a ~= i-arg2.app_args+1;
                        b ~= i;
                        c ~= j;
                    }
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

                if (this.type == "body" || this.type == "module" || this.type == "class" || this.type == "struct" || this.type == "if" || this.type == "switch")
                    savestr ~= "\n" ~ (' '.repeat((tab+1)*4).array) ~ arg.save(ps, tab+1, br, false);
                else
                    savestr ~= " " ~ arg.save(ps, tab+1, br, false);
            }

            savestr = ps.brackets.begin ~ savestr ~ ps.brackets.end;
        }
        else if (force_brackets)
            savestr = ps.brackets.begin ~ savestr ~ ps.brackets.end;

        long cj = 0;

        foreach(j, arg; this.post_operations)
        {
            if (cj < cbr.length && cbr[cj] == j)
            {
                savestr ~= ps.brackets.end;
                cj++;
            }

            savestr ~= ps.dot ~ arg.save(ps, tab+1, null, true);
        }

        ps.brackets = obr;
        return prestr ~ savestr ~ poststr;
    }

    string saveD(int tab = 0, Expression[] post = null, string ptype = null, string inner = null)
    {
        string savestr;
        string tabstr = "";
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
                        savestr = arg.saveD(-1) ~ " " ~ savestr;
                    }
                    else
                    {
                        savestr ~= arg.saveD(-1) ~ " ";
                    }
                }

                string poststr = "";
                if (parent !is null && !post && parent.arguments.length > index)
                {
                    foreach(i, arg; parent.arguments[index..$])
                    {
                        foreach(i2, arg2; arg.post_operations)
                        {
                            //writefln("%s -- %s (%s == %s)", this, arg2.app_args, arg.index - arg2.app_args + 1, this.index);
                            if (arg.index - arg2.app_args + 1 == this.index)
                            {
                                if (arg2.operator == "[]")
                                {
                                    savestr =  savestr ~ arg2.saveD(tab);

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(-1, null, "ctype");
                                    }
                                }
                                else if (arg2.type == "init")
                                {
                                }
                                else
                                {
                                    savestr = arg2.saveD(-1) ~ " " ~ savestr;

                                    foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                    {
                                        poststr ~= ", " ~ arg3.saveD(-1, null, "ctype");
                                    }
                                }
                            }
                            else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index - arg2.app_args + 1)
                                return "";
                        }
                    }
                }
                else
                foreach(i, arg; post ~ this.post_operations)
                {
                    if (arg.app_args == 1)
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
                            savestr = arg.saveD(-1) ~ " " ~ savestr;
                        }
                    }
                }

                savestr ~= this.operator;

                foreach(i, arg; post ~ this.post_operations)
                {
                    if (arg.app_args == 1)
                    {
                        if (arg.type == "init")
                        {
                            savestr = savestr ~ arg.saveD(tab);
                        }
                    }
                }

                savestr ~= poststr;

                if (tab >= 0)
                {
                    savestr = tabstr ~ savestr ~ ";\n";
                }
                break;

            case "enum":
                savestr ~= tabstr ~ this.operator;
                foreach(i, arg; post ~ this.post_operations)
                {
                    savestr =  savestr ~ arg.saveD(tab);
                }
                break;

            case "var":
                if (this.type == ".")
                    handled = false;
                else
                {
                    savestr ~= this.operator;
                    if (!this.arguments.empty)
                        savestr = this.arguments[0].saveD(-1) ~ " " ~ savestr;

                    foreach(i, arg; this.post_operations)
                    {
                        savestr = arg.saveD(tab, null, this.type) ~ " " ~ savestr;
                    }
                }
                break;

            default:
                handled = false;
                break;
        }
        
        if (!handled)
        {
            switch(this.type)
            {
                case "module":
                    savestr ~= tabstr ~ "module "~this.operator~";\n";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab, null, this.type);
                    }
                    break;

                case "import":
                    savestr ~= tabstr ~ "import "~this.arguments[0].operator;
                    if (!arguments[0].arguments.empty)
                    {
                        savestr ~= ": ";
                        foreach (i, arg; arguments[0].arguments)
                        {
                            if (i > 0) savestr ~= ", ";
                            savestr ~= arg.operator;
                            if (!arg.post_operations.empty)
                            {
                                savestr ~= " = " ~ arg.post_operations[0].operator;
                            }
                        }
                    }
                    savestr ~= ";\n";
                    break;

                case "enum":
                    savestr ~= tabstr ~ "enum "~this.operator~"\n"~tabstr~"{\n";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type) ~ ( i < this.arguments.length-1 ? ",\n" : "\n" );
                    }
                    savestr ~= tabstr ~ "}\n";
                    break;

                case "init":
                    savestr ~= " = "~this.operator;

                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-1, null, this.type);
                    }
                    break;

                case ":":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-1, null, this.type);
                    }
                    savestr ~= this.type;
                    break;

                case "*":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-1, null, this.type);
                    }
                    savestr ~= this.type;
                    break;

                case "struct":
                    savestr ~= tabstr ~ "struct "~this.operator~"\n"~tabstr~"{\n";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= tabstr ~ "}\n";
                    break;

                case "class":
                    savestr ~= tabstr ~ "class "~this.operator;
                    if (arguments[0].type == "superclass")
                        savestr ~= " : " ~ arguments[0].saveD(-1, null, this.type);
                    savestr ~= "\n"~tabstr~"{\n";

                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type != "superclass")
                            savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= tabstr ~ "}\n";
                    break;

                case "function":
                    savestr ~= tabstr ~ this.arguments[0].saveD(-1, null, this.type) ~" "~(this.operator.empty?"function":this.operator)~"(";

                    long[] a, b, c;
                    foreach(i, arg; this.arguments)
                    {
                        foreach(j, arg2; arg.post_operations)
                        {
                            if (arg2.app_args > 1)
                            {
                                a ~= i-arg2.app_args+1;
                                b ~= i;
                                c ~= j;
                            }
                        }
                    }

                    Expression[] getPost(long i)
                    {
                        Expression[] e;
                        
                        foreach(j, f; a)
                        {
                            if (i >= f && i < b[j])
                                e ~= this.arguments[b[j]].post_operations[c[j]];
                        }

                        return e;
                    }

                    if (this.arguments.length > 1)
                        savestr ~= this.arguments[1].saveD(-1, getPost(1), this.type);
                    if (this.arguments.length > 2)
                    {
                        foreach(i, arg; this.arguments[2..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-1, getPost(i+2), this.type);
                        }
                    }
                    if (!this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                        foreach(i, arg; this.post_operations)
                        {
                            savestr ~= arg.saveD(tab, null, this.type);
                        }
                    }
                    else if (tab >= 0)
                    {
                        savestr ~= ");\n";
                    }
                    else
                    {
                        savestr ~= ")";
                    }
                    break;

                case "body":
                    savestr ~= tabstr ~ "{\n";
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(tab+1, null, this.type);
                    }
                    savestr ~= tabstr ~ "}\n";
                    break;

                case "return":
                case "break":
                case "continue":
                case "goto":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= " " ~ this.arguments[0].saveD(-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-1, null, this.type);
                        }
                    }

                    if (tab >= 0)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "for":
                    savestr ~= tabstr ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[1].saveD(-1, null, this.type);
                    savestr ~= "; " ~ this.arguments[2].saveD(-1, null, this.type) ~ ")\n";
                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab);
                    }
                    break;

                case "while":
                    savestr ~= tabstr ~ this.type;
                    savestr ~= " (" ~ this.arguments[0].saveD(-1, null, this.type) ~ ")\n";
                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab);
                    }
                    break;

                case "do":
                    savestr ~= tabstr ~ this.type ~ "\n";
                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab);
                    }
                    savestr ~= tabstr ~ "while (" ~ this.arguments[0].saveD(-1, null, this.type) ~ ");\n";
                    break;

                case "foreach":
                    savestr ~= tabstr ~ this.type ~ " (";
                    if (!this.arguments[0].operator.empty)
                        savestr ~= this.arguments[0].saveD(-1, null, this.type) ~ ", ";
                    savestr ~= this.arguments[1].saveD(-1, null, this.type) ~ "; ";
                    savestr ~= this.arguments[2].saveD(-1, null, this.type) ~ ")\n";
                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab, null, this.type);
                    }
                    break;

                case "if":
                    savestr ~= tabstr ~ "if (" ~ (!operator.empty ? operator~" == " : "") ~ this.arguments[0].saveD(tab, null, this.type);
                    bool or_need = arguments[0].post_operations.empty;
                    foreach(i, arg; this.arguments[1..$])
                    {
                        if (arg.type == "else")
                        {
                            savestr ~= tabstr ~ "else\n" ~ arg.saveD(tab, null, "else");
                            or_need = false;
                        }
                        else if (or_need)
                        {
                            savestr ~= tabstr ~ " || " ~ (!operator.empty ? operator~" == " : "") ~ arg.saveD(tab, null, this.type);
                            or_need = arg.post_operations.empty;
                        }
                        else
                        {
                            savestr ~= tabstr ~ "else if (" ~ (!operator.empty ? operator~" == " : "") ~ arg.saveD(tab, null, this.type);
                            or_need = arg.post_operations.empty;
                        }
                    }
                    break;

                case "switch":
                    savestr ~= tabstr ~ "switch (" ~ (!operator.empty ? operator : inner) ~ ")\n";
                    savestr ~= tabstr ~ "{\n";
                    foreach(i, arg; this.arguments)
                    {
                        if (arg.type == "default")
                            savestr ~= tabstr ~ "    default" ~ arg.saveD(tab+1, null, "case");
                        else
                            savestr ~= tabstr ~ "    case " ~ arg.saveD(tab+1, null, "case");
                    }
                    savestr ~= tabstr ~ "}\n";
                    break;

                case "var":
                    foreach(i, arg; this.arguments)
                    {
                        savestr ~= arg.saveD(-1) ~ " ";
                    }

                    string poststr = "";
                    if (parent !is null && !post && parent.arguments.length > index)
                    {
                        foreach(i, arg; parent.arguments[index..$])
                        {
                            foreach(i2, arg2; arg.post_operations)
                            {
                                //writefln("%s -- %s (%s == %s)", this, arg2.app_args, arg.index - arg2.app_args + 1, this.index);
                                if (arg.index - arg2.app_args + 1 == this.index)
                                {
                                    if (arg2.operator == "[]")
                                    {
                                        savestr =  savestr ~ arg2.saveD(tab);

                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            poststr ~= ", " ~ arg3.saveD(-1, null, "ctype");
                                        }
                                    }
                                    else if (arg2.type == "init")
                                    {
                                    }
                                    else
                                    {
                                        savestr = arg2.saveD(-1) ~ " " ~ savestr;

                                        foreach(i3, arg3; parent.arguments[index+1..arg.index+1])
                                        {
                                            poststr ~= ", " ~ arg3.saveD(-1, null, "ctype");
                                        }
                                    }
                                }
                                else if (ptype != "ctype" && this.index <= arg.index && this.index > arg.index - arg2.app_args + 1)
                                    return "";
                            }
                        }
                    }
                    else
                    foreach(i, arg; this.post_operations)
                    {
                        if (arg.app_args == 1)
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
                                savestr = arg.saveD(-1) ~ " " ~ savestr;
                            }
                        }
                    }

                    savestr ~= " " ~ this.operator;

                    foreach(i, arg; post ~ this.post_operations)
                    {
                        if (arg.app_args == 1)
                        {
                            if (arg.type == "init")
                            {
                                savestr = savestr ~ arg.saveD(tab);
                            }
                        }
                    }

                    savestr ~= poststr;

                    if (tab >= 0)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "default":
                    savestr ~= ":\n";
                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab, null, "op");
                    }
                    break;

                case ".":
                    if (!arguments.empty)
                    {
                        savestr ~= this.arguments[0].saveD(-1, null, "op");
                        foreach(i, arg; this.arguments[1..$])
                        {
                            auto next = arg.saveD(-1, null, "op");
                            if (next[0] == '[')
                                savestr ~= next;
                            else if (next == "init")
                                savestr = "(" ~ savestr ~ ")" ~ this.type ~ next;
                            else
                                savestr ~= this.type ~ next;
                        }
                    }

                    if (ptype == "if" && !this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                    }
                    else if (ptype == "case")
                    {
                        savestr ~= ":\n";
                    }

                    foreach(i, arg; this.post_operations)
                    {
                        if (arg.type == "switch")
                            savestr = arg.saveD(tab, null, "op", savestr);
                        else
                            savestr ~= arg.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && ptype != "case" && tab >= 0 && this.post_operations.empty)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "[":
                    savestr ~= "[";
                    if (!arguments.empty)
                    {
                        savestr ~= this.arguments[0].saveD(-1, null, "op");
                        string sep = ", ";
                        foreach(i, arg; this.arguments[1..$])
                        {
                            if (arg.operator == "..") sep = "";
                            savestr ~= sep ~ arg.saveD(-1, null, "op");
                        }
                    }
                    savestr ~= "]";

                    if (ptype == "if" && !this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                    }

                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && tab >= 0 && this.post_operations.empty)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "\"":
                    savestr ~= "\"" ~ this.arguments[0].saveD(-1, null, "op");
                    string sep = " ";
                    foreach(i, arg; this.arguments[1..$])
                    {
                        savestr ~= sep ~ arg.saveD(-1, null, "op");
                    }
                    savestr ~= "\"";

                    if (ptype == "if" && !this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                    }

                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= arg.saveD(tab, null, "op");
                    }

                    if (ptype != "if" && tab >= 0 && this.post_operations.empty)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "new":
                    savestr ~= this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= " " ~ this.arguments[0].saveD(-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ", " ~ arg.saveD(-1, null, this.type);
                        }
                    }

                    foreach(i, arg; this.post_operations)
                    {
                        savestr ~= (arg.operator != "[]"?".":"") ~ arg.saveD(-1, null, this.type);
                    }

                    if (tab >= 0)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "cast":
                    savestr ~= "(" ~ this.type;
                    if (!this.arguments.empty)
                    {
                        savestr ~= "(" ~ this.arguments[0].saveD(-1, null, this.type);
                        foreach(i, arg; this.arguments[1..$])
                        {
                            savestr ~= ") (" ~ arg.saveD(-1, null, this.type);
                        }
                        savestr ~= "))";
                    }

                    if (ptype == "if" && !this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                    }
                    else if (ptype == "case")
                    {
                        savestr ~= ":\n";
                    }

                    bool body_;
                    foreach(i, arg; this.post_operations)
                    {
                        if (arg.type == "body")
                        {
                            savestr ~= arg.saveD(tab, null, this.type);
                            body_ = true;
                        }
                        else if (arg.type == "switch")
                        {
                            savestr = arg.saveD(tab, null, "postop", savestr);
                            body_ = true;
                        }
                        else
                            savestr ~= (arg.operator != "[]"?".":"") ~ arg.saveD(-1, null, this.type);
                    }

                    if (ptype != "if" && ptype != "case" && tab >= 0 && !body_)
                    {
                        savestr = tabstr ~ savestr ~ ";\n";
                    }
                    break;

                case "noop":
                    savestr ~= "{}";
                    if (tab >= 0)
                    {
                        savestr = tabstr ~ savestr ~ "\n";
                    }
                    break;

                case "string":
                    savestr ~= "\"" ~ escape(operator, bbe, false) ~ "\"";

                    if (ptype == "if" && !this.post_operations.empty)
                    {
                        savestr ~= ")\n";
                    }
                    else if (ptype == "case")
                    {
                        savestr ~= ":\n";
                    }

                    foreach(i, arg; this.post_operations)
                    {
                        if (arg.type == "switch")
                            savestr = arg.saveD(tab, null, "postop", savestr);
                        else
                            savestr ~= arg.saveD(tab, null, "postop");
                    }

                    if (ptype != "if" && ptype != "case" && tab >= 0)
                    {
                        savestr = tabstr ~ savestr ~ "\n";
                    }
                    break;

                case "?":
                    if (arguments.length >= 3)
                    {
                        savestr ~= "(" ~ arguments[0].saveD(-1, null, "op") ~ " ? " ~ arguments[1].saveD(-1, null, "op") ~ " : " ~ arguments[2].saveD(-1, null, "op") ~ ")";
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
                                savestr ~= this.arguments[0].saveD(-1, null, this.operator == "=" && arguments[0].type != "unary"?"var":"op");
                                foreach(i, arg; this.arguments[1..$])
                                {
                                    savestr ~= " " ~ this.operator ~ " " ~ arg.saveD(-1, null, "op");
                                }
                                if (type == "type")
                                    savestr ~= this.operator;
                            }

                            if (!(tab >= 0 && this.post_operations.empty) && ptype == "op")
                            {
                                savestr = "(" ~ savestr ~ ")";
                            }

                            if (ptype == "if" && !this.post_operations.empty)
                            {
                                savestr ~= ")\n";
                            }

                            foreach(i, arg; this.post_operations)
                            {
                                if (arg.type == "switch")
                                    savestr = arg.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= arg.saveD(tab, null, "postop");
                            }

                            if (ptype != "if" && tab >= 0 && this.post_operations.empty)
                            {
                                savestr = tabstr ~ savestr ~ ";\n";
                            }
                            break;

                        case "++":
                        case "--":
                            if (type == "post")
                            {
                                savestr = arguments[0].saveD(-1, null, "op") ~ operator;
                            }
                            else
                            {
                                savestr = operator ~ arguments[0].saveD(-1, null, "op");
                            }

                            if (ptype != "if" && tab >= 0 && this.post_operations.empty)
                            {
                                savestr = tabstr ~ savestr ~ ";\n";
                            }
                            break;

                        case "!":
                            savestr ~= this.operator;
                            if (!arguments.empty)
                                savestr ~= " " ~ this.arguments[0].saveD(-1, null, "op");

                            if (!(tab >= 0 && this.post_operations.empty) && ptype == "op")
                            {
                                savestr = "(" ~ savestr ~ ")";
                            }

                            if (ptype == "if" && !this.post_operations.empty)
                            {
                                savestr ~= ")\n";
                            }

                            foreach(i, arg; this.post_operations)
                            {
                                if (arg.type == "switch")
                                    savestr = arg.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= arg.saveD(tab, null, "postop");
                            }

                            if (ptype != "if" && tab >= 0 && this.post_operations.empty)
                            {
                                savestr = tabstr ~ savestr ~ ";\n";
                            }
                            break;

                        case "[]":

                            if (!this.arguments.empty)
                            {
                                savestr ~= this.arguments[0].saveD(-1, null, this.type);
                                if (type == "type")
                                {
                                    string of = "";
                                    if (this.arguments.length >= 2)
                                        of = this.arguments[1].saveD(-1, null, this.type);
                                    savestr ~= "["~of~"]";
                                }
                                else
                                {
                                    string sep = ", ";
                                    foreach(i, arg; this.arguments[1..$])
                                    {
                                        if (arg.operator == "..") sep = "";
                                        savestr ~= sep ~ arg.saveD(-1, null, this.type);
                                    }
                                }
                            }

                            if (type != "type")
                                savestr = "[" ~ savestr ~ "]";

                            foreach(i, arg; this.post_operations)
                            {
                                if (arg.type == "switch")
                                    savestr = arg.saveD(tab, null, "postop", savestr);
                                else if (type == "type")
                                    savestr = arg.saveD(tab, null, "op") ~ " " ~ savestr;
                                else
                                    savestr ~= arg.saveD(tab, null, "postop");
                            }

                            break;

                        case "false":
                        case "true":
                            savestr ~= this.operator;

                            if (ptype == "if" && !this.post_operations.empty)
                            {
                                savestr ~= ")\n";
                            }

                            foreach(i, arg; this.post_operations)
                            {
                                if (arg.type == "switch")
                                    savestr = arg.saveD(tab, null, "postop", savestr);
                                else
                                    savestr ~= arg.saveD(tab, null, "postop");
                            }
                            break;

                        default:
                            if (ptype == "postop") savestr ~= ".";

                            savestr ~= this.operator;
                            if (!this.arguments.empty)
                            {
                                bool first = true;
                                auto f = this.arguments[0].saveD(-1, null, this.type);
                                
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
                                    savestr ~= arg.saveD(-1, null, this.type);
                                }
                                savestr ~= ")";
                            }
                            else if (!bbe.begin.empty)
                            {
                                savestr ~= "()";
                            }

                            if (ptype == "if" && !this.post_operations.empty)
                            {
                                savestr ~= ")\n";
                            }
                            else if (ptype == "case")
                            {
                                savestr ~= ":\n";
                            }

                            bool body_;
                            foreach(i, arg; this.post_operations)
                            {
                                if (arg.type == "body")
                                {
                                    savestr ~= arg.saveD(tab, null, this.type);
                                    body_ = true;
                                }
                                else if (arg.type == "switch")
                                {
                                    savestr = arg.saveD(tab, null, "postop", savestr);
                                    body_ = true;
                                }
                                else if (ptype == "foreach")
                                {
                                    savestr = arg.saveD(-1, null, this.type) ~ " " ~ savestr;
                                }
                                else
                                    savestr ~= (arg.operator != "[]"?".":"") ~ arg.saveD(-1, null, this.type);
                            }

                            if (ptype != "if" && ptype != "case" && tab >= 0 && !body_)
                            {
                                savestr = tabstr ~ savestr ~ ";\n";
                            }
                            break;
                    }
                    break;
            }
        }

        if (type != "module" && !this.label.empty)
            savestr = tabstr ~ this.label ~ ":\n" ~ savestr;

        return savestr;
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

        foreach (arg; post_operations)
        {
            arg.findBlocks(code, lexemTypes, lexer);
        }
    }

    void replace(Expression ne)
    {
        ne.parent = this.parent;
        ne.index = this.index;
        ne.post = this.post;
        ne.x = this.x;
        ne.y = this.y;
        ne.r1 = this.r1;
        ne.r2 = this.r2;
        ne.center = this.center;
        if (this.parent !is null)
        {
            if (!this.post)
            {
                this.parent.arguments[this.index] = ne;
            }
            else
            {
                this.parent.post_operations[this.index] = ne;
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
        if (operator == "save")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back2 this)");
            code.addChild(ne);
        }
        else if (operator == "back")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" this back2)");
            code.addChild(ne);
        }
        else if (type == "switch")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back this)");
            code.addChild(ne);

            ne = new Expression("(nextChr)");
            code.addChild(ne);

            ne = new Expression(("(#if)"));
            code.addChild(ne);
            
            code = ne;
        } 
        else if (parent.type == "switch")
        {
            Expression ne;
            if (operator.startsWith("is"))
            {
                ne = new Expression("(#module (#. chr "~operator~").(#body))");
                ne = ne.arguments[0];
            }
            else if (operator == "!" && arguments[0].operator.startsWith("is"))
            {
                ne = new Expression("(#module (! (#. chr "~arguments[0].operator~")).(#body))");
                ne = ne.arguments[0];
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(#module (== chr "~operator~").(#body))");
                ne = ne.arguments[0];
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(#module (! (#. "~operator~" (find chr) empty)).(#body))");
                ne = ne.arguments[0];
            }
            else if (type == "\"")
            {
                ne = new Expression("(#module (! (#. replace_this (find chr) empty)).(#body))");
                ne = ne.arguments[0];
                auto dc = this.deepcopy;
                ne.arguments[0].arguments[0].replace(dc);
                dc.post_operations = null;
            }
            else if (type == "default")
            {
                ne = new Expression("(#module (true).(#body (= this back)))");
                ne = ne.arguments[0];
            }
            else
            {
                writefln("%s#%s", operator, type);
                assert(0);
            }

            if (post_operations.empty && (code.arguments.empty || code.arguments[$-1].operator != "||" || !code.arguments[$-1].post_operations[0].arguments.empty))
            {
                Expression ne2 = new Expression("(#module (||).(#body))");
                ne2 = ne2.arguments[0];

                ne.post_operations = null;
                ne2.addChild(ne);
                code.addChild(ne2);
            }
            else if (!code.arguments.empty && code.arguments[$-1].operator == "||" && code.arguments[$-1].post_operations[0].arguments.empty)
            {
                auto co = code.arguments[$-1];
                ne.post_operations = null;
                co.addChild(ne);
                if (!post_operations.empty)
                {
                    code = co.post_operations[0];
                }
            }
            else
            {
                code.addChild(ne);
                code = ne.post_operations[0];
            }
        }
        else if (type == "while")
        {
            Expression ne;

            Expression back = new Expression("(= this back)");

            if (arguments.length <= 1)
            {
                if (arguments[0].operator == "!")
                {
                    ne = new Expression(("(#module (#do"~(!label.empty?"@"~label:"")~" !).(#body (= back this) nextChr))"));
                    ne = ne.arguments[0];
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne.arguments[0];
                }
                else
                {
                    ne = new Expression(("(#module (#do).(#body (= back this) nextChr))"));
                    ne = ne.arguments[0];
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne;
                }
            }
            else
            {
                ne = new Expression(("(#module (#do ||).(#body (= back this) nextChr))"));
                ne = ne.arguments[0];
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
                ne = new Expression("(#. chr "~operator~")");
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(== chr "~operator~")");
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(! (#. "~operator~" (find chr) empty))");
            }
            else if (type == "\"")
            {
                ne = new Expression("(! (#. replace_this (find chr) empty))");
                auto dc = this.deepcopy;
                ne.arguments[0].arguments[0].replace(dc);
                dc.post_operations = null;
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
            Expression ne = new Expression("(#goto "~operator~")");
            code.addChild(ne);
        }
        else if (parent.type == "return")
        {
            Expression ne;
            
            if (main)
            {
                ne = new Expression("(= type (#. LexemType "~operator~"))");
                code.addChild(ne);
            }

            ne = new Expression("(#return)");
            code.addChild(ne);
        }

        foreach (arg; arguments)
        {
            arg.toLexer(code, main);
        }

        foreach (arg; post_operations)
        {
            arg.toLexer(code, main);
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
                foreach (arg; post_operations)
                {
                    arg.toLexer(main, true);
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
                Expression func = new Expression(("(#module ("~operator~"#function void).(#body (back#var Lexer) (back2#var Lexer)))").dup);
                func = func.arguments[0];
                foreach (arg; post_operations)
                {
                    arg.toLexer(func.post_operations[0], false);
                }

                lexer.addChild(func);
            }
        }

        foreach (arg; arguments)
        {
            arg.toLexer(code, lexer, lTypes);
        }

        foreach (arg; post_operations)
        {
            arg.toLexer(code, lexer, lTypes);
        }
    }

    Expression toLexer()
    {
        Expression code, lexemTypes, lexer;
        char[] text = readFile("lexer_templ.np");
        Expression ret = new Expression(text);
        ret.findBlocks(code, lexemTypes, lexer);
        assert(lexemTypes !is null);
        assert(code !is null);

        ret.operator = "lexer_synth";

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
        copy.app_args = app_args;
        copy.parent = parent;
        copy.index = index;
        copy.post = post;
        copy.center = center;
        copy.hidden = hidden;
        copy.level = level;
        copy.levels = levels;
        copy.bbe = bbe;
        
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

        foreach(arg; post_operations)
        {
            copy.post_operations ~= arg.deepcopy();
            copy.post_operations[$-1].parent = copy;
        }

        return copy;
    }

    Expression movecopy()
    {
        auto copy = deepcopy();
        copy.index++;

        if (!post)
        {
            foreach(arg; parent.arguments[index+1..$])
            {
                arg.index++;
            }
            parent.arguments = parent.arguments[0..index+1] ~ copy ~ parent.arguments[index+1..$];
        }
        else
        {
            foreach(arg; parent.post_operations[index+1..$])
            {
                arg.index++;
            }
            parent.post_operations = parent.post_operations[0..index+1] ~ copy ~ parent.post_operations[index+1..$];
        }

        return copy;
    }

    override string toString()
    {
        return operator ~ (!type.empty ? "#" ~ type : "") ~ (!label.empty ? "@" ~ label : "");
    }
}
