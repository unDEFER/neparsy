module parser;
import std.stdio;
import std.string;
import std.range;
import std.algorithm;
import styles.all;
import styles.common;
import styles.bitmaps;
import std.bitmanip;
import std.uni;
import std.json;
import std.conv;
import std.utf;
import common;

struct IndentedLine
{
    int level; // for using in Python-style
    char[] line;
}

struct TokenGroup
{
    string name;
    size_t start_token;
    size_t mincount;
    JSONValue *js;
    size_t next_token;
    size_t counter;
}

struct StateEntry
{
    size_t rule;
    size_t token;
    size_t counter; // for repeating tokens
    TokenGroup[] groups;
    char[][] tokens;
    char[] rest_of_line;
    size_t row;
    JSONValue js;
}

struct Parser
{
    char[] get_id(char[] line)
    {
        if (line.length == 0 || !isAlpha(line[0])) return null;

        for (size_t i=1; i < line.length; i++)
        {
            if (!isAlphaNum(line[i])) return line[0..i];
        }

        return line;
    }

    JSONValue get_type_or_expression(ref char[][] tokens, bool ok_type, bool ok_expr, bool ok_assign, string end_token = null)
    {
        JSONValue v;

        char[] save_lsplice = lsplice;
        char[][] save_tokens = tokens;
        size_t save_row = row;

        Style defined_style = cast(Style) style_hypothesis.bitsSet().front;
        shared StyleDefinition* styledef = styledefs[defined_style];
        char[] token_string = get_id(lsplice);

        writefln("id: %s", token_string);
        if (!token_string.empty)
        {
            v.object = null;

            Mutability mutability = styledef.default_mutability;
            int brackets = 0;

            if (styledef.immutable_keyword !is null && token_string == styledef.immutable_keyword)
            {
                mutability = Mutability.Immutable;
                consume(token_string.length);
                tokens ~= token_string;
                token_string = get_id(lsplice);
            }
            else if (styledef.mutable_keyword !is null && token_string == styledef.mutable_keyword)
            {
                mutability = Mutability.Mutable;
                consume(token_string.length);
                tokens ~= token_string;
                token_string = get_id(lsplice);
            }
            else if (styledef.const_keyword !is null && token_string == styledef.const_keyword)
            {
                mutability = Mutability.Const;
                consume(token_string.length);
                tokens ~= token_string;
                token_string = get_id(lsplice);
            }

            if (token_string.empty && lsplice.startsWith("("))
            {
                token_string = lsplice[0..1];
                brackets++;
                consume(token_string.length);
                tokens ~= token_string;
                token_string = get_id(lsplice);
            }

            JSONValue json_ptrs;
            json_ptrs.array = [];

            if (token_string.empty)
            {
                lsplice = save_lsplice;
                tokens = save_tokens;
                row = save_row;
                return v;
            }

            char[] type = token_string;

            consume(token_string.length);
            tokens ~= token_string;
            token_string = get_id(lsplice);

            writefln("ptrw: %s", lsplice);
            int ptrs = 0;
            int mutability_limit = 0;
            string ptr_sign = "*";
            while ( token_string.empty )
            {
                if (lsplice.startsWith(ptr_sign))
                {
                    JSONValue c;
                    c.str = "*";
                    json_ptrs.array ~= c;
                    ptrs++;
                }
                else if (brackets > 0 && lsplice.startsWith(")"))
                {
                    brackets--;
                    mutability_limit = ptrs+1;
                }
                else if (lsplice.startsWith("["))
                {
                    token_string = lsplice[0..1];
                    consume(token_string.length);
                    tokens ~= token_string;

                    json_ptrs.array ~= get_type_or_expression(tokens, false, true, false, "]");
                    ptrs++;

                    token_string = get_id(lsplice);
                    continue;
                }
                else if (lsplice.startsWith(end_token))
                {
                    token_string = lsplice[0..end_token.length];
                    consume(token_string.length);
                    tokens ~= token_string;
                    break;
                }
                else
                {
                    tokens = null;

                    lsplice = save_lsplice;
                    tokens = save_tokens;
                    row = save_row;
                    return v;
                }

                token_string = lsplice[0..1];
                consume(token_string.length);
                tokens ~= token_string;
                token_string = get_id(lsplice);
            }

            v.object["mutability"] = mutability;
            v.object["type"] = type;
            v.object["ptrs"] = json_ptrs;
            writefln("v=%s\n", v);
        }

        return v;
    }

    char[][] get_tokens(Token[] tokens, ref size_t t, ref TokenGroup[] groups, ref JSONValue statement_js)
    {
        if (lsplice.length == 0) return null;

        Token token;
        char[] token_string;
        char[][] ctokens;
        JSONValue *js = &statement_js;

    Repeat:
        if (t >= tokens.length) goto End;

        foreach_reverse(g; groups)
        {
            if (g.js !is null)
            {
                if (g.counter >= g.js.array.length)
                {
                    JSONValue v;
                    v.object = null;
                    g.js.array ~= v;
                }

                js = &g.js.array[g.counter];
                break;
            }
        }

        token = tokens[t];
        if (t > 0) writefln("Token %s in %s", token.type, lsplice);

        final switch(token.type)
        {
            case TokenType.Keyword:
            case TokenType.Symbol:
                //writefln("Symbol %s in %s", token.name, lsplice);
                if ( lsplice.startsWith(token.name) )
                {
                    token_string = lsplice[0..token.name.length];
                }
                break;

            case TokenType.Id:
                token_string = get_id(lsplice);
                if (!token.name.empty && !token_string.empty)
                {
                    js.object[token.name] = token_string;
                }
                //writefln("ID %s=%s in %s", token.name, token_string, lsplice);
                break;

            case TokenType.Type:
                if (style_hypothesis.count > 1)
                {
                    break;
                }

                char[][] ret_tokens;
                JSONValue v = get_type_or_expression(ret_tokens, true, false, false);
                js.object[token.name] = v;
                writefln("ret_tokens = %s, lsplice = %s", ret_tokens, lsplice);
                if (!ret_tokens.empty)
                {
                    ctokens ~= ret_tokens;
                }

                assert(t == 0, "Type parsing not implemented");
                break;

            case TokenType.CArray:
                assert(t == 0, "CArray parsing not implemented");
                break;

            case TokenType.Expression:
                assert(t == 0, "Expression parsing not implemented");
                break;

            case TokenType.Statement:
                assert(t == 0, "Statement parsing not implemented");
                break;

            case TokenType.TokenGroupBegin:
                //writefln("begin group '%s'", token.name);
                JSONValue *gjs;
                if (!token.name.empty)
                {
                    JSONValue v;
                    v.array = [];
                    js.object[token.name] = v;
                    gjs = &js.object[token.name];
                }
                groups ~= TokenGroup(token.name, ++t, token.mincount, gjs);
                goto Repeat;

            case TokenType.TokenGroupEnd:
                //writefln("end group '%s', counter %s", token.name, groups[$-1].counter);
                if (token.maxcount == 0 || groups[$-1].counter < token.maxcount)
                {
                    groups[$-1].next_token = t+1;
                    t = groups[$-1].start_token;

                    if (token.delimiter == StatementDelimiterType.None)
                        writefln("WARNING! [TokenGroupEnd] delimiter is none");
                    
                    groups[$-1].counter++;

                    string delimiter = statement_delimiters[token.delimiter];
                    if ( lsplice.startsWith(delimiter) )
                    {
                        //writefln("Delimiter '%s' is consumed", delimiter);
                        ctokens ~= lsplice[0..delimiter.length];
                        consume(delimiter.length);
                    }
                    else if (token.delimiter != StatementDelimiterType.None)
                    {
                        t = groups[$-1].next_token;
                        groups.length--;
                    }

                    goto Repeat;
                }
                else
                {
                    groups.length--;
                    t++;
                }
        }

        if (token_string.empty && groups.length > 0 && groups[$-1].counter >= groups[$-1].mincount && t == groups[$-1].start_token)
        {
            if (groups[$-1].next_token > 0)
            {
                t = groups[$-1].next_token;
            }
            else
            {
                size_t sgr = 1;
                do
                {
                    t++;
                    token = tokens[t];

                    if (token.type == TokenType.TokenGroupBegin)
                    {
                        sgr++;
                    }
                    else if (token.type == TokenType.TokenGroupEnd)
                    {
                        sgr--;
                    }
                } while (sgr > 0);
                t++;
            }

            if (groups[$-1].js !is null)
                groups[$-1].js.array.length--;
            groups.length--;

            goto Repeat;
        }
        //writefln("Return token: %s", token_string);

End:
        if (token_string.empty) return ctokens;

        consume(token_string.length);
        return ctokens ~ token_string;
    }

    bool is_eof()
    {
        return row >= lines.length;
    }

    void check_eol()
    {
        while (lsplice.empty)
        {
            row++;
            if (is_eof)
                return;
            lsplice = lines[row].line;
        }
    }

    void consume(size_t nchars)
    {
        lsplice = strip(lsplice[nchars..$]);
        check_eol();
    }

    string consume_textspan(TextSpan textspan, bool no_escape = false)
    {
        string ret;
        int nest = 0;
        bool escape;

        if ( lsplice.startsWith(textspan.begin) )
        {
            consume(textspan.begin.length);
            nest++;
            
            do
            {
                while ( escape || !lsplice.startsWith(textspan.end) )
                {
                    if (!escape && lsplice.startsWith(textspan.escape))
                    {
                        if (!no_escape) ret ~= lsplice[0..textspan.escape.length];
                        auto oldrow = row;
                        consume(textspan.escape.length);
                        auto newlines = row - oldrow;
                        if (newlines > 0 && !no_escape) ret ~= '\n'.repeat(newlines).array();
                        escape = true;
                    }
                    else if (!escape && textspan.nesting && lsplice.startsWith(textspan.begin))
                    {
                        ret ~= lsplice[0..textspan.begin.length];
                        auto oldrow = row;
                        consume(textspan.begin.length);
                        auto newlines = row - oldrow;
                        if (newlines > 0) ret ~= '\n'.repeat(newlines).array();
                        nest++;
                    }
                    else
                    {
                        auto chr_len = lsplice.stride;
                        ret ~= lsplice[0..chr_len];
                        auto oldrow = row;
                        consume(chr_len);
                        auto newlines = row - oldrow;
                        if (newlines > 0) ret ~= '\n'.repeat(newlines).array();
                        escape = false;
                    }
                }

                if (nest > 1) ret ~= lsplice[0..textspan.end.length];
                auto oldrow = row;
                consume(textspan.end.length);
                auto newlines = row - oldrow;
                if (nest > 1 && newlines > 0) ret ~= '\n'.repeat(newlines).array();
                nest--;
            } while (nest > 0);
        }

        return ret;
    }

    string consume_comment()
    {
        BitArray comments_hypothesis = get_hypothesis!("comments")(style_hypothesis);

        TextSpan comment;
        foreach(d; comments_hypothesis.bitsSet)
        {
            comment = .comments[d];
            auto consumed = consume_textspan(comment);
            if (!consumed.empty) return consumed;
        }

        return null;
    }

    StateEntry[] state;

    IndentedLine[] lines;
    BitArray style_hypothesis;
    char[] lsplice;
    size_t row;
    string consumed;

    this(IndentedLine[] _lines, BitArray _style_hypothesis, char[] _lsplice, size_t _row)
    {
        lines = _lines;
        style_hypothesis = _style_hypothesis;
        lsplice = _lsplice;
        row = _row;

        check_eol();
    }

    StateEntry statement;
    string[] comments;

    bool get_statement()
    {
        StateEntry[] new_state_candidates;
        StateEntry[] state_candidates_update;
        TokenGroup[] groups;

    retry:
        char[] save_lsplice = lsplice;
        size_t save_row = row;

        int finished;

        for(size_t r = 0; r < rules.length; r++)
        {
            if ((style_hypothesis & style_rules[r]).bitsSet.empty) continue;
            Rule rule = rules[r];
            JSONValue js;
            js.object = null;
            JSONValue v;
            v.str = rule.kind.to!(string);
            js.object["type"] = v;

            lsplice = save_lsplice;
            row = save_row;

            size_t t = 0;
            char[][] tokens = get_tokens(rule.tokens, t, groups, js);

            if (!tokens.empty)
            {
                auto se = StateEntry(r, t+1, 0, groups, tokens, lsplice, row, js);
                if (se.token >= rule.tokens.length)
                {
                    statement = se;
                    finished++;
                    continue;
                }
                new_state_candidates ~= se;
            }
        }

        //writefln("new_state_candidates: %s", new_state_candidates);

        while (!new_state_candidates.empty)
        {
            foreach(ref nsc; new_state_candidates)
            {
                Rule rule = rules[nsc.rule];

                lsplice = nsc.rest_of_line;
                row = nsc.row;
                char[][] tokens_new = get_tokens(rule.tokens, nsc.token, nsc.groups, nsc.js);

                if (!tokens_new.empty)
                {
                    nsc.token++;
                    nsc.tokens ~= tokens_new;
                    nsc.rest_of_line = lsplice;
                    nsc.row = row;
                    state_candidates_update ~= nsc;
                }

                if (nsc.token >= rule.tokens.length)
                {
                    statement = nsc;
                    finished++;
                }
            }
            
            swap(state_candidates_update, new_state_candidates);
            state_candidates_update.length = 0;
        }

        if (finished > 0)
            goto StatementEnded;

        if (is_eof)
        {
            writefln("End of File");
            return false;
        }
        
        consumed = consume_comment();
        if (!consumed.empty)
        {
            writefln("Consumed comment: %s", consumed);
            comments ~= consumed;
            goto retry;
        }

        assert(false, "Statement not parsed. Line is: " ~ lsplice);

    StatementEnded:
        
        style_hypothesis &= style_rules[statement.rule];
        writefln("parsed statement=%s, style_hypothesis=%s", statement, style_hypothesis);

        BitArray delimiter_hypothesis = get_hypothesis!("statement_delimiters")(style_hypothesis);

        string delimiter;
        foreach(d; delimiter_hypothesis.bitsSet)
        {
            lsplice = statement.rest_of_line;
            row = statement.row;

            delimiter = statement_delimiters[d];
            if ( lsplice.startsWith(delimiter) )
            {
                consume(delimiter.length);
                break;
            }
            delimiter = null;
        }

        if (!delimiter.empty)
        {
            writefln("Statement delimiter '%s' consumed successfully", delimiter);
        }

        return true;
    }
}

// return number characters to skip
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

    il.line = strip(line).dup();
    return il;
}

int convert2neparsy(string input, string output, Style style)
{
    bool[] styles = new bool[cast(size_t) Style.Unknown];

    if (style == Style.Unknown)
        styles[0..$] = true;
    else
        styles[style] = true;

    BitArray style_hypothesis = BitArray(styles);

    auto file = File(input); // Open for reading
    auto lines = file.byLine()            // Read lines
                 .map!parseIndent().array;
    file.close();

    StateEntry[] state;

    size_t row; // current line
    char[] lsplice = lines[row].line;

    auto parser = Parser(lines, style_hypothesis, lsplice, row);

    JSONValue module_js;
    module_js.array = [];

    while (parser.get_statement())
    {
        if (!parser.comments.empty)
        {
            JSONValue comments_js;
            comments_js.object = null;
            JSONValue v;
            v.str = "comment";
            comments_js.object["type"] = v;

            JSONValue comments_array_js;
            comments_array_js.array = [];

            foreach (comment; parser.comments)
            {
                JSONValue c;
                c.str = comment;
                comments_array_js.array ~= c;
            }

            comments_js.object["comments"] = comments_array_js;
            module_js.array ~= comments_js;
        }
        module_js.array ~= parser.statement.js;
    }

    if (style_hypothesis.count > 1)
    {
        writefln("WARNING! style_hypothesis.count > 1");
    }

    Style defined_style = cast(Style) style_hypothesis.bitsSet().front;
    JSONValue ast_with_style;
    ast_with_style.object = null;
    JSONValue v;
    v.str = defined_style.to!(string);
    ast_with_style.object["style"] = v;
    ast_with_style.object["ast"] = module_js;

    file = File(output, "w"); // Open for writing
    file.write(ast_with_style.toPrettyString());
    file.close();

    return 0;
}
