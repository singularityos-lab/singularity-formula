namespace Singularity.Apps.Formula {

    public class StarMathWriter {
        private static Gee.HashMap<string, string>? names;

        private const string[] TABLE = {
            "00b1", "+-", "2213", "-+", "00d7", "times", "00f7", "div", "22c5", "cdot", "2217", "*", "2218", "circ",
            "2260", "<>", "2264", "<=", "2265", ">=", "2a7d", "leslant", "2a7e", "geslant", "226a", "<<", "226b", ">>",
            "2248", "approx", "223c", "sim", "2243", "simeq", "2261", "equiv", "221d", "prop", "2225", "parallel",
            "22a5", "ortho", "2223", "divides", "2224", "ndivides", "2208", "in", "2209", "notin", "220b", "owns",
            "2282", "subset", "2283", "supset", "2286", "subseteq", "2287", "supseteq", "2284", "nsubset", "2285", "nsupset",
            "2288", "nsubseteq", "2289", "nsupseteq", "222a", "union", "2229", "intersection", "2216", "setminus",
            "2192", "toward", "21d0", "dlarrow", "21d4", "dlrarrow", "21d2", "drarrow", "27f9", "drarrow", "27fa", "dlrarrow",
            "27f8", "dlarrow", "221e", "infinity", "2202", "partial", "2207", "nabla", "2203", "exists", "2204", "notexists",
            "2200", "forall", "2205", "emptyset", "2135", "aleph", "211c", "Re", "2111", "Im", "2118", "wp",
            "22ef", "dotsaxis", "2026", "dotslow", "22ee", "dotsvert", "22f1", "dotsdown", "2227", "and", "2228", "or",
            "00ac", "neg", "2295", "circlePlus", "2297", "circleTimes", "2296", "circleMinus", "2299", "odot",
            "2298", "odivide", "227a", "prec", "227b", "succ", "2aaf", "preccurlyeq", "2ab0", "succcurlyeq",
            "22a2", "vdash", "22a8", "dvdash", "2245", "cong", "2250", "doteq", "210f", "hbar", "2113", "lambdabar",
            "2220", "angle", "2032", "'", "00b0", "\"\u00b0\""
        };

        private const string[] GREEK = {
            "03b1", "alpha", "03b2", "beta", "03b3", "gamma", "03b4", "delta", "03f5", "epsilon", "03b5", "varepsilon",
            "03b6", "zeta", "03b7", "eta", "03b8", "theta", "03d1", "vartheta", "03b9", "iota", "03ba", "kappa",
            "03bb", "lambda", "03bc", "mu", "03bd", "nu", "03be", "xi", "03bf", "omicron", "03c0", "pi", "03d6", "varpi",
            "03c1", "rho", "03f1", "varrho", "03c3", "sigma", "03c2", "varsigma", "03c4", "tau", "03c5", "upsilon",
            "03d5", "phi", "03c6", "varphi", "03c7", "chi", "03c8", "psi", "03c9", "omega",
            "0393", "GAMMA", "0394", "DELTA", "0398", "THETA", "039b", "LAMBDA", "039e", "XI", "03a0", "PI",
            "03a3", "SIGMA", "03a5", "UPSILON", "03a6", "PHI", "03a8", "PSI", "03a9", "OMEGA"
        };

        private static void ensure () {
            if (names != null) return;
            names = new Gee.HashMap<string, string> ();
            for (int i = 0; i + 1 < TABLE.length; i += 2) {
                string ch = Symbols.hex (TABLE[i]);
                if (!names.has_key (ch)) names[ch] = TABLE[i + 1];
            }
            for (int i = 0; i + 1 < GREEK.length; i += 2) {
                string ch = Symbols.hex (GREEK[i]);
                string n = GREEK[i + 1];
                bool upper = n == n.up ();
                names[ch] = "%" + (upper ? n : "i" + n);
            }
        }

        public static string write (Row r) {
            ensure ();
            return new StarMathWriter ().row (r).strip ();
        }

        private string group (Row r) {
            return "{" + row (r) + "}";
        }

        private string row (Row r) {
            var sb = new StringBuilder ();
            int i = 0;
            while (i < r.size) {
                var t = r[i] as Token;
                if (t != null && t.kind == TokenKind.TEXT) {
                    var tx = new StringBuilder ();
                    while (i < r.size && r[i] is Token && ((Token) r[i]).kind == TokenKind.TEXT) {
                        string c = ((Token) r[i]).text;
                        tx.append (c == "\"" ? "\\\"" : c);
                        i++;
                    }
                    sb.append (" \"").append (tx.str).append ("\" ");
                    continue;
                }
                if (t != null && t.kind == TokenKind.NUMBER) {
                    var num = new StringBuilder ();
                    while (i < r.size && r[i] is Token && ((Token) r[i]).kind == TokenKind.NUMBER) {
                        num.append (((Token) r[i]).text);
                        i++;
                    }
                    sb.append (" ").append (num.str).append (" ");
                    continue;
                }
                var n = r[i];
                if (i + 1 < r.size && r[i + 1] is Scripts && !((Scripts) r[i + 1]).pre) {
                    sb.append (scripted (n, (Scripts) r[i + 1]));
                    i += 2;
                    continue;
                }
                sb.append (" ").append (node (n)).append (" ");
                i++;
            }
            return sb.str.replace ("  ", " ").strip ();
        }

        private string scripted (Node base_node, Scripts s) {
            var t = base_node as Token;
            bool lim = t != null && (Symbols.is_large_op (t.text) || (t.kind == TokenKind.IDENT && Symbols.function_has_limits (t.text.replace (" ", ""))));
            string b = node (base_node);
            if (lim) {
                string res = " " + b;
                if (s.sub != null) res += " from" + group (s.sub);
                if (s.sup != null) res += " to" + group (s.sup);
                return res + " ";
            }
            if (base_node is Accent && ((Accent) base_node).is_brace ()) {
                var a = (Accent) base_node;
                string label = s.sup != null ? group (s.sup) : (s.sub != null ? group (s.sub) : "{}");
                return " " + group (a.body) + (a.under ? " underbrace " : " overbrace ") + label + " ";
            }
            string res = " {" + b + "}";
            if (s.sub != null) res += "_" + group (s.sub);
            if (s.sup != null) res += "^" + group (s.sup);
            return res + " ";
        }

        private static string delim (string d, bool left) {
            switch (d) {
                case "": return "none";
                case "(": return "(";
                case ")": return ")";
                case "[": return "[";
                case "]": return "]";
                case "{": return "lbrace";
                case "}": return "rbrace";
                case "|": return left ? "lline" : "rline";
                case "\u2016": return left ? "ldline" : "rdline";
                case "\u27e8": return "langle";
                case "\u27e9": return "rangle";
                case "\u230a": return "lfloor";
                case "\u230b": return "rfloor";
                case "\u2308": return "lceil";
                case "\u2309": return "rceil";
                case "\u27e6": return "ldbracket";
                case "\u27e7": return "rdbracket";
                default: return "none";
            }
        }

        private string token (Token t) {
            string s = t.text;
            if (t.kind == TokenKind.IDENT && s.char_count () > 1) {
                string compact = s.replace (" ", "");
                if (Symbols.is_function (compact) && compact != "sgn" && compact != "tr" && compact != "rank" && compact != "mod") return compact;
                return "func " + s;
            }
            string? name = names[s];
            string body;
            if (name != null) body = name;
            else if (s == "\u2212") body = "-";
            else if (s == "\u2211") return "sum";
            else if (s == "\u220f") return "prod";
            else if (s == "\u2210") return "coprod";
            else if (s == "\u222b") return "int";
            else if (s == "\u222c") return "iint";
            else if (s == "\u222d") return "iiint";
            else if (s == "\u222e") return "lint";
            else if (s == "\u222f") return "llint";
            else if (s == "\u2230") return "lllint";
            else if (s == "{") body = "lbrace";
            else if (s == "}") body = "rbrace";
            else if (s == "\"") body = "\"\\\"\"";
            else if (s == "%" || s == "#" || s == "&" || s == "_" || s == "^" || s == "~" || s == "`") body = "\"" + s + "\"";
            else body = s;
            if (t.kind == TokenKind.IDENT && t.variant != MathVariant.DEFAULT) {
                switch (t.variant) {
                    case MathVariant.BOLD: return "bold nitalic " + body;
                    case MathVariant.BOLD_ITALIC: return "bold " + body;
                    case MathVariant.NORMAL: return "nitalic " + body;
                    case MathVariant.SANS_SERIF: return "font sans nitalic " + body;
                    case MathVariant.MONOSPACE: return "font fixed nitalic " + body;
                    case MathVariant.DOUBLE_STRUCK: return body == "N" || body == "Z" || body == "Q" || body == "R" || body == "C" ? "set" + body : body;
                    default: return body;
                }
            }
            if (t.kind == TokenKind.NUMBER && t.variant == MathVariant.BOLD) return "bold " + body;
            return body;
        }

        private string node (Node n) {
            if (n is Token) return token ((Token) n);
            if (n is Space) {
                double w = ((Space) n).width;
                if (w <= 0) return "";
                if (w < 0.3) return "`";
                int tildes = int.max (1, (int) Math.round (w / 0.5));
                return string.nfill (tildes, '~');
            }
            if (n is Frac) {
                var f = (Frac) n;
                if (!f.line) return group (f.num) + " binom " + group (f.den);
                if (f.bevelled) return group (f.num) + " wideslash " + group (f.den);
                return group (f.num) + " over " + group (f.den);
            }
            if (n is Radical) {
                var r = (Radical) n;
                if (r.index == null) return "sqrt" + group (r.body);
                return "nroot" + group (r.index) + group (r.body);
            }
            if (n is Scripts) {
                var s = (Scripts) n;
                string res = "{}";
                if (s.pre) {
                    if (s.sub != null) res += " lsub" + group (s.sub);
                    if (s.sup != null) res += " lsup" + group (s.sup);
                    return res;
                }
                if (s.sub != null) res += "_" + group (s.sub);
                if (s.sup != null) res += "^" + group (s.sup);
                return res;
            }
            if (n is UnderOver) {
                var u = (UnderOver) n;
                string res = group (u.body);
                if (u.under != null) res += " csub" + group (u.under);
                if (u.over != null) res += " csup" + group (u.over);
                return res;
            }
            if (n is Accent) {
                var a = (Accent) n;
                if (a.is_brace ()) return group (a.body) + (a.under ? " underbrace {}" : " overbrace {}");
                string cmd;
                switch (Symbols.normalize_accent (a.mark)) {
                    case "\u0302": cmd = a.stretchy ? "widehat" : "hat"; break;
                    case "\u0303": cmd = a.stretchy ? "widetilde" : "tilde"; break;
                    case "\u0304": cmd = "bar"; break;
                    case "\u203e": cmd = "overline"; break;
                    case "_": cmd = "underline"; break;
                    case "\u0307": cmd = "dot"; break;
                    case "\u0308": cmd = "ddot"; break;
                    case "\u20db": cmd = "dddot"; break;
                    case "\u030c": cmd = "check"; break;
                    case "\u0301": cmd = "acute"; break;
                    case "\u0300": cmd = "grave"; break;
                    case "\u0306": cmd = "breve"; break;
                    case "\u030a": cmd = "circle"; break;
                    case "\u20d7": cmd = "vec"; break;
                    case "\u2192": cmd = "widevec"; break;
                    default: cmd = "hat"; break;
                }
                return cmd + " " + group (a.body);
            }
            if (n is Fenced) {
                var f = (Fenced) n;
                var body = new StringBuilder ();
                foreach (var item in f.body.items) {
                    var t = item as Token;
                    if (t != null && t.fence_middle) body.append (" mline ");
                    else body.append (" ").append ((item is Token) ? token ((Token) item) : node (item)).append (" ");
                }
                return "left " + delim (f.open, true) + " " + body.str.strip () + " right " + delim (f.close, false);
            }
            if (n is Table) {
                var t = (Table) n;
                var sb = new StringBuilder ();
                for (int r = 0; r < t.rows.size; r++) {
                    if (r > 0) sb.append (" ## ");
                    for (int c = 0; c < t.rows[r].size; c++) {
                        if (c > 0) sb.append (" # ");
                        string prefix = "";
                        if (t.kind == TableKind.ALIGN) prefix = c % 2 == 0 ? "alignr " : "alignl ";
                        else if (t.kind == TableKind.CASES || t.column_align (c) == 'l') prefix = "alignl ";
                        else if (t.column_align (c) == 'r') prefix = "alignr ";
                        sb.append (prefix).append (group (t.rows[r][c]));
                    }
                }
                string m = (t.kind == TableKind.GATHER ? "stack{" : "matrix{") + sb.str + "}";
                if (t.kind == TableKind.GATHER) m = "stack{" + sb.str.replace (" ## ", " # ") + "}";
                string o = t.kind.open_delim ();
                string cl = t.kind.close_delim ();
                if (o == "" && cl == "") return m;
                return "left " + delim (o, true) + " " + m + " right " + delim (cl, false);
            }
            if (n is Style) {
                var s = (Style) n;
                string body = group (s.body);
                if (s.color != null) {
                    string col = s.color.down ();
                    if (col.has_prefix ("#")) body = "color hex " + col.substring (1) + " " + body;
                    else body = "color " + col + " " + body;
                }
                return body;
            }
            if (n is Enclose) return group (((Enclose) n).body);
            if (n is Phantom) return "phantom" + group (((Phantom) n).body);
            if (n is Group) return group (((Group) n).body);
            return "";
        }
    }
}
