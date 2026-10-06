namespace Singularity.Apps.Formula {

    public struct InkPoint {
        public double x;
        public double y;

        public InkPoint (double x, double y) {
            this.x = x;
            this.y = y;
        }
    }

    public class InkStroke {
        public Gee.ArrayList<InkPoint?> points = new Gee.ArrayList<InkPoint?> ();

        public void add (double x, double y) {
            points.add (InkPoint (x, y));
        }

        public void bounds (out double x0, out double y0, out double x1, out double y1) {
            x0 = double.MAX;
            y0 = double.MAX;
            x1 = -double.MAX;
            y1 = -double.MAX;
            foreach (var p in points) {
                x0 = double.min (x0, p.x);
                y0 = double.min (y0, p.y);
                x1 = double.max (x1, p.x);
                y1 = double.max (y1, p.y);
            }
        }

        public double length () {
            double l = 0;
            for (int i = 1; i < points.size; i++) l += Math.hypot (points[i].x - points[i - 1].x, points[i].y - points[i - 1].y);
            return l;
        }

        public InkStroke translated (double dx, double dy, double scale = 1.0) {
            var s = new InkStroke ();
            foreach (var p in points) s.add (p.x * scale + dx, p.y * scale + dy);
            return s;
        }
    }

    public class InkBox {
        public double x0 = double.MAX;
        public double y0 = double.MAX;
        public double x1 = -double.MAX;
        public double y1 = -double.MAX;

        public void include (InkStroke s) {
            double a, b, c, d;
            s.bounds (out a, out b, out c, out d);
            x0 = double.min (x0, a);
            y0 = double.min (y0, b);
            x1 = double.max (x1, c);
            y1 = double.max (y1, d);
        }

        public void include_box (InkBox o) {
            x0 = double.min (x0, o.x0);
            y0 = double.min (y0, o.y0);
            x1 = double.max (x1, o.x1);
            y1 = double.max (y1, o.y1);
        }

        public double width {
            get { return x1 - x0; }
        }

        public double height {
            get { return y1 - y0; }
        }

        public double cx {
            get { return (x0 + x1) / 2; }
        }

        public double cy {
            get { return (y0 + y1) / 2; }
        }

        public bool contains_point (double x, double y, double pad = 0) {
            return x >= x0 - pad && x <= x1 + pad && y >= y0 - pad && y <= y1 + pad;
        }
    }

    public class InkDrawing : Object {
        public Gee.ArrayList<InkStroke> strokes = new Gee.ArrayList<InkStroke> ();

        public signal void changed ();

        public bool is_empty () {
            return strokes.size == 0;
        }

        public void add (InkStroke s) {
            strokes.add (s);
            changed ();
        }

        public void clear () {
            strokes.clear ();
            changed ();
        }

        public bool erase_at (double x, double y, double radius) {
            bool removed = false;
            for (int i = strokes.size - 1; i >= 0; i--) {
                foreach (var p in strokes[i].points) {
                    if (Math.hypot (p.x - x, p.y - y) <= radius) {
                        strokes.remove_at (i);
                        removed = true;
                        break;
                    }
                }
            }
            if (removed) changed ();
            return removed;
        }

        public void undo () {
            if (strokes.size == 0) return;
            strokes.remove_at (strokes.size - 1);
            changed ();
        }
    }
}
