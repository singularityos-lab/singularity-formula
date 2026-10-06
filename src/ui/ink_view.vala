using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Formula {

    public enum InkMode {
        WRITE,
        ERASE,
        CORRECT
    }

    public class InkCanvas : Widget {
        public InkDrawing drawing = new InkDrawing ();
        public InkParser? parser;
        public InkMode mode = InkMode.WRITE;
        private InkStroke? current;

        public signal void stroke_finished ();
        public signal void symbol_clicked (InkSymbol sym, double x, double y);

        public InkCanvas () {
            Object (accessible_role: AccessibleRole.IMG);
            hexpand = true;
            vexpand = true;
            focusable = true;
            add_css_class ("formula-ink");
            update_property (AccessibleProperty.LABEL, _("Handwriting area"), -1);
            var drag = new GestureDrag ();
            drag.button = 0;
            drag.drag_begin.connect ((x, y) => {
                grab_focus ();
                if (mode == InkMode.WRITE) {
                    current = new InkStroke ();
                    current.add (x, y);
                    queue_draw ();
                } else if (mode == InkMode.ERASE) {
                    if (drawing.erase_at (x, y, 10)) stroke_finished ();
                    queue_draw ();
                } else if (parser != null) {
                    var sym = parser.symbol_at (x, y);
                    if (sym != null) symbol_clicked (sym, x, y);
                }
            });
            drag.drag_update.connect ((dx, dy) => {
                double sx, sy;
                drag.get_start_point (out sx, out sy);
                if (mode == InkMode.WRITE && current != null) {
                    current.add (sx + dx, sy + dy);
                    queue_draw ();
                } else if (mode == InkMode.ERASE) {
                    if (drawing.erase_at (sx + dx, sy + dy, 10)) stroke_finished ();
                    queue_draw ();
                }
            });
            drag.drag_end.connect ((dx, dy) => {
                if (mode == InkMode.WRITE && current != null) {
                    if (current.points.size == 1) current.add (current.points[0].x + 0.5, current.points[0].y + 0.5);
                    drawing.add (current);
                    current = null;
                    stroke_finished ();
                    queue_draw ();
                }
            });
            add_controller (drag);
            drawing.changed.connect (() => queue_draw ());
        }

        public override void snapshot (Snapshot snap) {
            int w = get_width ();
            int h = get_height ();
            var rect = Graphene.Rect ();
            rect.init (0, 0, w, h);
            var cr = snap.append_cairo (rect);
            var fg = get_color ();
            cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.12);
            cr.set_line_width (1);
            for (double gy = 48; gy < h; gy += 48) {
                cr.move_to (12, gy + 0.5);
                cr.line_to (w - 12, gy + 0.5);
            }
            cr.stroke ();
            if (mode == InkMode.CORRECT && parser != null) {
                var ac = Gdk.RGBA ();
                ac.parse ("#3584e4");
                foreach (var sym in parser.symbols) {
                    cr.set_source_rgba (ac.red, ac.green, ac.blue, 0.14);
                    Renderer.rounded (cr, sym.box.x0 - 5, sym.box.y0 - 5, sym.box.width + 10, sym.box.height + 10, 6);
                    cr.fill ();
                    var pl = create_pango_layout (sym.symbol);
                    cr.set_source_rgba (ac.red, ac.green, ac.blue, 1);
                    cr.move_to (sym.box.x0 - 4, sym.box.y1 + 6);
                    Pango.cairo_show_layout (cr, pl);
                }
            }
            cr.set_source_rgba (fg.red, fg.green, fg.blue, fg.alpha);
            cr.set_line_width (2.6);
            cr.set_line_cap (Cairo.LineCap.ROUND);
            cr.set_line_join (Cairo.LineJoin.ROUND);
            foreach (var s in drawing.strokes) draw_stroke (cr, s);
            if (current != null) draw_stroke (cr, current);
            if (drawing.is_empty () && current == null) {
                var pl = create_pango_layout (_("Write an equation here with a pen, a touch screen or the mouse"));
                int pw, ph;
                pl.get_pixel_size (out pw, out ph);
                cr.set_source_rgba (fg.red, fg.green, fg.blue, 0.45);
                cr.move_to ((w - pw) / 2.0, (h - ph) / 2.0);
                Pango.cairo_show_layout (cr, pl);
            }
        }

        private static void draw_stroke (Cairo.Context cr, InkStroke s) {
            if (s.points.size == 0) return;
            cr.move_to (s.points[0].x, s.points[0].y);
            for (int i = 1; i < s.points.size; i++) cr.line_to (s.points[i].x, s.points[i].y);
            cr.stroke ();
        }
    }

    public class InkPage : Box {
        public InkCanvas canvas;
        private InkParser parser;
        private FormulaPreview preview;
        private Label status;
        private uint recognize_id;
        private string latex = "";
        private BubbleSwitcher modes;

        public signal void insert_requested (string latex);
        public signal void cancelled ();

        public InkPage () {
            Object (orientation: Orientation.VERTICAL, spacing: 0);
            add_css_class ("formula-ink-page");
            parser = new InkParser (InkRecognizer.get_default ());
            canvas = new InkCanvas ();
            canvas.parser = parser;
            canvas.stroke_finished.connect (schedule);
            canvas.symbol_clicked.connect (correct_symbol);

            var frame = new Box (Orientation.VERTICAL, 0);
            frame.add_css_class ("formula-ink-frame");
            frame.margin_start = 16;
            frame.margin_end = 16;
            frame.margin_top = 64;
            frame.vexpand = true;
            frame.append (canvas);
            append (frame);

            var bottom = new Box (Orientation.VERTICAL, 8);
            bottom.margin_start = 16;
            bottom.margin_end = 16;
            bottom.margin_top = 12;
            bottom.margin_bottom = 16;
            preview = new FormulaPreview (new FormulaDoc (), 28, false, 900);
            preview.height_request = 72;
            preview.update_property (AccessibleProperty.LABEL, _("Recognized equation"), -1);
            bottom.append (preview);
            status = new Label (_("The recognized equation appears here as you write."));
            status.add_css_class ("dim-label");
            status.wrap = true;
            bottom.append (status);
            var actions = new Box (Orientation.HORIZONTAL, 8);
            modes = new BubbleSwitcher ();
            modes.add_option ("write", _("Write"));
            modes.add_option ("erase", _("Erase"));
            modes.add_option ("correct", _("Select and Correct"));
            modes.set_active ("write");
            modes.selected.connect ((name) => {
                canvas.mode = name == "erase" ? InkMode.ERASE : (name == "correct" ? InkMode.CORRECT : InkMode.WRITE);
                canvas.queue_draw ();
            });
            actions.append (modes);
            var undo = new Button.from_icon_name ("edit-undo-symbolic");
            undo.tooltip_text = _("Undo Last Stroke");
            undo.clicked.connect (() => {
                canvas.drawing.undo ();
                schedule ();
            });
            actions.append (undo);
            var clear = new Button.with_label (_("Clear"));
            clear.clicked.connect (() => {
                canvas.drawing.clear ();
                schedule ();
            });
            actions.append (clear);
            var gap = new Box (Orientation.HORIZONTAL, 0);
            gap.hexpand = true;
            actions.append (gap);
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => cancelled ());
            var insert = new Button.with_label (_("Insert"));
            insert.add_css_class ("suggested-action");
            insert.clicked.connect (() => {
                if (latex != "") insert_requested (latex);
            });
            actions.append (cancel);
            actions.append (insert);
            bottom.append (actions);
            append (bottom);
        }

        public void reset () {
            canvas.drawing.clear ();
            latex = "";
            modes.set_active ("write");
            canvas.mode = InkMode.WRITE;
            preview.set_doc (new FormulaDoc ());
            status.label = _("The recognized equation appears here as you write.");
        }

        private void schedule () {
            if (recognize_id != 0) Source.remove (recognize_id);
            recognize_id = Timeout.add (250, () => {
                recognize_id = 0;
                recognize ();
                return Source.REMOVE;
            });
        }

        private void recognize () {
            latex = parser.recognize (canvas.drawing.strokes);
            show_result ();
        }

        private void show_result () {
            try {
                var d = FormulaDoc.parse_linear (latex, LinearSyntax.LATEX);
                preview.set_doc (d);
                string spoken = Singularity.Equations.Speech.describe (d.to_mathml (false, false));
                preview.update_property (AccessibleProperty.DESCRIPTION, spoken, -1);
                status.label = canvas.drawing.is_empty () ? _("The recognized equation appears here as you write.") : _("Wrong symbol? Choose Select and Correct, then click it.");
            } catch (ParseError e) {
                status.label = _("Keep writing: the equation is not complete yet.");
            }
            canvas.queue_draw ();
        }

        private void correct_symbol (InkSymbol sym, double x, double y) {
            var menu = new ContextMenu (canvas);
            var rect = Gdk.Rectangle ();
            rect.x = (int) x;
            rect.y = (int) y;
            rect.width = 1;
            rect.height = 1;
            menu.pointing_to = rect;
            foreach (var cand in sym.candidates) {
                string s = cand.symbol;
                menu.add_item (s == sym.symbol ? _("%s (current)").printf (s) : s, null, () => apply_correction (sym, s));
            }
            menu.add_separator ();
            menu.add_item (_("Other Symbol"), "edit-symbolic", () => other_symbol (sym));
            menu.closed.connect (() => Idle.add (() => {
                menu.unparent ();
                return Source.REMOVE;
            }));
            menu.popup ();
        }

        private void apply_correction (InkSymbol sym, string s) {
            sym.symbol = s;
            sym.forced = true;
            parser.recognizer.learn (s, sym.strokes);
            latex = parser.to_latex ();
            show_result ();
        }

        private void other_symbol (InkSymbol sym) {
            var win = get_root () as Gtk.Window;
            var dlg = new AppDialog (win != null ? win.application : null, true);
            dlg.set_title (_("Correct Symbol"));
            dlg.transient_for = win;
            dlg.set_default_size (360, 220);
            var group = new PreferencesGroup ();
            group.margin_start = group.margin_end = 18;
            var row = new EntryRow (_("Symbol or LaTeX command"));
            group.add_row (row);
            dlg.content_box.append (group);
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.halign = Align.END;
            bar.margin_start = bar.margin_end = 18;
            bar.margin_top = 12;
            bar.margin_bottom = 16;
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => dlg.close ());
            dlg.set_cancel_button (cancel);
            var ok = new Button.with_label (_("Correct"));
            ok.add_css_class ("suggested-action");
            ok.clicked.connect (() => {
                string t = row.text.strip ();
                if (t.has_prefix ("\\")) {
                    var symb = Symbols.by_command (t.substring (1));
                    if (symb != null) t = symb.ch;
                }
                if (t != "") apply_correction (sym, t);
                dlg.close ();
            });
            bar.append (cancel);
            bar.append (ok);
            dlg.content_box.append (bar);
            dlg.present ();
        }
    }
}
