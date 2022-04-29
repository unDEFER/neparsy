module lexer;
import std.stdio;
import std.range;
import std.utf;
import std.uni;
import std.file;
import std.conv;
import std.algorithm.searching;
enum LexemType
{
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
    LenOperator
}
enum 
{
    EOF
}
struct Lexer
{
    string file;
    string lexem;
    LexemType type;
    int line = 1;
    int col;
    dchar chr;
    void getLexem()
    {
        lexem = file;
        Lexer back;
        Lexer back2;
        back = this;
        nextChr;
        if (chr.isAlpha || (chr == '_'))
        {
            do
            {
                back = this;
                nextChr;
            }
            while (chr.isAlphaNum || (chr == '_'));
            this = back;
            type = LexemType.Identifier;
            return;
        }
        else if (chr.isNumber)
        {
            do
            {
                back = this;
                nextChr;
            }
            while (chr.isNumber);
            this = back;
            back2 = this;
            back = this;
            nextChr;
            if (chr == '.')
            {
                back = this;
                nextChr;
                if (chr == '.')
                {
                    this = back2;
                    type = LexemType.Number;
                    return;
                }
                else if (true)
                {
                    this = back;
                    do
                    {
                        back = this;
                        nextChr;
                    }
                    while (chr.isNumber);
                    this = back;
                    type = LexemType.Float;
                    return;
                }
            }
            else if (true)
            {
                this = back;
                type = LexemType.Number;
                return;
            }
        }
        else if (chr == '.')
        {
            back = this;
            nextChr;
            if (chr == '.')
            {
                type = LexemType.Punctuation;
                return;
            }
            else if (chr.isNumber)
            {
                do
                {
                    back = this;
                    nextChr;
                }
                while (chr.isNumber);
                this = back;
                type = LexemType.Float;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Punctuation;
                return;
            }
        }
        else if (! ",;:[]{}()?".find(chr).empty)
        {
            type = LexemType.Punctuation;
            return;
        }
        else if (chr == '+')
        {
            back = this;
            nextChr;
            if (chr == '+')
            {
                type = LexemType.Operator;
                return;
            }
            else if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '-')
        {
            back = this;
            nextChr;
            if (chr == '-')
            {
                type = LexemType.Operator;
                return;
            }
            else if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '=')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.CmpOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.AssignOperator;
                return;
            }
        }
        else if (chr == '*')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '/')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (chr == '/')
            {
                do
                {
                    back = this;
                    nextChr;
                }
                while (! (chr == '\n'));
                this = back;
                type = LexemType.Comment;
                return;
            }
            else if (chr == '*')
            {
                Comment:
                back = this;
                nextChr;
                if (chr == '*')
                {
                    back = this;
                    nextChr;
                    if (chr == '/')
                    {
                        type = LexemType.Comment;
                        return;
                    }
                    else if (! chr.isNonCharacter)
                    {
                        goto Comment;
                    }
                    else if (true)
                    {
                        this = back;
                    }
                }
                else if (! chr.isNonCharacter)
                {
                    goto Comment;
                }
                else if (true)
                {
                    this = back;
                }
            }
            else if (chr == '+')
            {
                type = LexemType.Comment;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '~')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '>')
        {
            back2 = this;
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.CmpOperator;
                return;
            }
            else if (chr == '>')
            {
                back = this;
                nextChr;
                if (chr == '>')
                {
                    back = this;
                    nextChr;
                    if (chr == '=')
                    {
                        type = LexemType.CmpOperator;
                        return;
                    }
                    else if (true)
                    {
                        this = back;
                        type = LexemType.Operator;
                        return;
                    }
                }
                else if (chr == '=')
                {
                    type = LexemType.CmpOperator;
                    return;
                }
                else if (true)
                {
                    this = back;
                    type = LexemType.Operator;
                    return;
                }
            }
            else if (true)
            {
                this = back;
                this = back2;
                type = LexemType.CmpOperator;
                return;
            }
        }
        else if (chr == '<')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.CmpOperator;
                return;
            }
            else if (chr == '<')
            {
                back = this;
                nextChr;
                if (chr == '=')
                {
                    type = LexemType.Operator;
                    return;
                }
                else if (true)
                {
                    this = back;
                    type = LexemType.Operator;
                    return;
                }
            }
            else if (true)
            {
                this = back;
                type = LexemType.CmpOperator;
                return;
            }
        }
        else if (chr == '&')
        {
            back = this;
            nextChr;
            if (chr == '&')
            {
                type = LexemType.Operator;
                return;
            }
            else if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '|')
        {
            back = this;
            nextChr;
            if (chr == '|')
            {
                type = LexemType.Operator;
                return;
            }
            else if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '^')
        {
            back = this;
            nextChr;
            if (chr == '^')
            {
                type = LexemType.Operator;
                return;
            }
            else if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '%')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '!')
        {
            back = this;
            nextChr;
            if (chr == '=')
            {
                type = LexemType.AssignOperator;
                return;
            }
            else if (true)
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '$')
        {
            type = LexemType.LenOperator;
            return;
        }
        else if (chr == '"')
        {
            String:
            back = this;
            nextChr;
            if (chr == '\\')
            {
                back = this;
                nextChr;
                if (! chr.isNonCharacter)
                {
                    goto String;
                }
                else if (true)
                {
                    this = back;
                }
            }
            else if (chr == '"')
            {
                type = LexemType.String;
                return;
            }
            else if (! chr.isNonCharacter)
            {
                goto String;
            }
            else if (true)
            {
                this = back;
            }
        }
        else if (chr == '\'')
        {
            Character:
            back = this;
            nextChr;
            if (chr == '\\')
            {
                back = this;
                nextChr;
                if (! chr.isNonCharacter)
                {
                    goto Character;
                }
                else if (true)
                {
                    this = back;
                }
            }
            else if (chr == '\'')
            {
                type = LexemType.Character;
                return;
            }
            else if (! chr.isNonCharacter)
            {
                goto Character;
            }
            else if (true)
            {
                this = back;
            }
        }
        else if (chr.isWhite)
        {
            do
            {
                back = this;
                nextChr;
            }
            while (chr.isWhite);
            this = back;
            type = LexemType.Blank;
            return;
        }
        else if (chr == EOF)
        {
            type = LexemType.EndInput;
            return;
        }
        writefln("%s %s", lexem, chr);
        assert(0);
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
            ++(line);
            col = 0;
        }
        else
        {
            ++(col);
        }
        lexem = lexem.ptr[0..(file.ptr - lexem.ptr)];
    }
    bool opEquals(string o)
    {
        return lexem == o;
    }
    bool opEquals(LexemType o)
    {
        return type == o;
    }
    string toString()
    {
        return type.text ~ " " ~ lexem ~ ":" ~ line.text ~ ":" ~ col.text;
    }
    void CommentPlus()
    {
        Lexer back;
        Lexer back2;
        Comment:
        back = this;
        nextChr;
        if (chr == '/')
        {
            back = this;
            nextChr;
            if (chr == '+')
            {
            }
            else if (true)
            {
                this = back;
                goto Comment;
            }
        }
        else if (chr == '+')
        {
            back = this;
            nextChr;
            if (chr == '/')
            {
            }
            else if (true)
            {
                this = back;
                goto Comment;
            }
        }
    }
}
