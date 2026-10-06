namespace Singularity.Apps.Formula {

    public struct MStyle {
        public int level;
        public bool cramped;

        public MStyle (int level, bool cramped) {
            this.level = level;
            this.cramped = cramped;
        }

        public bool display {
            get { return level == 0; }
        }

        public int script_level {
            get { return level <= 1 ? 0 : level - 1; }
        }

        public MStyle sup () {
            return MStyle (level <= 1 ? 2 : 3, cramped);
        }

        public MStyle sub () {
            return MStyle (level <= 1 ? 2 : 3, true);
        }

        public MStyle num () {
            return MStyle (level == 0 ? 1 : (level == 1 ? 2 : 3), cramped);
        }

        public MStyle den () {
            return MStyle (level == 0 ? 1 : (level == 1 ? 2 : 3), true);
        }

        public MStyle crampify () {
            return MStyle (level, true);
        }
    }

    public class LayoutEngine {
        public MathFont font;
        public double size;
        public bool editing;
        public Row? pending_row;
        public int pending_index;
        public string pending_text = "";
        public string placeholder_color = "#808080";
        public string error_color = "#d02020";
        public string pending_color = "#3070d0";
        public Gee.Map<string, string>? refs;
        public Singularity.Equations.NumberStyle number_style = Singularity.Equations.NumberStyle.PARENS;
        public double max_width = 0;
        public double wrap_indent = 2.0;
        public bool wrap_right = false;
        public Row? break_row;

        private const int[] SPACING = {
            0, 1, 2, 3, 0, 0, 0, 1,
            1, 1, -1, 3, 0, 0, 0, 1,
            2, 2, -1, -1, 2, -1, -1, 2,
            3, 3, -1, 0, 3, 0, 0, 3,
            0, 0, -1, 0, 0, 0, 0, 0,
            0, 1, 2, 3, 0, 0, 0, 1,
            1, 1, -1, 1, 1, 1, 1, 1,
            1, 1, 2, 3, 1, 0, 1, 1
        };

        private const bool[] SPACING_TIGHT = {
            false, false, true, true, false, false, false, true,
            false, false, false, true, false, false, false, true,
            true, true, false, false, true, false, false, true,
            true, true, false, false, true, false, false, true,
            false, false, false, false, false, false, false, false,
            false, false, true, true, false, false, false, true,
            true, true, false, true, true, true, true, true,
            true, false, true, true, true, false, true, true
        };

        public LayoutEngine (MathFont font, double size) {
            this.font = font;
            this.size = size;
        }

        public double em (MStyle st) {
            return size * font.script_scale (st.script_level);
        }

        private double c (MathConst k, MStyle st) {
            return font.get (k) * em (st);
        }

        public MBox layout (Row root, bool display) {
            return layout_row (root, MStyle (display ? 0 : 1, false), true);
        }

        private static int class_index (AtomClass c) {
            switch (c) {
                case AtomClass.OP: return 1;
                case AtomClass.BIN: return 2;
                case AtomClass.REL: return 3;
                case AtomClass.OPEN: return 4;
                case AtomClass.CLOSE: return 5;
                case AtomClass.PUNCT: return 6;
                case AtomClass.INNER: return 7;
                default: return 0;
            }
        }

        private double spacing (AtomClass left, AtomClass right, MStyle st) {
            int li = class_index (left);
            int ri = class_index (right);
            int v = SPACING[li * 8 + ri];
            if (v <= 0) return 0;
            if (SPACING_TIGHT[li * 8 + ri] && st.level >= 2) return 0;
            double mu = em (st) / 18.0;
            return v == 1 ? 3 * mu : (v == 2 ? 4 * mu : 5 * mu);
        }

        private MBox placeholder (MStyle st) {
            var b = new MBox ();
            double e = em (st);
            b.width = 0.62 * e;
            b.ascent = 0.72 * e;
            b.descent = 0.08 * e;
            if (editing) {
                var it = new Item (ItemKind.PLACEHOLDER);
                it.x = 0.06 * e;
                it.y = -b.ascent;
                it.w = b.width - 0.12 * e;
                it.h = b.ascent + b.descent;
                it.size = e;
                it.color = placeholder_color;
                b.add_item (it);
            } else {
                b.width = 0;
                b.ascent = 0;
                b.descent = 0;
            }
            return b;
        }

        private MBox pending_box (MStyle st) {
            double e = em (st);
            var b = text_box ("\\" + pending_text, st, false);
            var w = new MBox ();
            w.add (b, 0.05 * e, 0);
            w.width = b.width + 0.1 * e;
            w.ascent = double.max (b.ascent, 0.7 * e) + 0.05 * e;
            w.descent = double.max (b.descent, 0.2 * e) + 0.05 * e;
            var frame = new Item (ItemKind.PENDING);
            frame.x = 0;
            frame.y = -w.ascent;
            frame.w = w.width;
            frame.h = w.ascent + w.descent;
            frame.color = pending_color;
            w.items.insert (0, frame);
            return w;
        }

        public MBox layout_row (Row r, MStyle st, bool slot, double middle_target = 0, bool lead_ord = false) {
            var row_box = new MBox ();
            row_box.row = r;
            bool show_pending = editing && pending_row == r;
            if (r.size == 0 && !show_pending) {
                var ph = slot ? placeholder (st) : new MBox ();
                ph.row = r;
                ph.carets = { 0.0 };
                if (ph.width > 0) ph.carets = { ph.width / 2.0 };
                return ph;
            }
            var boxes = new Gee.ArrayList<MBox> ();
            var owners = new Gee.ArrayList<int> ();
            for (int i = 0; i < r.size; i++) {
                if (show_pending && pending_index == i) {
                    boxes.add (pending_box (st));
                    owners.add (-1);
                }
                var n = r[i];
                if (n is Scripts && !((Scripts) n).pre) {
                    MBox? base_box = null;
                    int bi = boxes.size - 1;
                    if (bi >= 0 && owners[bi] >= 0 && !(r[owners[bi]] is Space) && !(r[owners[bi]] is Scripts)) {
                        base_box = boxes[bi];
                    }
                    var sb = attach_scripts (base_box, (Scripts) n, st);
                    sb.node = n;
                    if (base_box != null) {
                        sb.cls = base_box.cls;
                        sb.limits = false;
                    }
                    boxes.add (sb);
                    owners.add (i);
                    continue;
                }
                if (n is Scripts) {
                    var ps = pre_scripts ((Scripts) n, st);
                    ps.node = n;
                    boxes.add (ps);
                    owners.add (i);
                    continue;
                }
                var b = layout_node (n, st, middle_target);
                b.node = n;
                boxes.add (b);
                owners.add (i);
            }
            if (show_pending && pending_index >= r.size) {
                boxes.add (pending_box (st));
                owners.add (-1);
            }
            var classes = new AtomClass[boxes.size];
            AtomClass prev = lead_ord ? AtomClass.ORD : AtomClass.NONE;
            for (int i = 0; i < boxes.size; i++) {
                var cl = boxes[i].cls;
                if (owners[i] >= 0 && r[owners[i]] is Space) {
                    classes[i] = AtomClass.NONE;
                    continue;
                }
                if (cl == AtomClass.BIN) {
                    if (prev == AtomClass.NONE || prev == AtomClass.BIN || prev == AtomClass.OP || prev == AtomClass.REL || prev == AtomClass.OPEN || prev == AtomClass.PUNCT) cl = AtomClass.ORD;
                }
                if ((cl == AtomClass.REL || cl == AtomClass.CLOSE || cl == AtomClass.PUNCT) && prev == AtomClass.BIN && i > 0) {
                    for (int k = i - 1; k >= 0; k--) {
                        if (classes[k] == AtomClass.NONE) continue;
                        if (classes[k] == AtomClass.BIN) classes[k] = AtomClass.ORD;
                        break;
                    }
                }
                classes[i] = cl;
                prev = cl;
            }
            for (int i = boxes.size - 1; i >= 0; i--) {
                if (classes[i] == AtomClass.NONE) continue;
                if (classes[i] == AtomClass.BIN) classes[i] = AtomClass.ORD;
                break;
            }
            double x = 0;
            double[] starts = new double[boxes.size];
            double[] ends = new double[boxes.size];
            AtomClass last = lead_ord ? AtomClass.ORD : AtomClass.NONE;
            for (int i = 0; i < boxes.size; i++) {
                var b = boxes[i];
                if (classes[i] != AtomClass.NONE) {
                    if (last != AtomClass.NONE) x += spacing (last, classes[i], st);
                    last = classes[i];
                }
                bool is_scripts = owners[i] >= 0 && r[owners[i]] is Scripts && !((Scripts) r[owners[i]]).pre && i > 0 && b.children.size > 0 && b.children[0].box == boxes[i - 1];
                if (is_scripts) {
                    var base_child = row_box.children.remove_at (row_box.children.size - 1);
                    double bx = base_child.x;
                    row_box.add (b, bx, 0);
                    starts[i] = bx + boxes[i - 1].width;
                    ends[i] = bx + b.width;
                    ends[i - 1] = bx + boxes[i - 1].width;
                    x = bx + b.width;
                    continue;
                }
                starts[i] = x;
                row_box.add (b, x, 0);
                x += b.width;
                ends[i] = x;
            }
            row_box.width = x;
            row_box.grow_to_children ();
            if (row_box.ascent < 0) row_box.ascent = 0;
            if (row_box.descent < 0) row_box.descent = 0;
            double[] carets = new double[r.size + 1];
            for (int i = 0; i < boxes.size; i++) {
                if (owners[i] >= 0) carets[owners[i]] = starts[i];
            }
            carets[r.size] = x;
            row_box.carets = carets;
            if (boxes.size > 0) {
                row_box.italic = boxes[boxes.size - 1].italic;
                if (boxes.size == 1) {
                    row_box.cls = boxes[0].cls;
                    row_box.limits = boxes[0].limits;
                    row_box.largeop = boxes[0].largeop;
                    row_box.single_glyph = boxes[0].single_glyph;
                    row_box.accent_x = boxes[0].accent_x;
                }
            }
            if (break_row == r && max_width > 0 && row_box.width > max_width) {
                var cands = new Gee.ArrayList<double?> ();
                for (int i = 1; i < boxes.size; i++) {
                    if (owners[i] < 0) continue;
                    if (classes[i] == AtomClass.REL || classes[i] == AtomClass.BIN) cands.add (starts[i]);
                }
                break_lines (row_box, cands, st);
            }
            return row_box;
        }

        public int line_count_of (MBox b) {
            if (b.caret_ys.length == 0) return 1;
            int n = 1;
            double last = b.caret_ys[0];
            foreach (var y in b.caret_ys) {
                if (Math.fabs (y - last) > 0.01) {
                    n++;
                    last = y;
                }
            }
            return n;
        }

        private void break_lines (MBox row_box, Gee.ArrayList<double?> cands, MStyle st) {
            if (cands.size == 0) return;
            double total = row_box.width;
            double indent = wrap_indent * em (st);
            var breaks = new Gee.ArrayList<double?> ();
            double start = 0;
            bool first = true;
            while (true) {
                double avail = max_width - (first ? 0 : (wrap_right ? 0 : indent));
                if (total - start <= avail) break;
                double best = -1;
                double next_after = -1;
                foreach (var c in cands) {
                    if (c <= start + 0.01) continue;
                    if (c - start <= avail) best = c;
                    else if (next_after < 0) next_after = c;
                }
                double chosen = best > 0 ? best : next_after;
                if (chosen < 0) break;
                breaks.add (chosen);
                start = chosen;
                first = false;
            }
            if (breaks.size == 0) return;
            int nlines = breaks.size + 1;
            double[] line_start = new double[nlines];
            line_start[0] = 0;
            for (int k = 1; k < nlines; k++) line_start[k] = breaks[k - 1];
            double[] line_w = new double[nlines];
            double[] asc = new double[nlines];
            double[] desc = new double[nlines];
            int[] child_line = new int[row_box.children.size];
            for (int i = 0; i < row_box.children.size; i++) {
                var ch = row_box.children[i];
                int k = 0;
                while (k + 1 < nlines && ch.x >= line_start[k + 1] - 0.01) k++;
                child_line[i] = k;
                asc[k] = double.max (asc[k], ch.box.ascent - ch.y);
                desc[k] = double.max (desc[k], ch.box.descent + ch.y);
                line_w[k] = double.max (line_w[k], ch.x + ch.box.width - line_start[k]);
            }
            double widest = 0;
            for (int k = 0; k < nlines; k++) widest = double.max (widest, line_w[k] + (k > 0 && !wrap_right ? indent : 0));
            double group_w = wrap_right ? double.max (widest, max_width) : widest;
            double[] offset = new double[nlines];
            double[] line_y = new double[nlines];
            double gap = 0.3 * em (st);
            for (int k = 0; k < nlines; k++) {
                if (k == 0) line_y[k] = 0;
                else line_y[k] = line_y[k - 1] + desc[k - 1] + gap + asc[k];
                if (wrap_right) offset[k] = k == 0 ? 0 : group_w - line_w[k];
                else offset[k] = k == 0 ? 0 : indent;
            }
            for (int i = 0; i < row_box.children.size; i++) {
                var ch = row_box.children[i];
                int k = child_line[i];
                ch.x = ch.x - line_start[k] + offset[k];
                ch.y = ch.y + line_y[k];
            }
            double[] ys = new double[row_box.carets.length];
            for (int j = 0; j < row_box.carets.length; j++) {
                double cx = row_box.carets[j];
                int k = 0;
                while (k + 1 < nlines && cx >= line_start[k + 1] - 0.01) k++;
                row_box.carets[j] = cx - line_start[k] + offset[k];
                ys[j] = line_y[k];
            }
            row_box.caret_ys = ys;
            row_box.width = group_w;
            row_box.ascent = asc[0];
            row_box.descent = line_y[nlines - 1] + desc[nlines - 1];
            row_box.line_count = nlines;
        }

        private string display_text (Token t) {
            if (t.kind == TokenKind.IDENT && t.text.char_count () == 1) {
                unichar ch = t.text.get_char (0);
                MathVariant v = t.variant;
                if (v == MathVariant.DEFAULT) v = Unimath.italic_by_default (ch) ? MathVariant.ITALIC : MathVariant.NORMAL;
                unichar s = Unimath.styled (ch, v);
                if (s != ch && font.has_char (s)) return s.to_string ();
                return t.text;
            }
            if (t.variant != MathVariant.DEFAULT && t.variant != MathVariant.NORMAL && t.kind != TokenKind.OPERATOR) {
                var sb = new StringBuilder ();
                int i = 0;
                unichar ch;
                while (t.text.get_next_char (ref i, out ch)) {
                    unichar s = Unimath.styled (ch, t.variant);
                    sb.append_unichar (font.has_char (s) ? s : ch);
                }
                return sb.str;
            }
            if (t.kind == TokenKind.OPERATOR && t.text == "\u2032" && t.prime) return "\u2032";
            return t.text;
        }

        private MBox text_box (string text, MStyle st, bool italic_corr) {
            var b = new MBox ();
            double e = em (st);
            var shaped = font.shape (text, st.script_level);
            MathFont use = font;
            bool missing = shaped.glyphs.length == 0;
            foreach (var g in shaped.glyphs) if (g == 0) missing = true;
            if (missing) {
                var fb = MathFont.fallback_text_font ();
                if (fb != null) {
                    use = fb;
                    shaped = fb.shape (text, 0);
                }
            }
            double x = 0;
            b.ascent = 0;
            b.descent = 0;
            for (int i = 0; i < shaped.glyphs.length; i++) {
                uint g = shaped.glyphs[i];
                var it = new Item (ItemKind.GLYPH);
                it.glyph = g;
                it.font = use;
                it.size = e;
                it.x = x;
                it.y = 0;
                b.add_item (it);
                double a, d, l, r;
                use.extents (g, out a, out d, out l, out r);
                b.ascent = double.max (b.ascent, a * e);
                b.descent = double.max (b.descent, d * e);
                x += shaped.advances[i] * e;
            }
            b.width = x;
            if (shaped.glyphs.length == 1) {
                b.single_glyph = true;
                uint g = shaped.glyphs[0];
                if (italic_corr) b.italic = use.italic (g) * e;
                b.accent_x = use.top_accent (g) * e;
            }
            return b;
        }

        private MBox glyph_box (MathFont f, uint g, double e, double sy = 1.0) {
            var b = new MBox ();
            var it = new Item (ItemKind.GLYPH);
            it.glyph = g;
            it.font = f;
            it.size = e;
            it.sy = sy;
            b.add_item (it);
            double a, d, l, r;
            f.extents (g, out a, out d, out l, out r);
            b.ascent = a * e * sy;
            b.descent = d * e * sy;
            b.width = f.advance (g) * e;
            b.italic = f.italic (g) * e;
            b.single_glyph = true;
            b.accent_x = f.top_accent (g) * e;
            return b;
        }

        private void center_on_axis (MBox b, MStyle st) {
            double axis = c (MathConst.AXIS_HEIGHT, st);
            double shift = (b.ascent - b.descent) / 2.0 - axis;
            foreach (var it in b.items) it.y += shift;
            foreach (var ch in b.children) ch.y += shift;
            b.ascent -= shift;
            b.descent += shift;
        }

        public MBox stretch_vertical (string text, double target, MStyle st) {
            double e = em (st);
            unichar ch = text.get_char (0);
            uint g = font.glyph (ch);
            if (g == 0) {
                var tb = text_box (text, st, false);
                center_on_axis (tb, st);
                return tb;
            }
            double a, d, l, r;
            font.extents (g, out a, out d, out l, out r);
            if ((a + d) * e >= target) {
                var b = glyph_box (font, g, e);
                center_on_axis (b, st);
                return b;
            }
            uint[] vg;
            double[] vs;
            font.variants (g, true, out vg, out vs);
            for (int i = 0; i < vg.length; i++) {
                if (vs[i] * e >= target) {
                    var b = glyph_box (font, vg[i], e);
                    center_on_axis (b, st);
                    b.stretched = vg[i] != g;
                    return b;
                }
            }
            double ic;
            var parts = font.assembly (g, true, out ic);
            if (parts.length > 0) {
                var b = assemble (parts, target / e, true, e);
                b.italic = ic * e;
                center_on_axis (b, st);
                b.stretched = true;
                return b;
            }
            if (vg.length > 0 && font.has_math) {
                var b = glyph_box (font, vg[vg.length - 1], e);
                center_on_axis (b, st);
                b.stretched = true;
                return b;
            }
            double h = (a + d) * e;
            var sb = glyph_box (font, g, e, h > 0 ? target / h : 1.0);
            center_on_axis (sb, st);
            sb.stretched = true;
            return sb;
        }

        public MBox stretch_horizontal (string text, double target, MStyle st) {
            double e = em (st);
            unichar ch = text.get_char (0);
            uint g = font.glyph (ch);
            if (g == 0) return text_box (text, st, false);
            double a, d, l, r;
            font.extents (g, out a, out d, out l, out r);
            if ((r - l) * e >= target) return glyph_box (font, g, e);
            uint[] vg;
            double[] vs;
            font.variants (g, false, out vg, out vs);
            for (int i = 0; i < vg.length; i++) {
                if (vs[i] * e >= target) return glyph_box (font, vg[i], e);
            }
            double ic;
            var parts = font.assembly (g, false, out ic);
            if (parts.length > 0) return assemble (parts, target / e, false, e);
            if (vg.length > 0 && font.has_math) return glyph_box (font, vg[vg.length - 1], e);
            var b = glyph_box (font, g, e);
            double w = (r - l) * e;
            if (w > 0) {
                var it = b.items[0];
                it.sx = target / w;
                it.x = -l * e * it.sx;
                b.width = target;
            }
            return b;
        }

        private MBox assemble (GlyphPart[] parts, double target, bool vertical, double e) {
            double omin = font.min_connector_overlap (vertical);
            int n_ext = 0;
            double sum_ne = 0;
            double sum_ext = 0;
            int n_ne = 0;
            foreach (var p in parts) {
                if (p.extender) {
                    n_ext++;
                    sum_ext += p.full_advance;
                } else {
                    n_ne++;
                    sum_ne += p.full_advance;
                }
            }
            int reps = 0;
            if (n_ext > 0) {
                while (reps < 200) {
                    int count = n_ne + reps * n_ext;
                    double max_size = sum_ne + reps * sum_ext - (count - 1) * omin;
                    if (max_size >= target) break;
                    reps++;
                }
            }
            var seq = new Gee.ArrayList<int> ();
            for (int i = 0; i < parts.length; i++) {
                if (parts[i].extender) {
                    for (int k = 0; k < reps; k++) seq.add (i);
                } else {
                    seq.add (i);
                }
            }
            int count = seq.size;
            double total_adv = 0;
            foreach (int i in seq) total_adv += parts[i].full_advance;
            double max_overlap = double.MAX;
            for (int k = 0; k + 1 < count; k++) {
                double lim = double.min (parts[seq[k]].end_connector, parts[seq[k + 1]].start_connector);
                max_overlap = double.min (max_overlap, lim);
            }
            if (max_overlap == double.MAX) max_overlap = omin;
            double overlap = count > 1 ? (total_adv - target) / (count - 1) : 0;
            overlap = double.max (omin, double.min (overlap, double.max (omin, max_overlap)));
            var b = new MBox ();
            double pos = 0;
            if (vertical) {
                double bottom = 0;
                double width = 0;
                for (int k = 0; k < count; k++) {
                    var p = parts[seq[k]];
                    double a, d, l, r;
                    font.extents (p.glyph, out a, out d, out l, out r);
                    var it = new Item (ItemKind.GLYPH);
                    it.glyph = p.glyph;
                    it.font = font;
                    it.size = e;
                    it.x = 0;
                    it.y = -(pos * e) - d * e;
                    b.add_item (it);
                    width = double.max (width, font.advance (p.glyph) * e);
                    if (k == 0) bottom = 0;
                    pos += p.full_advance - (k + 1 < count ? overlap : 0);
                }
                double h = pos * e;
                b.width = width;
                b.ascent = h;
                b.descent = 0;
                foreach (var it in b.items) it.y += 0;
            } else {
                double height_a = 0;
                double height_d = 0;
                for (int k = 0; k < count; k++) {
                    var p = parts[seq[k]];
                    double a, d, l, r;
                    font.extents (p.glyph, out a, out d, out l, out r);
                    var it = new Item (ItemKind.GLYPH);
                    it.glyph = p.glyph;
                    it.font = font;
                    it.size = e;
                    it.x = pos * e;
                    it.y = 0;
                    b.add_item (it);
                    height_a = double.max (height_a, a * e);
                    height_d = double.max (height_d, d * e);
                    pos += p.full_advance - (k + 1 < count ? overlap : 0);
                }
                b.width = pos * e;
                b.ascent = height_a;
                b.descent = height_d;
            }
            return b;
        }

        private MBox color_box (MBox b, string? color) {
            if (color != null) b.color = color;
            return b;
        }

        private MBox token_box (Token t, MStyle st, double middle_target) {
            double e = em (st);
            if (t.error) {
                var eb = text_box (t.text, st, false);
                eb.color = error_color;
                return eb;
            }
            string text = display_text (t);
            AtomClass cls;
            if (t.forced_class != AtomClass.NONE) cls = t.forced_class;
            else if (t.kind == TokenKind.OPERATOR) cls = Symbols.char_class (t.text);
            else if (t.kind == TokenKind.IDENT && t.text.char_count () > 1) cls = Symbols.is_function (t.text.replace (" ", "")) ? AtomClass.OP : AtomClass.ORD;
            else cls = AtomClass.ORD;
            if (t.prime) cls = AtomClass.ORD;
            MBox b;
            if (t.kind == TokenKind.OPERATOR && t.fence_middle && middle_target > 0) {
                b = stretch_vertical (text, middle_target, st);
                cls = AtomClass.REL;
                if (t.forced_class != AtomClass.NONE) cls = t.forced_class;
            } else if (t.kind == TokenKind.OPERATOR && t.min_size > 0) {
                b = stretch_vertical (text == "." ? " " : text, t.min_size * e, st);
            } else if (t.kind == TokenKind.OPERATOR && Symbols.is_large_op (t.text)) {
                uint g = font.glyph (t.text.get_char (0));
                if (g != 0 && st.display) {
                    double target = font.get (MathConst.DISPLAY_OPERATOR_MIN_HEIGHT) * e;
                    uint[] vg;
                    double[] vs;
                    font.variants (g, true, out vg, out vs);
                    uint chosen = g;
                    for (int i = 0; i < vg.length; i++) {
                        chosen = vg[i];
                        if (vs[i] * e >= target) break;
                    }
                    if (!font.has_math) {
                        double a, d, l, r;
                        font.extents (g, out a, out d, out l, out r);
                        b = glyph_box (font, g, e, (a + d) > 0 ? double.max (1.0, target / ((a + d) * e)) : 1.0);
                    } else {
                        b = glyph_box (font, chosen, e);
                    }
                } else if (g != 0) {
                    b = glyph_box (font, g, e);
                } else {
                    b = text_box (text, st, false);
                }
                center_on_axis (b, st);
                b.largeop = true;
                bool lim = t.limits == 1 || (t.limits == -1 && st.display && Symbols.has_limits (t.text));
                b.limits = lim;
                cls = AtomClass.OP;
                if (t.forced_class != AtomClass.NONE) cls = t.forced_class;
            } else {
                bool ital = t.kind == TokenKind.IDENT && t.text.char_count () == 1;
                b = text_box (text, st, ital);
                if (t.kind == TokenKind.IDENT && t.text.char_count () > 1 && cls == AtomClass.OP) {
                    b.limits = t.limits == 1 || (t.limits == -1 && st.display && Symbols.function_has_limits (t.text.replace (" ", "")));
                }
                if (t.kind == TokenKind.OPERATOR && t.prime) {
                    b.cls = AtomClass.ORD;
                }
            }
            b.cls = cls;
            return b;
        }

        public MBox layout_node (Node n, MStyle st, double middle_target = 0) {
            if (n is Token) return token_box ((Token) n, st, middle_target);
            if (n is Space) {
                var sb = new MBox ();
                sb.width = ((Space) n).width * em (st);
                sb.cls = AtomClass.NONE;
                return sb;
            }
            if (n is Frac) return frac_box ((Frac) n, st);
            if (n is Radical) return radical_box ((Radical) n, st);
            if (n is UnderOver) return underover_box ((UnderOver) n, st);
            if (n is Accent) return accent_box ((Accent) n, st);
            if (n is Fenced) return fenced_box ((Fenced) n, st);
            if (n is Table) return table_box ((Table) n, st);
            if (n is Style) return style_box ((Style) n, st);
            if (n is Enclose) return enclose_box ((Enclose) n, st);
            if (n is Phantom) return phantom_box ((Phantom) n, st);
            if (n is Ref) {
                var rf = (Ref) n;
                string num = refs != null && refs.has_key (rf.name) ? refs[rf.name] : "?";
                if (rf.paren) {
                    switch (number_style) {
                        case Singularity.Equations.NumberStyle.BRACKETS: num = "[" + num + "]"; break;
                        case Singularity.Equations.NumberStyle.PLAIN: break;
                        default: num = "(" + num + ")"; break;
                    }
                }
                var rb = text_box (num, st, false);
                rb.cls = AtomClass.ORD;
                return rb;
            }
            if (n is Group) {
                var g = layout_row (((Group) n).body, st, true);
                var w = new MBox ();
                w.add (g, 0, 0);
                w.width = g.width;
                w.ascent = g.ascent;
                w.descent = g.descent;
                w.italic = g.italic;
                w.cls = AtomClass.ORD;
                return w;
            }
            return new MBox ();
        }

        private MBox frac_box (Frac f, MStyle st0) {
            MStyle st = st0;
            if (f.display == 1) st = MStyle (0, st0.cramped);
            else if (f.display == 0 && st0.level == 0) st = MStyle (1, st0.cramped);
            double e = em (st);
            if (f.bevelled) return bevelled_box (f, st);
            MStyle ns = f.continued ? MStyle (0, false) : st.num ();
            var num = layout_row (f.num, ns, true);
            var den = layout_row (f.den, st.den (), true);
            double axis = c (MathConst.AXIS_HEIGHT, st);
            double pad = 0.12 * e;
            double width = double.max (num.width, den.width) + 2 * pad;
            double up, down;
            double t = 0;
            if (f.line) {
                t = f.thickness >= 0 ? f.thickness * e : c (MathConst.FRACTION_RULE_THICKNESS, st);
                up = c (st.display ? MathConst.FRACTION_NUMERATOR_DISPLAY_STYLE_SHIFT_UP : MathConst.FRACTION_NUMERATOR_SHIFT_UP, st);
                down = c (st.display ? MathConst.FRACTION_DENOMINATOR_DISPLAY_STYLE_SHIFT_DOWN : MathConst.FRACTION_DENOMINATOR_SHIFT_DOWN, st);
                double gn = c (st.display ? MathConst.FRACTION_NUM_DISPLAY_STYLE_GAP_MIN : MathConst.FRACTION_NUMERATOR_GAP_MIN, st);
                double gd = c (st.display ? MathConst.FRACTION_DENOM_DISPLAY_STYLE_GAP_MIN : MathConst.FRACTION_DENOMINATOR_GAP_MIN, st);
                up = double.max (up, axis + t / 2 + gn + num.descent);
                down = double.max (down, den.ascent + gd - (axis - t / 2));
            } else {
                up = c (st.display ? MathConst.STACK_TOP_DISPLAY_STYLE_SHIFT_UP : MathConst.STACK_TOP_SHIFT_UP, st);
                down = c (st.display ? MathConst.STACK_BOTTOM_DISPLAY_STYLE_SHIFT_DOWN : MathConst.STACK_BOTTOM_SHIFT_DOWN, st);
                double gap = c (st.display ? MathConst.STACK_DISPLAY_STYLE_GAP_MIN : MathConst.STACK_GAP_MIN, st);
                double delta = gap - ((up - num.descent) - (den.ascent - down));
                if (delta > 0) {
                    up += delta / 2;
                    down += delta / 2;
                }
            }
            var b = new MBox ();
            double nx = f.continued ? pad + (width - 2 * pad - num.width) / 2 : (width - num.width) / 2;
            b.add (num, nx, -up);
            b.add (den, (width - den.width) / 2, down);
            if (f.line && t > 0) {
                var rule = new Item (ItemKind.RULE);
                rule.x = pad * 0.5;
                rule.w = width - pad;
                rule.y = -(axis + t / 2);
                rule.h = t;
                b.add_item (rule);
            }
            b.width = width;
            b.ascent = up + num.ascent;
            b.descent = down + den.descent;
            b.cls = AtomClass.INNER;
            return b;
        }

        private MBox bevelled_box (Frac f, MStyle st) {
            double e = em (st);
            var num = layout_row (f.num, st.num (), true);
            var den = layout_row (f.den, st.den (), true);
            double axis = c (MathConst.AXIS_HEIGHT, st);
            double hgap = font.has_math ? c (MathConst.SKEWED_FRACTION_HORIZONTAL_GAP, st) : 0.1 * e;
            double vgap = font.has_math ? c (MathConst.SKEWED_FRACTION_VERTICAL_GAP, st) : 0.1 * e;
            double target = num.height + den.height + vgap;
            var slash = stretch_vertical ("/", double.max (target * 0.8, e), st);
            var b = new MBox ();
            double num_shift = axis + vgap / 2 + num.descent;
            double den_shift = den.ascent - axis + vgap / 2;
            b.add (num, 0, -num_shift);
            double sx = num.width - hgap / 2;
            sx = double.max (sx, num.width * 0.5);
            b.add (slash, sx, 0);
            b.add (den, sx + slash.width - hgap / 2 + hgap, den_shift);
            b.width = sx + slash.width + hgap / 2 + den.width;
            b.grow_to_children ();
            b.cls = AtomClass.INNER;
            return b;
        }

        private MBox radical_box (Radical r, MStyle st) {
            double e = em (st);
            var body = layout_row (r.body, st.crampify (), true);
            double gap = c (st.display ? MathConst.RADICAL_DISPLAY_STYLE_VERTICAL_GAP : MathConst.RADICAL_VERTICAL_GAP, st);
            double t = c (MathConst.RADICAL_RULE_THICKNESS, st);
            double extra = c (MathConst.RADICAL_EXTRA_ASCENDER, st);
            double target = body.ascent + body.descent + gap + t;
            var surd = stretch_vertical ("\u221a", target, st);
            double sh = surd.ascent + surd.descent;
            if (sh > target) gap += (sh - target) / 2;
            double top = body.ascent + gap + t;
            double shift = top - surd.ascent;
            var b = new MBox ();
            double x = 0;
            MBox? index = null;
            double kb = 0;
            double ka = 0;
            if (r.index != null) {
                index = layout_row (r.index, MStyle (3, false), true);
                kb = c (MathConst.RADICAL_KERN_BEFORE_DEGREE, st);
                ka = c (MathConst.RADICAL_KERN_AFTER_DEGREE, st);
                double raise = font.get (MathConst.RADICAL_DEGREE_BOTTOM_RAISE_PERCENT) / 100.0 * sh;
                double surd_bottom = surd.descent - shift;
                double index_y = surd_bottom - raise - index.descent;
                x = double.max (0, kb);
                b.add (index, x, index_y);
                x += index.width + ka;
                if (x < 0) x = 0;
            }
            b.add (surd, x, -shift);
            double bx = x + surd.width;
            b.add (body, bx, 0);
            var rule = new Item (ItemKind.RULE);
            rule.x = bx - 0.01 * e;
            rule.w = body.width + 0.02 * e;
            rule.y = -top;
            rule.h = t;
            b.add_item (rule);
            b.width = bx + body.width + 0.05 * e;
            b.grow_to_children ();
            b.ascent = double.max (b.ascent, top + extra);
            b.cls = AtomClass.ORD;
            return b;
        }

        private MBox attach_scripts (MBox? base_box, Scripts s, MStyle st) {
            double e = em (st);
            var b = new MBox ();
            MBox base_b = base_box ?? new MBox ();
            b.add (base_b, 0, 0);
            bool primes = s.sup != null && LatexParser.is_prime_row (s.sup);
            MBox? sup = s.sup != null ? layout_row (s.sup, primes ? st : st.sup (), true) : null;
            MBox? sub = s.sub != null ? layout_row (s.sub, st.sub (), true) : null;
            if (primes && !base_b.limits) {
                double px = base_b.width + base_b.italic;
                b.add (sup, px, 0);
                double w2 = px + sup.width;
                if (sub != null) {
                    double v2 = double.max (c (MathConst.SUBSCRIPT_SHIFT_DOWN, st), sub.ascent - c (MathConst.SUBSCRIPT_TOP_MAX, st));
                    b.add (sub, base_b.width, v2);
                    w2 = double.max (w2, base_b.width + sub.width);
                }
                b.width = w2;
                b.grow_to_children ();
                b.cls = base_b.cls;
                return b;
            }
            if (base_b.limits) {
                double w = base_b.width;
                if (sup != null) w = double.max (w, sup.width);
                if (sub != null) w = double.max (w, sub.width);
                double bx = (w - base_b.width) / 2;
                b.children[0].x = bx;
                double ic = base_b.italic;
                if (sup != null) {
                    double gap = c (MathConst.UPPER_LIMIT_GAP_MIN, st);
                    double rise = c (MathConst.UPPER_LIMIT_BASELINE_RISE_MIN, st);
                    double y = base_b.ascent + double.max (gap + sup.descent, rise);
                    b.add (sup, (w - sup.width) / 2 + ic / 2, -y);
                }
                if (sub != null) {
                    double gap = c (MathConst.LOWER_LIMIT_GAP_MIN, st);
                    double drop = c (MathConst.LOWER_LIMIT_BASELINE_DROP_MIN, st);
                    double y = base_b.descent + double.max (gap + sub.ascent, drop);
                    b.add (sub, (w - sub.width) / 2 - ic / 2, y);
                }
                b.width = w;
                b.grow_to_children ();
                b.cls = base_b.cls;
                return b;
            }
            bool is_char = base_b.single_glyph && !base_b.largeop;
            double x = base_b.width;
            double u = 0;
            double v = 0;
            if (sup != null) {
                u = is_char ? 0 : base_b.ascent - c (MathConst.SUPERSCRIPT_BASELINE_DROP_MAX, st.sup ());
                u = double.max (u, c (st.cramped ? MathConst.SUPERSCRIPT_SHIFT_UP_CRAMPED : MathConst.SUPERSCRIPT_SHIFT_UP, st));
                u = double.max (u, sup.descent + c (MathConst.SUPERSCRIPT_BOTTOM_MIN, st));
            }
            if (sub != null) {
                v = is_char ? 0 : base_b.descent + c (MathConst.SUBSCRIPT_BASELINE_DROP_MIN, st.sub ());
                v = double.max (v, c (MathConst.SUBSCRIPT_SHIFT_DOWN, st));
                v = double.max (v, sub.ascent - c (MathConst.SUBSCRIPT_TOP_MAX, st));
            }
            if (sup != null && sub != null) {
                double gap = (u - sup.descent) - (sub.ascent - v);
                double gmin = c (MathConst.SUB_SUPERSCRIPT_GAP_MIN, st);
                if (gap < gmin) {
                    v += gmin - gap;
                    double psi = c (MathConst.SUPERSCRIPT_BOTTOM_MAX_WITH_SUBSCRIPT, st) - (u - sup.descent);
                    if (psi > 0) {
                        u += psi;
                        v -= psi;
                    }
                }
            }
            double space = c (MathConst.SPACE_AFTER_SCRIPT, st);
            double w = x;
            if (sup != null) {
                double sx = base_b.largeop ? x : x + base_b.italic;
                b.add (sup, sx, -u);
                w = double.max (w, sx + sup.width);
            }
            if (sub != null) {
                double sx = base_b.largeop ? x - base_b.italic : x;
                b.add (sub, sx, v);
                w = double.max (w, sx + sub.width);
            }
            b.width = w + space;
            b.grow_to_children ();
            b.cls = base_b.cls;
            b.italic = 0;
            return b;
        }

        private MBox pre_scripts (Scripts s, MStyle st) {
            var b = new MBox ();
            MBox? sup = s.sup != null ? layout_row (s.sup, st.sup (), true) : null;
            MBox? sub = s.sub != null ? layout_row (s.sub, st.sub (), true) : null;
            double u = sup != null ? double.max (c (MathConst.SUPERSCRIPT_SHIFT_UP, st), sup.descent + c (MathConst.SUPERSCRIPT_BOTTOM_MIN, st)) : 0;
            double v = sub != null ? double.max (c (MathConst.SUBSCRIPT_SHIFT_DOWN, st), sub.ascent - c (MathConst.SUBSCRIPT_TOP_MAX, st)) : 0;
            double w = double.max (sup != null ? sup.width : 0, sub != null ? sub.width : 0);
            if (sup != null) b.add (sup, w - sup.width, -u);
            if (sub != null) b.add (sub, w - sub.width, v);
            b.width = w + c (MathConst.SPACE_AFTER_SCRIPT, st) * 0.5;
            b.grow_to_children ();
            b.cls = AtomClass.ORD;
            return b;
        }

        private static bool is_arrow_text (string s) {
            unichar ch = s.get_char (0);
            return (ch >= 0x2190 && ch <= 0x21ff) || (ch >= 0x27f0 && ch <= 0x27ff);
        }

        private MBox underover_box (UnderOver u, MStyle st) {
            double e = em (st);
            bool arrow = u.body.size == 1 && u.body[0] is Token && ((Token) u.body[0]).kind == TokenKind.OPERATOR && is_arrow_text (((Token) u.body[0]).text);
            MStyle os = u.accent_over ? st : st.sup ();
            MStyle us = u.accent_under ? st.crampify () : st.sub ();
            MBox? over = u.over != null ? layout_row (u.over, os, true) : null;
            MBox? under = u.under != null ? layout_row (u.under, us, true) : null;
            MBox body;
            if (arrow) {
                double w = 0;
                if (over != null) w = double.max (w, over.width);
                if (under != null) w = double.max (w, under.width);
                w += 0.8 * e;
                var t = (Token) u.body[0];
                var sb = stretch_horizontal (t.text, double.max (w, 1.5 * e), st);
                body = new MBox ();
                body.add (sb, 0, 0);
                body.width = sb.width;
                body.ascent = sb.ascent;
                body.descent = sb.descent;
                body.row = u.body;
                body.carets = { 0.0, sb.width };
                body.cls = AtomClass.REL;
            } else {
                body = layout_row (u.body, st, true);
            }
            double w = body.width;
            if (over != null) w = double.max (w, over.width);
            if (under != null) w = double.max (w, under.width);
            var b = new MBox ();
            b.add (body, (w - body.width) / 2, 0);
            if (over != null) {
                double y;
                if (arrow) {
                    y = body.ascent + c (MathConst.STRETCH_STACK_GAP_BELOW_MIN, st) + over.descent;
                    y = double.max (y, c (MathConst.STRETCH_STACK_TOP_SHIFT_UP, st));
                } else if (u.accent_over) {
                    y = body.ascent + 0.05 * e + over.descent;
                } else {
                    y = body.ascent + double.max (c (MathConst.UPPER_LIMIT_GAP_MIN, st) + over.descent, c (MathConst.UPPER_LIMIT_BASELINE_RISE_MIN, st));
                }
                b.add (over, (w - over.width) / 2, -y);
            }
            if (under != null) {
                double y;
                if (arrow) {
                    y = body.descent + c (MathConst.STRETCH_STACK_GAP_ABOVE_MIN, st) + under.ascent;
                    y = double.max (y, c (MathConst.STRETCH_STACK_BOTTOM_SHIFT_DOWN, st));
                } else {
                    y = body.descent + double.max (c (MathConst.LOWER_LIMIT_GAP_MIN, st) + under.ascent, c (MathConst.LOWER_LIMIT_BASELINE_DROP_MIN, st));
                }
                b.add (under, (w - under.width) / 2, y);
            }
            b.width = w;
            b.grow_to_children ();
            b.cls = arrow ? AtomClass.REL : (body.largeop ? AtomClass.OP : body.cls);
            if (u.body.size == 1 && u.body[0] is Token && Symbols.char_class (((Token) u.body[0]).text) == AtomClass.REL) b.cls = AtomClass.REL;
            return b;
        }

        private MBox accent_box (Accent a, MStyle st) {
            double e = em (st);
            var body = layout_row (a.body, a.under ? st : st.crampify (), true);
            var b = new MBox ();
            b.add (body, 0, 0);
            b.width = body.width;
            b.ascent = body.ascent;
            b.descent = body.descent;
            b.italic = body.italic;
            b.cls = AtomClass.ORD;
            if (a.is_line ()) {
                var rule = new Item (ItemKind.RULE);
                rule.x = 0;
                rule.w = body.width;
                if (!a.under) {
                    double gap = c (MathConst.OVERBAR_VERTICAL_GAP, st);
                    double t = c (MathConst.OVERBAR_RULE_THICKNESS, st);
                    double extra = c (MathConst.OVERBAR_EXTRA_ASCENDER, st);
                    rule.y = -(body.ascent + gap + t);
                    rule.h = t;
                    b.ascent = body.ascent + gap + t + extra;
                } else {
                    double gap = c (MathConst.UNDERBAR_VERTICAL_GAP, st);
                    double t = c (MathConst.UNDERBAR_RULE_THICKNESS, st);
                    double extra = c (MathConst.UNDERBAR_EXTRA_DESCENDER, st);
                    rule.y = body.descent + gap;
                    rule.h = t;
                    b.descent = body.descent + gap + t + extra;
                }
                b.add_item (rule);
                return b;
            }
            if (a.is_brace () || is_arrow_text (a.mark)) {
                var mark = stretch_horizontal (a.mark, body.width, st);
                double gap = 0.08 * e;
                double mx = (body.width - mark.width) / 2;
                if (mark.width > body.width) {
                    b.children[0].x = (mark.width - body.width) / 2;
                    b.width = mark.width;
                    mx = 0;
                }
                if (!a.under) {
                    double y = body.ascent + gap + mark.descent;
                    b.add (mark, mx, -y);
                } else {
                    double y = body.descent + gap + mark.ascent;
                    b.add (mark, mx, y);
                }
                b.grow_to_children ();
                b.limits = a.is_brace ();
                b.cls = a.is_brace () ? AtomClass.OP : AtomClass.ORD;
                return b;
            }
            string m = a.mark;
            uint g = font.glyph (m.get_char (0));
            if (g == 0) {
                string alt = Symbols.spacing_accent (m);
                g = font.glyph (alt.get_char (0));
                m = alt;
            }
            MBox mark;
            if (a.stretchy) mark = stretch_horizontal (m, body.width * 0.95, st);
            else mark = g != 0 ? glyph_box (font, g, e) : text_box (m, st, false);
            double base_attach = body.accent_x >= 0 && body.single_glyph ? body.accent_x : body.width / 2;
            if (a.body.size == 1 && a.body[0] is Token && ((Token) a.body[0]).text.char_count () == 1 && body.accent_x >= 0) base_attach = body.accent_x;
            double mark_attach = mark.width / 2;
            if (mark.items.size == 1 && mark.items[0].kind == ItemKind.GLYPH && mark.items[0].sx == 1.0) {
                double ma, md, ml, mr;
                mark.items[0].font.extents (mark.items[0].glyph, out ma, out md, out ml, out mr);
                mark_attach = mark.items[0].x + (ml + mr) / 2 * e;
            } else if (mark.items.size > 1) {
                double lo = double.MAX;
                double hi = -double.MAX;
                foreach (var it in mark.items) {
                    double ma, md, ml, mr;
                    it.font.extents (it.glyph, out ma, out md, out ml, out mr);
                    lo = double.min (lo, it.x + ml * e);
                    hi = double.max (hi, it.x + mr * e);
                }
                mark_attach = (lo + hi) / 2;
            }
            double abh = c (MathConst.ACCENT_BASE_HEIGHT, st);
            if (!a.under) {
                double raise = double.max (0, body.ascent - abh);
                b.add (mark, base_attach - mark_attach, -raise);
            } else {
                b.add (mark, base_attach - mark_attach, 0);
            }
            b.grow_to_children ();
            return b;
        }

        private double delimiter_size (double ascent, double descent, MStyle st) {
            double axis = c (MathConst.AXIS_HEIGHT, st);
            double delta = double.max (ascent - axis, descent + axis);
            double e = em (st);
            double size = double.max (delta * 2 * 0.901, delta * 2 - 0.5 * e);
            return size;
        }

        private MBox fenced_box (Fenced f, MStyle st) {
            double e = em (st);
            var probe = layout_row (f.body, st, true);
            double target = delimiter_size (probe.ascent, probe.descent, st);
            bool has_middle = false;
            foreach (var n in f.body.items) if (n is Token && ((Token) n).fence_middle) has_middle = true;
            var body = has_middle ? layout_row (f.body, st, true, target) : probe;
            var b = new MBox ();
            double x = 0;
            bool stretched_any = false;
            if (f.open != "") {
                var o = stretch_vertical (f.open, target, st);
                stretched_any = stretched_any || o.stretched;
                b.add (o, 0, 0);
                x += o.width;
            } else {
                x += 0.12 * e;
            }
            b.add (body, x, 0);
            x += body.width;
            if (f.close != "") {
                var cl = stretch_vertical (f.close, target, st);
                stretched_any = stretched_any || cl.stretched;
                b.add (cl, x, 0);
                x += cl.width;
                b.italic = cl.italic;
            } else {
                x += 0.12 * e;
            }
            b.width = x;
            b.grow_to_children ();
            b.cls = AtomClass.INNER;
            if (!stretched_any && !has_middle && Fences.simple_content (f.body)) {
                b.single_glyph = true;
                b.cls = AtomClass.ORD;
            }
            return b;
        }

        private MBox table_box (Table t, MStyle st0) {
            MStyle st;
            switch (t.kind) {
                case TableKind.ALIGN:
                case TableKind.GATHER:
                    st = MStyle (0, false);
                    break;
                case TableKind.SMALL_MATRIX:
                    st = MStyle (2, false);
                    break;
                default:
                    st = MStyle (st0.level == 0 ? 1 : st0.level, false);
                    break;
            }
            double e = em (st);
            int nrows = t.rows.size;
            int ncols = t.column_count;
            var cells = new MBox[nrows * int.max (ncols, 1)];
            double[] col_w = new double[int.max (ncols, 1)];
            double[] row_a = new double[int.max (nrows, 1)];
            double[] row_d = new double[int.max (nrows, 1)];
            double strut_a = 0.75 * e;
            double strut_d = 0.3 * e;
            for (int r = 0; r < nrows; r++) {
                row_a[r] = strut_a;
                row_d[r] = strut_d;
                for (int cix = 0; cix < ncols; cix++) {
                    var cell = t.cell (r, cix);
                    MBox cb = cell != null ? layout_row (cell, st, t.kind != TableKind.ALIGN || editing, 0, t.kind == TableKind.ALIGN && cix % 2 == 1) : new MBox ();
                    cells[r * ncols + cix] = cb;
                    col_w[cix] = double.max (col_w[cix], cb.width);
                    row_a[r] = double.max (row_a[r], cb.ascent);
                    row_d[r] = double.max (row_d[r], cb.descent);
                }
            }
            double row_gap;
            double[] col_gap = new double[int.max (ncols, 1)];
            switch (t.kind) {
                case TableKind.ALIGN:
                    row_gap = 0.3 * e;
                    for (int cix = 0; cix < ncols; cix++) col_gap[cix] = cix % 2 == 0 ? 0 : 2 * e;
                    break;
                case TableKind.GATHER:
                    row_gap = 0.3 * e;
                    break;
                case TableKind.CASES:
                    row_gap = 0.2 * e;
                    for (int cix = 0; cix < ncols; cix++) col_gap[cix] = e;
                    break;
                case TableKind.SMALL_MATRIX:
                    row_gap = 0.1 * e;
                    for (int cix = 0; cix < ncols; cix++) col_gap[cix] = 0.5 * e;
                    break;
                default:
                    row_gap = 0.2 * e;
                    for (int cix = 0; cix < ncols; cix++) col_gap[cix] = t.column_gap >= 0 ? t.column_gap * e : e;
                    if (t.row_gap >= 0) row_gap = t.row_gap * e;
                    break;
            }
            var grid = new MBox ();
            double y = 0;
            double[] baselines = new double[int.max (nrows, 1)];
            for (int r = 0; r < nrows; r++) {
                y += row_a[r];
                baselines[r] = y;
                double x = 0;
                for (int cix = 0; cix < ncols; cix++) {
                    if (cix > 0) x += col_gap[cix - 1 >= 0 ? cix - 1 : 0];
                    var cb = cells[r * ncols + cix];
                    char al = t.column_align (cix);
                    double off = al == 'l' ? 0 : (al == 'r' ? col_w[cix] - cb.width : (col_w[cix] - cb.width) / 2);
                    grid.add (cb, x + off, y);
                    x += col_w[cix];
                }
                grid.width = x;
                y += row_d[r];
                if (r + 1 < nrows) y += row_gap;
            }
            if (t.kind == TableKind.ARRAY && t.column_lines.contains ("s")) {
                double x = 0;
                for (int cix = 0; cix < ncols - 1; cix++) {
                    x += col_w[cix];
                    double gap = col_gap[cix];
                    if (cix < t.column_lines.length && t.column_lines[cix] == 's') {
                        var line = new Item (ItemKind.RULE);
                        double th = c (MathConst.FRACTION_RULE_THICKNESS, st);
                        line.x = x + gap / 2 - th / 2;
                        line.w = th;
                        line.y = 0;
                        line.h = y;
                        grid.add_item (line);
                    }
                    x += gap;
                }
            }
            double total = y;
            double axis = c (MathConst.AXIS_HEIGHT, st);
            double top;
            if ((t.kind == TableKind.ALIGN || t.kind == TableKind.GATHER) && nrows == 1) top = baselines[0];
            else top = total / 2 + axis;
            var tb = new MBox ();
            tb.add (grid, 0, -top);
            tb.width = grid.width;
            tb.ascent = top;
            tb.descent = total - top;
            string o = t.kind.open_delim ();
            string cl = t.kind.close_delim ();
            if (o == "" && cl == "") {
                tb.cls = AtomClass.ORD;
                return tb;
            }
            double target = delimiter_size (tb.ascent, tb.descent, st0.level == 0 ? MStyle (1, false) : st0);
            target = double.max (target, tb.height + 0.1 * e);
            var b = new MBox ();
            double bx = 0;
            MStyle ds = MStyle (st0.level <= 1 ? 1 : st0.level, false);
            if (o != "") {
                var ob = stretch_vertical (o, target, ds);
                b.add (ob, 0, 0);
                bx = ob.width + (t.kind == TableKind.CASES ? 0.15 * e : 0.08 * e);
            }
            b.add (tb, bx, 0);
            bx += tb.width;
            if (cl != "") {
                bx += 0.08 * e;
                var cb = stretch_vertical (cl, target, ds);
                b.add (cb, bx, 0);
                bx += cb.width;
            }
            b.width = bx;
            b.grow_to_children ();
            b.cls = AtomClass.INNER;
            return b;
        }

        private MBox style_box (Style s, MStyle st) {
            MStyle ns = st;
            if (s.script_level >= 0) ns = MStyle (s.script_level == 0 ? (s.display == 1 ? 0 : 1) : s.script_level + 1, st.cramped);
            else if (s.display == 1) ns = MStyle (0, st.cramped);
            else if (s.display == 0) ns = MStyle (st.level == 0 ? 1 : st.level, st.cramped);
            double saved = size;
            if (Math.fabs (s.scale - 1.0) > 1e-6) size = size * s.scale;
            var body = layout_row (s.body, ns, true);
            size = saved;
            var b = new MBox ();
            if (s.background != null) {
                var bg = new Item (ItemKind.BACKGROUND);
                double e = em (st);
                bg.x = -0.05 * e;
                bg.y = -body.ascent - 0.05 * e;
                bg.w = body.width + 0.1 * e;
                bg.h = body.height + 0.1 * e;
                bg.color = s.background;
                b.add_item (bg);
            }
            b.add (body, 0, 0);
            b.width = body.width;
            b.ascent = body.ascent;
            b.descent = body.descent;
            b.italic = body.italic;
            b.cls = body.cls;
            b.limits = body.limits;
            b.largeop = body.largeop;
            b.single_glyph = body.single_glyph;
            b.accent_x = body.accent_x;
            if (s.color != null) body.color = s.color;
            return b;
        }

        private MBox enclose_box (Enclose en, MStyle st) {
            double e = em (st);
            var body = layout_row (en.body, st, true);
            double pad = 0.3 * e;
            double th = c (MathConst.FRACTION_RULE_THICKNESS, st);
            var b = new MBox ();
            var words = new Gee.HashSet<string> ();
            foreach (var w0 in en.notation.split (" ")) words.add (w0);
            bool sides = words.contains ("top") || words.contains ("bottom") || words.contains ("left") || words.contains ("right") || words.contains ("actuarial") || words.contains ("madruwb");
            bool boxed = en.notation.contains ("box") || en.notation.contains ("longdiv") || en.notation == "" || en.notation.contains ("circle") || sides;
            bool strike_only = !boxed && (en.notation.contains ("strike") || en.notation.contains ("diagonal"));
            if (strike_only) pad = 0.05 * e;
            b.add (body, pad, 0);
            b.width = body.width + 2 * pad;
            b.ascent = body.ascent + pad;
            b.descent = body.descent + pad;
            foreach (var note in en.notation.split (" ")) {
                switch (note) {
                    case "box":
                    case "roundedbox":
                    case "longdiv":
                    case "":
                        var fr = new Item (ItemKind.FRAME);
                        fr.x = th / 2;
                        fr.y = -b.ascent + th / 2;
                        fr.w = b.width - th;
                        fr.h = b.ascent + b.descent - th;
                        fr.size = th;
                        fr.sx = note == "roundedbox" ? 0.2 * e : 0;
                        b.add_item (fr);
                        break;
                    case "circle":
                        var el = new Item (ItemKind.ELLIPSE);
                        el.x = 0;
                        el.y = -b.ascent;
                        el.w = b.width;
                        el.h = b.ascent + b.descent;
                        el.size = th;
                        b.add_item (el);
                        break;
                    case "updiagonalstrike":
                        var l1 = new Item (ItemKind.LINE);
                        l1.x = 0;
                        l1.y = b.descent;
                        l1.w = b.width;
                        l1.h = -(b.ascent + b.descent);
                        l1.size = th;
                        b.add_item (l1);
                        break;
                    case "downdiagonalstrike":
                        var l2 = new Item (ItemKind.LINE);
                        l2.x = 0;
                        l2.y = -b.ascent;
                        l2.w = b.width;
                        l2.h = b.ascent + b.descent;
                        l2.size = th;
                        b.add_item (l2);
                        break;
                    case "top":
                    case "bottom":
                    case "left":
                    case "right":
                    case "actuarial":
                    case "madruwb":
                        bool[] edges = {
                            note == "top" || note == "actuarial",
                            note == "bottom" || note == "madruwb",
                            note == "left",
                            note == "right" || note == "actuarial" || note == "madruwb"
                        };
                        if (edges[0]) b.add_item (rule_item (0, -b.ascent, b.width, th));
                        if (edges[1]) b.add_item (rule_item (0, b.descent - th, b.width, th));
                        if (edges[2]) b.add_item (rule_item (0, -b.ascent, th, b.ascent + b.descent));
                        if (edges[3]) b.add_item (rule_item (b.width - th, -b.ascent, th, b.ascent + b.descent));
                        break;
                    case "verticalstrike":
                        b.add_item (rule_item (b.width / 2 - th / 2, -b.ascent, th, b.ascent + b.descent));
                        break;
                    case "horizontalstrike":
                        var l3 = new Item (ItemKind.RULE);
                        l3.x = 0;
                        l3.y = -c (MathConst.AXIS_HEIGHT, st) - th / 2;
                        l3.w = b.width;
                        l3.h = th;
                        b.add_item (l3);
                        break;
                    default:
                        break;
                }
            }
            b.cls = AtomClass.ORD;
            return b;
        }

        private static Item rule_item (double x, double y, double w, double h) {
            var it = new Item (ItemKind.RULE);
            it.x = x;
            it.y = y;
            it.w = w;
            it.h = h;
            return it;
        }

        private MBox phantom_box (Phantom p, MStyle st) {
            var body = layout_row (p.body, st, true);
            var b = new MBox ();
            if (editing) {
                body.hidden = true;
                b.add (body, 0, 0);
            }
            b.width = p.keep_width ? body.width : 0;
            b.ascent = p.keep_height ? body.ascent : 0;
            b.descent = p.keep_height ? body.descent : 0;
            b.cls = AtomClass.ORD;
            return b;
        }
    }
}
