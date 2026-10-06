namespace Singularity.Apps.Formula {

    public class LatexWriter {
        private StringBuilder sb = new StringBuilder ();

        public static string write (Row root, string? tag = null, string? label = null) {
            var w = new LatexWriter ();
            w.row (root);
            if (tag != null) w.emit ("\\tag{" + tag + "}");
            if (label != null) w.emit ("\\label{" + label + "}");
            return w.sb.str.strip ();
        }

        public static string write_node (Node n) {
            var w = new LatexWriter ();
            w.node (n, null);
            return w.sb.str.strip ();
        }

        private bool ends_with_control_word () {
            int i = (int) sb.len - 1;
            int letters = 0;
            while (i >= 0 && sb.str[i].isalpha ()) {
                i--;
                letters++;
            }
            if (letters == 0 || i < 0 || sb.str[i] != '\\') return false;
            int slashes = 0;
            while (i >= 0 && sb.str[i] == '\\') {
                i--;
                slashes++;
            }
            return slashes % 2 == 1;
        }

        private void emit (string s) {
            if (s.length == 0) return;
            if (ends_with_control_word ()) {
                unichar c = s.get_char (0);
                if (c.isalnum () || c == '*') sb.append_c (' ');
            }
            sb.append (s);
        }

        private string sub_write (Row r) {
            var w = new LatexWriter ();
            w.row (r);
            return w.sb.str;
        }

        private string braced (Row r) {
            return "{" + sub_write (r) + "}";
        }

        private string script_arg (Row r) {
            return "{" + sub_write (r) + "}";
        }

        private static bool is_text_run (Node n, MathVariant v) {
            var t = n as Token;
            return t != null && t.kind == TokenKind.TEXT && t.variant == v && !t.error;
        }

        private static bool variant_applies (Token t) {
            if (t.error || t.kind == TokenKind.TEXT) return false;
            if (t.variant == MathVariant.DEFAULT) return false;
            if (t.kind == TokenKind.NUMBER && t.variant == MathVariant.NORMAL) return false;
            if (t.kind == TokenKind.IDENT && t.text.char_count () > 1 && t.variant == MathVariant.NORMAL) return false;
            if (t.kind == TokenKind.OPERATOR && t.variant == MathVariant.NORMAL) return false;
            if (t.kind == TokenKind.IDENT && t.variant == MathVariant.NORMAL && Symbols.by_char (t.text) != null && Symbols.by_char (t.text).category == "greek") {
                unichar c = t.text.get_char (0);
                if (c >= 0x391 && c <= 0x3a9) return false;
            }
            return true;
        }

        public void row (Row r) {
            int i = 0;
            while (i < r.size) {
                var n = r[i];
                var t = n as Token;
                if (t != null && t.kind == TokenKind.TEXT && !t.error) {
                    var text = new StringBuilder ();
                    var v = t.variant;
                    while (i < r.size && is_text_run (r[i], v)) {
                        text.append (escape_text (((Token) r[i]).text));
                        i++;
                    }
                    string cmd = "text";
                    if (v == MathVariant.BOLD) cmd = "textbf";
                    else if (v == MathVariant.ITALIC) cmd = "textit";
                    else if (v == MathVariant.MONOSPACE) cmd = "texttt";
                    else if (v == MathVariant.SANS_SERIF) cmd = "textsf";
                    emit ("\\" + cmd + "{" + text.str + "}");
                    continue;
                }
                if (t != null && variant_applies (t)) {
                    var v = t.variant;
                    var inner = new StringBuilder ();
                    var w = new LatexWriter ();
                    while (i < r.size && r[i] is Token && ((Token) r[i]).variant == v && variant_applies ((Token) r[i])) {
                        w.token ((Token) r[i], true);
                        i++;
                    }
                    inner.append (w.sb.str);
                    string? fc = Symbols.font_command_for (v);
                    emit ("\\" + (fc ?? "mathrm") + "{" + inner.str + "}");
                    continue;
                }
                node (n, i > 0 ? r[i - 1] : null);
                i++;
            }
        }

        private static string escape_text (string s) {
            switch (s) {
                case "{": return "\\{";
                case "}": return "\\}";
                case "\\": return "\\textbackslash{}";
                case "%": return "\\%";
                case "$": return "\\$";
                case "&": return "\\&";
                case "#": return "\\#";
                case "_": return "\\_";
                case "\u00a0": return "~";
                default: return s;
            }
        }

        private void token (Token t, bool plain = false) {
            if (t.error) {
                emit (t.text);
                return;
            }
            string s = token_body (t);
            if (!plain && t.forced_class != AtomClass.NONE && needs_class_wrapper (t)) {
                string w = "mathord";
                switch (t.forced_class) {
                    case AtomClass.BIN: w = "mathbin"; break;
                    case AtomClass.REL: w = "mathrel"; break;
                    case AtomClass.OP: w = "mathop"; break;
                    case AtomClass.OPEN: w = "mathopen"; break;
                    case AtomClass.CLOSE: w = "mathclose"; break;
                    case AtomClass.PUNCT: w = "mathpunct"; break;
                    case AtomClass.INNER: w = "mathinner"; break;
                    default: break;
                }
                s = "\\" + w + "{" + s + "}";
            }
            emit (s);
            if (t.limits == 1 && !(t.kind == TokenKind.IDENT && t.text.char_count () > 1 && !Symbols.is_function (t.text.replace (" ", "")))) {
                if (!Symbols.has_limits (t.text) && !Symbols.function_has_limits (t.text.replace (" ", ""))) emit ("\\limits");
            } else if (t.limits == 0) {
                if (Symbols.has_limits (t.text) || Symbols.function_has_limits (t.text)) emit ("\\nolimits");
            }
        }

        private bool needs_class_wrapper (Token t) {
            if (t.min_size > 0) return false;
            if (t.kind == TokenKind.IDENT && t.text.char_count () > 1) return false;
            if (t.text == "{" || t.text == "}") return false;
            if (t.text == "\u2026" || t.text == "\u22ef") return false;
            if (t.text == ":" && t.forced_class == AtomClass.PUNCT) return false;
            var sym = Symbols.by_char (t.text);
            if (sym != null && sym.cls == t.forced_class) return false;
            if (Symbols.char_class (t.text) == t.forced_class) return false;
            if (t.kind == TokenKind.IDENT && t.text == "mod" && t.forced_class == AtomClass.BIN) return false;
            return true;
        }

        private string token_body (Token t) {
            string text = t.text;
            if (t.min_size > 0) {
                string size = t.min_size <= 1.2 ? "big" : (t.min_size <= 1.8 ? "Big" : (t.min_size <= 2.4 ? "bigg" : "Bigg"));
                if (t.forced_class == AtomClass.OPEN) size += "l";
                else if (t.forced_class == AtomClass.CLOSE) size += "r";
                else if (t.forced_class == AtomClass.REL) size += "m";
                return "\\" + size + delimiter (text == "." ? "" : text);
            }
            switch (t.kind) {
                case TokenKind.NUMBER:
                    return text;
                case TokenKind.IDENT:
                    if (text.char_count () > 1) {
                        string compact = text.replace (" ", "");
                        if (Symbols.is_tex_function (compact) && t.forced_class != AtomClass.BIN) {
                            return "\\" + compact;
                        }
                        if (compact == "mod" && t.forced_class == AtomClass.BIN) return "\\bmod";
                        if (text.has_prefix ("\\")) return text;
                        return "\\operatorname" + (t.limits == 1 ? "*" : "") + "{" + escape_text_all (text) + "}";
                    }
                    return symbol_text (text);
                case TokenKind.OPERATOR:
                    if (t.fence_middle) return "\\middle" + delimiter (text);
                    switch (text) {
                        case "\u2212": return "-";
                        case "\u2217": return "*";
                        case "{": return "\\{";
                        case "}": return "\\}";
                        case "\u2016": return "\\|";
                        case "\u2026": return t.forced_class == AtomClass.INNER || t.forced_class == AtomClass.NONE ? "\\ldots" : "\\ldots";
                        case "\u22ef": return "\\cdots";
                        default: return symbol_text (text);
                    }
                default:
                    return escape_text (text);
            }
        }

        private static string escape_text_all (string s) {
            var sb = new StringBuilder ();
            int i = 0;
            unichar c;
            while (s.get_next_char (ref i, out c)) sb.append (escape_text (c.to_string ()));
            return sb.str;
        }

        private static string symbol_text (string text) {
            switch (text) {
                case "#": return "\\#";
                case "$": return "\\$";
                case "%": return "\\%";
                case "&": return "\\&";
                case "_": return "\\_";
                case "\\": return "\\backslash";
                case "\u2032": return "\\prime";
                case "|": case "(": case ")": case "[": case "]": case "<": case ">": case "=": case "+": case ",": case ";": case ":": case "!": case "?": case ".": case "/": return text;
                default: break;
            }
            if (text.char_count () == 2 && text.get_char (text.index_of_nth_char (1)) == 0x338) {
                return "\\not" + symbol_text (text.substring (0, text.index_of_nth_char (1)));
            }
            var cmd = Symbols.command_for_char (text);
            if (cmd != null) {
                if (cmd == "lbrace") return "\\{";
                if (cmd == "rbrace") return "\\}";
                if (cmd == "lbrack") return "[";
                if (cmd == "rbrack") return "]";
                if (cmd == "vert") return "|";
                if (cmd == "Vert") return "\\|";
                if (cmd == "colon") return ":";
                if (cmd == "backslash") return "\\backslash";
                return "\\" + cmd;
            }
            return text;
        }

        private static string delimiter (string ch) {
            return Symbols.delimiter_name (ch);
        }

        private static bool simple_fence_content (Row body) {
            foreach (var n in body.items) {
                if (n is Token) {
                    var t = (Token) n;
                    if (t.fence_middle || t.min_size > 0) return false;
                    if (Symbols.is_large_op (t.text)) return false;
                    continue;
                }
                if (n is Space) continue;
                if (n is Scripts) {
                    var s = (Scripts) n;
                    foreach (var slot in s.slots ()) if (!flat_content (slot)) return false;
                    continue;
                }
                if (n is Group || n is Accent) {
                    if (n is Accent && ((Accent) n).is_brace ()) return false;
                    if (!flat_content (n.slots ()[0])) return false;
                    continue;
                }
                return false;
            }
            return true;
        }

        private static bool flat_content (Row r) {
            foreach (var n in r.items) {
                if (n is Token || n is Space) continue;
                if (n is Group && flat_content (((Group) n).body)) continue;
                return false;
            }
            return true;
        }

        private static bool plain_fence (string d) {
            return d == "(" || d == ")" || d == "[" || d == "]" || d == "|" || d == "{" || d == "}" || d == "\u2016"
                || d == "\u27e8" || d == "\u27e9" || d == "\u230a" || d == "\u230b" || d == "\u2308" || d == "\u2309";
        }

        public void node (Node n, Node? prev) {
            if (n is Token) {
                token ((Token) n);
                return;
            }
            if (n is Space) {
                emit (Symbols.space_command (((Space) n).width));
                return;
            }
            if (n is Frac) {
                var f = (Frac) n;
                if (!f.line) {
                    emit ("{" + sub_write (f.num) + " \\atop " + sub_write (f.den) + "}");
                    return;
                }
                string cmd = "frac";
                if (f.bevelled) cmd = "sfrac";
                else if (f.continued) cmd = "cfrac";
                else if (f.display == 1) cmd = "dfrac";
                else if (f.display == 0) cmd = "tfrac";
                emit ("\\" + cmd + braced (f.num) + braced (f.den));
                return;
            }
            if (n is Radical) {
                var r = (Radical) n;
                if (r.index != null) emit ("\\sqrt[" + sub_write (r.index) + "]" + braced (r.body));
                else emit ("\\sqrt" + braced (r.body));
                return;
            }
            if (n is Scripts) {
                var s = (Scripts) n;
                if (prev == null || prev is Scripts || prev is Space || s.pre) emit ("{}");
                bool primes = s.sup != null && LatexParser.is_prime_row (s.sup);
                if (primes) {
                    var p = new StringBuilder ();
                    for (int i = 0; i < s.sup.size; i++) p.append ("'");
                    emit (p.str);
                }
                if (s.sub != null) emit ("_" + script_arg (s.sub));
                if (s.sup != null && !primes) emit ("^" + script_arg (s.sup));
                return;
            }
            if (n is UnderOver) {
                var u = (UnderOver) n;
                if (u.body.size == 1 && u.body[0] is Token) {
                    var bt = (Token) u.body[0];
                    string? x = x_command (bt.text);
                    if (x != null && bt.kind == TokenKind.OPERATOR && u.over != null) {
                        emit ("\\" + x + (u.under != null ? "[" + sub_write (u.under) + "]" : "") + braced (u.over));
                        return;
                    }
                    if (Symbols.is_large_op (bt.text) || (bt.kind == TokenKind.IDENT && Symbols.function_has_limits (bt.text.replace (" ", "")))) {
                        token (bt, true);
                        if (!Symbols.has_limits (bt.text) && !Symbols.function_has_limits (bt.text.replace (" ", ""))) emit ("\\limits");
                        if (u.under != null) emit ("_" + script_arg (u.under));
                        if (u.over != null) emit ("^" + script_arg (u.over));
                        return;
                    }
                }
                string inner = braced (u.body);
                if (u.over != null) inner = "{\\overset" + braced (u.over) + inner + "}";
                if (u.under != null) inner = "{\\underset" + braced (u.under) + inner + "}";
                if (inner.has_prefix ("{\\") && inner.has_suffix ("}")) inner = inner.substring (1, inner.length - 2);
                emit (inner);
                return;
            }
            if (n is Accent) {
                var a = (Accent) n;
                var info = Symbols.accent_for_mark (a.mark, a.stretchy, a.under);
                if (info != null) {
                    emit ("\\" + info.command + braced (a.body));
                } else {
                    var mr = new Row ();
                    mr.append (new Token.op (a.mark));
                    emit ((a.under ? "\\underset" : "\\overset") + braced (mr) + braced (a.body));
                }
                return;
            }
            if (n is Fenced) {
                var f = (Fenced) n;
                if (f.open == "(" && f.close == ")" && f.body.size == 1 && f.body[0] is Frac && !((Frac) f.body[0]).line) {
                    var bf = (Frac) f.body[0];
                    string cmd = bf.display == 1 ? "dbinom" : (bf.display == 0 ? "tbinom" : "binom");
                    emit ("\\" + cmd + braced (bf.num) + braced (bf.den));
                    return;
                }
                if (Fences.plain (f.open) && Fences.plain (f.close) && f.open != "" && f.close != "" && Fences.simple_content (f.body)) {
                    emit (plain_delim (f.open));
                    row (f.body);
                    emit (plain_delim (f.close));
                    return;
                }
                emit ("\\left" + delimiter (f.open));
                if (!delimiter (f.open).has_prefix ("\\")) {
                } else {
                    sb.append_c (' ');
                }
                row (f.body);
                emit ("\\right" + delimiter (f.close));
                return;
            }
            if (n is Table) {
                table ((Table) n);
                return;
            }
            if (n is Style) {
                var st = (Style) n;
                string body = sub_write (st.body);
                if (st.script_level == 1) body = "\\scriptstyle " + body;
                else if (st.script_level == 2) body = "\\scriptscriptstyle " + body;
                else if (st.display == 1) body = "\\displaystyle " + body;
                else if (st.display == 0) body = "\\textstyle " + body;
                if (st.display >= 0 || st.script_level >= 0) body = "{" + body + "}";
                if (st.color != null) body = "\\textcolor{" + st.color + "}{" + body + "}";
                if (st.background != null) body = "\\colorbox{" + st.background + "}{$" + body + "$}";
                if (st.display < 0 && st.script_level < 0 && st.color == null && st.background == null) body = "{" + body + "}";
                emit (body);
                return;
            }
            if (n is Enclose) {
                var e = (Enclose) n;
                string cmd = "boxed";
                bool up = e.notation.contains ("updiagonalstrike");
                bool down = e.notation.contains ("downdiagonalstrike");
                if (up && down) cmd = "xcancel";
                else if (up) cmd = "cancel";
                else if (down) cmd = "bcancel";
                string plain = e.notation.replace ("updiagonalstrike", "").replace ("downdiagonalstrike", "").strip ();
                bool simple = (cmd == "boxed" && (e.notation == "box" || e.notation == "" || e.notation == "longdiv")) || (cmd != "boxed" && plain == "");
                if (!simple) {
                    emit ("\\enclose{" + string.joinv (",", e.notation.split (" ")) + "}" + braced (e.body));
                    return;
                }
                emit ("\\" + cmd + braced (e.body));
                return;
            }
            if (n is Ref) {
                var rf = (Ref) n;
                emit ((rf.paren ? "\\eqref{" : "\\ref{") + rf.name + "}");
                return;
            }
            if (n is Phantom) {
                var p = (Phantom) n;
                string cmd = p.keep_width && p.keep_height ? "phantom" : (p.keep_width ? "hphantom" : "vphantom");
                if (!p.keep_width && p.body.size == 1 && p.body[0] is Token && ((Token) p.body[0]).text == "(") {
                    emit ("\\mathstrut");
                    return;
                }
                emit ("\\" + cmd + braced (p.body));
                return;
            }
            if (n is Group) {
                emit (braced (((Group) n).body));
                return;
            }
            if (n is Row) {
                row ((Row) n);
            }
        }

        private static string plain_delim (string d) {
            switch (d) {
                case "{": return "\\{";
                case "}": return "\\}";
                case "\u2016": return "\\|";
                default: return Symbols.delimiter_name (d);
            }
        }

        private static string? x_command (string arrow) {
            switch (arrow) {
                case "\u2192": return "xrightarrow";
                case "\u2190": return "xleftarrow";
                case "\u2194": return "xleftrightarrow";
                case "\u21d2": return "xRightarrow";
                case "\u21d0": return "xLeftarrow";
                case "\u21d4": return "xLeftrightarrow";
                case "\u21a6": return "xmapsto";
                case "\u21aa": return "xhookrightarrow";
                case "\u21a9": return "xhookleftarrow";
                case "\u21cc": return "xrightleftharpoons";
                default: return null;
            }
        }

        private void table (Table t) {
            string env = t.kind.env_name ();
            var b = new StringBuilder ();
            bool custom = t.kind.is_matrix () && t.kind != TableKind.SMALL_MATRIX && t.columns.replace ("c", "") != "";
            if (custom) {
                string o = t.kind.open_delim ();
                b.append ("\\left").append (o == "" ? "." : Symbols.delimiter_name (o)).append (" ");
                env = "array";
            }
            b.append ("\\begin{").append (env).append ("}");
            if (t.kind == TableKind.ARRAY || custom) {
                var spec = new StringBuilder ();
                int n = t.column_count;
                for (int c = 0; c < n; c++) {
                    spec.append_c (t.column_align (c));
                    if (c < t.column_lines.length && c < n - 1 && t.column_lines[c] == 's') spec.append_c ('|');
                }
                b.append ("{").append (spec.str).append ("}");
            }
            for (int r = 0; r < t.rows.size; r++) {
                b.append (r == 0 ? " " : " \\\\ ");
                var cells = t.rows[r];
                for (int c = 0; c < cells.size; c++) {
                    if (c > 0) b.append (" & ");
                    b.append (sub_write (cells[c]));
                }
                if (t.tags[r] != null) b.append (" \\tag{").append (t.tags[r]).append ("}");
                else if (t.notag[r]) b.append (" \\notag");
                if (t.names[r] != null) b.append (" \\label{").append (t.names[r]).append ("}");
            }
            b.append (" \\end{").append (env).append ("}");
            if (custom) {
                string cl = t.kind.close_delim ();
                b.append (" \\right").append (cl == "" ? "." : Symbols.delimiter_name (cl));
            }
            emit (b.str);
        }
    }
}
