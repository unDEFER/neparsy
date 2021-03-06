module parser;
import std.stdio;
import std.range;
import std.utf;
import std.uni;
import std.algorithm.searching;
import std.algorithm.mutation;
import lexer;
import expression;

class Parser {
    Lexer lexer;
    Expression cexpr;

    void getText(Expression expr, long te, long line = __LINE__)
    {
        string r = lexer.getText;

        string[] rs = expr.splitNL(r);
        if (expr.texts[1][te].empty)
        {
            if (lexer.fnl)
            {
                expr.texts[1][te] = [""];
            }
            expr.texts[1][te] ~= [""];
        }


        foreach (i, li; rs){
            expr.texts[1][te].back ~= li;

            if (li.endsWith("\n"))
            {
                expr.texts[1][te] ~= [""];
                lexer.fnl = true;
            }
            else
            {
                lexer.fnl = false;
            }
        }


        if (expr.texts[1][te].back.empty)
        {
            expr.texts[1][te] = expr.texts[1][te][0..($ - 1)];
        }

        writefln("%04d %s %s %s", line, [r], expr, expr.texts[1]);
    }

    void getLexem(long line = __LINE__)
    {

        if (backed)
        {
            backed = false;
            return;
        }
        do
        {
            lexer.getLexem();

            if (lexer == LexemType.Comment)
            {
                Expression com = new Expression;
                com.bt = BlockType.Comment;
                com.operator = lexer.lexem;
                getText(com, 0);
                writefln("%04d COMMENT %s", line, cexpr);
                cexpr.arguments ~= com;
            }

        }while ((lexer == LexemType.Blank) || (lexer == LexemType.Comment));


        lexer.skipNL();
    }

    Expression parse()
    {
        Expression file = new Expression;
        file.bt = BlockType.File;
        cexpr = file;
        Expression ret = new Expression;
Init:
        getLexem;

        if (lexer == "module")
        {
            ret.type = "module";
            ret.operator = getModuleName;

            getText(ret, 0);
            ret.label = "D";
            file.arguments ~= ret;
            cexpr = ret;
            goto Init;
        }
        else if (lexer == "import")
        {
            ret.arguments ~= getImport;
            goto Init;
        }
        else if (lexer == "struct")
        {
            ret.arguments ~= getStruct;
            goto Init;
        }
        else if (lexer == "class")
        {
            ret.arguments ~= getClass;
            goto Init;
        }
        else if (lexer == "enum")
        {
            ret.arguments ~= getEnum;
            goto Init;
        }
        else if (lexer == LexemType.Identifier)
        {
            ret.arguments ~= getVar;
            goto Init;
        }
        else if (lexer == LexemType.EndInput)
        {
            {}
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            return file;
        }
        return file;
    }

    string getModuleName()
    {
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            string ret = lexer.lexem;
            getLexem;

            if (lexer == ";")
            {
                return ret;
            }
            else 
            {
                writefln("Expected ; after module name not %s", lexer);
                assert(0);
            }
        }
        else 
        {
            writefln("Expected LexemType.Identifier after module, not %s", lexer);
            assert(0);
        }
    }

    Expression getImport()
    {
        Expression ret = new Expression;
        ret.type = "import";
        getText(ret, 0);
        string modname;
Init:
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            modname ~= lexer.lexem;
        }
        else 
        {
            writefln("Expected identifier not %s", lexer);
            assert(0);
        }
        getLexem;

        if (lexer == ".")
        {
            modname ~= ".";
            goto Init;
        }
        else if (lexer == ":")
        {
            Expression mod = new Expression;
            mod.operator = modname;
            ret.arguments ~= mod;
Ident:
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression name = new Expression;
                getText(name, 0);
                name.operator = lexer.lexem;
                mod.arguments ~= name;
                getLexem;

                if (lexer == "=")
                {
                    getLexem;

                    if (lexer == LexemType.Identifier)
                    {
                        Expression rename = new Expression;
                        getText(rename, 0);
                        rename.operator = lexer.lexem;
                        name.postop = rename;
                        getLexem;

                        if (lexer == ",")
                        {
                            goto Ident;
                        }
                        else if (lexer == ";")
                        {
                            return ret;
                        }
                        else 
                        {
                            writefln(", or ; Expected not %s", lexer);
                            assert(0);
                        }
                    }
                    else 
                    {
                        writefln("Expected identifier not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == ",")
                {
                    goto Ident;
                }
                else if (lexer == ";")
                {
                    getText(ret, 1);
                    return ret;
                }
                else 
                {
                    writefln(", or ; or () Expected not %s", lexer);
                    assert(0);
                }
            }
            else 
            {
                writefln("Expected identifier not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == ";")
        {
            Expression mod = new Expression;
            mod.operator = modname;
            ret.arguments ~= mod;
            getText(ret, 1);
            return ret;
        }
        else 
        {
            writefln("Expected  or ; not %s", lexer);
            assert(0);
        }
    }

    Expression getStruct()
    {
        Expression ret = new Expression;
        Expression oexpr = cexpr;
        cexpr = ret;
        ret.type = "struct";
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator = lexer.lexem;
            getLexem;
            {}
        }

        getText(ret, 0);


        if (lexer == "{")
        {
            {}
        }
        else 
        {
            writefln("{ Expected not %s", lexer);
            assert(0);
        }
        ret.arguments = getDefinitions;
        getText(ret, 1);
        cexpr = oexpr;
        return ret;
    }

    Expression getClass()
    {
        Expression ret = new Expression;
        Expression oexpr = cexpr;
        cexpr = ret;
        ret.type = "class";
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator = lexer.lexem;
            getLexem;
            {}
        }
        else 
        {
            {}
        }

        getText(ret, 0);

        if (lexer == "{")
        {
            {}
        }
        else if (lexer == ":")
        {
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                {}
            }
            else 
            {
                writefln("Expected Identifier not %s", lexer);
                assert(0);
            }
            Expression name = new Expression;
            name.operator = lexer.lexem;
            name.type = "superclass";

            getText(name, 0);ret.arguments ~= name;
Interface:
            getLexem;

            if (lexer == ",")
            {
                getLexem;

                if (lexer == LexemType.Identifier)
                {
                    {}
                }
                else 
                {
                    writefln("Expected Identifier not %s", lexer);
                    assert(0);
                }
                Expression iname = new Expression;
                iname.operator = lexer.lexem;

                getText(iname, 0);name.arguments ~= iname;
                goto Interface;
            }
            else if (lexer == "{")
            {
                {}
            }
            else 
            {
                writefln("Expected { or , not %s", lexer);
                assert(0);
            }
        }
        else 
        {
            writefln("{ or : Expected not %s", lexer);
            assert(0);
        }
        ret.arguments ~= getDefinitions;
        getText(ret, 1);
        cexpr = oexpr;
        return ret;
    }

    Expression[] getDefinitions()
    {
        Expression ret = new Expression;
        Expression oexpr = cexpr;
        cexpr = ret;
Init:
        getLexem;

        if (lexer == "struct")
        {
            ret.arguments ~= getStruct;
            goto Init;
        }
        else if (lexer == "class")
        {
            ret.arguments ~= getClass;
            goto Init;
        }
        else if (lexer == "enum")
        {
            ret.arguments ~= getEnum;
            goto Init;
        }

        else if (lexer == LexemType.Attribute
                || lexer == LexemType.Visibility
                || lexer == LexemType.Identifier)

        {
            ret.arguments ~= getVar;
            goto Init;
        }
        else if (lexer == "}")
        {
            cexpr = oexpr;
            return ret.arguments;
        }
        else 
        {
            writefln("LexemType.Identifier expected not %s", lexer);
            int curly = 1;
WaitCurly:
            getLexem;

            if (lexer == "{")
            {
                ++curly;
                goto WaitCurly;
            }
            else if (lexer == "}")
            {
                --curly;
                if (curly == 0)
                {
                    cexpr = oexpr;
                    return ret.arguments;
                }

                goto WaitCurly;
            }
            else 
            {
                goto WaitCurly;
            }

        }

    }

    Expression getEnum()
    {
        Expression ret = new Expression;
        Expression oexpr = cexpr;
        cexpr = ret;
        ret.type = "enum";
        getText(ret, 0);
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator = lexer.lexem;
            getText(ret, 0);
            getLexem;
            {}
        }
        else 
        {
            {}
        }

        if (lexer == "{")
        {
            {}
        }
        else 
        {
            writefln("{ Expected not %s", lexer);
            assert(0);
        }
Values:
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            Expression val = new Expression;
            val.operator = lexer.lexem;
            getText(val, 0);
            getLexem;

            if (lexer == "=")
            {
                getLexem;
                if (lexer == LexemType.Character || lexer == LexemType.Number)
                {
                    Expression init = new Expression;
                    init.operator = lexer.lexem;
                    init.type = "init";
                    val.postop = init;
                    getLexem;
                }
                else if (lexer == "-")
                {
                    getLexem;
                    if (lexer == LexemType.Character || lexer == LexemType.Number)
                    {
                        Expression init = new Expression;
                        init.operator = "-" ~ lexer.lexem;
                        init.type = "init";
                        val.postop = init;
                        getLexem;
                    }
                    else 
                    {
                        writefln("Number Expected not %s", lexer);
                        assert(0);
                    }
                }
                else 
                {
                    writefln("Number Expected not %s", lexer);
                    assert(0);
                }
            }
            else 
            {
                {}
            }

            if (lexer == ",")
            {
                ret.arguments ~= val;
                goto Values;
            }
            else if (lexer == "}")
            {
                ret.arguments ~= val;
                {}
            }
            else 
            {
                writefln(", or } Expected not %s", lexer);
                assert(0);
            }
            {}
        }
        else 
        {
            writefln("{ Expected not %s", lexer);
            assert(0);
        }
        getText(ret, 1);
        cexpr = oexpr;
        return ret;
    }

    Expression[] getVar()
    {
        Expression ret = new Expression;
        Expression oexpr = cexpr;
        cexpr = ret;
        Expression type = new Expression;
        Expression var1 = ret;
        Expression[] pp;
Init:
        if (lexer == "static"
                || lexer == "override"
                || lexer == "public"
                || lexer == "private"
                || lexer == "package"
                || lexer == "protected")
        {
            Expression post = new Expression;

            post.index = PostfixType.Prefix;
            post.type = "attr";
            post.operator = lexer.lexem;
            getText(post, 0);
            pp ~= post;
            getLexem;
            goto Init;
        }
        else if (lexer == ":")
        {
            type.texts[1][0] = ret.texts[1][0];
            type.arguments ~= ret.arguments;
            type.type = ":";
            getText(pp.back, 0);
            type.arguments ~= pp;
            type.postop = null;
            cexpr = oexpr;
            return [type];
        }
        else if (lexer == "this")
        {
            type.type = "constructor";

            getText(type, 0);}
        else if (lexer == LexemType.Identifier)
        {
            type.operator = lexer.lexem;
            type.type = "type";
            getText(type, 0);
            getLexem;
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
Var:
        if (lexer == LexemType.Identifier)
        {
            ret.operator = lexer.lexem;
            getText(ret, 0);
            type.addPosts(pp);
            getLexem;
        }
        else if (lexer == "*")
        {
            Expression nt = new Expression;
            nt.operator = "*";
            nt.type = "type";
            nt.arguments ~= type;
            type = nt;
            getLexem;
            goto Var;
        }
        else if (lexer == "[")
        {
            Expression nt = new Expression;
            nt.operator = "[]";
            nt.type = "type";
            nt.texts[1] = type.texts[1];
            type.texts[1] = [[], []];
            getText(nt, 0);

            Expression size = new Expression;

            nt.arguments ~= size;
            nt.arguments ~= type;
            type = nt;
            getLexem;

            if (lexer == "]")
            {
                getText(type, 0);
                getLexem;
                goto Var;
            }
            else if (lexer == LexemType.Number)
            {
                size.operator = lexer.lexem;
                getLexem;

                if (lexer == "]")
                {
                    getText(type, 0);
                    getLexem;
                    goto Var;
                }
                else if (lexer == LexemType.Number)
                {
                }
                else 
                {
                    writefln("Unexpected %s", lexer);
                    assert(0);
                }
            }
            else 
            {
                writefln("Unexpected %s", lexer);
                assert(0);
            }
        }
        else 
        {
            writefln("Identifier Expected not %s", lexer);
            assert(0);
        }
Eq:
        if (lexer == "(")
        {
            ret.type = "function";
            type.index = PostfixType.Prefix;
            ret.addPosts([type]);

            ret.arguments ~= getArguments;
            getText(ret, 1);

            if (ret.operator == "function")
            {
                ret.operator = "";
                type = ret;
                ret = new Expression;
                getLexem;

                if (lexer == LexemType.Identifier)
                {
                    ret.operator = lexer.lexem;
                    ret.arguments ~= type;
                }
                else 
                {
                    writefln("Identifier Expected not %s", lexer);
                    assert(0);
                }
                getLexem;

                if (lexer == ";")
                {
                    return [ret];
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
            }
            getLexem;

            if (lexer == "{")
            {
                back;
                ret.addPosts([getBody]);
            }
            else if (lexer == ";")
            {
                {}
            }
            else 
            {
                writefln("Expected { or ; not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == ",")
        {
            Expression expr = new Expression;
            expr.arguments ~= ret;
            ret = cexpr = expr;
Var2:
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression var = new Expression;
                getText(var, 0);
                var.operator = lexer.lexem;
                expr.arguments ~= var;
            }
            else 
            {
                writefln("Identifier Expected not %s", lexer);
                assert(0);
            }
            getLexem;
Comma:
            if (lexer == ",")
            {
                goto Var2;
            }
            else if (lexer == "=")
            {
                Expression eq = new Expression;
                eq.operator = "=";
                getText(eq, 0);
                Expression init = getExpression;
                eq.addChilds([init]);
                expr.arguments[($ - 1)].addPosts([eq]);
                eq.texts[1][1] = init.texts[1][1];
                init.texts[1][1] = [];
                goto Comma;
            }
            else if (lexer == ";")
            {
                type.index = PostfixType.Prefix;
                ret.operator = ".";
                ret.addPosts([type]);
                cexpr = oexpr;
                return [ret];
            }
            else 
            {
                writefln("() or , or ; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "=")
        {
            Expression eq = new Expression;
            getText(eq, 0);
            Expression init = getExpression;
            eq.texts[1][1] = init.texts[1][1];
            init.texts[1][1] = [];
            eq.operator = "=";eq.addChilds([init]);
            var1.addPosts([eq]);
            goto Eq;
        }
        else if (lexer == ";")
        {
            type.index = PostfixType.Prefix;
            ret.addPosts([type]);
        }
        else 
        {
            writefln("Expected or () or ; or , not %s", lexer);
            assert(0);
        }
        getText(ret, 1);
        cexpr = oexpr;
        return [ret];
    }

    Expression getBody()
    {
        Expression ret = new Expression;
        ret.type = "body";
        getText(ret, 0);
        Expression oexpr = cexpr;
        cexpr = ret;
Init:
        Expression[] s = getStatement(&ret.parentheses);
        ret.arguments ~= s;
        
        cexpr = oexpr;
        getText(ret, 1);
        return ret;
    }

    Expression getCaseBody()
    {
        Expression ret = new Expression;
        ret.type = "body";
        Expression oexpr = cexpr;
        cexpr = ret;
Init:
        Expression[] s = getStatement;

        if (s is null)
        {
            cexpr = oexpr;
            return ret;
        }
        ret.arguments ~= s;
        goto Init;
    }

    Expression[] getStatement(bool *parentheses = null)
    {
        Expression[] post;
        Expression comments = new Expression;
        comments.type = "comments";
        Expression oexpr = cexpr;
        Expression[] sargs = cexpr.arguments;
        Lexer back = lexer;
Attr:
        getLexem;

        if (lexer == "static")
        {
            Expression s = new Expression;
            s.operator = lexer.lexem;

            s.index = PostfixType.Prefix;
            post ~= s;
            goto Attr;
        }
        else if (lexer == "if")
        {
            Expression expr = new Expression;
            expr.type = "if";
            getText(expr, 0);
            cexpr = expr;
            sargs = [];
            expr.addPosts(post);
Init:
            getLexem;

            if (lexer == "(")
            {
                expr.addChilds(comments.arguments);
                comments.arguments = [];
                Expression cond = getExpression;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                cond.postop = getBody;
                expr.arguments ~= cond;
                sargs = cexpr.arguments;
                back = lexer;
                getLexem;

                if (lexer == "else")
                {
                    sargs = cexpr.arguments;
                    back = lexer;
                    getLexem;

                    if (lexer == "if")
                    {
                        goto Init;
                    }
                    else 
                    {
                        cexpr.arguments = sargs;
                        lexer = back;
                        Expression els = new Expression;
                        els.type = "else";
                        els.postop = getBody;
                        expr.arguments ~= els;
                    }
                }
                else 
                {
                    cexpr.arguments = sargs;
                    lexer = back;
                }
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
            oexpr.addChilds(comments.arguments);
            getText(expr, 1);
            cexpr = oexpr;
            return [expr];
        }
        else if (lexer == "switch")
        {
            Expression expr = new Expression;
            expr.type = "switch";
            cexpr = expr;
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                expr.addChilds(comments.arguments);
                comments.arguments = [];
                Expression var = getExpression;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                var.postop = expr;
                getLexem;

                if (lexer == "{")
                {
                    {}
                }
                else 
                {
                    writefln("{ Expected not %s", lexer);
                    assert(0);
                }
Case:
                long ind = expr.arguments.length;
Case2:
                expr.addChilds(comments.arguments);
                comments.arguments = [];
                sargs = cexpr.arguments;
                back = lexer;
                getLexem;

                if (lexer == "case")
                {
                    expr.arguments ~= getCaseVal;
                }
                else if (lexer == "default")
                {
                    Expression def = new Expression;
                    def.type = "default";
                    expr.arguments ~= def;
                    getLexem;
                }
                else if (lexer == "}")
                {
                    getText(expr, 1);
                    cexpr = oexpr;
                    return [var];
                }
                else 
                {
                    cexpr.arguments = sargs;
                    lexer = back;
                    comments.arguments = [];
                    Expression bod = getCaseBody;
                    bod.index = PostfixType.Postfix;
                    expr.arguments[($ - 1)].postop = bod;
                    goto Case;
                }

                if (lexer == ":")
                {
                    goto Case2;
                }
                else 
                {
                    writefln(": Expected not", lexer);
                    assert(0);
                }
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "for")
        {
            Expression expr = new Expression;
            expr.type = "for";
            getText(expr, 0);
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                Expression iexpr = getInnerStat;
                getLexem;

                if (lexer == ";")
                {
                    {}
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
                Expression cexpr = getExpression;

                if (lexer == ";")
                {
                    {}
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
                Expression pexpr = getInnerStat;
                getLexem;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                expr.arguments = [iexpr, cexpr, pexpr];
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "foreach"
                || lexer == "foreach_reverse")
        {
            Expression expr = new Expression;
            expr.type = lexer.lexem;
            getText(expr, 0);
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                Expression avar = new Expression;
                Expression bvar = new Expression;
                Expression[] p1;
Avar:
                getLexem;

                if (lexer == "ref")
                {
                    Expression aref = new Expression;
                    aref.operator = lexer.lexem;
                    aref.index = PostfixType.Prefix;
                    getText(aref, 0);
                    p1 ~= aref;
                    goto Avar;
                }
                else if (lexer == LexemType.Identifier)
                {
                    avar.operator = lexer.lexem;
                    getText(avar, 0);
                }
                else 
                {
                    writefln("Expected Identifier not %s", lexer);
                    assert(0);
                }
                getLexem;

                if (lexer == ",")
                {
Bvar:
                    getLexem;

                    if (lexer == "ref")
                    {
                        Expression aref = new Expression;
                        aref.operator = lexer.lexem;
                        aref.index = PostfixType.Prefix;
                        getText(aref, 0);
                        p1 ~= aref;
                        goto Bvar;
                    }
                    else if (lexer == LexemType.Identifier)
                    {
                        bvar.operator = lexer.lexem;
                        getText(bvar, 0);
                        getLexem;
                    }
                    else 
                    {
                        writefln("Expected Identifier not %s", lexer);
                        assert(0);
                    }
                }
                else 
                {
                    swap(avar, bvar);
                }

                if (lexer == LexemType.Identifier)
                {
                    Expression btype = bvar;
                    bvar = new Expression;
                    bvar.operator = lexer.lexem;
                    getText(bvar, 0);
                    btype.index = PostfixType.Prefix;
                    bvar.addPosts([btype]);

                    getLexem;
                }

                if (lexer == ";")
                {
                    {}
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
                bvar.addPosts(p1);
                Expression cexpr = getExpression;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                expr.arguments = [avar, bvar, cexpr];
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "while")
        {
            Expression expr = new Expression;
            expr.type = "while";
            getText(expr, 0);
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                Expression cexpr = getExpression;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                expr.arguments = [cexpr];
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "do")
        {
            Expression expr = new Expression;
            expr.type = "do";
            getText(expr, 0);
            expr.addPosts(post);
            auto bod_ = [getBody];
            foreach (b; bod_)
            {
                b.index = PostfixType.InBrace;
            }
            expr.addPosts(bod_);
            getLexem;

            if (lexer == "while")
            {
                getLexem;
            }
            else 
            {
                writefln("Expected while not %s", lexer);
                assert(0);
            }

            if (lexer == "(")
            {
                Expression cexpr = getExpression;

                if (lexer == ")")
                {
                    {}
                }
                else 
                {
                    writefln("Expected  not %s", lexer);
                    assert(0);
                }
                expr.arguments = [cexpr];
                getLexem;

                if (lexer == ";")
                {
                    {}
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "break"
                || lexer == "continue")
        {
            Expression expr = new Expression;
            expr.type = lexer.lexem;
            getText(expr, 0);
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression label = new Expression;
                label.operator = lexer.lexem;
                getLexem;

                if (lexer == ";")
                {
                    getText(label, 0);
                    return [expr];
                }
                else 
                {
                    writefln("; Expected not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == ";")
            {
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("Label or ; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "return")
        {
            Expression expr = new Expression;
            expr.type = "return";
            getText(expr, 0);
            Expression e = getExpression;

            if (e !is null)
            {
                expr.arguments ~= e;
                expr.texts[1][1] = e.texts[1][1];
                e.texts[1][1] = [];
            }

            if (lexer == ";")
            {
                oexpr.addChilds(comments.arguments);
                getText(expr, 1);
                return [expr];
            }
            else 
            {
                writefln("; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "struct")
        {
            return [getStruct];
        }
        else if (lexer == "class")
        {
            return [getClass];
        }
        else if (lexer == "{")
        {
            if (parentheses) *parentheses = true;
            Expression a = new Expression;
            a.type = "{";
            cexpr = a;
Body:
            Expression[] b = getStatement;

            if (b !is null)
            {
                a.arguments ~= b;
                goto Body;
            }
            getLexem;

            if (lexer == "}")
            {
                cexpr = oexpr;
                return a.arguments;
            }
            else 
            {
                writefln("} Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "++"
                || lexer == "--"
                || lexer == "(")
        {
            cexpr.arguments = sargs;
            lexer = back;
            Expression ret = getExpression;

            if (lexer == ";")
            {
                {}
            }
            else 
            {
                writefln("Expected ; not %s", lexer);
                assert(0);
            }
            return [ret];
        }
        else if (lexer == "case"
                || lexer == "default"
                || lexer == "}")

        {
            cexpr.arguments = sargs;
            lexer = back;
            cexpr = oexpr;
            return null;
        }
        else if (lexer == LexemType.Identifier)
        {
            string name = lexer.lexem;
            Expression type = new Expression;
            type.operator = name;
            getText(type, 0);
            cexpr = comments;
Name:
            getLexem;

            if (lexer == "."
                    || lexer == "="
                    || lexer == "+="
                    || lexer == "-="
                    || lexer == "*="
                    || lexer == "/="
                    || lexer == "~="
                    || lexer == "++"
                    || lexer == "--"
                    || lexer == "(")
            {
                lexer = back;
                comments.arguments = [];
                oexpr.arguments = sargs;
                Expression expr = getExpression;

                if (lexer == ";")
                {
                    oexpr.addChilds(comments.arguments);
                    cexpr = oexpr;
                    return [expr];
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == "*")
            {
                Expression ptr = new Expression;
                ptr.operator = "*";
                ptr.type = "type";
                ptr.arguments ~= type;
                type = ptr;
                goto Name;
            }
            else if (lexer == "[")
            {
                Expression ar = new Expression;
                ar.operator = "[]";
                ar.type = "type";
                Expression ty = new Expression;
                ar.arguments ~= ty;
                ar.arguments ~= type;
                type = ar;
                getLexem;

                if (lexer == "]")
                {
                    {}
                }
                else if (lexer == LexemType.Identifier)
                {
                    ty.operator = lexer.lexem;
                    getLexem;

                    if (lexer == "]")
                    {
                        {}
                    }
                    else 
                    {
                        lexer = back;
                        comments.arguments = [];
                        oexpr.arguments = sargs;
                        cexpr = oexpr;
                        return [getExpression];
                    }
                }
                else 
                {
                    lexer = back;
                    comments.arguments = [];
                    oexpr.arguments = sargs;
                    cexpr = oexpr;
                    return [getExpression];
                }
                goto Name;
            }
            else if (lexer == ";")
            {
                oexpr.addChilds(comments.arguments);
                cexpr = oexpr;
                return [type];
            }
            else if (lexer == ":")
            {
                oexpr.addChilds(comments.arguments);
                cexpr = oexpr;
                Expression label = new Expression;
                label.type = ":";
                label.addChild(type);
                return [label];
            }
            else if (lexer == LexemType.Identifier)
            {
                Expression expr = new Expression;
                expr.operator = lexer.lexem;
                expr.type = "var";
                getText(expr, 0);
                type.index = PostfixType.Prefix;
                getLexem;

MVar:
                if (lexer == ",")
                {
                    Expression multi = new Expression;
                    multi.operator = ".";
                    multi.arguments ~= expr;
Var:
                    getLexem;

                    if (lexer == LexemType.Identifier)
                    {
                        Expression var = new Expression;
                        var.operator = lexer.lexem;
                        var.type = "var";
                        getText(var, 0);
                        multi.arguments ~= var;
                        getLexem;

                        if (lexer == ",")
                        {
                            goto Var;
                        }
                        else if (lexer == ";")
                        {
                            getText(multi, 1);
                            multi.addPosts([type]);
                            cexpr = oexpr;
                            return [multi];
                        }
                        else if (lexer == "=")
                        {
                            Expression assign = new Expression;
                            assign.operator = "=";
                            getText(var, 0);
                            assign.index = PostfixType.Postfix;
                            var.addPosts([assign]);
                            Expression asexpr = getExpression;
                            assign.arguments ~= asexpr;
                            assign.texts[1][1] = asexpr.texts[1][1];
                            asexpr.texts[1][1] = [];

                            if (lexer == ";")
                            {
                                getText(multi, 1);
                                multi.addPosts([type]);
                                cexpr = oexpr;
                                return [multi];
                            }
                            else 
                            {
                                writefln("Expected ; not %s", lexer);
                                assert(0);
                            }
                        }
                        else 
                        {
                            writefln("; or , or () Expected not %s", lexer);
                            assert(0);
                        }
                    }
                    else 
                    {
                        writefln("Identifier Expected not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == ";")
                {
                    expr.addPosts([type]);
                    cexpr = oexpr;
                    getText(expr, 1);
                    return [expr];
                }
                else if (lexer == "=")
                {
                    Expression assign = new Expression;
                    assign.operator = "=";
                    getText(expr, 0);
                    assign.index = PostfixType.Postfix;
                    expr.addPosts([assign]);
                    Expression asexpr = getExpression;
                    assign.arguments ~= asexpr;
                    assign.texts[1][1] = asexpr.texts[1][1];
                    asexpr.texts[1][1] = [];

                    if (lexer == ";")
                    {
                        expr.addPosts([type]);
                        cexpr = oexpr;
                        return [expr];
                    }
                    else if (lexer == ",")
                    {
                        goto MVar;
                    }
                    else 
                    {
                        writefln("Expected ; not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == "(")
                {
                    expr.addPosts([type]);
                    expr.type = "function";
                    expr.arguments ~= getArguments;

                    if (expr.operator == "function")
                    {
                        expr.operator = "";
                        type = expr;
                        expr = new Expression;
                        getLexem;

                        if (lexer == LexemType.Identifier)
                        {
                            expr.operator = lexer.lexem;
                            expr.addPosts([type]);
                        }
                        else 
                        {
                            writefln("Identifier Expected not %s", lexer);
                            assert(0);
                        }
                        getLexem;

                        if (lexer == ";")
                        {
                            cexpr = oexpr;
                            return [expr];
                        }
                        else 
                        {
                            writefln("Expected ; not %s", lexer);
                            assert(0);
                        }
                    }
                    sargs = cexpr.arguments;
                    back = lexer;
                    getLexem;

                    if (lexer == "{")
                    {
                        lexer = back;
                        cexpr.arguments = sargs;
                        expr.addPosts([getBody]);
                        oexpr.addChilds(comments.arguments);
                        cexpr = oexpr;
                        return [expr];
                    }
                    else if (lexer == ";")
                    {
                        oexpr.addChilds(comments.arguments);
                        cexpr = oexpr;
                        return [expr];
                    }
                    else 
                    {
                        writefln("Expected { or ; not %s", lexer);
                        assert(0);
                    }
                }
                else 
                {
                    writefln("Expected , or ; or () not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == LexemType.AssignOperator)
            {
                Expression expr = new Expression;
                expr.operator = lexer.lexem;
                Expression var = new Expression;
                var.operator = name;
                expr.arguments ~= var;
                expr.arguments ~= getExpression;

                if (lexer == ";")
                {
                    oexpr.addChilds(comments.arguments);
                    cexpr = oexpr;
                    return [expr];
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
            }
            else 
            {
                writefln("Expected  or Identifier or AssignOperator not %s", lexer);
                assert(0);
            }
        }
        else 
        {
            writefln("Statement Expected not %s", lexer);
            assert(0);
        }
    }

    Expression getInnerStat()
    {
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            string name = lexer.lexem;
            getLexem;

            if (lexer == "(")
            {
                Expression expr = new Expression;
                expr.operator = name;
                expr.arguments = getCallArgs;
                getLexem;

                if (lexer == ";")
                {
                    return expr;
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == LexemType.Identifier)
            {
                Expression expr = new Expression;
                expr.operator = lexer.lexem;
                Expression type = new Expression;
                type.operator = name;
                expr.arguments ~= type;
                getLexem;

                if (lexer == ")"
                        || lexer == ";")
                {
                    back;
                    return expr;
                }
                else if (lexer == "=")
                {
                    Expression assign = new Expression;
                    assign.operator = "=";
                    assign.arguments ~= expr;
                    assign.arguments ~= getExpression;

                    if (lexer == ")"
                            || lexer == ";")
                    {
                        back;
                        return assign;
                    }
                    else 
                    {
                        writefln("Expected ; not %s", lexer);
                        assert(0);
                    }
                }
                else 
                {
                    writefln("Expected ; or () not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == LexemType.AssignOperator)
            {
                Expression expr = new Expression;
                expr.operator = lexer.lexem;
                Expression var = new Expression;
                var.operator = name;
                expr.arguments ~= var;
                expr.arguments ~= getExpression;

                if (lexer == ")"
                        || lexer == ";")
                {
                    back;
                    return expr;
                }
                else 
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
            }
            else 
            {
                writefln("Expected  or Identifier or AssignOperator not %s", lexer);
                assert(0);
            }
        }
        else 
        {
            back;
            Expression expr = getExpression;
            back;
            return expr;
        }
    }

    Expression[] getArguments()
    {
        Expression[] ret;
        Expression[] post;
Init:
        getLexem;

        if (lexer == ")")
        {

            if (ret.length > 0){
                getText(ret.back, 1);
            }

        }
        else if (lexer == "in"
                || lexer == "out"
                || lexer == "ref")
        {
            Expression expr = new Expression;
            expr.operator = lexer.lexem;

            expr.index = PostfixType.Prefix;
            getText(expr, 0);
            post ~= expr;
            goto Init;
        }
        else if (lexer == LexemType.Identifier)
        {
            Expression arg = new Expression;
            Expression type = new Expression;
            type.operator = lexer.lexem;
            getText(arg, 0);
Name:
            getLexem;

            if (lexer == "*")
            {
                Expression ptr = new Expression;
                ptr.type = "*";
                ptr.arguments ~= type;
                type = ptr;
                goto Name;
            }
            else if (lexer == "[")
            {
                Expression ar = new Expression;
                ar.operator = "[]";
                ar.type = "type";

                Expression ty = new Expression;
                ar.arguments ~= ty;
                ar.arguments ~= type;

                type = ar;
Type:
                getLexem;

                if (lexer == "]")
                {
                    {}
                }
                else if (lexer == LexemType.Identifier)
                {
                    ty.operator = lexer.lexem;
                    goto Type;
                }
                else 
                {
                    writefln("] Expected not %s", lexer);
                    assert(0);
                }
                goto Name;
            }
            else if (lexer == "!")
            {
                Expression q = new Expression;
                q.operator = lexer.lexem;
                Expression eq = new Expression;
                eq.type = lexer.lexem;
                type.arguments ~= q;
                getLexem;

                if (lexer == LexemType.Identifier)
                {
                    Expression a = new Expression;
                    a.operator = lexer.lexem;
                    type.arguments ~= a;
                }
                else if (lexer == "(")
                {
                    type.arguments ~= getArguments;
                }
                type.arguments ~= eq;
                goto Name;
            }
            else if (lexer == ")")
            {

                return ret;
            }
            else if (lexer == LexemType.Identifier)
            {
                arg.operator = lexer.lexem;
                getText(arg, 0);
                type.index = PostfixType.Prefix;
                arg.addPosts([type] ~ post);
                ret ~= arg;
            }
            else 
            {
                writefln("Identifier Expected not %s", lexer);
                assert(0);
            }
            getLexem;

            if (lexer == "=")
            {
                Expression iarg = new Expression;
                Expression init = getExpression;
                iarg.type = "init";
                getText(iarg, 0);
                iarg.addChild(init);
                arg.addPosts([iarg]);

                if (lexer == ")")
                {
                    getText(ret.back, 1);
                }
                else if (lexer == ",")
                {
                    getText(ret.back, 1);
                    post = null;
                    goto Init;
                }
                else 
                {
                    writefln(", or  Expected not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == ")")
            {
            }
            else if (lexer == ",")
            {
                post = null;
                goto Init;
            }
            else 
            {
                writefln(", or  or () Expected not %s", lexer);
                assert(0);
            }
        }
        else 
        {
            writefln("Expected Identifier or  not %s", lexer);
            assert(0);
        }
        return ret;
    }

    Expression[] getCallArgs()
    {
        Expression[] ret;
Init:
        Expression expr = getExpression;

        if (expr !is null)
        {
            ret ~= expr;

            if (lexer == ",")
            {
                getText(expr, 1);
                goto Init;
            }
            else if (lexer == ")")
            {
                getText(expr, 1);
                return ret;
            }
            else 
            {
                writefln("Expected , or  not %s", lexer);
                assert(0);
            }
        }

        if (lexer == ")")
        {
            {}
        }
        else 
        {
            writefln("Expected  not %s", lexer);
            assert(0);
        }
        return ret;
    }

    Expression getExpression()
    {
        Expression ret = new Expression;
        Expression ed = ret;
        Expression oexpr = cexpr;
        //cexpr = ret;
Argument:
        getLexem;

        if (lexer == "cast")
        {
            Expression ct = new Expression;
            ct.type = lexer.lexem;
            getLexem;

            if (lexer == "(")
            {
                {}
            }
            else 
            {
                writefln("Bracket expected not %s", lexer);
                assert(0);
            }
            ct.addChilds(getCallArgs);

            if (ed.operator.empty && ed.type.empty)
            {
                ed.type = ct.type;
                ed.addChilds(ct.arguments);
            }
            else 
            {
                ed.addChild(ct);
                ed = ct;
            }
            goto Argument;
        }
        else if (lexer == "new")
        {

            if (ed.operator.empty && ed.type.empty)
            {
                ed.type = lexer.lexem;
            }
            else 
            {
                Expression n = new Expression;
                n.type = lexer.lexem;
                ed.addChild(n);
                ed = n;
            }
            goto Argument;
        }
        else if (lexer == LexemType.Identifier)
        {
            Expression arg = new Expression;
            arg.operator = lexer.lexem;
            getText(arg, 0);
            getLexem;

            if (lexer == "(")
            {
                arg.addChilds(getCallArgs);
                ed.addChild(arg);
                getLexem;
            }
            else 
            {
                cexpr = arg;
                ed.addChild(arg);
            }
            goto Operator;
        }
        else if (lexer == LexemType.String)
        {
            Expression arg = new Expression;
            arg.operator = lexer.lexem;
            arg.bt = BlockType.String;
            getText(arg, 0);
            ed.addChild(arg);
            getLexem;
        }else if (lexer == LexemType.Number || lexer == LexemType.Float || lexer == LexemType.Character || lexer == LexemType.LenOperator)
        {
            Expression arg = new Expression;
            arg.operator = lexer.lexem;
            getText(arg, 0);
            ed.addChild(arg);
            getLexem;
        }
        else if (lexer == LexemType.Operator)
        {
            string op = ed.operator;

            if (op.empty)
            {
                op = ed.type;
            }

            if (ed.hidden)
            {
                op = "P";
            }

            if (op.empty)
            {
                ed.operator = lexer.lexem;
                ed.type = "unary";
            }
            else if ((op == "!") && ((lexer == "is") || (lexer == "in")))
            {
                ed.operator ~= lexer.lexem;
            }
            else 
            {
                Expression expr = new Expression;
                expr.operator = lexer.lexem;
                expr.type = "unary";
                ed.addChild(expr);
                ed = expr;
            }
            goto Argument;
        }
        else if (lexer == "(")
        {
            Expression expr = getExpression;

            if (!expr.arguments.empty)
            {
                expr.hidden = true;
            }
            ed.arguments ~= expr;
            expr.parentheses = true;

            if (lexer == ")")
            {
                getLexem;
            }
            else 
            {
                writefln("Expected  not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "{")
        {
            Expression br = new Expression;
            br.type = "brace";
Brace:
            Expression expr = getExpression;

            if (expr !is null)
            {
                br.addChild(expr);
            }

            if (lexer == ",")
            {
                goto Brace;
            }
            else if (lexer == "}")
            {

                if (ed.operator.empty && ed.type.empty)
                {
                    ed.type = br.type;
                    ed.addChilds(br.arguments);
                }
                else 
                {
                    ed.addChild(br);
                }
                getLexem;
            }
            else 
            {
                writefln("] or ; expected not %s", lexer);
            }
        }
        else if (lexer == "[")
        {
            Expression br = new Expression;
            br.operator = "[]";
Array:
            Expression expr = getExpression;

            if (expr !is null)
            {
                br.addChild(expr);
            }

            if (lexer == ",")
            {
                goto Array;
            }
            else if (lexer == "]")
            {

                if (ed.operator.empty && ed.type.empty)
                {
                    ed.operator = br.operator;
                    ed.addChilds(br.arguments);
                }
                else 
                {
                    ed.addChild(br);
                }
                getLexem;
            }
            else 
            {
                writefln("] or ; expected not %s", lexer);
            }
        }
        else if (lexer == "]"
                || lexer == ";"
                || lexer == "}"
                || lexer == ")")
        {
            writefln("cexpr=%s oexpr=%s", cexpr, oexpr);
            cexpr = oexpr;
            return null;
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
Operator:
        if (lexer == "."
                || lexer == "?"
                || lexer == ":"
                || lexer == "in"
                || lexer == "is"
                || lexer == LexemType.AssignOperator
                || lexer == LexemType.CmpOperator
                || lexer == LexemType.Operator)
        {
            string op2 = lexer.lexem;

            if (op2 == "!")
            {
                getLexem;

                if (lexer == "is"
                        || lexer == "in")
                {
                    op2 ~= lexer.lexem;
                }
                else 
                {
                    writefln("Expected () or () not %s", lexer);
                    assert(0);
                }
            }
LookOp:
            string op = ed.operator;

            if (op.empty)
            {
                op = ed.type;
            }

            if (ed.hidden)
            {
                op = "P";
            }

            if (op.empty)
            {

                if (op2 == "?"
                        || op2 == ":"
                        || op2 == ".")
                {
                    ed.type = op2;
                }
                else 
                {
                    ed.operator = op2;
                }
            }
            else if (op == op2)
            {
                {}
            }
            else if (getPriority(op2) >= getPriority(op))
            {
                Expression expr = new Expression;

                if (op2 == "?"
                        || op2 == ".")
                {
                    expr.type = op2;
                }
                else if (op2 == ":")
                {
                    goto Argument;
                }
                else 
                {
                    expr.operator = op2;
                }

                if (getPriority(op2) == getPriority(op))
                {
                    Expression pared = ed.parent;

                    if (pared)
                    {
                        pared.popChild;
                        pared.addChild(expr);
                    }
                    else 
                    {
                        expr.texts[1][0] ~= ret.texts[1][0];
                        ret.texts[1][0] ~= "";
                        ret = expr;
                    }
                    expr.addChild(ed);
                }
                else 
                {
                    Expression ch = ed.popChild;
                    expr.addChild(ch);
                    ed.addChild(expr);
                }
                ed = expr;
            }
            else if (ed.parent)
            {
                ed = ed.parent;
                goto LookOp;
            }
            else 
            {
                Expression expr = new Expression;

                if (op2 == "?"
                        || op2 == ":"
                        || op2 == ".")
                {
                    expr.type = op2;
                }
                else 
                {
                    expr.operator = op2;
                }
                expr.texts[1][0] ~= ret.texts[1][0];
                ret.texts[1][0] = [""];
                ret = expr;
                expr.addChild(ed);
                ed = expr;
            }

            if (lexer == "++"
                    || lexer == "--")
            {
                ed.type = "post";
                getLexem;
                goto Operator;
            }
            goto Argument;
        }

        else if (lexer == "(")
        {
            ed.arguments[($ - 1)].addChilds(getCallArgs);
            getLexem;
            goto Operator;
        }
        else if (lexer == "[")
        {
            Expression slice = new Expression;
            slice.type = "[";
            Expression s1 = getExpression;

            if (s1)
            {
                slice.addChild(s1);
            }

            if (lexer == "..")
            {
                Expression ss = new Expression;
                ss.operator = "..";
                Expression s2 = getExpression;
                slice.addChild(ss);
                slice.addChild(s2);
            }

            if (lexer == "]")
            {
LookOp2:
                string op = ed.operator;

                if (op.empty)
                {
                    op = ed.type;
                }

                if (ed.hidden)
                {
                    op = "P";
                }

                if (op.empty)
                {
                    ed.type = ".";
                    ed.addChild(slice);
                }
                else if (op == ".")
                {
                    ed.addChild(slice);
                }
                else if (getPriority(".") >= getPriority(op))
                {
                    Expression expr = new Expression;
                    expr.type = ".";
                    Expression ch = ed.popChild;
                    expr.addChild(ch);
                    expr.addChild(slice);
                    ed.addChild(expr);
                    ed = expr;
                }
                else if (ed.parent)
                {
                    ed = ed.parent;
                    goto LookOp2;
                }
                else 
                {
                    Expression expr = new Expression;
                    expr.type = ".";

                    if (ed.parent)
                    {
                        ed.parent.addChild(expr);
                    }
                    else 
                    {
                        expr.texts[1][0] ~= ret.texts[1][0];
                        ret.texts[1][0] = [""];
                        ret = expr;
                    }
                    expr.addChild(ed);
                    expr.addChild(slice);
                    ed = expr;
                }
                getLexem;
                goto Operator;
            }
            else 
            {
                writefln("] Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == ","
                || lexer == ".."
                || lexer == ")"
                || lexer == "}"
                || lexer == "]"
                || lexer == ";")
        {
            if ((ret.operator is null) && (ret.type is null))
            {
                oexpr.arguments ~= ret.arguments[0..$-1];
                writefln("OEXPR %s", oexpr);
                ret.arguments[($ - 1)].texts[1][0] ~= ret.texts[1][0];
                ret = ret.arguments[($ - 1)];
            }
            getText(ret, 1);
            writefln("cexpr=%s oexpr=%s", cexpr, oexpr);
            cexpr = oexpr;
            return ret;
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
    }

    Expression getCaseVal()
    {
        Expression ret = new Expression;
        Expression ed = ret;
Argument:
        getLexem;
        if (lexer == LexemType.String || lexer == LexemType.Number || lexer == LexemType.Character || lexer == LexemType.Identifier)
        {
            Expression arg = new Expression;
            arg.operator = lexer.lexem;
            getText(arg, 0);
            ed.arguments ~= arg;
            getLexem;
            goto Operator;
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
Operator:
        if (lexer == ".")
        {
            ed.type = lexer.lexem;
            goto Argument;
        }
        else if (lexer == ":")
        {
            getText(ed.arguments.back, 0);
            if ((ret.operator is null) && (ret.type is null))
            {
                ret = ret.arguments[0];
            }
            return ret;
        }
        else 
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
    }

    int getPriority(string op)
    {
        switch (op) {
            case "..":
                {
                    return 0;
                }
            case ",":
                {
                    return 1;
                }
            case "=>":
                {
                    return 2;

                }
            case "=":
            case "^^=":
            case "*=":
            case "/=":
            case "%=":
            case "+=":
            case "-=":
            case "~=":
            case "<<=":
            case ">>=":
            case ">>>=":
            case "&=":
            case "|=":
            case "^=":
                {
                    return 3;

                }
            case "?":
            case ":":
                   {
                       return 4;
                   }
            case "||":
                   {
                       return 5;
                   }
            case "&&":
                   {
                       return 6;
                   }
            case "|":
                   {
                       return 7;
                   }
            case "^":
                   {
                       return 8;
                   }
            case "&":
                   {
                       return 9;

                   }
            case "==":
            case "!=":
            case ">":
            case "<":
            case ">=":
            case "<=":
            case "in":
            case "!in":
            case "is":
            case "!is":
                   {
                       return 10;

                   }
            case "<<":
            case ">>":
            case ">>>":
                   {
                       return 11;
                   }

            case "+":
            case "-":
            case "~":
                   {
                       return 12;
                   }

            case "*":
            case "/":
            case "%":
                   {
                       return 13;
                   }

            case "!":
            case "cast":
            case "unary":
                   {
                       return 14;
                   }
            case "^^":
                   {
                       return 15;
                   }

            case ".":
            case "++":
            case "--":
            case "postfix":
                   {
                       return 16;
                   }
            case "lambda":
                   {
                       return 17;
                   }
            case "templ":
                   {
                       return 18;
                   }
            default:
                   {
                       return 100;
                   }
        }
    }

    void back()
    {
        backed = true;
    }
    bool backed;
}
