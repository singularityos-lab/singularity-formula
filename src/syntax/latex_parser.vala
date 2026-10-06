namespace Singularity.Apps.Formula {

    public errordomain ParseError {
        SYNTAX
    }

    public class ParseResult {
        public Row root;
        public string? tag;
        public bool notag;
        public string? label;

        public ParseResult (Row root) {
            this.root = root;
        }
    }

    public class LatexParser {
        private string src;
        private int pos;
        private string? row_tag;
        private bool row_notag;
        private string? row_label;
        private int depth;

        private LatexParser (string text) {
            src = text;
            pos = 0;
        }

        public static ParseResult parse (string text) throws ParseError {
            var p = new LatexParser (text);
            var root = p.parse_row (Stop.EOF);
            if (p.pos < p.src.length) throw p.error (_("Unexpected \"%s\"").printf (p.peek_str ()));
            var res = new ParseResult (root);
            res.tag = p.row_tag;
            res.notag = p.row_notag;
            res.label = p.row_label;
            return res;
        }

        public static Row parse_row_text (string text) throws ParseError {
            return parse (text).root;
        }

        [Flags]
        private enum Stop {
            EOF = 1,
            BRACE = 2,
            BRACKET = 4,
            CELL = 8,
            RIGHT = 16,
            END = 32
        }

        private ParseError error (string message) {
            return new ParseError.SYNTAX ("%d:%s", pos, message);
        }

        public static int error_position (ParseError e) {
            int colon = e.message.index_of (":");
            if (colon <= 0) return -1;
            return int.parse (e.message.substring (0, colon));
        }

        public static string error_message (ParseError e) {
            int colon = e.message.index_of (":");
            return colon > 0 ? e.message.substring (colon + 1) : e.message;
        }

        private bool at_end () {
            return pos >= src.length;
        }

        private unichar peek () {
            if (pos >= src.length) return 0;
            return src.get_char (pos);
        }

        private string peek_str () {
            if (pos >= src.length) return "";
            return peek ().to_string ();
        }

        private unichar next () {
            unichar c;
            int i = pos;
            if (!src.get_next_char (ref i, out c)) return 0;
            pos = i;
            return c;
        }

        private void skip_space () {
            while (!at_end ()) {
                unichar c = peek ();
                if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                    next ();
                } else if (c == '%') {
                    while (!at_end () && peek () != '\n') next ();
                } else {
                    break;
                }
            }
        }

        private bool looking_at (string s) {
            return src.substring (pos).has_prefix (s);
        }

        private string read_command_name () {
            int start = pos;
            if (at_end ()) return "";
            unichar c = peek ();
            if (c.isalpha () && c < 128) {
                while (!at_end () && peek ().isalpha () && peek () < 128) next ();
                if (!at_end () && peek () == '*') {
                    string n = src.substring (start, pos - start);
                    if (n == "operatorname" || n == "tag" || n == "align" || n == "gather") next ();
                }
            } else {
                next ();
            }
            return src.substring (start, pos - start);
        }

        private string peek_command () {
            if (at_end () || peek () != '\\') return "";
            int save = pos;
            next ();
            string n = read_command_name ();
            pos = save;
            return n;
        }

        private Row parse_row (Stop stop) throws ParseError {
            depth++;
            if (depth > 200) throw error (_("The formula is nested too deeply"));
            var row = new Row ();
            Row? numerator = null;
            string infix = "";
            while (true) {
                skip_space ();
                if (at_end ()) {
                    if (Stop.EOF in stop) break;
                    throw error (_("Missing closing brace"));
                }
                unichar c = peek ();
                if (c == '}') {
                    if (Stop.BRACE in stop) break;
                    throw error (_("Unmatched closing brace"));
                }
                if (c == ']' && Stop.BRACKET in stop) break;
                if (c == '&') {
                    if (Stop.CELL in stop) break;
                    throw error (_("\"&\" is only allowed inside a matrix or an alignment"));
                }
                if (c == '\\') {
                    string cmd = peek_command ();
                    if (cmd == "\\" || cmd == "cr") {
                        if (Stop.CELL in stop) break;
                        next ();
                        read_command_name ();
                        continue;
                    }
                    if (cmd == "right" || cmd == "middle") {
                        if (Stop.RIGHT in stop) break;
                        throw error (_("\"\\%s\" without a matching \"\\left\"").printf (cmd));
                    }
                    if (cmd == "end") {
                        if (Stop.END in stop || Stop.CELL in stop) break;
                        throw error (_("\"\\end\" without a matching \"\\begin\""));
                    }
                    if (cmd == "over" || cmd == "atop" || cmd == "choose" || cmd == "above" || cmd == "brace" || cmd == "brack") {
                        next ();
                        read_command_name ();
                        if (cmd == "above") parse_dimension_arg ();
                        numerator = row;
                        row = new Row ();
                        infix = cmd;
                        continue;
                    }
                    if (cmd == "displaystyle" || cmd == "textstyle" || cmd == "scriptstyle" || cmd == "scriptscriptstyle" || cmd == "color") {
                        next ();
                        read_command_name ();
                        var st = new Style ();
                        switch (cmd) {
                            case "displaystyle": st.display = 1; st.script_level = 0; break;
                            case "textstyle": st.display = 0; st.script_level = 0; break;
                            case "scriptstyle": st.display = 0; st.script_level = 1; break;
                            case "scriptscriptstyle": st.display = 0; st.script_level = 2; break;
                            default: st.color = read_braced_text (); break;
                        }
                        var rest = parse_row (stop);
                        st.body.move_from (rest);
                        row.append (st);
                        break;
                    }
                }
                parse_atom (row);
            }
            depth--;
            Fences.rebuild (row);
            if (numerator != null) {
                var frac = new Frac (numerator, row);
                var result = new Row ();
                if (infix == "atop") frac.line = false;
                if (infix == "choose" || infix == "brace" || infix == "brack") {
                    frac.line = false;
                    string o = infix == "choose" ? "(" : (infix == "brace" ? "{" : "[");
                    string cl = infix == "choose" ? ")" : (infix == "brace" ? "}" : "]");
                    var body = new Row ();
                    body.append (frac);
                    result.append (new Fenced (o, cl, body));
                } else {
                    result.append (frac);
                }
                return result;
            }
            return row;
        }

        private Row parse_argument () throws ParseError {
            skip_space ();
            if (at_end ()) throw error (_("Missing argument"));
            unichar c = peek ();
            if (c == '{') {
                next ();
                var r = parse_row (Stop.BRACE);
                expect ('}');
                return r;
            }
            if (c == '}' || c == '&' || c == '^' || c == '_') throw error (_("Missing argument"));
            var row = new Row ();
            parse_atom (row, true);
            return row;
        }

        private Row? parse_optional () throws ParseError {
            skip_space ();
            if (peek () != '[') return null;
            next ();
            var r = parse_row (Stop.BRACKET | Stop.BRACE);
            expect (']');
            return r;
        }

        private void expect (unichar c) throws ParseError {
            skip_space ();
            if (peek () != c) throw error (_("Expected \"%s\"").printf (c.to_string ()));
            next ();
        }

        private string read_braced_text () throws ParseError {
            skip_space ();
            if (peek () != '{') {
                if (at_end ()) throw error (_("Missing argument"));
                return next ().to_string ();
            }
            next ();
            int start = pos;
            int level = 1;
            while (!at_end ()) {
                unichar c = peek ();
                if (c == '\\') {
                    next ();
                    if (!at_end ()) next ();
                    continue;
                }
                if (c == '{') level++;
                if (c == '}') {
                    level--;
                    if (level == 0) break;
                }
                next ();
            }
            if (at_end ()) throw error (_("Missing closing brace"));
            string s = src.substring (start, pos - start);
            next ();
            return s;
        }

        private double parse_dimension_arg () throws ParseError {
            skip_space ();
            string t;
            if (peek () == '{') {
                t = read_braced_text ();
            } else {
                int start = pos;
                while (!at_end () && (peek ().isdigit () || peek () == '.' || peek () == '-' || peek () == '+')) next ();
                while (!at_end () && peek ().isalpha ()) {
                    next ();
                    if (pos - start > 12) break;
                }
                t = src.substring (start, pos - start);
            }
            return dimension_to_em (t);
        }

        public static double dimension_to_em (string text) {
            string t = text.strip ();
            int i = 0;
            while (i < t.length && (t[i].isdigit () || t[i] == '.' || t[i] == '-' || t[i] == '+')) i++;
            double v = double.parse (t.substring (0, i));
            string unit = t.substring (i).strip ();
            switch (unit) {
                case "mu": return v / 18.0;
                case "ex": return v * 0.43;
                case "pt": return v / 10.0;
                case "px": return v / 16.0;
                case "cm": return v * 28.45 / 10.0;
                case "mm": return v * 2.845 / 10.0;
                case "in": return v * 72.27 / 10.0;
                default: return v;
            }
        }

        private string read_delimiter () throws ParseError {
            skip_space ();
            if (at_end ()) throw error (_("Missing delimiter"));
            string name;
            if (peek () == '\\') {
                next ();
                name = "\\" + read_command_name ();
            } else {
                name = next ().to_string ();
            }
            var d = Symbols.delimiter (name);
            if (d == null) {
                var sym = name.has_prefix ("\\") ? Symbols.by_command (name.substring (1)) : null;
                if (sym != null) return sym.ch;
                throw error (_("\"%s\" is not a delimiter").printf (name));
            }
            return d;
        }

        private void attach_script (Row row, bool sup) throws ParseError {
            var arg = parse_argument ();
            Scripts? s = null;
            if (row.size > 0) s = row[row.size - 1] as Scripts;
            if (s != null && !s.pre && ((sup && s.sup == null) || (!sup && s.sub == null))) {
                if (sup) s.set_sup (arg);
                else s.set_sub (arg);
                return;
            }
            s = new Scripts (sup ? null : arg, sup ? arg : null);
            row.append (s);
        }

        private void add_prime (Row row, int count) {
            Scripts? s = null;
            if (row.size > 0) s = row[row.size - 1] as Scripts;
            if (s == null || s.pre || (s.sup != null && !is_prime_row (s.sup))) {
                s = new Scripts (null, new Row ());
                row.append (s);
            } else if (s.sup == null) {
                s.set_sup (new Row ());
            }
            for (int i = 0; i < count; i++) {
                var t = new Token.op ("\u2032");
                t.prime = true;
                s.sup.append (t);
            }
        }

        public static bool is_prime_row (Row r) {
            if (r.size == 0) return false;
            foreach (var n in r.items) {
                var t = n as Token;
                if (t == null || !t.prime) return false;
            }
            return true;
        }

        private void parse_atom (Row row, bool single = false) throws ParseError {
            skip_space ();
            unichar c = peek ();
            if (c == '{') {
                next ();
                var body = parse_row (Stop.BRACE);
                expect ('}');
                skip_space ();
                bool scripts_follow = !at_end () && (peek () == '^' || peek () == '_');
                if (body.size == 0) {
                    if (single) {
                        row.append (new Group (body));
                        return;
                    }
                    if (scripts_follow) {
                        var tmp = new Row ();
                        tmp.append (new Group ());
                        while (!at_end () && (peek () == '^' || peek () == '_')) {
                            bool up = next () == '^';
                            attach_script (tmp, up);
                            skip_space ();
                        }
                        bool base_follows = !at_end () && peek () != '}' && peek () != '&' && peek () != ']' && peek_command () != "\\" && peek_command () != "right" && peek_command () != "end";
                        var ps = tmp[tmp.size - 1] as Scripts;
                        if (ps != null && base_follows) {
                            tmp.remove_at (tmp.size - 1);
                            ps.pre = true;
                            row.append (ps);
                        } else {
                            row.move_from (tmp);
                        }
                    }
                    return;
                }
                if (single) {
                    row.move_from (body);
                    return;
                }
                if (body.size == 1 && !(body[0] is Token && ((Token) body[0]).kind == TokenKind.OPERATOR) && !(body[0] is Scripts)) {
                    row.move_from (body);
                    return;
                }
                if (scripts_follow || body.size > 1 || body[0] is Token) {
                    row.append (new Group (body));
                } else {
                    row.move_from (body);
                }
                return;
            }
            if (c == '^' || c == '_') {
                next ();
                attach_script (row, c == '^');
                return;
            }
            if (c == '\'') {
                int n = 0;
                while (peek () == '\'') {
                    next ();
                    n++;
                }
                add_prime (row, n);
                return;
            }
            if (c == '\\') {
                next ();
                string cmd = read_command_name ();
                parse_command (cmd, row);
                return;
            }
            if (c == '~') {
                next ();
                row.append (new Space (1.0 / 3.0));
                return;
            }
            if (c == '$') {
                next ();
                return;
            }
            next ();
            if (c.isdigit ()) {
                row.append (new Token.number (c.to_string ()));
                if (!single) {
                    while (!at_end () && (peek ().isdigit () || (peek () == '.' && pos + 1 < src.length && src[pos + 1].isdigit ()))) {
                        row.append (new Token.number (next ().to_string ()));
                    }
                }
                return;
            }
            if (c == '.' && !at_end () && peek ().isdigit () && !single) {
                row.append (new Token.number ("."));
                return;
            }
            if (c.isalpha ()) {
                row.append (new Token.ident (c.to_string ()));
                return;
            }
            string s = c.to_string ();
            if (s == "-") s = "\u2212";
            if (s == "*") s = "\u2217";
            row.append (new Token.op (s));
        }

        private void apply_variant (Row row, MathVariant v) {
            foreach (var n in row.items) {
                var t = n as Token;
                if (t != null) {
                    if (t.kind != TokenKind.OPERATOR || v == MathVariant.BOLD || v == MathVariant.BOLD_ITALIC) t.variant = v;
                    continue;
                }
                foreach (var s in n.slots ()) apply_variant (s, v);
            }
        }

        private void parse_text (Row row, MathVariant v) throws ParseError {
            skip_space ();
            if (peek () != '{') {
                if (at_end ()) throw error (_("Missing argument"));
                var t = new Token.plain (next ().to_string ());
                t.variant = v;
                row.append (t);
                return;
            }
            next ();
            int level = 1;
            while (true) {
                if (at_end ()) throw error (_("Missing closing brace"));
                unichar c = next ();
                if (c == '{') {
                    level++;
                    continue;
                }
                if (c == '}') {
                    level--;
                    if (level == 0) break;
                    continue;
                }
                if (c == '$') {
                    var inner = new Row ();
                    while (!at_end () && peek () != '$') parse_atom (inner);
                    if (!at_end ()) next ();
                    row.move_from (inner);
                    continue;
                }
                string s = c.to_string ();
                if (c == '\\') {
                    if (at_end ()) break;
                    string cmd = read_command_name ();
                    switch (cmd) {
                        case "{": case "}": case "%": case "$": case "&": case "#": case "_": s = cmd; break;
                        case "\\": s = " "; break;
                        case " ": s = " "; break;
                        case "textbackslash": s = "\\"; break;
                        case "ldots": case "dots": s = "\u2026"; break;
                        default:
                            var sym = Symbols.by_command (cmd);
                            s = sym != null ? sym.ch : "\\" + cmd;
                            break;
                    }
                }
                if (c == '~') s = "\u00a0";
                if (c == '\n' || c == '\t') s = " ";
                var t = new Token.plain (s);
                t.variant = v;
                row.append (t);
            }
        }

        private void parse_command (string cmd, Row row) throws ParseError {
            double sp;
            if (Symbols.named_space (cmd, out sp)) {
                row.append (new Space (sp));
                return;
            }
            switch (cmd) {
                case "{": case "}": case "#": case "$": case "%": case "&": case "_": case "|":
                    var t = new Token.op (cmd == "|" ? "\u2016" : cmd);
                    if (cmd == "{") t.forced_class = AtomClass.OPEN;
                    if (cmd == "}") t.forced_class = AtomClass.CLOSE;
                    if (cmd == "#" || cmd == "$" || cmd == "%" || cmd == "&") t.kind = TokenKind.IDENT;
                    row.append (t);
                    return;
                case "frac": case "dfrac": case "tfrac": case "cfrac": case "sfrac": case "nicefrac":
                    var num = parse_argument ();
                    var den = parse_argument ();
                    var f = new Frac (num, den);
                    if (cmd == "dfrac") f.display = 1;
                    if (cmd == "tfrac") f.display = 0;
                    if (cmd == "cfrac") {
                        f.continued = true;
                        f.display = 1;
                    }
                    if (cmd == "sfrac" || cmd == "nicefrac") f.bevelled = true;
                    row.append (f);
                    return;
                case "binom": case "dbinom": case "tbinom":
                    var bf = new Frac (parse_argument (), parse_argument ());
                    bf.line = false;
                    if (cmd == "dbinom") bf.display = 1;
                    if (cmd == "tbinom") bf.display = 0;
                    var fb = new Row ();
                    fb.append (bf);
                    row.append (new Fenced ("(", ")", fb));
                    return;
                case "genfrac":
                    string go = read_braced_text ();
                    string gc = read_braced_text ();
                    string gt = read_braced_text ();
                    string gs = read_braced_text ();
                    var gf = new Frac (parse_argument (), parse_argument ());
                    if (gt.strip () != "" && dimension_to_em (gt) == 0) gf.line = false;
                    if (gs.strip () == "0") gf.display = 1;
                    if (gs.strip () == "1") gf.display = 0;
                    string gso = go.strip ();
                    string gsc = gc.strip ();
                    string? dgo = Symbols.delimiter (gso);
                    string? dgc = Symbols.delimiter (gsc);
                    if (gso != "" && dgo != null) gso = dgo;
                    if (gsc != "" && dgc != null) gsc = dgc;
                    if (gso != "" || gsc != "") {
                        var gb = new Row ();
                        gb.append (gf);
                        row.append (new Fenced (gso, gsc, gb));
                    } else {
                        row.append (gf);
                    }
                    return;
                case "sqrt":
                    var index = parse_optional ();
                    var body = parse_argument ();
                    row.append (new Radical (body, index));
                    return;
                case "root":
                    var rindex = new Row ();
                    while (true) {
                        skip_space ();
                        if (at_end ()) throw error (_("Missing \"\\of\""));
                        if (peek_command () == "of") {
                            next ();
                            read_command_name ();
                            break;
                        }
                        parse_atom (rindex);
                    }
                    row.append (new Radical (parse_argument (), rindex));
                    return;
                case "left":
                    string open = read_delimiter ();
                    var inner = new Row ();
                    while (true) {
                        var part = parse_row (Stop.RIGHT);
                        inner.move_from (part);
                        if (at_end ()) throw error (_("Missing \"\\right\""));
                        next ();
                        string which = read_command_name ();
                        string d = read_delimiter ();
                        if (which == "middle") {
                            var mt = new Token.op (d);
                            mt.fence_middle = true;
                            inner.append (mt);
                            continue;
                        }
                        row.append (new Fenced (open, d, inner));
                        break;
                    }
                    return;
                case "big": case "Big": case "bigg": case "Bigg":
                case "bigl": case "Bigl": case "biggl": case "Biggl":
                case "bigr": case "Bigr": case "biggr": case "Biggr":
                case "bigm": case "Bigm": case "biggm": case "Biggm":
                    string d = read_delimiter ();
                    var bt = new Token.op (d == "" ? "." : d);
                    string size = cmd;
                    if (size.has_suffix ("l") || size.has_suffix ("r") || size.has_suffix ("m")) {
                        char last = size[size.length - 1];
                        bt.forced_class = last == 'l' ? AtomClass.OPEN : (last == 'r' ? AtomClass.CLOSE : AtomClass.REL);
                        size = size.substring (0, size.length - 1);
                    }
                    switch (size) {
                        case "big": bt.min_size = 1.2; break;
                        case "Big": bt.min_size = 1.8; break;
                        case "bigg": bt.min_size = 2.4; break;
                        default: bt.min_size = 3.0; break;
                    }
                    row.append (bt);
                    return;
                case "overset": case "stackrel":
                    var over = parse_argument ();
                    var obase = parse_argument ();
                    row.append (new UnderOver (obase, null, over));
                    return;
                case "underset":
                    var under = parse_argument ();
                    var ubase = parse_argument ();
                    row.append (new UnderOver (ubase, under, null));
                    return;
                case "xrightarrow": case "xleftarrow": case "xleftrightarrow": case "xRightarrow": case "xLeftarrow":
                case "xLeftrightarrow": case "xmapsto": case "xhookrightarrow": case "xhookleftarrow": case "xrightleftharpoons":
                    var xunder = parse_optional ();
                    var xover = parse_argument ();
                    string arrow = x_arrow (cmd);
                    var xb = new Row ();
                    xb.append (new Token.op (arrow));
                    row.append (new UnderOver (xb, xunder, xover));
                    return;
                case "text": case "textrm": case "mbox": case "textnormal": case "hbox":
                    parse_text (row, MathVariant.NORMAL);
                    return;
                case "textbf": case "textit": case "texttt": case "textsf":
                    MathVariant tv;
                    Symbols.font_command (cmd, out tv);
                    parse_text (row, tv);
                    return;
                case "operatorname": case "operatorname*":
                    string name = read_braced_text ().strip ();
                    var op = new Token.ident (name.replace ("\\,", " ").replace ("\\ ", " "));
                    if (op.text.char_count () == 1) op.variant = MathVariant.NORMAL;
                    op.forced_class = AtomClass.OP;
                    if (cmd.has_suffix ("*")) op.limits = 1;
                    row.append (op);
                    return;
                case "mathbin": case "mathrel": case "mathop": case "mathord": case "mathopen": case "mathclose": case "mathpunct": case "mathinner":
                    var arg = parse_argument ();
                    AtomClass cls = AtomClass.ORD;
                    switch (cmd) {
                        case "mathbin": cls = AtomClass.BIN; break;
                        case "mathrel": cls = AtomClass.REL; break;
                        case "mathop": cls = AtomClass.OP; break;
                        case "mathopen": cls = AtomClass.OPEN; break;
                        case "mathclose": cls = AtomClass.CLOSE; break;
                        case "mathpunct": cls = AtomClass.PUNCT; break;
                        case "mathinner": cls = AtomClass.INNER; break;
                        default: break;
                    }
                    if (arg.size == 1 && arg[0] is Token) {
                        ((Token) arg[0]).forced_class = cls;
                        row.move_from (arg);
                    } else if (cls == AtomClass.OP && arg.size > 1 && all_letters (arg)) {
                        var mop = new Token.ident (row_text (arg));
                        mop.forced_class = AtomClass.OP;
                        row.append (mop);
                    } else {
                        row.append (new Group (arg));
                    }
                    return;
                case "limits": case "nolimits": case "displaylimits":
                    if (row.size > 0 && row[row.size - 1] is Token) {
                        ((Token) row[row.size - 1]).limits = cmd == "limits" ? 1 : (cmd == "nolimits" ? 0 : -1);
                    }
                    return;
                case "textcolor":
                    var tc = new Style ();
                    tc.color = read_braced_text ().strip ();
                    tc.body.move_from (parse_argument ());
                    row.append (tc);
                    return;
                case "colorbox":
                    var cb = new Style ();
                    cb.background = read_braced_text ().strip ();
                    cb.body.move_from (parse_argument ());
                    row.append (cb);
                    return;
                case "boxed": case "fbox":
                    row.append (new Enclose ("box", parse_argument ()));
                    return;
                case "cancel":
                    row.append (new Enclose ("updiagonalstrike", parse_argument ()));
                    return;
                case "bcancel":
                    row.append (new Enclose ("downdiagonalstrike", parse_argument ()));
                    return;
                case "xcancel":
                    row.append (new Enclose ("updiagonalstrike downdiagonalstrike", parse_argument ()));
                    return;
                case "phantom":
                    row.append (new Phantom (parse_argument ()));
                    return;
                case "hphantom":
                    var hp = new Phantom (parse_argument ());
                    hp.keep_height = false;
                    row.append (hp);
                    return;
                case "vphantom":
                    var vp = new Phantom (parse_argument ());
                    vp.keep_width = false;
                    row.append (vp);
                    return;
                case "mathstrut": case "strut":
                    var sp2 = new Phantom (new Row.with ({ new Token.op ("(") }));
                    sp2.keep_width = false;
                    row.append (sp2);
                    return;
                case "hspace": case "hspace*": case "mspace": case "hskip": case "mkern": case "kern": case "mskip":
                    double w = parse_dimension_arg ();
                    row.append (new Space (w));
                    return;
                case "not":
                    parse_not (row);
                    return;
                case "pmod":
                    row.append (new Space (1.0));
                    var pm = new Row ();
                    var mod = new Token.ident ("mod");
                    mod.forced_class = AtomClass.OP;
                    pm.append (mod);
                    pm.append (new Space (6.0 / 18.0));
                    pm.move_from (parse_argument ());
                    row.append (new Fenced ("(", ")", pm));
                    return;
                case "bmod": case "mod":
                    var bm = new Token.ident ("mod");
                    bm.forced_class = AtomClass.BIN;
                    row.append (bm);
                    return;
                case "tag": case "tag*":
                    row_tag = read_braced_text ();
                    return;
                case "notag": case "nonumber":
                    row_notag = true;
                    return;
                case "label":
                    row_label = read_braced_text ().strip ();
                    return;
                case "eqref":
                case "ref":
                    row.append (new Ref (read_braced_text ().strip (), cmd == "eqref"));
                    return;
                case "prescript":
                    var pre_sup = parse_argument ();
                    var pre_sub = parse_argument ();
                    var pre = new Scripts (pre_sub.size > 0 ? pre_sub : null, pre_sup.size > 0 ? pre_sup : null);
                    pre.pre = true;
                    row.append (pre);
                    var pre_base = parse_argument ();
                    if (pre_base.size == 1) row.move_from (pre_base);
                    else row.append (new Group (pre_base));
                    return;
                case "enclose":
                    string notation = read_braced_text ().strip ().replace (",", " ");
                    skip_space ();
                    if (peek () == '[') {
                        while (!at_end () && peek () != ']') next ();
                        if (!at_end ()) next ();
                    }
                    row.append (new Enclose (notation, parse_argument ()));
                    return;
                case "begin":
                    parse_environment (row);
                    return;
                case "substack":
                    skip_space ();
                    expect ('{');
                    var st = new Table (TableKind.ARRAY);
                    st.columns = "c";
                    parse_table_body (st, false);
                    expect ('}');
                    row.append (st);
                    return;
                case "dots": case "ldots": case "cdots": case "dotsb": case "dotsc": case "dotsm": case "dotsi": case "dotso":
                    string ch = (cmd == "cdots" || cmd == "dotsb" || cmd == "dotsm" || cmd == "dotsi") ? "\u22ef" : "\u2026";
                    var dt = new Token.op (ch);
                    row.append (dt);
                    return;
                case "lim": case "liminf": case "limsup":
                    var lt = new Token.ident (cmd == "liminf" ? "lim inf" : (cmd == "limsup" ? "lim sup" : "lim"));
                    lt.forced_class = AtomClass.OP;
                    row.append (lt);
                    return;
                default:
                    break;
            }
            if (Symbols.is_function (cmd)) {
                var ft = new Token.ident (cmd);
                ft.forced_class = AtomClass.OP;
                row.append (ft);
                return;
            }
            MathVariant fv;
            if (Symbols.font_command (cmd, out fv)) {
                var arg = parse_argument ();
                apply_variant (arg, fv);
                row.move_from (arg);
                return;
            }
            var acc = Symbols.accent (cmd);
            if (acc != null) {
                var body = parse_argument ();
                row.append (new Accent (acc.mark, body, acc.stretchy, acc.under));
                return;
            }
            var sym = Symbols.by_command (cmd);
            if (sym != null) {
                var t = new Token (sym.cls == AtomClass.ORD && Symbols.is_letter (sym.ch.get_char (0)) ? TokenKind.IDENT : TokenKind.OPERATOR, sym.ch);
                if (sym.command == "lbrace" || sym.command == "lbrack" || sym.command == "langle" || sym.command == "lvert" || sym.command == "lVert" || sym.command == "lfloor" || sym.command == "lceil") t.forced_class = AtomClass.OPEN;
                if (sym.command == "rbrace" || sym.command == "rbrack" || sym.command == "rangle" || sym.command == "rvert" || sym.command == "rVert" || sym.command == "rfloor" || sym.command == "rceil") t.forced_class = AtomClass.CLOSE;
                if (sym.command == "colon") t.forced_class = AtomClass.PUNCT;
                if (sym.command == "prime") t.kind = TokenKind.IDENT;
                if (sym.category == "greek" && t.kind == TokenKind.OPERATOR) t.kind = TokenKind.IDENT;
                row.append (t);
                return;
            }
            var err = new Token.ident ("\\" + cmd);
            err.error = true;
            row.append (err);
        }

        private static bool all_letters (Row r) {
            foreach (var n in r.items) {
                var t = n as Token;
                if (t == null || t.kind != TokenKind.IDENT) return false;
            }
            return true;
        }

        private static string row_text (Row r) {
            var sb = new StringBuilder ();
            foreach (var n in r.items) sb.append (((Token) n).text);
            return sb.str;
        }

        private static string x_arrow (string cmd) {
            switch (cmd) {
                case "xleftarrow": return "\u2190";
                case "xleftrightarrow": return "\u2194";
                case "xRightarrow": return "\u21d2";
                case "xLeftarrow": return "\u21d0";
                case "xLeftrightarrow": return "\u21d4";
                case "xmapsto": return "\u21a6";
                case "xhookrightarrow": return "\u21aa";
                case "xhookleftarrow": return "\u21a9";
                case "xrightleftharpoons": return "\u21cc";
                default: return "\u2192";
            }
        }

        public static string? negate (string ch) {
            switch (ch) {
                case "=": return "\u2260";
                case "<": return "\u226e";
                case ">": return "\u226f";
                case "\u2264": return "\u2270";
                case "\u2265": return "\u2271";
                case "\u2208": return "\u2209";
                case "\u220b": return "\u220c";
                case "\u2282": return "\u2284";
                case "\u2283": return "\u2285";
                case "\u2286": return "\u2288";
                case "\u2287": return "\u2289";
                case "\u2261": return "\u2262";
                case "\u223c": return "\u2241";
                case "\u2243": return "\u2244";
                case "\u2245": return "\u2247";
                case "\u2248": return "\u2249";
                case "\u2223": return "\u2224";
                case "\u2225": return "\u2226";
                case "\u227a": return "\u2280";
                case "\u227b": return "\u2281";
                case "\u22a2": return "\u22ac";
                case "\u22a8": return "\u22ad";
                case "\u2203": return "\u2204";
                default: return null;
            }
        }

        private void parse_not (Row row) throws ParseError {
            var tmp = new Row ();
            parse_atom (tmp, true);
            if (tmp.size == 1 && tmp[0] is Token) {
                var t = (Token) tmp[0];
                var n = negate (t.text);
                t.text = n ?? t.text + "\u0338";
                if (t.kind == TokenKind.IDENT && n == null) t.kind = TokenKind.OPERATOR;
                row.append (t);
                return;
            }
            row.move_from (tmp);
        }

        private void parse_environment (Row row) throws ParseError {
            string env = read_braced_text ().strip ();
            TableKind kind;
            string cols = "";
            string col_lines = "";
            switch (env) {
                case "matrix": kind = TableKind.MATRIX; break;
                case "pmatrix": kind = TableKind.PMATRIX; break;
                case "bmatrix": kind = TableKind.BMATRIX; break;
                case "Bmatrix": kind = TableKind.BRACE_MATRIX; break;
                case "vmatrix": kind = TableKind.VMATRIX; break;
                case "Vmatrix": kind = TableKind.DOUBLE_VMATRIX; break;
                case "smallmatrix": kind = TableKind.SMALL_MATRIX; break;
                case "cases": case "dcases": kind = TableKind.CASES; break;
                case "aligned": case "align": case "align*": case "split": case "alignat": case "alignat*": case "alignedat": case "flalign": case "flalign*": case "eqnarray": case "eqnarray*":
                    kind = TableKind.ALIGN;
                    if (env.has_prefix ("alignat") || env == "alignedat") read_braced_text ();
                    break;
                case "gathered": case "gather": case "gather*": case "multline": case "multline*":
                    kind = TableKind.GATHER;
                    break;
                case "array": case "subarray":
                    kind = TableKind.ARRAY;
                    string spec = read_braced_text ();
                    var lines = new StringBuilder ();
                    foreach (char ch in spec.to_utf8 ()) {
                        if (ch == 'l' || ch == 'c' || ch == 'r') {
                            cols += ch.to_string ();
                            lines.append ("n");
                        } else if (ch == '|' && lines.len > 0) {
                            lines.truncate (lines.len - 1);
                            lines.append ("s");
                        }
                    }
                    col_lines = lines.str;
                    break;
                case "equation": case "equation*": case "displaymath": case "math":
                    var inner = parse_row (Stop.END);
                    expect_end (env);
                    row.move_from (inner);
                    return;
                default:
                    throw error (_("Unknown environment \"%s\"").printf (env));
            }
            var t = new Table (kind);
            t.columns = cols;
            t.column_lines = col_lines;
            parse_table_body (t, true);
            expect_end (env);
            row.append (t);
        }

        private void expect_end (string env) throws ParseError {
            skip_space ();
            if (peek_command () != "end") throw error (_("Missing \"\\end{%s}\"").printf (env));
            next ();
            read_command_name ();
            string e = read_braced_text ().strip ();
            if (e != env) throw error (_("\"\\begin{%s}\" ended by \"\\end{%s}\"").printf (env, e));
        }

        private void parse_table_body (Table t, bool until_end) throws ParseError {
            var cells = new Gee.ArrayList<Row> ();
            string? saved_tag = row_tag;
            bool saved_notag = row_notag;
            string? saved_label = row_label;
            row_tag = null;
            row_notag = false;
            row_label = null;
            while (true) {
                var cell = parse_row (Stop.CELL | Stop.END | Stop.BRACE);
                cells.add (cell);
                skip_space ();
                if (peek () == '&') {
                    next ();
                    continue;
                }
                string cmd = peek_command ();
                if (cmd == "\\" || cmd == "cr") {
                    next ();
                    read_command_name ();
                    skip_space ();
                    if (peek () == '[') {
                        next ();
                        while (!at_end () && peek () != ']') next ();
                        if (!at_end ()) next ();
                    }
                    while (peek_command () == "hline") {
                        next ();
                        read_command_name ();
                        skip_space ();
                    }
                    t.add_row_cells (cells, row_tag, row_notag, row_label);
                    row_tag = null;
                    row_notag = false;
                    row_label = null;
                    cells = new Gee.ArrayList<Row> ();
                    continue;
                }
                bool only_empty = cells.size == 1 && cells[0].size == 0 && row_tag == null;
                if (!only_empty || t.row_count == 0) t.add_row_cells (cells, row_tag, row_notag, row_label);
                break;
            }
            row_tag = saved_tag;
            row_notag = saved_notag;
            row_label = saved_label;
            t.normalize ();
        }
    }
}
