namespace Singularity.Apps.Formula {

    [DBus (name = "dev.sinty.Collab.Formula1")]
    public class FormulaCollabBus : Object {
        private unowned FormulaApp app;

        public FormulaCollabBus (FormulaApp app) {
            this.app = app;
        }

        public void receive (string title, string payload, string from) throws Error {
            var w = new FormulaWindow (app);
            w.present ();
            w.load_document (FormulaDoc.parse_any (payload));
        }

        public void join (string session, string title, string snapshot, string role, string from) throws Error {
            var w = new FormulaWindow (app);
            w.present ();
            w.new_document ();
            FormulaCollab.join (w, session, snapshot, from);
        }
    }

    public class FormulaCollab : Object {
        public Singularity.Collab.Session session;
        public Singularity.Collab.TextBinding binding;
        private unowned FormulaWindow win;
        private ulong edit_id = 0;

        private FormulaCollab (FormulaWindow win, Singularity.Collab.Text text, string title) {
            this.win = win;
            session = new Singularity.Collab.Session ("Formula", title, text);
            binding = new Singularity.Collab.TextBinding (text, () => win.doc != null ? win.doc.to_latex () : "", (latex, who) => {
                try {
                    var d = FormulaDoc.parse_any (latex);
                    if (win.doc != null) d.path = win.doc.path;
                    win.load_document (d);
                    attach_edits ();
                } catch (Error e) {
                    debug ("formula: remote change skipped: %s", e.message);
                }
            });
            attach_edits ();
            session.person_joined.connect ((name) => win.notify_collab (_("%s joined").printf (name)));
            session.person_left.connect ((name) => win.notify_collab (_("%s left").printf (name)));
            session.closed.connect (() => {
                if (win.editor != null && edit_id != 0) win.editor.disconnect (edit_id);
                edit_id = 0;
                win.set_data<FormulaCollab> ("formula-collab", null);
                win.notify_collab (_("Working together ended"));
            });
        }

        private void attach_edits () {
            if (win.editor == null || edit_id != 0) return;
            edit_id = win.editor.changed.connect (() => binding.local_changed ());
        }

        public static FormulaCollab? of (FormulaWindow win) {
            return win.get_data<FormulaCollab> ("formula-collab");
        }

        public static void share (FormulaWindow win, Gtk.Widget anchor) {
            if (win.doc == null) return;
            var c = of (win);
            if (c == null) {
                string title = win.doc.path != null ? Path.get_basename (win.doc.path) : _("Formula");
                c = new FormulaCollab (win, new Singularity.Collab.Text (win.doc.to_latex ()), title);
                win.set_data<FormulaCollab> ("formula-collab", c);
            }
            c.session.pick_and_share (anchor, (person) => win.notify_collab (_("Invitation sent to %s").printf (person.name)));
        }

        public static void stop (FormulaWindow win) {
            var c = of (win);
            if (c != null) c.session.stop.begin ();
        }

        public static void join (FormulaWindow win, string session_id, string snapshot, string from) {
            var text = new Singularity.Collab.Text ();
            text.load (snapshot);
            try {
                win.load_document (FormulaDoc.parse_any (text.to_string ()));
            } catch (Error e) {
                debug ("formula: %s", e.message);
            }
            var c = new FormulaCollab (win, text, _("Formula"));
            win.set_data<FormulaCollab> ("formula-collab", c);
            c.session.join (session_id, from);
            win.notify_collab (_("You are editing with %s").printf (from));
        }
    }
}
