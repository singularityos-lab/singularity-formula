namespace Singularity.Apps.Formula {

    public class FormulaPrintSource : Singularity.Print.PageSource {
        private FormulaDoc doc;
        private DocLayout? layout;
        private double size = 24;
        private Singularity.Print.PageFormat? format;
        private string latex_text = "";
        private bool show_source;
        private bool fit_width;

        public FormulaPrintSource (FormulaDoc doc, string title) {
            this.doc = doc;
            this.title = title;
            var x = new Singularity.Print.ExtraOptions (_("Formula"), _("How the equation is placed on the page"));
            x.add_number ("size", _("Font Size"), _("In points"), 8, 96, 1, 24);
            x.add_choice ("align", _("Alignment"), { "document", "left", "center", "right" }, { _("As in the Equation"), _("Left"), _("Center"), _("Right") }, "document");
            x.add_switch ("fit", _("Break Long Lines to Fit the Page"), null, true);
            x.add_switch ("source", _("Print the LaTeX Source"), _("Adds the linear form under the equation"), false);
            extra_options = x;
        }

        public override bool can_reflow {
            get { return true; }
        }

        public override async int paginate (Singularity.Print.PageFormat f) throws Error {
            format = f;
            size = extra_options.get_number ("size");
            fit_width = extra_options.get_bool ("fit");
            show_source = extra_options.get_bool ("source");
            var d = doc;
            double saved = d.line_width;
            if (fit_width && size > 0) d.line_width = f.content_width / size;
            var engine = new LayoutEngine (FormulaApp.math_font (), size);
            layout = DocLayout.build (d, engine);
            d.line_width = saved;
            latex_text = doc.to_latex ();
            page_width = f.width;
            page_height = f.height;
            return 1;
        }

        public override void render_page (Cairo.Context cr, int index) {
            if (layout == null || format == null) return;
            double avail = format.content_width;
            double scale = layout.width > avail ? avail / layout.width : 1.0;
            double w = layout.width * scale;
            string align = extra_options.get_choice ("align");
            var just = doc.justification;
            if (align == "left") just = Singularity.Equations.Justification.LEFT;
            else if (align == "right") just = Singularity.Equations.Justification.RIGHT;
            else if (align == "center") just = Singularity.Equations.Justification.CENTER;
            double x = format.margin_left + (avail - w) / 2.0;
            if (just == Singularity.Equations.Justification.LEFT) x = format.margin_left;
            else if (just == Singularity.Equations.Justification.RIGHT) x = format.margin_left + avail - w;
            double y = format.margin_top + size * 0.5;
            var r = new Renderer ();
            r.foreground = Rgba (0, 0, 0, 1);
            double box_w = layout.box.width * scale;
            double bx = format.margin_left + (avail - box_w) / 2.0;
            if (just == Singularity.Equations.Justification.LEFT) bx = format.margin_left;
            else if (just == Singularity.Equations.Justification.RIGHT) bx = format.margin_left + avail - box_w - (layout.label_width > 0 ? (layout.label_width + layout.label_gap) * scale : 0);
            if (layout.label_width <= 0) bx = x;
            cr.save ();
            cr.translate (bx, y);
            cr.scale (scale, scale);
            r.draw (cr, layout.box, 0, layout.ascent);
            cr.restore ();
            for (int i = 0; i < layout.labels.length; i++) {
                if (layout.labels[i] == null) continue;
                double by = layout.labels.length > 1 ? layout.label_baselines[i] : 0;
                cr.save ();
                cr.translate (format.margin_left + avail - layout.labels[i].width * scale, y);
                cr.scale (scale, scale);
                r.draw (cr, layout.labels[i], 0, layout.ascent + by);
                cr.restore ();
            }
            if (show_source && latex_text != "") {
                var pl = Pango.cairo_create_layout (cr);
                pl.set_font_description (Pango.FontDescription.from_string ("Monospace 9"));
                pl.set_width ((int) (avail * Pango.SCALE));
                pl.set_wrap (Pango.WrapMode.WORD_CHAR);
                pl.set_text (latex_text, -1);
                cr.set_source_rgb (0.3, 0.3, 0.3);
                cr.move_to (format.margin_left, y + (layout.ascent + layout.descent) * scale + size);
                Pango.cairo_show_layout (cr, pl);
            }
        }
    }
}
