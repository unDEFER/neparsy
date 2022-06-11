module ifacenode;

import color;
import expression;

struct IfaceNode
{
    real x = 0, y = 0;
    real r1, r2, r3;
    real d1, d2;
    real a1, a2;
    real arat;
    real brat;
    real[] pw, mw;
    Color c;
    int line;
    int block, level, levels;
    Expression center;
    bool hidden;
    size_t focus;
}

