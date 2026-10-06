namespace Singularity.Apps.Formula {

    public class Fences {
        public static bool plain (string d) {
            return d == "(" || d == ")" || d == "[" || d == "]" || d == "|" || d == "{" || d == "}" || d == "\u2016"
                || d == "\u27e8" || d == "\u27e9" || d == "\u230a" || d == "\u230b" || d == "\u2308" || d == "\u2309";
        }

        public static bool simple_content (Row body) {
            foreach (var n in body.items) {
                if (n is Token) {
                    var t = (Token) n;
                    if (t.fence_middle || t.min_size > 0) return false;
                    if (Symbols.is_large_op (t.text)) return false;
                    continue;
                }
                if (n is Space) continue;
                if (n is Scripts) {
                    foreach (var slot in n.slots ()) if (!flat (slot)) return false;
                    continue;
                }
                if (n is Fenced) {
                    var f = (Fenced) n;
                    if (!plain (f.open) || !plain (f.close) || f.open == "" || f.close == "") return false;
                    if (!simple_content (f.body)) return false;
                    continue;
                }
                if (n is Group || (n is Accent && !((Accent) n).is_brace ())) {
                    if (!flat (n.slots ()[0])) return false;
                    continue;
                }
                return false;
            }
            return true;
        }

        private static bool flat (Row r) {
            foreach (var n in r.items) {
                if (n is Token || n is Space) continue;
                if (n is Group && flat (((Group) n).body)) continue;
                return false;
            }
            return true;
        }

        private static bool candidate (Node n, out string text) {
            text = "";
            var t = n as Token;
            if (t == null || t.kind != TokenKind.OPERATOR || t.min_size > 0 || t.fence_middle || t.fixed) return false;
            if (!plain (t.text)) return false;
            text = t.text;
            if (t.forced_class != AtomClass.NONE && t.forced_class != AtomClass.OPEN && t.forced_class != AtomClass.CLOSE) return false;
            return true;
        }

        public static void rebuild_mathml (Row row) {
            rebuild (row, true);
        }

        public static void rebuild (Row row, bool any_content = false) {
            bool changed = true;
            while (changed) {
                changed = false;
                var stack = new Gee.ArrayList<int> ();
                for (int i = 0; i < row.size; i++) {
                    string text;
                    if (!candidate (row[i], out text)) continue;
                    var tok = (Token) row[i];
                    bool can_open = Symbols.matching_close (text) != null && tok.forced_class != AtomClass.CLOSE;
                    bool can_close = Symbols.matching_open (text) != null && tok.forced_class != AtomClass.OPEN;
                    if (can_close && stack.size > 0) {
                        int s = stack[stack.size - 1];
                        string open = ((Token) row[s]).text;
                        if (Symbols.matching_close (open) == text) {
                            stack.remove_at (stack.size - 1);
                            var body = new Row ();
                            for (int k = s + 1; k < i; k++) body.append (row[k].copy ());
                            if ((!any_content && !simple_content (body)) || (text == "|" && body.size == 0)) continue;
                            for (int k = i; k >= s; k--) row.remove_at (k);
                            row.insert (s, new Fenced (open, text, body));
                            changed = true;
                            break;
                        }
                        if (!can_open) continue;
                    }
                    if (can_open) stack.add (i);
                }
            }
        }
    }
}
