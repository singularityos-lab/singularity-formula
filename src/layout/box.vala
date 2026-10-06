namespace Singularity.Apps.Formula {

    public enum ItemKind {
        GLYPH,
        RULE,
        FRAME,
        LINE,
        PLACEHOLDER,
        ELLIPSE,
        BACKGROUND,
        PENDING
    }

    public class Item {
        public ItemKind kind;
        public double x;
        public double y;
        public double w;
        public double h;
        public uint glyph;
        public double size;
        public MathFont? font;
        public double sx = 1.0;
        public double sy = 1.0;
        public string? color;
        public string text = "";

        public Item (ItemKind kind) {
            this.kind = kind;
        }
    }

    public class Child {
        public MBox box;
        public double x;
        public double y;

        public Child (MBox box, double x, double y) {
            this.box = box;
            this.x = x;
            this.y = y;
        }
    }

    public class MBox {
        public double width;
        public double ascent;
        public double descent;
        public double italic;
        public AtomClass cls = AtomClass.ORD;
        public bool limits;
        public bool largeop;
        public bool single_glyph;
        public bool stretched;
        public double accent_x = -1;
        public Gee.ArrayList<Item> items = new Gee.ArrayList<Item> ();
        public Gee.ArrayList<Child> children = new Gee.ArrayList<Child> ();
        public Row? row;
        public double[] carets = {};
        public double[] caret_ys = {};
        public int line_count = 1;
        public Node? node;
        public string? color;
        public bool hidden;

        public MBox () {
        }

        public MBox.empty (double width = 0) {
            this.width = width;
        }

        public double height {
            get { return ascent + descent; }
        }

        public void add (MBox b, double x, double y) {
            children.add (new Child (b, x, y));
        }

        public void add_item (Item it) {
            items.add (it);
        }

        public void grow_to_children () {
            foreach (var c in children) {
                ascent = double.max (ascent, c.box.ascent - c.y);
                descent = double.max (descent, c.box.descent + c.y);
            }
        }

        public MBox wrap (double dx, double dy) {
            var b = new MBox ();
            b.add (this, dx, dy);
            b.width = width + dx;
            b.ascent = ascent - dy;
            b.descent = descent + dy;
            return b;
        }
    }

    public class RowGeom {
        public Row row;
        public double x;
        public double y;
        public double ascent;
        public double descent;
        public double width;
        public double[] carets;
        public double[] caret_ys = {};
        public int depth;
    }

    public class NodeRect {
        public Node node;
        public double x;
        public double y;
        public double width;
        public double ascent;
        public double descent;
    }

    public class Geometry {
        public Gee.HashMap<Row, RowGeom> rows = new Gee.HashMap<Row, RowGeom> ();
        public Gee.ArrayList<RowGeom> row_list = new Gee.ArrayList<RowGeom> ();
        public Gee.HashMap<Node, NodeRect> nodes = new Gee.HashMap<Node, NodeRect> ();

        public static Geometry compute (MBox root, double x, double y) {
            var g = new Geometry ();
            g.walk (root, x, y, 0);
            return g;
        }

        private void walk (MBox b, double x, double y, int depth) {
            if (b.row != null && !rows.has_key (b.row)) {
                var rg = new RowGeom ();
                rg.row = b.row;
                rg.x = x;
                rg.y = y;
                rg.ascent = b.ascent;
                rg.descent = b.descent;
                rg.width = b.width;
                rg.depth = depth;
                rg.carets = new double[b.carets.length];
                for (int i = 0; i < b.carets.length; i++) rg.carets[i] = x + b.carets[i];
                if (b.caret_ys.length == b.carets.length) {
                    rg.caret_ys = new double[b.caret_ys.length];
                    for (int i = 0; i < b.caret_ys.length; i++) rg.caret_ys[i] = y + b.caret_ys[i];
                }
                rows[b.row] = rg;
                row_list.add (rg);
            }
            if (b.node != null && !nodes.has_key (b.node)) {
                var nr = new NodeRect ();
                nr.node = b.node;
                nr.x = x;
                nr.y = y;
                nr.width = b.width;
                nr.ascent = b.ascent;
                nr.descent = b.descent;
                nodes[b.node] = nr;
            }
            foreach (var c in b.children) walk (c.box, x + c.x, y + c.y, depth + 1);
        }

        public RowGeom? row_at (double px, double py) {
            RowGeom? best = null;
            double best_score = double.MAX;
            foreach (var rg in row_list) {
                double pad = 2;
                double top = rg.y - rg.ascent - pad;
                double bottom = rg.y + rg.descent + pad;
                double left = rg.x - pad;
                double right = rg.x + rg.width + pad;
                double dx = px < left ? left - px : (px > right ? px - right : 0);
                double dy = py < top ? top - py : (py > bottom ? py - bottom : 0);
                double dist = dx + dy * 1.5;
                double area = (right - left) * (bottom - top);
                double score = dist * 10000 + area - rg.depth * 0.01;
                if (score < best_score) {
                    best_score = score;
                    best = rg;
                }
            }
            return best;
        }

        public static int nearest_caret (RowGeom rg, double px, double py = double.NAN) {
            int best = 0;
            double bd = double.MAX;
            bool lines = rg.caret_ys.length == rg.carets.length && !py.is_nan ();
            for (int i = 0; i < rg.carets.length; i++) {
                double d = Math.fabs (rg.carets[i] - px);
                if (lines) d += Math.fabs (rg.caret_ys[i] - py) * 4;
                if (d < bd) {
                    bd = d;
                    best = i;
                }
            }
            return best;
        }
    }
}
