/**
 * iface.d
 */

module iface;

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
import std.conv;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;
import pango.PgFontDescription;
import pango.PgLayout;
import pango.PgCairo;
import pango.PgCairoFontMap;

import gtk.Widget;
import gtk.DrawingArea;
import gdk.Event;
import gdk.Window;
import gdk.Cairo;

import expression;

struct Color
{
    real r, g, b, a;
    Color invert()
    {
        auto ret = Color(1.0 + 0.402*r - 1.174*g - 0.228*b,
                1.0 - 0.598*r - 0.174*g - 0.228*b,
                1.0 - 0.598*r - 1.174*g + 0.772*b,
                a);
        auto mi = min(ret.r, ret.g, ret.b);
        auto ma = max(ret.r, ret.g, ret.b);
        
        if (mi < 0)
        {
            ret.r -= mi;
            ret.g -= mi;
            ret.b -= mi;
        }
        
        if (ma > 1.0)
        {
            ret.r /= ma;
            ret.g /= ma;
            ret.b /= ma;
        }

        return ret;
    }

    static Color hsv(real H, real S, real V, real A = 1.0)
    {
        byte Hi = cast(byte) (H*6) % 6;
        real Vmin = (1.0-S)*V;
        real a = (V-Vmin)*((H*360) % 60)/60;
        real Vinc = Vmin + a;
        real Vdec = V - a;

        real R, G, B;

        switch (Hi)
        {
            case 0:
                R = V;
                G = Vinc;
                B = Vmin;
                break;
            case 1:
                R = Vdec;
                G = V;
                B = Vmin;
                break;
            case 2:
                R = Vmin;
                G = V;
                B = Vinc;
                break;
            case 3:
                R = Vmin;
                G = Vdec;
                B = V;
                break;
            case 4:
                R = Vinc;
                G = Vmin;
                B = V;
                break;
            case 5:
                R = V;
                G = Vmin;
                B = Vdec;
                break;
            default:
                assert(0);
        }

        return Color(R, G, B, A);
    }
}

enum Mode
{
    Block = 0,
    Circle
}

struct DrawState
{
    real f = 0, t = 360;
    real r = 0, d = 0, plus = 30;
    int post_dir;
    Mode mode;
    real x=0, y=0;
    int line;
    int block, level;
    bool hide;
    int llimit = -1;
    int hideline = -1;
    bool force;
    int sizes_invalid;

    int *blocks;
}

struct RotInfo
{
    double angle = 0.0;
    double target_angle = 0.0;
    Expression fun;
}

struct Button
{
    string text;
    Color c;
    string type;
    Expression expr;
}

Color typeColor(string type)
{
    Color c = Color(1.0, 1.0, 1.0, 1.0);

    if (type == "module")
        c = Color(1.0, 0.4, 0.4, 1.0); // Red
    else if (type == "class")
        c = Color(1.0, 0.8, 0.5, 1.0); // Light Orange
    else if (type == "struct")
        c = Color(1.0, 0.6, 0.0, 1.0); // Saturated Orange
    else if (type == "enum")
        c = Color(1.0, 1.0, 0.4, 1.0); // Yellow
    else if (type == "function")
        c = Color(0.4, 1.0, 0.4, 1.0); // Green
    else if (type == "var")
        c = Color(0.4, 1.0, 1.0, 1.0); // Cyan
    else if (type == "if")
        c = Color(0.8, 0.8, 1.0, 1.0); // Light Blue
    else if (type == "switch")
        c = Color(0.4, 0.4, 1.0, 1.0); // Blue
    else if (type == "for")
        c = Color(1.0, 0.6, 1.0, 1.0); // Light Magenta
    else if (type == "foreach")
        c = Color(1.0, 0.1, 1.0, 1.0); // Saturated Magenta
    else if (type == "while")
        c = Color(0.8, 0.1, 1.0, 1.0); // Saturated Violet
    else if (type == "do")
        c = Color(0.9, 0.6, 1.0, 1.0); // Light Violet

    return c;
}

class Iface : DrawingArea
{
    Expression root_expr;
    Expression fields;
    Expression selected, oselected, fselected, ofunselected;
    Expression scopy;
    string[] lines;
    int cursor;
    real sx1 = 0, sy1 = 0;
    real sx2 = 1200, sy2 = 900;
    real clickX, clickY;
    real clickRX, clickRY;
    real scrollY = 0.0;
    bool click_processed = true;
    bool edit;
    bool post_edit;

public:
	this(Expression _expression)
	{
        root_expr = _expression;
        selected = _expression;
        RotInfo ri;
        ri.fun = selected;
        rot_info ~= ri;
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

    bool click(uint button, double x, double y)
    {
        if (button == 1)
        {
            if (clickX != x || clickY != y)
            {
                clickX = x;
                clickY = y;
                click_processed = false;
                sizes_invalid = 2;
                //writefln("W %sx%s", clickX, clickY);
                redraw();
                return true;
            }
        }
        return false;
    }

    bool scroll(double deltaX, double deltaY)
    {
        scrollY += deltaY*10;
        redraw();
        return true;
    }

    Expression findCircPos(Expression expr, int posa = 1, Expression root = null)
    {
        if (root is null) root = root_expr;
        Expression ret = root;

        foreach(arg; root.arguments ~ (root.postop is null ? [] : [root.postop]))
        {
            //if (arg.hidden && arg.type != "body" && !isNeedHide(arg)) continue;
            arg = findCircPos(expr, posa, arg);
            real expra = (expr.a1 + expr.a2)/2;
            real arga = (arg.a1 + arg.a2)/2;
            real reta = (ret.a1 + ret.a2)/2;

            real argdiff = expra - arga;
            while (argdiff < -180) argdiff += 360;
            while (argdiff > 180) argdiff -= 360;
            real retdiff = expra - reta;
            while (retdiff < -180) retdiff += 360;
            while (retdiff > 180) retdiff -= 360;

            static if (false)
            {
                if ( posa > 0 && arg.x == expr.x && arg.y == expr.y )
                {
                    writefln("%s#%s (%sx%s): %s#%s (%sx%s) => %s#%s (%sx%s)",
                            expr.operator, expr.type, expr.x, expr.y,
                            ret.operator, ret.type, ret.x, ret.y,
                            arg.operator, arg.type, arg.x, arg.y);

                    if (!arg.hidden)
                    {
                        writefln ("0");
                        if (ret.hidden)
                        {
                            writefln("0/0");
                        }
                        else if ( arg.x == expr.x && arg.y == expr.y && !(ret.x == expr.x && ret.y == expr.y) )
                        {
                            writefln("1/1");
                        }
                        else if (arg.x == expr.x && arg.y == expr.y)
                        {
                            writefln("1");
                            if (abs(expr.r1 - arg.r1) < abs(expr.r1 - ret.r1))
                            {
                                writefln("2/2");
                            }
                            else if (abs(expr.r1 - arg.r1) == abs(expr.r1 - ret.r1))
                            {
                                writefln("2");
                                if (retdiff >= 0 && argdiff < 0)
                                {
                                    writefln("3/3");
                                }
                                else if (argdiff < 0 && retdiff < 0 && argdiff >= retdiff)
                                {
                                    writefln("3 final");
                                }
                            }
                        }
                    }
                }
            }

            if (posa > 0 && (
                    !arg.hidden && (ret.hidden ||
                    arg.center is expr.center && ret.center !is expr.center ||
                    arg.center is expr.center && (
                    abs(expr.level - arg.level) < abs(expr.level - ret.level) ||
                    abs(expr.level - arg.level) == abs(expr.level - ret.level) && (retdiff >= 0 && argdiff < 0 ||
                        argdiff < 0 && retdiff < 0 && argdiff >= retdiff )))
               ))
            {
                ret = arg;
            }

            static if (false)
            {
                if ( posa < 0 && arg.center is expr.center )
                {
                    writefln("%s#%s (%sx%s): %s#%s (%sx%s) => %s#%s (%sx%s)",
                            expr.operator, expr.type, expr.x, expr.y,
                            ret.operator, ret.type, ret.x, ret.y,
                            arg.operator, arg.type, arg.x, arg.y);

                    if (!arg.hidden)
                    {
                        writefln ("0");
                        if (ret.hidden)
                        {
                            writefln("0/0");
                        }
                        else if ( arg.center is expr.center && ret.center !is expr.center )
                        {
                            writefln("1/1");
                        }
                        else if (arg.center is expr.center)
                        {
                            writefln("1");
                            if (abs(expr.level - arg.level) < abs(expr.level - ret.level))
                            {
                                writefln("2/2");
                            }
                            else if (abs(expr.level - arg.level) == abs(expr.level - ret.level))
                            {
                                writefln("2");
                                if (retdiff <= 0 && argdiff > 0)
                                {
                                    writefln("3/3");
                                }
                                else if (argdiff > 0 && retdiff > 0 && argdiff <= retdiff)
                                {
                                    writefln("3 final");
                                }
                            }
                        }
                    }
                }
            }

            if (posa < 0 && (
                    !arg.hidden && (ret.hidden ||
                    arg.center is expr.center && ret.center !is expr.center ||
                    arg.center is expr.center && (
                    abs(expr.level - arg.level) < abs(expr.level - ret.level) ||
                    abs(expr.level - arg.level) == abs(expr.level - ret.level) && (retdiff <= 0 && argdiff > 0 ||
                        argdiff > 0 && retdiff > 0 && argdiff <= retdiff )))
               ))
            {
                ret = arg;
            }
        }

        return ret;
    }

    Expression findParent(Expression expr, Expression root = null)
    {
        if (root is null) root = expr;
        Expression ret = root;
        if (root.parent !is null) ret = root.parent;

        if (ret.type == "body")
        {
            if (ret.parent !is null) ret = ret.parent;
            else ret = root;
        }

        return ret;
    }

    Expression findChild(Expression expr, Expression root = null)
    {
        if (root is null) root = expr;
        Expression ret = root;
        if (!root.arguments.empty) ret = root.arguments[root.focus_index];
        else if (root.postop !is null) ret = root.postop;
        else
        {
            auto f = parentOfFun(root);
            if (f !is null && f.postop !is null)
            {
                ret = f.postop;
            }
        }

        if (ret.type == "body")
        {
            if (!ret.arguments.empty) ret = ret.arguments[ret.focus_index];
        }

        return ret;
    }

    Expression findSibling(Expression expr, int dir, Expression root = null)
    {
        if (root is null) root = expr;
        Expression ret = root;

        if (root.parent !is null)
        {
            if (root.index < 0)
            {
               if (dir > 0 && root.arguments.length > 0)
                   ret = root.arguments[0];
            }
            else if (root.index+dir >= 0 && root.index+dir < root.parent.arguments.length)
            {
               ret = root.parent.arguments[root.index+dir];
            }
        }

        return ret;
    }

    void updateView()
    {
        auto expr = selected;
        double nr = (expr.a1 + expr.a2)/2 - 180;
        if (nr < 0) nr += 360;

        RotInfo ri;
        while (!rot_info.empty && rot_info[$-1].fun.block >= expr.block)
        {
            ri.angle = rot_info[$-1].angle;
            rot_info = rot_info[0..$-1];
        }

        ri.target_angle = nr;
        //ri.angle = ri.target_angle; // DEBUG

        ri.fun = expr;
        rot_info ~= ri;

        if (expr.parent !is null && expr.index >= 0)
            expr.parent.focus_index = expr.index;

        //writefln("Select %s (%s), fsel %s", selected, rot_info.length, fselected);
        redraw();
    }

    void updateFields()
    {
        auto sel = selected;
        if (sel.parent !is null && sel.parent.type == ".") sel = sel.parent;
        else if (selected.parent !is null && selected.index >= 0)
        {
            auto ne = new Expression();
            ne.type = ".";
            ne.parent = selected.parent;
            ne.index = selected.index;
            ne.x = selected.x;
            ne.y = selected.y;
            ne.r1 = selected.r1;
            ne.r2 = selected.r2;
            ne.center = selected.center;
            ne.postop = selected.postop;
            selected.postop = null;
            
            if (ne.postop !is null)
            {
                ne.postop.parent = ne;
            }

            selected.parent.arguments[selected.index] = ne;

            selected.parent = ne;
            selected.index = 0;
            ne.arguments = [selected];
            sel = ne;
        }

        if (sel.type == "." && !sel.arguments.empty)
        {
            sel.arguments = [];
            auto fsel = fselected;
            do
            {
                auto ne = new Expression();
                ne.parent = sel;
                ne.operator = fsel.operator;
                sel.arguments = ne ~ sel.arguments;
                fsel = fsel.parent;
            }
            while (fsel !is null);

            foreach(i, arg; sel.arguments)
            {
                arg.index = i;
            }

            selected = sel.arguments[$-1];

            getFile(selected).type = "*";
            sizes_invalid = 1;
            getSize([root_expr], DrawState.init);
            updateView();
            post_edit = false;
        }
    }

    void left()
    {
        if (selected is null) return;
        end_edit();
        auto s = findSibling(selected, -1);
        if (s is selected && s.center !is s || s.hidden)
            selected = findCircPos(selected, -1);
        else selected = s;
        updateView();
    }

    void right()
    {
        if (selected is null) return;
        end_edit();
        auto s = findSibling(selected, 1);
        if (s is selected && s.center !is s || s.hidden)
            selected = findCircPos(selected, 1);
        else selected = s;
        updateView();
    }

    void up()
    {
        if (selected is null) return;
        end_edit();
        selected = findParent(selected);
        updateView();
    }

    void down()
    {
        if (selected is null) return;
        end_edit();
        selected = findChild(selected);
        updateView();
    }

    void field_left()
    {
        if (fselected is null) return;
        end_edit();
        auto s = findSibling(fselected, -1);
        if (s is fselected && s.center !is s)
            fselected = findCircPos(fselected, -1, fields);
        else fselected = s;
        updateFields();
    }

    void field_right()
    {
        if (fselected is null) return;
        end_edit();
        auto s = findSibling(fselected, 1);
        if (s is fselected && s.center !is s)
            fselected = findCircPos(fselected, 1, fields);
        else fselected = s;
        updateFields();
    }

    void field_up()
    {
        if (fselected is null) return;
        end_edit();
        fselected = findParent(fselected);
        updateFields();
    }

    void field_down()
    {
        if (fselected is null) return;
        end_edit();
        fselected = findChild(fselected);
        updateFields();
    }

    void end_edit()
    {
        if (edit)
        {
            edit = false;
            if (selected.parent is null || selected.parent.type != "\"")
            {
                auto s = selected.operator.findSplit("@");
                selected.operator = s[0];
                if (s[1] == "@") selected.label = s[2];

                s = selected.operator.findSplit("#");
                selected.operator = s[0];
                if (s[1] == "#") selected.type = s[2];

                sizes_invalid = 1;
            }
        }
    }

    void print(dchar key)
    {
        if (selected is null) return;
        if (!edit)
        {
            if (key == '@')
            {
                if (!selected.type.empty)
                    selected.operator ~= "#" ~ selected.type;
            }
            else selected.operator = "";
        }

        selected.operator ~= key;
        getFile(selected).type = "*";
        sizes_invalid = 1;
        redraw();
        edit = true;
        post_edit = false;
    }

    void backspace()
    {
        if (selected is null) return;

        if (!selected.operator.empty)
            selected.operator = selected.operator[0..$-selected.operator.strideBack];
        getFile(selected).type = "*";
        sizes_invalid = 1;
        redraw();
        edit = true;
        post_edit = false;
    }

    void space()
    {
        if (selected is null) return;
        if (edit && !selected.operator.empty && selected.operator[0] == '\"' && (selected.operator.length == 1 || selected.operator[$-1] != '\"'))
        {
            print(' ');
            return;
        }
        end_edit();

        if (selected.parent !is null && selected.index >= 0)
        {
            auto ne = new Expression();
            ne.parent = selected.parent;
            ne.index = selected.index+1;
            ne.x = selected.x;
            ne.y = selected.y;
            ne.r1 = selected.r1;
            ne.r2 = selected.r2;
            ne.center = selected.center;
            foreach(arg; selected.parent.arguments[selected.index+1..$])
            {
                arg.index++;
            }
            selected.parent.arguments = selected.parent.arguments[0..selected.index+1] ~ ne ~ selected.parent.arguments[selected.index+1..$];
            selected = ne;
        }
        getFile(selected).type = "*";
        sizes_invalid = 1;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void dot()
    {
        if (selected is null) return;
        if (edit)
        {
            print('.');
            return;
        }

        if (selected.parent !is null && selected.index >= 0)
        {
            auto ne = new Expression();
            ne.parent = selected.parent;
            ne.index = selected.index;
            ne.x = selected.x;
            ne.y = selected.y;
            ne.r1 = selected.r1;
            ne.r2 = selected.r2;
            ne.center = selected.center;
            ne.postop = selected.postop;
            selected.postop = null;
            
            if (ne.postop !is null)
            {
                ne.postop.parent = ne;
            }

            selected.parent.arguments[selected.index] = ne;

            selected.parent = ne;
            selected.index = 0;
            ne.arguments = [selected];
            selected = ne;
        }
        getFile(selected).type = "*";
        sizes_invalid = 2;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void comma()
    {
        if (selected is null) return;
        if (edit && (selected.parent !is null && selected.parent.type == "\"" ||
                    !selected.operator.empty && selected.operator[0] == '\"' &&
                     (selected.operator.length == 1 || selected.operator[$-1] != '\"')))
        {
            print(',');
            return;
        }
        end_edit();

        auto ne = new Expression();
        ne.parent = selected;
        ne.index = 0;
        ne.x = selected.x;
        ne.y = selected.y;
        ne.r1 = selected.r1;
        ne.r2 = selected.r2;
        ne.r3 = selected.r3;
        ne.center = selected.center;

        foreach(arg; selected.arguments)
        {
            arg.index++;
        }

        selected.arguments = ne ~ selected.arguments;
        selected = ne;

        getFile(selected).type = "*";
        sizes_invalid = 2;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void less()
    {
        if (selected is null) return;

        if (!post_edit && selected.postop is null)
        {
            auto ne = new Expression();
            ne.parent = selected;
            ne.index = -1;
            ne.x = selected.x;
            ne.y = selected.y;
            ne.center = selected.center;
            selected.postop = ne;
            selected = ne;

            if (ne.parent.type == "function" || ne.parent.type == "for" || ne.parent.type == "while" || ne.parent.type == "do" || ne.parent.type == "foreach" || ne.parent.parent.type == "if" || ne.parent.parent.type == "switch")
            {
                ne.type = "body";
                comma();
                selected = ne;
            }
        }
        else if (selected.postop !is null)
        {
            Expression pe = selected.postop;
            if (selected.index >= -pe.index)
                pe.index--;
        }
        else
        {
            Expression ep = selected.parent;
            while (ep.index < 0)
            {
                assert(ep.parent.postop is ep);
                ep = ep.parent;
            }
            assert(ep.parent.arguments[ep.index] is ep);

            if (ep.index >= -selected.index)
                selected.index--;
        }

        getFile(selected).type = "*";
        sizes_invalid = 1;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = true;
    }

    void greater()
    {
        if (selected is null) return;

        if (!post_edit && selected.postop is null)
        {
            auto ne = new Expression();
            ne.parent = selected;
            ne.index = -1;
            ne.x = selected.x;
            ne.y = selected.y;
            ne.center = selected.center;
            selected.postop = ne;
            selected = ne;
        }
        else if (selected.postop !is null)
        {
            Expression pe = selected.postop;
            if (pe.index < -1)
                pe.index++;
        }
        else
        {
            if (selected.index < -1)
                selected.index++;
        }

        getFile(selected).type = "*";
        sizes_invalid = 1;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = true;
    }

    void escape()
    {
        if (edit || post_edit)
        {
            end_edit();
            post_edit = false;
            updateView();
        }
        else
        {
            edit = true;
        }
    }

    void del()
    {
        if (selected is null) return;

        if (selected.parent !is null)
        {
            if (selected.parent.focus_index > 0) selected.parent.focus_index--;
            if (selected.index >= 0)
            {
                foreach(arg; selected.parent.arguments[selected.index+1..$])
                {
                    arg.index--;
                }
                selected.parent.arguments = selected.parent.arguments[0..selected.index] ~ selected.parent.arguments[selected.index+1..$];
                if (selected.parent.arguments.length > selected.index)
                    selected = selected.parent.arguments[selected.index];
                else
                    selected = selected.parent;
            }
            else
            {
                selected.parent.postop = null;
                selected = selected.parent;
            }
        }
        getFile(selected).type = "*";
        sizes_invalid = 1;
        updateView();
        edit = true;
        post_edit = false;
    }

    void remove()
    {
        if (selected is null) return;

        selected.arguments = null;
        selected.postop = null;
        selected.focus_index = 0;

        getFile(selected).type = "*";
        sizes_invalid = 1;
        updateView();
        edit = true;
        post_edit = false;
    }

    void copy()
    {
        if (selected is null) return;

        scopy = selected;

        post_edit = false;
    }

    void insert()
    {
        if (selected is null || scopy is null) return;

        auto c = scopy.deepcopy;
        if (selected.index >= 0)
        {
            selected.parent.arguments[selected.index] = c;
            c.parent = selected.parent;
            c.index = selected.index;
        }
        else
        {
            selected.parent.postop = c;
            c.parent = selected.parent;
            c.index = selected.index;
        }
        selected = c;

        getFile(selected).type = "*";
        sizes_invalid = 1;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void moveleft()
    {
        if (selected is null) return;
        if (selected.index <= 0) return;

        selected.parent.arguments[selected.index-1].index++;
        swap(selected.parent.arguments[selected.index], selected.parent.arguments[selected.index-1]);
        selected.index--;

        getFile(selected).type = "*";
        sizes_invalid = 2;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void moveright()
    {
        if (selected is null) return;
        if (selected.index <= 0) return;

        if (selected.index >= selected.parent.arguments.length-1) return;
        selected.parent.arguments[selected.index+1].index--;
        swap(selected.parent.arguments[selected.index], selected.parent.arguments[selected.index+1]);
        selected.index++;

        getFile(selected).type = "*";
        sizes_invalid = 2;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

    void redraw()
    {
		GtkAllocation area, ar;
		getAllocation(area);
        ar = area;

        if (sizes_invalid <= 1 && oselected !is null && oselected.center is selected.center && ofunselected is parentOfFun(selected))
        {
            real w = sx2 - sx1;
            real h = sy2 - sy1;

            area.width = area.width*5/6;
            w = h*area.width/area.height;

            real scale = area.width/w;
            real dx = w/5.0;
            
            area.x = cast(int) ((selected.center.x - selected.center.r3 + dx) * scale);
            area.y = cast(int) ((selected.center.y - 150) * scale);
            area.width = cast(int) ((selected.center.r3 * 2) * scale);
            area.height = cast(int) ((selected.center.r3 + 150) * scale);

            //writefln("Queue redraw %sx%s - %sx%s", area.x, area.y, area.width, area.height);
            queueDrawArea(area.x, area.y, area.width, area.height);
            //writefln("Queue navigation redraw %sx%s - %sx%s", 0, 0, ar.width/6, ar.height);
            queueDrawArea(0, 0, ar.width/6, ar.height);
        }
        else
        {
            sizes_invalid = 2;
            queueDrawArea(area.x, area.y, area.width, area.height);
        }
    }

    Expression getFile(Expression expr)
    {
        if (expr.parent is null) return null;
        if (expr.bt != BlockType.File) return getFile(expr.parent);
        return expr;
    }

    Expression getModule(Expression expr)
    {
        if (expr.parent is null) return null;
        if (expr.type != "module") return getModule(expr.parent);
        return expr;
    }

    void save()
    {
        auto efile = getFile(selected);
        if (efile is null) return;
        if (efile.type == "*")
        {
            efile.type = "";
            string savestr = efile.save();
            auto file = File(efile.operator, "w");
            file.writeln(savestr);
        }
    }

    void saveD()
    {
        auto mod = getModule(selected);
        auto efile = getFile(mod);
        if (efile is null) return;
        auto filename = efile.operator;
        if ( filename.endsWith(".np") )
            filename = filename[0..$-3];

        if (mod.label == "D")
        {
            string savestr = efile.saveD();
            auto file = File(filename~".d", "w");
            file.writeln(savestr);
        }
    }

    void toLexer()
    {
        auto mod = getModule(selected);
        auto efile = getFile(mod);
        if (efile is null) return;
        if (mod.label == "Lexer")
        {
            auto root = efile.toLexer();
            root.parent = root_expr;
            root.index = root_expr.arguments.length;
            root_expr.arguments ~= root;
            selected = root;
        }

        sizes_invalid = 1;
        getSize([root_expr], DrawState.init);
        updateView();
        post_edit = false;
    }

protected:
	real textWidth(string text)
	{
        static real[string] cache;

        auto res_cache = text in cache;
        if (res_cache !is null) return *res_cache;

        auto context = PgCairoFontMap.getDefault().createContext();
        auto layout = new PgLayout(context);

        auto desc = PgFontDescription.fromString("Times new roman,Sans");
        desc.setAbsoluteSize(20*PANGO_SCALE);

        layout.setFontDescription(desc);

        layout.setText(text);
        
        int width, height;
        layout.getSize(width, height);

        real rw = 1.0*width / PANGO_SCALE;
        cache[text] = rw;

        return rw;
    }

	void drawText(ref Scoped!Context cr, string text, real X, real Y, real w, Color c, bool inv = false, ubyte[] colors = null)
	{
        if (inv) c = c.invert();
        cr.setSourceRgba(c.r, c.g, c.b, c.a);

        Color black = Color(0.3, 0.0, 0.0, 1.0);
        if (inv) black = black.invert();

        Color selcol = Color(1.0, 0.0, 0.0, 1.0);
        if (!inv) selcol = selcol.invert();

        auto layout = PgCairo.createLayout(cr);

        auto desc = PgFontDescription.fromString("Times new roman,Sans");
        desc.setAbsoluteSize(20*PANGO_SCALE);

        layout.setFontDescription(desc);

        layout.setText(text);
        PgCairo.updateLayout(cr, layout);

        int width, height;
        layout.getSize(width, height);

        if (width/PANGO_SCALE > w)
        {
            desc.setAbsoluteSize(20*PANGO_SCALE*w/(width/PANGO_SCALE));
            layout.setFontDescription(desc);
            PgCairo.updateLayout(cr, layout);
            layout.getSize(width, height);
        }

        if (colors is null)
        {
            real XX = X - width/PANGO_SCALE/2;
            real YY = Y - height/PANGO_SCALE/2;

            cr.moveTo(XX, YY);
            PgCairo.showLayout(cr, layout);
        }
        else
        {
            real XX = X - width/PANGO_SCALE/2;
            real YY = Y - height/PANGO_SCALE/2;
            long cur_chr_stride;
            long wi = 0;
            for (long i = 0; i < text.length; i += cur_chr_stride)
            {
                cur_chr_stride = text.stride(i);
                string chr = text[i..i+cur_chr_stride].idup();

                ubyte co = colors[wi];
                switch (co)
                {
                    case 0:
                        cr.setSourceRgba(c.r, c.g, c.b, c.a);
                        desc.setWeight(PangoWeight.NORMAL);
                        break;
                    case 1:
                        cr.setSourceRgba(black.r, black.g, black.b, black.a);
                        desc.setWeight(PangoWeight.NORMAL);
                        break;
                    case 2:
                        cr.setSourceRgba(selcol.r, selcol.g, selcol.b, selcol.a);
                        desc.setWeight(PangoWeight.HEAVY);
                        break;
                    default:
                        assert(0);
                }

                
                wi++;
                while (wi < colors.length && colors[wi] == co)
                {
                    i += cur_chr_stride;
                    cur_chr_stride = text.stride(i);
                    chr ~= text[i..i+cur_chr_stride];
                    wi++;
                }

                layout.setFontDescription(desc);

                layout.setText(chr);
                PgCairo.updateLayout(cr, layout);
                int Width, Height;
                layout.getSize(Width, Height);

                XX += Width/PANGO_SCALE/2;
                cr.save();
                cr.translate(XX, YY);
                cr.moveTo(-Width/PANGO_SCALE/2, 0);

                PgCairo.showLayout(cr, layout);

                cr.restore();
                XX += Width/PANGO_SCALE/2;
            }
        }
    }

	real arcTextWidth(string text, real radius)
	{
        auto context = PgCairoFontMap.getDefault().createContext();
        auto layout = new PgLayout(context);

        auto desc = PgFontDescription.fromString("Times new roman,Sans");
        desc.setAbsoluteSize(20*PANGO_SCALE);

        long cur_chr_stride;

        real eangle = 0.0;
        for (long i = 0; i < text.length; i += cur_chr_stride)
        {
            cur_chr_stride = text.stride(i);
            string chr = text[i..i+cur_chr_stride].idup();

            layout.setText(chr);
            int Width, Height;
            layout.getSize(Width, Height);

            eangle += Width/PANGO_SCALE * 70 / radius;
        }

        return eangle;
    }

	real arcTextWidthRecursive(Expression[] expressions, real radius)
    {
        real tw = 0;
        foreach(i, expr; expressions)
        {
            if (expr.type == "." || expr.type == "[")
            {
                tw += arcTextWidthRecursive(expr.arguments, radius);
            }
            else
            {
                string text = (expr.index < 0 ? "." : "") ~ (expr.operator.empty ? expr.type : expr.operator);
                if (text.empty) text = ".";
                tw += arcTextWidth(text, radius);
            }
        }

        return tw;
    }

	void drawArcText(ref Scoped!Context cr, string text, real a_from, real a_to, real radius,
            real h1, real h2, real X, real Y,
            Color c, bool inv = false, ubyte[] colors = null)
	{
        text = " "~text~" ";
        if (colors !is null) colors = 0 ~ colors ~ 0;
        if (inv) c = c.invert();
        cr.setSourceRgba(c.r, c.g, c.b, c.a);

        Color black = Color(0.3, 0.0, 0.0, 1.0);
        if (inv) black = black.invert();

        Color selcol = Color(1.0, 0.0, 0.0, 1.0);
        if (!inv) selcol = selcol.invert();

        auto layout = PgCairo.createLayout(cr);

        auto desc = PgFontDescription.fromString("Times new roman,Sans");
        desc.setAbsoluteSize(20*PANGO_SCALE);

        layout.setFontDescription(desc);

        if (radius <= 15)
        {
            layout.setText(text);
            PgCairo.updateLayout(cr, layout);

            int width, height;
            layout.getSize(width, height);

            if (width/PANGO_SCALE/2 < 30)
            {
                real XX = X - width/PANGO_SCALE/2;
                real YY = Y - height/PANGO_SCALE/2;

                cr.moveTo(XX, YY);
                PgCairo.showLayout(cr, layout);

                return;
            }
            else
            {
                a_from = -45;
                a_to = -315;
                radius = 20;
            }
        }

        struct Rect
        {
            int w, h;
        }

        static Rect[string] cache;

        long cur_chr_stride;
        real height = 0.0;

        real eangle = 0.0;
        for (long i = 0; i < text.length; i += cur_chr_stride)
        {
            cur_chr_stride = text.stride(i);
            string chr = text[i..i+cur_chr_stride].idup();

            Rect rect;

            auto in_cache = chr in cache;
            if (in_cache !is null) rect = *in_cache;
            else
            {
                layout.setText(chr);
                PgCairo.updateLayout(cr, layout);
                layout.getSize(rect.w, rect.h);
                cache[chr] = rect;
            }

            height = max(height, rect.h/PANGO_SCALE);

            eangle += rect.w/PANGO_SCALE * 70 / radius;
        }

        real scale = 1.0;
        real wanted_eangle = abs(a_to - a_from);

        assert(h1 > 0);
        assert(h2 > 0);
        assert(height > 0);
        if (height*scale > h1)
        {
            scale = h1 / height;
            eangle *= scale;
        }

        assert(eangle > 0);
        assert(wanted_eangle > 0);
        if (eangle > wanted_eangle)
        {
            scale *= wanted_eangle / eangle;
            eangle = wanted_eangle;
        }

        int dir = a_to > a_from ? 1 : -1;
        real angle = (a_from+a_to)/2-dir*eangle/2;
        assert(!angle.isNaN);
        assert(!scale.isNaN);
        assert(scale > 0);

        long wi = 0;

        for (long i = 0; i < text.length; i += cur_chr_stride)
        {
            cur_chr_stride = text.stride(i);
            string chr = text[i..i+cur_chr_stride].idup();

            if (colors !is null)
            {
                switch (colors[wi])
                {
                    case 0:
                        cr.setSourceRgba(c.r, c.g, c.b, c.a);
                        desc.setWeight(PangoWeight.NORMAL);
                        break;
                    case 1:
                        cr.setSourceRgba(black.r, black.g, black.b, black.a);
                        desc.setWeight(PangoWeight.NORMAL);
                        break;
                    case 2:
                        cr.setSourceRgba(selcol.r, selcol.g, selcol.b, selcol.a);
                        desc.setWeight(PangoWeight.HEAVY);
                        break;
                    default:
                        assert(0);
                }
            }
            layout.setFontDescription(desc);

            wi++;

            layout.setText(chr);
            PgCairo.updateLayout(cr, layout);
            auto rect = cache[chr];
            int Width = rect.w;
            int Height = rect.h;

            cr.save();
            angle += dir*Width/PANGO_SCALE * 35 / radius * scale;
            assert(!angle.isNaN);
            assert(!X.isNaN);
            assert(!Y.isNaN);
            cr.translate(X, Y);
            real k = (cos(angle*PI/180.0)+1.0)/2;
            real s = scale * (k*h2 + (1-k)*h1)/h1;
            cr.scale(s, s);
            cr.rotate((dir < 0 ? PI : 0)+angle*PI/180.0);
            cr.moveTo(-Width/PANGO_SCALE/2, -dir*radius/s - Height/PANGO_SCALE/2);
            angle += dir*Width/PANGO_SCALE * 35 / radius * scale;

            PgCairo.showLayout(cr, layout);

            cr.restore();
        }
    }

	void drawArc(ref Scoped!Context cr, real a_from, real a_to, real p1, real p2, real d1, real d2,
            real X, real Y, Color c, bool inv = false, bool lines = true)
	{
        assert(a_from < 1440);
        assert(a_to < 1440);

        real r1 = (p1+d1)/2;
        real r2 = (p2+d2)/2;
        real Y1 = Y + (p1-d1)/2;
        real Y2 = Y + (p2-d2)/2;

		cr.setLineWidth(m_lineWidth * (r2-r1)/30);
        a_from = 270 + a_from;
        a_to = 270 + a_to;

        if (inv) c = c.invert();
        cr.setSourceRgba(c.r, c.g, c.b, c.a);

        if (r1 > 0.01)
        {
            cr.moveTo(X + r1*cos(a_from*PI/180), Y1 + r1*sin(a_from*PI/180));
            cr.lineTo(X + r2*cos(a_from*PI/180), Y2 + r2*sin(a_from*PI/180));
        }
        else
            cr.moveTo(X + r2*cos(a_from*PI/180), Y2 + r2*sin(a_from*PI/180));
        
        cr.arc(X, Y2, r2, a_from*PI/180, a_to*PI/180);

        if (r1 > 0.01)
        {
            cr.lineTo(X + r1*cos(a_to*PI/180), Y1 + r1*sin(a_to*PI/180));
            cr.arcNegative(X, Y1, r1, a_to*PI/180, a_from*PI/180);
        }
        cr.fill();

        Color black = Color(0, 0, 0.0, 1.0);
        if (inv) black = black.invert();
        cr.setSourceRgba(black.r, black.g, black.b, black.a);

        if (r1 > 0.01)
        {
            if (lines || abs(a_from-270) < 1 || abs(a_from-270-360) < 1)
            {
                cr.moveTo(X + r1*cos(a_from*PI/180), Y1 + r1*sin(a_from*PI/180));
                cr.lineTo(X + r2*cos(a_from*PI/180), Y2 + r2*sin(a_from*PI/180));
            }
            if (lines || abs(a_to-270) < 1 || abs(a_to-270-360) < 1)
            {
                cr.moveTo(X + r1*cos(a_to*PI/180), Y1 + r1*sin(a_to*PI/180));
                cr.lineTo(X + r2*cos(a_to*PI/180), Y2 + r2*sin(a_to*PI/180));
            }
        }
        
        cr.moveTo(X + r2*cos(a_from*PI/180), Y2 + r2*sin(a_from*PI/180));
        cr.arc(X, Y2, r2, a_from*PI/180, a_to*PI/180);
        cr.stroke();

		cr.setLineWidth(m_lineWidth);
    }

    DrawState getSize(Expression[] expressions, DrawState ds)
    {
        DrawState ret = ds;
        
        if (ds.llimit < 0 && ds.mode == Mode.Block)
            //p-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------m
        {
            ds.block++;

            ds.r = 0;
            ds.d = 0;

            foreach(i, expr; expressions)
            {
                if (expr.parent is null)
                {
                    if (!ds.force)
                    {
                        if (sizes_invalid == 0) return ret;
                        rlines = [0.0];
                    }
                    ds.line = 0;
                }
                else if (expr.parent.type == "body" && expr.index == 0)
                {
                    ds.line++;
                    if (rlines.length < ds.line+1) rlines ~= 0.0;
                }

                real width = 0.0;
                int blocks;

                auto ds2 = ds;
                ds2.post_dir = 0;
                ds2.level = 1;

                ds2.llimit = 0;
                ds2.blocks = &blocks;

                if (ds.r == 0)
                {
                    expr.center = expr;
                }
                else
                {
                    expr.center = expr.parent;
                }
                if (i == 0) expr.center.levels = 0;

                string text = (expr.index < 0 ? "." : "") ~ (expr.operator.empty ? expr.type : expr.operator);
                if (text.empty) text = ".";

                expr.pw = [ textWidth(text) + 5, 0.0 ];
                expr.mw = [];
                width = expr.pw[0];

                blocks = 1;

                ds2.post_dir = 0;
                ds2 = getSize(cast(Expression[]) expr.arguments, ds2);
                ds2.post_dir = 1;
                if (expr.postop !is null)
                    ds2 = getSize(cast(Expression[]) [expr.postop], ds2);

                if (expr.pw[1] < expr.pw[0])
                {
                    expr.pw[1] = expr.pw[0];
                }

                width = expr.pw[1];

                expr.pw[1] = width;
                expr.r3 = width/(2*PI);
                int levels = *ds2.blocks;
                //writefln("%s#%s levels %s", expr.operator, expr.type, levels);

                expr.center.levels = max(expr.center.levels, levels);
                //writefln("%s. %s#%s r3=%s, levels=%s", ds.block, expr.operator, expr.type, expr.r3, expr.center.levels);

                //if (expr.r3 < expr.center.levels*30)
                    expr.r3 = expr.center.levels*30;

                if (!ds.force)
                    rlines[ds.line] = max(rlines[ds.line], expr.r3);
            }

            if (!expressions.empty)
            {
                auto expr = expressions[0];

                ds.f = 0;
                ds.t = 360;
                ds.r = 0;
                ds.d = 0;
                ds.level = 0;
            }
        }

        real sumpw = 0;
        foreach(i, expr; expressions)
        {
            real fr, to;

            if (expr.parent !is null && ds.level > 0)
                expr.center = expr.parent.center;

            if (ds.llimit >= 0)
            {
                //writefln("%s. %s#%s", ds.llimit, expr.operator, expr.type);
                if (expr.parent !is null && (expr.parent.type == "root" || expr.parent.type == "module" || expr.parent.bt == BlockType.File || expr.parent.type == "body"))
                    continue;

                auto ds2 = ds;
                if (expr.parent is null || expr.parent.index >= 0 || expr.parent.type == "body" || expr.parent.type == "module" || expr.parent.bt == BlockType.File)
                    ds2.level++;

                string text = (expr.index < 0 ? "." : "") ~ (expr.operator.empty ? expr.type : expr.operator);
                if (text.empty) text = ".";

                expr.pw = [ textWidth(text) + 5, 0.0 ];

                ds2.post_dir = 0;
                ds2 = getSize(cast(Expression[]) expr.arguments, ds2);
                ds2.post_dir = 1;
                if (expr.postop !is null)
                    ds2 = getSize(cast(Expression[]) [expr.postop], ds2);

                if (expr.pw[1] < expr.pw[0])
                {
                    expr.pw[1] = expr.pw[0];
                }

                auto par = expr.parent;
                if (par.index >= 0) par.pw[1] += expr.pw[1];
                while (par.index < 0)
                {
                    par = par.parent;
                    par.pw[1] += expr.pw[1];
                }
                //writefln("l%s. %s#%s <= %s#%s (%s <=== %s)", ds.llimit, par.operator, par.type,
                //        expr.operator, expr.type, par.pw[1], expr.pw[1]);

                //writefln("%s", ds.level);
                (*ds.blocks) = max((*ds.blocks), ds.level);

                if (expr.index < 0)
                    ds.level++;
            }
            
            if (ds.llimit < 0)
            {
                if (expr.index < 0)
                {
                    //writefln("%s-%s:%s: %s", f, t, expr.index, rf);

                    assert(expr.parent.postop is expr);
                    Expression ep = expr.parent;
                    while (ep.index < 0)
                    {
                        assert(ep.parent.postop is ep);
                        ep = ep.parent;
                    }
                    //writefln("%s/%s. %s. %s..%s", expr.operator, ep.operator, ep.parent.arguments.length, ep.index+expr.index+1, ep.index+1);
                    assert(ep.parent.arguments[ep.index] is ep);

                    if (ds.mode == Mode.Circle && ep.index+expr.index+1 > 0 && ep.parent.arguments.length > ep.index)
                    {
                        ds.f = ep.parent.arguments[ep.index+expr.index+1].a1;
                        ds.t = ep.parent.arguments[ep.index].a2;
                    }

                    foreach(pre; ep.parent.arguments[ep.index+expr.index+1..ep.index+1])
                    {
                        //ds.r = max(ds.r, pre.r3);
                        if (expr.type == "body" && (ep.parent.type == "if" || ep.parent.type == "switch"))
                        {
                            real hue = (1.0*ep.index + expr.index/2.0 + 1.0)/(ep.parent.arguments.length+1);
                            pre.c = Color.hsv(hue, 0.5, 1.0);
                        }
                    }
                }

                if (ds.mode == Mode.Block)
                {
                    sumpw = 0;
                }

                //if (ds.level == 4)
                //writefln("%s.%s %s/%s. %s", ds.block, ds.level, expr, expr.parent, expr.pw);
                assert(expr.pw.length > 0);
                real w = expr.pw[1];
                assert(w > 0);
                auto par = expr.parent;
                real parentw = par is null || ds.mode == Mode.Block ? w : par.pw[1];
                while (par && par.index < 0 && par.parent.index < 0) par = par.parent;
                if (par !is null && par.index < 0 && par.type != "body")
                {
                    //if (expr !is expr.center)
                    //writefln("++ %s/%s. %s/%s", par, par.parent, par.pw, par.parent.pw);
                        parentw = par.parent.pw[1] - par.pw[1];
                    //else
                    //    parentw = w;
                }
                /*if (expr is expr.center)
                    parentw = (expr.r3)*2*PI;
                if (par !is null && par.index < 0 && par is par.center)
                    parentw = (par.r3)*2*PI;*/

                assert(parentw > 0);
                if (par !is null && expr !is expr.center)
                    expr.r3 = par.r3;
                assert(!expr.r3.isNaN && expr.r3 > 0);

                fr = ds.f + (ds.t-ds.f) * sumpw / parentw;
                to = ds.f + (ds.t-ds.f) * (sumpw + w) / parentw;

                real a = 180 - (to - fr)/2;
                real b = 180 - (expr.pw[0]/(ds.r+15) * 180/PI)/2;
                real rw = log(b/180)/log(a/180);
                if (expr.center.mw.length < ds.level+1) expr.center.mw ~= 1.0;
                expr.center.mw[ds.level] = max(expr.center.mw[ds.level], rw);

                if ((expr.index >= 0 && expr.index == expressions.length-1 || expr.index < 0 && expr.arguments.length == 0) && ds.t > to)
                    to = ds.t;
                
                if (expr.index >= 0)
                    sumpw += w;
                /*if (ds.level == 4)
                writefln("    %s => %s | %s => %s | %s | %s/%s/%s",
                        a, b,
                        to - fr,
                        expr.pw[0]/(ds.r+15) * 180/PI,
                        rw, w, sumpw, parentw);*/
                //writefln("    %s-%s (%s/%s)", fr, to, sumpw, parentw);
                assert(to >= fr);
                assert(sumpw <= parentw);

                Color c = typeColor(expr.type);
                //if (assign == 1 && ii == 0)
                //    c = Color(1.0, 0.5, 0.5, 1.0);
                if (ds.post_dir > 0)
                    c = Color(1.0, 1.0, 0.8, 1.0); // Yellow
                else if (ds.post_dir < 0)
                    c = Color(0.8, 0.8, 0.6, 1.0); // Dark Yellow

                real plus = ds.plus;
                if (ds.r > 90)
                {
                    plus /= 2;
                }

                expr.r1 = ds.r;
                expr.r2 = ds.r + 30;
                expr.d1 = ds.d;
                expr.d2 = ds.d + plus;
                expr.level = ds.level;
                //writefln("lev %s %s#%s. %s-%s", ds.level, expr.operator, expr.type, expr.r1, expr.r2);
                expr.a1 = fr;
                expr.a2 = to;
                //if (fr.isNaN || to.isNaN)
                //    writefln("%s. %s#%s %s (%s-%s) (%s)", expr.level, expr.operator, expr.type, expr.pw[1], expr.a1, expr.a2, parentw);
                expr.c = c;
                expr.block = ds.block;

                DrawState ds2 = ds;
                if (expr.index >= 0)
                {
                    if (!isNeedHide(expr))
                    {
                        ds2.r += 30;
                        ds2.d += plus;
                        ds2.plus = plus;
                    }
                    ds2.level++;
                    ds2.post_dir = 0;
                }
                else
                {
                    fr = to;
                    to = ds.t;
                    ds2.post_dir = -1;
                }
                
                ds2.f = fr;
                ds2.t = to;

                //writefln("%s#%s %s >= %s %s", expr.operator, expr.type, expr.level, expr.center.levels, expr.index);
                if (expr.type == "root" || expr.type == "module" || expr.bt == BlockType.File || expr.type == "body")
                {
                    ds2.mode = Mode.Block;
                    ds2.post_dir = 0;
                }
                else
                    ds2.mode = Mode.Circle;

                ds2 = getSize(cast(Expression[]) expr.arguments, ds2);
                ds2.post_dir = 1;
                if (expr.postop !is null)
                    ds2 = getSize(cast(Expression[]) [expr.postop], ds2);

                if (expr.index < 0)
                {
                    if (expr.type != "body")
                    {
                        ds.r += 30;
                        ds.d += plus;
                        ds.plus = plus;
                    }
                    ds.level++;
                    //writefln("%s %s.%s %s#%s %X", ds.mode, expr.block, expr.level, expr.operator, expr.type, cast(void*)expr.center);
                }

                if (ds2.mode == Mode.Circle)
                {
                    ret.r = max(ret.r, ds.r, ds2.r);
                    ret.d = max(ret.d, ds.d, ds2.d);
                    expr.r3 = max(expr.r3, ds.r, ds2.r);
                }

                if (ds.level == 0)
                {
                    //writefln("%s#%s %s", expr.operator, expr.type, expr.mw);
                }
            }
        }

        return ret;
    }

    void connectExpressions(ref Scoped!Context cr, Expression expression1, Expression expression2, real tx = real.nan, real ty = real.nan)
    {
        if (expression1 is null || expression2 is null) return;
        cr.save();
            real cx1 = expression1.x;
            real cy1 = expression1.y;
            real cx2 = tx.isNaN ? expression2.x : tx;
            real cy2 = ty.isNaN ? expression2.y : ty;

            //writefln("%sx%s-%sx%s", cx1, cy1, cx2, cy2);
            if (!tx.isNaN && tx < cx1)
            {
                cr.moveTo(cx1 - expression1.r3 + 30, cy1);
                cr.lineTo(cx2, cy1);
            }
            else if (cx2 > cx1)
            {
                cr.moveTo(cx1 + expression1.r3 - 30, cy1);
                cr.lineTo(cx2, cy1);
            }
            else
            {
                cr.moveTo(cx1, cy1 + expression1.r3 - 30);
                cr.lineTo(cx1, cy2);
            }
            cr.lineTo(cx2, cy2);

            if (!tx.isNaN && !ty.isNaN)
            {
                cx1 = tx;
                cy1 = ty;
                cx2 = expression2.x;
                cy2 = expression2.y;

                if (cx2 > cx1)
                {
                    cr.lineTo(cx2, cy1);
                }
                else
                {
                    cr.lineTo(cx1, cy2);
                }

                cr.lineTo(cx2, cy2 + (cy1 > cy2 ? expression2.r3 - 30 : 0));
            }

            cr.stroke();
        cr.restore();
    }

    Expression[] inExpressions(Expression expr)
    {
        Expression[] ret;

        if (expr.type == "if" || expr.type == "switch")
        {
            foreach(arg; expr.arguments)
            {
                assert(arg.postop.type == "body");
                ret ~= inExpressions(arg.postop.arguments[$-1]);
            }
        }
        else if (expr.type == "for" || expr.type == "foreach" || expr.type == "while" || expr.type == "do")
        {
            assert(expr.arguments[$-1].postop.type == "body");
            ret ~= expr;
            ret ~= inExpressions(expr.arguments[$-1].postop.arguments[$-1]);
        }
        else ret = [expr];

        return ret;
    }

    Expression[] prevExpressions(Expression expr)
    {
        if (expr.index == 0)
        {
            if (expr.parent.type == "body")
                return [expr.parent.parent];
            else
                return [expr.parent];
        }
        else
        {
            if (expr.index >= 0)
            {
                return inExpressions(expr.parent.arguments[expr.index - 1]);
            }
        }

        return [];
    }

    Expression inBody(Expression expr)
    {
        Expression ret = expr.parent;
        while (ret !is null)
        {
            if (ret.type == "body" || ret.type == "module" || ret.bt == BlockType.File) return ret;
            ret = ret.parent;
        }
        return null;
    }

    Expression parentOfFun(Expression expr)
    {
        Expression ret = expr;
        while (ret !is null)
        {
            if (ret.type == "root" || ret.type == "module" || ret.bt == BlockType.File || ret.type == "function" || ret.type == "for" || ret.type == "foreach" || ret.type == "while" || ret.type == "do" || ret.parent !is null && (ret.parent.type == "if" || ret.parent.type == "switch"))
            {
                if (ret.parent !is null && ret.index >= 0 && (ret.postop is null || ret.postop.type != "body"))
                {
                    foreach (arg; ret.parent.arguments[ret.index+1..$])
                    {
                        if (arg.postop !is null && arg.postop.type == "body")
                        {
                            if (arg.index + arg.postop.index + 1 <= ret.index)
                                ret = arg;
                            break;
                        }
                    }
                }
                return ret;
            }
            ret = ret.parent;
        }
        return null;
    }

    bool parentOf(Expression expr, Expression parent)
    {
        bool body_was = false;
        Expression ret = expr.parent;
        while (ret !is null)
        {
            if (ret.type == "body" || ret.type == "root" || ret.type == "module" || ret.bt == BlockType.File)
            {
                if (!body_was) body_was = true;
                else return false;
            }

            if (ret is parent)
            {
                return true;
            }
            ret = ret.parent;
        }
        return false;
    }

    bool isNeedHide(Expression expr)
    {
        return expr.level > 0 && expr.index >= 0 && (expr.type == "." || expr.type == "[" || expr.type == "\"" ||
                (expr.operator.length > 0 && !"-+!&*".find(expr.operator).empty && expr.arguments.length == 1));
    }

    void hideRecursive(Expression[] expressions)
    {
        foreach(expr; expressions)
        {
            expr.hidden = true;
            hideRecursive(expr.arguments);
            if (expr.postop !is null)
                hideRecursive([expr.postop]);
        }
    }

    void normAngle(ref real angle)
    {
        while (angle < 0) angle += 360;
        while (angle > 360) angle -= 360;
    }

    DrawState drawAll(ref Scoped!Context cr, Expression[] expressions, DrawState ds)
    {
        DrawState ret = ds;

        real sumpw = 0;
        foreach(expr; expressions)
        {
            real R1 = (expr.r1+expr.d1)/2;
            real R2 = (expr.r2+expr.d2)/2;
            real Y1 = expr.y + (expr.r1-expr.d1)/2;
            real Y2 = expr.y + (expr.r2-expr.d2)/2;

            real clickR1 = hypot(clickRX-expr.x, clickRY-Y1);
            real clickR2 = hypot(clickRX-expr.x, clickRY-Y2);

            real clickA1 = 360 - (atan2(clickRY-Y1, clickRX-expr.x)*180/PI + 90);
            real clickA2 = 360 - (atan2(clickRY-Y2, clickRX-expr.x)*180/PI + 90);

            if (clickA1 < 0) clickA1 += 360;
            if (clickA1 > 360) clickA1 -= 360;

            if (clickA2 < 0) clickA2 += 360;
            if (clickA2 > 360) clickA2 -= 360;

            if (!ds.force && inBody(expr) !is null)
            {
                bool po;
                foreach (ri; rot_info)
                {
                    auto f = parentOfFun(ri.fun);
                    if (f !is null && parentOf(expr, f))
                    {
                        po = true;
                        break;
                    }
                }
                if (!po)
                {
                    expr.hidden = true;
                    hideRecursive(expr.arguments);
                    if (expr.postop !is null)
                        hideRecursive([expr.postop]);
                    continue;
                }
            }

            /*if (parentOf(expr, rotfun))
                ds.hide = true;
            else if (ds.hide && parentOfStruct(expr) !is parentOfStruct(rotfun))
                continue;*/

            if (!(expr.type == "body"))
            if (ds.mode == Mode.Block)
            {
                /*cr.moveTo(dx[ds.line]+ds.x+ds.r, dy+ds.y-25);
                cr.lineTo(dx[ds.line]+ds.x+ds.r, dy+ds.y+25);
                cr.moveTo(dx[ds.line]+ds.x+ds.r+30, dy+ds.y-25);
                cr.lineTo(dx[ds.line]+ds.x+ds.r+30, dy+ds.y+25);
                cr.stroke();*/

                //writefln("%s. %s#%s r3=%s, levels=%s", expr.block, expr.operator, expr.type, expr.r3, expr.center.levels);
                ds.x += ds.r + expr.r3 + 30;

                //writefln("%sx%s. (+%s+%s) %s#%s", ds.x, ds.y, ds.r, expr.r3, expr.operator, expr.type);
                ds.r = 0;

                if (!ds.force)
                {
                    if (expr.parent !is null && expr.parent.type == "body" && expr.index == 0)
                    { 
                        foreach (ri; rot_info)
                        {
                            if (expr.parent.parent is parentOfFun(ri.fun))
                            {
                                if (rlines.length < ds.line+1) rlines ~= 0.0;
                                ds.y += 150 + max(rlines[ds.line], 50);
                                ds.x = 0;
                                ds.line++;
                                while (dx.length <= ds.line)
                                {
                                    dx ~= 150;
                                }
                                break;
                            }
                        }
                    }
                    else if (expr.parent !is null && (expr.parent.type == "module" || expr.parent.bt == BlockType.File) && expr.index == 0)
                    { 
                        foreach (ri; rot_info)
                        {
                            if (expr.parent is parentOfFun(ri.fun))
                            {
                                if (rlines.length < ds.line+1) rlines ~= 0.0;
                                ds.y += 150 + max(rlines[ds.line], 50);
                                ds.x = 0;
                                ds.line++;
                                while (dx.length <= ds.line)
                                {
                                    dx ~= 150;
                                }
                                break;
                            }
                        }
                    }
                }

                if (ds.line == ds.hideline)
                {
                    expr.hidden = true;
                    hideRecursive(expr.arguments);
                    if (expr.postop !is null)
                        hideRecursive([expr.postop]);
                    continue;
                }
            }

            if (!ds.force)
            {
                expr.x = ds.x + dx[ds.line];
                expr.y = ds.y + dy;
            }
            else
            {
                expr.x = 150;
                expr.y = 150;
            }
            expr.line = ds.line;

            expr.hidden = ((expr.type == "body" || expr.type == "root") && !expr.arguments.empty);
            if (!(expr.hidden || isNeedHide(expr) && !expr.arguments.empty) && (ds.sizes_invalid > 1 || selected.center is expr.center))
            {
                cr.save();
                    bool invert;
                    if (!ds.force)
                    {
                        foreach (ri; rot_info)
                        {
                            if (expr is ri.fun ||
                                    (ri.fun.hidden || isNeedHide(ri.fun) && !ri.fun.arguments.empty) && parentOf(expr, ri.fun) && expr.x == ri.fun.x && expr.y == ri.fun.y && expr.r1 == ri.fun.r1)
                            {
                                invert = true;
                                break;
                            }
                        }
                    }
                    else
                    {
                        if (expr is frot_info.fun)
                        {
                            invert = true;
                        }
                    }

                    string text = (expr.index < 0 ? "." : "") ~ (expr.operator.empty ? expr.type : expr.operator) ~ (expr.arguments.empty && expr.arguments !is null ? "()" : "");
                    if (expr.bt == BlockType.File && expr.type == "*")
                        text = text ~ " *";

                    Color col = Color(0.0, 0.0, 0.0, 1.0);
                    long p0 = 0;
                    long p1 = -1;
                    if (expr.operator.empty) col = Color(0.0, 0.0, 0.5, 1.0);

                    auto ex = expr;
                    auto parent = ex.parent;
                    bool first = true;
                    bool last = true;
                    ubyte[] colors = (cast(ubyte)0).repeat(text.walkLength).array;
                    
                    if (text.empty)
                    {
                        text = ".";
                        colors = [2];
                    }

                    if (!ds.force)
                    while (parent !is null && isNeedHide(parent))
                    {
                        ubyte selcol = 1;
                        foreach (ri; rot_info)
                        {
                            if (parent is ri.fun)
                            {
                                selcol = 2;
                                break;
                            }
                        }
                        if (parent.type == "." && first && ex.index > 0 && (!text.empty && text[0] != '[' && text[0] != ']' || selcol == 2))
                        {
                            text = "."~text;
                            colors = [selcol] ~ colors;
                        }

                        first = first && (ex.index == 0);
                        last = last && (ex.index == parent.arguments.length-1);
                        
                        if (parent.operator.length > 0 && !"-+!&*".find(parent.operator).empty && parent.arguments.length == 1 && first)
                        {
                            if (parent.type == "post")
                            {
                                text = text ~ parent.operator;
                                colors = colors ~ selcol.repeat(parent.operator.length).array;
                            }
                            else
                            {
                                text = parent.operator~text;
                                colors = selcol.repeat(parent.operator.length).array ~ colors;
                            }
                        }
                        if (parent.type == "[" && first)
                        {
                            text = "["~text;
                            colors = [selcol] ~ colors;
                        }
                        if (parent.type == "[" && last)
                        {
                            text = text~"]";
                            colors = colors ~ [selcol];
                        }
                        if (parent.type == "\"" && first)
                        {
                            text = "\""~text;
                            colors = [selcol] ~ colors;
                        }
                        if (parent.type == "\"" && last)
                        {
                            text = text~"\"";
                            colors = colors ~ [selcol];
                        }

                        ex = parent;
                        parent = ex.parent;

                        if (ex is selected && expr.a2-expr.a1 < 359)
                        {
                            //writefln("%s.%s %s#%s", ex.block, ex.level, ex.operator, ex.type);
                            ex.arat = ex.center.mw[ex.level];
                            ex.brat = pow(180.0, 1.0-ex.arat);
                            foreground ~= ex;
                        }
                    }

                    bool lines = true;
                    if (ex !is expr)
                    {
                        expr.c = ex.c;
                        lines = false;
                    }

                    real rot = 0;
                    if (!ds.force)
                    {
                        foreach (ri; rot_info)
                        {
                            if (expr.center is ri.fun.center && expr.block == ri.fun.block)
                            {
                                rot = ri.angle;
                                break;
                            }
                        }
                    }
                    else
                    {
                        rot = frot_info.angle;
                    }

                //writefln("DRAW lev %s %s#%s. %s-%s %s-%s %sx%s", expr.level, expr.operator, expr.type, expr.a1, expr.a2, expr.r1, expr.r2, expr.x, expr.y);
                    assert(!expr.r1.isNaN);
                    assert(!expr.r2.isNaN);
                    assert(!expr.x.isNaN);
                    assert(!expr.y.isNaN);
                    assert(!expr.a1.isNaN);
                    assert(!expr.a2.isNaN);
                    assert(expr.r2 > expr.r1);
                    assert(expr.a2 >= expr.a1);

                    real a1 = expr.a1;
                    real a2 = expr.a2;
                    if (invert && a2-a1 < 359)
                    {
                        //writefln("%s.%s %s#%s", expr.block, expr.level, expr.operator, expr.type);
                        expr.arat = expr.center.mw[expr.level];
                        expr.brat = pow(180.0, 1.0-expr.arat);
                        foreground ~= expr;
                    }
                    
                    foreach(exp; oforeground)
                    {
                        if (exp.center is expr.center)
                        {
                            real mid = (exp.a1+exp.a2)/2;
                            //writefln("%s.%s %s#%s %s", expr.block, expr.level, expr.operator, expr.type, a2 - a1);
                            if (a1 > mid - 180 && a1 < mid || a1 > mid+180)
                            {
                                a1 = 180-(mid - a1);
                            //writefln("-1. %s#%s a1=%s | %s", expr.operator, expr.type, a1, mid);
                                normAngle(a1);
                            //writefln("-2. %s#%s a1=%s | %s | %s/%s", expr.operator, expr.type, a1, mid, fa1, ea1);
                                a1 = exp.brat * pow(a1, exp.arat);
                                if (a1.isNaN || a1 > 3600) a1 = 0;
                                a1 = mid-(180 - a1);
                                normAngle(a1);
                            }
                            else
                            {
                                a1 = 360 - a1;
                                mid = 360 - mid;

                                a1 = 180-(mid - a1);
                            //writefln("1. %s#%s a1=%s | %s", expr.operator, expr.type, a1, mid);

                                normAngle(a1);
                            //writefln("2. %s#%s a1=%s | %s | %s/%s", expr.operator, expr.type, a1, mid, fa2, ea2);

                                a1 = exp.brat * pow(a1, exp.arat);
                                if (a1.isNaN || a1 > 3600) a1 = 0;
                                a1 = mid - (180-a1);
                                a1 = 360 - a1;
                                normAngle(a1);
                                mid = 360 - mid;
                            }

                            if (a2 > mid - 180 && a2 < mid || a2 > mid+180)
                            {
                                a2 = 180-(mid - a2);
                            //writefln("-1. %s#%s a2=%s | %s", expr.operator, expr.type, a2, mid);
                                normAngle(a2);
                            //writefln("-2. %s#%s a2=%s | %s | %s/%s", expr.operator, expr.type, a2, mid, fa1, ea1);
                                a2 = exp.brat * pow(a2, exp.arat);
                                if (a2.isNaN || a2 > 3600) a2 = 0;
                                a2 = mid-(180 - a2);
                                normAngle(a2);
                            }
                            else
                            {
                                a2 = 360 - a2;
                                mid = 360 - mid;

                                a2 = 180-(mid - a2);
                            //writefln("1. %s#%s a2=%s | %s | %s/%s", expr.operator, expr.type, a2, mid, fa2, ea2);

                                normAngle(a2);
                            //writefln("2. %s#%s a2=%s | %s | %s/%s", expr.operator, expr.type, a2, mid, fa2, ea2);

                                a2 = exp.brat * pow(a2, exp.arat);
                                if (a2.isNaN || a2 > 3600) a2 = 0;
                                a2 = mid - (180-a2);
                                a2 = 360 - a2;
                                normAngle(a2);
                                mid = 360 - mid;
                            }

                            while (a2 < a1 || abs(a1 - a2) < 1 && expr.a2-expr.a1 > 359) a2 += 360;
                            //writefln("%s#%s %s-%s => %s-%s | %s", expr.operator, expr.type,
                            //        expr.a1, expr.a2, a1, a2, mid);
                            break;
                        }
                    }

                    //if (ds.force)
                    //    writefln("%s %s-%s => %s-%s", expr, expr.a1, expr.a2, a1, a2);
                    if (a2 > a1+1)
                    {
                        a1 -= rot;
                        a2 -= rot;
                        auto A1 = a1;
                        auto A2 = a2;
                        normAngle(A1);
                        normAngle(A2);

                        /*if (!click_processed && clickR1 > R1 && clickR2 < R2)
                        {
                            writefln("%s#%s", expr.operator, expr.type);
                            writefln("%s-%s, %s-%s", a1, a2, clickA1, clickA2);
                        }*/

                        if (!click_processed && clickA1 > A1 && clickA1 < A2 &&
                                clickA2 > A1 && clickA2 < A2 &&
                                clickR1 > R1 && clickR2 < R2)
                        {
                            click_processed = true;
                            selected = expr;
                            updateView();
                            //writefln("%s#%s", expr.operator, expr.type);
                        }

                        drawArc(cr, 360-a2, 360-a1, expr.r1, expr.r2, expr.d1, expr.d2, expr.x, expr.y, expr.c, invert, lines);
                        real r = (expr.r1+expr.r2+expr.d1+expr.d2)/4;
                        real dr1 = (expr.r2-expr.r1);
                        real dr2 = (expr.d2-expr.d1);
                        assert(r > 0);
                        assert(dr1 > 0);
                        assert(dr2 > 0);
                        real Y = expr.y + (expr.r1+expr.r2-expr.d1-expr.d2)/4;
                        if (a2 > a1+10)
                            drawArcText(cr, text, 360-a1, 360-a2, r, dr1, dr2, expr.x, Y, col, invert, colors);
                    }

                    if (expr.r1 == 0 && !expr.label.empty)
                    {
                        drawText(cr, "@"~expr.label, expr.x, expr.y+expr.r3+15, 2*expr.r3, col);
                    }

                cr.restore();
            }

            DrawState ds2 = ds;

            if (expr.type == "root" || expr.type == "module" || expr.bt == BlockType.File || expr.type == "body")
                ds2.mode = Mode.Block;
            else
                ds2.mode = Mode.Circle;

            ds2 = drawAll(cr, cast(Expression[]) expr.arguments, ds2);
            if (expr.postop !is null)
                ds2 = drawAll(cr, cast(Expression[]) [expr.postop], ds2);

            if (ds2.hide)
                ds.hide = ret.hide = true;
            ds.hideline = ret.hideline = ds2.hideline;

            ds.r = ret.r = max(ds.r, expr.r3);
        }

        return ret;
    }

    Button[] getSymbols(Expression expr)
    {
        if (expr.parent is null) return [];

        Button[] ret = [];

        if (expr.parent.type == "body")
        {
            foreach (ex; expr.parent.arguments[0..expr.index])
            {
                if (ex.operator == "=" && !ex.arguments.empty && ex.arguments[0].arguments.length == 1)
                {
                    ret ~= Button(ex.arguments[0].operator, typeColor(ex.arguments[0].type), ex.arguments[0].arguments[0].operator, ex.arguments[0]);
                }
                else if (ex.type == "var" && !ex.operator.empty && ex.arguments.length == 1)
                {
                    ret ~= Button(ex.operator, typeColor(ex.type), ex.arguments[0].operator, ex);
                }
            }
        }
        else if (expr.parent.type == "struct" || expr.parent.type == "class" || expr.parent.type == "root" || expr.parent.type == "module" || expr.parent.bt == BlockType.File)
        {
            foreach (ex; expr.parent.arguments)
            {
                if (!ex.operator.empty && ex.arguments.length >= 1)
                {
                    if (ex.type == "struct" || ex.type == "class" || ex.type == "root" || ex.type == "module" || ex.bt == BlockType.File || ex.type == "enum")
                        ret ~= Button(ex.operator, typeColor(ex.type), ex.type, ex);
                    else
                        ret ~= Button(ex.operator, typeColor(ex.type), ex.arguments[0].operator, ex);
                }
                else if (ex.type == "import")
                {
                    auto imp = ex.arguments[0].operator;
                    foreach (mod; root_expr.arguments)
                    {
                        if (mod.operator == imp)
                        {
                            foreach (modarg; mod.arguments)
                            {
                                if (!modarg.operator.empty && modarg.arguments.length >= 1)
                                {
                                    if (modarg.type == "struct" || modarg.type == "class" || modarg.type == "root" || modarg.type == "module" || modarg.bt == BlockType.File || modarg.type == "enum")
                                        ret ~= Button(modarg.operator, typeColor(modarg.type), modarg.type, modarg);
                                    else
                                        ret ~= Button(modarg.operator, typeColor(modarg.type), modarg.arguments[0].operator, modarg);
                                }
                            }

                            ret ~= Button("", Color(1.0, 1.0, 1.0, 1.0), null);
                        }
                    }
                }
            }
        }
        else if (expr.parent.type == "function")
        {
            if (expr.parent.arguments.length > 1)
            foreach (ex; expr.parent.arguments[1..$])
            {
                if (!ex.operator.empty && ex.arguments.length >= 1)
                    ret ~= Button(ex.operator, typeColor(ex.type), ex.arguments[0].operator, ex);
            }
        }

        if (!ret.empty) ret = [ Button("", Color(1.0, 1.0, 1.0, 1.0), null) ] ~ ret;
        return getSymbols(expr.parent) ~ ret;
    }

    Expression[] getFieldsType(string type, Button[] symbols, Expression[] fsel, Expression parent, int level = 1)
    {
        Expression[] ret;
        if (level > 2 && fsel.empty) return ret;

        foreach (ref sym; symbols)
        {
            if (type == sym.text)
            {
                if (sym.expr !is null && (sym.expr.type != "enum" || level == 1))
                {
                    foreach (arg; sym.expr.arguments)
                    {
                        Expression expr = new Expression;
                        expr.operator = arg.operator;
                        expr.parent = parent;
                        expr.index = ret.length;

                        bool sel;
                        if (level < fsel.length && fsel[level].operator == arg.operator)
                        {
                            sel = true;
                            fselected = expr;
                        }

                        if (arg.arguments.length > 0)
                        {
                            expr.arguments = getFieldsType(arg.arguments[0].operator, symbols, sel ? fsel : [], expr, level + 1);
                        }
                        ret ~= expr;
                    }
                }
            }
        }
        //writefln("%s ~ %s", type, ret);

        return ret;
    }

    Expression getFields(string var, Button[] symbols, Expression[] fsel)
    {
        Expression expr = new Expression;
        expr.operator = var;

        fselected = expr;

        foreach (ref sym; symbols)
        {
            if (var == sym.text)
            {
                if (sym.type == "enum")
                    expr.arguments = getFieldsType(sym.text, symbols, fsel, expr);
                else
                    expr.arguments = getFieldsType(sym.type, symbols, fsel, expr);
            }
        }
        //writefln("%s", expr);

        return expr;
    }

	//Override default signal handler:
	bool drawCallback(Scoped!Context cr, Widget widget)
	{
		// This is where we draw on the window

        if ( m_timeout is null )
        {
            foreach (ri; rot_info)
            {
                if (ri.target_angle != ri.angle)
                {
                    //Create a new timeout that will ask the window to be drawn once every second.
                    m_timeout = new Timeout( 100, &onSecondElapsed, false );
                    break;
                }
            }
        }
        else
        {
            bool redraw_need;
            foreach (ri; rot_info)
            {
                if (ri.target_angle != ri.angle)
                {
                    redraw_need = true;
                    break;
                }
            }
            if (!redraw_need)
            {
                m_timeout.stop();
                m_timeout = null;
            }
        }

		GtkAllocation size;

		getAllocation(size);

        GdkRectangle rect;
        bool exist = cr.getClipRectangle(rect);
        int sizesInvalid = sizes_invalid;

        if (!(rect.x == 0 && rect.width < size.width) || rect.width > size.width/6)
        {
            //writefln("Redraw View %sx%s size %sx%s", rect.x, rect.y, rect.width, rect.height);
            real min_x=real.max;
            real min_y=real.max;
            real max_x=-real.max;
            real max_y=-real.max;

            getSize([root_expr], DrawState.init);
            sizes_invalid = 0;

            if (rect.width == size.width && rect.height == size.height)
                sizesInvalid = 2;

            real w;
            real h;

            min_x = sx1;
            min_y = sy1;
            max_x = sx2;
            max_y = sy2;

            w = max_x - min_x;
            h = max_y - min_y;

            size.width = size.width*5/6;

            /*if (w/size.width > h/size.height)
            {
                max_y += (w*size.height/size.width - h);
                h = w*size.height/size.width;
                sy2 = h;
            }
            else*/
            {
                max_x += (h*size.width/size.height - w);
                w = h*size.width/size.height;
                sx2 = w;
            }

            clickRX = (clickX - size.width/5.0) * w/size.width + min_x;
            clickRY = clickY * h/size.height + min_y;

            cr.save();
            cr.scale(size.width/w, size.height/h);
            cr.translate(-min_x + w/5.0, -min_y);
            cr.setLineWidth(m_lineWidth);

            cr.rectangle(0, 0, sx2, sy2);
            cr.clip();

            Color c = Color(0.9, 0.9, 0.9, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.paint();

            Color black = Color(0, 0, 0.0, 1.0);
            cr.setSourceRgba(black.r, black.g, black.b, black.a);

            DrawState ds;
            ds.sizes_invalid = sizesInvalid;

            if (dx.empty)
                dx ~= 150;

            oforeground = foreground;
            foreground = [];
            drawAll(cr, [root_expr], ds);
            cr.restore();

            bool redraw_need = false;
            foreach (ref ri; rot_info)
            {
                if (ri.target_angle != ri.angle)
                {
                    //writefln("target %s rot %s", ri.target_angle, ri.angle);
                    //writefln("%s + %s", 0.8*target_angle, 0.2*rot_angle);
                    real adiff = ri.angle - ri.target_angle;
                    
                    while (adiff > 180)
                    {
                        ri.angle -= 360;
                        adiff -= 360;
                    }

                    while (adiff < -180)
                    {
                        ri.angle += 360;
                        adiff += 360;
                    }

                    if (abs(ri.target_angle - ri.angle) < 10)
                        ri.angle = ri.target_angle;
                    else
                        ri.angle = 0.6*ri.target_angle + 0.4*ri.angle;
                    //writefln("=rot %s", ri.angle);
                    
                    redraw_need = true;
                }
            }

            if (frot_info.target_angle != frot_info.angle)
            {
                //writefln("target %s rot %s", frot_info.target_angle, frot_info.angle);
                //writefln("%s + %s", 0.8*target_angle, 0.2*rot_angle);
                real adiff = frot_info.angle - frot_info.target_angle;
                
                while (adiff > 180)
                {
                    frot_info.angle -= 360;
                    adiff -= 360;
                }

                while (adiff < -180)
                {
                    frot_info.angle += 360;
                    adiff += 360;
                }

                if (abs(frot_info.target_angle - frot_info.angle) < 10)
                    frot_info.angle = frot_info.target_angle;
                else
                    frot_info.angle = 0.6*frot_info.target_angle + 0.4*frot_info.angle;
                //writefln("=rot %s", frot_info.angle);
                
                redraw_need = true;
            }

            if (selected.x < 150)
            {
                redraw_need = true;
                dx[selected.line] += 150 - selected.x;
            }
            else if (selected.x > sx2-150)
            {
                redraw_need = true;
                dx[selected.line] -= selected.x - (sx2-150);
            }

            if (selected.y < 150)
            {
                redraw_need = true;
                dy += 150 - selected.y;
            }
            else if (selected.y > sy2-300)
            {
                redraw_need = true;
                dy -= selected.y - (sy2-300);
            }

            if (redraw_need)
                redraw();
        }

        if (rect.x == 0)
        {
            //writefln("Redraw Navigation %sx%s size %sx%s", rect.x, rect.y, rect.width, rect.height);
            cr.save();

            size.width /= 5;
            real w = 200;
            real h = w*size.height/size.width;
            
            cr.scale(size.width/w, size.height/h);
            cr.setLineWidth(m_lineWidth);

            cr.rectangle(0, 0, w, h);
            cr.clip();

            Color c = Color(0.9, 0.9, 1.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.paint();

            c = Color(0.5, 0.5, 1.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.moveTo(100, 0);
            cr.lineTo(200, 50);
            cr.lineTo(100, 100);
            cr.lineTo(0, 50);
            cr.closePath();
            cr.fill();

            c = Color(1.0, 1.0, 1.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.rectangle(50, 25, 100, 50);
            cr.fill();

            c = Color(0.0, 0.0, 0.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);

            cr.rectangle(50, 25, 50, 25);
            cr.stroke();
            drawText(cr, ".", 75, 37.5, 50, c);

            cr.rectangle(100, 25, 50, 25);
            cr.stroke();
            drawText(cr, "+", 125, 37.5, 50, c);

            cr.rectangle(50, 50, 50, 25);
            cr.stroke();
            drawText(cr, ",", 75, 62.5, 50, c);

            cr.rectangle(100, 50, 25, 25);
            cr.stroke();
            drawText(cr, "<", 112.5, 62.5, 25, c);

            cr.rectangle(125, 50, 25, 25);
            cr.stroke();
            drawText(cr, ">", 137.5, 62.5, 25, c);

            real y = 125;
            real x = 5;

            c = Color(1.0, 1.0, 1.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.rectangle(x, y, 190, 20);
            cr.fill();

            c = Color(0.0, 0.0, 0.0, 1.0);
            cr.setSourceRgba(c.r, c.g, c.b, c.a);
            cr.rectangle(x, y, 190, 20);
            cr.stroke();
            drawText(cr, selected.text, x+(190)/2, y+10, 180, c);

            x = 5;
            y += 35;

            Button[] buttons;
            if (selected.parent !is null && (selected.parent.type == "body" || selected.parent.type == "root" || selected.parent.type == "module" || selected.parent.bt == BlockType.File || selected.parent.type == "struct" || selected.parent.type == "class"))
            {
                foreach (type; ["import", "class", "struct", "function", "enum", "var"])
                    buttons ~= [Button("#"~type, typeColor(type), null)];
            }
              
            if (selected.parent !is null && selected.parent.type == "body")
            {
                buttons ~= [ Button("", c, null) ];
                foreach (type; ["if", "switch", "for", "foreach", "while", "do", "return"])
                    buttons ~= [Button("#"~type, typeColor(type), null)];
            }

            static Button[] symbols;
            Expression sel;
            Expression[] fsel;
            if (sizesInvalid > 0 || selected !is oselected)
            {
                sel = selected;
                fsel = [selected];
                if (sel.parent !is null && sel.parent.type == ".") sel = sel.parent;
                if (sel.type == "." && !sel.arguments.empty)
                {
                    fsel = sel.arguments;
                    sel = sel.arguments[0];
                }

                symbols = getSymbols(sel);
            }
            buttons ~= symbols;

            cr.rectangle(0, y, w, h-y);
            cr.clip();
            cr.translate(0, scrollY);
            foreach(but; buttons)
            {
                if (but.text.empty)
                {
                    x = 5;
                    y += 35;
                    continue;
                }

                real wi = textWidth(but.text);
                if (x+wi > 200)
                {
                    x = 5;
                    y += 25;
                }

                c = but.c;
                cr.setSourceRgba(c.r, c.g, c.b, c.a);
                cr.rectangle(x, y, wi+5, 20);
                cr.fill();

                c = Color(0.0, 0.0, 0.0, 1.0);
                cr.setSourceRgba(c.r, c.g, c.b, c.a);
                cr.rectangle(x, y, wi+5, 20);
                cr.stroke();
                drawText(cr, but.text, x+(wi+5)/2, y+10, wi+5, c);

                x += wi + 10;
            }

            cr.restore();

            if (sizesInvalid > 0 || selected !is oselected)
            {
                fields = getFields(sel.operator, symbols, fsel);
                oselected = selected;
                ofunselected = parentOfFun(oselected);

                auto ds = DrawState.init;
                ds.force = true;
                getSize([fields], ds);

                auto expr = fselected;
                double nr = (expr.a1 + expr.a2)/2 - 180;
                if (nr < 0) nr += 360;

                frot_info.target_angle = nr;
                frot_info.fun = expr;
            }

            if (!fields.arguments.empty)
            {
                cr.save();

                cr.translate(0, size.height - size.width);
                cr.scale(size.width/w, size.height/h);
                cr.scale(2.0/3, 2.0/3);
                cr.setLineWidth(m_lineWidth);

                cr.rectangle(0, 0, 300, 300);
                cr.clip();

                c = Color(0.9, 0.9, 1.0, 1.0);
                cr.setSourceRgba(c.r, c.g, c.b, c.a);
                cr.paint();

                c = Color(0.0, 0.0, 0.0, 1.0);
                cr.setSourceRgba(c.r, c.g, c.b, c.a);
                cr.rectangle(0, 0, 300, 300);
                cr.stroke();

                auto ds = DrawState.init;
                ds.force = true;
                ds.sizes_invalid = 2;
                drawAll(cr, [fields], ds);

                cr.restore();
            }
        }

        /*if (selected.parent !is null)
        writefln("%s#%s %s %s", selected.parent.operator, selected.parent.type,
                selected.parent.r3, (selected.parent.x2-selected.parent.x1)/(2*PI));
                */

		return true;
	}

    bool onSecondElapsed()
    {
        redraw();
        return true;
    }

	double m_radius = 0.40;
	double m_lineWidth = 1.0;
    RotInfo[] rot_info;
    RotInfo frot_info;
    Expression[] foreground, oforeground;
    real[] dx;
    real dy = 0;
    real[] rlines;
    int sizes_invalid = 1;

	Timeout m_timeout;
}

