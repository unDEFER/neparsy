module parser;
import std.stdio;
import std.range;
import std.utf;
import std.uni;
import std.algorithm.searching;
import lexer;
import expression;

class Parser {
    Lexer lexer;
    bool is_c = false;

    void getLexem()
    {
        if (backed)
        {
            backed = false;
            return;
        }

        lexer.getLexem();
    }

    Expression parse()
    {
        Expression file = new Expression;
        file.bt = BlockType.File;
        Expression ret = new Expression;
        file.arguments ~= ret;
        ret.type = "module";
        ret.label = "C";

        Init:
        getLexem;

        if (lexer == "module")
        {
            ret.type_lexem = lexer.lexem;
            ret.operator_lexem = getModuleName;
            ret.operator = ret.operator_lexem.text;
            ret.label = "D";
            goto Init;
        }
        else if (lexer == "import")
        {
            ret.arguments ~= getImport;
            goto Init;
        }
        else if (lexer == "struct")
        {
            Expression sexpr = getStruct;
            if (sexpr.open_lexem.text is null)
            {
                writefln("{ Expected not %s", lexer);
                assert(0);
            }

            ret.arguments ~= sexpr;

            if (!sexpr.arguments.empty && sexpr.arguments[$-1].type == "quote")
            {
                ret.arguments ~= sexpr.arguments[$-1];
                sexpr.arguments.length--;
            }

            goto Init;
        }
        else if (lexer == "class")
        {
            ret.arguments ~= getClass;
            goto Init;
        }
        else if (lexer == "enum")
        {
            Expression eexpr = getEnum;
            ret.arguments ~= eexpr;
            if (!eexpr.arguments.empty && eexpr.arguments[$-1].type == "quote")
            {
                ret.arguments ~= eexpr.arguments[$-1];
                eexpr.arguments.length--;
            }
            goto Init;
        }
        else if (lexer == LexemType.Identifier)
        {
            ret.arguments ~= getVar;
            goto Init;
        }
        else if (isCPreprocessorDirective(ret))
        {
            goto Init;
        }
        else if (lexer == LexemType.EndInput)
        {
        }
        else
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }
        return file;
    }

    bool isCPreprocessorDirective(Expression ret)
    {
        if (lexer == "#")
        {
            Lexem sharp = lexer.lexem;
            getLexem;

            if (lexer == "include")
            {
                ret.arguments ~= getCInclude();
                ret.arguments[$-1].type_lexem = sharp;
                getLexem;

                if (lexer == LexemType.EndOfCMacros)
                {
                    return true;
                }
                else
                {
                    writefln("Expected End Of Line not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer.lexem.text.endsWith("define"))
            {
                ret.arguments ~= getCDefine();
                ret.arguments[$-1].type_lexem = sharp;

                if (lexer == LexemType.EndOfCMacros)
                {
                    return true;
                }
                else
                {
                    writefln("Expected End Of Line not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == "if" || lexer == "ifdef" || lexer == "ifndef" || lexer == "elif")
            {
                ret.arguments ~= getCIf();
                ret.arguments[$-1].type_lexem = sharp;
                return true;
            }
            else if (lexer == "else" || lexer == "endif")
            {
                ret.arguments ~= getCEndIf();
                ret.arguments[$-1].type_lexem = sharp;
                return true;
            }
            else
            {
                writefln("Unknown c-preprocessor directive #%s", lexer);
                assert(0);
            }
        }

        return false;
    }

    Lexem getModuleName()
    {
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            Lexem ret = lexer.lexem;
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
        ret.type_lexem = lexer.lexem;
        Lexem modname;
        Init:
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            if (modname.text is null)
            {
                modname = lexer.lexem;
            }
            else
            {
                modname.text ~= lexer.lexem.text;
                modname.end = lexer.lexem.end;
            }
        }
        else
        {
            writefln("Expected identifier not %s", lexer);
            assert(0);
        }
        getLexem;

        if (lexer == ".")
        {
            modname.text ~= ".";
            goto Init;
        }
        else if (lexer == ":")
        {
            Expression mod = new Expression;
            mod.operator_lexem = modname;
            mod.operator = mod.operator_lexem.text;
            ret.arguments ~= mod;

            Expression cexpr = new Expression;
            cexpr.operator_lexem = lexer.lexem;
            cexpr.operator = cexpr.operator_lexem.text;

            Expression qexpr = new Expression;
            qexpr.type = "quote";
            qexpr.addChilds([cexpr]);

            mod.addChilds([qexpr]);

            Ident:
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression name = new Expression;
                name.operator_lexem = lexer.lexem;
                name.operator = name.operator_lexem.text;
                mod.arguments ~= name;
                getLexem;

                if (lexer == "=")
                {
                    Expression eexpr = new Expression;
                    eexpr.operator_lexem = lexer.lexem;
                    eexpr.operator = eexpr.operator_lexem.text;

                    Expression qeexpr = new Expression;
                    qeexpr.type = "quote";
                    qeexpr.addChilds([eexpr]);

                    getLexem;

                    if (lexer == LexemType.Identifier)
                    {
                        Expression rename = new Expression;
                        rename.operator_lexem = lexer.lexem;
                        rename.operator = rename.operator_lexem.text;
                        qeexpr.postop = rename;
                        name.postop = qeexpr;
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
            mod.operator_lexem = modname;
            mod.operator = mod.operator_lexem.text;
            ret.arguments ~= mod;
            return ret;
        }
        else
        {
            writefln("Expected . or ; not %s", lexer);
            assert(0);
        }
    }

    Expression getStruct()
    {
        Expression ret = new Expression;
        ret.type = "struct";
        ret.type_lexem = lexer.lexem;
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator_lexem = lexer.lexem;
            ret.operator = ret.operator_lexem.text;
            getLexem;
        }

        if (lexer == "{")
        {
            ret.open_lexem = lexer.lexem;
        }
        else
        {
            assert(ret.open_lexem.text is null);
            return ret;
        }

        ret.arguments = getDefinitions;
        ret.close_lexem = lexer.lexem;

        getLexem;

        if (lexer == ";")
        {
            Expression sexpr = new Expression;
            sexpr.operator_lexem = lexer.lexem;
            sexpr.operator = sexpr.operator_lexem.text;

            Expression qexpr = new Expression;
            qexpr.type = "quote";
            qexpr.addChilds([sexpr]);

            ret.arguments ~= qexpr;
        }
        else
        {
            back;
        }

        assert(ret.open_lexem.text !is null);
        return ret;
    }

    Expression getClass()
    {
        Expression ret = new Expression;
        ret.type = "class";
        ret.type_lexem = lexer.lexem;
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator_lexem = lexer.lexem;
            ret.operator = ret.operator_lexem.text;
            getLexem;
        }
        else
        {
        }

        if (lexer == "{")
        {
            ret.open_lexem = lexer.lexem;
        }
        else if (lexer == ":")
        {
            Lexem type_lexem = lexer.lexem;
            getLexem;

            if (lexer == LexemType.Identifier)
            {
            }
            else
            {
                writefln("Expected Identifier not %s", lexer);
                assert(0);
            }

            Expression name = new Expression;
            name.operator_lexem = lexer.lexem;
            name.operator = name.operator_lexem.text;
            name.type = "superclass";
            name.type_lexem = type_lexem;
            ret.arguments ~= name;
            Interface:
            getLexem;

            if (lexer == ",")
            {

                if (lexer == LexemType.Identifier)
                {
                }
                else
                {
                    writefln("Expected Identifier not %s", lexer);
                    assert(0);
                }
                Expression iname = new Expression;
                iname.operator_lexem = lexer.lexem;
                iname.operator = iname.operator_lexem.text;
                name.arguments ~= iname;
                goto Interface;
            }
            else if (lexer == "{")
            {
                ret.open_lexem = lexer.lexem;
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
        ret.close_lexem = lexer.lexem;
        return ret;
    }

    Expression[] getDefinitions()
    {
        Expression ret = new Expression;
        Init:
        getLexem;

        if (lexer == "struct")
        {
            Expression sexpr = getStruct;
            if (sexpr.open_lexem.text is null)
            {
                writefln("{ Expected not %s", lexer);
                assert(0);
            }
            ret.arguments ~= sexpr;
            goto Init;
        }
        else if (lexer == "class")
        {
            ret.arguments ~= getClass;
            goto Init;
        }
        else if (lexer == "enum")
        {
            Expression eexpr = getEnum;
            ret.arguments ~= eexpr;
            if (!eexpr.arguments.empty && eexpr.arguments[$-1].type == "quote")
            {
                ret.arguments ~= eexpr.arguments[$-1];
                eexpr.arguments.length--;
            }
            goto Init;
        }
        else if (lexer == LexemType.Identifier)
        {
            ret.arguments ~= getVar;
            goto Init;
        }
        else if (lexer == "}")
        {
            return ret.arguments;
        }
        else if (isCPreprocessorDirective(ret))
        {
            goto Init;
        }
        else
        {
            writefln("LexemType.Identifier expected not %s", lexer);
            assert(0);
        }
    }

    Expression getEnum()
    {
        Expression ret = new Expression;
        ret.type = "enum";
        ret.type_lexem = lexer.lexem;
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            ret.operator_lexem = lexer.lexem;
            ret.operator = ret.operator_lexem.text;
            getLexem;
        }
        else
        {
        }

        if (lexer == "{")
        {
            ret.open_lexem = lexer.lexem;
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
            val.operator_lexem = lexer.lexem;
            val.operator = val.operator_lexem.text;
            getLexem;

            if (lexer == "=")
            {
                Lexem ilexem = lexer.lexem;
                getLexem;

                if (lexer == LexemType.Character
                 || lexer == LexemType.Number)
                {
                    Expression einit = new Expression;
                    einit.operator_lexem = lexer.lexem;
                    einit.operator = einit.operator_lexem.text;

                    Expression init = new Expression;
                    init.type = "init";
                    init.type_lexem = ilexem;
                    init.addChilds([einit]);
                    if (lexer == LexemType.Character)
                        einit.bt = BlockType.Character;
                    val.postop = init;
                    getLexem;
                }
                else
                {
                    writefln("Number or Character Expected not %s", lexer);
                    assert(0);
                }
            }
            else
            {
            }

            if (lexer == ",")
            {
                ret.arguments ~= val;
                goto Values;
            }
            else if (lexer == "}")
            {
                ret.close_lexem = lexer.lexem;
                ret.arguments ~= val;
            }
            else
            {
                writefln(", or } Expected not %s", lexer);
                assert(0);
            }
        }
        else
        {
            writefln("{ Expected not %s", lexer);
            assert(0);
        }

        getLexem;

        if (lexer == ";")
        {
            Expression sexpr = new Expression;
            sexpr.operator_lexem = lexer.lexem;
            sexpr.operator = sexpr.operator_lexem.text;

            Expression qexpr = new Expression;
            qexpr.type = "quote";
            qexpr.addChilds([sexpr]);

            ret.arguments ~= qexpr;
        }
        else
        {
            back;
        }

        return ret;
    }

    Expression[] getVar()
    {
        Expression ret = new Expression;
        Expression type = new Expression;
        type.type = "type";
        Expression[]  pp;

        Init:
        if (lexer == "static"
         || lexer == "override"
         || lexer == "public"
         || lexer == "private"
         || lexer == "package"
         || lexer == "protected")
        {
            Expression post = new Expression;
            post.operator_lexem = lexer.lexem;
            post.operator = post.operator_lexem.text;
            pp ~= post;
            getLexem;
            goto Init;
        }
        else if (lexer == ":")
        {
            type.nl1 = ret.nl1;
            type.arguments ~= ret.arguments;
            type.type = ":";
            type.type_lexem = lexer.lexem;
            type.arguments ~= pp;
            type.postop = null;
            return [type];
        }
        else if (lexer == "this")
        {
            type.type = "constructor";
            type.type_lexem = lexer.lexem;
        }
        else if (lexer == LexemType.Identifier)
        {
            Expression typename = new Expression;
            typename.operator_lexem = lexer.lexem;
            typename.operator = typename.operator_lexem.text;
            type.arguments ~= typename;
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
            ret.operator_lexem = lexer.lexem;
            ret.operator = ret.operator_lexem.text;
            ret.type = "var";
            ret.arguments ~= type;
            getLexem;
        }
        else if (lexer == "*")
        {
            Expression nt = new Expression;
            nt.type = "*";
            nt.type_lexem = lexer.lexem;
            type.arguments = [nt] ~ type.arguments;
            getLexem;
            goto Var;
        }
        else if (lexer == "[")
        {
            Expression nt = new Expression;
            nt.operator = "[]";
            nt.open_lexem = lexer.lexem;
            type.arguments = [nt] ~ type.arguments;
            getLexem;

            if (lexer == "]")
            {
                nt.operator_lexem.end = lexer.lexem.end;
                nt.close_lexem = lexer.lexem;
                getLexem;
                goto Var;
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
            ret.open_lexem = lexer.lexem;
            ret.arguments ~= getArguments;
            ret.close_lexem = lexer.lexem;

            if (ret.operator == "function")
            {
                ret.operator = "";
                type = ret;
                ret = new Expression;
                getLexem;

                if (lexer == LexemType.Identifier)
                {
                    ret.operator_lexem = lexer.lexem;
                    ret.operator = ret.operator_lexem.text;
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
                    if (!pp.empty)
                    {
                        Expression attr = new Expression;
                        attr.type = "attr";
                        attr.arguments = pp;
                        attr.postop = ret;
                        ret = attr;
                    }

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
                ret.postop = getBody;
            }
            else if (lexer == ";")
            {
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
            ret.arguments = null;
            expr.arguments ~= ret;
            ret = expr;
            Var2:
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression var = new Expression;
                var.operator_lexem = lexer.lexem;
                var.operator = var.operator_lexem.text;
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
                Expression init = new Expression();
                init.type_lexem = lexer.lexem;
                init.type = "init";
                init.addChilds([getExpression]);
                expr.arguments[($ - 1)].postop = init;
                goto Comma;
            }
            else if (lexer == ";")
            {
                type.index = (-ret.arguments.length);
                ret.arguments[($ - 1)].addPosts([type]);

                if (!pp.empty)
                {
                    Expression attr = new Expression;
                    attr.type = "attr";
                    attr.arguments = pp;
                    attr.postop = ret;
                    return [attr];
                }

                return ret.arguments;
            }
            else
            {
                writefln("() or , or ; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "=")
        {
            Expression init = new Expression();
            init.type_lexem = lexer.lexem;
            init.type = "init";
            init.addChilds([getExpression]);
            ret.postop = init;
            goto Eq;
        }
        else if (lexer == ";")
        {
        }
        else if (lexer == "[")
        {
            Expression nt = new Expression;
            nt.operator = "[]";
            nt.open_lexem = lexer.lexem;
            nt.type = "carray";
            Expression args = getExpression;
            if (args !is null)
                nt.arguments ~= args;
            type.arguments = [nt] ~ type.arguments;

            if (lexer == "]")
            {
                nt.operator_lexem.end = lexer.lexem.end;
                nt.close_lexem = lexer.lexem;
                getLexem;
                goto Eq;
            }
            else
            {
                writefln("Expected ']', not %s", lexer);
                assert(0);
            }
        }
        else
        {
            writefln("Expected or () or ; or , not %s", lexer);
            assert(0);
        }

        if (!pp.empty)
        {
            Expression attr = new Expression;
            attr.type = "attr";
            attr.arguments = pp;
            attr.postop = ret;
            ret = attr;
        }

        return [ret];
    }

    Expression getCInclude()
    {
        Expression ret = new Expression;
        ret.operator = "include";
        ret.operator_lexem = lexer.lexem;
        ret.type = "cpreprocessor";
        Init:
        getLexem;

        if (lexer == LexemType.String)
        {
            Expression mod = new Expression;
            mod.operator_lexem = lexer.lexem;
            mod.operator = mod.operator_lexem.text;
            mod.bt = BlockType.String;
            ret.arguments ~= mod;
            return ret;
        }
        else if (lexer == "<")
        {
            Expression mod = new Expression;
            mod.operator_lexem = lexer.lexem;
            mod.operator = mod.operator_lexem.text;
            mod.bt = BlockType.String;
            ret.arguments ~= mod;

            HeaderFileName:
            getLexem;
            if (lexer == LexemType.Identifier || lexer == ".")
            {
                mod.operator ~= lexer.lexem.text;
                mod.operator_lexem.text ~= lexer.lexem.text;
                mod.operator_lexem.end = lexer.lexem.end;
                goto HeaderFileName;
            }
            else if (lexer == ">")
            {
                mod.operator ~= lexer.lexem.text;
                mod.operator_lexem.text ~= lexer.lexem.text;
                mod.operator_lexem.end = lexer.lexem.end;
                return ret;
            }
            else
            {
                writefln("Expected Identifier or '>' not %s", lexer);
                assert(0);
            }
        }
        else
        {
            writefln("Expected String or '<' not %s", lexer);
            assert(0);
        }
    }

    Expression getCDefine()
    {
        Expression ret = new Expression;
        ret.operator = "define";
        ret.operator_lexem = lexer.lexem;
        ret.type = "cpreprocessor";

        Expression macros = new Expression;
        ret.arguments ~= macros;
        Init:
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            macros.operator_lexem = lexer.lexem;
            macros.operator = macros.operator_lexem.text;
        }
        else
        {
            writefln("Expected Identifier not %s", lexer);
            assert(0);
        }

        if (lexer == "(")
        {
            macros.open_lexem = lexer.lexem;
            getLexem;

            if (lexer == ")")
            {
                macros.close_lexem = lexer.lexem;
                getLexem;
            }
            else if (lexer == LexemType.Identifier)
            {
                Argument:
                Expression arg = new Expression;
                arg.operator_lexem = lexer.lexem;
                arg.operator = arg.operator_lexem.text;

                macros.arguments ~= arg;
                getLexem;

                if (lexer == ")")
                {
                    macros.close_lexem = lexer.lexem;
                    getLexem;
                }
                else if (lexer == ",")
                {
                    getLexem;

                    if (lexer == LexemType.Identifier)
                    {
                        goto Argument;
                    }
                    else
                    {
                        writefln("Expected Identifier not %s", lexer);
                        assert(0);
                    }
                }
                else
                {
                    writefln("Expected ')' or ',' not %s", lexer);
                    assert(0);
                }
            }
            else
            {
                writefln("Expected ')' or Identifier not %s", lexer);
                assert(0);
            }
        }

        ret.postop = getExpression;

        return ret;
    }

    Expression getCIf()
    {
        Expression ret = new Expression;
        ret.operator = lexer.lexem.text;
        ret.operator_lexem = lexer.lexem;
        ret.type = "cpreprocessor";

        ret.arguments ~= getExpression;

        if (lexer != LexemType.EndOfCMacros)
        {
            writefln("Expected End Of Line, not %s", lexer);
            assert(0);
        }

        return ret;
    }

    Expression getCEndIf()
    {
        Expression ret = new Expression;
        ret.operator = lexer.lexem.text;
        ret.operator_lexem = lexer.lexem;
        ret.type = "cpreprocessor";

        getLexem;
        if (lexer != LexemType.EndOfCMacros)
        {
            writefln("Expected End Of Line, not %s", lexer);
            assert(0);
        }

        return ret;
    }

    Expression getBody()
    {
        Expression ret = new Expression;
        ret.type = "body";

        Init:
        Expression[] s = getStatement;

        if (s.length == 1 && s[0].type == "{")
        {
            ret.open_lexem = s[0].type_lexem;
            ret.close_lexem = s[0].close_lexem;
            s = s[0].arguments;
        }

        ret.arguments ~= s;
        return ret;
    }

    Expression getCaseBody()
    {
        Expression ret = new Expression;
        ret.type = "body";
        Init:
        Expression[] s = getStatement;

        if (s.length == 1 && s[0].type == "{")
        {
            ret.type_lexem = s[0].type_lexem;
            ret.close_lexem = s[0].close_lexem;
            s = s[0].arguments;
        }

        if (s is null)
        {
            return ret;
        }
        ret.arguments ~= s;
        goto Init;
    }

    Expression[] getStatement()
    {
        Expression[]  post;
        Lexer back = lexer;
        Attr:
        getLexem;

        if (lexer == "static")
        {
            Expression s = new Expression;
            s.operator_lexem = lexer.lexem;
            s.operator = s.operator_lexem.text;
            post ~= s;
            goto Attr;
        }
        else if (lexer == "if")
        {
            Expression expr = new Expression;
            if (post.length > 0 && post[$-1].operator == "static")
            {
                expr.type_lexem = post[$-1].operator_lexem;
                expr.type = "static-if";
                post = post[0..$-1];
            }
            else
            {
                expr.type = "if";
                expr.type_lexem = lexer.lexem;
            }
            expr.addPosts(post);
            Expression if_open_close = expr;
            Init:
            getLexem;

            if (lexer == "(")
            {
                if_open_close.open_lexem = lexer.lexem;
                Expression cond = getExpression;

                if (lexer == ")")
                {
                    if_open_close.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                cond.postop = getBody;
                expr.arguments ~= cond;
                back = lexer;
                getLexem;

                if (lexer == "else")
                {
                    Lexem else_lexem = lexer.lexem;
                    back = lexer;
                    getLexem;

                    if (lexer == "if")
                    {
                        Expression eexpr = new Expression;
                        eexpr.operator_lexem = else_lexem;
                        eexpr.operator = eexpr.operator_lexem.text;

                        Expression iexpr = new Expression;
                        iexpr.operator_lexem = lexer.lexem;
                        iexpr.operator = iexpr.operator_lexem.text;

                        Expression qexpr = new Expression;
                        qexpr.type = "quote";
                        qexpr.addChilds([eexpr, iexpr]);

                        expr.addChilds([qexpr]);
                        if_open_close = qexpr;

                        goto Init;
                    }
                    else
                    {
                        lexer = back;
                        Expression els = new Expression;
                        els.type = "else";
                        els.type_lexem = else_lexem;
                        els.postop = getBody;
                        expr.arguments ~= els;
                    }
                }
                else
                {
                    lexer = back;
                }
            }
            else
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
            return [expr];
        }
        else if (lexer == "switch")
        {
            Expression expr = new Expression;
            expr.type = "switch";
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                expr.open_lexem = lexer.lexem;
                Expression var = getExpression;

                if (lexer == ")")
                {
                    expr.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                expr.arguments ~= var;
                expr.postop = getBody;
            }
            else
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
            return [expr];
        }
        else if (lexer == "case")
        {
            Expression expr = new Expression;
            expr.type = "case";
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);
            expr.arguments ~= getCaseVal;
            expr.open_lexem = lexer.lexem;
            return [expr];
        }
        else if (lexer == "default")
        {
            Expression expr = new Expression;
            expr.type = "default";
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);

            getLexem;
            if (lexer == ":")
            {
            }
            else
            {
                writefln("Expected : not %s", lexer);
                assert(0);
            }
            expr.open_lexem = lexer.lexem;

            return [expr];
        }
        else if (lexer == "for")
        {
            Expression expr = new Expression;
            expr.type = "for";
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                expr.open_lexem = lexer.lexem;
                Expression iexpr = getInnerStat;
                getLexem;

                if (lexer == ";")
                {
                }
                else
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
                Expression cexpr = getExpression;

                if (lexer == ";")
                {
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
                    expr.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                if (iexpr is null) iexpr = new Expression;
                if (cexpr is null) cexpr = new Expression;
                if (pexpr is null) pexpr = new Expression;
                expr.arguments = [iexpr, cexpr, pexpr];
                return [expr];
            }
            else
            {
                writefln("Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "foreach" || lexer == "foreach_reverse")
        {
            Expression expr = new Expression;
            expr.type_lexem = lexer.lexem;
            expr.type = expr.type_lexem.text;
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                expr.open_lexem = lexer.lexem;
                Expression avar = new Expression;
                Expression bvar = new Expression;
                Expression[]  p1;
                Avar:
                getLexem;

                if (lexer == "ref")
                {
                    Expression aref = new Expression;
                    aref.operator_lexem = lexer.lexem;
                    aref.operator = aref.operator_lexem.text;
                    p1 ~= aref;
                    goto Avar;
                }
                else if (lexer == LexemType.Identifier)
                {
                    avar.operator_lexem = lexer.lexem;
                    avar.operator = avar.operator_lexem.text;
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
                        aref.operator_lexem = lexer.lexem;
                        aref.operator = aref.operator_lexem.text;
                        p1 ~= aref;
                        goto Bvar;
                    }
                    else if (lexer == LexemType.Identifier)
                    {
                        bvar.operator_lexem = lexer.lexem;
                        bvar.operator = bvar.operator_lexem.text;
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
                    bvar.operator_lexem = avar.operator_lexem;
                    avar.operator_lexem = Lexem.init;
                    bvar.operator = avar.operator;
                    avar.operator = null;
                }

                if (lexer == ";")
                {
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
                    expr.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                expr.arguments = [avar, bvar, cexpr];
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
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);
            getLexem;

            if (lexer == "(")
            {
                expr.open_lexem = lexer.lexem;
                Expression cexpr = getExpression;

                if (lexer == ")")
                {
                    expr.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                expr.postop = getBody;
                expr.arguments = [cexpr];
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
            expr.type_lexem = lexer.lexem;
            expr.addPosts(post);
            expr.addPosts([getBody]);
            getLexem;

            Expression wexpr = new Expression;

            if (lexer == "while")
            {
                wexpr.type = "while";
                wexpr.type_lexem = lexer.lexem;
                getLexem;
            }
            else
            {
                writefln("Expected while not %s", lexer);
                assert(0);
            }

            if (lexer == "(")
            {
                wexpr.open_lexem = lexer.lexem;
                Expression cexpr = getExpression;

                if (lexer == ")")
                {
                    wexpr.close_lexem = lexer.lexem;
                }
                else
                {
                    writefln("Expected . not %s", lexer);
                    assert(0);
                }
                wexpr.arguments ~= cexpr;
                expr.addPosts([wexpr]);
                getLexem;

                if (lexer == ";")
                {
                }
                else
                {
                    writefln("Expected ; not %s", lexer);
                    assert(0);
                }
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
            expr.type_lexem = lexer.lexem;
            expr.type = expr.type_lexem.text;
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression label = new Expression;
                label.operator_lexem = lexer.lexem;
                label.operator = label.operator_lexem.text;
                expr.arguments ~= label;
                getLexem;

                if (lexer == ";")
                {
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
                return [expr];
            }
            else
            {
                writefln("Label or ; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "goto")
        {
            Expression expr = new Expression;
            expr.type_lexem = lexer.lexem;
            expr.type = expr.type_lexem.text;
            getLexem;

            if (lexer == LexemType.Identifier)
            {
                Expression label = new Expression;
                label.operator_lexem = lexer.lexem;
                label.operator = label.operator_lexem.text;
                expr.arguments ~= label;
                getLexem;

                if (lexer == ";")
                {
                    return [expr];
                }
                else
                {
                    writefln("; Expected not %s", lexer);
                    assert(0);
                }
            }
            else
            {
                writefln("Label Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "return")
        {
            Expression expr = new Expression;
            expr.type_lexem = lexer.lexem;
            expr.type = "return";
            Expression e = getExpression;

            if (e !is null)
            {
                expr.arguments ~= e;
            }

            if (lexer == ";")
            {
                return [expr];
            }
            else
            {
                writefln("; Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "class")
        {
            return [getClass];
        }
        else if (lexer == "{")
        {
            Expression a = new Expression;
            a.type = "{";
            a.type_lexem = lexer.lexem;

            Body:
            Expression[] b = getStatement();

            if (b !is null)
            {
                a.arguments ~= b;
                goto Body;
            }
            getLexem;

            if (lexer == "}")
            {
                a.close_lexem = lexer.lexem;
                return [a];
            }
            else
            {
                writefln("} Expected not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == ";")
        {
            Expression a = new Expression;
            a.type = ";";
            a.type_lexem = lexer.lexem;
            return [a];
        }
        else if (lexer == "++"
         || lexer == "--"
         || lexer == "(")
        {
            lexer = back;
            Expression ret = getExpression;

            if (lexer == ";")
            {
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
            lexer = back;
            return null;
        }
        else if (lexer == "*")
        {
            lexer = back;
            Expression expr = getExpression;

            if (lexer == ";")
            {
                expr.addPosts(post);
                return [expr];
            }
            else
            {
                writefln("Expected ; not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == LexemType.Identifier)
        {
            Expression type = new Expression;
            type.type = "type";

            Expression typename = new Expression;
            Lexem name;

            if (lexer == "struct")
            {
                Expression sexpr = getStruct;
                if (sexpr.open_lexem.text is null)
                {
                    typename = sexpr;
                    type.arguments = [typename] ~ type.arguments;
                    goto Assign;
                }
                return [sexpr];
            }
            else if (is_c && (lexer == "signed" || lexer == "unsigned"))
            {
                typename.type_lexem = lexer.lexem;
                typename.type = typename.type_lexem.text;

                getLexem;
                if (lexer == LexemType.Identifier)
                {
                }
                else
                {
                    writefln("Identifier Expected not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == "const")
            {
                Expression a = new Expression;
                a.operator_lexem = lexer.lexem;
                a.operator = a.operator_lexem.text;
                if (type.arguments.empty)
                    type.arguments ~= a;
                else
                    type.arguments[0].postop = a;

                getLexem;
                if (lexer == LexemType.Identifier)
                {
                }
                else
                {
                    writefln("Identifier Expected not %s", lexer);
                    assert(0);
                }
            }

            name = lexer.lexem;
            typename.operator = name.text;
            typename.operator_lexem = lexer.lexem;

            type.arguments = [typename] ~ type.arguments;

            Name:
            getLexem;
            Assign:

            if (lexer == "."
             || lexer == "->"
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
                Expression expr = getExpression;

                if (lexer == ";")
                {
                    expr.addPosts(post);
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
                ptr.type = "*";
                ptr.type_lexem = lexer.lexem;
                type.arguments = [ptr] ~ type.arguments;
                goto Name;
            }
            else if (lexer == "[")
            {
                Expression ar = new Expression;
                ar.operator = "[]";
                ar.open_lexem = lexer.lexem;
                type.arguments = [ar] ~ type.arguments;
                getLexem;

                if (lexer == "]")
                {
                    ar.operator_lexem.end = lexer.lexem.end;
                    ar.close_lexem = lexer.lexem;
                }
                else if (lexer == LexemType.Identifier)
                {
                    Expression ty = new Expression;
                    ty.operator_lexem = lexer.lexem;
                    ty.operator = ty.operator_lexem.text;
                    ar.arguments ~= ty;
                    getLexem;

                    if (lexer == "]")
                    {
                        ar.operator_lexem.end = lexer.lexem.end;
                    }
                    else
                    {
                        lexer = back;
                        Expression expr = getExpression;
                        expr.addPosts(post);
                        return [expr];
                    }
                }
                else
                {
                    lexer = back;
                    Expression expr = getExpression;
                    expr.addPosts(post);
                    return [expr];
                }
                goto Name;
            }
            else if (lexer == ";" || lexer == LexemType.EndOfCMacros)
            {
                type.arguments[0].addPosts(post);
                return [type.arguments[0]];
            }
            else if (lexer == ":")
            {
                Expression label = new Expression;
                label.type = "label";
                label.type_lexem = lexer.lexem;
                label.addChild(type);
                return [label];
            }
            else if (lexer == LexemType.Identifier)
            {
                Expression expr = new Expression;

                if (lexer == "const")
                {
                    Expression a = new Expression;
                    a.operator_lexem = lexer.lexem;
                    a.operator = a.operator_lexem.text;
                    if (type.arguments.empty)
                        type.arguments ~= a;
                    else
                        type.arguments[0].postop = a;

                    goto Name;
                }

                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                expr.type = "var";
                expr.arguments ~= type;

                if (post.length > 0 && post[$-1].operator == "static")
                {
                    expr.addPosts(post);
                    post = null;
                }

                getLexem;

                Eq:

                if (lexer == ",")
                {
                    Expression var;
                    expr.arguments = null;
                    Expression multi = new Expression;
                    multi.arguments ~= expr;
                    multi.postop = type;
                    Var:
                    getLexem;

                    if (lexer == LexemType.Identifier)
                    {
                        if (var is null) var = new Expression;
                        var.operator_lexem = lexer.lexem;
                        var.operator = var.operator_lexem.text;
                        var.type = "var";
                        multi.arguments ~= var;
                        getLexem;

                        if (lexer == ",")
                        {
                            var = null;
                            goto Var;
                        }
                        else if (lexer == ";")
                        {
                            type.index = (-multi.arguments.length);
                            var.postop = type;
                            multi.addPosts(post);
                            return multi.arguments;
                        }
                        else if (lexer == "=")
                        {
                            Expression assign = new Expression;
                            assign.operator_lexem = lexer.lexem;
                            assign.operator = "=";
                            assign.arguments ~= expr;
                            assign.arguments ~= getExpression;

                            if (lexer == ";")
                            {
                                assign.addPosts(post);
                                return [assign];
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
                    else if (lexer == "*")
                    {
                        if (var is null) var = new Expression;
                        Expression ptr = new Expression;
                        ptr.type = "*";
                        ptr.type_lexem = lexer.lexem;
                        var.arguments ~= ptr;
                        goto Var;
                    }
                    else
                    {
                        writefln("Identifier Expected not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == ";")
                {
                    expr.addPosts(post);
                    return [expr];
                }
                else if (lexer == "=")
                {
                    Expression assign = new Expression;
                    assign.operator_lexem = lexer.lexem;
                    assign.operator = "=";
                    assign.arguments ~= expr;
                    assign.arguments ~= getExpression;

                    if (lexer == ";")
                    {
                        assign.addPosts(post);
                        return [assign];
                    }
                    else
                    {
                        writefln("Expected ; not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == "(")
                {
                    expr.type = "function";
                    expr.type_lexem = lexer.lexem;
                    expr.arguments ~= getArguments;

                    if (expr.operator == "function")
                    {
                        expr.operator = "";
                        type = expr;
                        expr = new Expression;
                        getLexem;

                        if (lexer == LexemType.Identifier)
                        {
                            expr.operator_lexem = lexer.lexem;
                            expr.operator = expr.operator_lexem.text;
                            expr.arguments ~= type;
                        }
                        else
                        {
                            writefln("Identifier Expected not %s", lexer);
                            assert(0);
                        }

                        getLexem;

                        if (lexer == ";")
                        {
                            expr.addPosts(post);
                            return [expr];
                        }
                        else
                        {
                            writefln("Expected ; not %s", lexer);
                            assert(0);
                        }
                    }

                    back = lexer;
                    getLexem;

                    if (lexer == "{")
                    {
                        lexer = back;
                        expr.postop = getBody;
                        expr.addPosts(post);
                        return [expr];
                    }
                    else if (lexer == ";")
                    {
                        expr.addPosts(post);
                        return [expr];
                    }
                    else
                    {
                        writefln("Expected { or ; not %s", lexer);
                        assert(0);
                    }
                }
                else if (lexer == "[")
                {
                    Expression nt = new Expression;
                    nt.operator = "[]";
                    nt.open_lexem = lexer.lexem;
                    nt.type = "carray";
                    Expression args = getExpression;
                    if (args !is null)
                        nt.arguments ~= args;
                    type.arguments = [nt] ~ type.arguments;

                    if (lexer == "]")
                    {
                        nt.operator_lexem.end = lexer.lexem.end;
                        nt.close_lexem = lexer.lexem;
                        getLexem;
                        goto Eq;
                    }
                    else
                    {
                        writefln("Expected ']', not %s", lexer);
                        assert(0);
                    }
                }
                else
                {
                    writefln("Expected , or ; or = or ( not %s", lexer);
                    assert(0);
                }
            }
            else if (lexer == LexemType.AssignOperator)
            {
                Expression expr = new Expression;
                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                Expression var = new Expression;
                var.operator_lexem = name;
                var.operator = name.text;
                expr.arguments ~= var;
                expr.arguments ~= getExpression;

                if (lexer == ";")
                {
                    expr.addPosts(post);
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
                writefln("Expected . or Identifier or AssignOperator not %s", lexer);
                assert(0);
            }
        }
        else
        {
            Expression expr = new Expression;
            if (isCPreprocessorDirective(expr))
                return expr.arguments;

            writefln("Statement Expected not %s", lexer);
            assert(0);
        }
    }

    Expression getInnerStat()
    {
        getLexem;

        if (lexer == LexemType.Identifier)
        {
            Lexem name = lexer.lexem;
            getLexem;

            if (lexer == "(")
            {
                Expression expr = new Expression;
                expr.operator_lexem = name;
                expr.operator = expr.operator_lexem.text;
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
                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                expr.type = "var";
                Expression type = new Expression;
                type.type = "type";
                Expression typename = new Expression;
                typename.operator_lexem = name;
                typename.operator = typename.operator_lexem.text;
                type.arguments ~= typename;
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
                    assign.operator_lexem = lexer.lexem;
                    assign.operator = assign.operator_lexem.text;
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
                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                Expression var = new Expression;
                var.operator_lexem = name;
                var.operator = var.operator_lexem.text;
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
            else if (lexer == "++"
                    || lexer == "--")
            {
                Expression expr = new Expression;
                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                expr.type = "post";
                Expression var = new Expression;
                var.operator_lexem = name;
                var.operator = var.operator_lexem.text;
                expr.arguments ~= var;

                getLexem;

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
                writefln("Expected . or Identifier or AssignOperator not %s", lexer);
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
        Expression[]  ret;
        Expression[]  post;
        Init:
        getLexem;

        if (lexer == ")")
        {
        }
        else if (lexer == "in"
         || lexer == "out"
         || lexer == "ref"
         || lexer == "const")
        {
            Expression expr = new Expression;
            expr.operator_lexem = lexer.lexem;
            expr.operator = expr.operator_lexem.text;
            post ~= expr;
            goto Init;
        }
        else if (lexer == LexemType.Identifier)
        {
            Expression arg = new Expression;
            Expression typename = new Expression;

            if (lexer == "struct")
            {
                typename.type_lexem = lexer.lexem;
                typename.type = typename.type_lexem.text;

                getLexem;
                if (lexer == LexemType.Identifier)
                {
                }
                else
                {
                    writefln("Identifier Expected not %s", lexer);
                    assert(0);
                }
            }

            typename.operator_lexem = lexer.lexem;
            typename.operator = typename.operator_lexem.text;

            Expression type = new Expression;
            type.type = "type";
            type.arguments ~= typename;

            Name:
            getLexem;

            if (lexer == "*")
            {
                Expression ptr = new Expression;
                ptr.type_lexem = lexer.lexem;
                ptr.type = "*";
                type.arguments = [ptr] ~ type.arguments;
                ptr.addPosts(post);
                post = [];
                goto Name;
            }
            else if (lexer == "[")
            {
                Expression ar = new Expression;
                ar.operator = "[]";
                ar.open_lexem = lexer.lexem;
                type.arguments = [ar] ~ type.arguments;
                Type:
                getLexem;

                if (lexer == "]")
                {
                    ar.operator_lexem.end = lexer.lexem.end;
                    ar.close_lexem = lexer.lexem;
                }
                else if (lexer == LexemType.Identifier)
                {
                    Expression ty = new Expression;
                    ty.operator_lexem = lexer.lexem;
                    ty.operator = ty.operator_lexem.text;
                    ar.arguments ~= ty;
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
                Expression eq = new Expression;
                eq.type_lexem = lexer.lexem;
                eq.type = eq.type_lexem.text;
                writefln("! %s", lexer.lexem);
                type.arguments[$-1].arguments ~= eq;
                getLexem;

                if (lexer == LexemType.Identifier)
                {
                    Expression a = new Expression;
                    a.operator_lexem = lexer.lexem;
                    a.operator = a.operator_lexem.text;
                    eq.arguments ~= a;
                }
                else if (lexer == "(")
                {
                    eq.open_lexem = lexer.lexem;
                    eq.arguments ~= getArguments;
                    eq.close_lexem = lexer.lexem;
                }
                goto Name;
            }
            else if (lexer == ")")
            {
                if (typename.operator == "void")
                    ret ~= type;
                return ret;
            }
            else if (lexer == "const")
            {
                Expression a = new Expression;
                a.operator_lexem = lexer.lexem;
                a.operator = a.operator_lexem.text;
                if (type.arguments.empty)
                    type.arguments ~= a;
                else
                    type.arguments[0].postop = a;
                goto Name;
            }
            else if (lexer == LexemType.Identifier)
            {
                arg.operator_lexem = lexer.lexem;
                arg.operator = arg.operator_lexem.text;
                arg.arguments ~= type;
                arg.arguments ~= post;
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
                Expression init = new Expression();
                init.type_lexem = lexer.lexem;
                init.type = "init";
                init.addChilds([getExpression]);
                arg.postop = init;

                if (lexer == ")")
                {
                }
                else if (lexer == ",")
                {
                    post = null;
                    goto Init;
                }
                else
                {
                    writefln(", or . Expected not %s", lexer);
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
                writefln(", or ) or = Expected not %s", lexer);
                assert(0);
            }
        }
        else
        {
            writefln("Expected Identifier or . not %s", lexer);
            assert(0);
        }
        return ret;
    }

    Expression[] getCallArgs()
    {
        Expression[]  ret;
        Init:
        Expression expr = getExpression;

        if (expr !is null)
        {
            ret ~= expr;

            if (lexer == ",")
            {
                goto Init;
            }
            else if (lexer == ")")
            {
                return ret;
            }
            else
            {
                writefln("Expected , or . not %s", lexer);
                assert(0);
            }
        }

        if (lexer == ")")
        {
        }
        else
        {
            writefln("Expected . not %s", lexer);
            assert(0);
        }
        return ret;
    }

    Expression getExpression()
    {
        Expression ret = new Expression;
        Expression ed = ret;
        Argument:
        getLexem;

        if (!is_c && lexer == "cast")
        {
            Expression ct = new Expression;
            ct.type_lexem = lexer.lexem;
            ct.type = ct.type_lexem.text;
            getLexem;

            if (lexer == "(")
            {
                ct.open_lexem = lexer.lexem;
            }
            else
            {
                writefln("Bracket expected not %s", lexer);
                assert(0);
            }

            ct.addChilds(getCallArgs);
            ct.close_lexem = lexer.lexem;

            if (ed.operator.empty && ed.type.empty)
            {
                ed.open_lexem = ct.open_lexem;
                ed.type = ct.type;
                ed.type_lexem = ct.type_lexem;
                ed.close_lexem = ct.close_lexem;
                ed.addChilds(ct.arguments);
            }
            else
            {
                ed.addChild(ct);
                ed = ct;
            }
            goto Argument;
        }
        else if (!is_c && lexer == "new")
        {
            if (ed.operator.empty && ed.type.empty)
            {
                ed.type_lexem = lexer.lexem;
                ed.type = ed.type_lexem.text;
            }
            else
            {
                Expression n = new Expression;
                n.type_lexem = lexer.lexem;
                n.type = n.type_lexem.text;
                ed.addChild(n);
                ed = n;
            }
            goto Argument;
        }
        else if (is_c && lexer == "sizeof")
        {
            if (ed.operator.empty && ed.type.empty)
            {
                ed.type_lexem = lexer.lexem;
                ed.type = ed.type_lexem.text;
            }
            else
            {
                Expression n = new Expression;
                n.type_lexem = lexer.lexem;
                n.type = n.type_lexem.text;
                ed.addChild(n);
                ed = n;
            }
            goto Argument;
        }
        else if (lexer == LexemType.Identifier)
        {
            Lexem name = lexer.lexem;
            getLexem;

            if (lexer == "(")
            {
                Expression funcall = new Expression;
                funcall.operator_lexem = name;
                funcall.operator = funcall.operator_lexem.text;
                funcall.type_lexem = lexer.lexem;
                funcall.type = "funcall";
                funcall.open_lexem = lexer.lexem;
                funcall.addChilds(getCallArgs);
                funcall.close_lexem = lexer.lexem;
                ed.addChild(funcall);
                getLexem;
            }
            else
            {
                Expression arg = new Expression;
                arg.operator_lexem = name;
                arg.operator = arg.operator_lexem.text;
                ed.addChild(arg);
            }
            goto Operator;
        }
        else if (lexer == LexemType.String)
        {
            Expression arg = new Expression;
            arg.operator_lexem = lexer.lexem;
            arg.operator = arg.operator_lexem.text;
            arg.bt = BlockType.String;
            ed.addChild(arg);
            getLexem;
        }
        else if (lexer == LexemType.Number
         || lexer == LexemType.Float
         || lexer == LexemType.Character
         || lexer == LexemType.LenOperator)
        {
            Expression arg = new Expression;
            arg.operator_lexem = lexer.lexem;
            arg.operator = arg.operator_lexem.text;
            if (lexer == LexemType.Character)
                arg.bt = BlockType.Character;
            ed.addChild(arg);
            getLexem;
        }
        else if (lexer == LexemType.Operator)
        {
            Lexem op = ed.operator_lexem;

            if (op.text.empty)
            {
                op.text = ed.type;
            }

            if (ed.hidden)
            {
                op.text = "P";
            }

            if (op.text.empty)
            {
                ed.operator_lexem = lexer.lexem;
                ed.operator = ed.operator_lexem.text;
                ed.type = "unary";
            }
            else if ((op.text == "!") && ((lexer == "is") || (lexer == "in")))
            {
                ed.operator ~= lexer.lexem.text;
                ed.operator_lexem.end = lexer.lexem.end;
            }
            else
            {
                Expression expr = new Expression;
                expr.operator_lexem = lexer.lexem;
                expr.operator = expr.operator_lexem.text;
                expr.type = "unary";
                ed.addChild(expr);
                ed = expr;
            }
            goto Argument;
        }
        else if (lexer == "(")
        {
            writefln("LEXEM %s", lexer.lexem);
            Lexem open_lexem = lexer.lexem;
            Expression expr = getExpression;
            writefln("EXPR %s, open %s", expr, expr.open_lexem.start);
            /*if (expr.open_lexem.start.row == 0)
            {
                expr.open_lexem = open_lexem;
            }
            else*/
            {
                Expression brexpr = new Expression;
                brexpr.type = "ord";
                brexpr.open_lexem = open_lexem;
                brexpr.arguments ~= expr;
                expr = brexpr;
            }

            ed.arguments ~= expr;

            if (lexer == ")")
            {
                expr.close_lexem = lexer.lexem;
                getLexem;
            }
            else
            {
                writefln("Expected . not %s", lexer);
                assert(0);
            }
        }
        else if (lexer == "[")
        {
            Expression br = new Expression;
            br.operator = "[]";
            br.open_lexem = lexer.lexem;

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
                br.close_lexem = lexer.lexem;
                if (ed.operator.empty && ed.type.empty)
                {
                    ed.operator_lexem = br.operator_lexem;
                    ed.operator = br.operator;
                    ed.open_lexem = br.open_lexem;
                    ed.close_lexem = br.close_lexem;
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
                writefln("] or , expected not %s", lexer);
            }
        }
        else if (lexer == "{")
        {
            Expression br = new Expression;
            br.operator = "{}";
            br.operator_lexem = lexer.lexem;
            br.open_lexem = lexer.lexem;
            br.type = "cinit";

            CInit:
            Expression expr = getExpression;

            if (expr !is null)
            {
                br.addChild(expr);
            }

            if (lexer == ",")
            {
                goto CInit;
            }
            else if (lexer == "}")
            {
                br.close_lexem = lexer.lexem;
                if (ed.operator.empty && ed.type.empty)
                {
                    ed.operator_lexem = br.operator_lexem;
                    ed.operator = br.operator;
                    ed.open_lexem = br.open_lexem;
                    ed.close_lexem = br.close_lexem;
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
                writefln("} or , expected not %s", lexer);
            }
        }
        else if (lexer == "]")
        {
            return null;
        }
        else if (lexer == ";")
        {
            return null;
        }
        else if (lexer == ")")
        {
            return null;
        }
        else
        {
            writefln("Unexpected %s", lexer);
            assert(0);
        }

        Operator:
        if (lexer == "."
         || lexer == "->"
         || lexer == "?"
         || lexer == ":"
         || lexer == "in"
         || lexer == "is"
         || lexer == LexemType.AssignOperator
         || lexer == LexemType.CmpOperator
         || lexer == LexemType.Operator
         || lexer == LexemType.Lambda)
        {
            Lexem op2 = lexer.lexem;

            if (op2.text == "!")
            {
                getLexem;

                if (lexer == "is"
                 || lexer == "in")
                {
                    op2.text ~= lexer.lexem.text;
                    op2.end = lexer.lexem.end;
                }
                else if (lexer == "(")
                {
                    Expression em = new Expression;
                    em.type_lexem = op2;
                    em.type = em.type_lexem.text;
                    em.open_lexem = lexer.lexem;
                    em.arguments ~= getCallArgs;
                    em.close_lexem = lexer.lexem;
                    ed.arguments[$-1].arguments ~= em;

                    getLexem;
                    if (lexer == "(")
                    {
                        ed.arguments[$-1].open_lexem = lexer.lexem;
                        ed.arguments[$-1].addChilds(getCallArgs);
                        ed.arguments[$-1].close_lexem = lexer.lexem;
                        getLexem;
                    }
                    goto Operator;
                }
                else
                {
                    writefln("Expected 'is', 'in' or '(' not %s", lexer);
                    assert(0);
                }
            }

            LookOp:
            Lexem op = ed.operator_lexem;

            if (op.text.empty)
            {
                if (!ed.operator.empty)
                    op.text = ed.operator;
                else
                {
                    op = ed.type_lexem;
                    if (op.text.empty)
                    {
                        if (!ed.type.empty)
                        {
                            op.text = ed.type;
                        }
                    }
                }
            }

            if (ed.hidden)
            {
                op.text = "P";
            }

            if (op.text.empty)
            {
                if (op2.text == "?"
                 || op2.text == ":"
                 || op2.text == "."
                 || op2.text == "->")
                {
                    ed.type_lexem = op2;
                    ed.type = ed.type_lexem.text;
                }
                else
                {
                    ed.operator_lexem = op2;
                    ed.operator = ed.operator_lexem.text;
                }
            }
            else if (op.text == op2.text)
            {
                Expression oexpr = new Expression;
                oexpr.operator_lexem = op2;
                oexpr.operator = op2.text;

                Expression qexpr = new Expression;
                qexpr.type = "quote";
                qexpr.addChilds([oexpr]);

                ed.addChilds([qexpr]);
            }
            else if (getPriority(op2.text) >= getPriority(op.text))
            {
                Expression expr = new Expression;

                if (op2.text == "?"
                 || op2.text == "."
                 || op2.text == "->")
                {
                    expr.type_lexem = op2;
                    expr.type = expr.type_lexem.text;
                }
                else if (op2.text == ":")
                {
                    Expression oexpr = new Expression;
                    oexpr.operator_lexem = op2;
                    oexpr.operator = op2.text;

                    Expression qexpr = new Expression;
                    qexpr.type = "quote";
                    qexpr.addChilds([oexpr]);

                    ed.addChilds([qexpr]);
                    goto Argument;
                }
                else
                {
                    expr.operator_lexem = op2;
                    expr.operator = expr.operator_lexem.text;
                }

                if (getPriority(op2.text) == getPriority(op.text))
                {
                    Expression pared = ed.parent;

                    if (pared)
                    {
                        pared.popChild;
                        pared.addChild(expr);
                    }
                    else
                    {
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

                if (op2.text == "?"
                 || op2.text == ":"
                 || op2.text == "."
                 || op2.text == "->")
                {
                    expr.type_lexem = op2;
                    expr.type = expr.type_lexem.text;
                }
                else
                {
                    expr.operator_lexem = op2;
                    expr.operator = expr.operator_lexem.text;
                }
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
            slice.type_lexem = lexer.lexem;
            slice.open_lexem = lexer.lexem;
            slice.type = "[";
            Expression s1 = getExpression;

            if (s1)
            {
                slice.addChild(s1);
            }

            if (lexer == "..")
            {
                Expression ss = new Expression;
                ss.operator_lexem = lexer.lexem;
                ss.operator = "..";
                Expression s2 = getExpression;
                slice.addChild(ss);
                slice.addChild(s2);
            }

            if (lexer == "]")
            {
                LookOp2:
                Lexem op = ed.operator_lexem;
                slice.close_lexem = lexer.lexem;

                if (op.text.empty)
                {
                    op = ed.type_lexem;
                }

                if (ed.hidden)
                {
                    op.text = "P";
                }

                if (op.text.empty)
                {
                    ed.type = ".";
                    ed.addChild(slice);
                }
                else if (op.text == ".")
                {
                    ed.addChild(slice);
                }
                else if (getPriority(".") >= getPriority(op.text))
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
                        expr.nl1 += ret.nl1;
                        ret.nl1 = 0;
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
         || lexer == "]"
         || lexer == "}"
         || lexer == ";"
         || lexer == LexemType.EndOfCMacros)
        {
            if ((ret.operator is null) && (ret.type is null))
            {
                ret.arguments[0].nl1 += ret.nl1;
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

    Expression getCaseVal()
    {
        Expression ret = new Expression;
        Expression ed = ret;
        Argument:
        getLexem;

        if (lexer == LexemType.String
         || lexer == LexemType.Number
         || lexer == LexemType.Character
         || lexer == LexemType.Identifier)
        {
            Expression arg = new Expression;
            arg.operator_lexem = lexer.lexem;
            arg.operator = arg.operator_lexem.text;
            if (lexer == LexemType.String)
                arg.bt = BlockType.String;
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
            ed.type_lexem = lexer.lexem;
            ed.type = ed.type_lexem.text;
            goto Argument;
        }
        else if (lexer == ":")
        {
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
            case "->":
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
