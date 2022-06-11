module color;

import std.algorithm.comparison;

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

