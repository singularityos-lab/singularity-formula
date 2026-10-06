using GLib;
using Gtk;
using Singularity.Accounts;
using Singularity.Widgets;

namespace Singularity.Apps.Formula {

    public delegate void CloudFileFunc (GLib.File file);

    public class CloudActions : Object {
        private static string[] mime_types () {
            return {
                "application/mathml+xml",
                "application/vnd.oasis.opendocument.formula",
                "text/x-tex"
            };
        }

        public static async void open (Gtk.Window window, owned CloudFileFunc open_file) {
            var file = yield CloudFileDialog.open (window, mime_types ());
            if (file != null) open_file (file.local);
        }

        public static void save_document (FormulaWindow window) {
            var doc = window.doc;
            if (doc == null) return;
            string name = doc.path != null ? Path.get_basename (doc.path) : _("Formula") + ".mml";
            var kind = FileKind.for_path (name);
            if (kind != FileKind.MATHML && kind != FileKind.ODF && kind != FileKind.LATEX) {
                int dot = name.last_index_of (".");
                name = (dot > 0 ? name.substring (0, dot) : name) + ".mml";
            }
            save.begin (window, name);
        }

        private static async void save (FormulaWindow window, string name) {
            string dir;
            try {
                dir = DirUtils.make_tmp ("singularity-formula-XXXXXX");
            } catch (Error e) {
                window.add_toast (new Toast (e.message));
                return;
            }
            var source = GLib.File.new_for_path (Path.build_filename (dir, name));
            try {
                window.write_to (source.get_path ());
            } catch (Error e) {
                window.show_error (_("Could Not Save"), e.message);
            }
            CloudFile? cloud = null;
            if (source.query_exists ()) cloud = yield CloudFileDialog.save (window, source, name);
            FileUtils.remove (source.get_path ());
            DirUtils.remove (dir);
            if (cloud == null) return;
            window.adopt_path (cloud.local.get_path ());
            try {
                window.write_to (cloud.local.get_path ());
            } catch (Error e) {
            }
            window.add_toast (new Toast (_("Saved to %s").printf (account_name (cloud.local))));
        }

        public static void sync_back (Singularity.Widgets.Window window, GLib.File file) {
            CloudFile.sync_back.begin (file, null, (obj, res) => {
                try {
                    if (CloudFile.sync_back.end (res))
                        window.add_toast (new Toast (_("Saved to %s").printf (account_name (file))));
                } catch (Error e) {
                    window.add_toast (new Toast (_("Not saved to %s: %s").printf (account_name (file), e.message)));
                }
            });
        }

        private static string account_name (GLib.File file) {
            var cloud = CloudFile.for_local (file);
            var account = cloud != null ? Manager.get_default ().get_account (cloud.account_id) : null;
            return account != null ? account.display_name : _("Online Account");
        }
    }
}
