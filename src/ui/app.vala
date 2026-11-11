using Gtk;

namespace Singularity.Apps.Formula {

    public class FormulaApp : Singularity.Application {
        public GLib.Settings? settings;
        public History history;
        private static MathFont? font_cache;
        private static string font_family = "";
        private string? insert_output;
        private string? initial_latex;
        private string? initial_mathml;
        private bool initial_inline;

        public FormulaApp (bool unique) {
            Object (application_id: "dev.sinty.formula", flags: ApplicationFlags.HANDLES_OPEN | (unique ? 0 : ApplicationFlags.NON_UNIQUE));
            add_main_option ("new", 0, OptionFlags.NONE, OptionArg.NONE, _("Start a new formula"), null);
            add_main_option ("insert", 0, OptionFlags.NONE, OptionArg.FILENAME, _("Edit a formula for another app and write it to FILE"), "FILE");
            add_main_option ("latex", 0, OptionFlags.NONE, OptionArg.STRING, _("Start from this LaTeX formula"), "TEXT");
            add_main_option ("mathml", 0, OptionFlags.NONE, OptionArg.FILENAME, _("Start from the formula in this MathML, OMML or LaTeX file"), "FILE");
            add_main_option ("inline", 0, OptionFlags.NONE, OptionArg.NONE, _("Edit the formula as an inline equation"), null);
            var schema = SettingsSchemaSource.get_default ()?.lookup ("dev.sinty.formula", true);
            if (schema != null) settings = new GLib.Settings ("dev.sinty.formula");
            history = new History (settings);
            Symbols.autocorrect = Singularity.Equations.AutoCorrect.get_default ();
            if (settings != null) {
                font_family = settings.get_string ("math-font");
                settings.changed["math-font"].connect (() => {
                    font_family = settings.get_string ("math-font");
                    font_cache = null;
                    foreach (var w in get_windows ()) if (w is FormulaWindow) ((FormulaWindow) w).reload_font ();
                });
                settings.changed["font-size"].connect (() => {
                    foreach (var w in get_windows ()) if (w is FormulaWindow) ((FormulaWindow) w).apply_font_size (settings.get_int ("font-size"));
                });
            }
        }

        public static MathFont math_font () {
            if (font_cache == null) font_cache = MathFont.get_default (font_family != "" ? font_family : null);
            return font_cache;
        }

        protected override int handle_local_options (VariantDict options) {
            string? ins = null;
            string? lat = null;
            options.lookup ("insert", "^ay", out ins);
            options.lookup ("latex", "s", out lat);
            string? mml = null;
            options.lookup ("mathml", "^ay", out mml);
            if (ins != null) insert_output = ins;
            if (lat != null) initial_latex = lat;
            if (mml != null) initial_mathml = mml;
            if (options.contains ("inline")) initial_inline = true;
            if (!options.contains ("new") || insert_output != null) return -1;
            try {
                register (null);
            } catch (Error e) {
                warning ("formula: %s", e.message);
                return 1;
            }
            activate_action ("new", null);
            return get_is_remote () ? 0 : -1;
        }

        private uint collab_bus_id = 0;

        public override bool dbus_register (DBusConnection connection, string object_path) throws Error {
            if (!base.dbus_register (connection, object_path)) return false;
            collab_bus_id = connection.register_object ("/dev/sinty/formula/Collab", new FormulaCollabBus (this));
            return true;
        }

        public override void dbus_unregister (DBusConnection connection, string object_path) {
            if (collab_bus_id != 0) connection.unregister_object (collab_bus_id);
            collab_bus_id = 0;
            base.dbus_unregister (connection, object_path);
        }

        protected override void startup () {
            base.startup ();
            about_version = "0.1.0";
            about_license = _("GNU General Public License, version 3 only");
            var provider = new CssProvider ();
            provider.load_from_string (CSS);
            StyleContext.add_provider_for_display (Gdk.Display.get_default (), provider, STYLE_PROVIDER_PRIORITY_USER + 1);
            FormulaIntents.install (this);
            var new_action = new SimpleAction ("new", null);
            new_action.activate.connect (() => {
                var w = get_active_window () as FormulaWindow;
                if (w != null && w.doc == null) {
                    w.new_document ();
                } else {
                    var nw = new FormulaWindow (this);
                    nw.present ();
                    nw.new_document ();
                }
            });
            add_action (new_action);
            var open_action = new SimpleAction ("open", null);
            open_action.activate.connect (() => {
                var w = get_active_window () as FormulaWindow;
                if (w == null) {
                    w = new FormulaWindow (this);
                    w.present ();
                }
                choose_file (w);
            });
            add_action (open_action);
            var open_online = new SimpleAction ("open-online", null);
            open_online.activate.connect (() => {
                var w = get_active_window () as FormulaWindow;
                if (w == null) {
                    w = new FormulaWindow (this);
                    w.present ();
                }
                CloudActions.open.begin (w, (f) => open_file (f, w));
            });
            add_action (open_online);
            var quit = new SimpleAction ("quit", null);
            quit.activate.connect (() => {
                foreach (var w in get_windows ().copy ()) w.close ();
            });
            add_action (quit);
            var settings_action = new SimpleAction ("settings", null);
            settings_action.activate.connect (() => {
                try {
                    Singularity.Shell.ShellService shell = Bus.get_proxy_sync (BusType.SESSION, "dev.sinty.desktop", "/dev/sinty/Shell");
                    shell.open_app_settings ("dev.sinty.formula");
                } catch (Error e) {
                    warning ("Failed to open settings: %s", e.message);
                }
            });
            add_action (settings_action);
            build_menu ();
            string[,] accels = {
                { "app.quit", "<Control>q" }, { "app.new", "<Control>n" }, { "app.open", "<Control>o" }, { "app.settings", "<Control>comma" },
                { "win.save", "<Control>s" }, { "win.save-as", "<Control><Shift>s" }, { "win.close-doc", "<Control>w" },
                { "win.export-png", "<Control>e" }, { "win.export-pdf", "<Control><Shift>e" },
                { "win.undo", "<Control>z" }, { "win.cut", "<Control>x" }, { "win.copy", "<Control>c" }, { "win.paste", "<Control>v" },
                { "win.select-all", "<Control>a" }, { "win.copy-image", "<Control><Shift>c" }, { "win.copy-latex", "<Control><Alt>c" },
                { "win.focus-linear", "F6" }, { "win.focus-canvas", "<Shift>F6" },
                { "win.toggle-sidebar", "F9" }, { "win.search-symbols", "<Control><Shift>f" },
                { "win.zoom-in", "<Control>plus" }, { "win.zoom-out", "<Control>minus" }, { "win.zoom-reset", "<Control>0" },
                { "win.structure::frac", "<Control>f" }, { "win.structure::sfrac", "<Control>slash" },
                { "win.structure::sqrt", "<Control>r" }, { "win.structure::root", "<Control><Shift>r" },
                { "win.structure::sup", "<Control>h" }, { "win.structure::sub", "<Control>l" }, { "win.structure::subsup", "<Control>j" },
                { "win.structure::paren", "<Control>9" }, { "win.structure::bracket", "<Control>bracketleft" },
                { "win.structure::brace", "<Control>braceleft" }, { "win.structure::abs", "<Control>bar" },
                { "win.structure::sum", "<Control><Alt>s" }, { "win.structure::int", "<Control><Alt>i" },
                { "win.structure::pmatrix", "<Control><Alt>m" }, { "win.text-mode", "<Control><Shift>t" },
                { "win.variant::bold", "<Control>b" }, { "win.variant::italic", "<Control>i" }, { "win.variant::normal", "<Control><Shift>u" },
                { "win.new-line", "<Control>Return" }, { "win.number-equations", "<Control><Shift>n" },
                { "win.insert-confirm", "<Control><Shift>Return" }, { "win.print", "<Control>p" },
                { "win.toggle-linear", "<Control><Shift>l" }, { "win.ink", "<Control><Alt>w" }, { "win.read-aloud", "<Control><Alt>r" }
            };
            for (int i = 0; i < accels.length[0]; i++) set_accels_for_action (accels[i, 0], { accels[i, 1] });
            set_accels_for_action ("win.redo", { "<Control><Shift>z", "<Control>y" });
            set_accels_for_action ("win.copy-mathml", { "<Control><Alt>x" });
        }

        private static GLib.Menu section (string[,] items) {
            var m = new GLib.Menu ();
            for (int i = 0; i < items.length[0]; i++) m.append (items[i, 0], items[i, 1]);
            return m;
        }

        private static GLib.Menu submenu_section (string label, GLib.Menu sub) {
            var m = new GLib.Menu ();
            m.append_submenu (label, sub);
            return m;
        }

        private void build_menu () {
            var menu = new GLib.Menu ();

            var file = new GLib.Menu ();
            file.append_section (null, section ({ { _("New"), "app.new" }, { _("Open…"), "app.open" }, { _("Open from Online Account…"), "app.open-online" } }));
            file.append_section (null, section ({ { _("Save"), "win.save" }, { _("Save As…"), "win.save-as" }, { _("Save to Online Account…"), "win.save-online" } }));
            file.append_section (null, section ({ { _("Export as SVG…"), "win.export-svg" }, { _("Export as PNG…"), "win.export-png" }, { _("Export as PDF…"), "win.export-pdf" }, { _("Export as MathML…"), "win.export-mathml" }, { _("Export as LaTeX…"), "win.export-latex" }, { _("Export as Word Document…"), "win.export-docx" }, { _("Export as OpenDocument Formula…"), "win.export-odf" }, { _("Export as Office Math (OMML)…"), "win.export-omml" }, { _("Share…"), "win.share" } }));
            file.append_section (null, section ({ { _("Print…"), "win.print" } }));
            file.append_section (null, section ({ { _("Close Formula"), "win.close-doc" } }));
            file.append_section (null, section ({ { _("Close Window"), "win.close" }, { _("Quit"), "app.quit" } }));
            menu.append_submenu (_("File"), file);

            var edit = new GLib.Menu ();
            edit.append_section (null, section ({ { _("Undo"), "win.undo" }, { _("Redo"), "win.redo" } }));
            edit.append_section (null, section ({ { _("Cut"), "win.cut" }, { _("Copy"), "win.copy" }, { _("Paste"), "win.paste" } }));
            edit.append_section (null, submenu_section (_("Copy As"), section ({ { _("Image"), "win.copy-image" }, { _("MathML"), "win.copy-mathml" }, { _("LaTeX"), "win.copy-latex" }, { _("UnicodeMath"), "win.copy-unicodemath" }, { _("Image and MathML"), "win.copy-all" }, { _("Word Equation"), "win.copy-word" }, { _("Spoken Text"), "win.copy-speech" } })));
            edit.append_section (null, section ({ { _("Save as New Equation…"), "win.save-gallery" }, { _("Math AutoCorrect"), "win.show-autocorrect" } }));
            edit.append_section (null, section ({ { _("Select All"), "win.select-all" }, { _("Next Placeholder"), "win.next-slot" } }));
            edit.append_section (null, section ({ { _("Edit as Text"), "win.focus-linear" }, { _("Edit Visually"), "win.focus-canvas" }, { _("Find Symbol…"), "win.search-symbols" } }));
            edit.append_section (null, section ({ { _("Clear History…"), "win.clear-history" }, { _("Settings"), "app.settings" } }));
            menu.append_submenu (_("Edit"), edit);

            var view = new GLib.Menu ();
            view.append_section (null, section ({ { _("Symbols Panel"), "win.toggle-sidebar" }, { _("Text Editor"), "win.show-linear" } }));
            var syntax = new GLib.Menu ();
            syntax.append (_("LaTeX"), "win.syntax::latex");
            syntax.append (_("UnicodeMath"), "win.syntax::unicodemath");
            view.append_section (null, submenu_section (_("Text Syntax"), syntax));
            view.append_section (null, section ({ { _("Display Style"), "win.display-style" }, { _("Switch Linear and Professional"), "win.toggle-linear" } }));
            view.append_section (null, section ({ { _("Read Aloud"), "win.read-aloud" } }));
            view.append_section (null, section ({ { _("Zoom In"), "win.zoom-in" }, { _("Zoom Out"), "win.zoom-out" }, { _("Actual Size"), "win.zoom-reset" } }));
            menu.append_submenu (_("View"), view);

            var insert = new GLib.Menu ();
            insert.append_section (null, section ({
                { _("Fraction"), "win.structure::frac" }, { _("Skewed Fraction"), "win.structure::sfrac" }, { _("Binomial"), "win.structure::binom" },
                { _("Square Root"), "win.structure::sqrt" }, { _("Nth Root"), "win.structure::root" }
            }));
            insert.append_section (null, section ({
                { _("Superscript"), "win.structure::sup" }, { _("Subscript"), "win.structure::sub" }, { _("Subscript and Superscript"), "win.structure::subsup" }
            }));
            insert.append_section (null, submenu_section (_("Brackets"), section ({
                { _("Parentheses"), "win.structure::paren" }, { _("Square Brackets"), "win.structure::bracket" }, { _("Braces"), "win.structure::brace" },
                { _("Absolute Value"), "win.structure::abs" }, { _("Norm"), "win.structure::norm" }, { _("Angle Brackets"), "win.structure::angle" },
                { _("Floor"), "win.structure::floor" }, { _("Ceiling"), "win.structure::ceil" }, { _("Evaluation Bar"), "win.structure::eval" }
            })));
            insert.append_section (null, submenu_section (_("Large Operators"), section ({
                { _("Summation"), "win.structure::sum" }, { _("Product"), "win.structure::prod" }, { _("Integral"), "win.structure::int" },
                { _("Double Integral"), "win.structure::iint" }, { _("Contour Integral"), "win.structure::oint" }, { _("Union"), "win.structure::bigcup" },
                { _("Intersection"), "win.structure::bigcap" }, { _("Limit"), "win.structure::lim" }
            })));
            insert.append_section (null, submenu_section (_("Accents"), section ({
                { _("Hat"), "win.structure::hat" }, { _("Bar"), "win.structure::bar" }, { _("Vector"), "win.structure::vec" }, { _("Tilde"), "win.structure::tilde" },
                { _("Dot"), "win.structure::dot" }, { _("Double Dot"), "win.structure::ddot" }, { _("Wide Hat"), "win.structure::widehat" },
                { _("Overline"), "win.structure::overline" }, { _("Underline"), "win.structure::underline" },
                { _("Brace Above"), "win.structure::overbrace" }, { _("Brace Below"), "win.structure::underbrace" }, { _("Arrow Above"), "win.structure::overarrow" }
            })));
            insert.append_section (null, submenu_section (_("Matrix"), section ({
                { _("Matrix in Parentheses"), "win.structure::pmatrix" }, { _("Matrix in Brackets"), "win.structure::bmatrix" },
                { _("Determinant"), "win.structure::vmatrix" }, { _("3 by 3 Matrix"), "win.structure::matrix3" },
                { _("Cases"), "win.structure::cases" }, { _("Aligned Equations"), "win.structure::aligned" }
            })));
            insert.append_section (null, submenu_section (_("Space"), section ({
                { _("Thin Space"), "win.space::thinspace" }, { _("Medium Space"), "win.space::medspace" }, { _("Thick Space"), "win.space::thickspace" },
                { _("Quad"), "win.space::quad" }, { _("Double Quad"), "win.space::qquad" }
            })));
            insert.append_section (null, section ({ { _("Text"), "win.text-mode" }, { _("New Line"), "win.new-line" } }));
            insert.append_section (null, section ({ { _("Left Subscript and Superscript"), "win.structure::prescript" }, { _("Reference to Equation…"), "win.insert-reference" } }));
            insert.append_section (null, section ({ { _("Ink Equation…"), "win.ink" } }));
            menu.append_submenu (_("Insert"), insert);

            var format = new GLib.Menu ();
            format.append_section (null, submenu_section (_("Style"), section ({
                { _("Bold"), "win.variant::bold" }, { _("Italic"), "win.variant::italic" }, { _("Upright"), "win.variant::normal" },
                { _("Bold Italic"), "win.variant::bold-italic" }, { _("Double-Struck"), "win.variant::double-struck" }, { _("Script"), "win.variant::script" },
                { _("Fraktur"), "win.variant::fraktur" }, { _("Sans Serif"), "win.variant::sans-serif" }, { _("Monospace"), "win.variant::monospace" }
            })));
            format.append_section (null, submenu_section (_("Color"), section ({
                { _("Red"), "win.color::red" }, { _("Orange"), "win.color::orange" }, { _("Green"), "win.color::green" }, { _("Blue"), "win.color::blue" },
                { _("Purple"), "win.color::purple" }, { _("Gray"), "win.color::gray" }
            })));
            format.append_section (null, section ({ { _("Box"), "win.structure::boxed" }, { _("Cancel"), "win.structure::cancel" } }));
            format.append_section (null, submenu_section (_("Border Box"), section ({
                { _("Top Border"), "win.border::top" }, { _("Bottom Border"), "win.border::bottom" }, { _("Left Border"), "win.border::left" }, { _("Right Border"), "win.border::right" },
                { _("Horizontal Strike"), "win.border::horizontalstrike" }, { _("Vertical Strike"), "win.border::verticalstrike" },
                { _("Diagonal Strike Up"), "win.border::updiagonalstrike" }, { _("Diagonal Strike Down"), "win.border::downdiagonalstrike" }
            })));
            var justify = new GLib.Menu ();
            justify.append (_("Centered as Group"), "win.justify::center-group");
            justify.append (_("Centered"), "win.justify::center");
            justify.append (_("Left"), "win.justify::left");
            justify.append (_("Right"), "win.justify::right");
            format.append_section (null, submenu_section (_("Justification"), justify));
            format.append_section (null, section ({ { _("Break Long Equations"), "win.break-lines" } }));
            format.append_section (null, submenu_section (_("Matrix Rows and Columns"), section ({
                { _("Insert Row Above"), "win.table-row-above" }, { _("Insert Row Below"), "win.table-row-below" },
                { _("Insert Column Left"), "win.table-col-left" }, { _("Insert Column Right"), "win.table-col-right" },
                { _("Delete Row"), "win.table-delete-row" }, { _("Delete Column"), "win.table-delete-col" }
            })));
            format.append_section (null, section ({ { _("Number Equations"), "win.number-equations" }, { _("Numbering Options…"), "win.numbering-options" }, { _("Name This Line"), "win.name-line" } }));
            menu.append_submenu (_("Format"), format);

            set_menubar (menu);
        }

        public override void activate () {
            var w = get_active_window () as FormulaWindow;
            if (w == null) {
                w = new FormulaWindow (this);
                w.present ();
            } else {
                w.present ();
            }
            if (insert_output != null) {
                w.enable_insert_mode (insert_output);
                start_with_latex (w);
                insert_output = null;
            } else if (initial_latex != null || initial_mathml != null) {
                start_with_latex (w);
            }
        }

        private void start_with_latex (FormulaWindow w) {
            FormulaDoc d;
            try {
                if (initial_mathml != null) {
                    d = Formats.load (initial_mathml);
                    d.path = null;
                    d.modified = false;
                } else {
                    d = initial_latex != null ? FormulaDoc.parse_any (initial_latex) : new FormulaDoc ();
                }
            } catch (Error e) {
                d = new FormulaDoc ();
            }
            if (initial_inline) d.display = false;
            initial_latex = null;
            initial_mathml = null;
            w.load_document (d);
        }

        public override void open (File[] files, string hint) {
            foreach (var f in files) open_file (f, null);
        }

        public void open_file (File file, FormulaWindow? target) {
            string? path = file.get_path ();
            if (path == null) return;
            foreach (var w in get_windows ()) {
                var fw = w as FormulaWindow;
                if (fw != null && fw.doc != null && fw.doc.path == path) {
                    fw.present ();
                    return;
                }
            }
            FormulaWindow? win = target != null && target.is_empty () ? target : null;
            if (win == null) {
                foreach (var w in get_windows ()) {
                    var fw = w as FormulaWindow;
                    if (fw != null && fw.is_empty ()) win = fw;
                }
            }
            if (win == null) win = new FormulaWindow (this);
            win.present ();
            if (path.down ().has_suffix (".docx")) {
                try {
                    uint8[] data;
                    FileUtils.get_data (path, out data);
                    var eqs = WordFormat.equations_in_docx (data);
                    if (eqs.size > 1) {
                        win.choose_docx_equation (eqs, path);
                        RecentManager.get_default ().add_item (file.get_uri ());
                        return;
                    }
                } catch (Error e) {
                }
            }
            try {
                var d = Formats.load (path);
                win.load_document (d);
                RecentManager.get_default ().add_item (file.get_uri ());
            } catch (Error e) {
                win.show_error (_("Could Not Open"), _("\"%s\" could not be opened: %s").printf (file.get_basename (), e.message));
            }
        }

        public void choose_file (FormulaWindow parent) {
            var dialog = new FileDialog ();
            dialog.title = _("Open Formula");
            var filter = new FileFilter ();
            filter.name = _("Formulas");
            foreach (string s in new string[] { "mml", "mathml", "xml", "odf", "tex", "txt", "docx", "omml" }) filter.add_suffix (s);
            var filters = new GLib.ListStore (typeof (FileFilter));
            filters.append (filter);
            dialog.filters = filters;
            dialog.open.begin (parent, null, (obj, res) => {
                try {
                    var file = dialog.open.end (res);
                    if (file != null) open_file (file, parent);
                } catch (Error e) {
                }
            });
        }

        private const string CSS = """
.formula-canvas {
    color: @window_fg_color;
}

.formula-canvas-scroll {
    background: transparent;
}

.formula-linear {
    padding: 0 16px 16px 16px;
}

.formula-linear-frame {
    border-radius: 12px;
    border: 1px solid alpha(@window_fg_color, 0.12);
    background-color: alpha(@window_fg_color, 0.03);
}

.formula-linear-text,
.formula-linear-text text {
    background: transparent;
}

.formula-symbol {
    min-width: 34px;
    min-height: 34px;
    padding: 0;
    border-radius: 8px;
}

.formula-structure {
    min-width: 56px;
    min-height: 44px;
    padding: 2px;
    border-radius: 8px;
}

.formula-gallery-card {
    padding: 10px 8px;
    border-radius: 12px;
    background-color: alpha(@window_fg_color, 0.04);
}

.formula-gallery-card:hover {
    background-color: alpha(@window_fg_color, 0.08);
}

.formula-recent-row {
    border-radius: 10px;
    padding: 8px 10px;
}
""";
    }

    public static int main (string[] args) {
        Intl.setlocale (LocaleCategory.ALL, "");
        string locale_dir = "/usr/share/locale";
        try {
            string exe = FileUtils.read_link ("/proc/self/exe");
            locale_dir = Path.build_filename (Path.get_dirname (Path.get_dirname (exe)), "share", "locale");
        } catch (Error e) {
        }
        Intl.bindtextdomain ("singularity-formula", locale_dir);
        Intl.bind_textdomain_codeset ("singularity-formula", "UTF-8");
        Intl.textdomain ("singularity-formula");
        if (args.length >= 2 && args[1] == "--render") return Cli.render (args);
        bool unique = true;
        foreach (var a in args) if (a == "--insert" || a.has_prefix ("--insert=")) unique = false;
        return new FormulaApp (unique).run (args);
    }
}
