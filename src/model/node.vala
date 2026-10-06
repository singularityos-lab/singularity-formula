namespace Singularity.Apps.Formula {

    public enum TokenKind {
        IDENT,
        NUMBER,
        OPERATOR,
        TEXT
    }

    public enum AtomClass {
        NONE,
        ORD,
        OP,
        BIN,
        REL,
        OPEN,
        CLOSE,
        PUNCT,
        INNER
    }

    public enum MathVariant {
        DEFAULT,
        NORMAL,
        BOLD,
        ITALIC,
        BOLD_ITALIC,
        DOUBLE_STRUCK,
        SCRIPT,
        BOLD_SCRIPT,
        FRAKTUR,
        BOLD_FRAKTUR,
        SANS_SERIF,
        BOLD_SANS_SERIF,
        SANS_SERIF_ITALIC,
        SANS_SERIF_BOLD_ITALIC,
        MONOSPACE;

        public string to_mathml () {
            switch (this) {
                case NORMAL: return "normal";
                case BOLD: return "bold";
                case ITALIC: return "italic";
                case BOLD_ITALIC: return "bold-italic";
                case DOUBLE_STRUCK: return "double-struck";
                case SCRIPT: return "script";
                case BOLD_SCRIPT: return "bold-script";
                case FRAKTUR: return "fraktur";
                case BOLD_FRAKTUR: return "bold-fraktur";
                case SANS_SERIF: return "sans-serif";
                case BOLD_SANS_SERIF: return "bold-sans-serif";
                case SANS_SERIF_ITALIC: return "sans-serif-italic";
                case SANS_SERIF_BOLD_ITALIC: return "sans-serif-bold-italic";
                case MONOSPACE: return "monospace";
                default: return "";
            }
        }

        public static MathVariant from_mathml (string name) {
            switch (name) {
                case "normal": return NORMAL;
                case "bold": return BOLD;
                case "italic": return ITALIC;
                case "bold-italic": return BOLD_ITALIC;
                case "double-struck": return DOUBLE_STRUCK;
                case "script": return SCRIPT;
                case "bold-script": return BOLD_SCRIPT;
                case "fraktur": return FRAKTUR;
                case "bold-fraktur": return BOLD_FRAKTUR;
                case "sans-serif": return SANS_SERIF;
                case "bold-sans-serif": return BOLD_SANS_SERIF;
                case "sans-serif-italic": return SANS_SERIF_ITALIC;
                case "sans-serif-bold-italic": return SANS_SERIF_BOLD_ITALIC;
                case "monospace": return MONOSPACE;
                default: return DEFAULT;
            }
        }
    }

    public abstract class Node : Object {
        public weak Node? parent;

        public abstract Node copy ();

        public virtual Row[] slots () {
            return {};
        }

        public virtual bool equals (Node other) {
            if (get_type () != other.get_type ()) return false;
            var a = slots ();
            var b = other.slots ();
            if (a.length != b.length) return false;
            for (int i = 0; i < a.length; i++) {
                if ((a[i] == null) != (b[i] == null)) return false;
                if (a[i] != null && !a[i].equals (b[i])) return false;
            }
            return true;
        }

        public Row? parent_row {
            get { return parent as Row; }
        }

        protected Row? adopt (Row? row) {
            if (row != null) row.parent = this;
            return row;
        }
    }

    public class Row : Node {
        public Gee.ArrayList<Node> items = new Gee.ArrayList<Node> ();

        public Row () {
        }

        public Row.with (Node[] nodes) {
            foreach (var n in nodes) append (n);
        }

        public int size {
            get { return items.size; }
        }

        public bool is_empty () {
            return items.size == 0;
        }

        public new Node get (int i) {
            return items[i];
        }

        public void append (Node n) {
            n.parent = this;
            items.add (n);
        }

        public void insert (int i, Node n) {
            n.parent = this;
            items.insert (i, n);
        }

        public Node remove_at (int i) {
            var n = items.remove_at (i);
            n.parent = null;
            return n;
        }

        public void replace (int i, Node n) {
            items[i].parent = null;
            n.parent = this;
            items[i] = n;
        }

        public void append_all (Row other) {
            foreach (var n in other.items) append (n.copy ());
        }

        public void move_from (Row other) {
            var list = new Gee.ArrayList<Node> ();
            list.add_all (other.items);
            other.items.clear ();
            foreach (var n in list) append (n);
        }

        public Row slice (int from, int to) {
            var r = new Row ();
            for (int i = from; i < to; i++) r.append (items[i].copy ());
            return r;
        }

        public void clear () {
            foreach (var n in items) n.parent = null;
            items.clear ();
        }

        public int index_of (Node n) {
            for (int i = 0; i < items.size; i++) if (items[i] == n) return i;
            return -1;
        }

        public override Node copy () {
            var r = new Row ();
            foreach (var n in items) r.append (n.copy ());
            return r;
        }

        public Row copy_row () {
            return (Row) copy ();
        }

        public override bool equals (Node other) {
            var o = other as Row;
            if (o == null || o.items.size != items.size) return false;
            for (int i = 0; i < items.size; i++) if (!items[i].equals (o.items[i])) return false;
            return true;
        }

        public Node? owner {
            get { return parent; }
        }
    }

    public class Token : Node {
        public TokenKind kind;
        public string text;
        public MathVariant variant = MathVariant.DEFAULT;
        public AtomClass forced_class = AtomClass.NONE;
        public int limits = -1;
        public double min_size = 0;
        public bool fence_middle;
        public bool error;
        public bool prime;
        public bool fixed;
        public bool linear;

        public Token (TokenKind kind, string text) {
            this.kind = kind;
            this.text = text;
        }

        public Token.ident (string text) {
            this (TokenKind.IDENT, text);
        }

        public Token.number (string text) {
            this (TokenKind.NUMBER, text);
        }

        public Token.op (string text) {
            this (TokenKind.OPERATOR, text);
        }

        public Token.plain (string text) {
            this (TokenKind.TEXT, text);
        }

        public bool is_function () {
            return kind == TokenKind.IDENT && text.char_count () > 1;
        }

        public override Node copy () {
            var t = new Token (kind, text);
            t.variant = variant;
            t.forced_class = forced_class;
            t.limits = limits;
            t.min_size = min_size;
            t.fence_middle = fence_middle;
            t.error = error;
            t.prime = prime;
            t.fixed = fixed;
            t.linear = linear;
            return t;
        }

        public override bool equals (Node other) {
            var o = other as Token;
            return o != null && o.kind == kind && o.text == text && o.variant == variant
                && o.forced_class == forced_class && o.limits == limits
                && Math.fabs (o.min_size - min_size) < 1e-6 && o.fence_middle == fence_middle;
        }
    }

    public class Space : Node {
        public double width;

        public Space (double width_em) {
            width = width_em;
        }

        public override Node copy () {
            return new Space (width);
        }

        public override bool equals (Node other) {
            var o = other as Space;
            return o != null && Math.fabs (o.width - width) < 1e-6;
        }
    }

    public class Frac : Node {
        public Row num;
        public Row den;
        public bool line = true;
        public double thickness = -1;
        public int display = -1;
        public bool bevelled;
        public bool continued;

        public Frac (Row? num = null, Row? den = null) {
            this.num = adopt (num ?? new Row ());
            this.den = adopt (den ?? new Row ());
        }

        public override Row[] slots () {
            return { num, den };
        }

        public override Node copy () {
            var f = new Frac (num.copy_row (), den.copy_row ());
            f.line = line;
            f.thickness = thickness;
            f.display = display;
            f.bevelled = bevelled;
            f.continued = continued;
            return f;
        }

        public override bool equals (Node other) {
            var o = other as Frac;
            return o != null && o.line == line && o.display == display && o.bevelled == bevelled
                && o.continued == continued && base.equals (other);
        }
    }

    public class Radical : Node {
        public Row body;
        public Row? index;

        public Radical (Row? body = null, Row? index = null) {
            this.body = adopt (body ?? new Row ());
            this.index = adopt (index);
        }

        public override Row[] slots () {
            if (index != null) return { index, body };
            return { body };
        }

        public void set_index (Row? r) {
            index = adopt (r);
        }

        public override Node copy () {
            return new Radical (body.copy_row (), index != null ? index.copy_row () : null);
        }
    }

    public class Scripts : Node {
        public Row? sub;
        public Row? sup;
        public bool pre;

        public Scripts (Row? sub, Row? sup) {
            this.sub = adopt (sub);
            this.sup = adopt (sup);
        }

        public override Row[] slots () {
            Row[] r = {};
            if (sub != null) r += sub;
            if (sup != null) r += sup;
            return r;
        }

        public void set_sub (Row? r) {
            sub = adopt (r);
        }

        public void set_sup (Row? r) {
            sup = adopt (r);
        }

        public override Node copy () {
            var s = new Scripts (sub != null ? sub.copy_row () : null, sup != null ? sup.copy_row () : null);
            s.pre = pre;
            return s;
        }

        public override bool equals (Node other) {
            var o = other as Scripts;
            if (o == null || o.pre != pre) return false;
            if ((o.sub == null) != (sub == null) || (o.sup == null) != (sup == null)) return false;
            return base.equals (other);
        }
    }

    public class UnderOver : Node {
        public Row body;
        public Row? under;
        public Row? over;
        public bool accent_under;
        public bool accent_over;

        public UnderOver (Row? body, Row? under, Row? over) {
            this.body = adopt (body ?? new Row ());
            this.under = adopt (under);
            this.over = adopt (over);
        }

        public override Row[] slots () {
            Row[] r = {};
            if (over != null) r += over;
            r += body;
            if (under != null) r += under;
            return r;
        }

        public override Node copy () {
            var u = new UnderOver (body.copy_row (), under != null ? under.copy_row () : null, over != null ? over.copy_row () : null);
            u.accent_under = accent_under;
            u.accent_over = accent_over;
            return u;
        }

        public override bool equals (Node other) {
            var o = other as UnderOver;
            if (o == null || (o.under == null) != (under == null) || (o.over == null) != (over == null)) return false;
            return base.equals (other);
        }
    }

    public class Accent : Node {
        public Row body;
        public string mark;
        public bool under;
        public bool stretchy;

        public Accent (string mark, Row? body = null, bool stretchy = false, bool under = false) {
            this.mark = mark;
            this.body = adopt (body ?? new Row ());
            this.stretchy = stretchy;
            this.under = under;
        }

        public override Row[] slots () {
            return { body };
        }

        public bool is_brace () {
            return mark == "\u23de" || mark == "\u23df" || mark == "\u23dc" || mark == "\u23dd" || mark == "\u23b4" || mark == "\u23b5";
        }

        public bool is_line () {
            return mark == "\u203e" || mark == "\u00af" || mark == "_" || mark == "\u0332";
        }

        public override Node copy () {
            return new Accent (mark, body.copy_row (), stretchy, under);
        }

        public override bool equals (Node other) {
            var o = other as Accent;
            return o != null && o.mark == mark && o.under == under && o.stretchy == stretchy && base.equals (other);
        }
    }

    public class Fenced : Node {
        public string open;
        public string close;
        public Row body;

        public Fenced (string open, string close, Row? body = null) {
            this.open = open;
            this.close = close;
            this.body = adopt (body ?? new Row ());
        }

        public override Row[] slots () {
            return { body };
        }

        public override Node copy () {
            return new Fenced (open, close, body.copy_row ());
        }

        public override bool equals (Node other) {
            var o = other as Fenced;
            return o != null && o.open == open && o.close == close && base.equals (other);
        }
    }

    public enum TableKind {
        MATRIX,
        PMATRIX,
        BMATRIX,
        BRACE_MATRIX,
        VMATRIX,
        DOUBLE_VMATRIX,
        SMALL_MATRIX,
        CASES,
        ALIGN,
        GATHER,
        ARRAY;

        public string open_delim () {
            switch (this) {
                case PMATRIX: return "(";
                case BMATRIX: return "[";
                case BRACE_MATRIX: return "{";
                case VMATRIX: return "|";
                case DOUBLE_VMATRIX: return "\u2016";
                case CASES: return "{";
                default: return "";
            }
        }

        public string close_delim () {
            switch (this) {
                case PMATRIX: return ")";
                case BMATRIX: return "]";
                case BRACE_MATRIX: return "}";
                case VMATRIX: return "|";
                case DOUBLE_VMATRIX: return "\u2016";
                default: return "";
            }
        }

        public bool is_matrix () {
            return this == MATRIX || this == PMATRIX || this == BMATRIX || this == BRACE_MATRIX
                || this == VMATRIX || this == DOUBLE_VMATRIX || this == SMALL_MATRIX;
        }

        public string env_name () {
            switch (this) {
                case MATRIX: return "matrix";
                case PMATRIX: return "pmatrix";
                case BMATRIX: return "bmatrix";
                case BRACE_MATRIX: return "Bmatrix";
                case VMATRIX: return "vmatrix";
                case DOUBLE_VMATRIX: return "Vmatrix";
                case SMALL_MATRIX: return "smallmatrix";
                case CASES: return "cases";
                case ALIGN: return "aligned";
                case GATHER: return "gathered";
                default: return "array";
            }
        }
    }

    public class Table : Node {
        public TableKind kind;
        public Gee.ArrayList<Gee.ArrayList<Row>> rows = new Gee.ArrayList<Gee.ArrayList<Row>> ();
        public string columns = "";
        public string column_lines = "";
        public Gee.ArrayList<string?> tags = new Gee.ArrayList<string?> ();
        public Gee.ArrayList<bool> notag = new Gee.ArrayList<bool> ();
        public Gee.ArrayList<string?> names = new Gee.ArrayList<string?> ();
        public double column_gap = -1;
        public double row_gap = -1;

        public Table (TableKind kind) {
            this.kind = kind;
        }

        public Table.sized (TableKind kind, int nrows, int ncols) {
            this.kind = kind;
            for (int r = 0; r < nrows; r++) {
                var row = new Gee.ArrayList<Row> ();
                for (int c = 0; c < ncols; c++) row.add (adopt (new Row ()));
                add_row_cells (row);
            }
        }

        public int row_count {
            get { return rows.size; }
        }

        public int column_count {
            get {
                int n = 0;
                foreach (var r in rows) n = int.max (n, r.size);
                return n;
            }
        }

        public void add_row_cells (Gee.ArrayList<Row> cells, string? tag = null, bool no_tag = false, string? name = null) {
            foreach (var c in cells) c.parent = this;
            rows.add (cells);
            tags.add (tag);
            notag.add (no_tag);
            names.add (name);
        }

        public void insert_row (int at, int ncols) {
            var row = new Gee.ArrayList<Row> ();
            for (int c = 0; c < ncols; c++) row.add (adopt (new Row ()));
            rows.insert (at, row);
            tags.insert (at, null);
            notag.insert (at, false);
            names.insert (at, null);
        }

        public void remove_row (int at) {
            rows.remove_at (at);
            tags.remove_at (at);
            notag.remove_at (at);
            names.remove_at (at);
        }

        public void insert_column (int at) {
            foreach (var row in rows) row.insert (int.min (at, row.size), adopt (new Row ()));
        }

        public void remove_column (int at) {
            foreach (var row in rows) if (at < row.size) row.remove_at (at);
        }

        public void normalize () {
            int n = column_count;
            foreach (var row in rows) while (row.size < n) row.add (adopt (new Row ()));
        }

        public Row? cell (int r, int c) {
            if (r < 0 || r >= rows.size || c < 0 || c >= rows[r].size) return null;
            return rows[r][c];
        }

        public bool locate (Row cell, out int r, out int c) {
            for (r = 0; r < rows.size; r++) {
                for (c = 0; c < rows[r].size; c++) if (rows[r][c] == cell) return true;
            }
            r = -1;
            c = -1;
            return false;
        }

        public char column_align (int c) {
            if (kind == TableKind.ALIGN) return c % 2 == 0 ? 'r' : 'l';
            if (kind == TableKind.CASES) return 'l';
            if (columns.length > 0) {
                if (c < columns.length) return columns[c];
                return columns[columns.length - 1];
            }
            return 'c';
        }

        public override Row[] slots () {
            Row[] r = {};
            foreach (var row in rows) foreach (var c in row) r += c;
            return r;
        }

        public override Node copy () {
            var t = new Table (kind);
            t.columns = columns;
            t.column_lines = column_lines;
            t.column_gap = column_gap;
            t.row_gap = row_gap;
            for (int i = 0; i < rows.size; i++) {
                var row = new Gee.ArrayList<Row> ();
                foreach (var c in rows[i]) row.add (c.copy_row ());
                t.add_row_cells (row, tags[i], notag[i], names[i]);
            }
            return t;
        }

        public override bool equals (Node other) {
            var o = other as Table;
            if (o == null || o.kind != kind || o.rows.size != rows.size || o.columns != columns) return false;
            for (int i = 0; i < rows.size; i++) {
                if (o.rows[i].size != rows[i].size || o.tags[i] != tags[i] || o.notag[i] != notag[i]) return false;
                for (int c = 0; c < rows[i].size; c++) if (!rows[i][c].equals (o.rows[i][c])) return false;
            }
            return true;
        }
    }

    public class Style : Node {
        public Row body;
        public int display = -1;
        public int script_level = -1;
        public string? color;
        public string? background;
        public double scale = 1.0;

        public Style (Row? body = null) {
            this.body = adopt (body ?? new Row ());
        }

        public override Row[] slots () {
            return { body };
        }

        public override Node copy () {
            var s = new Style (body.copy_row ());
            s.display = display;
            s.script_level = script_level;
            s.color = color;
            s.background = background;
            s.scale = scale;
            return s;
        }

        public override bool equals (Node other) {
            var o = other as Style;
            return o != null && o.display == display && o.script_level == script_level && o.color == color
                && o.background == background && Math.fabs (o.scale - scale) < 1e-6 && base.equals (other);
        }
    }

    public class Enclose : Node {
        public Row body;
        public string notation;

        public Enclose (string notation, Row? body = null) {
            this.notation = notation;
            this.body = adopt (body ?? new Row ());
        }

        public override Row[] slots () {
            return { body };
        }

        public override Node copy () {
            return new Enclose (notation, body.copy_row ());
        }

        public override bool equals (Node other) {
            var o = other as Enclose;
            return o != null && o.notation == notation && base.equals (other);
        }
    }

    public class Phantom : Node {
        public Row body;
        public bool keep_width = true;
        public bool keep_height = true;

        public Phantom (Row? body = null) {
            this.body = adopt (body ?? new Row ());
        }

        public override Row[] slots () {
            return { body };
        }

        public override Node copy () {
            var p = new Phantom (body.copy_row ());
            p.keep_width = keep_width;
            p.keep_height = keep_height;
            return p;
        }

        public override bool equals (Node other) {
            var o = other as Phantom;
            return o != null && o.keep_width == keep_width && o.keep_height == keep_height && base.equals (other);
        }
    }

    public class Ref : Node {
        public string name;
        public bool paren;

        public Ref (string name, bool paren = true) {
            this.name = name;
            this.paren = paren;
        }

        public override Node copy () {
            return new Ref (name, paren);
        }

        public override bool equals (Node other) {
            var o = other as Ref;
            return o != null && o.name == name && o.paren == paren;
        }
    }

    public class Group : Node {
        public Row body;

        public Group (Row? body = null) {
            this.body = adopt (body ?? new Row ());
        }

        public override Row[] slots () {
            return { body };
        }

        public override Node copy () {
            return new Group (body.copy_row ());
        }
    }
}
