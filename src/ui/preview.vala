using Gtk;

namespace Singularity.Apps.Formula {

    public class FormulaPreview : DrawingArea {
        private FormulaDoc doc;
        private double size;
        private bool placeholders;
        private DocLayout? layout;
        private double max_width;

        public FormulaPreview (FormulaDoc doc, double size, bool placeholders = false, double max_width = -1) {
            this.doc = doc;
            this.size = size;
            this.placeholders = placeholders;
            this.max_width = max_width;
            relayout ();
            set_draw_func (draw);
        }

        public FormulaPreview.latex (string latex, double size, bool placeholders = false, double max_width = -1) {
            FormulaDoc d;
            try {
                d = FormulaDoc.parse_linear (latex, LinearSyntax.LATEX);
            } catch (ParseError e) {
                d = new FormulaDoc ();
            }
            this (d, size, placeholders, max_width);
        }

        public void set_doc (FormulaDoc d) {
            doc = d;
            relayout ();
            queue_draw ();
        }

        private double scale_factor () {
            if (layout == null || max_width <= 0 || layout.width <= max_width) return 1.0;
            return max_width / layout.width;
        }

        public void relayout () {
            var engine = new LayoutEngine (FormulaApp.math_font (), size);
            engine.editing = placeholders;
            layout = DocLayout.build (doc, engine);
            double s = scale_factor ();
            content_width = (int) Math.ceil (layout.width * s) + 4;
            content_height = (int) Math.ceil ((layout.ascent + layout.descent) * s) + 4;
        }

        private void draw (DrawingArea area, Cairo.Context cr, int w, int h) {
            if (layout == null) return;
            var fg = get_color ();
            var r = new Renderer ();
            r.foreground = Rgba (fg.red, fg.green, fg.blue, fg.alpha);
            double s = scale_factor ();
            double lw = layout.width * s;
            double lh = (layout.ascent + layout.descent) * s;
            cr.translate ((w - lw) / 2.0, (h - lh) / 2.0);
            cr.scale (s, s);
            layout.draw (cr, r, 0, layout.ascent);
        }
    }
}
