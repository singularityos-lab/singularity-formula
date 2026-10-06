namespace Singularity.Apps.Formula {

    public class InkSymbol {
        public Gee.ArrayList<InkStroke> strokes = new Gee.ArrayList<InkStroke> ();
        public InkBox box = new InkBox ();
        public Gee.List<InkCandidate> candidates = new Gee.ArrayList<InkCandidate> ();
        public string symbol = "";
        public bool forced;

        public void add (InkStroke s) {
            strokes.add (s);
            box.include (s);
        }

        public bool is_hline () {
            return box.width > 0 && box.height / double.max (box.width, 1e-3) < 0.25 && strokes.size == 1 && box.width > 3;
        }

        public bool is_dot (double ref_h) {
            return box.width < ref_h * 0.18 && box.height < ref_h * 0.18;
        }
    }

    public class InkParser : Object {
        public InkRecognizer recognizer;
        public Gee.ArrayList<InkSymbol> symbols = new Gee.ArrayList<InkSymbol> ();
        private double ref_h = 1;

        public InkParser (InkRecognizer recognizer) {
            this.recognizer = recognizer;
        }

        private static bool boxes_overlap_x (InkBox a, InkBox b, double ratio) {
            double ov = double.min (a.x1, b.x1) - double.max (a.x0, b.x0);
            double narrow = double.max (1e-3, double.min (a.width, b.width));
            return ov / narrow >= ratio;
        }

        private static bool segments_cross (InkStroke a, InkStroke b) {
            for (int i = 1; i < a.points.size; i++) {
                var p1 = a.points[i - 1];
                var p2 = a.points[i];
                for (int j = 1; j < b.points.size; j++) {
                    var q1 = b.points[j - 1];
                    var q2 = b.points[j];
                    double d1 = (q2.x - q1.x) * (p1.y - q1.y) - (q2.y - q1.y) * (p1.x - q1.x);
                    double d2 = (q2.x - q1.x) * (p2.y - q1.y) - (q2.y - q1.y) * (p2.x - q1.x);
                    double d3 = (p2.x - p1.x) * (q1.y - p1.y) - (p2.y - p1.y) * (q1.x - p1.x);
                    double d4 = (p2.x - p1.x) * (q2.y - p1.y) - (p2.y - p1.y) * (q2.x - p1.x);
                    if (((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0))) return true;
                }
            }
            return false;
        }

        private static InkBox box_of (InkStroke s) {
            var b = new InkBox ();
            b.include (s);
            return b;
        }

        private static bool is_hline_stroke (InkStroke s) {
            var b = box_of (s);
            return b.width > 0 && b.height / double.max (b.width, 1e-3) < 0.25;
        }

        private static double min_distance (InkStroke a, InkStroke b) {
            double best = double.MAX;
            int sa = int.max (1, a.points.size / 60);
            int sb2 = int.max (1, b.points.size / 60);
            for (int i = 0; i < a.points.size; i += sa) {
                var p = a.points[i];
                for (int j = 0; j < b.points.size; j += sb2) {
                    var q = b.points[j];
                    double d = Math.hypot (p.x - q.x, p.y - q.y);
                    if (d < best) best = d;
                }
            }
            return best;
        }

        public void group (Gee.List<InkStroke> strokes) {
            symbols.clear ();
            int n = strokes.size;
            if (n == 0) return;
            var dims = new Gee.ArrayList<double?> ();
            foreach (var s in strokes) {
                var b = box_of (s);
                dims.add (double.max (b.width, b.height));
            }
            dims.sort ((a, b) => a < b ? -1 : (a > b ? 1 : 0));
            double scale = double.max (dims[dims.size / 2], 4);
            double thr = double.max (2.5, scale * 0.12);
            var parent = new int[n];
            for (int i = 0; i < n; i++) parent[i] = i;
            for (int i = 0; i < n; i++) {
                for (int j = i + 1; j < n; j++) {
                    bool hi = is_hline_stroke (strokes[i]) && box_of (strokes[i]).width > scale * 1.2;
                    bool hj = is_hline_stroke (strokes[j]) && box_of (strokes[j]).width > scale * 1.2;
                    if (hi || hj) {
                        if (!segments_cross (strokes[i], strokes[j])) continue;
                        var ob = box_of (hi ? strokes[j] : strokes[i]);
                        var lb = box_of (hi ? strokes[i] : strokes[j]);
                        if (ob.height > lb.width * 0.9 || lb.width > ob.height * 2.2) continue;
                    }
                    if (min_distance (strokes[i], strokes[j]) <= thr || segments_cross (strokes[i], strokes[j])) {
                        int a = find (parent, i);
                        int b = find (parent, j);
                        if (a != b) parent[b] = a;
                    }
                }
            }
            var groups = new Gee.HashMap<int, InkSymbol> ();
            for (int i = 0; i < n; i++) {
                int r = find (parent, i);
                if (!groups.has_key (r)) groups[r] = new InkSymbol ();
                groups[r].add (strokes[i]);
            }
            var list = new Gee.ArrayList<InkSymbol> ();
            list.add_all (groups.values);
            var heights = new Gee.ArrayList<double?> ();
            foreach (var g in list) if (!g.is_hline ()) heights.add (g.box.height);
            heights.sort ((a, b) => a < b ? -1 : (a > b ? 1 : 0));
            ref_h = heights.size > 0 ? heights[heights.size / 2] : 20;
            if (ref_h < 4) ref_h = 20;
            bool merged = true;
            while (merged) {
                merged = false;
                for (int i = 0; i < list.size && !merged; i++) {
                    for (int j = 0; j < list.size && !merged; j++) {
                        if (i == j) continue;
                        var a = list[i];
                        var b = list[j];
                        if (should_merge (a, b)) {
                            foreach (var s in b.strokes) a.add (s);
                            list.remove_at (j);
                            merged = true;
                        }
                    }
                }
            }
            list.sort (cmp_x);
            symbols.add_all (list);
        }

        private static int find (int[] parent, int i) {
            while (parent[i] != i) {
                parent[i] = parent[parent[i]];
                i = parent[i];
            }
            return i;
        }

        private bool should_merge (InkSymbol a, InkSymbol b) {
            var ab = a.box;
            var bb = b.box;
            if (a.is_hline () && b.is_hline ()) {
                double wr = bb.width / double.max (ab.width, 1e-3);
                double dy = bb.cy - ab.cy;
                return wr > 0.6 && wr < 1.6 && dy > 0 && dy < ref_h * 0.6 && boxes_overlap_x (ab, bb, 0.6) && ab.width < ref_h * 2.5;
            }
            bool b_dot = bb.width < ref_h * 0.28 && bb.height < ref_h * 0.28;
            if (b_dot && !a.is_hline () && ab.width < ref_h * 0.6 && bb.cx > ab.x0 - ref_h * 0.15 && bb.cx < ab.x1 + ref_h * 0.15 && bb.y1 < ab.y0 && ab.y0 - bb.y1 < ref_h * 0.45 && ab.height > bb.height * 2) return true;
            if (b_dot && a.is_hline () && ab.width < ref_h * 1.2 && bb.cx > ab.x0 && bb.cx < ab.x1 && Math.fabs (bb.cy - ab.cy) < ref_h * 0.6) {
                int dots = 0;
                foreach (var s in a.strokes) {
                    var sbox = box_of (s);
                    if (sbox.width < ref_h * 0.28 && sbox.height < ref_h * 0.28) dots++;
                }
                return dots < 2;
            }
            return false;
        }

        private static bool segments_cross_any (InkStroke s, InkSymbol sym) {
            foreach (var t in sym.strokes) if (segments_cross (s, t)) return true;
            return false;
        }

        public void classify () {
            foreach (var sym in symbols) {
                if (sym.symbol != "" && sym.forced) continue;
                if (sym.is_dot (ref_h)) {
                    sym.candidates = new Gee.ArrayList<InkCandidate> ();
                    sym.candidates.add (new InkCandidate (".", 0));
                    sym.candidates.add (new InkCandidate ("⋅", 0.1));
                    sym.symbol = ".";
                    continue;
                }
                if (sym.is_hline ()) {
                    sym.candidates = new Gee.ArrayList<InkCandidate> ();
                    sym.candidates.add (new InkCandidate ("−", 0));
                    sym.candidates.add (new InkCandidate ("_", 0.1));
                    sym.symbol = "−";
                    continue;
                }
                sym.candidates = recognizer.classify (sym.strokes, 6);
                sym.symbol = sym.candidates.size > 0 ? sym.candidates[0].symbol : "?";
                if (sym.candidates.size > 1) {
                    var top = sym.candidates[0];
                    unichar tc = top.symbol.get_char (0);
                    foreach (var cand in sym.candidates) {
                        if (cand.score > top.score * 1.25) break;
                        unichar cc = cand.symbol.get_char (0);
                        if (tc.isupper () && cc == tc.tolower () && sym.box.height < ref_h * 1.15) {
                            sym.symbol = cand.symbol;
                            break;
                        }
                        if (top.symbol == "Σ" && cand.symbol == "∑") {
                            sym.symbol = cand.symbol;
                            break;
                        }
                    }
                }
            }
        }

        public string recognize (Gee.List<InkStroke> strokes) {
            group (strokes);
            classify ();
            return to_latex ();
        }

        public string to_latex () {
            var list = new Gee.ArrayList<InkSymbol> ();
            list.add_all (symbols);
            return parse_region (list);
        }

        private static string tex_of (string sym) {
            switch (sym) {
                case "−": return "-";
                case "{": return "\\{";
                case "}": return "\\}";
                case "′": return "'";
                case "√": return "\\surd ";
                case "|": return "|";
                case ".": return ".";
                case ",": return ",";
                default: break;
            }
            unichar c = sym.get_char (0);
            if (c < 0x80) return sym;
            string? cmd = Symbols.command_for_char (sym);
            if (cmd != null) return "\\" + cmd + " ";
            return sym;
        }

        private static int cmp_x (InkSymbol a, InkSymbol b) {
            return a.box.x0 < b.box.x0 ? -1 : (a.box.x0 > b.box.x0 ? 1 : 0);
        }

        private string parse_region (Gee.ArrayList<InkSymbol> items) {
            if (items.size == 0) return "";
            items.sort (cmp_x);
            InkSymbol? bar = null;
            foreach (var s in items) {
                if (s.symbol != "−" || !s.is_hline ()) continue;
                bool above = false, below = false;
                foreach (var o in items) {
                    if (o == s) continue;
                    if (o.box.cx < s.box.x0 || o.box.cx > s.box.x1) continue;
                    if (o.box.cy < s.box.cy) above = true;
                    else below = true;
                }
                if (above && below && (bar == null || s.box.width > bar.box.width)) bar = s;
            }
            if (bar != null) {
                var num = new Gee.ArrayList<InkSymbol> ();
                var den = new Gee.ArrayList<InkSymbol> ();
                var left = new Gee.ArrayList<InkSymbol> ();
                var right = new Gee.ArrayList<InkSymbol> ();
                foreach (var o in items) {
                    if (o == bar) continue;
                    if (o.box.cx >= bar.box.x0 && o.box.cx <= bar.box.x1) {
                        if (o.box.cy < bar.box.cy) num.add (o);
                        else den.add (o);
                    } else if (o.box.cx < bar.box.x0) {
                        left.add (o);
                    } else {
                        right.add (o);
                    }
                }
                return parse_region (left) + "\\frac{" + parse_region (num) + "}{" + parse_region (den) + "}" + parse_region (right);
            }
            foreach (var s in items) {
                if (s.symbol != "√") continue;
                var inside = new Gee.ArrayList<InkSymbol> ();
                var rest = new Gee.ArrayList<InkSymbol> ();
                foreach (var o in items) {
                    if (o == s) continue;
                    if (o.box.cx > s.box.x0 + s.box.width * 0.25 && o.box.cx < s.box.x1 && o.box.cy > s.box.y0 && o.box.cy < s.box.y1) inside.add (o);
                    else rest.add (o);
                }
                if (inside.size == 0) continue;
                var before = new Gee.ArrayList<InkSymbol> ();
                var after = new Gee.ArrayList<InkSymbol> ();
                foreach (var o in rest) {
                    if (o.box.cx < s.box.x0) before.add (o);
                    else after.add (o);
                }
                return parse_region (before) + "\\sqrt{" + parse_region (inside) + "}" + parse_region (after);
            }
            return baseline (items);
        }

        private string baseline (Gee.ArrayList<InkSymbol> items) {
            var sb = new StringBuilder ();
            int i = 0;
            InkSymbol? prev = null;
            while (i < items.size) {
                var s = items[i];
                bool large = s.symbol == "∑" || s.symbol == "∫";
                if (large) {
                    var above = new Gee.ArrayList<InkSymbol> ();
                    var below = new Gee.ArrayList<InkSymbol> ();
                    int j = i + 1;
                    while (j < items.size) {
                        var o = items[j];
                        bool over_x = o.box.cx <= s.box.x1 + s.box.width * 0.4;
                        if (over_x && o.box.y1 < s.box.y0 + s.box.height * 0.25) above.add (o);
                        else if (over_x && o.box.y0 > s.box.y1 - s.box.height * 0.25) below.add (o);
                        else break;
                        j++;
                    }
                    sb.append (s.symbol == "∑" ? "\\sum" : "\\int");
                    if (below.size > 0) sb.append ("_{").append (parse_region (below)).append ("}");
                    if (above.size > 0) sb.append ("^{").append (parse_region (above)).append ("}");
                    sb.append (" ");
                    prev = null;
                    i = j;
                    continue;
                }
                sb.append (tex_of (s.symbol));
                int j = i + 1;
                var sup = new Gee.ArrayList<InkSymbol> ();
                var sub = new Gee.ArrayList<InkSymbol> ();
                double h = double.max (s.box.height, ref_h * 0.5);
                bool base_ok = s.symbol != "(" && s.symbol != "=" && s.symbol != "+" && s.symbol != "−" && s.symbol != "<" && s.symbol != ">";
                while (base_ok && j < items.size) {
                    var o = items[j];
                    if (o.symbol == "=" || o.symbol == "<" || o.symbol == ">" || o.symbol == "≤" || o.symbol == "≥" || o.symbol == "≠") break;
                    bool smaller = o.box.height < h * 0.85 || o.is_dot (ref_h);
                    if (smaller && o.box.y1 < s.box.y0 + h * 0.55 && o.box.cy < s.box.cy - h * 0.2 && sub.size == 0) {
                        sup.add (o);
                    } else if (smaller && o.box.y0 > s.box.y0 + h * 0.45 && o.box.cy > s.box.cy + h * 0.2 && !o.is_dot (ref_h) && sup.size == 0) {
                        sub.add (o);
                    } else if (sup.size > 0 && o.box.cy < s.box.cy - h * 0.2 && o.box.height < h * 0.85) {
                        sup.add (o);
                    } else if (sub.size > 0 && o.box.cy > s.box.cy + h * 0.2 && o.box.height < h * 0.85) {
                        sub.add (o);
                    } else {
                        break;
                    }
                    j++;
                }
                if (sub.size > 0) sb.append ("_{").append (parse_region (sub)).append ("}");
                if (sup.size > 0) sb.append ("^{").append (parse_region (sup)).append ("}");
                prev = s;
                i = j;
            }
            return sb.str;
        }

        public InkSymbol? symbol_at (double x, double y) {
            foreach (var s in symbols) if (s.box.contains_point (x, y, 6)) return s;
            return null;
        }
    }
}
