namespace Singularity.Apps.Formula {

    public class MathmlReader {
        public string? tag;
        public bool display = true;
        public string? annotation;
        public string? starmath;
        public string justification = "";
        public string number_style = "";
        public bool numbered;
        public int first_number = 1;
        public string? label;
        private bool auto_seen;

        public void apply_document (FormulaDoc d) {
            if (justification != "") d.justification = Singularity.Equations.Justification.from_mathml (justification);
            if (number_style != "") d.number_style = Singularity.Equations.NumberStyle.parse (number_style);
            if (numbered) d.numbered = true;
            d.first_number = first_number;
            if (label != null) d.label = label;
        }

        public static ParseResult parse (string xml) throws ParseError {
            var r = new MathmlReader ();
            return r.read (xml);
        }

        public ParseResult read (string xml) throws ParseError {
            string text = xml.strip ();
            if (text.has_prefix ("\xef\xbb\xbf")) text = text.substring (3);
            if (!text.has_prefix ("<?xml") && !text.contains ("<math") && !text.contains (":math")) {
                throw new ParseError.SYNTAX ("0:%s", _("This is not MathML"));
            }
            if (!text.contains ("xmlns") && text.contains ("&")) text = text.replace ("&nbsp;", "&#160;");
            Xml.Doc* doc = Xml.Parser.read_memory (text, text.length, null, null,
                Xml.ParserOption.NONET | Xml.ParserOption.NOERROR | Xml.ParserOption.NOWARNING | Xml.ParserOption.RECOVER);
            if (doc == null) throw new ParseError.SYNTAX ("0:%s", _("The MathML could not be read"));
            Xml.Node* root = doc->get_root_element ();
            Xml.Node* math = find_math (root);
            if (math == null) {
                delete doc;
                throw new ParseError.SYNTAX ("0:%s", _("No <math> element was found"));
            }
            string? disp = math->get_prop ("display");
            display = disp == null || disp == "block";
            string? mode = math->get_prop ("mode");
            if (mode != null && disp == null) display = mode == "display";
            justification = math->get_prop ("data-justification") ?? "";
            if (justification == "") {
                string ia = math->get_prop ("indentalign") ?? "";
                if (ia == "left" || ia == "right" || ia == "center") justification = ia;
            }
            number_style = math->get_prop ("data-number-style") ?? "";
            numbered = math->get_prop ("data-numbered") == "true";
            string? fnum = math->get_prop ("data-first-number");
            if (fnum != null) first_number = int.parse (fnum);
            label = math->get_prop ("data-label");
            var row = new Row ();
            children_into (math, row);
            delete doc;
            var res = new ParseResult (row);
            res.tag = tag;
            if (row.size == 1 && row[0] is Table) {
                var t = (Table) row[0];
                if (t.row_count == 1 && t.column_count == 1 && (t.tags[0] != null || auto_seen) && t.kind == TableKind.GATHER) {
                    res.tag = t.tags[0];
                    var cell = t.rows[0][0];
                    var r2 = new Row ();
                    r2.move_from (cell);
                    res.root = r2;
                }
            }
            return res;
        }

        private static Xml.Node* find_math (Xml.Node* n) {
            for (Xml.Node* c = n; c != null; c = c->next) {
                if (c->type != Xml.ElementType.ELEMENT_NODE) continue;
                if (c->name == "math") return c;
                Xml.Node* inner = find_math (c->children);
                if (inner != null) return inner;
            }
            return null;
        }

        private static Xml.Node*[] elements (Xml.Node* n) {
            Xml.Node*[] list = {};
            for (Xml.Node* c = n->children; c != null; c = c->next) {
                if (c->type == Xml.ElementType.ELEMENT_NODE) list += c;
            }
            return list;
        }

        private static string content (Xml.Node* n) {
            string s = n->get_content () ?? "";
            var sb = new StringBuilder ();
            bool space = false;
            int i = 0;
            unichar c;
            string t = s.strip ();
            while (t.get_next_char (ref i, out c)) {
                if (c == ' ' || c == '\n' || c == '\t' || c == '\r') {
                    if (!space) sb.append_c (' ');
                    space = true;
                    continue;
                }
                space = false;
                sb.append_unichar (c);
            }
            return sb.str;
        }

        private void children_into (Xml.Node* n, Row row) {
            foreach (Xml.Node* c in elements (n)) element_into (c, row);
            Fences.rebuild_mathml (row);
            fold_matrices (row);
        }

        private static void fold_matrices (Row row) {
            for (int i = 0; i < row.size; i++) {
                var f = row[i] as Fenced;
                if (f != null && f.body.size == 1 && f.body[0] is Table) {
                    var t = (Table) f.body[0];
                    TableKind? k = null;
                    if (t.kind == TableKind.MATRIX || (t.kind == TableKind.ARRAY && !t.column_lines.contains ("s"))) {
                        switch (f.open + f.close) {
                            case "()": k = TableKind.PMATRIX; break;
                            case "[]": k = TableKind.BMATRIX; break;
                            case "{}": k = TableKind.BRACE_MATRIX; break;
                            case "||": k = TableKind.VMATRIX; break;
                            case "\u2016\u2016": k = TableKind.DOUBLE_VMATRIX; break;
                            default: break;
                        }
                    }
                    if (k != null) {
                        var nt = (Table) t.copy ();
                        nt.kind = k;
                        if (t.columns.replace ("c", "") == "") nt.columns = "";
                        row.replace (i, nt);
                    }
                    continue;
                }
                var tok = row[i] as Token;
                if (tok != null && tok.text == "{" && tok.kind == TokenKind.OPERATOR && i + 1 < row.size && row[i + 1] is Table && i + 2 == row.size) {
                    var t = (Table) row[i + 1];
                    if (t.kind == TableKind.ARRAY || t.kind == TableKind.MATRIX) {
                        var nt = (Table) t.copy ();
                        nt.kind = TableKind.CASES;
                        nt.columns = "";
                        row.remove_at (i + 1);
                        row.replace (i, nt);
                    }
                }
            }
        }

        private Row row_of (Xml.Node* n) {
            var r = new Row ();
            element_into (n, r);
            return r;
        }

        private Row children_row (Xml.Node* n) {
            var r = new Row ();
            children_into (n, r);
            return r;
        }

        private static void unbox (Row r) {
            if (r.size == 1 && r[0] is Group) {
                var g = (Group) r[0];
                r.clear ();
                r.move_from (g.body);
            }
        }

        private void append_base (Row row, Row base_row) {
            if (base_row.size == 1 || base_row.size == 0) {
                row.move_from (base_row);
                return;
            }
            row.append (new Group (base_row));
        }

        private static bool is_largeop_token (Row r) {
            if (r.size != 1 || !(r[0] is Token)) return false;
            var t = (Token) r[0];
            if (t.kind == TokenKind.OPERATOR && Symbols.is_large_op (t.text)) return true;
            if (t.kind == TokenKind.IDENT && t.forced_class == AtomClass.OP) return true;
            return false;
        }

        private static string mark_char (Row r) {
            if (r.size != 1 || !(r[0] is Token)) return "";
            var t = (Token) r[0];
            return t.kind == TokenKind.OPERATOR || t.kind == TokenKind.IDENT || t.kind == TokenKind.TEXT ? t.text : "";
        }

        private static bool accent_like (string m) {
            if (m == "") return false;
            string n = Symbols.normalize_accent (m);
            if (n == "\u203e" || n == "_" || n == "\u0304") return true;
            unichar c = n.get_char (0);
            if (c >= 0x300 && c <= 0x36f) return true;
            if (c >= 0x20d0 && c <= 0x20ff) return true;
            if (c >= 0x23b4 && c <= 0x23e1) return true;
            if (n == "\u2192" || n == "\u2190" || n == "\u2194") return true;
            return false;
        }

        private static bool is_arrow (Row r) {
            if (r.size != 1 || !(r[0] is Token)) return false;
            unichar c = ((Token) r[0]).text.get_char (0);
            return (c >= 0x2190 && c <= 0x21ff) || (c >= 0x27f0 && c <= 0x27ff);
        }

        private Node? make_accent (Row body, string mark, bool under, string? stretchy_attr) {
            string m = Symbols.normalize_accent (mark);
            if (m == "\u2015") m = "\u203e";
            bool stretchy;
            if (stretchy_attr != null) stretchy = stretchy_attr == "true";
            else {
                unichar c = m.get_char (0);
                stretchy = m == "\u203e" || m == "_" || (c >= 0x23b4 && c <= 0x23e1) || (c >= 0x2190 && c <= 0x21ff);
            }
            if (m == "\u00af" || m == "\u0304") {
                if (stretchy) m = "\u203e";
            }
            if (m == "\u2192" && !stretchy) m = "\u20d7";
            var info = Symbols.accent_for_mark (m, stretchy, under);
            if (info != null && info.stretchy != stretchy && (info.mark == "\u203e" || info.mark == "_")) stretchy = true;
            return new Accent (m, body, stretchy, under);
        }

        private static string attr (Xml.Node* n, string name) {
            return n->get_prop (name) ?? "";
        }

        private void element_into (Xml.Node* n, Row row) {
            string name = n->name;
            var kids = elements (n);
            switch (name) {
                case "math":
                case "mrow":
                case "mpadded":
                case "maction":
                case "mstyle":
                    if (name == "maction") {
                        if (kids.length > 0) element_into (kids[0], row);
                        return;
                    }
                    if (name == "mstyle" || name == "mrow") {
                        string ds = attr (n, "displaystyle");
                        string sl = attr (n, "scriptlevel");
                        string col = attr (n, "mathcolor");
                        string bg = attr (n, "mathbackground");
                        string mv = attr (n, "mathvariant");
                        if (col == "") col = attr (n, "color");
                        if (ds != "" || sl != "" || col != "" || bg != "") {
                            var st = new Style (children_row (n));
                            if (ds != "") st.display = ds == "true" ? 1 : 0;
                            if (sl != "" && sl[0].isdigit ()) st.script_level = int.parse (sl);
                            if (col != "") st.color = col;
                            if (bg != "") st.background = bg;
                            if (mv != "") apply_variant (st.body, MathVariant.from_mathml (mv));
                            if (st.body.size == 1 && st.body[0] is Frac && st.color == null && st.background == null && st.display >= 0) {
                                var f = (Frac) st.body[0];
                                if (f.display < 0) {
                                    f.display = st.display;
                                    row.append (f.copy ());
                                    return;
                                }
                            }
                            if (st.body.size == 1 && st.body[0] is Table && st.color == null && st.background == null) {
                                row.append (st.body[0].copy ());
                                return;
                            }
                            row.append (st);
                            return;
                        }
                        if (mv != "") {
                            var inner = children_row (n);
                            apply_variant (inner, MathVariant.from_mathml (mv));
                            row.move_from (inner);
                            return;
                        }
                    }
                    if (name == "mpadded") {
                        if (kids.length == 1 && kids[0]->name == "mphantom") {
                            var p = new Phantom (children_row (kids[0]));
                            if (attr (n, "height") == "0" || attr (n, "depth") == "0") p.keep_height = false;
                            if (attr (n, "width") == "0") p.keep_width = false;
                            row.append (p);
                            return;
                        }
                        if (kids.length == 1 && kids[0]->name == "mpadded" && elements (kids[0]).length == 1 && elements (kids[0])[0]->name == "mphantom") {
                            var p = new Phantom (children_row (elements (kids[0])[0]));
                            p.keep_height = false;
                            p.keep_width = false;
                            row.append (p);
                            return;
                        }
                    }
                    var inner = children_row (n);
                    row.move_from (inner);
                    return;
                case "semantics":
                    foreach (Xml.Node* k in kids) {
                        if (k->name == "annotation") {
                            string enc = attr (k, "encoding");
                            if (enc == "application/x-tex" || enc == "TeX" || enc == "LaTeX") annotation = k->get_content ();
                            if (enc.has_prefix ("StarMath")) starmath = k->get_content ();
                        }
                    }
                    if (kids.length > 0) element_into (kids[0], row);
                    return;
                case "annotation":
                case "annotation-xml":
                case "none":
                case "mprescripts":
                    return;
                case "mi":
                    string text = content (n);
                    if (text == "") return;
                    var t = token_from_text (TokenKind.IDENT, text);
                    string mv = attr (n, "mathvariant");
                    if (mv != "") t.variant = MathVariant.from_mathml (mv);
                    if (t.text.char_count () > 1 && t.variant == MathVariant.ITALIC) {
                        int ci = 0;
                        unichar cc;
                        var letters = new Row ();
                        while (t.text.get_next_char (ref ci, out cc)) letters.append (new Token.ident (cc.to_string ()));
                        append_row_colored (row, letters, n);
                        return;
                    }
                    if (t.text.char_count () > 1) {
                        if (t.variant == MathVariant.NORMAL) t.variant = MathVariant.DEFAULT;
                        if (Symbols.is_function (t.text.replace (" ", ""))) t.forced_class = AtomClass.OP;
                    }
                    append_colored (row, t, n);
                    return;
                case "mn":
                    string num = content (n);
                    string nv = attr (n, "mathvariant");
                    int i = 0;
                    unichar c;
                    var nums = new Row ();
                    while (num.get_next_char (ref i, out c)) {
                        var d = token_from_text (TokenKind.NUMBER, c.to_string ());
                        if (nv != "" && nv != "normal") d.variant = MathVariant.from_mathml (nv);
                        nums.append (d);
                    }
                    append_row_colored (row, nums, n);
                    return;
                case "mtext":
                case "ms":
                    string? dref = n->get_prop ("data-ref");
                    if (dref != null) {
                        row.append (new Ref (dref, n->get_prop ("data-paren") == "true"));
                        return;
                    }
                    string tx = n->get_content () ?? "";
                    if (name == "ms") tx = "\"" + tx + "\"";
                    string tv = attr (n, "mathvariant");
                    int ti = 0;
                    unichar tc;
                    var texts = new Row ();
                    while (tx.get_next_char (ref ti, out tc)) {
                        if (tc == '\n' || tc == '\t' || tc == '\r') tc = ' ';
                        var tt = new Token.plain (tc == 0xa0 ? " " : tc.to_string ());
                        tt.variant = tv != "" ? MathVariant.from_mathml (tv) : MathVariant.NORMAL;
                        texts.append (tt);
                    }
                    append_row_colored (row, texts, n);
                    return;
                case "mo":
                    string op = content (n);
                    if (op == "" || op == "\u2061" || op == "\u2062" || op == "\u2063" || op == "\u2064") return;
                    var o = new Token.op (op == "-" ? "\u2212" : op);
                    string ms = attr (n, "minsize");
                    if (ms != "") {
                        double v = LatexParser.dimension_to_em (ms);
                        if (ms.has_suffix ("%")) v = double.parse (ms.replace ("%", "")) / 100.0;
                        if (v > 1.0) o.min_size = v;
                        string form = attr (n, "form");
                        if (form == "prefix") o.forced_class = AtomClass.OPEN;
                        else if (form == "postfix") o.forced_class = AtomClass.CLOSE;
                    }
                    if (attr (n, "fence") == "true" && attr (n, "form") == "infix") o.fence_middle = true;
                    if (attr (n, "movablelimits") == "false" && Symbols.has_limits (o.text)) o.limits = 0;
                    if (attr (n, "stretchy") == "true" && Symbols.is_fence (op) && attr (n, "fence") != "true" && attr (n, "form") == "") o.fence_middle = row.size > 0;
                    string ls = attr (n, "lspace");
                    if (ls != "" && Symbols.char_class (o.text) == AtomClass.ORD) {
                        double lv = LatexParser.dimension_to_em (ls);
                        if (lv > 0.25) o.forced_class = AtomClass.REL;
                        else if (lv > 0.2) o.forced_class = AtomClass.BIN;
                    }
                    if (ls == "0em" && attr (n, "rspace") == "0em" && Symbols.char_class (o.text) != AtomClass.ORD) o.forced_class = AtomClass.ORD;
                    if (Symbols.is_function (op) && op.char_count () > 1) {
                        var f = new Token.ident (op);
                        f.forced_class = AtomClass.OP;
                        append_colored (row, f, n);
                        return;
                    }
                    string mv2 = attr (n, "mathvariant");
                    if (mv2 == "bold") o.variant = MathVariant.BOLD;
                    if (attr (n, "stretchy") == "false") o.fixed = true;
                    append_colored (row, o, n);
                    return;
                case "mspace":
                    string w = attr (n, "width");
                    double wv = named_space (w);
                    if (wv == 0 && attr (n, "linebreak") == "newline") return;
                    row.append (new Space (wv));
                    return;
                case "mfrac":
                    if (kids.length < 2) return;
                    var f = new Frac (row_of (kids[0]), row_of (kids[1]));
                    unbox (f.num);
                    unbox (f.den);
                    string lt = attr (n, "linethickness").strip ();
                    if (lt != "" && (lt == "0" || double.parse (lt) == 0) && !lt.has_prefix ("thin") && !lt.has_prefix ("med") && !lt.has_prefix ("thick")) f.line = false;
                    if (attr (n, "bevelled") == "true") f.bevelled = true;
                    row.append (f);
                    return;
                case "msqrt":
                    row.append (new Radical (children_row (n)));
                    return;
                case "mroot":
                    if (kids.length < 2) return;
                    var rb = row_of (kids[0]);
                    var ri = row_of (kids[1]);
                    unbox (rb);
                    unbox (ri);
                    row.append (new Radical (rb, ri));
                    return;
                case "msub":
                case "msup":
                case "msubsup":
                    if (kids.length < 2) return;
                    var b = row_of (kids[0]);
                    Row? sub = null;
                    Row? sup = null;
                    if (name == "msub") sub = row_of (kids[1]);
                    else if (name == "msup") sup = row_of (kids[1]);
                    else {
                        sub = row_of (kids[1]);
                        if (kids.length > 2) sup = row_of (kids[2]);
                    }
                    if (sub != null) unbox (sub);
                    if (sup != null) {
                        unbox (sup);
                        mark_primes (sup);
                    }
                    append_base (row, b);
                    if (is_largeop_token (b) && row.size > 0 && row[row.size - 1] is Token) {
                        var bt = (Token) row[row.size - 1];
                        if (Symbols.has_limits (bt.text) || Symbols.function_has_limits (bt.text.replace (" ", ""))) bt.limits = 0;
                    }
                    row.append (new Scripts (sub, sup));
                    return;
                case "munder":
                case "mover":
                case "munderover":
                    if (kids.length < 2) return;
                    var ub = row_of (kids[0]);
                    Row? under = null;
                    Row? over = null;
                    if (name == "munder") under = row_of (kids[1]);
                    else if (name == "mover") over = row_of (kids[1]);
                    else {
                        under = row_of (kids[1]);
                        if (kids.length > 2) over = row_of (kids[2]);
                    }
                    if (under != null) unbox (under);
                    if (over != null) unbox (over);
                    underover (row, n, ub, under, over, kids);
                    return;
                case "mtable":
                    row.append (table (n));
                    return;
                case "mtr":
                case "mlabeledtr":
                case "mtd":
                    children_into (n, row);
                    return;
                case "menclose":
                    string note = attr (n, "notation").strip ();
                    if (note == "") note = "longdiv";
                    row.append (new Enclose (note, children_row (n)));
                    return;
                case "mphantom":
                    row.append (new Phantom (children_row (n)));
                    return;
                case "merror":
                    var er = children_row (n);
                    foreach (var en in er.items) if (en is Token) ((Token) en).error = true;
                    row.move_from (er);
                    return;
                case "mfenced":
                    string fo = n->get_prop ("open") ?? "(";
                    string fc = n->get_prop ("close") ?? ")";
                    string seps = (n->get_prop ("separators") ?? ",").replace (" ", "");
                    var fb = new Row ();
                    for (int k = 0; k < kids.length; k++) {
                        if (k > 0 && seps.length > 0) {
                            int si = int.min (k - 1, seps.char_count () - 1);
                            fb.append (new Token.op (seps.get_char (seps.index_of_nth_char (si)).to_string ()));
                        }
                        element_into (kids[k], fb);
                    }
                    row.append (new Fenced (fo, fc, fb));
                    return;
                case "mmultiscripts":
                    if (kids.length == 0) return;
                    var mb = row_of (kids[0]);
                    Xml.Node*[] post = {};
                    Xml.Node*[] pre = {};
                    bool in_pre = false;
                    for (int k = 1; k < kids.length; k++) {
                        if (kids[k]->name == "mprescripts") {
                            in_pre = true;
                            continue;
                        }
                        if (in_pre) pre += kids[k];
                        else post += kids[k];
                    }
                    if (pre.length >= 2) {
                        var ps = new Scripts (script_or_null (pre[0]), script_or_null (pre[1]));
                        ps.pre = true;
                        row.append (ps);
                    }
                    append_base (row, mb);
                    if (post.length >= 2) row.append (new Scripts (script_or_null (post[0]), script_or_null (post[1])));
                    return;
                default:
                    children_into (n, row);
                    return;
            }
        }

        private Row? script_or_null (Xml.Node* n) {
            if (n->name == "none") return null;
            var r = row_of (n);
            unbox (r);
            return r;
        }

        private static void mark_primes (Row sup) {
            foreach (var n in sup.items) {
                var t = n as Token;
                if (t == null) return;
                if (t.text != "\u2032" && t.text != "'") return;
            }
            foreach (var n in sup.items) {
                var t = (Token) n;
                t.text = "\u2032";
                t.kind = TokenKind.OPERATOR;
                t.prime = true;
            }
        }

        private void underover (Row row, Xml.Node* n, Row b, Row? under, Row? over, Xml.Node*[] kids) {
            bool accent = attr (n, "accent") == "true";
            bool accentunder = attr (n, "accentunder") == "true";
            string om = over != null ? mark_char (over) : "";
            string um = under != null ? mark_char (under) : "";
            if (is_largeop_token (b)) {
                row.move_from (b);
                var bt = (Token) row[row.size - 1];
                if (!Symbols.has_limits (bt.text) && !Symbols.function_has_limits (bt.text.replace (" ", ""))) bt.limits = 1;
                if (attr (kids[0], "movablelimits") == "false") bt.limits = 1;
                row.append (new Scripts (under, over));
                return;
            }
            if (over != null && under == null && accent_like (om) && (accent || Symbols.normalize_accent (om) != om || om.get_char (0) >= 0x23b4 || om == "\u203e" || om == "\u00af" || om == "\u2015")) {
                string? st = over.size == 1 ? stretchy_of (kids[1]) : null;
                unbox (b);
                row.append (make_accent (b, om, false, st));
                return;
            }
            if (under != null && over == null && accent_like (um) && (accentunder || um == "_" || um == "\u0332" || um.get_char (0) >= 0x23b4)) {
                string? st = stretchy_of (kids[1]);
                unbox (b);
                row.append (make_accent (b, um, true, st));
                return;
            }
            if (b.size == 1 && b[0] is Accent && ((Accent) b[0]).is_brace ()) {
                row.move_from (b);
                row.append (new Scripts (under, over));
                return;
            }
            var u = new UnderOver (b, under, over);
            u.accent_over = accent && !is_arrow (b);
            u.accent_under = accentunder;
            unbox (u.body);
            row.append (u);
        }

        private static string? stretchy_of (Xml.Node* n) {
            if (n->name != "mo") return null;
            return n->get_prop ("stretchy");
        }

        private Table table (Xml.Node* n) {
            string ca = attr (n, "columnalign").strip ();
            var aligns = ca.split (" ");
            var t = new Table (TableKind.MATRIX);
            bool alternating = aligns.length >= 2;
            for (int i = 0; i < aligns.length; i++) {
                string want = i % 2 == 0 ? "right" : "left";
                if (aligns[i] != want) alternating = false;
            }
            string cols = "";
            foreach (var a in aligns) {
                if (a == "left") cols += "l";
                else if (a == "right") cols += "r";
                else if (a == "center") cols += "c";
            }
            if (alternating) t.kind = TableKind.ALIGN;
            else if (cols != "" && cols.replace ("c", "") != "") {
                t.kind = TableKind.ARRAY;
                t.columns = cols;
            }
            if (attr (n, "displaystyle") == "true" && !alternating && cols == "") t.kind = TableKind.GATHER;
            string cs = attr (n, "columnspacing").strip ();
            if (cs != "" && !alternating) t.column_gap = LatexParser.dimension_to_em (cs.split (" ")[0]);
            string rs = attr (n, "rowspacing").strip ();
            if (rs != "") t.row_gap = LatexParser.dimension_to_em (rs.split (" ")[0]);
            string cl = attr (n, "columnlines").strip ();
            if (cl != "") {
                if (t.kind != TableKind.ARRAY) {
                    t.kind = TableKind.ARRAY;
                    if (t.columns == "") t.columns = "c";
                }
                var sb = new StringBuilder ();
                foreach (var l in cl.split (" ")) sb.append (l == "solid" || l == "dashed" ? "s" : "n");
                t.column_lines = sb.str;
            }
            foreach (Xml.Node* tr in elements (n)) {
                if (tr->name != "mtr" && tr->name != "mlabeledtr") continue;
                var cells = new Gee.ArrayList<Row> ();
                string? label = null;
                bool first = true;
                foreach (Xml.Node* td in elements (tr)) {
                    if (td->name != "mtd") continue;
                    if (tr->name == "mlabeledtr" && first) {
                        first = false;
                        string l = (td->get_content () ?? "").strip ();
                        if (l.has_prefix ("(") && l.has_suffix (")")) l = l.substring (1, l.length - 2);
                        if (tr->get_prop ("data-auto") == "true") {
                            auto_seen = true;
                            label = null;
                        } else {
                            label = l;
                        }
                        continue;
                    }
                    first = false;
                    cells.add (children_row (td));
                }
                t.add_row_cells (cells, label, false, tr->get_prop ("id"));
            }
            if (t.kind == TableKind.MATRIX && t.column_count == 1 && t.tags.size > 0) {
                bool any = false;
                foreach (var tg in t.tags) if (tg != null) any = true;
                if (any) t.kind = TableKind.GATHER;
            }
            t.normalize ();
            return t;
        }

        private static double named_space (string w) {
            switch (w.strip ()) {
                case "veryverythinmathspace": return 1.0 / 18.0;
                case "verythinmathspace": return 2.0 / 18.0;
                case "thinmathspace": return 3.0 / 18.0;
                case "mediummathspace": return 4.0 / 18.0;
                case "thickmathspace": return 5.0 / 18.0;
                case "verythickmathspace": return 6.0 / 18.0;
                case "veryverythickmathspace": return 7.0 / 18.0;
                case "": return 0;
                default:
                    double v = LatexParser.dimension_to_em (w);
                    double k = Math.round (v * 18.0);
                    if (Math.fabs (v * 18.0 - k) < 0.02) return k / 18.0;
                    return v;
            }
        }

        private void apply_variant (Row r, MathVariant v) {
            foreach (var n in r.items) {
                var t = n as Token;
                if (t != null) {
                    if (t.variant == MathVariant.DEFAULT) t.variant = v;
                    continue;
                }
                foreach (var s in n.slots ()) apply_variant (s, v);
            }
        }

        private void append_colored (Row row, Token t, Xml.Node* n) {
            string col = attr (n, "mathcolor");
            if (col == "") {
                row.append (t);
                return;
            }
            var st = new Style ();
            st.color = col;
            st.body.append (t);
            row.append (st);
        }

        private void append_row_colored (Row row, Row items, Xml.Node* n) {
            string col = attr (n, "mathcolor");
            if (col == "") {
                row.move_from (items);
                return;
            }
            var st = new Style (items);
            st.color = col;
            row.append (st);
        }

        public static Token token_from_text (TokenKind kind, string text) {
            if (text.char_count () == 1) {
                unichar c = text.get_char (0);
                MathVariant v;
                unichar plain = Unimath.from_styled (c, out v);
                if (v != MathVariant.DEFAULT) {
                    var t = new Token (kind, plain.to_string ());
                    t.variant = v;
                    if (v == MathVariant.ITALIC && kind == TokenKind.IDENT) t.variant = MathVariant.DEFAULT;
                    return t;
                }
            }
            return new Token (kind, text);
        }
    }
}
