using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Formula {

    public class AutoCorrectView : Box {
        private Singularity.Equations.AutoCorrect ac;
        private PreferencesGroup entries_group;
        private PreferencesGroup functions_group;
        private EntryRow key_row;
        private EntryRow value_row;
        private EntryRow function_row;
        private SwitchRow enabled_row;
        private SwitchRow outside_row;
        private string query = "";
        private bool syncing;

        public AutoCorrectView (Singularity.Equations.AutoCorrect ac) {
            Object (orientation: Orientation.VERTICAL, spacing: 12);
            this.ac = ac;
            margin_start = 6;
            margin_end = 6;
            margin_bottom = 12;

            var options = new PreferencesGroup (_("Math AutoCorrect"), _("Type a name such as \\alpha and a space to replace it"));
            enabled_row = new SwitchRow (_("Replace While Typing"), null, ac.enabled);
            enabled_row.switch_btn.notify["active"].connect (() => {
                if (syncing) return;
                ac.enabled = enabled_row.active;
                save ();
            });
            options.add_row (enabled_row);
            outside_row = new SwitchRow (_("Use Outside Equations"), _("Write replaces names in normal text too"), ac.replace_outside_math);
            outside_row.switch_btn.notify["active"].connect (() => {
                if (syncing) return;
                ac.replace_outside_math = outside_row.active;
                save ();
            });
            options.add_row (outside_row);
            append (options);

            var add_group = new PreferencesGroup (_("New Entry"));
            key_row = new EntryRow (_("Replace, for example \\RR"));
            value_row = new EntryRow (_("With, for example ℝ"));
            value_row.entry_activated.connect (add_entry);
            add_group.add_row (key_row);
            add_group.add_row (value_row);
            var add_btn = new Button.with_label (_("Add Entry"));
            add_btn.add_css_class ("pill");
            add_btn.halign = Align.END;
            add_btn.margin_top = 6;
            add_btn.clicked.connect (add_entry);
            add_group.append (add_btn);
            append (add_group);

            functions_group = new PreferencesGroup (_("Recognized Functions"), _("Names typed in an equation that are set upright, like sin"));
            function_row = new EntryRow (_("Add a function name"));
            function_row.entry_activated.connect (add_function);
            functions_group.add_row (function_row);
            append (functions_group);

            entries_group = new PreferencesGroup (_("Entries"));
            append (entries_group);

            var reset = new Button.with_label (_("Restore Defaults"));
            reset.add_css_class ("pill");
            reset.halign = Align.CENTER;
            reset.clicked.connect (() => {
                ac.reset ();
                save ();
            });
            append (reset);
            ac.changed.connect (() => rebuild ());
            rebuild ();
        }

        public void filter (string text) {
            query = text.strip ().down ();
            rebuild ();
        }

        private void save () {
            try {
                ac.save ();
            } catch (Error e) {
                warning ("math autocorrect: %s", e.message);
            }
        }

        private void add_entry () {
            string k = key_row.text.strip ();
            string v = value_row.text;
            if (k == "" || v == "") return;
            if (!k.has_prefix ("\\") && k.char_count () < 2) return;
            ac.set_entry (k, v);
            save ();
            key_row.text = "";
            value_row.text = "";
        }

        private void add_function () {
            string f = function_row.text.strip ();
            if (f == "") return;
            ac.add_function (f);
            save ();
            function_row.text = "";
        }

        private void rebuild () {
            syncing = true;
            enabled_row.active = ac.enabled;
            outside_row.active = ac.replace_outside_math;
            syncing = false;
            foreach (var r in functions_group.get_rows ()) if (r != function_row) functions_group.remove_row (r);
            var flow = new FlowBox ();
            flow.selection_mode = SelectionMode.NONE;
            flow.column_spacing = 4;
            flow.row_spacing = 4;
            flow.max_children_per_line = 4;
            foreach (var f in ac.functions ()) {
                if (query != "" && !f.down ().contains (query)) continue;
                var chip = new Button ();
                chip.add_css_class ("formula-function-chip");
                var box = new Box (Orientation.HORIZONTAL, 4);
                box.append (new Label (f));
                var x = new Image.from_icon_name ("window-close-symbolic");
                x.pixel_size = 12;
                box.append (x);
                chip.child = box;
                chip.tooltip_text = _("Remove \"%s\"").printf (f);
                string name = f;
                chip.clicked.connect (() => {
                    ac.remove_function (name);
                    save ();
                });
                flow.append (chip);
            }
            var holder = new ListBoxRow ();
            holder.activatable = false;
            holder.selectable = false;
            holder.child = flow;
            functions_group.add_row (holder);

            entries_group.clear ();
            int shown = 0;
            var keys = ac.keys ();
            keys.sort ((a, b) => {
                bool ca = ac.is_custom (a);
                bool cb = ac.is_custom (b);
                if (ca != cb) return ca ? -1 : 1;
                return strcmp (a.down (), b.down ());
            });
            foreach (var k in keys) {
                string v = ac.lookup (k) ?? "";
                if (query != "" && !k.down ().contains (query) && !v.down ().contains (query)) continue;
                if (shown >= 120) break;
                shown++;
                var row = new ActionRow (k, display_value (v));
                if (ac.is_custom (k)) {
                    var tag = new Label (_("Yours"));
                    tag.add_css_class ("caption");
                    tag.add_css_class ("dim-label");
                    row.add_suffix (tag);
                }
                var rm = new Button.from_icon_name ("user-trash-symbolic");
                rm.add_css_class ("flat");
                rm.valign = Align.CENTER;
                rm.tooltip_text = _("Remove");
                string key = k;
                rm.clicked.connect (() => {
                    ac.remove_entry (key);
                    save ();
                });
                row.add_suffix (rm);
                entries_group.add_row (row);
            }
            if (shown == 0) {
                var none = new ActionRow (_("No Matches"), _("No entry matches your search."));
                entries_group.add_row (none);
            }
        }

        private static string display_value (string v) {
            if (v.char_count () == 1) {
                unichar c = v.get_char (0);
                if ((c >= 0x300 && c <= 0x36f) || (c >= 0x20d0 && c <= 0x20ff)) return "◌" + v;
                if (c == 0x2061 || c == 0x2062 || c == 0x200b || c == 0x200c) return "U+%04X".printf ((uint) c);
                if (c == 0x2003 || c == 0x2002 || c == 0x2005 || c == 0x2004 || c == 0x2006 || c == 0x205f || c == 0x200a || c == 0xa0) return _("space");
            }
            return v;
        }
    }
}
