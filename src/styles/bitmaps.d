module styles.bitmaps;

import std.bitmanip;
import std.string;
import common;
import styles.common;
import styles.all;
import std.ascii : toUpper;

BitArray[] style_rules;

void init_map(string field)(shared StyleDefinition *def) pure nothrow
{
    bool[] map = new bool[mixin(field~".length")];
    
    foreach(s; mixin("def."~field))
    {
        map[s] = true;
    }

    mixin("def.maps."~field) = shared BitArray(map);
}

void init_maps()
{
    style_rules = new BitArray[rules.length];

    bool[][] maps = new bool[][](rules.length, Style.Unknown);
    
    foreach (style, def; styledefs)
    {
        init_map!("rules")(def);
        init_map!("comments")(def);
        init_map!("string_literals")(def);
        init_map!("argument_delimiters")(def);
        init_map!("statement_delimiters")(def);
        init_map!("statement_brackets")(def);
        init_map!("field_access_symbols")(def);

        foreach (r; def.rules)
        {
            maps[r][style] = true;
        }
    }
    
    foreach(r, map; maps)
    {
        style_rules[r] = BitArray(map);
    }
}

