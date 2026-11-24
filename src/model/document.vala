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

        public Variant save_state () {
            var d = new VariantDict ();
            d.insert_value ("root", new Variant.string (MathmlWriter.write (root, true, null, false)));
            d.insert_value ("display", new Variant.boolean (display));
            if (tag != null) d.insert_value ("tag", new Variant.string (tag));
            d.insert_value ("notag", new Variant.boolean (notag));
            if (label != null) d.insert_value ("label", new Variant.string (label));
            d.insert_value ("justification", new Variant.string (justification.to_mathml ()));
            d.insert_value ("number-style", new Variant.string (number_style.to_string ()));
            d.insert_value ("line-width", new Variant.double (line_width));
            d.insert_value ("break-after", new Variant.boolean (break_after));
            d.insert_value ("wrap-indent", new Variant.double (wrap_indent));
            d.insert_value ("wrap-right", new Variant.boolean (wrap_right));
            d.insert_value ("numbered", new Variant.boolean (numbered));
            d.insert_value ("first-number", new Variant.int32 (first_number));
            d.insert_value ("number-prefix", new Variant.string (number_prefix));
            d.insert_value ("modified", new Variant.boolean (modified));
            return d.end ();
        }

        public static FormulaDoc from_state (Variant state) throws ParseError {
            var root = new VariantDict (state).lookup_value ("root", VariantType.STRING);
            var doc = new FormulaDoc.from_result (MathmlReader.parse (root != null ? root.get_string () : ""));
            doc.apply_state (state);
            return doc;
        }

        public void apply_state (Variant state) {
            var d = new VariantDict (state);
            Variant? v;
            if ((v = d.lookup_value ("display", VariantType.BOOLEAN)) != null) display = v.get_boolean ();
            v = d.lookup_value ("tag", VariantType.STRING);
            tag = v != null ? v.get_string () : null;
            if ((v = d.lookup_value ("notag", VariantType.BOOLEAN)) != null) notag = v.get_boolean ();
            v = d.lookup_value ("label", VariantType.STRING);
            label = v != null ? v.get_string () : null;
            if ((v = d.lookup_value ("justification", VariantType.STRING)) != null) justification = Singularity.Equations.Justification.from_mathml (v.get_string ());
            if ((v = d.lookup_value ("number-style", VariantType.STRING)) != null) number_style = Singularity.Equations.NumberStyle.parse (v.get_string ());
            if ((v = d.lookup_value ("line-width", VariantType.DOUBLE)) != null) line_width = v.get_double ();
            if ((v = d.lookup_value ("break-after", VariantType.BOOLEAN)) != null) break_after = v.get_boolean ();
            if ((v = d.lookup_value ("wrap-indent", VariantType.DOUBLE)) != null) wrap_indent = v.get_double ();
            if ((v = d.lookup_value ("wrap-right", VariantType.BOOLEAN)) != null) wrap_right = v.get_boolean ();
            if ((v = d.lookup_value ("numbered", VariantType.BOOLEAN)) != null) numbered = v.get_boolean ();
            if ((v = d.lookup_value ("first-number", VariantType.INT32)) != null) first_number = v.get_int32 ();
            if ((v = d.lookup_value ("number-prefix", VariantType.STRING)) != null) number_prefix = v.get_string ();
            if ((v = d.lookup_value ("modified", VariantType.BOOLEAN)) != null) modified = v.get_boolean ();
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
