module lexer;
import std.stdio;
import std.range;
import std.utf;
import std.uni;
import std.file;
import std.conv;
import std.algorithm.searching;
enum LexemType {
    Identifier,
    AssignOperator,
    Comment,
    String,
    EndInput,
    Punctuation,
    Number,
    Float,
    CmpOperator,
    Blank,
    Operator,
    Character,
    LenOperator,
    Lambda,
    CPreprocessor,
    EndOfCMacros
}

enum  {
    EOF = '\u0004'
}

struct Position
{
    uint row;
    uint col;

    int opCmp(Position b)
    {
        return b.row == row ? col - b.col : row - b.row;
    }
}

struct Lexem
{
    string text;
    LexemType type;
    Position start;
    Position end;
    Lexem[] comments;
}

struct Lexer {
    string file;
    Lexem lexem;
    Position cursor = Position(1, 1);
    dchar chr;
    bool is_cpreprocessor_line;

    bool isWhiteNL(dchar chr)
    {
        return isWhite(chr);
    }

    void getLexemRaw()
    {
        lexem.text = file;
        Lexer  back;
        Lexer  back2;
        back = this;
        lexem.start = cursor;
        nextChr();

        if (isAlpha(chr) || (chr == '_'))
        {
            if (chr == 'L')
            {
                back = this;
                nextChr;
                if (chr == '\'')
                {
                    goto Character;
                }
                else goto Identifier;
            }

            do
            {
                back = this;
                nextChr;
                Identifier:
            } while (isAlphaNum(chr) || (chr == '_'));

            this = back;
            lexem.type = LexemType.Identifier;
            lexem.end = cursor;
            return;
        }
        else if (isNumber(chr))
        {
            if (chr == '0')
            {
                back = this;
                nextChr;
                if (chr == 'x')
                {
                    do
                    {
                        if (chr != 'x') back = this;
                        nextChr;
                    } while (isNumber(chr) || (chr >= 'a' && chr <= 'f') || (chr >= 'A' && chr <= 'F'));

                    this = back;
                    lexem.type = LexemType.Number;
                    lexem.end = cursor;
                    return;
                }
                else goto Number;
            }

            do
            {
                back = this;
                nextChr;
                Number:
            } while (isNumber(chr));
            this = back;
            back2 = this;
            back = this;
            nextChr();

            if (chr == '.')
            {
                back = this;
                nextChr();

                if (chr == '.')
                {
                    this = back2;
                    lexem.type = LexemType.Number;
                    lexem.end = cursor;
                    return;
                }
                else
                {
                    this = back;
                    do
                    {
                        back = this;
                        nextChr;
                    } while (isNumber(chr));
                    this = back;
                    lexem.type = LexemType.Float;
                    lexem.end = cursor;
                    return;
                }
            }
            else
            {
                this = back;
                lexem.type = LexemType.Number;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '.')
        {
            back = this;
            nextChr();

            if (chr == '.')
            {
                lexem.type = LexemType.Punctuation;
                lexem.end = cursor;
                return;
            }
            else if (isNumber(chr))
            {
                do
                {
                    back = this;
                    nextChr;
                } while (isNumber(chr));

                this = back;
                lexem.type = LexemType.Float;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Punctuation;
                lexem.end = cursor;
                return;
            }
        }
        else if (! ",;:[]{}()?".find(chr).empty)
        {
            lexem.type = LexemType.Punctuation;
            lexem.end = cursor;
            return;
        }
        else if (chr == '+')
        {
            back = this;
            nextChr();

            if (chr == '+')
            {
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '-')
        {
            back = this;
            nextChr();

            if (chr == '-')
            {
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '=')
        {
            back = this;
            nextChr();

            if (chr == '>')
            {
                lexem.type = LexemType.Lambda;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.CmpOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '*')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '/')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '/')
            {
                do
                {
                    nextChr;
                } while (! (chr == '\n'));

                lexem.type = LexemType.Comment;
                lexem.end = cursor;
                return;
            }
            else if (chr == '*')
            {
                Comment:
                back = this;
                nextChr();

                if (chr == '*')
                {
                    back = this;
                    nextChr();

                    if (chr == '/')
                    {
                        lexem.type = LexemType.Comment;
                        lexem.end = cursor;
                        return;
                    }
                    else if (! chr.isNonCharacter)
                    {
                        goto Comment;
                    }
                    else
                    {
                        this = back;
                    }
                }
                else if (! chr.isNonCharacter)
                {
                    goto Comment;
                }
                else
                {
                    this = back;
                }
            }
            else if (chr == '+')
            {
                lexem.type = LexemType.Comment;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (is_cpreprocessor_line && chr == '\\')
        {
            nextChr();
            if (chr == '\n')
            {
                lexem.type = LexemType.Blank;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '~')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '>')
        {
            back2 = this;
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.CmpOperator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '>')
            {
                back = this;
                nextChr();

                if (chr == '>')
                {
                    back = this;
                    nextChr();

                    if (chr == '=')
                    {
                        lexem.type = LexemType.CmpOperator;
                        lexem.end = cursor;
                        return;
                    }
                    else
                    {
                        this = back;
                        lexem.type = LexemType.Operator;
                        lexem.end = cursor;
                        return;
                    }
                }
                else if (chr == '=')
                {
                    lexem.type = LexemType.CmpOperator;
                    lexem.end = cursor;
                    return;
                }
                else
                {
                    this = back;
                    lexem.type = LexemType.Operator;
                    lexem.end = cursor;
                    return;
                }
            }
            else
            {
                this = back2;
                lexem.type = LexemType.CmpOperator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '<')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.CmpOperator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '<')
            {
                back = this;
                nextChr();

                if (chr == '=')
                {
                    lexem.type = LexemType.Operator;
                    lexem.end = cursor;
                    return;
                }
                else
                {
                    this = back;
                    lexem.type = LexemType.Operator;
                    lexem.end = cursor;
                    return;
                }
            }
            else
            {
                this = back;
                lexem.type = LexemType.CmpOperator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '&')
        {
            back = this;
            nextChr();

            if (chr == '&')
            {
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '|')
        {
            back = this;
            nextChr();

            if (chr == '|')
            {
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '^')
        {
            back = this;
            nextChr();

            if (chr == '^')
            {
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
            else if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '%')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '!')
        {
            back = this;
            nextChr();

            if (chr == '=')
            {
                lexem.type = LexemType.AssignOperator;
                lexem.end = cursor;
                return;
            }
            else
            {
                this = back;
                lexem.type = LexemType.Operator;
                lexem.end = cursor;
                return;
            }
        }
        else if (chr == '$')
        {
            lexem.type = LexemType.LenOperator;
            lexem.end = cursor;
            return;
        }
        else if (chr == '"')
        {
            String:
            back = this;
            nextChr();

            if (chr == '\\')
            {
                back = this;
                nextChr();

                if (! chr.isNonCharacter)
                {
                    goto String;
                }
                else
                {
                    this = back;
                }
            }
            else if (chr == '"')
            {
                lexem.type = LexemType.String;
                lexem.end = cursor;
                return;
            }
            else if (! chr.isNonCharacter)
            {
                goto String;
            }
            else
            {
                this = back;
            }
        }
        else if (chr == '\'')
        {
            Character:
            back = this;
            nextChr();

            if (chr == '\\')
            {
                back = this;
                nextChr();

                if (! chr.isNonCharacter)
                {
                    goto Character;
                }
                else
                {
                    this = back;
                }
            }
            else if (chr == '\'')
            {
                lexem.type = LexemType.Character;
                lexem.end = cursor;
                return;
            }
            else if (! chr.isNonCharacter)
            {
                goto Character;
            }
            else
            {
                this = back;
            }
        }
        else if (chr == '#')
        {
            do
            {
                back = this;
                nextChr;
            } while (isAlpha(chr));

            this = back;
            lexem.type = LexemType.CPreprocessor;
            lexem.end = cursor;
            is_cpreprocessor_line = true;
            return;
        }
        else if (is_cpreprocessor_line && chr == '\n')
        {
            is_cpreprocessor_line = false;
            lexem.type = LexemType.EndOfCMacros;
            lexem.end = cursor;
            return;
        }
        else if (isWhiteNL(chr))
        {
            do
            {
                back = this;
                nextChr;
            } while (isWhiteNL(chr));

            this = back;
            lexem.type = LexemType.Blank;
            lexem.end = cursor;
            return;
        }
        else if (chr == EOF)
        {
            lexem.type = LexemType.EndInput;
            lexem.end = cursor;
            return;
        }
        writefln("%s %s", lexem, chr);
        assert(0);
    }

    void getLexem()
    {
        lexem.comments = null;
        Lexem[] comments;

        do
        {
            getLexemRaw();
            if (lexem.type == LexemType.Comment)
            {
                comments ~= lexem;
            }
        } while (lexem.type == LexemType.Blank || lexem.type == LexemType.Comment);

        lexem.comments = comments;
    }

    void nextChr()
    {
        if (file.empty)
        {
            chr = EOF;
        }
        else
        {
            chr = decodeFront(file);
        }

        if (chr == '\n')
        {
            ++cursor.row;
            cursor.col = 1;
        }
        else
        {
            ++cursor.col;
        }

        lexem.text = lexem.text.ptr[0..(file.ptr - lexem.text.ptr)];
    }

    bool opEquals(string o)
    {
        return lexem.text == o;
    }

    bool opEquals(LexemType o)
    {
        return lexem.type == o;
    }

    string toString()
    {
        return lexem.type.text ~ "." ~ lexem.text ~ ":" ~ lexem.start.row.text ~ ":" ~ lexem.start.col.text;
    }

    void CommentPlus()
    {
        Lexer  back;
        Lexer  back2;
        Comment:
        back = this;
        nextChr();

        if (chr == '/')
        {
            back = this;
            nextChr();

            if (chr == '+')
            {
            }
            else
            {
                this = back;
                goto Comment;
            }
        }
        else if (chr == '+')
        {
            back = this;
            nextChr();

            if (chr == '/')
            {
            }
            else
            {
                this = back;
                goto Comment;
            }
        }
    }
}
