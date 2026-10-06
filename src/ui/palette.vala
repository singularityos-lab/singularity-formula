using Gtk;
using Singularity.Widgets;

namespace Singularity.Apps.Formula {

    public class StructureInfo {
        public string id;
        public string preview;
        public string name;
        public string category;

        public StructureInfo (string id, string preview, string name, string category) {
            this.id = id;
            this.preview = preview;
            this.name = name;
            this.category = category;
        }
    }

    public class Structures {
        private static Gee.ArrayList<StructureInfo>? list;

        public static Gee.List<StructureInfo> all () {
            if (list != null) return list;
            list = new Gee.ArrayList<StructureInfo> ();
            string frac = _("Fractions");
            add ("frac", "\\frac{}{}", _("Fraction (Ctrl+F)"), frac);
            add ("dfrac", "\\dfrac{}{}", _("Display Fraction"), frac);
            add ("sfrac", "\\sfrac{}{}", _("Skewed Fraction (Ctrl+/)"), frac);
            add ("binom", "\\binom{}{}", _("Binomial Coefficient"), frac);
            string scr = _("Scripts and Roots");
            add ("sup", "{\\square}^{}", _("Superscript (Ctrl+H)"), scr);
            add ("sub", "{\\square}_{}", _("Subscript (Ctrl+L)"), scr);
            add ("subsup", "{\\square}_{}^{}", _("Subscript and Superscript (Ctrl+J)"), scr);
            add ("sqrt", "\\sqrt{}", _("Square Root (Ctrl+R)"), scr);
            add ("root", "\\sqrt[]{}", _("Nth Root (Ctrl+Shift+R)"), scr);
            add ("cbrt", "\\sqrt[3]{}", _("Cube Root"), scr);
            add ("prescript", "{}_{}^{}\\square", _("Left Subscript and Superscript"), scr);
            add ("presub", "{}_{}\\square", _("Left Subscript"), scr);
            add ("presup", "{}^{}\\square", _("Left Superscript"), scr);
            string br = _("Brackets");
            add ("paren", "\\left({}\\right)", _("Parentheses (Ctrl+9)"), br);
            add ("bracket", "\\left[{}\\right]", _("Square Brackets (Ctrl+[)"), br);
            add ("brace", "\\left\\{{}\\right\\}", _("Braces (Ctrl+Shift+[)"), br);
            add ("abs", "\\left|{}\\right|", _("Absolute Value"), br);
            add ("norm", "\\left\\|{}\\right\\|", _("Norm"), br);
            add ("angle", "\\left\\langle{}\\right\\rangle", _("Angle Brackets"), br);
            add ("floor", "\\left\\lfloor{}\\right\\rfloor", _("Floor"), br);
            add ("ceil", "\\left\\lceil{}\\right\\rceil", _("Ceiling"), br);
            add ("eval", "\\left.{}\\right|", _("Evaluation Bar"), br);
            string big = _("Big Operators");
            add ("sum", "\\sum_{}^{}", _("Summation"), big);
            add ("prod", "\\prod_{}^{}", _("Product"), big);
            add ("int", "\\int_{}^{}", _("Integral"), big);
            add ("iint", "\\iint", _("Double Integral"), big);
            add ("oint", "\\oint", _("Contour Integral"), big);
            add ("bigcup", "\\bigcup_{}^{}", _("Union"), big);
            add ("bigcap", "\\bigcap_{}^{}", _("Intersection"), big);
            add ("lim", "\\lim_{}", _("Limit"), big);
            string acc = _("Accents");
            add ("hat", "\\hat{}", _("Hat"), acc);
            add ("bar", "\\bar{}", _("Bar"), acc);
            add ("vec", "\\vec{}", _("Vector"), acc);
            add ("tilde", "\\tilde{}", _("Tilde"), acc);
            add ("dot", "\\dot{}", _("Dot"), acc);
            add ("ddot", "\\ddot{}", _("Double Dot"), acc);
            add ("widehat", "\\widehat{}", _("Wide Hat"), acc);
            add ("overline", "\\overline{}", _("Overline"), acc);
            add ("underline", "\\underline{}", _("Underline"), acc);
            add ("overbrace", "\\overbrace{}^{}", _("Brace Above"), acc);
            add ("underbrace", "\\underbrace{}_{}", _("Brace Below"), acc);
            add ("overarrow", "\\overrightarrow{}", _("Arrow Above"), acc);
            string mat = _("Matrices");
            add ("pmatrix", "\\begin{pmatrix} & \\\\ & \\end{pmatrix}", _("Matrix in Parentheses"), mat);
            add ("bmatrix", "\\begin{bmatrix} & \\\\ & \\end{bmatrix}", _("Matrix in Brackets"), mat);
            add ("vmatrix", "\\begin{vmatrix} & \\\\ & \\end{vmatrix}", _("Determinant"), mat);
            add ("matrix3", "\\begin{matrix} & & \\\\ & & \\\\ & & \\end{matrix}", _("3 by 3 Matrix"), mat);
            add ("cases", "\\begin{cases} & \\\\ & \\end{cases}", _("Cases"), mat);
            add ("aligned", "\\begin{aligned} & = \\\\ & = \\end{aligned}", _("Aligned Equations"), mat);
            string dec = _("Decorations");
            add ("boxed", "\\boxed{}", _("Box"), dec);
            add ("cancel", "\\cancel{}", _("Cancel"), dec);
            add ("enclose:roundedbox", "\\enclose{roundedbox}{}", _("Rounded Box"), dec);
            add ("enclose:circle", "\\enclose{circle}{}", _("Circle"), dec);
            add ("enclose:top bottom", "\\enclose{top,bottom}{}", _("Border Above and Below"), dec);
            add ("enclose:left right", "\\enclose{left,right}{}", _("Border Left and Right"), dec);
            add ("enclose:top", "\\enclose{top}{}", _("Border Above"), dec);
            add ("enclose:bottom", "\\enclose{bottom}{}", _("Border Below"), dec);
            add ("enclose:horizontalstrike", "\\enclose{horizontalstrike}{}", _("Horizontal Strike"), dec);
            add ("enclose:verticalstrike", "\\enclose{verticalstrike}{}", _("Vertical Strike"), dec);
            add ("enclose:downdiagonalstrike", "\\enclose{downdiagonalstrike}{}", _("Diagonal Strike Down"), dec);
            add ("enclose:updiagonalstrike downdiagonalstrike", "\\enclose{updiagonalstrike,downdiagonalstrike}{}", _("Cross Out"), dec);
            add ("xarrow", "\\xrightarrow[]{}", _("Arrow with Labels"), dec);
            add ("overset", "\\overset{}{}", _("Stack Above"), dec);
            add ("underset", "\\underset{}{}", _("Stack Below"), dec);
            add ("text", "\\text{abc}", _("Text (Ctrl+Shift+E)"), dec);
            string fn = _("Functions");
            add ("sin", "\\sin", _("Sine"), fn);
            add ("cos", "\\cos", _("Cosine"), fn);
            add ("tan", "\\tan", _("Tangent"), fn);
            add ("log", "\\log", _("Logarithm"), fn);
            add ("ln", "\\ln", _("Natural Logarithm"), fn);
            add ("exp", "\\exp", _("Exponential"), fn);
            add ("max", "\\max", _("Maximum"), fn);
            add ("min", "\\min", _("Minimum"), fn);
            add ("det", "\\det", _("Determinant Function"), fn);
            return list;
        }

        private static void add (string id, string preview, string name, string category) {
            list.add (new StructureInfo (id, preview, name, category));
        }
    }

    public class PaletteView : Box {
        public signal void symbol_chosen (Symbol s);
        public signal void structure_chosen (string id);
        public signal void clear_search ();

        private Gee.ArrayList<Button> buttons = new Gee.ArrayList<Button> ();
        private Gee.HashMap<Button, string> keys = new Gee.HashMap<Button, string> ();
        private Gee.ArrayList<Widget> headers = new Gee.ArrayList<Widget> ();
        private Gee.HashMap<Widget, FlowBox> header_box = new Gee.HashMap<Widget, FlowBox> ();
        private StatusPage empty;

        public PaletteView () {
            Object (orientation: Orientation.VERTICAL, spacing: 4);
            add_css_class ("formula-palette");
            string? current = null;
            FlowBox? flow = null;
            foreach (var st in Structures.all ()) {
                if (st.category != current) {
                    current = st.category;
                    flow = section (st.category);
                }
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("formula-structure");
                b.tooltip_text = st.name;
                var prev = new FormulaPreview.latex (st.preview, 15, true, 64);
                prev.can_target = false;
                b.child = prev;
                string id = st.id;
                b.clicked.connect (() => structure_chosen (id));
                flow.append (b);
                register (b, (st.name + " " + st.id + " " + st.category).down (), flow);
            }
            string[] cats = { "greek", "operators", "relations", "negated", "arrows", "sets", "logic", "bigops", "letterlike", "script", "geometry", "misc", "delimiters" };
            string[] titles = { _("Greek"), _("Operators"), _("Relations"), _("Negated Relations"), _("Arrows"), _("Sets"), _("Logic"), _("Large Operators"), _("Letter-Like Symbols"), _("Script, Fraktur and Double-Struck"), _("Geometry"), _("Other Symbols"), _("Delimiters") };
            for (int i = 0; i < cats.length; i++) {
                var seen = new Gee.HashSet<string> ();
                flow = section (titles[i]);
                foreach (var s in Symbols.all ()) {
                    if (s.category != cats[i]) continue;
                    if (seen.contains (s.ch)) continue;
                    seen.add (s.ch);
                    var b = new Button ();
                    b.add_css_class ("flat");
                    b.add_css_class ("formula-symbol");
                    var l = new Label (s.ch);
                    var attrs = new Pango.AttrList ();
                    string fam = FormulaApp.math_font ().family;
                    if (fam != "") attrs.insert (Pango.attr_family_new (fam));
                    attrs.insert (Pango.attr_scale_new (1.35));
                    l.attributes = attrs;
                    b.child = l;
                    b.tooltip_text = "%s  \\%s".printf (_(s.name), s.command);
                    var sym = s;
                    b.clicked.connect (() => symbol_chosen (sym));
                    flow.append (b);
                    register (b, (s.name + " " + s.command + " " + titles[i]).down (), flow);
                }
            }
            empty = new StatusPage ();
            empty.icon_name = "edit-find";
            empty.title = _("No Symbols Found");
            empty.description = _("Try another name, such as \"integral\" or \"arrow\".");
            var clear = new Button.with_label (_("Clear Search"));
            clear.add_css_class ("pill");
            clear.halign = Align.CENTER;
            clear.clicked.connect (() => clear_search ());
            empty.child = clear;
            empty.visible = false;
            empty.compact = true;
            append (empty);
        }

        private FlowBox section (string title) {
            var label = new SidebarSectionLabel (title);
            append (label);
            var flow = new FlowBox ();
            flow.selection_mode = SelectionMode.NONE;
            flow.homogeneous = true;
            flow.min_children_per_line = 4;
            flow.max_children_per_line = 8;
            flow.column_spacing = 2;
            flow.row_spacing = 2;
            flow.margin_start = 6;
            flow.margin_end = 6;
            append (flow);
            headers.add (label);
            header_box[label] = flow;
            return flow;
        }

        private void register (Button b, string key, FlowBox flow) {
            buttons.add (b);
            keys[b] = key;
        }

        public void filter (string text) {
            string q = text.strip ().down ();
            int shown = 0;
            foreach (var b in buttons) {
                bool v = q == "" || keys[b].contains (q) || (b.child is Label && ((Label) b.child).label == text.strip ());
                b.get_parent ().visible = v;
                if (v) shown++;
            }
            foreach (var h in headers) {
                var flow = header_box[h];
                bool any = false;
                for (var c = flow.get_first_child (); c != null; c = c.get_next_sibling ()) if (c.visible) any = true;
                h.visible = any;
                flow.visible = any;
            }
            empty.visible = shown == 0;
        }
    }

    public class GalleryView : Box {
        public signal void chosen (GalleryItem item);
        private Gee.ArrayList<Widget> cards = new Gee.ArrayList<Widget> ();
        private Gee.HashMap<Widget, string> keys = new Gee.HashMap<Widget, string> ();
        private FlowBox flow;
        private FlowBox user_flow;
        private Widget user_title;
        private Widget builtin_title;
        private bool compact;
        private Gee.ArrayList<Widget> user_cards = new Gee.ArrayList<Widget> ();
        private string query = "";

        public GalleryView (bool compact, int limit = -1) {
            Object (orientation: Orientation.VERTICAL, spacing: 8);
            this.compact = compact;
            var ut = new Label (_("My Equations"));
            ut.add_css_class (compact ? "heading" : "title-4");
            ut.halign = Align.START;
            user_title = ut;
            append (user_title);
            user_flow = new FlowBox ();
            user_flow.selection_mode = SelectionMode.NONE;
            user_flow.homogeneous = false;
            user_flow.valign = Align.START;
            user_flow.min_children_per_line = compact ? 1 : 2;
            user_flow.max_children_per_line = compact ? 1 : 3;
            user_flow.column_spacing = 8;
            user_flow.row_spacing = 8;
            append (user_flow);
            var builtin = new Label (_("Common Equations"));
            builtin.add_css_class (compact ? "heading" : "title-4");
            builtin.halign = Align.START;
            builtin_title = builtin;
            append (builtin);
            var store = Singularity.Equations.UserGallery.get_default ();
            store.changed.connect (() => fill_user ());
            fill_user ();
            flow = new FlowBox ();
            flow.selection_mode = SelectionMode.NONE;
            flow.homogeneous = false;
            flow.valign = Align.START;
            flow.min_children_per_line = compact ? 1 : 2;
            flow.max_children_per_line = compact ? 1 : 3;
            flow.column_spacing = 8;
            flow.row_spacing = 8;
            append (flow);
            int count = 0;
            foreach (var item in Gallery.all ()) {
                if (limit > 0 && (count >= limit || !item.featured)) continue;
                count++;
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("formula-gallery-card");
                var box = new Box (Orientation.VERTICAL, 6);
                var prev = new FormulaPreview.latex (item.latex, compact ? 13 : 15, false, compact ? 220 : 200);
                prev.can_target = false;
                prev.height_request = compact ? 44 : 64;
                box.append (prev);
                var title = new Label (item.title);
                title.add_css_class ("caption");
                title.ellipsize = Pango.EllipsizeMode.END;
                box.append (title);
                b.child = box;
                b.tooltip_text = "%s: %s".printf (item.category, item.title);
                var it = item;
                b.clicked.connect (() => chosen (it));
                flow.append (b);
                cards.add (b);
                keys[b] = (item.title + " " + item.category + " " + item.latex).down ();
            }
        }

        private void fill_user () {
            foreach (var c in user_cards) user_flow.remove (c.get_parent ());
            user_cards.clear ();
            var store = Singularity.Equations.UserGallery.get_default ();
            foreach (var e in store.items ()) {
                FormulaDoc d;
                try {
                    d = FormulaDoc.parse_any (e.mathml);
                } catch (ParseError err) {
                    continue;
                }
                var b = new Button ();
                b.add_css_class ("flat");
                b.add_css_class ("formula-gallery-card");
                var box = new Box (Orientation.VERTICAL, 6);
                var prev = new FormulaPreview (d, compact ? 13 : 15, false, compact ? 220 : 200);
                prev.can_target = false;
                prev.height_request = compact ? 44 : 64;
                box.append (prev);
                var title = new Label (e.name);
                title.add_css_class ("caption");
                title.ellipsize = Pango.EllipsizeMode.END;
                box.append (title);
                b.child = box;
                b.tooltip_text = e.category != "" ? "%s: %s".printf (e.category, e.name) : e.name;
                var item = new GalleryItem (e.name, e.category, d.to_latex (), false);
                b.clicked.connect (() => chosen (item));
                string id = e.id;
                var rc = new GestureClick ();
                rc.button = Gdk.BUTTON_SECONDARY;
                rc.pressed.connect ((n, x, y) => {
                    var menu = new ContextMenu (b);
                    menu.add_item (_("Insert"), "list-add-symbolic", () => chosen (item));
                    menu.add_separator ();
                    menu.add_item (_("Remove from Gallery"), "user-trash-symbolic", () => {
                        store.remove (id);
                        try {
                            store.save ();
                        } catch (Error err) {
                            warning ("gallery: %s", err.message);
                        }
                    });
                    menu.closed.connect (() => Idle.add (() => {
                        menu.unparent ();
                        return Source.REMOVE;
                    }));
                    menu.popup ();
                });
                b.add_controller (rc);
                user_flow.append (b);
                user_cards.add (b);
                keys[b] = (e.name + " " + e.category + " " + d.to_latex ()).down ();
            }
            user_title.visible = user_cards.size > 0;
            builtin_title.visible = user_cards.size > 0;
            user_flow.visible = user_cards.size > 0;
            if (query != "") filter (query);
        }

        public int filter (string text) {
            string q = text.strip ().down ();
            query = q;
            int shown = 0;
            foreach (var c in user_cards) {
                bool v = q == "" || keys[c].contains (q);
                c.get_parent ().visible = v;
                if (v) shown++;
            }
            foreach (var c in cards) {
                bool v = q == "" || keys[c].contains (q);
                c.get_parent ().visible = v;
                if (v) shown++;
            }
            return shown;
        }
    }
}
