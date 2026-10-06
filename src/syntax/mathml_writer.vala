namespace Singularity.Apps.Formula {

    public class MathmlWriter {
        public const string NS = "http://www.w3.org/1998/Math/MathML";

        public static Gee.Map<string, string>? refs;
        public static Gee.Set<int>? auto_rows;
        public static bool auto_single;
        public static Singularity.Equations.NumberStyle number_style = Singularity.Equations.NumberStyle.PARENS;

        private StringBuilder sb = new StringBuilder ();
        private bool pretty;
        private int level;
        private string prefix = "";

        public static string write (Row root, bool display = true, string? latex = null, bool pretty = true, string? tag = null, string prefix = "", string encoding = "application/x-tex") {
            var w = new MathmlWriter ();
            w.pretty = pretty;
            w.prefix = prefix;
            string attrs = " xmlns" + (prefix != "" ? ":" + prefix : "") + "=\"" + NS + "\"" + (display ? " display=\"block\"" : "");
            w.open ("math", attrs);
            if (latex != null) w.open ("semantics");
            if (tag != null) {
                var t = new Table (TableKind.GATHER);
                var cells = new Gee.ArrayList<Row> ();
                cells.add (root);
                t.add_row_cells (cells, tag, false);
                w.table_element (t);
                foreach (var c in cells) c.parent = null;
            } else {
                w.row_element (root, latex != null);
            }
            if (latex != null) {
                w.leaf ("annotation", " encoding=\"" + encoding + "\"", latex);
                w.close ("semantics");
            }
            w.close ("math");
            return w.sb.str;
        }

        public static string wrap_label (string label) {
            switch (number_style) {
                case Singularity.Equations.NumberStyle.BRACKETS: return "[" + label + "]";
                case Singularity.Equations.NumberStyle.PLAIN: return label;
                default: return "(" + label + ")";
            }
        }

        public static string escape (string s) {
            return Markup.escape_text (s);
        }

        private string tagname (string name) {
            return prefix != "" ? prefix + ":" + name : name;
        }

        private void indent () {
            if (!pretty) return;
            for (int i = 0; i < level; i++) sb.append ("  ");
        }

        private void nl () {
            if (pretty) sb.append_c ('\n');
        }

        private void open (string name, string attrs = "") {
            indent ();
            sb.append ("<").append (tagname (name)).append (attrs).append (">");
            nl ();
            level++;
        }

        private void close (string name) {
            level--;
            indent ();
            sb.append ("</").append (tagname (name)).append (">");
            nl ();
        }

        private void leaf (string name, string attrs, string text) {
            indent ();
            sb.append ("<").append (tagname (name)).append (attrs).append (">").append (escape (text)).append ("</").append (tagname (name)).append (">");
            nl ();
        }

        private void empty (string name, string attrs = "") {
            indent ();
            sb.append ("<").append (tagname (name)).append (attrs).append ("/>");
            nl ();
        }

        private static string em (double v) {
            return Format.num (v) + "em";
        }

        private void row_element (Row r, bool force = false) {
            int count = units (r);
            if (count == 1 && !force) {
                items (r);
                return;
            }
            if (count == 0) {
                empty ("mrow");
                return;
            }
            open ("mrow");
            items (r);
            close ("mrow");
        }

        private int units (Row r) {
            int n = 0;
            int i = 0;
            while (i < r.size) {
                int next = run_end (r, i);
                if (next == i) next = i + 1;
                if (next < r.size && r[next] is Scripts && !((Scripts) r[next]).pre) next++;
                if (r[i] is Scripts && ((Scripts) r[i]).pre && next < r.size) next++;
                n++;
                i = next;
            }
            return n;
        }

        private static bool mergeable (Token a, Token b) {
            if (a.kind != b.kind || a.variant != b.variant || a.error || b.error) return false;
            return a.kind == TokenKind.NUMBER || a.kind == TokenKind.TEXT;
        }

        private int run_end (Row r, int i) {
            var t = r[i] as Token;
            if (t == null || (t.kind != TokenKind.NUMBER && t.kind != TokenKind.TEXT)) return i + 1;
            int j = i + 1;
            while (j < r.size && r[j] is Token && mergeable (t, (Token) r[j])) j++;
            return j;
        }

        private void items (Row r) {
            int i = 0;
            while (i < r.size) {
                var n = r[i];
                if (n is Scripts && ((Scripts) n).pre) {
                    var s = (Scripts) n;
                    open ("mmultiscripts");
                    int end = i + 1;
                    if (end < r.size) {
                        int e2 = run_end (r, end);
                        unit (r, end, e2);
                        end = e2;
                    } else {
                        empty ("mrow");
                    }
                    empty ("mprescripts");
                    script_slot (s.sub);
                    script_slot (s.sup);
                    close ("mmultiscripts");
                    i = end;
                    continue;
                }
                int end = run_end (r, i);
                if (end < r.size && r[end] is Scripts && !((Scripts) r[end]).pre) {
                    scripted (r, i, end, (Scripts) r[end]);
                    i = end + 1;
                    continue;
                }
                if (n is Scripts) {
                    scripted (r, i, i, (Scripts) n);
                    i++;
                    continue;
                }
                unit (r, i, end);
                if (n is Token && ((Token) n).kind == TokenKind.IDENT && ((Token) n).text.char_count () > 1 && ((Token) n).forced_class == AtomClass.OP && end < r.size && !(r[end] is Space)) {
                    leaf ("mo", "", "\u2061");
                }
                i = end;
            }
        }

        private void script_slot (Row? r) {
            if (r == null) empty ("none");
            else row_element (r);
        }

        private bool limits_base (Row r, int from, int to) {
            if (to - from != 1) return false;
            var t = r[from] as Token;
            if (t != null) {
                if (t.limits == 1) return true;
                if (t.limits == 0) return false;
                if (Symbols.has_limits (t.text)) return true;
                if (t.kind == TokenKind.IDENT && Symbols.function_has_limits (t.text.replace (" ", ""))) return true;
                return false;
            }
            var a = r[from] as Accent;
            return a != null && a.is_brace ();
        }

        private void scripted (Row r, int from, int to, Scripts s) {
            bool lim = limits_base (r, from, to);
            string name;
            if (lim) name = s.sub != null && s.sup != null ? "munderover" : (s.sub != null ? "munder" : "mover");
            else name = s.sub != null && s.sup != null ? "msubsup" : (s.sub != null ? "msub" : "msup");
            string attrs = "";
            var t = to > from ? r[from] as Token : null;
            if (lim && t != null && t.limits == 1 && !Symbols.has_limits (t.text) && !Symbols.function_has_limits (t.text.replace (" ", ""))) attrs = "";
            open (name, attrs);
            if (to > from) {
                if (to - from == 1 && t != null && t.limits == 1 && !Symbols.has_limits (t.text) && t.kind == TokenKind.OPERATOR) {
                    leaf ("mo", " movablelimits=\"false\"", t.text);
                } else {
                    unit (r, from, to);
                }
            } else {
                empty ("mrow");
            }
            if (s.sub != null) row_element (s.sub);
            if (s.sup != null) row_element (s.sup);
            close (name);
        }

        private void unit (Row r, int from, int to) {
            var n = r[from];
            if (n is Token && to - from > 1) {
                var sb2 = new StringBuilder ();
                for (int k = from; k < to; k++) sb2.append (((Token) r[k]).text);
                var t = (Token) n;
                string text = sb2.str;
                if (t.kind == TokenKind.TEXT) text = text.replace (" ", "\u00a0");
                leaf (t.kind == TokenKind.NUMBER ? "mn" : "mtext", variant_attr (t), text);
                return;
            }
            node (n);
        }

        private static string variant_attr (Token t) {
            if (t.variant == MathVariant.DEFAULT) return "";
            if (t.kind == TokenKind.TEXT && t.variant == MathVariant.NORMAL) return "";
            if (t.kind == TokenKind.NUMBER && t.variant == MathVariant.NORMAL) return "";
            if (t.kind == TokenKind.OPERATOR && t.variant == MathVariant.NORMAL) return "";
            if (t.kind == TokenKind.IDENT && t.text.char_count () > 1 && t.variant == MathVariant.NORMAL) return "";
            return " mathvariant=\"" + t.variant.to_mathml () + "\"";
        }

        private void token (Token t) {
            string attrs = variant_attr (t);
            switch (t.kind) {
                case TokenKind.IDENT:
                    if (t.error) {
                        open ("merror");
                        leaf ("mtext", "", t.text);
                        close ("merror");
                        return;
                    }
                    if (t.forced_class == AtomClass.BIN || t.forced_class == AtomClass.REL) {
                        leaf ("mo", attrs, t.text);
                        return;
                    }
                    leaf ("mi", attrs, t.text);
                    return;
                case TokenKind.NUMBER:
                    leaf ("mn", attrs, t.text);
                    return;
                case TokenKind.TEXT:
                    leaf ("mtext", attrs, t.text.replace (" ", "\u00a0"));
                    return;
                default:
                    var a = new StringBuilder (attrs);
                    if (t.min_size > 0) {
                        a.append (" minsize=\"").append (em (t.min_size)).append ("\" maxsize=\"").append (em (t.min_size)).append ("\"");
                        if (t.forced_class == AtomClass.OPEN) a.append (" form=\"prefix\"");
                        else if (t.forced_class == AtomClass.CLOSE) a.append (" form=\"postfix\"");
                    } else if (t.fence_middle) {
                        a.append (" fence=\"true\" stretchy=\"true\" form=\"infix\"");
                    } else if (Symbols.is_fence (t.text)) {
                        a.append (" stretchy=\"false\"");
                    }
                    if (t.limits == 0 && Symbols.has_limits (t.text)) a.append (" movablelimits=\"false\"");
                    if (t.forced_class == AtomClass.ORD && Symbols.char_class (t.text) != AtomClass.ORD) a.append (" lspace=\"0em\" rspace=\"0em\"");
                    if (t.forced_class == AtomClass.BIN && Symbols.char_class (t.text) != AtomClass.BIN) a.append (" lspace=\"0.2222em\" rspace=\"0.2222em\"");
                    if (t.forced_class == AtomClass.REL && Symbols.char_class (t.text) != AtomClass.REL && t.min_size == 0) a.append (" lspace=\"0.2778em\" rspace=\"0.2778em\"");
                    leaf ("mo", a.str, t.text);
                    return;
            }
        }

        private void node (Node n) {
            if (n is Token) {
                token ((Token) n);
                return;
            }
            if (n is Space) {
                empty ("mspace", " width=\"" + em (((Space) n).width) + "\"");
                return;
            }
            if (n is Frac) {
                var f = (Frac) n;
                var a = new StringBuilder ();
                if (!f.line) a.append (" linethickness=\"0\"");
                if (f.bevelled) a.append (" bevelled=\"true\"");
                if (f.display >= 0) open ("mstyle", " displaystyle=\"" + (f.display == 1 ? "true" : "false") + "\"" + (f.display == 0 ? " scriptlevel=\"0\"" : ""));
                open ("mfrac", a.str);
                row_element (f.num);
                row_element (f.den);
                close ("mfrac");
                if (f.display >= 0) close ("mstyle");
                return;
            }
            if (n is Radical) {
                var r = (Radical) n;
                if (r.index == null) {
                    open ("msqrt");
                    items (r.body);
                    close ("msqrt");
                } else {
                    open ("mroot");
                    row_element (r.body);
                    row_element (r.index);
                    close ("mroot");
                }
                return;
            }
            if (n is Scripts) {
                var s = (Scripts) n;
                string name = s.sub != null && s.sup != null ? "msubsup" : (s.sub != null ? "msub" : "msup");
                open (name);
                empty ("mrow");
                if (s.sub != null) row_element (s.sub);
                if (s.sup != null) row_element (s.sup);
                close (name);
                return;
            }
            if (n is UnderOver) {
                var u = (UnderOver) n;
                string name = u.under != null && u.over != null ? "munderover" : (u.under != null ? "munder" : "mover");
                var a = new StringBuilder ();
                if (u.accent_over) a.append (" accent=\"true\"");
                if (u.accent_under) a.append (" accentunder=\"true\"");
                open (name, a.str);
                if (u.body.size == 1 && u.body[0] is Token && ((Token) u.body[0]).kind == TokenKind.OPERATOR && is_arrow (((Token) u.body[0]).text)) {
                    leaf ("mo", " stretchy=\"true\"", ((Token) u.body[0]).text);
                } else {
                    row_element (u.body);
                }
                if (u.under != null) row_element (u.under);
                if (u.over != null) row_element (u.over);
                close (name);
                return;
            }
            if (n is Accent) {
                var a = (Accent) n;
                string name = a.under ? "munder" : "mover";
                bool accent = !a.is_brace ();
                open (name, accent ? (a.under ? " accentunder=\"true\"" : " accent=\"true\"") : "");
                row_element (a.body);
                string mark = a.is_line () ? (a.under ? "_" : "\u203e") : Symbols.spacing_accent (a.mark);
                leaf ("mo", a.stretchy ? " stretchy=\"true\"" : " stretchy=\"false\"", mark);
                close (name);
                return;
            }
            if (n is Fenced) {
                var f = (Fenced) n;
                open ("mrow");
                if (f.open != "") leaf ("mo", " fence=\"true\" form=\"prefix\"", f.open);
                items (f.body);
                if (f.close != "") leaf ("mo", " fence=\"true\" form=\"postfix\"", f.close);
                close ("mrow");
                return;
            }
            if (n is Table) {
                var t = (Table) n;
                string o = t.kind.open_delim ();
                string c = t.kind.close_delim ();
                if (o != "" || c != "") {
                    open ("mrow");
                    if (o != "") leaf ("mo", " fence=\"true\" form=\"prefix\"", o);
                    table_element (t);
                    if (c != "") leaf ("mo", " fence=\"true\" form=\"postfix\"", c);
                    close ("mrow");
                } else {
                    table_element (t);
                }
                return;
            }
            if (n is Style) {
                var s = (Style) n;
                var a = new StringBuilder ();
                if (s.display >= 0) a.append (" displaystyle=\"").append (s.display == 1 ? "true" : "false").append ("\"");
                if (s.script_level >= 0) a.append (" scriptlevel=\"").append (s.script_level.to_string ()).append ("\"");
                if (s.color != null) a.append (" mathcolor=\"").append (escape (css_color (s.color))).append ("\"");
                if (s.background != null) a.append (" mathbackground=\"").append (escape (css_color (s.background))).append ("\"");
                if (Math.fabs (s.scale - 1.0) > 1e-6) a.append (" mathsize=\"").append (Format.num (s.scale * 100)).append ("%\"");
                open ("mstyle", a.str);
                items (s.body);
                close ("mstyle");
                return;
            }
            if (n is Enclose) {
                var e = (Enclose) n;
                open ("menclose", " notation=\"" + escape (e.notation) + "\"");
                items (e.body);
                close ("menclose");
                return;
            }
            if (n is Phantom) {
                var p = (Phantom) n;
                if (!p.keep_height) open ("mpadded", " height=\"0\" depth=\"0\"");
                if (!p.keep_width) open ("mpadded", " width=\"0\"");
                open ("mphantom");
                items (p.body);
                close ("mphantom");
                if (!p.keep_width) close ("mpadded");
                if (!p.keep_height) close ("mpadded");
                return;
            }
            if (n is Group) {
                open ("mrow");
                items (((Group) n).body);
                close ("mrow");
                return;
            }
            if (n is Ref) {
                var rf = (Ref) n;
                string num = refs != null && refs.has_key (rf.name) ? refs[rf.name] : "?";
                leaf ("mtext", " data-ref=\"" + escape (rf.name) + "\"" + (rf.paren ? " data-paren=\"true\"" : ""), rf.paren ? wrap_label (num) : num);
                return;
            }
        }

        private static bool is_arrow (string s) {
            unichar c = s.get_char (0);
            return (c >= 0x2190 && c <= 0x21ff) || (c >= 0x27f0 && c <= 0x27ff);
        }

        public static string css_color (string c) {
            if (c.has_prefix ("#")) return c;
            if (c.length == 6) {
                bool hex = true;
                for (int i = 0; i < 6; i++) if (!c[i].isxdigit ()) hex = false;
                if (hex) return "#" + c;
            }
            return c;
        }

        private void table_element (Table t) {
            var a = new StringBuilder ();
            int n = t.column_count;
            if (t.kind == TableKind.ALIGN) {
                a.append (" columnalign=\"");
                for (int c = 0; c < n; c++) a.append (c > 0 ? " " : "").append (c % 2 == 0 ? "right" : "left");
                a.append ("\" columnspacing=\"");
                for (int c = 0; c < n - 1; c++) a.append (c > 0 ? " " : "").append (c % 2 == 0 ? "0em" : "2em");
                if (n <= 1) a.append ("0em");
                a.append ("\" displaystyle=\"true\"");
            } else if (t.kind == TableKind.GATHER) {
                a.append (" displaystyle=\"true\"");
            } else if (t.kind == TableKind.CASES) {
                a.append (" columnalign=\"left left\"");
            } else if (t.columns != "") {
                a.append (" columnalign=\"");
                for (int c = 0; c < n; c++) {
                    char al = t.column_align (c);
                    a.append (c > 0 ? " " : "").append (al == 'l' ? "left" : (al == 'r' ? "right" : "center"));
                }
                a.append ("\"");
            }
            if (t.kind == TableKind.ARRAY && t.column_lines.contains ("s")) {
                a.append (" columnlines=\"");
                for (int c = 0; c < n - 1; c++) a.append (c > 0 ? " " : "").append (c < t.column_lines.length && t.column_lines[c] == 's' ? "solid" : "none");
                a.append ("\"");
            }
            if (t.kind == TableKind.SMALL_MATRIX) a.append (" displaystyle=\"false\" scriptlevel=\"1\"");
            if (t.column_gap >= 0) a.append (" columnspacing=\"").append (em (t.column_gap)).append ("\"");
            if (t.row_gap >= 0) a.append (" rowspacing=\"").append (em (t.row_gap)).append ("\"");
            open ("mtable", a.str);
            for (int r = 0; r < t.rows.size; r++) {
                bool labeled = t.tags[r] != null;
                string id = t.names[r] != null ? " id=\"" + escape (t.names[r]) + "\"" : "";
                if (labeled && ((auto_rows != null && auto_rows.contains (r)) || (auto_single && t.rows.size == 1 && t.kind == TableKind.GATHER))) id += " data-auto=\"true\"";
                open (labeled ? "mlabeledtr" : "mtr", id);
                if (labeled) {
                    open ("mtd");
                    leaf ("mtext", "", wrap_label (t.tags[r]));
                    close ("mtd");
                }
                foreach (var cell in t.rows[r]) {
                    open ("mtd");
                    items (cell);
                    close ("mtd");
                }
                close (labeled ? "mlabeledtr" : "mtr");
            }
            close ("mtable");
        }
    }
}
