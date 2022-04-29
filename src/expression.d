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
    long app_args;
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

    this(char[] line)
    {
        long app_args = 1;
        if (line[0] == '(' && line[$-1] == ')')
        {
            line = line[1..$-1];

            auto operator = line;
            char[] type;
            char[] label;

            auto sp = line.find(" ");
            if (!sp.empty)
            {
                operator = line[0..sp.ptr - line.ptr];
                auto sh = operator.findSplit("#");
                if (!sh[1].empty)
                {
                    operator = sh[0];
                    type = sh[2];
                }
                sh = operator.findSplit("@");
                if (!sh[1].empty)
                {
                    operator = sh[0];
                    label = sh[2];
                }
                else
                {
                    sh = type.findSplit("@");
                    if (!sh[1].empty)
                    {
                        type = sh[0];
                        label = sh[2];
                    }
                }

                line = sp[1..$];

                do
                {
                    if (line[0] == '(')
                    {
                        int brackets = 0;
                        bool str = false;
                        bool chr = false;
                        bool slash = false;
                        bool sharp = false;
                        foreach(i, c; line)
                        {
                            if (sharp) sharp = false;
                            else if (str)
                            {
                                if (slash) slash = false;
                                else if (c == '\\') slash = true;
                                else if (c == '\"') str = false;
                            }
                            else if (chr)
                            {
                                if (slash) slash = false;
                                else if (c == '\\') slash = true;
                                else if (c == '\'') chr = false;
                            }
                            else if (c == '\"')
                                str = true;
                            else if (c == '\'')
                                chr = true;
                            else if (c == '#')
                                sharp = true;
                            else if (c == '(')
                                brackets++;
                            else if (c == ')')
                            {
                                brackets--;
                                if (brackets == 0)
                                {
                                    Expression ne = new Expression(line[0..i+1]);
                                    ne.parent = this;
                                    if (ne.operator == ".")
                                    {
                                        foreach(k, ne2; ne.arguments)
                                        {
                                            ne2.parent = this;
                                            ne2.index = this.arguments.length + k;
                                        }

                                        this.arguments ~= ne.arguments;
                                        app_args = ne.arguments.length;
                                        this.post_operations ~= ne.post_operations;
                                    }
                                    else
                                    {
                                        ne.index = this.arguments.length;
                                        this.arguments ~= ne;
                                        app_args = 1;
                                    }
                                    if (line.length > i+1 && line[i+1] == ' ')
                                        line = line[i+2..$];
                                    else if (line.length > i+1 && line[i+1] == '.')
                                        line = line[i+1..$];
                                    else line = line[0..0];
                                    break;
                                }
                            }
                        }
                        assert(brackets == 0);
                    }
                    else if (line[0] == '.')
                    {
                        line = line[1..$];

                        if (!line.empty && line[0] == '.')
                        {
                            Expression ne = new Expression;
                            ne.parent = this;
                            ne.index = this.arguments.length;
                            ne.operator = "..";
                            this.arguments ~= ne;
                            app_args = 1;

                            if (line.length > 1 && line[1] == ' ')
                                line = line[2..$];
                            else
                                line = line[1..$];
                        }
                        else if (!line.empty && line[0] == '(')
                        {
                            int brackets = 0;
                            bool str = false;
                            bool chr = false;
                            bool slash = false;
                            bool sharp = false;
                            foreach(i, c; line)
                            {
                                if (sharp) sharp = false;
                                else if (str)
                                {
                                    if (slash) slash = false;
                                    else if (c == '\\') slash = true;
                                    else if (c == '\"') str = false;
                                }
                                else if (chr)
                                {
                                    if (slash) slash = false;
                                    else if (c == '\\') slash = true;
                                    else if (c == '\'') chr = false;
                                }
                                else if (c == '\"')
                                    str = true;
                                else if (c == '\'')
                                    chr = true;
                                else if (c == '#')
                                    sharp = true;
                                else if (c == '(')
                                    brackets++;
                                else if (c == ')')
                                {
                                    brackets--;
                                    if (brackets == 0)
                                    {
                                        Expression ne = new Expression(line[0..i+1]);
                                        //writefln("%s", line);
                                        ne.parent = this.arguments[$-1];
                                        ne.post = true;
                                        ne.index = this.arguments[$-1].post_operations.length;
                                        this.arguments[$-1].post_operations ~= ne;
                                        ne.app_args = app_args;
                                        if (line.length > i+1 && line[i+1] == ' ')
                                            line = line[i+2..$];
                                        else if (line.length > i+1 && line[i+1] == '.')
                                            line = line[i+1..$];
                                        else line = line[0..0];
                                        break;
                                    }
                                }
                            }
                            assert(brackets == 0);
                        }
                        else if (line.empty || line[0] == ' ')
                        {
                            Expression ne = new Expression;
                            ne.parent = this;
                            ne.index = this.arguments.length;
                            this.arguments ~= ne;
                            app_args = 1;

                            if (!line.empty)
                                line = line[1..$];
                        }
                    }
                    else if (line[0] == '"')
                    {
                        bool escape = true;
                        foreach(i, c; line)
                        {
                            if (c == '"' && !escape)
                            {
                                Expression ne = new Expression;
                                ne.parent = this;
                                ne.index = this.arguments.length;
                                ne.operator = line[0..i+1].idup;
                                this.arguments ~= ne;
                                app_args = 1;

                                line = line[i+1..$];
                                if (!line.empty && line[0] == '#')
                                {
                                    sp = line.findAmong(" .");
                                    this.type = line[1..sp.ptr - line.ptr].idup;
                                    line = sp;
                                }

                                if (!line.empty && line[0] == ' ') line = line[1..$];

                                break;
                            }

                            if (c == '\\' && !escape)
                                escape = true;
                            else
                                escape = false;
                        }

                    }
                    else
                    {
                        auto ch = line.findAmong(" .");
                        while (!ch.empty && ch[0] == '.' && ch[1] != '(')
                            ch = ch[1..$].findAmong(" .");
                        if (!ch.empty && ch[0] == '.')
                        {
                            Expression ne = new Expression;
                            ne.parent = this;
                            ne.index = this.arguments.length;
                            ne.operator = line[0..ch.ptr - line.ptr].idup;
                            auto ssh = ne.operator.findSplit("#");
                            if (!ssh[1].empty)
                            {
                                ne.operator = ssh[0];
                                ne.type = ssh[2];
                            }
                            this.arguments ~= ne;
                            app_args = 1;

                            line = ch;
                        }
                        else if (!ch.empty && ch[0] == ' ')
                        {
                            Expression ne = new Expression;
                            ne.parent = this;
                            ne.index = this.arguments.length;
                            ne.operator = line[0..ch.ptr - line.ptr].idup;
                            auto ssh = ne.operator.findSplit("#");
                            if (!ssh[1].empty)
                            {
                                ne.operator = ssh[0];
                                ne.type = ssh[2];
                            }
                            ssh = ne.operator.findSplit("@");
                            if (!ssh[1].empty)
                            {
                                ne.operator = ssh[0];
                                ne.label = ssh[2];
                            }
                            else
                            {
                                ssh = ne.type.findSplit("@");
                                if (!ssh[1].empty)
                                {
                                    ne.type = ssh[0];
                                    ne.label = ssh[2];
                                }
                            }
                            this.arguments ~= ne;
                            app_args = 1;

                            line = ch[1..$];
                        }
                        else
                        {
                            Expression ne = new Expression;
                            ne.parent = this;
                            ne.index = this.arguments.length;
                            ne.operator = line.idup;
                            auto ssh = ne.operator.findSplit("#");
                            if (!ssh[1].empty)
                            {
                                ne.operator = ssh[0];
                                ne.type = ssh[2];
                            }
                            ssh = ne.operator.findSplit("@");
                            if (!ssh[1].empty)
                            {
                                ne.operator = ssh[0];
                                ne.label = ssh[2];
                            }
                            else
                            {
                                ssh = ne.type.findSplit("@");
                                if (!ssh[1].empty)
                                {
                                    ne.type = ssh[0];
                                    ne.label = ssh[2];
                                }
                            }
                            this.arguments ~= ne;
                            app_args = 1;

                            line = line[0..0];
                        }
                    }
                } while (line.length > 0);
            }
            else
            {
                auto sh = operator.findSplit("#");
                if (!sh[1].empty)
                {
                    operator = sh[0];
                    type = sh[2];
                }
                sh = operator.findSplit("@");
                if (!sh[1].empty)
                {
                    operator = sh[0];
                    label = sh[2];
                }
                else
                {
                    sh = type.findSplit("@");
                    if (!sh[1].empty)
                    {
                        type = sh[0];
                        label = sh[2];
                    }
                }
            }

            this.operator = operator.idup;
            this.type = type.idup;
            this.label = label.idup;
        }
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

    string save(int tab = 0, long[] cbr = null, bool force_brackets = false)
    {
        string savestr = this.operator ~ (this.type.empty ? "" : "#" ~ this.type) ~ (this.label.empty ? "" : "@" ~ this.label);

        if (savestr.empty)
            savestr = ".";

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
                        savestr ~= " (.";
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
                    savestr ~= "\n" ~ (' '.repeat((tab+1)*4).array) ~ arg.save(tab+1, br);
                else
                    savestr ~= " " ~ arg.save(tab+1, br);
            }

            savestr = "("~savestr~")";
        }
        else if (force_brackets)
            savestr = "("~savestr~")";

        long cj = 0;

        foreach(j, arg; this.post_operations)
        {
            if (cj < cbr.length && cbr[cj] == j)
            {
                savestr ~= ')';
                cj++;
            }

            savestr ~= "." ~ arg.save(tab+1, null, true);
        }

        return savestr;
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
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back2 this)".dup);
            code.addChild(ne);
        }
        else if (operator == "back")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" this back2)".dup);
            code.addChild(ne);
        }
        else if (type == "switch")
        {
            Expression ne = new Expression("(="~(!label.empty?"@"~label:"")~" back this)".dup);
            code.addChild(ne);

            ne = new Expression("(nextChr)".dup);
            code.addChild(ne);

            ne = new Expression(("(#if)").dup);
            code.addChild(ne);
            
            code = ne;
        } 
        else if (parent.type == "switch")
        {
            Expression ne;
            if (operator.startsWith("is"))
            {
                ne = new Expression("(#module (#. chr "~operator~").(#body))".dup);
                ne = ne.arguments[0];
            }
            else if (operator == "!" && arguments[0].operator.startsWith("is"))
            {
                ne = new Expression("(#module (! (#. chr "~arguments[0].operator~")).(#body))".dup);
                ne = ne.arguments[0];
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(#module (== chr "~operator~").(#body))".dup);
                ne = ne.arguments[0];
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(#module (! (#. "~operator~" (find chr) empty)).(#body))".dup);
                ne = ne.arguments[0];
            }
            else if (type == "\"")
            {
                ne = new Expression("(#module (! (#. replace_this (find chr) empty)).(#body))".dup);
                ne = ne.arguments[0];
                auto dc = this.deepcopy;
                ne.arguments[0].arguments[0].replace(dc);
                dc.post_operations = null;
            }
            else if (type == "default")
            {
                ne = new Expression("(#module (true).(#body (= this back)))".dup);
                ne = ne.arguments[0];
            }
            else
            {
                writefln("%s#%s", operator, type);
                assert(0);
            }

            if (post_operations.empty && (code.arguments.empty || code.arguments[$-1].operator != "||" || !code.arguments[$-1].post_operations[0].arguments.empty))
            {
                Expression ne2 = new Expression("(#module (||).(#body))".dup);
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

            Expression back = new Expression("(= this back)".dup);

            if (arguments.length <= 1)
            {
                if (arguments[0].operator == "!")
                {
                    ne = new Expression(("(#module (#do"~(!label.empty?"@"~label:"")~" !).(#body (= back this) nextChr))").dup);
                    ne = ne.arguments[0];
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne.arguments[0];
                }
                else
                {
                    ne = new Expression(("(#module (#do).(#body (= back this) nextChr))").dup);
                    ne = ne.arguments[0];
                    code.addChild(ne);
                    code.addChild(back);
                    
                    code = ne;
                }
            }
            else
            {
                ne = new Expression(("(#module (#do ||).(#body (= back this) nextChr))").dup);
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
                ne = new Expression("(#. chr "~operator~")".dup);
            }
            else if (operator.length > 2 && operator[0] == '\'' && operator[$-1] == '\'' || operator == "EOF")
            {
                ne = new Expression("(== chr "~operator~")".dup);
            }
            else if (operator.length > 2 && operator[0] == '"' && operator[$-1] == '"')
            {
                ne = new Expression("(! (#. "~operator~" (find chr) empty))".dup);
            }
            else if (type == "\"")
            {
                ne = new Expression("(! (#. replace_this (find chr) empty))".dup);
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
            Expression ne = new Expression("(#goto "~operator~")".dup);
            code.addChild(ne);
        }
        else if (parent.type == "return")
        {
            Expression ne;
            
            if (main)
            {
                ne = new Expression("(= type (#. LexemType "~operator~"))".dup);
                code.addChild(ne);
            }

            ne = new Expression("(#return)".dup);
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
        Expression ret = new Expression(readFile("lexer_templ.np"));
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
