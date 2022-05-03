Neparsy is language for representation result of parsing of any language.
Also it has original graphical representation and GUI for editing .np-files.

# Compiling
To compile from D-sources you can use `dub`:

    $ dub build

# Neparsy branch
Use `git checkout neparsy` to switch to neparsy version of repository

# Control
Arrows -- navigation

Comma -- add child

Space -- add sibling

Dot -- move down current node to child

Ctrl+Comma -- add postfix child/extend influence to the left from parent

Ctrl+Dot -- add postfix child/decrease influence to the right from parent

Shift+Left, Shift+Right -- move current node to the left/right

Ctrl + Arrows -- navigate by fields (when diagram visible on bottom of the left panel)

Del -- remove node and all descendants

Ctrl+Backspace -- remove descendants

Ctrl+S -- save to neparsy-format

Ctrl+D -- save to .d-file (@D modules)

Ctrl+L -- make lexer module from syntax (@Lexer modules)

Enter/Escape -- exit from edit mode
