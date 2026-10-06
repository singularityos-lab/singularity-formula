namespace Singularity.Apps.Formula {

    public class UnicodeMath {
        public const string MATRIX = "\u25a0";
        public const string PMATRIX = "\u24a8";
        public const string VMATRIX = "\u24b1";
        public const string EQARRAY = "\u2588";
        public const string CASES = "\u24b8";
        public const string OF = "\u2592";
        public const string FUNCAPPLY = "\u2061";
        public const string ABOVE = "\u2534";
        public const string BELOW = "\u252c";
        public const string ATOP = "\u00a6";
        public const string SDIV = "\u2044";
        public const string BOX = "\u25a1";
        public const string RECT = "\u25ad";
        public const string OVERBAR = "\u00af";
        public const string UNDERBAR = "\u2581";
        public const string LEFT = "\u251c";
        public const string RIGHT = "\u2524";
        public const string BEGIN = "\u3016";
        public const string END = "\u3017";
        public const string ROOT = "\u24ad";
        public const string PHANTOM = "\u27e1";
        public const string HPHANTOM = "\u2b04";
        public const string VPHANTOM = "\u21f3";
        public const string EQNO = "#";

        private static Gee.HashMap<string, string>? words;

        private static void ensure () {
            if (words != null) return;
            words = new Gee.HashMap<string, string> ();
            foreach (var s in Symbols.all ()) words[s.command] = s.ch;
            string[] extra = {
                "matrix", MATRIX, "pmatrix", PMATRIX, "vmatrix", VMATRIX, "eqarray", EQARRAY, "cases", CASES,
                "of", OF, "funcapply", FUNCAPPLY, "above", ABOVE, "below", BELOW, "atop", ATOP, "sdiv", SDIV,
                "box", BOX, "rect", RECT, "overbar", OVERBAR, "underbar", UNDERBAR, "left", LEFT, "right", RIGHT,
                "begin", BEGIN, "end", END, "root", ROOT, "phantom", PHANTOM, "hphantom", HPHANTOM, "vphantom", VPHANTOM,
                "sqrt", "\u221a", "cbrt", "\u221b", "qdrt", "\u221c", "overbrace", "\u23de", "underbrace", "\u23df",
                "overparen", "\u23dc", "underparen", "\u23dd", "hat", "\u0302", "tilde", "\u0303", "bar", "\u0305",
                "dot", "\u0307", "ddot", "\u0308", "check", "\u030c", "acute", "\u0301", "grave", "\u0300",
                "breve", "\u0306", "vec", "\u20d7", "dddot", "\u20db", "thinsp", "\u2009", "medsp", "\u205f",
                "thicksp", "\u2005", "quad", "\u2003", "qquad", "\u2003\u2003", "ensp", "\u2002", "negthinsp", "\u200b",
                "infty", "\u221e", "degree", "\u00b0", "ldiv", "\u2215", "eqno", "#", "mid", "\u2223", "dots", "\u2026",
                "ldots", "\u2026", "cdots", "\u22ef", "iff", "\u27fa", "implies", "\u27f9", "to", "\u2192"
            };
            for (int i = 0; i + 1 < extra.length; i += 2) words[extra[i]] = extra[i + 1];
        }

        public static string? control_word (string w) {
            ensure ();
            return words[w];
        }

        public static string autocorrect (string text) {
            ensure ();
            var sb = new StringBuilder ();
            int i = 0;
            while (i < text.length) {
                if (text[i] == '\\' && i + 1 < text.length && text[i + 1].isalpha ()) {
                    int j = i + 1;
                    while (j < text.length && text[j].isalpha ()) j++;
                    string w = text.substring (i + 1, j - i - 1);
                    var ch = words[w];
                    if (ch != null) {
                        sb.append (ch);
                        if (text[j] == ' ') j++;
                        i = j;
                        continue;
                    }
                }
                sb.append_c (text[i]);
                i++;
            }
            return sb.str;
        }

        public static Row parse (string text) throws ParseError {
            return new UnicodeMathParser (text).parse_all ();
        }

        public static ParseResult parse_result (string text) throws ParseError {
            var p = new UnicodeMathParser (text);
            var row = p.parse_all ();
            fold_prescripts (row);
            var r = new ParseResult (row);
            r.tag = p.tag;
            return r;
        }

        public static void fold_prescripts (Row row) {
            for (int i = 0; i < row.size; i++) {
                var n = row[i];
                foreach (var slot in n.slots ()) fold_prescripts (slot);
                var g = n as Group;
                if (g == null || g.body.size != 0 || i + 1 >= row.size) continue;
                var s = row[i + 1] as Scripts;
                if (s == null || s.pre) continue;
                row.remove_at (i);
                if (i + 1 < row.size) s.pre = true;
            }
        }

        public static string write (Row row, string? tag = null) {
            var w = new UnicodeMathWriter ();
            string s = w.row (row).strip ();
            if (tag != null) s += "#(" + tag + ")";
            return s;
        }
    }

    private class UElem {
        public Row nodes = new Row ();
        public bool op;
        public bool paren;
        public bool brk;
        public string marker = "";

        public UElem.node (Node n) {
            nodes.append (n);
        }

        public UElem.row (Row r) {
            nodes.move_from (r);
        }

        public UElem.mark (string m) {
            marker = m;
        }

        public UElem.space () {
            brk = true;
        }
    }

    public class UnicodeMathParser {
        private string src;
        private int pos;
        public string? tag;
        private int depth;

        public UnicodeMathParser (string text) {
            src = UnicodeMath.autocorrect (text);
        }

        private ParseError error (string message) {
            return new ParseError.SYNTAX ("%d:%s", pos, message);
        }

        private bool at_end () {
            return pos >= src.length;
        }

        private unichar peek () {
            if (pos >= src.length) return 0;
            return src.get_char (pos);
        }

        private unichar peek_at (int offset) {
            int i = pos;
            unichar c = 0;
            for (int k = 0; k <= offset; k++) {
                if (!src.get_next_char (ref i, out c)) return 0;
            }
            return c;
        }

        private unichar next () {
            unichar c;
            int i = pos;
            if (!src.get_next_char (ref i, out c)) return 0;
            pos = i;
            return c;
        }

        public Row parse_all () throws ParseError {
            var r = parse_expr ("");
            if (!at_end ()) throw error (_("Unexpected \"%s\"").printf (peek ().to_string ()));
            return r;
        }

        private static bool is_close (unichar c) {
            return c == ')' || c == ']' || c == '}' || c == 0x27e9 || c == 0x230b || c == 0x2309 || c == 0x27e7 || c == 0x3017 || c == 0x2524;
        }

        private static bool is_open (unichar c) {
            return c == '(' || c == '[' || c == '{' || c == 0x27e8 || c == 0x230a || c == 0x2308 || c == 0x27e6 || c == 0x3016 || c == 0x251c;
        }

        private static string close_for (unichar c) {
            switch (c) {
                case '(': return ")";
                case '[': return "]";
                case '{': return "}";
                case 0x27e8: return "\u27e9";
                case 0x230a: return "\u230b";
                case 0x2308: return "\u2309";
                case 0x27e6: return "\u27e7";
                default: return "";
            }
        }

        private static bool is_combining (unichar c) {
            return (c >= 0x300 && c <= 0x36f) || (c >= 0x20d0 && c <= 0x20ff);
        }

        private static int superscript_digit (unichar c, out string plain) {
            string sup = "\u2070\u00b9\u00b2\u00b3\u2074\u2075\u2076\u2077\u2078\u2079";
            string sub = "\u2080\u2081\u2082\u2083\u2084\u2085\u2086\u2087\u2088\u2089";
            plain = "";
            for (int d = 0; d < 10; d++) {
                if (sup.get_char (sup.index_of_nth_char (d)) == c) {
                    plain = d.to_string ();
                    return 1;
                }
                if (sub.get_char (sub.index_of_nth_char (d)) == c) {
                    plain = d.to_string ();
                    return -1;
                }
            }
            switch (c) {
                case 0x207a: plain = "+"; return 1;
                case 0x207b: plain = "\u2212"; return 1;
                case 0x207c: plain = "="; return 1;
                case 0x207d: plain = "("; return 1;
                case 0x207e: plain = ")"; return 1;
                case 0x207f: plain = "n"; return 1;
                case 0x2071: plain = "i"; return 1;
                case 0x208a: plain = "+"; return -1;
                case 0x208b: plain = "\u2212"; return -1;
                case 0x208c: plain = "="; return -1;
                case 0x208d: plain = "("; return -1;
                case 0x208e: plain = ")"; return -1;
                default: return 0;
            }
        }

        private static double unicode_space (unichar c) {
            switch (c) {
                case 0x2009: return 3.0 / 18.0;
                case 0x205f: return 4.0 / 18.0;
                case 0x2005: return 5.0 / 18.0;
                case 0x2003: return 1.0;
                case 0x2002: return 0.5;
                case 0x2004: return 6.0 / 18.0;
                case 0x2006: return 3.0 / 18.0;
                case 0x200a: return 1.0 / 18.0;
                case 0x2008: return 3.0 / 18.0;
                case 0x00a0: return 1.0 / 3.0;
                default: return 0;
            }
        }

        private Row parse_expr (string stop) throws ParseError {
            depth++;
            if (depth > 200) throw error (_("The formula is nested too deeply"));
            var elems = new Gee.ArrayList<UElem> ();
            while (!at_end ()) {
                unichar c = peek ();
                if (stop.index_of_char (c) >= 0) break;
                if (is_close (c) && c != 0x2524) break;
                if (c == 0x2524 && stop.contains ("\u2524")) break;
                if (c == ' ' || c == '\t' || c == '\n') {
                    next ();
                    elems.add (new UElem.space ());
                    continue;
                }
                if (c == 0x2592 || c == 0x2061) {
                    next ();
                    if (c == 0x2061) mark_function (elems);
                    elems.add (new UElem.space ());
                    continue;
                }
                if (c == '#' && stop == "") {
                    next ();
                    var t = parse_element ();
                    tag = t != null ? UnicodeMath.write (t.nodes) : "";
                    if (tag.has_prefix ("(") && tag.has_suffix (")")) tag = tag.substring (1, tag.length - 2);
                    continue;
                }
                if (c == '^' || c == '_' || c == '/' || c == 0x00a6 || c == 0x2044 || c == 0x2534 || c == 0x252c) {
                    next ();
                    elems.add (new UElem.mark (c.to_string ()));
                    continue;
                }
                string plain;
                int sd = superscript_digit (c, out plain);
                if (sd != 0) {
                    var sr = new Row ();
                    while (!at_end ()) {
                        string p2;
                        if (superscript_digit (peek (), out p2) != sd) break;
                        next ();
                        if (p2.get_char (0).isdigit ()) sr.append (new Token.number (p2));
                        else if (p2 == "n" || p2 == "i") sr.append (new Token.ident (p2));
                        else sr.append (new Token.op (p2));
                    }
                    elems.add (new UElem.mark (sd > 0 ? "^" : "_"));
                    var ge = new UElem.row (sr);
                    ge.paren = true;
                    elems.add (ge);
                    continue;
                }
                if (is_combining (c)) {
                    next ();
                    apply_accent (elems, c.to_string ());
                    continue;
                }
                var e = parse_element ();
                if (e != null) elems.add (e);
            }
            depth--;
            return resolve (elems);
        }

        private void mark_function (Gee.ArrayList<UElem> elems) {
            var letters = new StringBuilder ();
            int k = elems.size - 1;
            while (k >= 0 && elems[k].nodes.size == 1 && elems[k].nodes[0] is Token && ((Token) elems[k].nodes[0]).kind == TokenKind.IDENT && !elems[k].brk && elems[k].marker == "") {
                letters.prepend (((Token) elems[k].nodes[0]).text);
                k--;
            }
            if (letters.len == 0) return;
            for (int j = elems.size - 1; j > k; j--) elems.remove_at (j);
            var f = new Token.ident (letters.str);
            f.forced_class = AtomClass.OP;
            elems.add (new UElem.node (f));
        }

        private void apply_accent (Gee.ArrayList<UElem> elems, string mark) {
            if (elems.size == 0) return;
            var last = elems[elems.size - 1];
            if (last.brk || last.marker != "") return;
            var body = new Row ();
            bool wide = last.paren;
            if (last.paren && last.nodes.size == 1 && last.nodes[0] is Fenced) {
                body.move_from (((Fenced) last.nodes[0]).body);
            } else {
                body.move_from (last.nodes);
            }
            string m = mark == "\u0305" ? "\u203e" : mark;
            bool stretchy = wide && body.size > 1;
            if (m == "\u203e") stretchy = true;
            var a = new Accent (m, body, stretchy, false);
            elems[elems.size - 1] = new UElem.node (a);
        }

        private Row parse_group_arg () throws ParseError {
            skip_spaces ();
            if (peek () == '(') {
                next ();
                var r = parse_expr ("");
                if (peek () != ')') throw error (_("Missing \")\""));
                next ();
                return r;
            }
            var e = parse_element ();
            if (e == null) throw error (_("Missing argument"));
            var r2 = new Row ();
            if (e.paren && e.nodes.size == 1 && e.nodes[0] is Fenced && ((Fenced) e.nodes[0]).open == "(") r2.move_from (((Fenced) e.nodes[0]).body);
            else r2.move_from (e.nodes);
            while (!at_end () && is_combining (peek ())) {
                string m = next ().to_string ();
                var inner = new Row ();
                inner.move_from (r2);
                r2.append (new Accent (m, inner, false, false));
            }
            return r2;
        }

        private void skip_spaces () {
            while (!at_end () && (peek () == ' ' || peek () == '\t')) next ();
        }

        private Table parse_table (TableKind kind) throws ParseError {
            skip_spaces ();
            if (peek () != '(') throw error (_("Missing \"(\" after the matrix"));
            next ();
            var t = new Table (kind);
            var cells = new Gee.ArrayList<Row> ();
            while (true) {
                var cell = parse_expr ("&@)");
                cells.add (cell);
                if (at_end ()) throw error (_("Missing \")\""));
                unichar c = next ();
                if (c == '&') continue;
                t.add_row_cells (cells);
                cells = new Gee.ArrayList<Row> ();
                if (c == ')') break;
            }
            t.normalize ();
            return t;
        }

        private UElem? parse_element () throws ParseError {
            if (at_end ()) return null;
            unichar c = peek ();
            if (c == '"') {
                next ();
                var r = new Row ();
                while (!at_end () && peek () != '"') {
                    unichar tc = next ();
                    if (tc == '\\' && !at_end ()) tc = next ();
                    r.append (new Token.plain (tc.to_string ()));
                    ((Token) r[r.size - 1]).variant = MathVariant.NORMAL;
                }
                if (at_end ()) throw error (_("Missing closing quote"));
                next ();
                return new UElem.row (r);
            }
            if (c == '\\' && !at_end ()) {
                next ();
                if (at_end ()) return new UElem.node (new Token.op ("\\"));
                unichar lit = next ();
                string ls = lit == '-' ? "\u2212" : lit.to_string ();
                var lt = new Token.op (ls);
                if (lit.isalpha ()) {
                    lt.kind = TokenKind.IDENT;
                }
                var le = new UElem.node (lt);
                le.op = Symbols.char_class (ls) == AtomClass.BIN || Symbols.char_class (ls) == AtomClass.REL;
                return le;
            }
            if (c.isdigit () || (c == '.' && peek_at (1).isdigit ())) {
                var r = new Row ();
                while (!at_end () && (peek ().isdigit () || (peek () == '.' && peek_at (1).isdigit ()))) r.append (new Token.number (next ().to_string ()));
                return new UElem.row (r);
            }
            double sp = unicode_space (c);
            if (sp != 0) {
                next ();
                double total = sp;
                while (!at_end () && unicode_space (peek ()) != 0) total += unicode_space (next ());
                return new UElem.node (new Space (total));
            }
            if (c == 0x2502) {
                next ();
                var mid = new Token.op ("|");
                mid.fence_middle = true;
                return new UElem.node (mid);
            }
            if (c == 0x200b) {
                next ();
                return new UElem.node (new Space (-3.0 / 18.0));
            }
            if (c == 0x3016) {
                next ();
                var r = parse_expr ("\u3017");
                if (peek () != 0x3017) throw error (_("Missing closing bracket"));
                next ();
                if (r.size > 1 || r.size == 0) return new UElem.node (new Group (r));
                var e = new UElem.row (r);
                e.paren = true;
                return e;
            }
            if (c == 0x251c) {
                next ();
                string open = delimiter_after ();
                var body = parse_expr ("\u2524");
                if (peek () != 0x2524) throw error (_("Missing closing delimiter"));
                next ();
                string close = delimiter_after ();
                return new UElem.node (new Fenced (open, close, body));
            }
            if (is_open (c)) {
                next ();
                string close = close_for (c);
                var body = parse_expr ("");
                if (at_end ()) throw error (_("Missing \"%s\"").printf (close));
                unichar got = peek ();
                if (got.to_string () != close) {
                    if (got == 0x2524) {
                        next ();
                        close = delimiter_after ();
                        return new UElem.node (new Fenced (c.to_string (), close, body));
                    }
                    throw error (_("Missing \"%s\"").printf (close));
                }
                next ();
                if (body.size == 1 && body[0] is Table && c != '(') {
                    var t = (Table) body[0];
                    if (t.kind == TableKind.MATRIX) {
                        if (c == '[') t.kind = TableKind.BMATRIX;
                        else if (c == '{') t.kind = TableKind.BRACE_MATRIX;
                        if (t.kind != TableKind.MATRIX) return new UElem.node (body.remove_at (0));
                    }
                }
                if (body.size == 1 && body[0] is Table && c == '(' && ((Table) body[0]).kind == TableKind.MATRIX) {
                    ((Table) body[0]).kind = TableKind.PMATRIX;
                    return new UElem.node (body.remove_at (0));
                }
                var e = new UElem.node (new Fenced (c.to_string (), close, body));
                e.paren = c == '(';
                return e;
            }
            if (c == '|' || c == 0x2016) {
                next ();
                string d = c.to_string ();
                int save = pos;
                try {
                    var body = parse_expr (d);
                    if (!at_end () && peek () == c && body.size > 0) {
                        next ();
                        if (body.size == 1 && body[0] is Table && ((Table) body[0]).kind == TableKind.MATRIX) {
                            ((Table) body[0]).kind = c == '|' ? TableKind.VMATRIX : TableKind.DOUBLE_VMATRIX;
                            return new UElem.node (body.remove_at (0));
                        }
                        return new UElem.node (new Fenced (d, d, body));
                    }
                } catch (ParseError e) {
                }
                pos = save;
                var bar = new Token.op (d);
                return new UElem.node (bar);
            }
            string cs = c.to_string ();
            switch (cs) {
                case UnicodeMath.MATRIX:
                    next ();
                    return new UElem.node (parse_table (TableKind.MATRIX));
                case UnicodeMath.PMATRIX:
                    next ();
                    return new UElem.node (parse_table (TableKind.PMATRIX));
                case UnicodeMath.VMATRIX:
                    next ();
                    return new UElem.node (parse_table (TableKind.VMATRIX));
                case UnicodeMath.CASES:
                    next ();
                    return new UElem.node (parse_table (TableKind.CASES));
                case UnicodeMath.EQARRAY:
                    next ();
                    var eq = parse_table (TableKind.ALIGN);
                    if (eq.column_count == 1) eq.kind = TableKind.GATHER;
                    return new UElem.node (eq);
                case "\u221a":
                    next ();
                    skip_spaces ();
                    if (peek () == '(') {
                        int save = pos;
                        next ();
                        var first = parse_expr ("&");
                        if (peek () == '&') {
                            next ();
                            var body = parse_expr ("");
                            if (peek () != ')') throw error (_("Missing \")\""));
                            next ();
                            return new UElem.node (new Radical (body, first));
                        }
                        pos = save;
                    }
                    return new UElem.node (new Radical (parse_group_arg ()));
                case "\u221b":
                case "\u221c":
                    next ();
                    var idx = new Row ();
                    idx.append (new Token.number (cs == "\u221b" ? "3" : "4"));
                    return new UElem.node (new Radical (parse_group_arg (), idx));
                case UnicodeMath.ROOT:
                    next ();
                    var rindex = parse_expr (UnicodeMath.OF);
                    if (peek () == 0x2592) next ();
                    return new UElem.node (new Radical (parse_group_arg (), rindex));
                case UnicodeMath.BOX:
                case UnicodeMath.RECT:
                    next ();
                    return new UElem.node (new Enclose ("box", parse_group_arg ()));
                case UnicodeMath.OVERBAR:
                    next ();
                    return new UElem.node (new Accent ("\u203e", parse_group_arg (), true, false));
                case UnicodeMath.UNDERBAR:
                    next ();
                    return new UElem.node (new Accent ("_", parse_group_arg (), true, true));
                case "\u23de":
                case "\u23df":
                case "\u23dc":
                case "\u23dd":
                case "\u23b4":
                case "\u23b5":
                    next ();
                    bool under = cs == "\u23df" || cs == "\u23dd" || cs == "\u23b5";
                    return new UElem.node (new Accent (cs, parse_group_arg (), true, under));
                case UnicodeMath.PHANTOM:
                    next ();
                    return new UElem.node (new Phantom (parse_group_arg ()));
                case UnicodeMath.HPHANTOM:
                    next ();
                    var hp = new Phantom (parse_group_arg ());
                    hp.keep_height = false;
                    return new UElem.node (hp);
                case UnicodeMath.VPHANTOM:
                    next ();
                    var vp = new Phantom (parse_group_arg ());
                    vp.keep_width = false;
                    return new UElem.node (vp);
                default:
                    break;
            }
            next ();
            MathVariant v;
            unichar base_c = Unimath.from_styled (c, out v);
            if (base_c.isalpha () && !is_combining (base_c)) {
                if (v == MathVariant.DEFAULT && base_c >= 'a' && base_c <= 'z' || v == MathVariant.DEFAULT && base_c >= 'A' && base_c <= 'Z') {
                    int start = pos - 1;
                    int end = pos;
                    while (end < src.length && src[end].isalpha () && src[end] < 128) end++;
                    string word = src.substring (start, end - start);
                    string? fname = longest_function (word);
                    if (fname != null && (start + fname.length == src.length || !src[start + fname.length].isalpha () || fname.length == word.length)) {
                        int after = start + fname.length;
                        bool followed = after >= src.length || src[after] == ' ' || src[after] == '(' || src[after] == '_' || src[after] == '^' || !src[after].isalpha () || src.substring (after).has_prefix (UnicodeMath.FUNCAPPLY);
                        if (followed) {
                            pos = after;
                            var f = new Token.ident (fname);
                            f.forced_class = AtomClass.OP;
                            return new UElem.node (f);
                        }
                    }
                }
                var t = new Token.ident (base_c.to_string ());
                if (v == MathVariant.ITALIC) v = MathVariant.DEFAULT;
                t.variant = v;
                return new UElem.node (t);
            }
            if (v != MathVariant.DEFAULT && base_c.isdigit ()) {
                var t = new Token.number (base_c.to_string ());
                t.variant = v;
                return new UElem.node (t);
            }
            string s = cs;
            if (s == "-") s = "\u2212";
            if (s == "*") s = "\u2217";
            if (s == "'") s = "\u2032";
            var tok = new Token.op (s);
            if (s == "\u2032") {
                tok.prime = true;
                var sr = new Row ();
                sr.append (tok);
                while (!at_end () && (peek () == '\'' || peek () == 0x2032)) {
                    next ();
                    var t2 = new Token.op ("\u2032");
                    t2.prime = true;
                    sr.append (t2);
                }
                var pe = new UElem.row (sr);
                pe.marker = "prime";
                return pe;
            }
            var sym = Symbols.by_char (s);
            if (sym != null && sym.category == "greek") tok.kind = TokenKind.IDENT;
            else if (sym != null && sym.cls == AtomClass.ORD && s.get_char (0).isalpha ()) tok.kind = TokenKind.IDENT;
            var e2 = new UElem.node (tok);
            AtomClass cls = Symbols.char_class (s);
            e2.op = cls == AtomClass.BIN || cls == AtomClass.REL || cls == AtomClass.PUNCT || (Symbols.is_large_op (s) && false);
            return e2;
        }

        private static string? longest_function (string word) {
            string? best = null;
            foreach (var f in Symbols.FUNCTION_NAMES) {
                if (word.has_prefix (f) && (best == null || f.length > best.length)) best = f;
            }
            return best;
        }

        private string delimiter_after () {
            if (at_end ()) return "";
            unichar c = next ();
            if (c == '.' || c == ' ') return "";
            return c.to_string ();
        }

        private bool is_operand (UElem e) {
            return !e.brk && e.marker == "" && !e.op;
        }

        private Row take_operand_right (Gee.ArrayList<UElem> elems, int from, out int consumed) {
            var r = new Row ();
            consumed = 0;
            int i = from;
            if (i < elems.size && elems[i].paren && is_operand (elems[i])) {
                var e = elems[i];
                if (e.nodes.size == 1 && e.nodes[0] is Fenced) r.move_from (((Fenced) e.nodes[0]).body);
                else r.move_from (e.nodes);
                consumed = 1;
                return r;
            }
            while (i < elems.size && is_operand (elems[i])) {
                r.move_from (elems[i].nodes);
                i++;
                consumed++;
            }
            if (consumed == 0 && i < elems.size && elems[i].op && !elems[i].brk) {
                r.move_from (elems[i].nodes);
                consumed = 1;
                i++;
                while (i < elems.size && is_operand (elems[i])) {
                    r.move_from (elems[i].nodes);
                    i++;
                    consumed++;
                }
            }
            return r;
        }

        private Row resolve (Gee.ArrayList<UElem> elems) throws ParseError {
            for (int i = 0; i < elems.size; i++) {
                var e = elems[i];
                if (e.marker == "prime") {
                    var sr = new Row ();
                    sr.move_from (e.nodes);
                    elems[i] = new UElem.node (new Scripts (null, sr));
                    if (i + 1 < elems.size && (elems[i + 1].marker == "^" || elems[i + 1].marker == "_")) {
                    }
                }
            }
            for (int i = 0; i < elems.size; i++) {
                var e = elems[i];
                if (e.marker != "^" && e.marker != "_" && e.marker != "\u2534" && e.marker != "\u252c") continue;
                int consumed;
                var arg = take_operand_right (elems, i + 1, out consumed);
                if (consumed == 0) throw error (_("\"%s\" needs an argument").printf (e.marker));
                bool sup = e.marker == "^" || e.marker == "\u2534";
                bool above = e.marker == "\u2534" || e.marker == "\u252c";
                for (int k = 0; k < consumed; k++) elems.remove_at (i + 1);
                elems.remove_at (i);
                if (above && i > 0 && elems[i - 1].nodes.size == 1 && !(elems[i - 1].nodes[0] is Scripts)) {
                    var prev = elems[i - 1];
                    var bn = prev.nodes[0];
                    bool lim_op = bn is Token && (Symbols.is_large_op (((Token) bn).text) || ((Token) bn).forced_class == AtomClass.OP);
                    if (!lim_op) {
                        var body = new Row ();
                        body.move_from (prev.nodes);
                        var uo = new UnderOver (body, sup ? null : arg, sup ? arg : null);
                        elems[i - 1] = new UElem.node (uo);
                        i--;
                        continue;
                    }
                    if (bn is Token && !Symbols.has_limits (((Token) bn).text) && !Symbols.function_has_limits (((Token) bn).text)) ((Token) bn).limits = 1;
                }
                if (above && i > 0 && elems[i - 1].nodes.size == 1 && elems[i - 1].nodes[0] is UnderOver) {
                    var uo = (UnderOver) elems[i - 1].nodes[0];
                    if (sup && uo.over == null) {
                        uo.over = arg;
                        arg.parent = uo;
                        i--;
                        continue;
                    }
                    if (!sup && uo.under == null) {
                        uo.under = arg;
                        arg.parent = uo;
                        i--;
                        continue;
                    }
                }
                Scripts? s = null;
                if (i > 0 && elems[i - 1].nodes.size > 0 && !elems[i - 1].brk) {
                    var ln = elems[i - 1].nodes[elems[i - 1].nodes.size - 1];
                    s = ln as Scripts;
                }
                if (s != null && ((sup && s.sup == null) || (!sup && s.sub == null))) {
                    if (sup) s.set_sup (arg);
                    else s.set_sub (arg);
                } else {
                    var ns = new Scripts (sup ? null : arg, sup ? arg : null);
                    if (i > 0 && !elems[i - 1].brk && elems[i - 1].marker == "") {
                        elems[i - 1].nodes.append (ns);
                        elems[i - 1].paren = false;
                    } else {
                        elems.insert (i, new UElem.node (ns));
                        i++;
                    }
                }
                i--;
            }
            for (int i = 0; i < elems.size; i++) {
                var e = elems[i];
                if (e.marker != "/" && e.marker != "\u00a6" && e.marker != "\u2044") continue;
                var num = new Row ();
                int j = i - 1;
                if (j >= 0 && elems[j].paren && is_operand (elems[j])) {
                    var pe = elems[j];
                    if (pe.nodes.size == 1 && pe.nodes[0] is Fenced) num.move_from (((Fenced) pe.nodes[0]).body);
                    else num.move_from (pe.nodes);
                    j--;
                } else {
                    var parts = new Gee.ArrayList<UElem> ();
                    while (j >= 0 && is_operand (elems[j])) {
                        parts.insert (0, elems[j]);
                        j--;
                    }
                    foreach (var p in parts) num.move_from (p.nodes);
                }
                int consumed;
                var den = take_operand_right (elems, i + 1, out consumed);
                if (consumed == 0) throw error (_("A fraction needs a denominator"));
                var f = new Frac (num, den);
                if (e.marker == "\u00a6") f.line = false;
                if (e.marker == "\u2044") f.bevelled = true;
                int start = j + 1;
                int count = (i - start) + 1 + consumed;
                for (int k = 0; k < count; k++) elems.remove_at (start);
                elems.insert (start, new UElem.node (f));
                i = start;
            }
            var row = new Row ();
            foreach (var e in elems) {
                if (e.marker != "" && e.marker != "prime") throw error (_("\"%s\" needs an argument").printf (e.marker));
                row.move_from (e.nodes);
            }
            return row;
        }
    }

    public class UnicodeMathWriter {
        public string row (Row r) {
            var sb = new StringBuilder ();
            string prev = "";
            for (int i = 0; i < r.size; i++) {
                string s = node (r[i], i > 0 ? r[i - 1] : null, i + 1 < r.size ? r[i + 1] : null);
                if (s == "") continue;
                if (needs_space (prev, s, i > 0 ? r[i - 1] : null, r[i])) sb.append_c (' ');
                sb.append (s);
                prev = s;
            }
            return sb.str;
        }

        private static bool needs_space (string prev, string next, Node? pn, Node n) {
            if (prev == "") return false;
            if (pn is Token && ((Token) pn).kind == TokenKind.IDENT && ((Token) pn).text.char_count () > 1) return true;
            if (pn is Scripts && n is Token && ((Token) n).kind != TokenKind.OPERATOR) return true;
            if (pn is Scripts && !(n is Token) && !(n is Scripts)) return true;
            if (pn is Token && Symbols.is_large_op (((Token) pn).text) && !(n is Scripts)) return true;
            unichar a = prev.get_char (prev.index_of_nth_char (prev.char_count () - 1));
            unichar b = next.get_char (0);
            if (a.isalpha () && b.isalpha () && (pn is Token) && ((Token) pn).text.char_count () > 1) return true;
            if (n is Token && ((Token) n).kind == TokenKind.IDENT && ((Token) n).text.char_count () > 1 && a.isalpha ()) return true;
            if (n is Frac && (a == '/' || a.isalnum () || a == ')')) return true;
            if (pn is Frac && (b.isalnum () || b == '(')) return true;
            return false;
        }

        private bool simple_operand (Row r) {
            if (r.size == 0) return false;
            if (r.size == 1) {
                var n = r[0];
                if (n is Fenced) return false;
                if (n is Token) return ((Token) n).kind != TokenKind.OPERATOR || !is_breaking (((Token) n).text);
                if (n is Scripts) return false;
                return !(n is Space) && !(n is Frac);
            }
            foreach (var n in r.items) {
                var t = n as Token;
                if (t == null) return false;
                if (t.kind != TokenKind.NUMBER) return false;
            }
            return true;
        }

        private static bool is_breaking (string s) {
            var c = Symbols.char_class (s);
            return c == AtomClass.BIN || c == AtomClass.REL || c == AtomClass.PUNCT || s == "/" || s == "^" || s == "_";
        }

        private string operand (Row r) {
            string s = row (r);
            if (simple_operand (r)) return s;
            return "(" + s + ")";
        }

        private string frac_operand (Row r) {
            if (r.size == 0) return "()";
            bool simple = true;
            foreach (var n in r.items) {
                if (n is Token && ((Token) n).kind == TokenKind.OPERATOR) simple = false;
                if (n is Token && ((Token) n).kind == TokenKind.IDENT && ((Token) n).text.char_count () > 1) simple = false;
                if (n is Fenced || n is Space || n is Frac || n is Table) simple = false;
            }
            if (r.size == 1 && r[0] is Scripts) simple = false;
            string s = row (r);
            return simple ? s : "(" + s + ")";
        }

        private static string token_text (Token t) {
            string s = t.text;
            if (t.kind == TokenKind.OPERATOR) {
                if (s == "\u2212") return "-";
                if (s == "\u2217") return "*";
                if (t.fence_middle && s == "|") return "\u2502";
                if (t.fixed || (Symbols.is_fence (s) && !t.fence_middle)) return "\\" + s;
                return s;
            }
            if (t.kind == TokenKind.IDENT && s.char_count () > 1) {
                string compact = s.replace (" ", "");
                if (Symbols.is_function (compact)) return compact;
                return s + UnicodeMath.FUNCAPPLY;
            }
            if (t.variant != MathVariant.DEFAULT && t.variant != MathVariant.NORMAL && s.char_count () == 1) {
                return Unimath.styled (s.get_char (0), t.variant).to_string ();
            }
            if (t.kind == TokenKind.TEXT) return s;
            if (t.error) return s;
            return s;
        }

        private string space_text (double w) {
            double[] widths = { 3.0 / 18.0, 4.0 / 18.0, 5.0 / 18.0, 1.0, 0.5, 2.0, 1.0 / 3.0, -3.0 / 18.0 };
            string[] chars = { "\u2009", "\u205f", "\u2005", "\u2003", "\u2002", "\u2003\u2003", "\u00a0", "\u200b" };
            for (int i = 0; i < widths.length; i++) if (Math.fabs (widths[i] - w) < 1e-4) return chars[i];
            return "\u2009";
        }

        public string node (Node n, Node? prev, Node? next) {
            if (n is Token) {
                var t = (Token) n;
                if (t.kind == TokenKind.TEXT) {
                    string q = t.text == "\"" ? "\\\"" : t.text;
                    bool first = !(prev is Token && ((Token) prev).kind == TokenKind.TEXT);
                    bool last = !(next is Token && ((Token) next).kind == TokenKind.TEXT);
                    return (first ? "\"" : "") + q + (last ? "\"" : "");
                }
                return token_text (t);
            }
            if (n is Space) return space_text (((Space) n).width);
            if (n is Frac) {
                var f = (Frac) n;
                string op = f.bevelled ? UnicodeMath.SDIV : (f.line ? "/" : UnicodeMath.ATOP);
                return frac_operand (f.num) + op + frac_operand (f.den);
            }
            if (n is Radical) {
                var r = (Radical) n;
                if (r.index == null) return "\u221a" + operand (r.body);
                if (r.index.size == 1 && r.index[0] is Token && ((Token) r.index[0]).text == "3") return "\u221b" + operand (r.body);
                if (r.index.size == 1 && r.index[0] is Token && ((Token) r.index[0]).text == "4") return "\u221c" + operand (r.body);
                return "\u221a(" + row (r.index) + "&" + row (r.body) + ")";
            }
            if (n is Ref) {
                var rf = (Ref) n;
                string num = MathmlWriter.refs != null && MathmlWriter.refs.has_key (rf.name) ? MathmlWriter.refs[rf.name] : "?";
                return "\"" + (rf.paren ? MathmlWriter.wrap_label (num) : num) + "\"";
            }
            if (n is Scripts && ((Scripts) n).pre) {
                var ps = (Scripts) n;
                var pb = new StringBuilder (UnicodeMath.BEGIN + UnicodeMath.END);
                if (ps.sub != null) pb.append ("_").append (operand (ps.sub));
                if (ps.sup != null) pb.append ("^").append (operand (ps.sup));
                pb.append (" ");
                return pb.str;
            }
            if (n is Scripts) {
                var s = (Scripts) n;
                var sb = new StringBuilder ();
                bool attach_limits = prev is Token && ((Token) prev).limits == 1 && !Symbols.has_limits (((Token) prev).text);
                if (s.sup != null && LatexParser.is_prime_row (s.sup)) {
                    for (int i = 0; i < s.sup.size; i++) sb.append ("'");
                    if (s.sub != null) sb.append ("_").append (operand (s.sub));
                    return sb.str;
                }
                if (prev == null || prev is Space || prev is Scripts) sb.append ("\u3016\u3017");
                if (s.sub != null) sb.append (attach_limits ? UnicodeMath.BELOW : "_").append (operand (s.sub));
                if (s.sup != null) sb.append (attach_limits ? UnicodeMath.ABOVE : "^").append (operand (s.sup));
                return sb.str;
            }
            if (n is UnderOver) {
                var u = (UnderOver) n;
                var sb = new StringBuilder ();
                string body = row (u.body);
                if (!(u.body.size == 1 && (u.body[0] is Token))) body = "\u3016" + body + "\u3017";
                sb.append (body);
                if (u.under != null) sb.append (UnicodeMath.BELOW).append (operand (u.under));
                if (u.over != null) sb.append (UnicodeMath.ABOVE).append (operand (u.over));
                return sb.str;
            }
            if (n is Accent) {
                var a = (Accent) n;
                if (a.is_brace ()) return a.mark + operand (a.body);
                if (a.mark == "\u203e") return UnicodeMath.OVERBAR + operand (a.body);
                if (a.mark == "_") return UnicodeMath.UNDERBAR + operand (a.body);
                string mark = a.mark;
                unichar mc = mark.get_char (0);
                if (!((mc >= 0x300 && mc <= 0x36f) || (mc >= 0x20d0 && mc <= 0x20ff))) {
                    var mr = new Row ();
                    mr.append (new Token.op (mark));
                    return "\u3016" + row (a.body) + "\u3017" + (a.under ? UnicodeMath.BELOW : UnicodeMath.ABOVE) + row (mr);
                }
                string body = row (a.body);
                if (a.stretchy || !(a.body.size == 1 && a.body[0] is Token && ((Token) a.body[0]).text.char_count () == 1)) body = "(" + body + ")";
                return body + mark;
            }
            if (n is Fenced) {
                var f = (Fenced) n;
                string body = row (f.body);
                string? close = Symbols.matching_close (f.open);
                bool auto_pair = f.open != "" && close == f.close && (f.open != "|" || body.length > 0);
                if (auto_pair && f.open != "\u2016") {
                    foreach (var bn in f.body.items) if (bn is Token && ((Token) bn).fence_middle) auto_pair = false;
                }
                if (auto_pair) return f.open + body + f.close;
                return UnicodeMath.LEFT + (f.open == "" ? "." : f.open) + body + UnicodeMath.RIGHT + (f.close == "" ? "." : f.close);
            }
            if (n is Table) {
                var t = (Table) n;
                var sb = new StringBuilder ();
                for (int r = 0; r < t.rows.size; r++) {
                    if (r > 0) sb.append ("@");
                    for (int c = 0; c < t.rows[r].size; c++) {
                        if (c > 0) sb.append ("&");
                        sb.append (row (t.rows[r][c]));
                    }
                }
                string inner = "(" + sb.str + ")";
                switch (t.kind) {
                    case TableKind.PMATRIX: return UnicodeMath.PMATRIX + inner;
                    case TableKind.VMATRIX: return UnicodeMath.VMATRIX + inner;
                    case TableKind.BMATRIX: return "[" + UnicodeMath.MATRIX + inner + "]";
                    case TableKind.BRACE_MATRIX: return "{" + UnicodeMath.MATRIX + inner + "}";
                    case TableKind.DOUBLE_VMATRIX: return "\u2016" + UnicodeMath.MATRIX + inner + "\u2016";
                    case TableKind.CASES: return UnicodeMath.CASES + inner;
                    case TableKind.ALIGN: case TableKind.GATHER: return UnicodeMath.EQARRAY + inner;
                    default: return UnicodeMath.MATRIX + inner;
                }
            }
            if (n is Style) return "\u3016" + row (((Style) n).body) + "\u3017";
            if (n is Enclose) return UnicodeMath.RECT + operand (((Enclose) n).body);
            if (n is Phantom) {
                var p = (Phantom) n;
                string ph = p.keep_width && p.keep_height ? UnicodeMath.PHANTOM : (p.keep_width ? UnicodeMath.HPHANTOM : UnicodeMath.VPHANTOM);
                return ph + operand (p.body);
            }
            if (n is Group) return "\u3016" + row (((Group) n).body) + "\u3017";
            return "";
        }
    }
}
