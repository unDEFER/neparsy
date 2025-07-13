module styles.all;

import common;
import styles.common;
import styles.c;
import styles.d;
import styles.rust;

shared StyleDefinition*[Style] styledefs =
[
    Style.D: &DDefinition
];

enum Rule[] rules =
[
    ClikeFor,
    DModule
];
