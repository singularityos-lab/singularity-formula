namespace Singularity.Apps.Formula {

    internal class FormulaIntents : Object {

        private static string text (Json.Object args, string key) {
            return args.has_member (key) ? args.get_string_member (key).strip () : "";
        }

        private static FormulaWindow window (FormulaApp app, bool need_doc) throws Error {
            FormulaWindow? w = app.get_active_window () as FormulaWindow;
            if (w == null) {
                foreach (var x in app.get_windows ()) {
                    if (x is FormulaWindow) {
                        w = (FormulaWindow) x;
                        break;
                    }
                }
            }
            if (w == null) {
                w = new FormulaWindow (app);
                w.present ();
            }
            if (need_doc && (w.doc == null || w.editor == null)) w.new_document ();
            return w;
        }

        private static FormulaWindow open_window (FormulaApp app) throws Error {
            var w = window (app, false);
            if (w.doc == null || w.editor == null) throw new IOError.NOT_FOUND ("no formula is open; use formula_set or formula_open");
            return w;
        }

        private static string path_arg (Json.Object args) throws Error {
            string p = text (args, "path");
            if (p == "") throw new IOError.INVALID_ARGUMENT ("give the file path");
            if (p.has_prefix ("~/")) return Path.build_filename (Environment.get_home_dir (), p.substring (2));
            if (!Path.is_absolute (p)) return Path.build_filename (Environment.get_home_dir (), p);
            return p;
        }

        private static void describe (Json.Builder b, FormulaDoc d) {
            b.set_member_name ("latex").add_string_value (d.to_latex ());
            b.set_member_name ("unicodemath").add_string_value (d.to_unicodemath ());
            b.set_member_name ("display").add_boolean_value (d.display);
            if (d.tag != null) b.set_member_name ("tag").add_string_value (d.tag);
            if (d.path != null) b.set_member_name ("file").add_string_value (d.path);
            b.set_member_name ("unsaved_changes").add_boolean_value (d.modified);
        }

        private static Json.Node state (FormulaWindow w, string? undo = null) {
            var b = new Json.Builder ();
            b.begin_object ();
            describe (b, w.doc);
            b.set_member_name ("can_undo").add_boolean_value (w.editor.can_undo);
            if (undo != null) b.set_member_name ("undo").add_string_value (undo);
            b.end_object ();
            return b.get_root ();
        }

        private static FormulaDoc parse (string t, string syntax) throws Error {
            if (t == "") throw new IOError.INVALID_ARGUMENT ("give the formula");
            switch (syntax) {
                case "latex": return FormulaDoc.parse_linear (t, LinearSyntax.LATEX);
                case "unicodemath": return FormulaDoc.parse_linear (t, LinearSyntax.UNICODEMATH);
                case "":
                case "mathml":
                    return FormulaDoc.parse_any (t);
                default:
                    throw new IOError.INVALID_ARGUMENT ("syntax is latex, unicodemath or mathml");
            }
        }

        private static string normalized (string latex) {
            return latex.replace (" ", "");
        }

        internal static void install (FormulaApp app) {
            var agent = app.agent;
            agent.add_intent ("formula_read", "The formula open in Formula, as LaTeX and UnicodeMath, and whether it has unsaved changes. Add mathml true for the MathML too.",
                "{\"type\":\"object\",\"properties\":{\"mathml\":{\"type\":\"boolean\"}}}", Singularity.AppIntentRisk.READ, (args) => {
                    var w = open_window (app);
                    var root = state (w);
                    if (args.has_member ("mathml") && args.get_boolean_member ("mathml")) root.get_object ().set_string_member ("mathml", w.doc.to_mathml ());
                    return root;
                });
            agent.add_intent ("formula_set", "Replace the whole formula in the Formula window with a new one, written in LaTeX, UnicodeMath or MathML. Undo with formula_undo or Ctrl+Z.",
                "{\"type\":\"object\",\"properties\":{\"formula\":{\"type\":\"string\"},\"syntax\":{\"type\":\"string\",\"enum\":[\"latex\",\"unicodemath\",\"mathml\"]}},\"required\":[\"formula\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var d = parse (text (args, "formula"), text (args, "syntax"));
                    var w = window (app, true);
                    w.editor.replace_root (d.root, d.tag, true);
                    w.present ();
                    if (normalized (w.doc.to_latex ()) != normalized (d.to_latex ())) throw new IOError.FAILED ("the formula in the window is not the one given");
                    return state (w, "formula_undo");
                });
            agent.add_intent ("formula_insert", "Insert a piece of formula (UnicodeMath or a symbol) where the cursor is in the Formula window.",
                "{\"type\":\"object\",\"properties\":{\"text\":{\"type\":\"string\"}},\"required\":[\"text\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    string t = text (args, "text");
                    if (t == "") throw new IOError.INVALID_ARGUMENT ("give what to insert");
                    var w = window (app, true);
                    string before = w.doc.to_latex ();
                    if (!w.editor.insert_replacement (t)) throw new IOError.INVALID_ARGUMENT ("%s could not be read as a formula", t);
                    if (w.doc.to_latex () == before) throw new IOError.FAILED ("nothing was inserted");
                    w.present ();
                    return state (w, "formula_undo");
                });
            agent.add_intent ("formula_undo", "Undo the last change to the formula.",
                "{\"type\":\"object\",\"properties\":{}}", Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = open_window (app);
                    if (!w.editor.can_undo) throw new IOError.NOT_FOUND ("there is nothing to undo");
                    w.editor.undo ();
                    return state (w, "formula_redo");
                });
            agent.add_intent ("formula_redo", "Redo the change that was just undone.",
                "{\"type\":\"object\",\"properties\":{}}", Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    var w = open_window (app);
                    if (!w.editor.can_redo) throw new IOError.NOT_FOUND ("there is nothing to redo");
                    w.editor.redo ();
                    return state (w, "formula_undo");
                });
            agent.add_intent ("formula_convert", "Convert a formula between LaTeX, UnicodeMath and MathML without touching the open one.",
                "{\"type\":\"object\",\"properties\":{\"formula\":{\"type\":\"string\"},\"syntax\":{\"type\":\"string\",\"enum\":[\"latex\",\"unicodemath\",\"mathml\"]}},\"required\":[\"formula\"]}",
                Singularity.AppIntentRisk.READ, (args) => {
                    var d = parse (text (args, "formula"), text (args, "syntax"));
                    var b = new Json.Builder ();
                    b.begin_object ();
                    b.set_member_name ("latex").add_string_value (d.to_latex ());
                    b.set_member_name ("unicodemath").add_string_value (d.to_unicodemath ());
                    b.set_member_name ("mathml").add_string_value (d.to_mathml (false, false));
                    b.end_object ();
                    return b.get_root ();
                });
            agent.add_intent ("formula_open", "Open a formula file (MathML, OpenDocument Formula, LaTeX, UnicodeMath text or the first equation of a Word document) in Formula.",
                "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}},\"required\":[\"path\"]}",
                Singularity.AppIntentRisk.UNDOABLE, (args) => {
                    string path = path_arg (args);
                    var w = window (app, false);
                    if (w.doc != null && w.doc.modified && !w.doc.is_empty ()) throw new IOError.BUSY ("the open formula has unsaved changes; save it with formula_save first");
                    string? before = w.doc != null ? w.doc.path : null;
                    var d = Formats.load (path);
                    w.load_document (d);
                    w.present ();
                    if (w.doc != d) throw new IOError.FAILED ("%s was not opened", path);
                    return state (w, before != null ? "formula_open with path " + before : "nothing to undo; the previous formula was empty or saved");
                });
            agent.add_intent ("formula_save", "Save the formula to a file. The extension picks the format: .mml, .odf, .tex, .txt (UnicodeMath) or .docx keep it editable; .svg, .png and .pdf export a picture. An existing file is replaced.",
                "{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\"}},\"required\":[\"path\"]}",
                Singularity.AppIntentRisk.IRREVERSIBLE, (args) => {
                    var w = open_window (app);
                    string path = path_arg (args);
                    var kind = FileKind.for_path (path);
                    bool editable = kind == FileKind.MATHML || kind == FileKind.ODF || kind == FileKind.LATEX || kind == FileKind.UNICODEMATH || kind == FileKind.DOCX;
                    bool existed = FileUtils.test (path, FileTest.EXISTS);
                    DirUtils.create_with_parents (Path.get_dirname (path), 0755);
                    w.write_to (path);
                    if (!FileUtils.test (path, FileTest.EXISTS)) throw new IOError.FAILED ("%s was not written", path);
                    if (editable) {
                        var again = Formats.load (path);
                        if (normalized (again.to_latex ()) != normalized (w.doc.to_latex ())) throw new IOError.FAILED ("%s does not read back as the same formula", path);
                        w.adopt_path (path);
                    }
                    var b = new Json.Builder ();
                    b.begin_object ();
                    b.set_member_name ("saved").add_string_value (path);
                    b.set_member_name ("format").add_string_value (kind.extension ());
                    b.set_member_name ("replaced_existing").add_boolean_value (existed);
                    b.set_member_name ("bytes").add_int_value (File.new_for_path (path).query_info (FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE).get_size ());
                    b.end_object ();
                    return b.get_root ();
                });
        }
    }
}
