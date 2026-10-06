namespace Singularity.Apps.Formula {

    public enum LinearSyntax {
        LATEX,
        UNICODEMATH
    }

    public class FormulaDoc : Object {
        private Row _root;

        public Row root {
            get { return _root; }
        }
        public bool display = true;
        public string? tag;
        public bool notag;
        public string? label;
        public Singularity.Equations.Justification justification = Singularity.Equations.Justification.CENTER_GROUP;
        public Singularity.Equations.NumberStyle number_style = Singularity.Equations.NumberStyle.PARENS;
        public double line_width = 0;
        public bool break_after = false;
        public double wrap_indent = 2.0;
        public bool wrap_right = false;
        public bool numbered;
        public int first_number = 1;
        public string number_prefix = "";
        public string? path;
        public bool modified;

        public signal void changed ();

        public FormulaDoc () {
            _root = new Row ();
        }

        public FormulaDoc.from_result (ParseResult r) {
            _root = r.root;
            tag = r.tag;
            notag = r.notag;
            label = r.label;
        }

        public void set_root (Row r) {
            _root = r;
            _root.parent = null;
        }

        public bool is_empty () {
            return root.size == 0;
        }

        public Table? lines_table () {
            if (root.size == 1 && root[0] is Table) {
                var t = (Table) root[0];
                if (t.kind == TableKind.ALIGN || t.kind == TableKind.GATHER) return t;
            }
            return null;
        }

        public string?[] labels () {
            var t = lines_table ();
            int n = first_number;
            if (t != null) {
                string?[] res = new string?[t.row_count];
                for (int i = 0; i < t.row_count; i++) {
                    if (t.tags[i] != null) res[i] = t.tags[i];
                    else if (numbered && !t.notag[i]) res[i] = number_prefix + (n++).to_string ();
                    else res[i] = null;
                }
                return res;
            }
            string?[] one = new string?[1];
            if (tag != null) one[0] = tag;
            else if (numbered && !notag && root.size > 0) one[0] = number_prefix + first_number.to_string ();
            else one[0] = null;
            return one;
        }

        public string format_label (string bare) {
            switch (number_style) {
                case Singularity.Equations.NumberStyle.BRACKETS: return "[" + bare + "]";
                case Singularity.Equations.NumberStyle.PLAIN: return bare;
                default: return "(" + bare + ")";
            }
        }

        public Gee.HashMap<string, string> references () {
            var map = new Gee.HashMap<string, string> ();
            var labs = labels ();
            var t = lines_table ();
            if (t != null) {
                for (int i = 0; i < t.row_count && i < labs.length; i++) {
                    if (t.names[i] != null && labs[i] != null) map[t.names[i]] = labs[i];
                }
            } else if (label != null && labs.length > 0 && labs[0] != null) {
                map[label] = labs[0];
            }
            return map;
        }

        public string unique_label () {
            var existing = references ();
            int n = 1;
            while (existing.has_key ("eq" + n.to_string ())) n++;
            var t = lines_table ();
            if (t != null) {
                bool clash = true;
                while (clash) {
                    clash = false;
                    foreach (var nm in t.names) if (nm == "eq" + n.to_string ()) clash = true;
                    if (clash) n++;
                }
            }
            return "eq" + n.to_string ();
        }

        public string to_latex () {
            return LatexWriter.write (root, tag, lines_table () == null ? label : null);
        }

        public string to_unicodemath () {
            return UnicodeMath.write (root, tag);
        }

        public string to_linear (LinearSyntax syntax) {
            return syntax == LinearSyntax.LATEX ? to_latex () : to_unicodemath ();
        }

        public string to_mathml (bool pretty = true, bool annotate = true, string? annotation = null, string encoding = "application/x-tex") {
            var labels = labels ();
            string? single = lines_table () == null ? labels[0] : null;
            Row r = root;
            var t = lines_table ();
            if (t != null) {
                bool any = false;
                foreach (var l in labels) if (l != null) any = true;
                if (any) {
                    var copy = (Table) t.copy ();
                    MathmlWriter.auto_rows = new Gee.HashSet<int> ();
                    for (int i = 0; i < copy.row_count; i++) {
                        if (copy.tags[i] == null && labels[i] != null) MathmlWriter.auto_rows.add (i);
                        copy.tags[i] = labels[i];
                    }
                    r = new Row ();
                    r.append (copy);
                }
            }
            string? note = annotation;
            if (note == null && annotate) note = to_latex ();
            MathmlWriter.refs = references ();
            MathmlWriter.number_style = number_style;
            MathmlWriter.auto_single = t == null && tag == null && single != null;
            string xml = MathmlWriter.write (r, display, note, pretty, single, "", encoding);
            MathmlWriter.refs = null;
            MathmlWriter.auto_rows = null;
            MathmlWriter.auto_single = false;
            var extra = new StringBuilder ();
            if (justification != Singularity.Equations.Justification.CENTER_GROUP) extra.append (" data-justification=\"").append (justification.to_mathml ()).append ("\"");
            if (number_style != Singularity.Equations.NumberStyle.PARENS) extra.append (" data-number-style=\"").append (number_style.to_string ()).append ("\"");
            if (numbered) extra.append (" data-numbered=\"true\"");
            if (first_number != 1) extra.append (" data-first-number=\"").append (first_number.to_string ()).append ("\"");
            if (label != null && lines_table () == null) extra.append (" data-label=\"").append (Markup.escape_text (label)).append ("\"");
            if (extra.len > 0) {
                int at = xml.index_of ("<math");
                int end = at >= 0 ? xml.index_of (">", at) : -1;
                if (end > 0) xml = xml.substring (0, end) + extra.str + xml.substring (end);
            }
            return xml;
        }

        public static FormulaDoc parse_linear (string text, LinearSyntax syntax) throws ParseError {
            var res = syntax == LinearSyntax.LATEX ? LatexParser.parse (text) : UnicodeMath.parse_result (text);
            return new FormulaDoc.from_result (res);
        }

        public static FormulaDoc parse_any (string text) throws ParseError {
            string t = text.strip ();
            if (t.has_prefix ("<") && (t.contains ("<math") || t.contains (":math"))) {
                var reader = new MathmlReader ();
                var res = reader.read (t);
                var d = new FormulaDoc.from_result (res);
                d.display = reader.display;
                reader.apply_document (d);
                return d;
            }
            if (t.has_prefix ("$$") && t.has_suffix ("$$") && t.length > 4) t = t.substring (2, t.length - 4);
            else if (t.has_prefix ("\\[") && t.has_suffix ("\\]")) t = t.substring (2, t.length - 4);
            else if (t.has_prefix ("$") && t.has_suffix ("$") && t.length > 2) t = t.substring (1, t.length - 2);
            else if (t.has_prefix ("\\(") && t.has_suffix ("\\)")) t = t.substring (2, t.length - 4);
            if (looks_like_latex (t)) return parse_linear (t, LinearSyntax.LATEX);
            try {
                return parse_linear (t, LinearSyntax.UNICODEMATH);
            } catch (ParseError e) {
                return parse_linear (t, LinearSyntax.LATEX);
            }
        }

        public static bool looks_like_latex (string t) {
            if (t.contains ("\\frac") || t.contains ("\\begin") || t.contains ("\\left") || t.contains ("{") || t.contains ("\\sqrt")) return true;
            if (t.contains ("^{") || t.contains ("_{")) return true;
            int i = 0;
            unichar c;
            while (t.get_next_char (ref i, out c)) if (c > 127) return false;
            return t.contains ("\\");
        }
    }
}
