namespace Singularity.Apps.Formula {

    public class Symbol {
        public string command;
        public string ch;
        public AtomClass cls;
        public string category;
        public string name;
        public bool largeop;
        public bool limits;

        public Symbol (string command, string ch, AtomClass cls, string category, string name, bool largeop = false, bool limits = false) {
            this.command = command;
            this.ch = ch;
            this.cls = cls;
            this.category = category;
            this.name = name;
            this.largeop = largeop;
            this.limits = limits;
        }
    }

    public class AccentInfo {
        public string command;
        public string mark;
        public bool stretchy;
        public bool under;
        public string name;

        public AccentInfo (string command, string mark, bool stretchy, bool under, string name) {
            this.command = command;
            this.mark = mark;
            this.stretchy = stretchy;
            this.under = under;
            this.name = name;
        }
    }

    public class Symbols {
        private static Gee.HashMap<string, Symbol>? commands;
        private static Gee.HashMap<string, Symbol>? chars;
        private static Gee.ArrayList<Symbol>? all_list;
        private static Gee.HashMap<string, AccentInfo>? accents;
        private static Gee.HashMap<string, AccentInfo>? accent_marks;
        private static Gee.ArrayList<AccentInfo>? accent_list;
        private static Gee.HashMap<string, string>? delimiters;
        private static Gee.HashMap<string, string>? delimiter_names;
        private static Gee.HashSet<string>? functions;
        private static Gee.HashSet<string>? limit_functions;

        public const string[] FUNCTION_NAMES = {
            "sin", "cos", "tan", "cot", "sec", "csc", "arcsin", "arccos", "arctan", "arccot", "arcsec", "arccsc",
            "sinh", "cosh", "tanh", "coth", "sech", "csch", "arsinh", "arcosh", "artanh",
            "log", "ln", "lg", "exp", "det", "dim", "ker", "hom", "deg", "arg", "gcd", "lcm",
            "max", "min", "sup", "inf", "lim", "liminf", "limsup", "Pr", "sgn", "tr", "rank", "mod"
        };

        public const string[] LIMIT_FUNCTION_NAMES = { "lim", "liminf", "limsup", "max", "min", "sup", "inf", "det", "gcd", "lcm", "Pr" };

        private const string[] TABLE = {
            "alpha", "03b1", "o", "greek", "alpha",
            "beta", "03b2", "o", "greek", "beta",
            "gamma", "03b3", "o", "greek", "gamma",
            "delta", "03b4", "o", "greek", "delta",
            "epsilon", "03f5", "o", "greek", "epsilon",
            "varepsilon", "03b5", "o", "greek", "epsilon variant",
            "zeta", "03b6", "o", "greek", "zeta",
            "eta", "03b7", "o", "greek", "eta",
            "theta", "03b8", "o", "greek", "theta",
            "vartheta", "03d1", "o", "greek", "theta variant",
            "iota", "03b9", "o", "greek", "iota",
            "kappa", "03ba", "o", "greek", "kappa",
            "varkappa", "03f0", "o", "greek", "kappa variant",
            "lambda", "03bb", "o", "greek", "lambda",
            "mu", "03bc", "o", "greek", "mu",
            "nu", "03bd", "o", "greek", "nu",
            "xi", "03be", "o", "greek", "xi",
            "omicron", "03bf", "o", "greek", "omicron",
            "pi", "03c0", "o", "greek", "pi",
            "varpi", "03d6", "o", "greek", "pi variant",
            "rho", "03c1", "o", "greek", "rho",
            "varrho", "03f1", "o", "greek", "rho variant",
            "sigma", "03c3", "o", "greek", "sigma",
            "varsigma", "03c2", "o", "greek", "final sigma",
            "tau", "03c4", "o", "greek", "tau",
            "upsilon", "03c5", "o", "greek", "upsilon",
            "phi", "03d5", "o", "greek", "phi",
            "varphi", "03c6", "o", "greek", "phi variant",
            "chi", "03c7", "o", "greek", "chi",
            "psi", "03c8", "o", "greek", "psi",
            "omega", "03c9", "o", "greek", "omega",
            "Gamma", "0393", "o", "greek", "capital gamma",
            "Delta", "0394", "o", "greek", "capital delta",
            "Theta", "0398", "o", "greek", "capital theta",
            "Lambda", "039b", "o", "greek", "capital lambda",
            "Xi", "039e", "o", "greek", "capital xi",
            "Pi", "03a0", "o", "greek", "capital pi",
            "Sigma", "03a3", "o", "greek", "capital sigma",
            "Upsilon", "03a5", "o", "greek", "capital upsilon",
            "Phi", "03a6", "o", "greek", "capital phi",
            "Psi", "03a8", "o", "greek", "capital psi",
            "Omega", "03a9", "o", "greek", "capital omega",
            "digamma", "03dd", "o", "greek", "digamma",

            "pm", "00b1", "b", "operators", "plus minus",
            "mp", "2213", "b", "operators", "minus plus",
            "times", "00d7", "b", "operators", "times",
            "div", "00f7", "b", "operators", "division",
            "cdot", "22c5", "b", "operators", "dot",
            "ast", "2217", "b", "operators", "asterisk",
            "star", "22c6", "b", "operators", "star",
            "circ", "2218", "b", "operators", "ring operator",
            "bullet", "2219", "b", "operators", "bullet",
            "oplus", "2295", "b", "operators", "circled plus",
            "ominus", "2296", "b", "operators", "circled minus",
            "otimes", "2297", "b", "operators", "circled times",
            "oslash", "2298", "b", "operators", "circled slash",
            "odot", "2299", "b", "operators", "circled dot",
            "setminus", "2216", "b", "sets", "set minus",
            "cap", "2229", "b", "sets", "intersection",
            "cup", "222a", "b", "sets", "union",
            "uplus", "228e", "b", "sets", "multiset union",
            "sqcap", "2293", "b", "sets", "square cap",
            "sqcup", "2294", "b", "sets", "square cup",
            "wedge", "2227", "b", "logic", "logical and",
            "land", "2227", "b", "logic", "logical and",
            "vee", "2228", "b", "logic", "logical or",
            "lor", "2228", "b", "logic", "logical or",
            "wr", "2240", "b", "operators", "wreath product",
            "diamond", "22c4", "b", "operators", "diamond",
            "bigtriangleup", "25b3", "b", "operators", "triangle up",
            "bigtriangledown", "25bd", "b", "operators", "triangle down",
            "triangleleft", "25c1", "b", "operators", "triangle left",
            "triangleright", "25b7", "b", "operators", "triangle right",
            "dagger", "2020", "b", "operators", "dagger",
            "ddagger", "2021", "b", "operators", "double dagger",
            "amalg", "2a3f", "b", "operators", "amalgamation",
            "dotplus", "2214", "b", "operators", "dot plus",
            "ltimes", "22c9", "b", "operators", "left semidirect product",
            "rtimes", "22ca", "b", "operators", "right semidirect product",

            "le", "2264", "r", "relations", "less than or equal",
            "leq", "2264", "r", "relations", "less than or equal",
            "ge", "2265", "r", "relations", "greater than or equal",
            "geq", "2265", "r", "relations", "greater than or equal",
            "neq", "2260", "r", "relations", "not equal",
            "ne", "2260", "r", "relations", "not equal",
            "leqslant", "2a7d", "r", "relations", "less than or slanted equal",
            "geqslant", "2a7e", "r", "relations", "greater than or slanted equal",
            "ll", "226a", "r", "relations", "much less than",
            "gg", "226b", "r", "relations", "much greater than",
            "approx", "2248", "r", "relations", "approximately equal",
            "sim", "223c", "r", "relations", "similar",
            "simeq", "2243", "r", "relations", "asymptotically equal",
            "cong", "2245", "r", "relations", "congruent",
            "equiv", "2261", "r", "relations", "identical",
            "propto", "221d", "r", "relations", "proportional",
            "asymp", "224d", "r", "relations", "equivalent",
            "doteq", "2250", "r", "relations", "approaches the limit",
            "triangleq", "225c", "r", "relations", "defined as",
            "coloneqq", "2254", "r", "relations", "colon equals",
            "lesssim", "2272", "r", "relations", "less than or equivalent",
            "gtrsim", "2273", "r", "relations", "greater than or equivalent",
            "prec", "227a", "r", "relations", "precedes",
            "succ", "227b", "r", "relations", "succeeds",
            "preceq", "2aaf", "r", "relations", "precedes or equal",
            "succeq", "2ab0", "r", "relations", "succeeds or equal",
            "perp", "22a5", "r", "relations", "perpendicular",
            "parallel", "2225", "r", "relations", "parallel",
            "mid", "2223", "r", "relations", "divides",
            "nmid", "2224", "r", "relations", "does not divide",
            "smile", "2323", "r", "relations", "smile",
            "frown", "2322", "r", "relations", "frown",
            "bowtie", "22c8", "r", "relations", "bowtie",
            "models", "22a8", "r", "logic", "models",
            "vdash", "22a2", "r", "logic", "proves",
            "dashv", "22a3", "r", "logic", "left tack",
            "in", "2208", "r", "sets", "element of",
            "notin", "2209", "r", "sets", "not an element of",
            "ni", "220b", "r", "sets", "contains as member",
            "subset", "2282", "r", "sets", "subset",
            "supset", "2283", "r", "sets", "superset",
            "subseteq", "2286", "r", "sets", "subset or equal",
            "supseteq", "2287", "r", "sets", "superset or equal",
            "subsetneq", "228a", "r", "sets", "proper subset",
            "supsetneq", "228b", "r", "sets", "proper superset",
            "nsubseteq", "2288", "r", "sets", "not a subset",
            "sqsubset", "228f", "r", "sets", "square subset",
            "sqsupset", "2290", "r", "sets", "square superset",
            "sqsubseteq", "2291", "r", "sets", "square subset or equal",
            "sqsupseteq", "2292", "r", "sets", "square superset or equal",
            "therefore", "2234", "r", "logic", "therefore",
            "because", "2235", "r", "logic", "because",

            "leftarrow", "2190", "r", "arrows", "left arrow",
            "gets", "2190", "r", "arrows", "left arrow",
            "rightarrow", "2192", "r", "arrows", "right arrow",
            "to", "2192", "r", "arrows", "right arrow",
            "leftrightarrow", "2194", "r", "arrows", "left right arrow",
            "uparrow", "2191", "r", "arrows", "up arrow",
            "downarrow", "2193", "r", "arrows", "down arrow",
            "updownarrow", "2195", "r", "arrows", "up down arrow",
            "Leftarrow", "21d0", "r", "arrows", "double left arrow",
            "Rightarrow", "21d2", "r", "arrows", "double right arrow",
            "Leftrightarrow", "21d4", "r", "arrows", "double left right arrow",
            "Uparrow", "21d1", "r", "arrows", "double up arrow",
            "Downarrow", "21d3", "r", "arrows", "double down arrow",
            "Updownarrow", "21d5", "r", "arrows", "double up down arrow",
            "longleftarrow", "27f5", "r", "arrows", "long left arrow",
            "longrightarrow", "27f6", "r", "arrows", "long right arrow",
            "longleftrightarrow", "27f7", "r", "arrows", "long left right arrow",
            "Longleftarrow", "27f8", "r", "arrows", "long double left arrow",
            "Longrightarrow", "27f9", "r", "arrows", "long double right arrow",
            "Longleftrightarrow", "27fa", "r", "arrows", "long double left right arrow",
            "implies", "27f9", "r", "logic", "implies",
            "impliedby", "27f8", "r", "logic", "is implied by",
            "iff", "27fa", "r", "logic", "if and only if",
            "mapsto", "21a6", "r", "arrows", "maps to",
            "longmapsto", "27fc", "r", "arrows", "long maps to",
            "hookrightarrow", "21aa", "r", "arrows", "hook right arrow",
            "hookleftarrow", "21a9", "r", "arrows", "hook left arrow",
            "nearrow", "2197", "r", "arrows", "north east arrow",
            "searrow", "2198", "r", "arrows", "south east arrow",
            "swarrow", "2199", "r", "arrows", "south west arrow",
            "nwarrow", "2196", "r", "arrows", "north west arrow",
            "rightharpoonup", "21c0", "r", "arrows", "right harpoon up",
            "rightharpoondown", "21c1", "r", "arrows", "right harpoon down",
            "leftharpoonup", "21bc", "r", "arrows", "left harpoon up",
            "leftharpoondown", "21bd", "r", "arrows", "left harpoon down",
            "rightleftharpoons", "21cc", "r", "arrows", "equilibrium",
            "leftrightharpoons", "21cb", "r", "arrows", "reverse equilibrium",
            "twoheadrightarrow", "21a0", "r", "arrows", "surjection",
            "rightarrowtail", "21a3", "r", "arrows", "injection",
            "leadsto", "21dd", "r", "arrows", "leads to",
            "circlearrowright", "21bb", "r", "arrows", "clockwise arrow",
            "circlearrowleft", "21ba", "r", "arrows", "anticlockwise arrow",
            "rightrightarrows", "21c9", "r", "arrows", "paired right arrows",
            "leftleftarrows", "21c7", "r", "arrows", "paired left arrows",

            "sum", "2211", "L", "bigops", "sum",
            "prod", "220f", "L", "bigops", "product",
            "coprod", "2210", "L", "bigops", "coproduct",
            "int", "222b", "I", "bigops", "integral",
            "iint", "222c", "I", "bigops", "double integral",
            "iiint", "222d", "I", "bigops", "triple integral",
            "iiiint", "2a0c", "I", "bigops", "quadruple integral",
            "oint", "222e", "I", "bigops", "contour integral",
            "oiint", "222f", "I", "bigops", "surface integral",
            "oiiint", "2230", "I", "bigops", "volume integral",
            "bigcap", "22c2", "L", "bigops", "n-ary intersection",
            "bigcup", "22c3", "L", "bigops", "n-ary union",
            "bigsqcup", "2a06", "L", "bigops", "n-ary square union",
            "bigvee", "22c1", "L", "bigops", "n-ary logical or",
            "bigwedge", "22c0", "L", "bigops", "n-ary logical and",
            "bigodot", "2a00", "L", "bigops", "n-ary circled dot",
            "bigoplus", "2a01", "L", "bigops", "n-ary circled plus",
            "bigotimes", "2a02", "L", "bigops", "n-ary circled times",
            "biguplus", "2a04", "L", "bigops", "n-ary multiset union",

            "infty", "221e", "o", "misc", "infinity",
            "partial", "2202", "o", "misc", "partial derivative",
            "nabla", "2207", "o", "misc", "nabla",
            "forall", "2200", "o", "logic", "for all",
            "exists", "2203", "o", "logic", "there exists",
            "nexists", "2204", "o", "logic", "there does not exist",
            "neg", "00ac", "o", "logic", "not",
            "lnot", "00ac", "o", "logic", "not",
            "top", "22a4", "o", "logic", "top",
            "bot", "22a5", "o", "logic", "bottom",
            "emptyset", "2205", "o", "sets", "empty set",
            "varnothing", "2205", "o", "sets", "empty set",
            "complement", "2201", "o", "sets", "complement",
            "aleph", "2135", "o", "sets", "aleph",
            "beth", "2136", "o", "sets", "beth",
            "hbar", "210f", "o", "misc", "h bar",
            "ell", "2113", "o", "misc", "script l",
            "wp", "2118", "o", "misc", "Weierstrass p",
            "Re", "211c", "o", "misc", "real part",
            "Im", "2111", "o", "misc", "imaginary part",
            "imath", "0131", "o", "misc", "dotless i",
            "jmath", "0237", "o", "misc", "dotless j",
            "prime", "2032", "o", "misc", "prime",
            "angle", "2220", "o", "misc", "angle",
            "measuredangle", "2221", "o", "misc", "measured angle",
            "triangle", "25b3", "o", "misc", "triangle",
            "square", "25a1", "o", "misc", "square",
            "Box", "25a1", "o", "misc", "square",
            "lozenge", "25ca", "o", "misc", "lozenge",
            "degree", "00b0", "o", "misc", "degree",
            "ldots", "2026", "i", "misc", "horizontal ellipsis",
            "dots", "2026", "i", "misc", "horizontal ellipsis",
            "cdots", "22ef", "i", "misc", "midline ellipsis",
            "vdots", "22ee", "o", "misc", "vertical ellipsis",
            "ddots", "22f1", "o", "misc", "diagonal ellipsis",
            "spadesuit", "2660", "o", "misc", "spades",
            "heartsuit", "2661", "o", "misc", "hearts",
            "diamondsuit", "2662", "o", "misc", "diamonds",
            "clubsuit", "2663", "o", "misc", "clubs",
            "flat", "266d", "o", "misc", "flat",
            "natural", "266e", "o", "misc", "natural",
            "sharp", "266f", "o", "misc", "sharp",
            "checkmark", "2713", "o", "misc", "check mark",
            "qed", "220e", "o", "misc", "end of proof",
            "S", "00a7", "o", "misc", "section",
            "P", "00b6", "o", "misc", "paragraph",
            "surd", "221a", "o", "misc", "radical sign",
            "backslash", "005c", "o", "misc", "backslash",
            "colon", "003a", "p", "misc", "colon",
            "vert", "007c", "o", "delimiters", "vertical bar",
            "Vert", "2016", "o", "delimiters", "double vertical bar",
            "lbrace", "007b", "(", "delimiters", "left brace",
            "rbrace", "007d", ")", "delimiters", "right brace",
            "lbrack", "005b", "(", "delimiters", "left bracket",
            "rbrack", "005d", ")", "delimiters", "right bracket",
            "langle", "27e8", "(", "delimiters", "left angle",
            "rangle", "27e9", ")", "delimiters", "right angle",
            "lfloor", "230a", "(", "delimiters", "left floor",
            "rfloor", "230b", ")", "delimiters", "right floor",
            "lceil", "2308", "(", "delimiters", "left ceiling",
            "rceil", "2309", ")", "delimiters", "right ceiling",
            "lvert", "007c", "(", "delimiters", "left vertical bar",
            "rvert", "007c", ")", "delimiters", "right vertical bar",
            "lVert", "2016", "(", "delimiters", "left double bar",
            "rVert", "2016", ")", "delimiters", "right double bar",
            "llbracket", "27e6", "(", "delimiters", "left white bracket",
            "rrbracket", "27e7", ")", "delimiters", "right white bracket",
            "lgroup", "27ee", "(", "delimiters", "left group",
            "rgroup", "27ef", ")", "delimiters", "right group",
            "nless", "226e", "r", "negated", "not less than",
            "ngtr", "226f", "r", "negated", "not greater than",
            "nleq", "2270", "r", "negated", "neither less than nor equal",
            "ngeq", "2271", "r", "negated", "neither greater than nor equal",
            "nequiv", "2262", "r", "negated", "not identical",
            "nsim", "2241", "r", "negated", "not similar",
            "nsimeq", "2244", "r", "negated", "not asymptotically equal",
            "ncong", "2247", "r", "negated", "not congruent",
            "napprox", "2249", "r", "negated", "not approximately equal",
            "nasymp", "226d", "r", "negated", "not equivalent",
            "notni", "220c", "r", "negated", "does not contain",
            "nsubset", "2284", "r", "negated", "not a subset",
            "nsupset", "2285", "r", "negated", "not a superset",
            "nsupseteq", "2289", "r", "negated", "not a superset or equal",
            "nprec", "2280", "r", "negated", "does not precede",
            "nsucc", "2281", "r", "negated", "does not succeed",
            "npreceq", "22e0", "r", "negated", "does not precede or equal",
            "nsucceq", "22e1", "r", "negated", "does not succeed or equal",
            "nparallel", "2226", "r", "negated", "not parallel",
            "nvdash", "22ac", "r", "negated", "does not prove",
            "nvDash", "22ad", "r", "negated", "not true",
            "ntriangleleft", "22ea", "r", "negated", "not normal subgroup",
            "ntriangleright", "22eb", "r", "negated", "does not contain as normal subgroup",
            "lneq", "2a87", "r", "negated", "less than and not equal",
            "gneq", "2a88", "r", "negated", "greater than and not equal",
            "lnsim", "22e6", "r", "negated", "less than but not equivalent",
            "gnsim", "22e7", "r", "negated", "greater than but not equivalent",
            "lnapprox", "2a89", "r", "negated", "less than and not approximate",
            "gnapprox", "2a8a", "r", "negated", "greater than and not approximate",
            "nleftarrow", "219a", "r", "negated", "not left arrow",
            "nrightarrow", "219b", "r", "negated", "not right arrow",
            "nleftrightarrow", "21ae", "r", "negated", "not left right arrow",
            "nLeftarrow", "21cd", "r", "negated", "not implied by",
            "nRightarrow", "21cf", "r", "negated", "does not imply",
            "nLeftrightarrow", "21ce", "r", "negated", "not if and only if",
            "gimel", "2137", "o", "letterlike", "gimel",
            "daleth", "2138", "o", "letterlike", "daleth",
            "mho", "2127", "o", "letterlike", "mho",
            "eth", "00f0", "o", "letterlike", "eth",
            "Finv", "2132", "o", "letterlike", "turned F",
            "Game", "2141", "o", "letterlike", "turned G",
            "Angstrom", "212b", "o", "letterlike", "angstrom",
            "Eulerconst", "2107", "o", "letterlike", "Euler constant",
            "DD", "2145", "o", "letterlike", "double-struck capital d",
            "dd", "2146", "o", "letterlike", "double-struck d, differential",
            "ee", "2147", "o", "letterlike", "double-struck e, exponential",
            "ii", "2148", "o", "letterlike", "double-struck i, imaginary",
            "jj", "2149", "o", "letterlike", "double-struck j",
            "Planckconst", "210e", "o", "letterlike", "Planck constant",
            "BbbC", "2102", "o", "letterlike", "complex numbers",
            "BbbH", "210d", "o", "letterlike", "quaternions",
            "BbbN", "2115", "o", "letterlike", "natural numbers",
            "BbbP", "2119", "o", "letterlike", "primes",
            "BbbQ", "211a", "o", "letterlike", "rational numbers",
            "BbbR", "211d", "o", "letterlike", "real numbers",
            "BbbZ", "2124", "o", "letterlike", "integers",
            "scrB", "212c", "o", "letterlike", "script capital B",
            "scrE", "2130", "o", "letterlike", "script capital E",
            "scrF", "2131", "o", "letterlike", "script capital F",
            "scrH", "210b", "o", "letterlike", "script capital H",
            "scrI", "2110", "o", "letterlike", "script capital I",
            "scrL", "2112", "o", "letterlike", "script capital L, Laplace transform",
            "scrM", "2133", "o", "letterlike", "script capital M",
            "scrR", "211b", "o", "letterlike", "script capital R",
            "scre", "212f", "o", "letterlike", "script small e",
            "scrg", "210a", "o", "letterlike", "script small g",
            "scro", "2134", "o", "letterlike", "script small o",
            "frakC", "212d", "o", "letterlike", "fraktur capital C",
            "frakH", "210c", "o", "letterlike", "fraktur capital H",
            "frakZ", "2128", "o", "letterlike", "fraktur capital Z",
            "tcohm", "2126", "o", "letterlike", "ohm",
            "backepsilon", "03f6", "o", "letterlike", "reversed epsilon",
            "varkappa2", "03f0", "o", "letterlike", "kappa symbol",
            "gangle", "2220", "o", "geometry", "angle",
            "gmeasuredangle", "2221", "o", "geometry", "measured angle",
            "sphericalangle", "2222", "o", "geometry", "spherical angle",
            "rightangle", "221f", "o", "geometry", "right angle",
            "measuredrightangle", "22be", "o", "geometry", "right angle with arc",
            "righttriangle", "22bf", "o", "geometry", "right triangle",
            "gperp", "22a5", "r", "geometry", "perpendicular",
            "gparallel", "2225", "r", "geometry", "parallel",
            "gtriangle", "25b3", "o", "geometry", "triangle",
            "blacktriangle", "25b2", "o", "geometry", "black triangle",
            "gsquare", "25a1", "o", "geometry", "square",
            "blacksquare", "25a0", "o", "geometry", "black square",
            "rectangle", "25ad", "o", "geometry", "rectangle",
            "parallelogram", "25b1", "o", "geometry", "parallelogram",
            "gdiamond", "25c7", "o", "geometry", "diamond shape",
            "bigcirc", "25cb", "o", "geometry", "circle",
            "odotcircle", "2299", "o", "geometry", "circle with centre",
            "arc", "2312", "o", "geometry", "arc",
            "gcong", "2245", "r", "geometry", "congruent",
            "gsim", "223c", "r", "geometry", "similar",
            "gdegree", "00b0", "o", "geometry", "degree",
            "gprime", "2032", "o", "geometry", "minute of arc",
            "dprime", "2033", "o", "geometry", "second of arc",
            "measeq", "225e", "r", "geometry", "measured by",
            "gequal", "225c", "r", "geometry", "equal by definition",
            "propor", "2237", "r", "geometry", "proportion",
            "mathcalA", "1d49c", "o", "script", "script capital A",
            "mathcalB", "212c", "o", "script", "script capital B",
            "mathcalC", "1d49e", "o", "script", "script capital C",
            "mathcalD", "1d49f", "o", "script", "script capital D",
            "mathcalE", "2130", "o", "script", "script capital E",
            "mathcalF", "2131", "o", "script", "script capital F",
            "mathcalG", "1d4a2", "o", "script", "script capital G",
            "mathcalH", "210b", "o", "script", "script capital H",
            "mathcalI", "2110", "o", "script", "script capital I",
            "mathcalJ", "1d4a5", "o", "script", "script capital J",
            "mathcalK", "1d4a6", "o", "script", "script capital K",
            "mathcalL", "2112", "o", "script", "script capital L",
            "mathcalM", "2133", "o", "script", "script capital M",
            "mathcalN", "1d4a9", "o", "script", "script capital N",
            "mathcalO", "1d4aa", "o", "script", "script capital O",
            "mathcalP", "1d4ab", "o", "script", "script capital P",
            "mathcalQ", "1d4ac", "o", "script", "script capital Q",
            "mathcalR", "211b", "o", "script", "script capital R",
            "mathcalS", "1d4ae", "o", "script", "script capital S",
            "mathcalT", "1d4af", "o", "script", "script capital T",
            "mathcalU", "1d4b0", "o", "script", "script capital U",
            "mathcalV", "1d4b1", "o", "script", "script capital V",
            "mathcalW", "1d4b2", "o", "script", "script capital W",
            "mathcalX", "1d4b3", "o", "script", "script capital X",
            "mathcalY", "1d4b4", "o", "script", "script capital Y",
            "mathcalZ", "1d4b5", "o", "script", "script capital Z",
            "mathfrakA", "1d504", "o", "script", "fraktur capital A",
            "mathfrakB", "1d505", "o", "script", "fraktur capital B",
            "mathfrakC", "212d", "o", "script", "fraktur capital C",
            "mathfrakD", "1d507", "o", "script", "fraktur capital D",
            "mathfrakE", "1d508", "o", "script", "fraktur capital E",
            "mathfrakF", "1d509", "o", "script", "fraktur capital F",
            "mathfrakG", "1d50a", "o", "script", "fraktur capital G",
            "mathfrakH", "210c", "o", "script", "fraktur capital H",
            "mathfrakI", "2111", "o", "script", "fraktur capital I",
            "mathfrakJ", "1d50d", "o", "script", "fraktur capital J",
            "mathfrakK", "1d50e", "o", "script", "fraktur capital K",
            "mathfrakL", "1d50f", "o", "script", "fraktur capital L",
            "mathfrakM", "1d510", "o", "script", "fraktur capital M",
            "mathfrakN", "1d511", "o", "script", "fraktur capital N",
            "mathfrakO", "1d512", "o", "script", "fraktur capital O",
            "mathfrakP", "1d513", "o", "script", "fraktur capital P",
            "mathfrakQ", "1d514", "o", "script", "fraktur capital Q",
            "mathfrakR", "211c", "o", "script", "fraktur capital R",
            "mathfrakS", "1d516", "o", "script", "fraktur capital S",
            "mathfrakT", "1d517", "o", "script", "fraktur capital T",
            "mathfrakU", "1d518", "o", "script", "fraktur capital U",
            "mathfrakV", "1d519", "o", "script", "fraktur capital V",
            "mathfrakW", "1d51a", "o", "script", "fraktur capital W",
            "mathfrakX", "1d51b", "o", "script", "fraktur capital X",
            "mathfrakY", "1d51c", "o", "script", "fraktur capital Y",
            "mathfrakZ", "2128", "o", "script", "fraktur capital Z",
            "mathbbA", "1d538", "o", "script", "double-struck capital A",
            "mathbbB", "1d539", "o", "script", "double-struck capital B",
            "mathbbC", "2102", "o", "script", "double-struck capital C",
            "mathbbD", "1d53b", "o", "script", "double-struck capital D",
            "mathbbE", "1d53c", "o", "script", "double-struck capital E",
            "mathbbF", "1d53d", "o", "script", "double-struck capital F",
            "mathbbG", "1d53e", "o", "script", "double-struck capital G",
            "mathbbH", "210d", "o", "script", "double-struck capital H",
            "mathbbI", "1d540", "o", "script", "double-struck capital I",
            "mathbbJ", "1d541", "o", "script", "double-struck capital J",
            "mathbbK", "1d542", "o", "script", "double-struck capital K",
            "mathbbL", "1d543", "o", "script", "double-struck capital L",
            "mathbbM", "1d544", "o", "script", "double-struck capital M",
            "mathbbN", "2115", "o", "script", "double-struck capital N",
            "mathbbO", "1d546", "o", "script", "double-struck capital O",
            "mathbbP", "2119", "o", "script", "double-struck capital P",
            "mathbbQ", "211a", "o", "script", "double-struck capital Q",
            "mathbbR", "211d", "o", "script", "double-struck capital R",
            "mathbbS", "1d54a", "o", "script", "double-struck capital S",
            "mathbbT", "1d54b", "o", "script", "double-struck capital T",
            "mathbbU", "1d54c", "o", "script", "double-struck capital U",
            "mathbbV", "1d54d", "o", "script", "double-struck capital V",
            "mathbbW", "1d54e", "o", "script", "double-struck capital W",
            "mathbbX", "1d54f", "o", "script", "double-struck capital X",
            "mathbbY", "1d550", "o", "script", "double-struck capital Y",
            "mathbbZ", "2124", "o", "script", "double-struck capital Z"
        };

        private const string[] ACCENTS = {
            "hat", "0302", "0", "0", "hat",
            "widehat", "0302", "1", "0", "wide hat",
            "check", "030c", "0", "0", "caron",
            "widecheck", "030c", "1", "0", "wide caron",
            "tilde", "0303", "0", "0", "tilde",
            "widetilde", "0303", "1", "0", "wide tilde",
            "acute", "0301", "0", "0", "acute",
            "grave", "0300", "0", "0", "grave",
            "dot", "0307", "0", "0", "dot",
            "ddot", "0308", "0", "0", "double dot",
            "dddot", "20db", "0", "0", "triple dot",
            "breve", "0306", "0", "0", "breve",
            "bar", "0304", "0", "0", "bar",
            "vec", "20d7", "0", "0", "vector",
            "mathring", "030a", "0", "0", "ring",
            "overline", "203e", "1", "0", "overline",
            "underline", "005f", "1", "1", "underline",
            "overrightarrow", "2192", "1", "0", "right arrow above",
            "overleftarrow", "2190", "1", "0", "left arrow above",
            "overleftrightarrow", "2194", "1", "0", "left right arrow above",
            "underrightarrow", "2192", "1", "1", "right arrow below",
            "underleftarrow", "2190", "1", "1", "left arrow below",
            "overbrace", "23de", "1", "0", "brace above",
            "underbrace", "23df", "1", "1", "brace below",
            "overparen", "23dc", "1", "0", "parenthesis above",
            "underparen", "23dd", "1", "1", "parenthesis below",
            "overbracket", "23b4", "1", "0", "bracket above",
            "underbracket", "23b5", "1", "1", "bracket below"
        };

        private const string[] DELIMS = {
            "(", "0028", ")", "0029", "[", "005b", "]", "005d", "\\{", "007b", "\\}", "007d",
            "\\lbrace", "007b", "\\rbrace", "007d", "\\lbrack", "005b", "\\rbrack", "005d",
            "\\langle", "27e8", "\\rangle", "27e9", "<", "27e8", ">", "27e9",
            "|", "007c", "\\|", "2016", "\\vert", "007c", "\\Vert", "2016", "\\lvert", "007c", "\\rvert", "007c",
            "\\lVert", "2016", "\\rVert", "2016", "\\lfloor", "230a", "\\rfloor", "230b", "\\lceil", "2308",
            "\\rceil", "2309", "/", "002f", "\\backslash", "005c", "\\uparrow", "2191", "\\downarrow", "2193",
            "\\updownarrow", "2195", "\\Uparrow", "21d1", "\\Downarrow", "21d3", "\\Updownarrow", "21d5",
            "\\llbracket", "27e6", "\\rrbracket", "27e7", "\\lgroup", "27ee", "\\rgroup", "27ef",
            "\\langle", "27e8", "\\rangle", "27e9"
        };

        public static string hex (string code) {
            uint v = 0;
            for (int i = 0; i < code.length; i++) {
                char c = code[i];
                v = v * 16 + (uint) (c.isdigit () ? c - '0' : c.tolower () - 'a' + 10);
            }
            return ((unichar) v).to_string ();
        }

        public static string cp (uint code) {
            return ((unichar) code).to_string ();
        }

        private static void ensure () {
            if (commands != null) return;
            commands = new Gee.HashMap<string, Symbol> ();
            chars = new Gee.HashMap<string, Symbol> ();
            all_list = new Gee.ArrayList<Symbol> ();
            for (int i = 0; i + 4 < TABLE.length; i += 5) {
                AtomClass cls = AtomClass.ORD;
                bool large = false;
                bool lim = false;
                switch (TABLE[i + 2]) {
                    case "b": cls = AtomClass.BIN; break;
                    case "r": cls = AtomClass.REL; break;
                    case "p": cls = AtomClass.PUNCT; break;
                    case "(": cls = AtomClass.OPEN; break;
                    case ")": cls = AtomClass.CLOSE; break;
                    case "i": cls = AtomClass.INNER; break;
                    case "L": cls = AtomClass.OP; large = true; lim = true; break;
                    case "I": cls = AtomClass.OP; large = true; break;
                    default: cls = AtomClass.ORD; break;
                }
                var s = new Symbol (TABLE[i], hex (TABLE[i + 1]), cls, TABLE[i + 3], TABLE[i + 4], large, lim);
                commands[s.command] = s;
                if (!chars.has_key (s.ch)) chars[s.ch] = s;
                all_list.add (s);
            }
            accents = new Gee.HashMap<string, AccentInfo> ();
            accent_marks = new Gee.HashMap<string, AccentInfo> ();
            accent_list = new Gee.ArrayList<AccentInfo> ();
            for (int i = 0; i + 4 < ACCENTS.length; i += 5) {
                var a = new AccentInfo (ACCENTS[i], hex (ACCENTS[i + 1]), ACCENTS[i + 2] == "1", ACCENTS[i + 3] == "1", ACCENTS[i + 4]);
                accents[a.command] = a;
                string key = a.mark + (a.stretchy ? "s" : "") + (a.under ? "u" : "");
                if (!accent_marks.has_key (key)) accent_marks[key] = a;
                accent_list.add (a);
            }
            string[] preferred = { "to", "leq", "geq", "neq", "leftarrow", "wedge", "vee", "neg", "emptyset", "ldots", "mid", "perp" };
            foreach (var pref in preferred) {
                var ps = commands[pref];
                if (ps != null) chars[ps.ch] = ps;
            }
            delimiters = new Gee.HashMap<string, string> ();
            delimiter_names = new Gee.HashMap<string, string> ();
            for (int i = 0; i + 1 < DELIMS.length; i += 2) {
                string ch = hex (DELIMS[i + 1]);
                delimiters[DELIMS[i]] = ch;
                if (!delimiter_names.has_key (ch)) delimiter_names[ch] = DELIMS[i];
            }
            delimiters["."] = "";
            delimiter_names["{"] = "\\{";
            delimiter_names["}"] = "\\}";
            delimiter_names[hex ("2016")] = "\\|";
            delimiter_names[hex ("27e8")] = "\\langle";
            delimiter_names[hex ("27e9")] = "\\rangle";
            functions = new Gee.HashSet<string> ();
            foreach (var f in FUNCTION_NAMES) functions.add (f);
            limit_functions = new Gee.HashSet<string> ();
            foreach (var f in LIMIT_FUNCTION_NAMES) limit_functions.add (f);
        }

        public static Symbol? by_command (string cmd) {
            ensure ();
            return commands[cmd];
        }

        public static Symbol? by_char (string ch) {
            ensure ();
            return chars[ch];
        }

        public static Gee.List<Symbol> all () {
            ensure ();
            return all_list;
        }

        public static AccentInfo? accent (string cmd) {
            ensure ();
            return accents[cmd];
        }

        public static AccentInfo? accent_for_mark (string mark, bool stretchy, bool under) {
            ensure ();
            string m = normalize_accent (mark);
            var a = accent_marks[m + (stretchy ? "s" : "") + (under ? "u" : "")];
            if (a == null) a = accent_marks[m + (!stretchy ? "s" : "") + (under ? "u" : "")];
            return a;
        }

        public static Gee.List<AccentInfo> all_accents () {
            ensure ();
            return accent_list;
        }

        public static string normalize_accent (string mark) {
            switch (mark) {
                case "^": case "\u02c6": return "\u0302";
                case "~": case "\u02dc": return "\u0303";
                case "\u00af": case "\u02c9": return "\u0304";
                case "\u02d8": return "\u0306";
                case "\u02d9": return "\u0307";
                case "\u00a8": return "\u0308";
                case "\u02c7": return "\u030c";
                case "\u00b4": case "\u02ca": return "\u0301";
                case "`": case "\u02cb": return "\u0300";
                case "\u02da": return "\u030a";
                case "\u0332": case "_": return "_";
                case "\u2015": case "\u0305": return "\u203e";
                default: return mark;
            }
        }

        public static string spacing_accent (string mark) {
            switch (mark) {
                case "\u0302": return "^";
                case "\u0303": return "~";
                case "\u0304": return "\u00af";
                case "\u0306": return "\u02d8";
                case "\u0307": return "\u02d9";
                case "\u0308": return "\u00a8";
                case "\u030c": return "\u02c7";
                case "\u0301": return "\u00b4";
                case "\u0300": return "`";
                case "\u030a": return "\u02da";
                case "\u20d7": return cp (0x2192);
                default: return mark;
            }
        }

        public static string? delimiter (string name) {
            ensure ();
            return delimiters[name];
        }

        public static string delimiter_name (string ch) {
            ensure ();
            if (ch == "") return ".";
            var n = delimiter_names[ch];
            return n ?? ch;
        }

        public static Singularity.Equations.AutoCorrect? autocorrect;

        public static bool is_function (string name) {
            ensure ();
            if (autocorrect != null) {
                if (autocorrect.is_function (name)) return true;
                return functions.contains (name) && !autocorrect.is_default_function (name);
            }
            return functions.contains (name);
        }

        public static bool function_has_limits (string name) {
            ensure ();
            return limit_functions.contains (name);
        }

        public static AtomClass char_class (string ch) {
            ensure ();
            var s = chars[ch];
            if (s != null) return s.cls;
            switch (ch) {
                case "+": case "-": case "\u2212": case "*": return AtomClass.BIN;
                case "=": case "<": case ">": case ":": return AtomClass.REL;
                case ",": case ";": return AtomClass.PUNCT;
                case "(": case "[": case "{": return AtomClass.OPEN;
                case ")": case "]": case "}": case "!": case "?": return AtomClass.CLOSE;
                default: return AtomClass.ORD;
            }
        }

        public static bool is_large_op (string ch) {
            ensure ();
            var s = chars[ch];
            return s != null && s.largeop;
        }

        public static bool has_limits (string ch) {
            ensure ();
            var s = chars[ch];
            return s != null && s.limits;
        }

        public static bool is_integral (string ch) {
            ensure ();
            var s = chars[ch];
            return s != null && s.largeop && !s.limits;
        }

        public static bool is_fence (string ch) {
            return matching_close (ch) != null || matching_open (ch) != null;
        }

        public static string? matching_close (string open) {
            switch (open) {
                case "(": return ")";
                case "[": return "]";
                case "{": return "}";
                case "|": return "|";
                case "\u2016": return "\u2016";
                case "\u27e8": return "\u27e9";
                case "\u230a": return "\u230b";
                case "\u2308": return "\u2309";
                case "\u27e6": return "\u27e7";
                case "\u27ee": return "\u27ef";
                default: return null;
            }
        }

        public static string? matching_open (string close) {
            switch (close) {
                case ")": return "(";
                case "]": return "[";
                case "}": return "{";
                case "|": return "|";
                case "\u2016": return "\u2016";
                case "\u27e9": return "\u27e8";
                case "\u230b": return "\u230a";
                case "\u2309": return "\u2308";
                case "\u27e7": return "\u27e6";
                case "\u27ef": return "\u27ee";
                default: return null;
            }
        }

        public static string? command_for_char (string ch) {
            ensure ();
            var s = chars[ch];
            return s != null ? s.command : null;
        }

        public static bool named_space (string cmd, out double width) {
            switch (cmd) {
                case ",": case "thinspace": width = 3.0 / 18.0; return true;
                case ":": case ">": case "medspace": width = 4.0 / 18.0; return true;
                case ";": case "thickspace": width = 5.0 / 18.0; return true;
                case "!": case "negthinspace": width = -3.0 / 18.0; return true;
                case "negmedspace": width = -4.0 / 18.0; return true;
                case "negthickspace": width = -5.0 / 18.0; return true;
                case " ": case "space": width = 1.0 / 3.0; return true;
                case "enspace": width = 0.5; return true;
                case "quad": width = 1.0; return true;
                case "qquad": width = 2.0; return true;
                default: width = 0; return false;
            }
        }

        public static string space_command (double w) {
            double[] widths = { 3.0 / 18.0, 4.0 / 18.0, 5.0 / 18.0, -3.0 / 18.0, 1.0, 2.0, 1.0 / 3.0, 0.5, -4.0 / 18.0, -5.0 / 18.0 };
            string[] names = { "\\,", "\\:", "\\;", "\\!", "\\quad", "\\qquad", "\\ ", "\\enspace", "\\negmedspace", "\\negthickspace" };
            for (int i = 0; i < widths.length; i++) if (Math.fabs (widths[i] - w) < 1e-4) return names[i];
            return "\\hspace{%sem}".printf (Format.num (w));
        }

        public static bool font_command (string cmd, out MathVariant variant) {
            switch (cmd) {
                case "mathbf": case "textbf": variant = MathVariant.BOLD; return true;
                case "mathit": case "textit": variant = MathVariant.ITALIC; return true;
                case "mathrm": case "mathup": case "operatorname": variant = MathVariant.NORMAL; return true;
                case "mathbb": variant = MathVariant.DOUBLE_STRUCK; return true;
                case "mathcal": case "mathscr": variant = MathVariant.SCRIPT; return true;
                case "mathfrak": variant = MathVariant.FRAKTUR; return true;
                case "mathsf": case "textsf": variant = MathVariant.SANS_SERIF; return true;
                case "mathtt": case "texttt": variant = MathVariant.MONOSPACE; return true;
                case "boldsymbol": case "bm": case "mathbfit": variant = MathVariant.BOLD_ITALIC; return true;
                case "mathbfcal": variant = MathVariant.BOLD_SCRIPT; return true;
                case "mathbffrak": variant = MathVariant.BOLD_FRAKTUR; return true;
                case "mathbfsf": variant = MathVariant.BOLD_SANS_SERIF; return true;
                case "mathsfit": variant = MathVariant.SANS_SERIF_ITALIC; return true;
                case "mathbfsfit": variant = MathVariant.SANS_SERIF_BOLD_ITALIC; return true;
                default: variant = MathVariant.DEFAULT; return false;
            }
        }

        public const string[] TEX_FUNCTION_NAMES = {
            "arccos", "arcsin", "arctan", "arg", "cos", "cosh", "cot", "coth", "csc", "deg", "det", "dim", "exp",
            "gcd", "hom", "inf", "ker", "lg", "lim", "liminf", "limsup", "ln", "log", "max", "min", "Pr", "sec",
            "sin", "sinh", "sup", "tan", "tanh"
        };

        public static bool is_tex_function (string name) {
            foreach (var f in TEX_FUNCTION_NAMES) if (f == name) return true;
            return false;
        }

        public static bool is_letter (unichar c) {
            return c.isalpha ();
        }

        public static string? font_command_for (MathVariant v) {
            switch (v) {
                case MathVariant.BOLD: return "mathbf";
                case MathVariant.ITALIC: return "mathit";
                case MathVariant.NORMAL: return "mathrm";
                case MathVariant.DOUBLE_STRUCK: return "mathbb";
                case MathVariant.SCRIPT: return "mathcal";
                case MathVariant.FRAKTUR: return "mathfrak";
                case MathVariant.SANS_SERIF: return "mathsf";
                case MathVariant.MONOSPACE: return "mathtt";
                case MathVariant.BOLD_ITALIC: return "boldsymbol";
                case MathVariant.BOLD_SCRIPT: return "mathbfcal";
                case MathVariant.BOLD_FRAKTUR: return "mathbffrak";
                case MathVariant.BOLD_SANS_SERIF: return "mathbfsf";
                case MathVariant.SANS_SERIF_ITALIC: return "mathsfit";
                case MathVariant.SANS_SERIF_BOLD_ITALIC: return "mathbfsfit";
                default: return null;
            }
        }
    }

    public class Format {
        public static string num (double v) {
            if (Math.fabs (v - Math.round (v)) < 1e-9) return "%d".printf ((int) Math.round (v));
            var s = "%.4f".printf (v);
            s = s.replace (",", ".");
            while (s.has_suffix ("0")) s = s.substring (0, s.length - 1);
            if (s.has_suffix (".")) s = s.substring (0, s.length - 1);
            return s;
        }
    }
}
