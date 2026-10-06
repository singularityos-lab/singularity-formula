namespace Singularity.Apps.Formula {

    public class History : Object {
        public const int LIMIT = 40;
        private GLib.Settings? settings;
        private Gee.ArrayList<string> list = new Gee.ArrayList<string> ();

        public signal void changed ();

        public History (GLib.Settings? settings) {
            this.settings = settings;
            if (settings != null) {
                foreach (var s in settings.get_strv ("history")) list.add (s);
            }
        }

        public Gee.List<string> items {
            get { return list; }
        }

        public void add (string latex) {
            string t = latex.strip ();
            if (t == "") return;
            list.remove (t);
            list.insert (0, t);
            while (list.size > LIMIT) list.remove_at (list.size - 1);
            store ();
        }

        public void remove (string latex) {
            if (list.remove (latex)) store ();
        }

        public void clear () {
            list.clear ();
            store ();
        }

        private void store () {
            if (settings != null) settings.set_strv ("history", list.to_array ());
            changed ();
        }
    }
}
