using Gtk;

namespace Singularity.Apps.Formula {

    public class FormulaCanvas : Widget {
        public Editor editor { get; private set; }
        public double base_size = 36;
        public double zoom { get; private set; default = 1.0; }
        private LayoutEngine engine;
        private DocLayout? layout;
        private Geometry? geom;
        private double ox;
        private double oy;
        private bool dirty = true;
        private bool caret_on = true;
        private uint blink_id;
        private IMMulticontext im;
        private const double MARGIN = 48;
        private uint a11y_id;
        private Row? last_row;
        public string spoken { get; private set; default = ""; }

        public signal void context_menu (double x, double y);
        public signal void zoom_changed ();

        public FormulaCanvas (Editor editor) {
            Object (accessible_role: AccessibleRole.MATH);
            this.editor = editor;
            focusable = true;
            can_focus = true;
            hexpand = true;
            vexpand = true;
            add_css_class ("formula-canvas");
            engine = new LayoutEngine (FormulaApp.math_font (), base_size);
            engine.editing = true;
            editor.changed.connect (() => {
                invalidate ();
                schedule_accessible ();
            });
            editor.moved.connect (() => {
                if (last_row != editor.row) {
                    last_row = editor.row;
                    announce_context ();
                }
                engine.pending_row = editor.pending != null ? editor.row : null;
                engine.pending_index = editor.index;
                engine.pending_text = editor.pending ?? "";
                if (editor.pending != null) dirty = true;
                restart_blink ();
                queue_resize ();
                queue_draw ();
            });

            im = new IMMulticontext ();
            im.commit.connect ((text) => {
                editor.type_text (text);
            });
            var keys = new EventControllerKey ();
            keys.set_im_context (im);
            keys.key_pressed.connect (on_key);
            add_controller (keys);

            var focus = new EventControllerFocus ();
            focus.enter.connect (() => {
                im.focus_in ();
                restart_blink ();
                queue_draw ();
            });
            focus.leave.connect (() => {
                im.focus_out ();
                queue_draw ();
            });
            add_controller (focus);

            var click = new GestureClick ();
            click.button = 0;
            click.pressed.connect ((n, x, y) => {
                grab_focus ();
                uint button = click.get_current_button ();
                if (button == Gdk.BUTTON_SECONDARY) {
                    if (!editor.has_selection) place_caret (x, y, false);
                    Timeout.add (60, () => {
                        context_menu (x, y);
                        return Source.REMOVE;
                    });
                    return;
                }
                var state = click.get_current_event_state ();
                bool extend = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
                place_caret (x, y, extend);
                if (n == 2) select_word_at_caret ();
                if (n == 3) editor.select_all ();
            });
            add_controller (click);

            var drag = new GestureDrag ();
            drag.drag_update.connect ((dx, dy) => {
                double sx, sy;
                drag.get_start_point (out sx, out sy);
                if (Math.fabs (dx) + Math.fabs (dy) < 3) return;
                drag_to (sx + dx, sy + dy);
            });
            add_controller (drag);

            var scroll = new EventControllerScroll (EventControllerScrollFlags.VERTICAL);
            scroll.scroll.connect ((dx, dy) => {
                var st = scroll.get_current_event_state ();
                if ((st & Gdk.ModifierType.CONTROL_MASK) == 0) return false;
                zoom_to (zoom * (dy < 0 ? 1.1 : 1 / 1.1));
                return true;
            });
            add_controller (scroll);
            restart_blink ();
            update_property (AccessibleProperty.LABEL, _("Equation"), -1);
            update_accessible ();
        }

        private void schedule_accessible () {
            if (a11y_id != 0) Source.remove (a11y_id);
            a11y_id = Timeout.add (350, () => {
                a11y_id = 0;
                update_accessible ();
                return Source.REMOVE;
            });
        }

        public void update_accessible () {
            string mml = editor.doc.to_mathml (false, false);
            string s = Singularity.Equations.Speech.describe (mml);
            spoken = s;
            update_property (AccessibleProperty.DESCRIPTION, s != "" ? s : _("Empty equation"), -1);
            tooltip_text = null;
        }

        public static string context_name (Row row) {
            var owner = row.parent;
            if (owner == null) return _("Equation");
            if (owner is Frac) return ((Frac) owner).num == row ? _("Numerator") : _("Denominator");
            if (owner is Radical) return ((Radical) owner).index == row ? _("Root index") : _("Radicand");
            if (owner is Scripts) {
                var s = (Scripts) owner;
                if (s.pre) return s.sub == row ? _("Left subscript") : _("Left superscript");
                return s.sub == row ? _("Subscript") : _("Superscript");
            }
            if (owner is UnderOver) {
                var u = (UnderOver) owner;
                if (u.under == row) return _("Lower limit");
                if (u.over == row) return _("Upper limit");
                return _("Base");
            }
            if (owner is Accent) return _("Accent base");
            if (owner is Fenced) return _("Inside brackets");
            if (owner is Table) {
                int r, c;
                if (((Table) owner).locate (row, out r, out c)) return _("Row %d, column %d").printf (r + 1, c + 1);
                return _("Matrix cell");
            }
            if (owner is Enclose) return _("Inside box");
            return _("Group");
        }

        private void announce_context () {
            if (!has_focus) return;
            string where = context_name (editor.row);
            string content = "";
            if (editor.row.size > 0) {
                var d = new FormulaDoc ();
                d.set_root (editor.row.copy_row ());
                content = Singularity.Equations.Speech.describe (d.to_mathml (false, false));
            }
            announce (content != "" ? where + ": " + content : where, AccessibleAnnouncementPriority.MEDIUM);
        }

        public override void dispose () {
            if (a11y_id != 0) Source.remove (a11y_id);
            a11y_id = 0;
            if (blink_id != 0) Source.remove (blink_id);
            blink_id = 0;
            base.dispose ();
        }

        public void zoom_to (double z) {
            zoom = z.clamp (0.3, 6.0);
            invalidate ();
            zoom_changed ();
        }

        public void set_font_size (double size) {
            base_size = size;
            invalidate ();
        }

        public void reload_font () {
            engine = new LayoutEngine (FormulaApp.math_font (), base_size * zoom);
            engine.editing = true;
            invalidate ();
        }

        public void invalidate () {
            dirty = true;
            queue_resize ();
            queue_draw ();
        }

        private void restart_blink () {
            caret_on = true;
            if (blink_id != 0) Source.remove (blink_id);
            blink_id = Timeout.add (530, () => {
                caret_on = !caret_on;
                if (has_focus) queue_draw ();
                return Source.CONTINUE;
            });
        }

        private void ensure_layout () {
            if (!dirty && layout != null) return;
            if (engine.font != FormulaApp.math_font ()) engine = new LayoutEngine (FormulaApp.math_font (), base_size * zoom);
            engine.size = base_size * zoom;
            engine.editing = true;
            engine.pending_row = editor.pending != null ? editor.row : null;
            engine.pending_index = editor.index;
            engine.pending_text = editor.pending ?? "";
            layout = DocLayout.build (editor.doc, engine);
            dirty = false;
        }

        public override SizeRequestMode get_request_mode () {
            return SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline) {
            ensure_layout ();
            if (orientation == Orientation.HORIZONTAL) {
                minimum = (int) Math.ceil (layout.width + 2 * MARGIN);
            } else {
                minimum = (int) Math.ceil (layout.ascent + layout.descent + 2 * MARGIN);
            }
            natural = minimum;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void compute_origin () {
            int w = get_width ();
            int h = get_height ();
            double fw = layout.width;
            double fh = layout.ascent + layout.descent;
            ox = Math.floor (double.max (MARGIN, (w - fw) / 2.0));
            if (layout.label_width > 0) ox = Math.floor (double.max (MARGIN, (w - layout.box.width) / 2.0));
            if (editor.doc.justification == Singularity.Equations.Justification.LEFT) ox = MARGIN;
            else if (editor.doc.justification == Singularity.Equations.Justification.RIGHT) ox = Math.floor (double.max (MARGIN, w - MARGIN - (layout.label_width > 0 ? layout.width : fw)));
            oy = Math.floor (double.max (MARGIN, (h - fh) / 2.0)) + layout.ascent;
            geom = Geometry.compute (layout.box, ox, oy);
        }

        private Gdk.RGBA accent () {
            Gdk.RGBA c;
            var ctx = get_style_context ();
            if (!ctx.lookup_color ("accent_color", out c) && !ctx.lookup_color ("accent_bg_color", out c)) c.parse ("#3584e4");
            return c;
        }

        public override void snapshot (Snapshot snap) {
            ensure_layout ();
            int w = get_width ();
            int h = get_height ();
            compute_origin ();
            var rect = Graphene.Rect ();
            rect.init (0, 0, w, h);
            var cr = snap.append_cairo (rect);
            var fg = get_color ();
            var ac = accent ();
            var rg = geom.rows[editor.row];
            if (rg != null && editor.has_selection) {
                cr.set_source_rgba (ac.red, ac.green, ac.blue, 0.28);
                if (rg.caret_ys.length == rg.carets.length) {
                    double em = base_size * zoom;
                    for (int i = editor.sel_start; i < editor.sel_end; i++) {
                        double a = rg.carets[i];
                        double b = rg.caret_ys[i + 1] == rg.caret_ys[i] ? rg.carets[i + 1] : a + em * 0.5;
                        cr.rectangle (a, rg.caret_ys[i] - em * 0.8, b - a, em * 1.1);
                    }
                    cr.fill ();
                } else {
                    double x1 = rg.carets[editor.sel_start];
                    double x2 = rg.carets[editor.sel_end];
                    Renderer.rounded (cr, x1 - 1, rg.y - rg.ascent - 2, x2 - x1 + 2, rg.ascent + rg.descent + 4, 3);
                    cr.fill ();
                }
            }
            if (has_focus && rg != null && editor.row.parent != null) {
                cr.set_source_rgba (ac.red, ac.green, ac.blue, 0.08);
                Renderer.rounded (cr, rg.x - 2, rg.y - rg.ascent - 2, rg.width + 4, rg.ascent + rg.descent + 4, 3);
                cr.fill ();
            }
            var r = new Renderer ();
            r.foreground = Rgba (fg.red, fg.green, fg.blue, fg.alpha);
            layout.draw (cr, r, ox, oy, w - ox - MARGIN * 0.5);
            if (editor.doc.is_empty () && editor.pending == null) {
                var pl = create_pango_layout (_("Type a formula, or pick symbols and structures from the side panel"));
                int pw, ph;
                pl.get_pixel_size (out pw, out ph);
                cr.set_source_rgba (fg.red, fg.green, fg.blue, fg.alpha * 0.5);
                cr.move_to ((w - pw) / 2.0, oy + layout.descent + 24);
                Pango.cairo_show_layout (cr, pl);
            }
            if (has_focus && caret_on && rg != null && !editor.has_selection) {
                int idx = int.min (editor.index, rg.carets.length - 1);
                double cx = rg.carets[idx];
                double top = rg.y - double.max (rg.ascent, base_size * zoom * 0.7);
                double bottom = rg.y + double.max (rg.descent, base_size * zoom * 0.2);
                if (rg.caret_ys.length == rg.carets.length) {
                    top = rg.caret_ys[idx] - base_size * zoom * 0.8;
                    bottom = rg.caret_ys[idx] + base_size * zoom * 0.25;
                }
                cr.set_source_rgba (ac.red, ac.green, ac.blue, 1);
                cr.rectangle (Math.round (cx) - 1, top, 2, bottom - top);
                cr.fill ();
                if (editor.text_mode) {
                    cr.rectangle (Math.round (cx) - 4, bottom - 1, 8, 2);
                    cr.fill ();
                }
            }
        }

        private void place_caret (double x, double y, bool extend) {
            if (geom == null) return;
            var rg = geom.row_at (x, y);
            if (rg == null) return;
            int i = Geometry.nearest_caret (rg, x, y);
            editor.set_caret (rg.row, i, extend && rg.row == editor.row);
        }

        private void drag_to (double x, double y) {
            if (geom == null) return;
            var rg = geom.rows[editor.row];
            if (rg == null) return;
            int i = Geometry.nearest_caret (rg, x, y);
            if (editor.anchor < 0) editor.anchor = editor.index;
            editor.set_caret (editor.row, i, true);
        }

        private void select_word_at_caret () {
            if (editor.index > 0) {
                var n = editor.row[editor.index - 1];
                editor.select_node (n);
            } else if (editor.row.size > 0) {
                editor.select_node (editor.row[0]);
            }
        }

        private void vertical (bool up) {
            ensure_layout ();
            if (geom == null) compute_origin ();
            var cur = geom.rows[editor.row];
            if (cur == null) return;
            double cx = cur.carets[int.min (editor.index, cur.carets.length - 1)];
            double cy = cur.y;
            if (cur.caret_ys.length == cur.carets.length) {
                double ly = cur.caret_ys[int.min (editor.index, cur.caret_ys.length - 1)];
                double target = up ? -double.MAX : double.MAX;
                foreach (var y in cur.caret_ys) {
                    if (up && y < ly - 0.5 && y > target) target = y;
                    if (!up && y > ly + 0.5 && y < target) target = y;
                }
                if (target != double.MAX && target != -double.MAX) {
                    editor.set_caret (editor.row, Geometry.nearest_caret (cur, cx, target));
                    return;
                }
            }
            RowGeom? best = null;
            double best_score = double.MAX;
            foreach (var rg in geom.row_list) {
                if (rg == cur) continue;
                bool dir = up ? rg.y < cy - 0.5 : rg.y > cy + 0.5;
                if (!dir) continue;
                double dy = Math.fabs (rg.y - cy);
                double dx = cx < rg.x ? rg.x - cx : (cx > rg.x + rg.width ? cx - rg.x - rg.width : 0);
                double score = dx * 4 + dy + rg.width * 0.001;
                if (score < best_score) {
                    best_score = score;
                    best = rg;
                }
            }
            if (best == null) {
                if (up) editor.home ();
                else editor.end ();
                return;
            }
            editor.set_caret (best.row, Geometry.nearest_caret (best, cx));
        }

        private bool on_key (uint keyval, uint keycode, Gdk.ModifierType state) {
            bool shift = (state & Gdk.ModifierType.SHIFT_MASK) != 0;
            bool ctrl = (state & Gdk.ModifierType.CONTROL_MASK) != 0;
            restart_blink ();
            switch (keyval) {
                case Gdk.Key.Left:
                case Gdk.Key.KP_Left:
                    editor.move_left (shift);
                    return true;
                case Gdk.Key.Right:
                case Gdk.Key.KP_Right:
                    editor.move_right (shift);
                    return true;
                case Gdk.Key.Up:
                case Gdk.Key.KP_Up:
                    vertical (true);
                    return true;
                case Gdk.Key.Down:
                case Gdk.Key.KP_Down:
                    vertical (false);
                    return true;
                case Gdk.Key.Home:
                    editor.home (shift);
                    return true;
                case Gdk.Key.End:
                    editor.end (shift);
                    return true;
                case Gdk.Key.Tab:
                    editor.next_slot (false);
                    return true;
                case Gdk.Key.ISO_Left_Tab:
                    editor.next_slot (true);
                    return true;
                case Gdk.Key.BackSpace:
                    editor.backspace ();
                    return true;
                case Gdk.Key.Delete:
                case Gdk.Key.KP_Delete:
                    editor.delete_forward ();
                    return true;
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (ctrl) return false;
                    if (editor.pending != null) {
                        editor.finish_pending ();
                        return true;
                    }
                    editor.new_line ();
                    return true;
                case Gdk.Key.Escape:
                    if (editor.pending != null) {
                        editor.pending = null;
                        editor.moved ();
                        return true;
                    }
                    if (editor.has_selection) {
                        editor.clear_selection ();
                        editor.moved ();
                        return true;
                    }
                    return false;
                default:
                    return false;
            }
        }

        public bool caret_rect (out Gdk.Rectangle rect) {
            rect = Gdk.Rectangle ();
            if (geom == null) return false;
            var rg = geom.rows[editor.row];
            if (rg == null) return false;
            double cx = rg.carets[int.min (editor.index, rg.carets.length - 1)];
            rect.x = (int) cx;
            rect.y = (int) (rg.y - rg.ascent);
            rect.width = 2;
            rect.height = (int) (rg.ascent + rg.descent);
            return true;
        }
    }
}
