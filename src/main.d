/**
 * main.d
 */

module main;

import iface;

import gio.Application : GioApplication = Application;
import gio.FileT;
import gtk.Application;
import gtk.ApplicationWindow;
import gtk.Widget;
import gdk.Event;
import gdk.Keymap;
import std.stdio;
import std.array;
import std.string;
import std.conv;
import std.typecons : Flag, Yes, No;
import std.algorithm.searching;
import std.math.traits;
import std.math;
import std.algorithm;
import std.uni;
import std.file;
import expression;
import lexer;
import parser;

class MyWindow : ApplicationWindow
{
    public this (GtkApplicationWindow* gtkApplicationWindow, bool ownedRef = false)
    {
        super(gtkApplicationWindow, ownedRef);
    }

    public this (Application application)
    {
        super(application);
        addEvents(EventMask.KEY_PRESS_MASK | EventMask.BUTTON_PRESS_MASK);
		addOnKeyPress(&keyPressCallback);
		addOnButtonPress(&buttonPressCallback);
		addOnScroll(&scrollCallback);
    }

    protected:
    bool keyPressCallback(Event event, Widget widget)
    {
        uint val;
        event.getKeyval(val);
        dchar unicode = cast(dchar) Keymap.keyvalToUnicode(val);

        GdkModifierType state;
        event.getState(state);

        if (state & GdkModifierType.SHIFT_MASK && val == 65361) /*LEFT*/
        {
            //write("S<");
            IFACE.moveleft();
        }
        else if (state & GdkModifierType.SHIFT_MASK && val == 65363) /*RIGHT*/
        {
            //write("S>");
            IFACE.moveright();
        }
        else if (val == 65535)
        {
            //write("Del");
            IFACE.del();
        }
        else if (val == 65307 /*Escape*/ || val == 65293 /*Enter*/)
        {
            //write('\n');
            IFACE.escape();
        }
        else if (unicode == ' ')
        {
            //write(unicode);
            IFACE.space();
        }
        else if (state & GdkModifierType.CONTROL_MASK)
        {
            if (unicode == ',')
            {
                //write("^<");
                IFACE.less();
            }
            else if (unicode == '.')
            {
                //write("^>");
                IFACE.greater();
            }
            else if (unicode == 's')
            {
                IFACE.save();
            }
            else if (unicode == 'd')
            {
                IFACE.saveD();
            }
            else if (unicode == 'c')
            {
                //write('C', unicode);
                IFACE.copy();
            }
            else if (unicode == 'x')
            {
                //write('C', unicode);
                IFACE.copy();
                IFACE.del();
            }
            else if (unicode == 'v')
            {
                //write('C', unicode);
                IFACE.insert();
            }
            else if (unicode == 'l')
            {
                //write('C', unicode);
                IFACE.toLexer();
            }
            else if (unicode == '=')
            {
                IFACE.sx2 /= 1.5;
                IFACE.sy2 /= 1.5;
                IFACE.redraw();
            }
            else if (unicode == '-')
            {
                IFACE.sx2 *= 1.5;
                IFACE.sy2 *= 1.5;
                IFACE.redraw();
            }
            else if (val == 65288)
            {
                //write("C<-");
                IFACE.remove();
            }
            else if (val == 65361) /*LEFT*/
            {
                //write("C<");
                IFACE.field_left();
            }
            else if (val == 65363) /*RIGHT*/
            {
                //write("C>");
                IFACE.field_right();
            }
            else if (val == 65364) /*DOWN*/
            {
                //write("Cv");
                IFACE.field_down();
            }
            else if (val == 65362) /*UP*/
            {
                //write("C^");
                IFACE.field_up();
            }
        }
        else if (val == 65288)
        {
            //write("<-");
            IFACE.backspace();
        }
        else if (val == 65361) /*LEFT*/
        {
            //write("<");
            IFACE.left();
        }
        else if (val == 65363) /*RIGHT*/
        {
            //write(">");
            IFACE.right();
        }
        else if (val == 65364) /*DOWN*/
        {
            //write("v");
            IFACE.down();
        }
        else if (val == 65362) /*UP*/
        {
            //write("^");
            IFACE.up();
        }
        else if (unicode == '.')
        {
            //write(unicode);
            IFACE.dot();
        }
        else if (unicode == ',')
        {
            //write(unicode);
            IFACE.comma();
        }
        else if ( isAlphaNum(unicode) || isPunctuation(unicode) )
        {
            //write(unicode);
            IFACE.print(unicode);
        }

        IFACE.redraw();

        return false;
    }

    bool buttonPressCallback(Event event, Widget widget)
    {
        uint button;
        event.getButton(button);
        double x, y;
        event.getCoords(x, y);

        //writefln("%s. %sx%s", button, x, y);
        return IFACE.click(button, x, y);
    }

    bool scrollCallback(Event event, Widget widget)
    {
        double deltaX, deltaY;
        event.getScrollDeltas(deltaX, deltaY);
        return IFACE.scroll(deltaX, deltaY);
    }
}

Iface IFACE;

struct BranchInfo
{
    int maxdeep;
    real maxx;
    real maxy;
    Expression fig;
}

int main(string[] args)
{
    if (args.length > 1)
    {
        if (args[1] == "-h" || args[1] == "--help")
        {
            writefln("usage: %s [file1] [file2]... -- for editing files in GUI\n"
                    ~"   or: %s -c <source> <destination> -- for converting between neparsy/D formats\n"
                    ~"where files must have '.np' or '.d' extension", args[0], args[0]);
            return 0;
        }
        else if (args[1] == "-c" && args.length == 4)
        {
            Expression expr;
            if (args[2].endsWith(".d"))
            {
                Lexer lex;
                lex.file = readText(args[2]);
                Parser pars = new Parser;
                pars.lexer = lex;
                expr = pars.parse();
                expr.fixParents();
                expr.label = "D";
            }
            else if (args[2].endsWith(".np"))
            {
                string mod = readText(args[2]);
                expr = new Expression(mod);
            }
            else
            {
                writefln("Can't convert file with unknown extension: `%s`", args[2]);
                return 1;
            }

            string savestr;

            if (args[3].endsWith(".d"))
            {
                savestr = expr.saveD;
            }
            else if (args[3].endsWith(".np"))
            {
                savestr = expr.save;
            }
            else
            {
                writefln("Can't convert to file with unknown extension: `%s`", args[3]);
                return 1;
            }

            auto file = File(args[3], "w");
            file.writeln(savestr);
            return 0;
        }
    }

	Application application;

	void activateClock(GioApplication app)
	{
		MyWindow win = new MyWindow(application);

		win.setTitle("Neparsy");
		win.setDefaultSize( 640, 480 );

        real x = 0.0;
        real y = 0.0;

        int state = 0;
        BranchInfo[] branches;

        Expression root = new Expression();
        root.type = "root";

        foreach (i, arg; args[1..$])
        {
            if (arg.endsWith(".d"))
            {
                Lexer lex;
                lex.file = readText(arg);
                Parser pars = new Parser;
                pars.lexer = lex;
                Expression expr = pars.parse();
                expr.fixParents();

                expr.parent = root;
                expr.operator = expr.operator~".np";
                expr.type = "*";
                expr.index = root.arguments.length;
                root.arguments ~= expr;
            }
            else if (arg.endsWith(".np"))
            {
                string mod = readText(arg);
                Expression expr = new Expression(mod);
                expr.parent = root;
                expr.operator = arg;
                expr.index = i;
                root.arguments ~= expr;
            }
            else
            {
                writefln("Skip file with unknown extension: `%s`", arg);
            }
        }

		IFACE = new Iface(root);
		win.add(IFACE);
		IFACE.show();
		win.showAll();
	}

	void handleOpen(FileIF[] files, string name, GioApplication app)
	{
	    activateClock(app);
    }

	application = new Application("org.gtkd.demo.cairo.iface", GApplicationFlags.HANDLES_OPEN);
	application.addOnOpen(&handleOpen);
	application.addOnActivate(&activateClock);
	return application.run(args);
}

