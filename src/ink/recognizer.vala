namespace Singularity.Apps.Formula {

    public class InkTemplate {
        public string symbol;
        public InkPoint[] cloud;
        public double aspect;
        public bool user;

        public InkTemplate (string symbol, InkPoint[] cloud, double aspect, bool user = false) {
            this.symbol = symbol;
            this.cloud = cloud;
            this.aspect = aspect;
            this.user = user;
        }
    }

    public class InkCandidate {
        public string symbol;
        public double score;

        public InkCandidate (string symbol, double score) {
            this.symbol = symbol;
            this.score = score;
        }
    }

    public class InkRecognizer : Object {
        public const int N = 40;
        public const string SYMBOLS = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZαβγδεθλμπρσφωΔΣΩ+−=<>≤≥≠±()[]{}|,.!/√∑∫∞∂′";

        private static InkRecognizer? instance;
        public Gee.ArrayList<InkTemplate> templates = new Gee.ArrayList<InkTemplate> ();
        public string? user_path;

        public static InkRecognizer get_default () {
            if (instance == null) {
                var fonts = new Gee.ArrayList<MathFont> ();
                fonts.add (MathFont.get_default (null));
                foreach (var fam in new string[] { "DejaVu Serif", "DejaVu Sans", "Latin Modern Math", "STIX Two Math", "FreeSerif", "Inter", "Cantarell", "Noto Sans", "Liberation Sans" }) {
                    string matched;
                    string? file = MathFont.find_file (fam, out matched);
                    if (file == null || matched != fam) continue;
                    var f = MathFont.load_file (file, fam, false);
                    if (f != null && f.family != fonts[0].family) fonts.add (f);
                    if (fonts.size >= 6) break;
                }
                instance = new InkRecognizer.from_fonts (fonts);
                instance.user_path = Path.build_filename (Environment.get_user_data_dir (), "singularity-formula", "ink-templates.json");
                instance.load_user ();
            }
            return instance;
        }

        public InkRecognizer.from_fonts (Gee.List<MathFont> fonts) {
            int i = 0;
            unichar c;
            while (SYMBOLS.get_next_char (ref i, out c)) {
                string ch = c.to_string ();
                foreach (var f in fonts) {
                    add_glyph_template (f, ch, false);
                    if (c.isalpha () && c < 0x80) add_glyph_template (f, ch, true);
                }
            }
        }

        private void add_glyph_template (MathFont f, string ch, bool italic) {
            var strokes = glyph_strokes (f, ch, italic);
            if (strokes == null || strokes.size == 0) return;
            double aspect;
            var cloud = normalize (strokes, out aspect);
            if (cloud == null) return;
            templates.add (new InkTemplate (ch, cloud, aspect));
        }

        public static Gee.ArrayList<InkStroke>? glyph_strokes (MathFont f, string ch, bool italic, int size = 64, bool fit = true) {
            unichar c = ch.get_char (0);
            unichar use = c;
            if (italic) {
                unichar it = Unimath.styled (c, MathVariant.ITALIC);
                if (it != c && f.has_char (it)) use = it;
                else return null;
            }
            uint g = f.glyph (use);
            if (g == 0 || f.face == null) return null;
            var surf = new Cairo.ImageSurface (Cairo.Format.A8, size, size);
            var cr = new Cairo.Context (surf);
            cr.set_font_face (f.face);
            cr.set_font_size (100);
            Cairo.Glyph[] glyphs = new Cairo.Glyph[1];
            glyphs[0].index = g;
            glyphs[0].x = 0;
            glyphs[0].y = 0;
            Cairo.TextExtents ext;
            cr.glyph_extents (glyphs, out ext);
            if (ext.width <= 0 && ext.height <= 0) return null;
            double box = size * 0.78;
            double k = box / double.max (double.max (ext.width, ext.height), 1);
            if (!fit) k = size * 0.7 / 100.0;
            cr.set_font_size (100 * k);
            glyphs[0].x = fit ? (size - ext.width * k) / 2 - ext.x_bearing * k : size * 0.1 - ext.x_bearing * k;
            glyphs[0].y = fit ? (size - ext.height * k) / 2 - ext.y_bearing * k : size * 0.78;
            cr.set_source_rgba (0, 0, 0, 1);
            cr.show_glyphs (glyphs);
            surf.flush ();
            unowned uint8[] data = surf.get_data ();
            int stride = surf.get_stride ();
            var grid = new bool[size * size];
            for (int y = 0; y < size; y++) {
                for (int x = 0; x < size; x++) grid[y * size + x] = data[y * stride + x] > 110;
            }
            thin (grid, size, size);
            return trace (grid, size, size);
        }

        public static void thin (bool[] g, int w, int h) {
            bool changed = true;
            var remove = new Gee.ArrayList<int> ();
            while (changed) {
                changed = false;
                for (int pass = 0; pass < 2; pass++) {
                    remove.clear ();
                    for (int y = 1; y < h - 1; y++) {
                        for (int x = 1; x < w - 1; x++) {
                            if (!g[y * w + x]) continue;
                            bool p2 = g[(y - 1) * w + x], p3 = g[(y - 1) * w + x + 1], p4 = g[y * w + x + 1], p5 = g[(y + 1) * w + x + 1];
                            bool p6 = g[(y + 1) * w + x], p7 = g[(y + 1) * w + x - 1], p8 = g[y * w + x - 1], p9 = g[(y - 1) * w + x - 1];
                            int b = (int) p2 + (int) p3 + (int) p4 + (int) p5 + (int) p6 + (int) p7 + (int) p8 + (int) p9;
                            if (b < 2 || b > 6) continue;
                            bool[] seq = { p2, p3, p4, p5, p6, p7, p8, p9, p2 };
                            int a = 0;
                            for (int i = 0; i < 8; i++) if (!seq[i] && seq[i + 1]) a++;
                            if (a != 1) continue;
                            if (pass == 0) {
                                if (p2 && p4 && p6) continue;
                                if (p4 && p6 && p8) continue;
                            } else {
                                if (p2 && p4 && p8) continue;
                                if (p2 && p6 && p8) continue;
                            }
                            remove.add (y * w + x);
                        }
                    }
                    foreach (int i in remove) g[i] = false;
                    if (remove.size > 0) changed = true;
                }
            }
        }

        private static int degree (bool[] g, bool[] used, int w, int h, int x, int y) {
            int n = 0;
            for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                    if (dx == 0 && dy == 0) continue;
                    int nx = x + dx;
                    int ny = y + dy;
                    if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                    if (g[ny * w + nx] && !used[ny * w + nx]) n++;
                }
            }
            return n;
        }

        public static Gee.ArrayList<InkStroke> trace (bool[] g, int w, int h) {
            var strokes = new Gee.ArrayList<InkStroke> ();
            var used = new bool[w * h];
            while (true) {
                int start = -1;
                for (int i = 0; i < w * h && start < 0; i++) {
                    if (g[i] && !used[i] && degree (g, used, w, h, i % w, i / w) <= 1) start = i;
                }
                for (int i = 0; i < w * h && start < 0; i++) if (g[i] && !used[i]) start = i;
                if (start < 0) break;
                var s = new InkStroke ();
                int x = start % w;
                int y = start / w;
                while (true) {
                    used[y * w + x] = true;
                    s.add (x, y);
                    int bx = -1, by = -1;
                    for (int k = 0; k < 8 && bx < 0; k++) {
                        int dx = k == 0 ? 1 : (k == 1 ? 0 : (k == 2 ? -1 : (k == 3 ? 0 : (k == 4 ? 1 : (k == 5 ? -1 : (k == 6 ? 1 : -1))))));
                        int dy = k == 0 ? 0 : (k == 1 ? 1 : (k == 2 ? 0 : (k == 3 ? -1 : (k == 4 ? 1 : (k == 5 ? 1 : (k == 6 ? -1 : -1))))));
                        int nx = x + dx;
                        int ny = y + dy;
                        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                        if (g[ny * w + nx] && !used[ny * w + nx]) {
                            bx = nx;
                            by = ny;
                        }
                    }
                    if (bx < 0) break;
                    x = bx;
                    y = by;
                }
                if (s.points.size >= 2 || strokes.size == 0) strokes.add (s);
            }
            return strokes;
        }

        public static InkPoint[]? normalize (Gee.List<InkStroke> strokes, out double aspect) {
            aspect = 1;
            double total = 0;
            int count = 0;
            var box = new InkBox ();
            foreach (var s in strokes) {
                if (s.points.size == 0) continue;
                total += s.length ();
                count++;
                box.include (s);
            }
            if (count == 0) return null;
            aspect = (box.height + 1e-3) / (box.width + 1e-3);
            var pts = new Gee.ArrayList<InkPoint?> ();
            int remaining = N;
            int idx = 0;
            foreach (var s in strokes) {
                if (s.points.size == 0) continue;
                idx++;
                int k;
                if (idx == count) k = remaining;
                else k = total > 0 ? (int) Math.round (N * s.length () / total) : N / count;
                k = int.max (1, int.min (k, remaining - (count - idx)));
                remaining -= k;
                resample_into (s, k, pts);
            }
            while (pts.size < N) pts.add (pts[pts.size - 1]);
            double scale = double.max (box.width, box.height);
            if (scale <= 0) scale = 1;
            double cx = 0, cy = 0;
            foreach (var p in pts) {
                cx += p.x;
                cy += p.y;
            }
            cx /= pts.size;
            cy /= pts.size;
            var res = new InkPoint[N];
            for (int i = 0; i < N; i++) res[i] = InkPoint ((pts[i].x - cx) / scale, (pts[i].y - cy) / scale);
            return res;
        }

        private static void resample_into (InkStroke s, int k, Gee.ArrayList<InkPoint?> out_pts) {
            double len = s.length ();
            if (k <= 1 || len <= 0 || s.points.size < 2) {
                for (int i = 0; i < k; i++) out_pts.add (s.points[0]);
                return;
            }
            double step = len / (k - 1);
            out_pts.add (s.points[0]);
            int added = 1;
            double acc = 0;
            var prev = s.points[0];
            for (int i = 1; i < s.points.size && added < k; i++) {
                var cur = s.points[i];
                double d = Math.hypot (cur.x - prev.x, cur.y - prev.y);
                while (acc + d >= step && added < k) {
                    double t = (step - acc) / d;
                    var q = InkPoint (prev.x + t * (cur.x - prev.x), prev.y + t * (cur.y - prev.y));
                    out_pts.add (q);
                    added++;
                    d = Math.hypot (cur.x - q.x, cur.y - q.y);
                    prev = q;
                    acc = 0;
                }
                acc += d;
                prev = cur;
            }
            while (added < k) {
                out_pts.add (s.points[s.points.size - 1]);
                added++;
            }
        }

        private static double cloud_distance (InkPoint[] a, InkPoint[] b, int start) {
            var matched = new bool[N];
            double sum = 0;
            int i = start;
            do {
                int best = -1;
                double min = double.MAX;
                for (int j = 0; j < N; j++) {
                    if (matched[j]) continue;
                    double d = Math.hypot (a[i].x - b[j].x, a[i].y - b[j].y);
                    if (d < min) {
                        min = d;
                        best = j;
                    }
                }
                matched[best] = true;
                double weight = 1.0 - ((i - start + N) % N) / (double) N;
                sum += weight * min;
                i = (i + 1) % N;
            } while (i != start);
            return sum;
        }

        public static double match (InkPoint[] a, InkPoint[] b) {
            int step = (int) Math.floor (Math.pow (N, 0.5));
            double min = double.MAX;
            for (int i = 0; i < N; i += step) {
                min = double.min (min, cloud_distance (a, b, i));
                min = double.min (min, cloud_distance (b, a, i));
            }
            return min;
        }

        public Gee.List<InkCandidate> classify (Gee.List<InkStroke> strokes, int top = 5) {
            var result = new Gee.ArrayList<InkCandidate> ();
            double aspect;
            var cloud = normalize (strokes, out aspect);
            if (cloud == null) return result;
            var best = new Gee.HashMap<string, double?> ();
            var coarse = new Gee.ArrayList<InkTemplate> ();
            var coarse_score = new Gee.HashMap<InkTemplate, double?> ();
            foreach (var t in templates) {
                double ar = Math.fabs (Math.log (aspect) - Math.log (t.aspect));
                coarse_score[t] = cloud_distance (cloud, t.cloud, 0) + 0.6 * double.min (ar, 3.0) * N * 0.5;
                coarse.add (t);
            }
            coarse.sort ((x, y) => coarse_score[x] < coarse_score[y] ? -1 : (coarse_score[x] > coarse_score[y] ? 1 : 0));
            while (coarse.size > 80) coarse.remove_at (coarse.size - 1);
            foreach (var t in coarse) {
                double d = match (cloud, t.cloud);
                double ar = Math.fabs (Math.log (aspect) - Math.log (t.aspect));
                d += 0.6 * double.min (ar, 3.0);
                if (t.user) d *= 0.85;
                if (!best.has_key (t.symbol) || best[t.symbol] > d) best[t.symbol] = d;
            }
            foreach (var e in best.entries) result.add (new InkCandidate (e.key, e.value));
            result.sort ((x, y) => x.score < y.score ? -1 : (x.score > y.score ? 1 : 0));
            while (result.size > top) result.remove_at (result.size - 1);
            return result;
        }

        public void learn (string symbol, Gee.List<InkStroke> strokes) {
            double aspect;
            var cloud = normalize (strokes, out aspect);
            if (cloud == null) return;
            templates.add (new InkTemplate (symbol, cloud, aspect, true));
            save_user ();
        }

        public int user_template_count () {
            int n = 0;
            foreach (var t in templates) if (t.user) n++;
            return n;
        }

        public void forget_user () {
            for (int i = templates.size - 1; i >= 0; i--) if (templates[i].user) templates.remove_at (i);
            save_user ();
        }

        private void load_user () {
            if (user_path == null || !FileUtils.test (user_path, FileTest.EXISTS)) return;
            try {
                var parser = new Json.Parser ();
                parser.load_from_file (user_path);
                var root = parser.get_root ();
                if (root == null || root.get_node_type () != Json.NodeType.ARRAY) return;
                foreach (var n in root.get_array ().get_elements ()) {
                    var o = n.get_object ();
                    var arr = o.get_array_member ("points");
                    if (arr.get_length () != N) continue;
                    var cloud = new InkPoint[N];
                    for (int i = 0; i < N; i++) {
                        var p = arr.get_array_element (i);
                        cloud[i] = InkPoint (p.get_double_element (0), p.get_double_element (1));
                    }
                    templates.add (new InkTemplate (o.get_string_member ("symbol"), cloud, o.get_double_member ("aspect"), true));
                }
            } catch (Error e) {
                warning ("ink templates: %s", e.message);
            }
        }

        private void save_user () {
            if (user_path == null) return;
            var b = new Json.Builder ();
            b.begin_array ();
            foreach (var t in templates) {
                if (!t.user) continue;
                b.begin_object ();
                b.set_member_name ("symbol");
                b.add_string_value (t.symbol);
                b.set_member_name ("aspect");
                b.add_double_value (t.aspect);
                b.set_member_name ("points");
                b.begin_array ();
                foreach (var p in t.cloud) {
                    b.begin_array ();
                    b.add_double_value (p.x);
                    b.add_double_value (p.y);
                    b.end_array ();
                }
                b.end_array ();
                b.end_object ();
            }
            b.end_array ();
            var gen = new Json.Generator ();
            gen.set_root (b.get_root ());
            try {
                DirUtils.create_with_parents (Path.get_dirname (user_path), 0700);
                FileUtils.set_contents (user_path, gen.to_data (null));
            } catch (Error e) {
                warning ("ink templates: %s", e.message);
            }
        }
    }
}
