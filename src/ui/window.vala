using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Formula {

    public class FormulaWindow : Singularity.Widgets.Window {
        public FormulaDoc? doc { get; private set; }
        public Editor? editor { get; private set; }
        public string? insert_target;
        private FormulaApp app;
        private Stack content_stack;
        private Box editor_page;
        private FormulaCanvas? canvas;
        private ScrolledWindow canvas_scroll;
        private TextView linear;
        private Box linear_panel;
        private Banner parse_banner;
        private TextTag error_tag;
        private bool linear_sync;
        private uint parse_id;
        private LinearSyntax syntax = LinearSyntax.LATEX;
        private BubbleSwitcher syntax_switch;
        private AppSidebar sidebar;
        private Stack side_stack;
        private PaletteView palette;
        private GalleryView side_gallery;
        private Box history_box;
        private SearchBubble side_search;
        private Box recent_list;
        private Box recent_wrap;
        private Gee.ArrayList<Widget> doc_bubbles = new Gee.ArrayList<Widget> ();
        private Button undo_bubble;
        private Button redo_bubble;
        private Button share_bubble;
        private Button? insert_bubble;
        private bool close_confirmed;
        private string[] doc_actions = {};
        private InkPage? ink_page;
        private AutoCorrectView? autocorrect_view;
        private Subprocess? speaker;
        private BubbleSwitcher side_switcher;

        public FormulaWindow (FormulaApp app) {
            Object (application: app);
            this.app = app;
            set_default_size (1180, 780);
            set_title (_("Formula"));
            var s = app.settings;
            if (s != null) syntax = s.get_string ("linear-syntax") == "unicodemath" ? LinearSyntax.UNICODEMATH : LinearSyntax.LATEX;

            content_stack = new Stack ();
            content_stack.transition_type = StackTransitionType.CROSSFADE;
            content_stack.add_named (build_welcome (), "welcome");
            editor_page = new Box (Orientation.VERTICAL, 0);
            editor_page.add_css_class ("formula-page");
            content_stack.add_named (editor_page, "editor");
            ink_page = new InkPage ();
            ink_page.insert_requested.connect ((latex) => finish_ink (latex));
            ink_page.cancelled.connect (() => leave_ink ());
            content_stack.add_named (ink_page, "ink");
            set_content (content_stack);
            build_sidebar ();
            build_bubbles ();
            install_actions ();
            close_request.connect (on_close_request);
            app.history.changed.connect (fill_history);

            var drop = new DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
            drop.drop.connect ((value, x, y) => {
                var list = (Gdk.FileList) value.get_boxed ();
                foreach (var file in list.get_files ()) {
                    app.open_file (file, this);
                    break;
                }
                return true;
            });
            ((Widget) this).add_controller (drop);
            show_welcome ();
        }

        public bool is_empty () {
            return doc == null || (doc.is_empty () && doc.path == null && !doc.modified);
        }

        private Widget build_welcome () {
            var wp = new WelcomePage ();
            wp.app_icon_name = "dev.sinty.formula";
            wp.title = _("Formula");
            wp.subtitle = _("Write equations for documents, slides and the web");
            wp.add_action ("x-office-formula", _("New Formula"), _("Start from an empty equation"), () => new_document ());
            wp.add_action ("folder-open", _("Open"), _("MathML, OpenDocument formula and LaTeX files"), () => app.choose_file (this));
            wp.add_action ("edit-paste", _("Paste a Formula"), _("From LaTeX, MathML or UnicodeMath on the clipboard"), () => paste_as_new ());
            wp.add_action ("input-tablet", _("Write by Hand"), _("Draw the equation and it is recognized as you write"), () => open_ink ());
            var extra = new Box (Orientation.VERTICAL, 12);
            recent_wrap = new Box (Orientation.VERTICAL, 12);
            var recent_title = new Label (_("Recent"));
            recent_title.add_css_class ("title-2");
            recent_title.halign = Align.START;
            recent_list = new Box (Orientation.VERTICAL, 0);
            recent_list.add_css_class ("formula-recent-list");
            recent_wrap.append (recent_title);
            recent_wrap.append (recent_list);
            extra.append (recent_wrap);
            var gallery_title = new Label (_("Gallery"));
            gallery_title.add_css_class ("title-2");
            gallery_title.halign = Align.START;
            extra.append (gallery_title);
            var gallery = new GalleryView (false, 12);
            gallery.chosen.connect ((item) => open_gallery_item (item));
            extra.append (gallery);
            wp.set_extra_widget (extra);
            return wp;
        }

        private void open_gallery_item (GalleryItem item) {
            try {
                var d = FormulaDoc.parse_linear (item.latex, LinearSyntax.LATEX);
                load_document (d);
            } catch (ParseError e) {
                show_error (_("Could Not Open"), e.message);
            }
        }

        private static bool is_formula_file (string uri) {
            string u = uri.down ();
            return u.has_suffix (".mml") || u.has_suffix (".odf") || u.has_suffix (".mathml") || u.has_suffix (".tex") || u.has_suffix (".docx") || u.has_suffix (".omml");
        }

        private void fill_recent () {
            Widget? child;
            while ((child = recent_list.get_first_child ()) != null) recent_list.remove (child);
            var items = new Gee.ArrayList<RecentInfo> ();
            foreach (var info in RecentManager.get_default ().get_items ()) {
                if (is_formula_file (info.get_uri ()) && info.exists ()) items.add (info);
            }
            items.sort ((a, b) => b.get_modified ().compare (a.get_modified ()));
            int count = 0;
            foreach (var info in items) {
                if (count++ >= 6) break;
                var file = File.new_for_uri (info.get_uri ());
                var row = new Button ();
                row.add_css_class ("flat");
                row.add_css_class ("formula-recent-row");
                var box = new Box (Orientation.HORIZONTAL, 12);
                var icon = new Image.from_icon_name ("x-office-formula");
                icon.pixel_size = 24;
                box.append (icon);
                var texts = new Box (Orientation.VERTICAL, 2);
                texts.hexpand = true;
                var name = new Label (file.get_basename ());
                name.halign = Align.START;
                name.ellipsize = Pango.EllipsizeMode.MIDDLE;
                name.add_css_class ("heading");
                var parent = file.get_parent ();
                string p = parent != null ? (parent.get_path () ?? "") : "";
                string home = Environment.get_home_dir ();
                if (p.has_prefix (home)) p = "~" + p.substring (home.length);
                var path = new Label (p);
                path.halign = Align.START;
                path.ellipsize = Pango.EllipsizeMode.START;
                path.add_css_class ("caption");
                path.add_css_class ("dim-label");
                texts.append (name);
                texts.append (path);
                box.append (texts);
                row.child = box;
                row.clicked.connect (() => app.open_file (file, this));
                recent_list.append (row);
            }
            recent_wrap.visible = count > 0;
        }

        private void build_sidebar () {
            sidebar = new AppSidebar (290);
            side_switcher = new BubbleSwitcher ();
            var switcher = side_switcher;
            switcher.add_option ("symbols", _("Symbols"));
            switcher.add_option ("gallery", _("Gallery"));
            switcher.add_option ("history", _("History"));
            switcher.add_option ("autocorrect", _("AutoCorrect"));
            sidebar.add_bubble_widget (switcher);
            side_search = sidebar.add_bubble_search (_("Search"), (t) => filter_side (t));
            side_stack = new Stack ();
            side_stack.transition_type = StackTransitionType.CROSSFADE;
            side_stack.vhomogeneous = false;
            palette = new PaletteView ();
            palette.symbol_chosen.connect ((s) => insert_symbol (s));
            palette.structure_chosen.connect ((id) => run_structure (id));
            palette.clear_search.connect (() => side_search.clear ());
            side_stack.add_named (palette, "symbols");
            side_gallery = new GalleryView (true);
            side_gallery.margin_start = 6;
            side_gallery.margin_end = 6;
            side_gallery.chosen.connect ((item) => insert_latex (item.latex));
            side_stack.add_named (side_gallery, "gallery");
            history_box = new Box (Orientation.VERTICAL, 4);
            history_box.margin_start = 6;
            history_box.margin_end = 6;
            side_stack.add_named (history_box, "history");
            autocorrect_view = new AutoCorrectView (Singularity.Equations.AutoCorrect.get_default ());
            side_stack.add_named (autocorrect_view, "autocorrect");
            switcher.selected.connect ((name) => {
                side_stack.visible_child_name = name;
                filter_side (side_search.text);
            });
            sidebar.box.append (side_stack);
            set_sidebar (sidebar);
            fill_history ();
        }

        private void filter_side (string text) {
            switch (side_stack.visible_child_name) {
                case "symbols":
                    palette.filter (text);
                    break;
                case "gallery":
                    side_gallery.filter (text);
                    break;
                case "autocorrect":
                    autocorrect_view.filter (text);
                    break;
                default:
                    fill_history ();
                    break;
            }
        }

        private void fill_history () {
            Widget? child;
            while ((child = history_box.get_first_child ()) != null) history_box.remove (child);
            string q = side_search != null ? side_search.text.strip ().down () : "";
            int shown = 0;
            foreach (var latex in app.history.items) {
                if (q != "" && !latex.down ().contains (q)) continue;
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("formula-gallery-card");
                var prev = new FormulaPreview.latex (latex, 13, false, 250);
                prev.can_target = false;
                b.child = prev;
                b.tooltip_text = latex;
                string l = latex;
                b.clicked.connect (() => insert_latex (l));
                var rc = new GestureClick ();
                rc.button = Gdk.BUTTON_SECONDARY;
                rc.pressed.connect ((n, x, y) => {
                    var menu = new ContextMenu (b);
                    menu.add_item (_("Insert"), "list-add-symbolic", () => insert_latex (l));
                    menu.add_item (_("Open as New Formula"), "document-new-symbolic", () => {
                        try {
                            load_document (FormulaDoc.parse_linear (l, LinearSyntax.LATEX));
                        } catch (ParseError e) {
                        }
                    });
                    menu.add_separator ();
                    menu.add_item (_("Remove from History"), "user-trash-symbolic", () => app.history.remove (l));
                    menu.closed.connect (() => Idle.add (() => {
                        menu.unparent ();
                        return Source.REMOVE;
                    }));
                    menu.popup ();
                });
                b.add_controller (rc);
                history_box.append (b);
                shown++;
            }
            if (shown == 0) {
                if (q != "") {
                    var st = new StatusPage ();
                    st.compact = true;
                    st.icon_name = "edit-find";
                    st.title = _("No Matches");
                    st.description = _("No formula in the history matches your search.");
                    var clear = new Button.with_label (_("Clear Search"));
                    clear.add_css_class ("pill");
                    clear.halign = Align.CENTER;
                    clear.clicked.connect (() => side_search.clear ());
                    st.child = clear;
                    history_box.append (st);
                } else {
                    var wp = new WelcomePage ();
                    wp.is_section = true;
                    wp.embedded = true;
                    wp.app_icon_name = "document-open-recent";
                    wp.title = _("History");
                    wp.subtitle = _("Formulas you copy, export or insert are kept here.");
                    wp.add_action ("x-office-formula", _("Browse the Gallery"), _("Common formulas ready to insert"), () => {
                        side_stack.visible_child_name = "gallery";
                    });
                    history_box.append (wp);
                }
            } else {
                var clear = new Button.with_label (_("Clear History"));
                clear.add_css_class ("pill");
                clear.halign = Align.CENTER;
                clear.margin_top = 8;
                clear.clicked.connect (() => confirm_clear_history ());
                history_box.append (clear);
            }
        }

        private void confirm_clear_history () {
            var dlg = new ConfirmDialog (app, _("Clear the History?"), null,
                _("The formulas you copied, exported and inserted will be removed from the list."),
                _("Clear"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.transient_for = this;
            dlg.response.connect ((r) => {
                if (r == ConfirmDialog.Response.PRIMARY) app.history.clear ();
            });
            dlg.present ();
        }

        private Widget track (Widget w) {
            doc_bubbles.add (w);
            return w;
        }

        private void anchor_menu (ContextMenu menu, Widget bubble) {
            Graphene.Rect bounds;
            if (bubble.compute_bounds (content_stack, out bounds)) {
                var rect = Gdk.Rectangle ();
                rect.x = (int) bounds.origin.x;
                rect.y = (int) bounds.origin.y;
                rect.width = (int) bounds.size.width;
                rect.height = (int) bounds.size.height;
                menu.pointing_to = rect;
            }
            menu.position = PositionType.BOTTOM;
            menu.closed.connect (() => Idle.add (() => {
                menu.unparent ();
                return Source.REMOVE;
            }));
            menu.popup ();
        }

        private void build_bubbles () {
            track (add_bubble_icon ("go-previous-symbolic", _("Close Formula (Ctrl+W)"), () => close_document ()));
            track (add_bubble_icon ("sidebar-show-symbolic", _("Symbols (F9)"), () => set_sidebar_visible (!get_sidebar_visible ())));
            var save = add_bubble_icon ("document-save-symbolic", _("Save and Export"), () => { });
            save.clicked.connect (() => {
                var menu = new ContextMenu (content_stack);
                menu.add_item (_("Save"), "document-save-symbolic", () => run ("save"));
                menu.add_item (_("Save As"), "document-save-as-symbolic", () => run ("save-as"));
                menu.add_item (_("Save to Online Account"), "folder-remote-symbolic", () => run ("save-online"));
                menu.add_separator ();
                menu.add_item (_("Export as SVG"), "image-x-generic-symbolic", () => run ("export-svg"));
                menu.add_item (_("Export as PNG"), "image-x-generic-symbolic", () => run ("export-png"));
                menu.add_item (_("Export as PDF"), "x-office-document-symbolic", () => run ("export-pdf"));
                menu.add_item (_("Export as MathML"), "text-x-generic-symbolic", () => run ("export-mathml"));
                menu.add_item (_("Export as LaTeX"), "text-x-generic-symbolic", () => run ("export-latex"));
                menu.add_item (_("Export as Word Document"), "x-office-document-symbolic", () => run ("export-docx"));
                menu.add_item (_("Export as OpenDocument Formula"), "x-office-document-symbolic", () => run ("export-odf"));
                menu.add_item (_("Export as Office Math (OMML)"), "text-x-generic-symbolic", () => run ("export-omml"));
                menu.add_separator ();
                menu.add_item (_("Print"), "document-print-symbolic", () => run ("print"));
                anchor_menu (menu, save);
            });
            track (save);
            share_bubble = add_bubble_icon ("singularity-share-symbolic", _("Share"), () => run ("share"));
            track (share_bubble);
            undo_bubble = add_bubble_icon ("edit-undo-symbolic", _("Undo (Ctrl+Z)"), () => run ("undo"));
            track (undo_bubble);
            redo_bubble = add_bubble_icon ("edit-redo-symbolic", _("Redo (Ctrl+Shift+Z)"), () => run ("redo"));
            track (redo_bubble);
            var copy = add_bubble_icon ("edit-copy-symbolic", _("Copy"), () => { });
            copy.clicked.connect (() => {
                var menu = new ContextMenu (content_stack);
                menu.add_item (_("Copy for Documents"), "edit-copy-symbolic", () => run ("copy-all"));
                menu.add_item (_("Copy as Image"), "image-x-generic-symbolic", () => run ("copy-image"));
                menu.add_item (_("Copy as MathML"), "text-x-generic-symbolic", () => run ("copy-mathml"));
                menu.add_item (_("Copy as LaTeX"), "text-x-generic-symbolic", () => run ("copy-latex"));
                menu.add_item (_("Copy as UnicodeMath"), "text-x-generic-symbolic", () => run ("copy-unicodemath"));
                anchor_menu (menu, copy);
            });
            track (copy);
            syntax_switch = new BubbleSwitcher ();
            syntax_switch.add_option ("latex", _("LaTeX"));
            syntax_switch.add_option ("unicodemath", _("UnicodeMath"));
            syntax_switch.set_active (syntax == LinearSyntax.LATEX ? "latex" : "unicodemath");
            syntax_switch.selected.connect ((name) => {
                var a = lookup_action ("syntax") as SimpleAction;
                if (a != null) a.change_state (new Variant.string (name));
            });
            add_bubble_widget (syntax_switch);
            track (syntax_switch);
        }

        public void enable_insert_mode (string target) {
            insert_target = target;
            if (insert_bubble == null) {
                insert_bubble = add_bubble_suggested (_("Insert"), () => run ("insert-confirm"));
                track (insert_bubble);
            }
            insert_bubble.visible = content_stack.visible_child_name == "editor";
        }

        private void build_editor_page () {
            Widget? child;
            while ((child = editor_page.get_first_child ()) != null) editor_page.remove (child);
            canvas = new FormulaCanvas (editor);
            if (app.settings != null) canvas.base_size = app.settings.get_int ("font-size");
            canvas.context_menu.connect (show_canvas_menu);
            canvas_scroll = new ScrolledWindow ();
            canvas_scroll.child = canvas;
            canvas_scroll.hexpand = true;
            canvas_scroll.vexpand = true;
            canvas_scroll.add_css_class ("formula-canvas-scroll");
            apply_view_edge (canvas_scroll);
            editor_page.append (canvas_scroll);

            linear_panel = new Box (Orientation.VERTICAL, 6);
            linear_panel.add_css_class ("formula-linear");
            parse_banner = new Banner ("", BannerStyle.ERROR);
            parse_banner.icon_name = "dialog-warning-symbolic";
            parse_banner.visible = false;
            linear_panel.append (parse_banner);
            var frame = new ScrolledWindow ();
            frame.add_css_class ("formula-linear-frame");
            frame.vscrollbar_policy = PolicyType.AUTOMATIC;
            frame.hscrollbar_policy = PolicyType.NEVER;
            frame.min_content_height = 64;
            frame.max_content_height = 140;
            frame.propagate_natural_height = true;
            linear = new TextView ();
            linear.add_css_class ("formula-linear-text");
            linear.wrap_mode = WrapMode.WORD_CHAR;
            linear.monospace = true;
            linear.top_margin = 10;
            linear.bottom_margin = 10;
            linear.left_margin = 12;
            linear.right_margin = 12;
            linear.input_hints = InputHints.NO_SPELLCHECK | InputHints.NO_EMOJI;
            linear.accepts_tab = false;
            error_tag = linear.buffer.create_tag ("error", "underline", Pango.Underline.ERROR, null);
            linear.buffer.changed.connect (on_linear_changed);
            frame.child = linear;
            linear_panel.append (frame);
            bool show_linear = app.settings == null || app.settings.get_boolean ("show-linear");
            linear_panel.visible = show_linear;
            editor_page.append (linear_panel);
        }

        private void on_linear_changed () {
            if (linear_sync) return;
            if (parse_id != 0) Source.remove (parse_id);
            parse_id = Timeout.add (280, () => {
                parse_id = 0;
                parse_linear ();
                return Source.REMOVE;
            });
        }

        private void parse_linear () {
            if (editor == null) return;
            string text = linear.buffer.text;
            TextIter s, e;
            linear.buffer.get_bounds (out s, out e);
            linear.buffer.remove_tag (error_tag, s, e);
            try {
                var res = syntax == LinearSyntax.LATEX ? LatexParser.parse (text) : UnicodeMath.parse_result (text);
                parse_banner.visible = false;
                linear_sync = true;
                editor.replace_root (res.root, res.tag);
                linear_sync = false;
                update_title ();
            } catch (ParseError err) {
                int pos = LatexParser.error_position (err);
                parse_banner.title = _("Column %d: %s").printf (int.max (1, pos + 1), LatexParser.error_message (err));
                parse_banner.visible = true;
                if (pos >= 0) {
                    TextIter a, b;
                    int chars = text.substring (0, int.min (pos, text.length)).char_count ();
                    linear.buffer.get_iter_at_offset (out a, chars);
                    b = a;
                    if (!b.forward_char ()) a.backward_char ();
                    linear.buffer.apply_tag (error_tag, a, b);
                }
            }
        }

        private void sync_linear () {
            if (doc == null || linear == null || linear_sync) return;
            if (linear.has_focus) return;
            linear_sync = true;
            linear.buffer.text = doc.to_linear (syntax);
            TextIter s, e;
            linear.buffer.get_bounds (out s, out e);
            linear.buffer.remove_tag (error_tag, s, e);
            parse_banner.visible = false;
            linear_sync = false;
        }

        private void show_canvas_menu (double x, double y) {
            var menu = new ContextMenu (canvas);
            var rect = Gdk.Rectangle ();
            rect.x = (int) x;
            rect.y = (int) y;
            rect.width = 1;
            rect.height = 1;
            menu.pointing_to = rect;
            if (editor.has_selection) {
                menu.add_item (_("Cut"), "edit-cut-symbolic", () => run ("cut"));
                menu.add_item (_("Copy"), "edit-copy-symbolic", () => run ("copy"));
            }
            menu.add_item (_("Paste"), "edit-paste-symbolic", () => run ("paste"));
            var copy_as = menu.add_submenu (_("Copy As"), "edit-copy-symbolic");
            copy_as.add_item (_("Image"), "image-x-generic-symbolic", () => run ("copy-image"));
            copy_as.add_item (_("MathML"), "text-x-generic-symbolic", () => run ("copy-mathml"));
            copy_as.add_item (_("LaTeX"), "text-x-generic-symbolic", () => run ("copy-latex"));
            copy_as.add_item (_("Word Equation"), "x-office-document-symbolic", () => run ("copy-word"));
            copy_as.add_item (_("Spoken Text"), "audio-speakers-symbolic", () => run ("copy-speech"));
            menu.add_separator ();
            menu.add_item (editor.in_linear () ? _("Show as Professional") : (editor.has_selection ? _("Show Selection as Linear") : _("Show as Linear")), "format-text-plaintext-symbolic", () => run ("toggle-linear"));
            var eq = menu.add_submenu (_("Equation"), "x-office-formula-symbolic");
            eq.add_item (_("Save as New Equation"), "starred-symbolic", () => run ("save-gallery"));
            eq.add_item (_("Read Aloud"), "audio-speakers-symbolic", () => run ("read-aloud"));
            eq.add_item (_("Name This Line"), "bookmark-new-symbolic", () => run ("name-line"));
            eq.add_item (_("Insert Reference"), "insert-link-symbolic", () => run ("insert-reference"));
            eq.add_item (_("Numbering Options"), "view-list-ordered-symbolic", () => run ("numbering-options"));
            var enc = editor.current_enclose ();
            if (enc != null) {
                var sub = menu.add_submenu (_("Border"), "view-grid-symbolic");
                string[] notes = { "top", "bottom", "left", "right", "horizontalstrike", "verticalstrike", "updiagonalstrike", "downdiagonalstrike" };
                string[] shown = { _("Top Border"), _("Bottom Border"), _("Left Border"), _("Right Border"), _("Horizontal Strike"), _("Vertical Strike"), _("Diagonal Strike Up"), _("Diagonal Strike Down") };
                for (int i = 0; i < notes.length; i++) {
                    string note = notes[i];
                    bool on = Editor.has_note (enc, note);
                    sub.add_item ((on ? _("Hide %s") : _("Show %s")).printf (shown[i]), on ? "object-select-symbolic" : null, () => {
                        editor.toggle_enclose_note (note);
                    });
                }
            }
            if (editor.in_table ()) {
                var tm = menu.add_submenu (_("Rows and Columns"), "view-grid-symbolic");
                tm.add_item (_("Insert Row Below"), "list-add-symbolic", () => run ("table-row-below"));
                tm.add_item (_("Insert Column Right"), "list-add-symbolic", () => run ("table-col-right"));
                tm.add_item (_("Delete Row"), "list-remove-symbolic", () => run ("table-delete-row"));
                tm.add_item (_("Delete Column"), "list-remove-symbolic", () => run ("table-delete-col"));
                var tb = editor.table_at_caret ();
                if (tb != null && tb.kind != TableKind.ALIGN && tb.kind != TableKind.GATHER && tb.kind != TableKind.CASES) {
                    tm.add_item (_("Align Column Left"), "format-justify-left-symbolic", () => editor.table_align_column ('l'));
                    tm.add_item (_("Center Column"), "format-justify-center-symbolic", () => editor.table_align_column ('c'));
                    tm.add_item (_("Align Column Right"), "format-justify-right-symbolic", () => editor.table_align_column ('r'));
                    tm.add_item (_("Matrix Spacing"), "view-grid-symbolic", () => matrix_spacing ());
                }
            }
            menu.add_separator ();
            menu.add_item (_("Select All"), "edit-select-all-symbolic", () => run ("select-all"));
            menu.closed.connect (() => Idle.add (() => {
                menu.unparent ();
                return Source.REMOVE;
            }));
            menu.popup ();
        }

        private void show_welcome () {
            content_stack.visible_child_name = "welcome";
            foreach (var w in doc_bubbles) w.visible = false;
            set_sidebar_visible (false);
            fill_recent ();
            set_title (_("Formula"));
            sync_actions ();
        }

        public void new_document () {
            load_document (new FormulaDoc ());
        }

        public void load_document (FormulaDoc d) {
            doc = d;
            if (app.settings != null && d.path == null && !d.numbered) d.numbered = app.settings.get_boolean ("number-equations");
            if (app.settings != null && d.path == null && d.is_empty ()) {
                d.justification = Singularity.Equations.Justification.from_mathml (app.settings.get_string ("justification"));
                d.number_style = Singularity.Equations.NumberStyle.parse (app.settings.get_string ("number-style"));
            }
            if (editor == null) {
                editor = new Editor (d);
                editor.changed.connect (on_edit);
                editor.moved.connect (sync_actions);
            } else {
                editor.reset (d);
            }
            doc.changed.connect (update_title);
            build_editor_page ();
            content_stack.visible_child_name = "editor";
            foreach (var w in doc_bubbles) w.visible = true;
            if (insert_bubble != null) insert_bubble.visible = insert_target != null;
            set_sidebar_visible (app.settings == null || app.settings.get_boolean ("show-symbols"));
            sync_linear ();
            update_title ();
            sync_actions ();
            update_state_actions ();
            canvas.grab_focus ();
        }

        private void on_edit () {
            sync_linear ();
            update_title ();
            sync_actions ();
        }

        private void update_title () {
            if (doc == null) return;
            string name = doc.path != null ? Path.get_basename (doc.path) : _("Untitled Formula");
            set_title ((doc.modified ? "* " : "") + name);
            sync_share ();
            if (undo_bubble != null && editor != null) {
                undo_bubble.sensitive = editor.can_undo;
                redo_bubble.sensitive = editor.can_redo;
            }
        }

        public void close_document () {
            if (doc == null) {
                show_welcome ();
                return;
            }
            confirm_discard (() => {
                doc = null;
                canvas = null;
                Widget? child;
                while ((child = editor_page.get_first_child ()) != null) editor_page.remove (child);
                show_welcome ();
            });
        }

        public delegate void ActionFunc ();

        private void confirm_discard (owned ActionFunc then) {
            if (doc == null || !doc.modified || doc.is_empty ()) {
                then ();
                return;
            }
            var dlg = new ConfirmDialog (app, _("Save Changes?"), "dialog-warning",
                _("Your changes will be lost if you do not save them."),
                _("Discard"), ConfirmDialog.ActionStyle.DESTRUCTIVE);
            dlg.set_secondary (_("Save"), ConfirmDialog.ActionStyle.SUGGESTED);
            dlg.transient_for = this;
            dlg.response.connect ((r) => {
                if (r == ConfirmDialog.Response.CANCEL) return;
                if (r == ConfirmDialog.Response.SECONDARY) {
                    save.begin (false, (obj, res) => {
                        if (save.end (res)) then ();
                    });
                    return;
                }
                then ();
            });
            dlg.present ();
        }

        private bool on_close_request () {
            if (close_confirmed || doc == null || !doc.modified || doc.is_empty () || insert_target != null) return false;
            confirm_discard (() => {
                close_confirmed = true;
                close ();
            });
            return true;
        }

        private MathFont font () {
            return FormulaApp.math_font ();
        }

        private double export_size () {
            return app.settings != null ? app.settings.get_int ("font-size") : 36;
        }

        public async bool save (bool save_as) {
            if (doc == null) return false;
            string? target = save_as ? null : doc.path;
            if (target != null) {
                var k = FileKind.for_path (target);
                if (k != FileKind.MATHML && k != FileKind.ODF && k != FileKind.LATEX && k != FileKind.UNICODEMATH && k != FileKind.DOCX) target = null;
            }
            if (target == null) {
                var dialog = new FileDialog ();
                dialog.title = _("Save Formula");
                string base_name = doc.path != null ? Path.get_basename (doc.path) : _("Formula") + ".mml";
                dialog.initial_name = base_name;
                var filters = new GLib.ListStore (typeof (FileFilter));
                filters.append (filter (_("MathML (.mml)"), { "mml", "mathml" }));
                filters.append (filter (_("OpenDocument Formula (.odf)"), { "odf" }));
                filters.append (filter (_("LaTeX (.tex)"), { "tex" }));
                filters.append (filter (_("UnicodeMath Text (.txt)"), { "txt" }));
                filters.append (filter (_("Word Document (.docx)"), { "docx" }));
                dialog.filters = filters;
                try {
                    var file = yield dialog.save (this, null);
                    if (file == null) return false;
                    target = file.get_path ();
                    string low = target.down ();
                    if (!low.has_suffix (".mml") && !low.has_suffix (".odf") && !low.has_suffix (".tex") && !low.has_suffix (".txt") && !low.has_suffix (".mathml") && !low.has_suffix (".docx")) target += ".mml";
                } catch (Error e) {
                    return false;
                }
            }
            try {
                Formats.save (doc, target, font (), export_size ());
                doc.path = target;
                doc.modified = false;
                RecentManager.get_default ().add_item (File.new_for_path (target).get_uri ());
                app.history.add (doc.to_latex ());
                CloudActions.sync_back (this, File.new_for_path (target));
                update_title ();
                return true;
            } catch (Error e) {
                show_error (_("Could Not Save"), e.message);
                return false;
            }
        }

        public void write_to (string path) throws Error {
            Formats.save (doc, path, font (), export_size ());
        }

        public void adopt_path (string path) {
            if (doc == null) return;
            doc.path = path;
            doc.modified = false;
            RecentManager.get_default ().add_item (File.new_for_path (path).get_uri ());
            update_title ();
        }

        private static FileFilter filter (string name, string[] suffixes) {
            var f = new FileFilter ();
            f.name = name;
            foreach (var s in suffixes) f.add_suffix (s);
            return f;
        }

        private async void export (string ext) {
            if (doc == null) return;
            var dialog = new FileDialog ();
            dialog.title = _("Export Formula");
            string base_name = doc.path != null ? Path.get_basename (doc.path) : _("Formula");
            int dot = base_name.last_index_of (".");
            if (dot > 0) base_name = base_name.substring (0, dot);
            dialog.initial_name = base_name + "." + ext;
            try {
                var file = yield dialog.save (this, null);
                if (file == null) return;
                string path = file.get_path ();
                if (ext == "mml") {
                    FileUtils.set_contents (path, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + doc.to_mathml (true, true));
                } else if (ext == "docx" || ext == "omml") {
                    Formats.save (doc, path, font (), export_size ());
                } else if (ext == "png") {
                    double scale = app.settings != null ? (double) app.settings.get_int ("export-scale") : 2.0;
                    var ex = new Exporter (doc, font (), export_size ());
                    ex.write_png (path, scale);
                } else {
                    Formats.save (doc, path, font (), export_size ());
                }
                app.history.add (doc.to_latex ());
                add_toast (new Toast (_("Exported \"%s\"").printf (file.get_basename ())));
            } catch (Error e) {
                if (!(e is Gtk.DialogError.DISMISSED) && !(e is IOError.CANCELLED)) show_error (_("Could Not Export"), e.message);
            }
        }

        public void show_error (string title, string message) {
            var dlg = new ConfirmDialog (app, title, "dialog-error", message, _("OK"), ConfirmDialog.ActionStyle.SUGGESTED);
            dlg.transient_for = this;
            dlg.present ();
        }

        private FormulaDoc clip_doc () {
            if (editor != null && editor.has_selection) {
                var d = new FormulaDoc ();
                d.set_root (editor.selection_copy ());
                return d;
            }
            return doc;
        }

        private Gdk.ContentProvider provider_for (FormulaDoc d, bool image, bool mathml, bool latex, bool um) {
            Gdk.ContentProvider[] parts = {};
            if (mathml) {
                var mml = d.to_mathml (false, true);
                parts += new Gdk.ContentProvider.for_bytes ("application/mathml+xml", new Bytes (mml.data));
                parts += new Gdk.ContentProvider.for_bytes ("application/mathml-presentation+xml", new Bytes (mml.data));
                parts += new Gdk.ContentProvider.for_bytes ("text/mathml", new Bytes (mml.data));
                parts += new Gdk.ContentProvider.for_bytes ("MathML", new Bytes (mml.data));
                parts += new Gdk.ContentProvider.for_bytes (Singularity.Equations.Equation.OMML_MIME, new Bytes (WordFormat.omml_of (d).data));
                parts += new Gdk.ContentProvider.for_bytes ("text/html", new Bytes (WordFormat.clipboard_html (d).data));
            }
            if (image) {
                double scale = app.settings != null ? (double) app.settings.get_int ("export-scale") : 2.0;
                var ex = new Exporter (d, font (), export_size ());
                parts += new Gdk.ContentProvider.for_bytes ("image/png", new Bytes (ex.png_bytes (scale)));
                parts += new Gdk.ContentProvider.for_bytes ("image/svg+xml", new Bytes (ex.svg_bytes ()));
            }
            string text;
            if (latex) text = d.to_latex ();
            else if (um) text = d.to_unicodemath ();
            else if (mathml && !image) text = d.to_mathml (true, true);
            else text = d.to_latex ();
            var val = GLib.Value (typeof (string));
            val.set_string (text);
            parts += new Gdk.ContentProvider.for_value (val);
            return new Gdk.ContentProvider.union (parts);
        }

        private void copy_as (bool image, bool mathml, bool latex, bool um, string message) {
            if (doc == null) return;
            var d = clip_doc ();
            if (d.is_empty ()) return;
            get_clipboard ().set_content (provider_for (d, image, mathml, latex, um));
            app.history.add (d.to_latex ());
            add_toast (new Toast (message));
        }

        private void paste () {
            var cb = get_clipboard ();
            var formats = cb.get_formats ();
            string? pick = null;
            foreach (var m in new string[] { "application/mathml+xml", Singularity.Equations.Equation.OMML_MIME, "text/html" }) {
                if (pick == null && formats.contain_mime_type (m)) pick = m;
            }
            if (pick != null) {
                string chosen_mime = pick;
                cb.read_async.begin ({ chosen_mime }, Priority.DEFAULT, null, (obj, res) => {
                    try {
                        string mime;
                        var stream = cb.read_async.end (res, out mime);
                        var mem = new MemoryOutputStream.resizable ();
                        mem.splice (stream, OutputStreamSpliceFlags.CLOSE_SOURCE | OutputStreamSpliceFlags.CLOSE_TARGET);
                        uint8[] data = mem.steal_data ();
                        data.length = (int) mem.get_data_size ();
                        string got = ((string) data).make_valid ((ssize_t) data.length);
                        if (chosen_mime != "application/mathml+xml") {
                            var eq = Singularity.Equations.Equation.from_clipboard (chosen_mime, new Bytes (got.data));
                            if (eq == null) {
                                paste_plain ();
                                return;
                            }
                            got = eq.mathml;
                        }
                        paste_text (got);
                    } catch (Error e) {
                        paste_plain ();
                    }
                });
                return;
            }
            paste_plain ();
        }

        private void paste_plain () {
            get_clipboard ().read_text_async.begin (null, (obj, res) => {
                try {
                    string? text = get_clipboard ().read_text_async.end (res);
                    if (text != null) paste_text (text);
                } catch (Error e) {
                }
            });
        }

        private void paste_text (string text) {
            if (editor == null) return;
            try {
                var d = FormulaDoc.parse_any (text);
                editor.insert_row (d.root);
            } catch (ParseError e) {
                var r = new Row ();
                int i = 0;
                unichar c;
                while (text.get_next_char (ref i, out c)) {
                    var t = new Token.plain (c.to_string ());
                    t.variant = MathVariant.NORMAL;
                    r.append (t);
                }
                editor.insert_row (r);
                add_toast (new Toast (_("Pasted as text: the clipboard is not a formula")));
            }
        }

        private void paste_as_new () {
            new_document ();
            paste ();
        }

        private void insert_latex (string latex) {
            if (editor == null || doc == null) {
                try {
                    load_document (FormulaDoc.parse_linear (latex, LinearSyntax.LATEX));
                } catch (ParseError e) {
                }
                return;
            }
            try {
                var d = FormulaDoc.parse_linear (latex, LinearSyntax.LATEX);
                if (d.root.size == 1 && d.root[0] is Table && editor.doc.is_empty ()) {
                    editor.replace_root (d.root, d.tag);
                } else {
                    editor.insert_row (d.root);
                }
                canvas.grab_focus ();
            } catch (ParseError e) {
            }
        }

        private void insert_symbol (Symbol s) {
            if (editor == null || doc == null) return;
            if (s.largeop) {
                editor.insert_big_operator (s.ch, false);
            } else {
                var r = new Row ();
                var kind = (s.category == "greek" || (s.cls == AtomClass.ORD && s.ch.get_char (0).isalpha ())) ? TokenKind.IDENT : TokenKind.OPERATOR;
                if (kind == TokenKind.IDENT) r.append (MathmlReader.token_from_text (kind, s.ch));
                else r.append (new Token (kind, s.ch));
                editor.insert_row (r);
            }
            canvas.grab_focus ();
        }

        public void run_structure (string id) {
            if (editor == null || doc == null) return;
            switch (id) {
                case "frac": editor.insert_fraction (false); break;
                case "dfrac": editor.run_command ("dfrac"); break;
                case "sfrac":
                    var sf = new Frac ();
                    sf.bevelled = true;
                    editor.insert_node (sf);
                    break;
                case "binom": editor.run_command ("binom"); break;
                case "sup": editor.insert_script (true); break;
                case "sub": editor.insert_script (false); break;
                case "subsup": editor.insert_subsup (); break;
                case "sqrt": editor.insert_node (new Radical ()); break;
                case "root": editor.insert_node (new Radical (null, new Row ()), 0); break;
                case "cbrt": editor.insert_node (new Radical (null, new Row.with ({ new Token.number ("3") }))); break;
                case "paren": editor.insert_fenced ("(", ")"); break;
                case "bracket": editor.insert_fenced ("[", "]"); break;
                case "brace": editor.insert_fenced ("{", "}"); break;
                case "abs": editor.insert_fenced ("|", "|"); break;
                case "norm": editor.insert_fenced ("\u2016", "\u2016"); break;
                case "angle": editor.insert_fenced ("\u27e8", "\u27e9"); break;
                case "floor": editor.insert_fenced ("\u230a", "\u230b"); break;
                case "ceil": editor.insert_fenced ("\u2308", "\u2309"); break;
                case "eval": editor.insert_fenced ("", "|"); break;
                case "sum": editor.insert_big_operator ("\u2211", true); break;
                case "prod": editor.insert_big_operator ("\u220f", true); break;
                case "int": editor.insert_big_operator ("\u222b", true); break;
                case "iint": editor.insert_big_operator ("\u222c", false); break;
                case "oint": editor.insert_big_operator ("\u222e", false); break;
                case "bigcup": editor.insert_big_operator ("\u22c3", true); break;
                case "bigcap": editor.insert_big_operator ("\u22c2", true); break;
                case "lim": editor.run_command ("lim"); break;
                case "overbrace": editor.insert_node (new Accent ("\u23de", null, true, false)); break;
                case "underbrace": editor.insert_node (new Accent ("\u23df", null, true, true)); break;
                case "overarrow": editor.run_command ("overrightarrow"); break;
                case "pmatrix": editor.insert_table (TableKind.PMATRIX, 2, 2); break;
                case "bmatrix": editor.insert_table (TableKind.BMATRIX, 2, 2); break;
                case "vmatrix": editor.insert_table (TableKind.VMATRIX, 2, 2); break;
                case "matrix3": editor.insert_table (TableKind.MATRIX, 3, 3); break;
                case "cases": editor.insert_table (TableKind.CASES, 2, 2); break;
                case "aligned": editor.insert_table (TableKind.ALIGN, 2, 2); break;
                case "boxed": editor.run_command ("boxed"); break;
                case "cancel": editor.run_command ("cancel"); break;
                case "xarrow": editor.insert_node (new UnderOver (new Row.with ({ new Token.op ("\u2192") }), new Row (), new Row ()), 0); break;
                case "overset": editor.run_command ("overset"); break;
                case "underset": editor.run_command ("underset"); break;
                case "text": editor.insert_text_mode (); break;
                case "prescript": editor.insert_prescripts (); break;
                case "presub":
                case "presup":
                    editor.insert_prescripts ();
                    var owner = editor.row.parent as Scripts;
                    if (owner != null) {
                        if (id == "presub") owner.set_sup (null);
                        else owner.set_sub (null);
                        editor.set_caret (id == "presub" ? owner.sub : owner.sup, 0);
                        editor.changed ();
                    }
                    break;
                default:
                    if (id.has_prefix ("enclose:")) {
                        editor.insert_node (new Enclose (id.substring (8)));
                        break;
                    }
                    editor.run_command (id);
                    break;
            }
            if (canvas != null) canvas.grab_focus ();
        }

        private delegate void Act ();

        private void act (string name, owned Act handler, bool needs_doc = true) {
            var a = new SimpleAction (name, null);
            if (needs_doc) doc_actions += name;
            a.activate.connect (() => {
                if (needs_doc && (editor == null || doc == null)) return;
                handler ();
            });
            add_action (a);
        }

        private bool text_focused () {
            var f = get_focus ();
            return f != null && (f is Gtk.Text || f is Gtk.TextView);
        }

        private void forward (string action) {
            get_focus ().activate_action_variant (action, null);
        }

        private void insert_confirm () {
            if (insert_target == null || doc == null) return;
            try {
                string target = insert_target;
                var ex = new Exporter (doc, font (), export_size ());
                if (target.down ().has_suffix (".svg")) ex.write_svg (target);
                else ex.write_png (target, 2.0);
                int dot = target.last_index_of (".");
                string stem = dot > 0 ? target.substring (0, dot) : target;
                FileUtils.set_contents (stem + ".tex", doc.to_latex ());
                FileUtils.set_contents (stem + ".mml", doc.to_mathml (true, true));
                FileUtils.set_contents (stem + ".json", Cli.metrics_json (ex, 2.0));
                app.history.add (doc.to_latex ());
                close_confirmed = true;
                app.quit ();
            } catch (Error e) {
                show_error (_("Could Not Insert"), e.message);
            }
        }


        public void open_ink () {
            ink_page.reset ();
            content_stack.visible_child_name = "ink";
            foreach (var w in doc_bubbles) w.visible = false;
            set_sidebar_visible (false);
            set_title (_("Write by Hand"));
            ink_page.canvas.grab_focus ();
        }

        private void leave_ink () {
            if (doc != null) {
                content_stack.visible_child_name = "editor";
                foreach (var w in doc_bubbles) w.visible = true;
                if (insert_bubble != null) insert_bubble.visible = insert_target != null;
                set_sidebar_visible (app.settings == null || app.settings.get_boolean ("show-symbols"));
                update_title ();
                if (canvas != null) canvas.grab_focus ();
            } else {
                show_welcome ();
            }
        }

        private void finish_ink (string latex) {
            if (doc == null) {
                try {
                    load_document (FormulaDoc.parse_linear (latex, LinearSyntax.LATEX));
                } catch (ParseError e) {
                    show_error (_("Could Not Insert"), LatexParser.error_message (e));
                }
                return;
            }
            leave_ink ();
            insert_latex (latex);
        }

        private async void print_formula () {
            if (doc == null) return;
            string name = doc.path != null ? Path.get_basename (doc.path) : _("Formula");
            var source = new FormulaPrintSource (doc, name);
            yield Singularity.Print.run_source (this, source);
        }

        private void copy_for_word () {
            if (doc == null) return;
            var d = clip_doc ();
            if (d.is_empty ()) return;
            var eq = new Singularity.Equations.Equation.from_mathml (d.to_mathml (false, true));
            eq.display = d.display;
            eq.justification = d.justification;
            Gdk.ContentProvider[] parts = {};
            parts += eq.content_provider ();
            double scale = app.settings != null ? (double) app.settings.get_int ("export-scale") : 2.0;
            var ex = new Exporter (d, font (), export_size ());
            parts += new Gdk.ContentProvider.for_bytes ("image/png", new Bytes (ex.png_bytes (scale)));
            get_clipboard ().set_content (new Gdk.ContentProvider.union (parts));
            app.history.add (d.to_latex ());
            add_toast (new Toast (_("Copied as a Word equation")));
        }

        public static string? speech_program () {
            string? over = Environment.get_variable ("SINGULARITY_SPEAK_COMMAND");
            if (over != null && over != "") return over;
            foreach (var p in new string[] { "spd-say", "espeak-ng", "espeak" }) {
                if (Environment.find_program_in_path (p) != null) return p;
            }
            return null;
        }

        private void read_aloud () {
            if (doc == null) return;
            var d = clip_doc ();
            string text = Singularity.Equations.Speech.describe (d.to_mathml (false, false));
            if (text == "") return;
            string? prog = speech_program ();
            if (prog == null) {
                add_toast (new Toast (_("No speech synthesizer is installed. The spoken text was copied instead.")));
                get_clipboard ().set_text (text);
                return;
            }
            try {
                if (speaker != null) speaker.force_exit ();
                string[] argv = { prog };
                if (Path.get_basename (prog) == "spd-say") argv += "--wait";
                argv += text;
                speaker = new Subprocess.newv (argv, SubprocessFlags.STDOUT_SILENCE | SubprocessFlags.STDERR_SILENCE);
            } catch (Error e) {
                add_toast (new Toast (_("Could not start speech: %s").printf (e.message)));
            }
        }

        private void copy_speech () {
            if (doc == null) return;
            string text = Singularity.Equations.Speech.describe (clip_doc ().to_mathml (false, false));
            get_clipboard ().set_text (text);
            add_toast (new Toast (_("Spoken text copied")));
        }

        private AppDialog small_dialog (string title, int width, int height) {
            var dlg = new AppDialog (app, true);
            dlg.set_title (title);
            dlg.transient_for = this;
            dlg.set_default_size (width, height);
            return dlg;
        }

        private delegate void DialogApply ();

        private void dialog_footer (AppDialog dlg, string label, owned DialogApply apply) {
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.halign = Align.END;
            bar.margin_start = bar.margin_end = 18;
            bar.margin_top = 12;
            bar.margin_bottom = 16;
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => dlg.close ());
            dlg.set_cancel_button (cancel);
            var ok = new Button.with_label (label);
            ok.add_css_class ("suggested-action");
            ok.clicked.connect (() => {
                apply ();
                dlg.close ();
            });
            bar.append (cancel);
            bar.append (ok);
            dlg.content_box.append (bar);
            dlg.default_widget = ok;
        }

        private void save_to_gallery () {
            if (doc == null || doc.is_empty ()) return;
            var d = clip_doc ();
            var dlg = small_dialog (_("Save as New Equation"), 420, 330);
            var prev = new FormulaPreview (d, 22, false, 360);
            prev.height_request = 64;
            prev.margin_top = 6;
            dlg.content_box.append (prev);
            var group = new PreferencesGroup (_("Equation"));
            group.margin_start = group.margin_end = 18;
            var name = new EntryRow (_("Name"));
            var category = new EntryRow (_("Category"));
            category.text = _("My Equations");
            group.add_row (name);
            group.add_row (category);
            dlg.content_box.append (group);
            dialog_footer (dlg, _("Save"), () => {
                var g = Singularity.Equations.UserGallery.get_default ();
                g.add (name.text.strip () != "" ? name.text.strip () : d.to_latex (), category.text, d.to_mathml (false, true), d.to_latex ());
                try {
                    g.save ();
                    add_toast (new Toast (_("Saved to the gallery")));
                } catch (Error e) {
                    show_error (_("Could Not Save"), e.message);
                }
            });
            dlg.present ();
            name.grab_focus ();
        }

        private void numbering_options () {
            if (doc == null) return;
            var dlg = small_dialog (_("Equation Numbering"), 420, 400);
            var group = new PreferencesGroup (_("Numbers"));
            group.margin_start = group.margin_end = 18;
            var on = new SwitchRow (_("Number Equations"), null, doc.numbered);
            group.add_row (on);
            var style = new BubbleSwitcher ();
            style.add_option ("parens", "(1)");
            style.add_option ("brackets", "[1]");
            style.add_option ("plain", "1");
            style.set_active (doc.number_style.to_string ());
            var style_row = new ActionRow (_("Format"));
            style.valign = Align.CENTER;
            style_row.add_suffix (style);
            group.add_row (style_row);
            var prefix = new EntryRow (_("Prefix, for example 2."));
            prefix.text = doc.number_prefix;
            group.add_row (prefix);
            var first = new SpinRow (_("Start At"), null, 0, 9999, 1, doc.first_number);
            group.add_row (first);
            dlg.content_box.append (group);
            dialog_footer (dlg, _("Apply"), () => {
                editor.checkpoint ();
                doc.numbered = on.active;
                doc.number_style = Singularity.Equations.NumberStyle.parse (style.active_option ?? "parens");
                doc.number_prefix = prefix.text;
                doc.first_number = (int) first.value;
                doc.modified = true;
                update_state_actions ();
                canvas.invalidate ();
                sync_linear ();
            });
            dlg.present ();
        }

        private void matrix_spacing () {
            var t = editor.table_at_caret ();
            if (t == null) return;
            var dlg = small_dialog (_("Matrix Spacing"), 400, 280);
            var group = new PreferencesGroup (_("Spacing"), _("In ems, the width of the letter M"));
            group.margin_start = group.margin_end = 18;
            var col = new SpinRow (_("Between Columns"), null, 0, 8, 0.1, t.column_gap >= 0 ? t.column_gap : 1.0);
            col.spin_btn.digits = 1;
            var row = new SpinRow (_("Between Rows"), null, 0, 8, 0.1, t.row_gap >= 0 ? t.row_gap : 0.2);
            row.spin_btn.digits = 1;
            group.add_row (col);
            group.add_row (row);
            dlg.content_box.append (group);
            dialog_footer (dlg, _("Apply"), () => editor.table_set_spacing (col.value, row.value));
            dlg.present ();
        }

        private void name_line () {
            var t = doc.lines_table ();
            if (t == null) {
                if (doc.label == null) doc.label = doc.unique_label ();
                if (!doc.numbered && doc.tag == null) doc.numbered = true;
            } else {
                int r = current_line ();
                if (r < 0) return;
                if (t.names[r] == null) t.names[r] = doc.unique_label ();
                if (!doc.numbered && t.tags[r] == null) doc.numbered = true;
            }
            doc.modified = true;
            update_state_actions ();
            canvas.invalidate ();
            sync_linear ();
            add_toast (new Toast (_("This line can now be referenced")));
        }

        private int current_line () {
            var t = doc.lines_table ();
            if (t == null) return -1;
            Row? cur = editor.row;
            while (cur != null) {
                int r = -1, c = -1;
                if (cur.parent == t && t.locate (cur, out r, out c)) return r;
                var owner = cur.parent;
                if (owner == null) return -1;
                cur = owner.parent as Row;
            }
            return -1;
        }

        private void insert_reference_menu (Widget anchor_widget) {
            var refs = doc.references ();
            var menu = new ContextMenu (anchor_widget);
            if (refs.size == 0) {
                menu.add_item (_("Name This Line First"), "bookmark-new-symbolic", () => name_line ());
            } else {
                var names = new Gee.ArrayList<string> ();
                names.add_all (refs.keys);
                names.sort ((a, b) => strcmp (refs[a], refs[b]));
                foreach (var n in names) {
                    string nm = n;
                    menu.add_item (_("Equation %s").printf (doc.format_label (refs[n])), "insert-link-symbolic", () => {
                        editor.insert_node (new Ref (nm, true));
                        canvas.grab_focus ();
                    });
                }
            }
            menu.closed.connect (() => Idle.add (() => {
                menu.unparent ();
                return Source.REMOVE;
            }));
            menu.popup ();
        }

        public void choose_docx_equation (Gee.List<string> omml, string path) {
            var dlg = small_dialog (_("Choose an Equation"), 520, 560);
            var scroll = new ScrolledWindow ();
            scroll.vexpand = true;
            scroll.hscrollbar_policy = PolicyType.NEVER;
            var list = new Box (Orientation.VERTICAL, 8);
            list.margin_start = list.margin_end = 18;
            list.margin_bottom = 12;
            var intro = new Label (ngettext ("This document contains %d equation.", "This document contains %d equations.", omml.size).printf (omml.size));
            intro.halign = Align.START;
            intro.add_css_class ("dim-label");
            list.append (intro);
            for (int i = 0; i < omml.size; i++) {
                FormulaDoc d;
                try {
                    d = WordFormat.doc_from_omml (omml[i]);
                } catch (Error e) {
                    continue;
                }
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("formula-gallery-card");
                var prev = new FormulaPreview (d, 18, false, 440);
                prev.can_target = false;
                prev.height_request = 56;
                b.child = prev;
                b.tooltip_text = _("Equation %d").printf (i + 1);
                var chosen = d;
                b.clicked.connect (() => {
                    dlg.close ();
                    load_document (chosen);
                });
                list.append (b);
            }
            scroll.child = list;
            dlg.content_box.append (scroll);
            var bar = new Box (Orientation.HORIZONTAL, 8);
            bar.halign = Align.END;
            bar.margin_start = bar.margin_end = 18;
            bar.margin_top = 8;
            bar.margin_bottom = 16;
            var cancel = new Button.with_label (_("Cancel"));
            cancel.clicked.connect (() => dlg.close ());
            dlg.set_cancel_button (cancel);
            bar.append (cancel);
            dlg.content_box.append (bar);
            dlg.present ();
        }

        private void apply_break_setting () {
            if (doc == null) return;
            int width = app.settings != null ? app.settings.get_int ("break-width") : 30;
            doc.line_width = width;
            if (app.settings != null) {
                doc.wrap_right = app.settings.get_string ("wrap-mode") == "right";
                doc.wrap_indent = app.settings.get_int ("wrap-indent");
            }
        }

        private void install_actions () {
            act ("save", () => save.begin (false));
            act ("save-as", () => save.begin (true));
            act ("save-online", () => CloudActions.save_document (this));
            act ("export-svg", () => export.begin ("svg"));
            act ("export-png", () => export.begin ("png"));
            act ("export-pdf", () => export.begin ("pdf"));
            act ("export-mathml", () => export.begin ("mml"));
            act ("export-latex", () => export.begin ("tex"));
            Singularity.Share.add_action (this, this, () => {
                var file = share_file ();
                return file != null ? new Singularity.ShareContent.for_files ({ file }) : null;
            });
            act ("close-doc", () => close_document ());
            act ("undo", () => {
                if (text_focused ()) {
                    forward ("text.undo");
                    return;
                }
                editor.undo ();
            });
            act ("redo", () => {
                if (text_focused ()) {
                    forward ("text.redo");
                    return;
                }
                editor.redo ();
            });
            act ("cut", () => {
                if (text_focused ()) {
                    forward ("clipboard.cut");
                    return;
                }
                if (!editor.has_selection) return;
                copy_as (true, true, false, false, _("Cut"));
                editor.delete_selection ();
            });
            act ("copy", () => {
                if (text_focused ()) {
                    forward ("clipboard.copy");
                    return;
                }
                copy_as (true, true, false, false, _("Formula copied"));
            });
            act ("paste", () => {
                if (text_focused ()) {
                    forward ("clipboard.paste");
                    return;
                }
                paste ();
            });
            act ("select-all", () => {
                if (text_focused ()) {
                    forward ("selection.select-all");
                    return;
                }
                editor.select_all ();
            });
            act ("copy-all", () => copy_as (true, true, false, false, _("Formula copied as image and MathML")));
            act ("copy-image", () => copy_as (true, false, false, false, _("Formula copied as an image")));
            act ("copy-mathml", () => copy_as (false, true, false, false, _("Formula copied as MathML")));
            act ("copy-latex", () => copy_as (false, false, true, false, _("Formula copied as LaTeX")));
            act ("copy-unicodemath", () => copy_as (false, false, false, true, _("Formula copied as UnicodeMath")));
            act ("focus-linear", () => {
                if (!linear_panel.visible) linear_panel.visible = true;
                linear.grab_focus ();
            });
            act ("focus-canvas", () => canvas.grab_focus ());
            act ("toggle-sidebar", () => set_sidebar_visible (!get_sidebar_visible ()), false);
            act ("search-symbols", () => {
                set_sidebar_visible (true);
                side_search.grab_focus_entry ();
            });
            act ("zoom-in", () => canvas.zoom_to (canvas.zoom * 1.2));
            act ("zoom-out", () => canvas.zoom_to (canvas.zoom / 1.2));
            act ("zoom-reset", () => canvas.zoom_to (1.0));
            act ("new-line", () => editor.new_line ());
            act ("text-mode", () => editor.insert_text_mode ());
            act ("next-slot", () => editor.next_slot ());
            act ("table-row-above", () => editor.table_insert_row (false));
            act ("table-row-below", () => editor.table_insert_row (true));
            act ("table-col-left", () => editor.table_insert_column (false));
            act ("table-col-right", () => editor.table_insert_column (true));
            act ("table-delete-row", () => editor.table_delete_row ());
            act ("table-delete-col", () => editor.table_delete_column ());
            act ("insert-confirm", () => insert_confirm ());
            act ("clear-history", () => confirm_clear_history (), false);
            act ("print", () => print_formula.begin ());
            act ("export-docx", () => export.begin ("docx"));
            act ("export-omml", () => export.begin ("omml"));
            act ("export-odf", () => export.begin ("odf"));
            act ("copy-word", () => copy_for_word ());
            act ("save-gallery", () => save_to_gallery ());
            act ("toggle-linear", () => {
                editor.toggle_linear (syntax);
                canvas.grab_focus ();
            });
            act ("read-aloud", () => read_aloud ());
            act ("copy-speech", () => copy_speech ());
            act ("ink", () => open_ink (), false);
            act ("name-line", () => name_line ());
            act ("insert-reference", () => insert_reference_menu (canvas));
            act ("numbering-options", () => numbering_options ());
            act ("show-autocorrect", () => {
                set_sidebar_visible (true);
                side_switcher.set_active ("autocorrect");
                side_stack.visible_child_name = "autocorrect";
            }, false);

            var border = new SimpleAction ("border", VariantType.STRING);
            border.activate.connect ((p) => {
                if (editor == null || doc == null) return;
                if (editor.current_enclose () == null) {
                    editor.insert_node (new Enclose (p.get_string ()));
                    return;
                }
                editor.toggle_enclose_note (p.get_string ());
            });
            add_action (border);
            doc_actions += "border";

            var justify = new SimpleAction.stateful ("justify", VariantType.STRING, new Variant.string ("center-group"));
            justify.change_state.connect ((v) => {
                if (doc == null) return;
                justify.set_state (v);
                doc.justification = Singularity.Equations.Justification.from_mathml (v.get_string ());
                doc.modified = true;
                canvas.invalidate ();
            });
            add_action (justify);
            doc_actions += "justify";

            var breaks = new SimpleAction.stateful ("break-lines", null, new Variant.boolean (false));
            breaks.activate.connect (() => {
                if (doc == null) return;
                bool on = !(doc.line_width > 0);
                if (on) apply_break_setting ();
                else doc.line_width = 0;
                breaks.set_state (new Variant.boolean (on));
                doc.modified = true;
                canvas.invalidate ();
            });
            add_action (breaks);
            doc_actions += "break-lines";

            var structure = new SimpleAction ("structure", VariantType.STRING);
            structure.activate.connect ((p) => run_structure (p.get_string ()));
            add_action (structure);
            doc_actions += "structure";

            var variant = new SimpleAction ("variant", VariantType.STRING);
            variant.activate.connect ((p) => {
                if (editor == null || doc == null) return;
                if (!editor.has_selection && editor.index > 0) editor.anchor = editor.index - 1;
                editor.apply_variant (MathVariant.from_mathml (p.get_string ()));
            });
            add_action (variant);
            doc_actions += "variant";

            var color = new SimpleAction ("color", VariantType.STRING);
            color.activate.connect ((p) => {
                if (editor == null || doc == null) return;
                string c = p.get_string ();
                editor.wrap_style (c == "" ? null : c, -1);
            });
            add_action (color);
            doc_actions += "color";

            var space = new SimpleAction ("space", VariantType.STRING);
            space.activate.connect ((p) => {
                if (editor != null && doc != null) editor.run_command (p.get_string ());
            });
            add_action (space);
            doc_actions += "space";

            var display = new SimpleAction.stateful ("display-style", null, new Variant.boolean (true));
            display.activate.connect (() => {
                if (doc == null) return;
                doc.display = !doc.display;
                display.set_state (new Variant.boolean (doc.display));
                doc.modified = true;
                canvas.invalidate ();
            });
            add_action (display);
            doc_actions += "display-style";

            var numbered = new SimpleAction.stateful ("number-equations", null, new Variant.boolean (false));
            numbered.activate.connect (() => {
                if (doc == null) return;
                doc.numbered = !doc.numbered;
                numbered.set_state (new Variant.boolean (doc.numbered));
                doc.modified = true;
                canvas.invalidate ();
                sync_linear ();
            });
            add_action (numbered);
            doc_actions += "number-equations";

            var show_linear = new SimpleAction.stateful ("show-linear", null, new Variant.boolean (app.settings == null || app.settings.get_boolean ("show-linear")));
            show_linear.activate.connect (() => {
                bool v = !show_linear.get_state ().get_boolean ();
                show_linear.set_state (new Variant.boolean (v));
                if (linear_panel != null) linear_panel.visible = v;
                if (app.settings != null) app.settings.set_boolean ("show-linear", v);
            });
            add_action (show_linear);

            var syn = new SimpleAction.stateful ("syntax", VariantType.STRING, new Variant.string (syntax == LinearSyntax.LATEX ? "latex" : "unicodemath"));
            syn.change_state.connect ((v) => {
                string name = v.get_string ();
                syn.set_state (v);
                syntax = name == "unicodemath" ? LinearSyntax.UNICODEMATH : LinearSyntax.LATEX;
                if (syntax_switch.active_option != name) syntax_switch.set_active (name);
                if (app.settings != null) app.settings.set_string ("linear-syntax", name);
                if (linear != null) {
                    bool had = linear.has_focus;
                    if (had && canvas != null) canvas.grab_focus ();
                    sync_linear ();
                    if (had) linear.grab_focus ();
                }
            });
            add_action (syn);
        }

        private void update_state_actions () {
            var d = lookup_action ("display-style") as SimpleAction;
            if (d != null && doc != null) d.set_state (new Variant.boolean (doc.display));
            var n = lookup_action ("number-equations") as SimpleAction;
            if (n != null && doc != null) n.set_state (new Variant.boolean (doc.numbered));
            var j = lookup_action ("justify") as SimpleAction;
            if (j != null && doc != null) j.set_state (new Variant.string (doc.justification.to_mathml ()));
            var b = lookup_action ("break-lines") as SimpleAction;
            if (b != null && doc != null) b.set_state (new Variant.boolean (doc.line_width > 0));
        }

        private void sync_actions () {
            foreach (string name in doc_actions) {
                var a = lookup_action (name) as SimpleAction;
                if (a != null) a.set_enabled (editor != null && doc != null);
            }
            bool table = editor != null && doc != null && editor.in_table ();
            foreach (var name in new string[] { "table-row-above", "table-row-below", "table-col-left", "table-col-right", "table-delete-row", "table-delete-col" }) {
                var a = lookup_action (name) as SimpleAction;
                if (a != null) a.set_enabled (table);
            }
            if (undo_bubble != null && editor != null) {
                undo_bubble.sensitive = editor.can_undo;
                redo_bubble.sensitive = editor.can_redo;
            }
            sync_share ();
        }

        private File? share_file () {
            if (doc == null || doc.path == null || !FileUtils.test (doc.path, FileTest.EXISTS)) return null;
            return File.new_for_path (doc.path);
        }

        private void sync_share () {
            bool can = share_file () != null;
            var a = lookup_action ("share") as SimpleAction;
            if (a != null) a.set_enabled (can);
            if (share_bubble != null) share_bubble.sensitive = can;
        }

        public void run (string name) {
            ((GLib.ActionGroup) this).activate_action (name, null);
        }

        public void reload_font () {
            if (canvas != null) canvas.reload_font ();
        }

        public void apply_font_size (int size) {
            if (canvas != null) canvas.set_font_size (size);
        }
    }
}
