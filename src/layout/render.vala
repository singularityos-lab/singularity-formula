namespace Singularity.Apps.Formula {

    public struct Rgba {
        public double r;
        public double g;
        public double b;
        public double a;

        public Rgba (double r, double g, double b, double a = 1.0) {
            this.r = r;
            this.g = g;
            this.b = b;
            this.a = a;
        }

        public static bool parse (string spec, out Rgba color) {
            color = Rgba (0, 0, 0, 1);
            string s = spec.strip ().down ();
            if (s.has_prefix ("#")) s = s.substring (1);
            else {
                string? hex = named (s);
                if (hex != null) s = hex;
            }
            if (s.length == 3) s = "%c%c%c%c%c%c".printf (s[0], s[0], s[1], s[1], s[2], s[2]);
            if (s.length != 6 && s.length != 8) return false;
            for (int i = 0; i < s.length; i++) if (!s[i].isxdigit ()) return false;
            color.r = hexval (s, 0) / 255.0;
            color.g = hexval (s, 2) / 255.0;
            color.b = hexval (s, 4) / 255.0;
            color.a = s.length == 8 ? hexval (s, 6) / 255.0 : 1.0;
            return true;
        }

        private static int hexval (string s, int at) {
            return s[at].xdigit_value () * 16 + s[at + 1].xdigit_value ();
        }

        public static string? named (string n) {
            switch (n) {
                case "black": return "000000";
                case "white": return "ffffff";
                case "red": return "d62828";
                case "green": return "1f8a3a";
                case "blue": return "1c5fd6";
                case "cyan": return "00a6c0";
                case "magenta": return "c42a9c";
                case "yellow": return "d4a800";
                case "orange": return "e8740c";
                case "purple": return "7b3fb5";
                case "violet": return "8a4fd8";
                case "brown": return "8a5a2b";
                case "gray": case "grey": return "808080";
                case "darkgray": return "404040";
                case "lightgray": return "bfbfbf";
                case "lime": return "7cc300";
                case "olive": return "7f7f00";
                case "pink": return "ff7fb0";
                case "teal": return "008080";
                default: return null;
            }
        }
    }

    public class Renderer {
        public Rgba foreground = Rgba (0, 0, 0, 1);
        public bool draw_hidden;

        public void draw (Cairo.Context cr, MBox box, double x, double y) {
            draw_box (cr, box, x, y, foreground);
        }

        private void set_color (Cairo.Context cr, Rgba c) {
            cr.set_source_rgba (c.r, c.g, c.b, c.a);
        }

        private void draw_box (Cairo.Context cr, MBox b, double x, double y, Rgba inherited) {
            if (b.hidden && !draw_hidden) return;
            Rgba col = inherited;
            if (b.color != null) {
                Rgba parsed;
                if (Rgba.parse (b.color, out parsed)) col = parsed;
            }
            foreach (var it in b.items) draw_item (cr, it, x, y, col);
            foreach (var c in b.children) draw_box (cr, c.box, x + c.x, y + c.y, col);
        }

        private void draw_item (Cairo.Context cr, Item it, double x, double y, Rgba col) {
            Rgba ic = col;
            if (it.color != null) {
                Rgba parsed;
                if (Rgba.parse (it.color, out parsed)) ic = parsed;
            }
            switch (it.kind) {
                case ItemKind.GLYPH:
                    if (it.font == null || it.font.face == null) return;
                    set_color (cr, ic);
                    cr.save ();
                    cr.set_font_face (it.font.face);
                    var opts = new Cairo.FontOptions ();
                    opts.set_hint_metrics (Cairo.HintMetrics.OFF);
                    opts.set_hint_style (Cairo.HintStyle.NONE);
                    cr.set_font_options (opts);
                    cr.translate (x + it.x, y + it.y);
                    if (it.sx != 1.0 || it.sy != 1.0) cr.scale (it.sx, it.sy);
                    cr.set_font_size (it.size);
                    Cairo.Glyph[] glyphs = new Cairo.Glyph[1];
                    glyphs[0].index = it.glyph;
                    glyphs[0].x = 0;
                    glyphs[0].y = 0;
                    cr.show_glyphs (glyphs);
                    cr.restore ();
                    break;
                case ItemKind.RULE:
                    set_color (cr, ic);
                    cr.rectangle (x + it.x, y + it.y, it.w, it.h);
                    cr.fill ();
                    break;
                case ItemKind.BACKGROUND:
                    set_color (cr, ic);
                    cr.rectangle (x + it.x, y + it.y, it.w, it.h);
                    cr.fill ();
                    break;
                case ItemKind.FRAME:
                    set_color (cr, ic);
                    cr.set_line_width (it.size);
                    if (it.sx > 0) {
                        rounded (cr, x + it.x, y + it.y, it.w, it.h, it.sx);
                    } else {
                        cr.rectangle (x + it.x, y + it.y, it.w, it.h);
                    }
                    cr.stroke ();
                    break;
                case ItemKind.ELLIPSE:
                    set_color (cr, ic);
                    cr.save ();
                    cr.translate (x + it.x + it.w / 2, y + it.y + it.h / 2);
                    cr.scale (it.w / 2, it.h / 2);
                    cr.arc (0, 0, 1, 0, 2 * Math.PI);
                    cr.restore ();
                    cr.set_line_width (it.size);
                    cr.stroke ();
                    break;
                case ItemKind.LINE:
                    set_color (cr, ic);
                    cr.set_line_width (it.size);
                    cr.move_to (x + it.x, y + it.y);
                    cr.line_to (x + it.x + it.w, y + it.y + it.h);
                    cr.stroke ();
                    break;
                case ItemKind.PLACEHOLDER:
                    Rgba pc = Rgba (0.5, 0.5, 0.5, 1);
                    if (it.color != null) Rgba.parse (it.color, out pc);
                    cr.set_source_rgba (pc.r, pc.g, pc.b, 0.12);
                    rounded (cr, x + it.x, y + it.y, it.w, it.h, it.w * 0.12);
                    cr.fill_preserve ();
                    cr.set_source_rgba (pc.r, pc.g, pc.b, 0.65);
                    cr.set_line_width (double.max (0.8, it.size * 0.035));
                    cr.set_dash ({ it.size * 0.07, it.size * 0.05 }, 0);
                    cr.stroke ();
                    cr.set_dash (null, 0);
                    break;
                case ItemKind.PENDING:
                    Rgba pd = Rgba (0.2, 0.4, 0.8, 1);
                    if (it.color != null) Rgba.parse (it.color, out pd);
                    cr.set_source_rgba (pd.r, pd.g, pd.b, 0.14);
                    rounded (cr, x + it.x, y + it.y, it.w, it.h, 3);
                    cr.fill ();
                    break;
                default:
                    break;
            }
        }

        public static void rounded (Cairo.Context cr, double x, double y, double w, double h, double r) {
            r = double.min (r, double.min (w, h) / 2);
            cr.new_sub_path ();
            cr.arc (x + w - r, y + r, r, -Math.PI / 2, 0);
            cr.arc (x + w - r, y + h - r, r, 0, Math.PI / 2);
            cr.arc (x + r, y + h - r, r, Math.PI / 2, Math.PI);
            cr.arc (x + r, y + r, r, Math.PI, 3 * Math.PI / 2);
            cr.close_path ();
        }
    }

    public class DocLayout {
        public MBox box;
        public MBox?[] labels = {};
        public double[] label_baselines = {};
        public double label_gap;
        public double width;
        public double ascent;
        public double descent;
        public double label_width;
        public Singularity.Equations.Justification justification = Singularity.Equations.Justification.CENTER_GROUP;

        public static DocLayout build (FormulaDoc doc, LayoutEngine engine) {
            var dl = new DocLayout ();
            engine.refs = doc.references ();
            engine.number_style = doc.number_style;
            engine.max_width = doc.line_width * engine.size;
            engine.wrap_indent = doc.wrap_indent;
            engine.wrap_right = doc.wrap_right;
            engine.break_row = doc.root;
            dl.justification = doc.justification;
            dl.box = engine.layout (doc.root, doc.display);
            var labels = doc.labels ();
            dl.label_gap = 2.0 * engine.size;
            var t = doc.lines_table ();
            dl.labels = new MBox?[labels.length];
            dl.label_baselines = new double[labels.length];
            for (int i = 0; i < labels.length; i++) {
                if (labels[i] == null) continue;
                var row = new Row ();
                int k = 0;
                unichar c;
                string lab = doc.format_label (labels[i]);
                while (lab.get_next_char (ref k, out c)) {
                    if (c == '(' || c == ')' || c == '[' || c == ']') {
                        row.append (new Token.op (c.to_string ()));
                        continue;
                    }
                    var tk = new Token.plain (c.to_string ());
                    tk.variant = MathVariant.NORMAL;
                    row.append (tk);
                }
                var lb = engine.layout_row (row, MStyle (1, false), false);
                dl.labels[i] = lb;
                dl.label_width = double.max (dl.label_width, lb.width);
            }
            if (t != null && labels.length == t.row_count && dl.box.children.size > 0) {
                var tb = find_table_grid (dl.box);
                if (tb != null) {
                    for (int i = 0; i < labels.length && i < tb.length; i++) dl.label_baselines[i] = tb[i];
                }
            }
            dl.ascent = dl.box.ascent;
            dl.descent = dl.box.descent;
            foreach (var lb in dl.labels) {
                if (lb == null) continue;
                dl.ascent = double.max (dl.ascent, lb.ascent);
                dl.descent = double.max (dl.descent, lb.descent);
            }
            dl.width = dl.box.width + (dl.label_width > 0 ? dl.label_gap + dl.label_width : 0);
            return dl;
        }

        private static double[]? find_table_grid (MBox root) {
            MBox b = root;
            double offset = 0;
            for (int depth = 0; depth < 4; depth++) {
                if (b.children.size == 0) return null;
                var c = b.children[0];
                offset += c.y;
                b = c.box;
                if (b.children.size > 1 && b.row == null) {
                    var ys = new Gee.ArrayList<double?> ();
                    foreach (var ch in b.children) {
                        double yy = offset + ch.y;
                        bool seen = false;
                        foreach (var v in ys) if (Math.fabs (v - yy) < 0.01) seen = true;
                        if (!seen) ys.add (yy);
                    }
                    double[] res = new double[ys.size];
                    for (int i = 0; i < ys.size; i++) res[i] = ys[i];
                    return res;
                }
            }
            return null;
        }

        public void draw (Cairo.Context cr, Renderer r, double x, double y, double total_width = -1) {
            r.draw (cr, box, x, y);
            double w = total_width > 0 ? total_width : width;
            for (int i = 0; i < labels.length; i++) {
                if (labels[i] == null) continue;
                double by = labels.length > 1 ? y + label_baselines[i] : y;
                r.draw (cr, labels[i], x + w - labels[i].width, by);
            }
        }
    }

    public class Exporter {
        public FormulaDoc doc;
        public LayoutEngine engine;
        public Rgba foreground = Rgba (0, 0, 0, 1);
        public Rgba? background;
        public double padding;

        public Exporter (FormulaDoc doc, MathFont font, double size) {
            this.doc = doc;
            engine = new LayoutEngine (font, size);
            padding = size * 0.25;
        }

        public void extent (out double w, out double h, out DocLayout dl) {
            dl = DocLayout.build (doc, engine);
            w = Math.ceil (dl.width + 2 * padding);
            h = Math.ceil (dl.ascent + dl.descent + 2 * padding);
            if (w < 1) w = 1;
            if (h < 1) h = 1;
        }

        private void paint (Cairo.Context cr, DocLayout dl, double scale) {
            cr.scale (scale, scale);
            if (background != null) {
                cr.set_source_rgba (background.r, background.g, background.b, background.a);
                cr.paint ();
            }
            var r = new Renderer ();
            r.foreground = foreground;
            dl.draw (cr, r, padding, padding + dl.ascent);
        }

        public void write_svg (string path) throws Error {
            double w, h;
            DocLayout dl;
            extent (out w, out h, out dl);
            var s = new Cairo.SvgSurface (path, w, h);
            s.restrict_to_version (Cairo.SvgVersion.VERSION_1_1);
            var cr = new Cairo.Context (s);
            paint (cr, dl, 1.0);
            s.finish ();
            check (s.status (), path);
        }

        public void write_pdf (string path) throws Error {
            double w, h;
            DocLayout dl;
            extent (out w, out h, out dl);
            var s = new Cairo.PdfSurface (path, w, h);
            s.set_metadata (Cairo.PdfMetadata.CREATOR, "Formula");
            var cr = new Cairo.Context (s);
            paint (cr, dl, 1.0);
            s.finish ();
            check (s.status (), path);
        }

        public Cairo.ImageSurface image (double scale) {
            double w, h;
            DocLayout dl;
            extent (out w, out h, out dl);
            var s = new Cairo.ImageSurface (Cairo.Format.ARGB32, (int) Math.ceil (w * scale), (int) Math.ceil (h * scale));
            var cr = new Cairo.Context (s);
            paint (cr, dl, scale);
            s.flush ();
            return s;
        }

        public void write_png (string path, double scale) throws Error {
            var s = image (scale);
            var st = s.write_to_png (path);
            check (st, path);
        }

        public uint8[] png_bytes (double scale) {
            var s = image (scale);
            var buf = new ByteArray ();
            s.write_to_png_stream ((data) => {
                buf.append (data);
                return Cairo.Status.SUCCESS;
            });
            return buf.data;
        }

        public uint8[] svg_bytes () {
            double w, h;
            DocLayout dl;
            extent (out w, out h, out dl);
            var buf = new ByteArray ();
            var s = new Cairo.SvgSurface.for_stream ((data) => {
                buf.append (data);
                return Cairo.Status.SUCCESS;
            }, w, h);
            var cr = new Cairo.Context (s);
            paint (cr, dl, 1.0);
            s.finish ();
            return buf.data;
        }

        private static void check (Cairo.Status st, string path) throws Error {
            if (st != Cairo.Status.SUCCESS) throw new IOError.FAILED (_("Could not write \"%s\": %s").printf (Path.get_basename (path), st.to_string ()));
        }
    }
}
