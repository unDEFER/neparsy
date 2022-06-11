module lexer;
import std.stdio;
import std.range;
import std.utf;
import std.uni;
import std.ascii: isHexDigit;
import std.file;
import std.conv;
import std.algorithm.searching;

enum LexemType {
    At, 
    Keyword, 
    Identifier, 
    AssignOperator, 
    Comment, 
    String, 
    EndInput, 
    Visibility, 
    Number, 
    Punctuation, 
    Return, 
    Attribute, 
    CmpOperator, 
    Float, 
    Operator, 
    Character, 
    Blank, 
    LenOperator
}

enum  {
    EOF = '\u0004'
}

struct Lexer {
    string file;
    string lexem;
    LexemType type;
    int line = 1;
    int col;
    dchar chr;
    string text;
    bool fnl = true;

    bool isWhiteNL(dchar chr)
    {
        return isWhite(chr);

    }
    string getText()
    {
        string res = text[0..(file.ptr - text.ptr)];
        text = file;
        return res;

    }
    void getLexem()
    {
        lexem = file;

        if (text is null)
        {
            text = file;
        }

        Lexer back;
        Lexer back2;

        back = this;
        nextChr();

        if (isAlpha(chr) || (chr == '_')){

            do{

                back = this;
                nextChr;
            }

            while (isAlphaNum(chr) || (chr == '_'));

            this = back;
            switch (lexem) {
                case "static":
                case "extern":
                case "align":
                case "deprecated":
                case "abstract":
                case "final":
                case "override":
                case "synchronized":
                case "scope":
                case "const":
                case "immutable":
                case "inout":
                case "shared":
                case "__gshared":
                case "nothrow":
                case "pure":
                case "ref":
                    type = LexemType.Attribute;
                    return;

                case "private":
                case "package":
                case "protected":
                case "public":
                case "export":
                    type = LexemType.Visibility;
                    return;

                case "return":
                    type = LexemType.Return;
                    return;

                case "version":
                case "debug":
                case "unittest":
                case "module":
                case "import":
                case "struct":
                case "class":
                case "union":
                case "enum":
                case "foreach":
                case "for":
                case "foreach_reverse":
                case "do":
                case "while":
                    type = LexemType.Keyword;
                    return;

                default:
                    break;
            }

            type = LexemType.Identifier;
            return;
        }

        else if (chr == '0'){

            back2 = this;
            back = this;
            nextChr();

            if (chr == 'x'){

                do{

                    back = this;
                    nextChr;
                }
                while (isHexDigit(chr));

                this = back;
                type = LexemType.Number;
                return;
            }

            else if (chr == '.'){

                back = this;
                nextChr();

                if (chr == '.'){

                    this = back2;
                    type = LexemType.Number;
                    return;
                }
                else {

                    this = back;
                    do{

                        back = this;
                        nextChr;
                    }

                    while (isNumber(chr));

                    this = back;
                    type = LexemType.Float;
                    return;
                }
            }

            else {

                this = back;
                type = LexemType.Number;
                return;
            }
        }
        else if (isNumber(chr)){

            do{

                back = this;
                nextChr;
            }
            while (isNumber(chr));

            this = back;
            back2 = this;
            back = this;
            nextChr();

            if (chr == '.'){
                back = this;
                nextChr();

                if (chr == '.'){
                    this = back2;
                    type = LexemType.Number;
                    return;
                }
                else
                {
                    this = back;
                    do{

                        back = this;
                        nextChr;
                    }

                    while (isNumber(chr));

                    this = back;
                    type = LexemType.Float;
                    return;
                }
            }
            else
            {
                this = back;
                type = LexemType.Number;
                return;
            }
        }

        else if (chr == '.')
        {
            back = this;
            nextChr();

            if (chr == '.'){

                type = LexemType.Punctuation;
                return;
            }

            else if (isNumber(chr)){

                do{

                    back = this;
                    nextChr;
                }

                while (isNumber(chr));

                this = back;
                type = LexemType.Float;
                return;
            }

            else if (true){

                this = back;
                type = LexemType.Punctuation;
                return;
            }
        }
        else if (!",;:[]{}()?".find(chr).empty){
            type = LexemType.Punctuation;
            return;
        }

        else if (chr == '+'){
            back = this;
            nextChr();

            if (chr == '+'){

                type = LexemType.Operator;
                return;
            }

            else if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }

            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }
        else if (chr == '-')
        {
            back = this;
            nextChr();

            if (chr == '-'){

                type = LexemType.Operator;
                return;
            }
            else if (chr == '='){
                type = LexemType.AssignOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '='){
            back = this;
            nextChr();

            if (chr == '='){

                type = LexemType.CmpOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.AssignOperator;
                return;
            }
        }

        else if (chr == '*'){

            back = this;
            nextChr();

            if (chr == '='){
                type = LexemType.AssignOperator;
                return;
            }

            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '/')
        {
            back = this;
            nextChr();

            if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }

            else if (chr == '/')
            {
                do{

                    back = this;
                    nextChr;
                }

                while (!(chr == '\n'));

                this = back;                nextChr;

                type = LexemType.Comment;
                return;
            }

            else if (chr == '*')
            {
Comment: 
                back = this;
                nextChr();

                if (chr == '*'){

                    back = this;
                    nextChr();

                    if (chr == '/'){

                        type = LexemType.Comment;
                        return;
                    }

                    else if (!chr.isNonCharacter){

                        goto Comment;
                    }

                    else if (true){

                        this = back;
                    }
                }

                else if (!chr.isNonCharacter){

                    goto Comment;
                }

                else if (true){

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
            nextChr();

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
            nextChr();

            if (chr == '=')
            {
                type = LexemType.CmpOperator;
                return;
            }

            else if (chr == '>')
            {
                back = this;
                nextChr();

                if (chr == '>'){

                    back = this;
                    nextChr();

                    if (chr == '='){

                        type = LexemType.AssignOperator;
                        return;
                    }
                    else
                    {
                        this = back;
                        type = LexemType.Operator;
                        return;
                    }
                }
                else if (chr == '=')
                {
                    type = LexemType.AssignOperator;
                    return;
                }
                else
                {
                    this = back;
                    type = LexemType.Operator;
                    return;
                }
            }
            else
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
            nextChr();

            if (chr == '=')
            {
                type = LexemType.CmpOperator;
                return;
            }

            else if (chr == '<'){

                back = this;
                nextChr();

                if (chr == '='){

                    type = LexemType.AssignOperator;
                    return;
                }

                else
                {
                    this = back;
                    type = LexemType.Operator;
                    return;
                }
            }

            else
            {
                this = back;
                type = LexemType.CmpOperator;
                return;
            }
        }

        else if (chr == '&'){

            back = this;
            nextChr();

            if (chr == '&'){

                type = LexemType.Operator;
                return;
            }

            else if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '|'){

            back = this;
            nextChr();

            if (chr == '|'){

                type = LexemType.Operator;
                return;
            }

            else if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }

            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '^'){

            back = this;
            nextChr();

            if (chr == '^'){

                type = LexemType.Operator;
                return;
            }
            else if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '%'){

            back = this;
            nextChr();

            if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '!'){

            back = this;
            nextChr();

            if (chr == '='){

                type = LexemType.AssignOperator;
                return;
            }
            else
            {
                this = back;
                type = LexemType.Operator;
                return;
            }
        }

        else if (chr == '$'){

            type = LexemType.LenOperator;
            return;
        }

        else if (chr == '@'){

            type = LexemType.At;
            return;
        }

        else if (chr == '"'){

String: 
            back = this;
            nextChr();

            if (chr == '\\'){

                back = this;
                nextChr();

                if (!chr.isNonCharacter){
                    goto String;
                }
                else
                {
                    this = back;
                }
            }

            else if (chr == '"'){

                type = LexemType.String;
                return;
            }

            else if (!chr.isNonCharacter){

                goto String;
            }

            else
            {
                this = back;
            }
        }

        else if (chr == '`'){

Str:
            back = this;
            nextChr();

            if (chr == '`'){

                type = LexemType.String;
                return;
            }

            else if (!chr.isNonCharacter){

                goto Str;
            }

            else{

                this = back;
            }
        }

        else if (chr == '\''){

Character:
            back = this;
            nextChr();

            if (chr == '\\'){

                back = this;
                nextChr();

                if (!chr.isNonCharacter){

                    goto Character;
                }
                else
                {
                    this = back;
                }
            }

            else if (chr == '\''){

                type = LexemType.Character;
                return;
            }

            else if (!chr.isNonCharacter){

                goto Character;
            }

            else if (true){

                this = back;
            }
        }

        else if (isWhiteNL(chr)){

            do{

                back = this;
                nextChr;
            }

            while (isWhiteNL(chr));

            this = back;
            type = LexemType.Blank;
            return;
        }

        else if (chr == EOF){

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
        }else 
        {
            chr = decodeFront(file);
        }

        if (chr == '\n')
        {
            ++line;
            col = 0;
        }
        else 
        {
            ++col;
        }

        lexem = lexem.ptr[0..(file.ptr - lexem.ptr)];
    }

    void skipNL()
    {
        string savefile = file;
        auto saveline = line;
        while (true) 
        {
            if ((file.startsWith(" ")))
            {
                decodeFront(file);
            }
            else if ((file.startsWith("\n")))
            {
                decodeFront(file);
                col = 0;
                ++line;
                return;
            }
            else 
            {
                file = savefile;
                line = saveline;
                return;
            }

        }
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
        return type.text ~ "." ~ lexem.idup ~ ":" ~ line.text ~ ":" ~ col.text;
    }


    void CommentPlus()
    {
        Lexer back;
        Lexer back2;
Comment:
        back = this;
        nextChr();

        if (chr == '/'){

            back = this;
            nextChr();

            if (chr == '+'){
            }
            else{
                this = back;
                goto Comment;
            }
        }

        else if (chr == '+'){

            back = this;
            nextChr();

            if (chr == '/'){
            }
            else
            {
                this = back;
                goto Comment;
            }
        }
    }
}

