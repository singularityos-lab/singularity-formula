namespace Singularity.Apps.Formula {

    public enum MathConst {
        SCRIPT_PERCENT_SCALE_DOWN = 0,
        SCRIPT_SCRIPT_PERCENT_SCALE_DOWN = 1,
        DELIMITED_SUB_FORMULA_MIN_HEIGHT = 2,
        DISPLAY_OPERATOR_MIN_HEIGHT = 3,
        MATH_LEADING = 4,
        AXIS_HEIGHT = 5,
        ACCENT_BASE_HEIGHT = 6,
        FLATTENED_ACCENT_BASE_HEIGHT = 7,
        SUBSCRIPT_SHIFT_DOWN = 8,
        SUBSCRIPT_TOP_MAX = 9,
        SUBSCRIPT_BASELINE_DROP_MIN = 10,
        SUPERSCRIPT_SHIFT_UP = 11,
        SUPERSCRIPT_SHIFT_UP_CRAMPED = 12,
        SUPERSCRIPT_BOTTOM_MIN = 13,
        SUPERSCRIPT_BASELINE_DROP_MAX = 14,
        SUB_SUPERSCRIPT_GAP_MIN = 15,
        SUPERSCRIPT_BOTTOM_MAX_WITH_SUBSCRIPT = 16,
        SPACE_AFTER_SCRIPT = 17,
        UPPER_LIMIT_GAP_MIN = 18,
        UPPER_LIMIT_BASELINE_RISE_MIN = 19,
        LOWER_LIMIT_GAP_MIN = 20,
        LOWER_LIMIT_BASELINE_DROP_MIN = 21,
        STACK_TOP_SHIFT_UP = 22,
        STACK_TOP_DISPLAY_STYLE_SHIFT_UP = 23,
        STACK_BOTTOM_SHIFT_DOWN = 24,
        STACK_BOTTOM_DISPLAY_STYLE_SHIFT_DOWN = 25,
        STACK_GAP_MIN = 26,
        STACK_DISPLAY_STYLE_GAP_MIN = 27,
        STRETCH_STACK_TOP_SHIFT_UP = 28,
        STRETCH_STACK_BOTTOM_SHIFT_DOWN = 29,
        STRETCH_STACK_GAP_ABOVE_MIN = 30,
        STRETCH_STACK_GAP_BELOW_MIN = 31,
        FRACTION_NUMERATOR_SHIFT_UP = 32,
        FRACTION_NUMERATOR_DISPLAY_STYLE_SHIFT_UP = 33,
        FRACTION_DENOMINATOR_SHIFT_DOWN = 34,
        FRACTION_DENOMINATOR_DISPLAY_STYLE_SHIFT_DOWN = 35,
        FRACTION_NUMERATOR_GAP_MIN = 36,
        FRACTION_NUM_DISPLAY_STYLE_GAP_MIN = 37,
        FRACTION_RULE_THICKNESS = 38,
        FRACTION_DENOMINATOR_GAP_MIN = 39,
        FRACTION_DENOM_DISPLAY_STYLE_GAP_MIN = 40,
        SKEWED_FRACTION_HORIZONTAL_GAP = 41,
        SKEWED_FRACTION_VERTICAL_GAP = 42,
        OVERBAR_VERTICAL_GAP = 43,
        OVERBAR_RULE_THICKNESS = 44,
        OVERBAR_EXTRA_ASCENDER = 45,
        UNDERBAR_VERTICAL_GAP = 46,
        UNDERBAR_RULE_THICKNESS = 47,
        UNDERBAR_EXTRA_DESCENDER = 48,
        RADICAL_VERTICAL_GAP = 49,
        RADICAL_DISPLAY_STYLE_VERTICAL_GAP = 50,
        RADICAL_RULE_THICKNESS = 51,
        RADICAL_EXTRA_ASCENDER = 52,
        RADICAL_KERN_BEFORE_DEGREE = 53,
        RADICAL_KERN_AFTER_DEGREE = 54,
        RADICAL_DEGREE_BOTTOM_RAISE_PERCENT = 55,
        COUNT = 56
    }

    public struct GlyphPart {
        public uint glyph;
        public double start_connector;
        public double end_connector;
        public double full_advance;
        public bool extender;
    }

    public class Shaped {
        public uint[] glyphs = {};
        public double[] advances = {};
        public uint[] clusters = {};
    }

    public class MathFont : Object {
        public const string[] PREFERRED = {
            "STIX Two Math", "Latin Modern Math", "STIX Math", "TeX Gyre Termes Math", "TeX Gyre Pagella Math",
            "TeX Gyre Schola Math", "TeX Gyre Bonum Math", "TeX Gyre DejaVu Math", "DejaVu Math TeX Gyre",
            "Libertinus Math", "Fira Math", "Garamond Math", "Noto Sans Math", "XITS Math", "Asana Math", "Cambria Math"
        };

        private static Gee.HashMap<string, MathFont>? cache;
        private static bool fc_ready;
        private static FT.Library ft_lib;
        private static bool ft_ready;
        private static Gee.ArrayList<string>? families_cache;

        public string family { get; private set; }
        public string path { get; private set; }
        public bool has_math { get; private set; }
        public double upem { get; private set; }
        public Cairo.FontFace face;
        private Hb.Blob blob;
        private Hb.Face hb_face;
        private Hb.Font hb_font;
        private double[] constants = new double[MathConst.COUNT];
        private Gee.HashMap<string, Shaped> shape_cache = new Gee.HashMap<string, Shaped> ();

        private MathFont () {
        }

        private static void init_libs () {
            if (!fc_ready) {
                Fc.init ();
                fc_ready = true;
            }
            if (!ft_ready) {
                FT.init (out ft_lib);
                ft_ready = true;
            }
        }

        public static string? find_file (string family, out string matched_family) {
            init_libs ();
            matched_family = "";
            var pat = new Fc.Pattern.parse (family);
            Fc.config_substitute (null, pat, 0);
            Fc.default_substitute (pat);
            int result;
            var m = Fc.font_match (null, pat, out result);
            if (m == null) return null;
            unowned string file;
            unowned string fam;
            if (m.get_string ("file", 0, out file) != 0) return null;
            if (m.get_string ("family", 0, out fam) == 0) matched_family = fam;
            return file;
        }

        public static Gee.List<string> math_families () {
            if (families_cache != null) return families_cache;
            init_libs ();
            families_cache = new Gee.ArrayList<string> ();
            var seen = new Gee.HashSet<string> ();
            var pat = new Fc.Pattern ();
            var os = new Fc.ObjectSet ();
            os.add ("family");
            os.add ("file");
            var set = Fc.font_list (null, pat, os);
            if (set != null) {
                for (int i = 0; i < set.nfont; i++) {
                    unowned string fam;
                    unowned string file;
                    if (set.fonts[i].get_string ("family", 0, out fam) != 0) continue;
                    if (set.fonts[i].get_string ("file", 0, out file) != 0) continue;
                    if (seen.contains (fam)) continue;
                    if (!fam.down ().contains ("math")) continue;
                    var b = new Hb.Blob.from_file (file);
                    if (b.get_length () == 0) continue;
                    var f = new Hb.Face (b, 0);
                    if (!Hb.math_has_data (f)) continue;
                    seen.add (fam);
                    families_cache.add (fam);
                }
            }
            families_cache.sort ((a, b) => a.collate (b));
            return families_cache;
        }

        public static MathFont get_default (string? preferred = null) {
            if (cache == null) cache = new Gee.HashMap<string, MathFont> ();
            string key = preferred ?? "";
            if (cache.has_key (key)) return cache[key];
            MathFont? font = null;
            if (preferred != null && preferred != "") font = try_family (preferred, true);
            if (font == null) {
                foreach (var fam in PREFERRED) {
                    font = try_family (fam, true);
                    if (font != null) break;
                }
            }
            if (font == null) {
                foreach (var fam in math_families ()) {
                    font = try_family (fam, true);
                    if (font != null) break;
                }
            }
            if (font == null) font = try_family ("serif", false);
            if (font == null) font = new MathFont.empty ();
            cache[key] = font;
            return font;
        }

        public static MathFont? fallback_text_font () {
            if (cache == null) cache = new Gee.HashMap<string, MathFont> ();
            if (cache.has_key ("\ttext")) return cache["\ttext"];
            var f = try_family ("serif", false);
            if (f != null) cache["\ttext"] = f;
            return f;
        }

        private MathFont.empty () {
            family = "";
            path = "";
            has_math = false;
            upem = 1000;
            synthesize_constants ();
        }

        private static MathFont? try_family (string fam, bool need_math) {
            string matched;
            string? file = find_file (fam, out matched);
            if (file == null) return null;
            if (need_math && matched.down () != fam.down ()) return null;
            return load_file (file, matched, need_math);
        }

        public static MathFont? load_file (string file, string family, bool need_math) {
            init_libs ();
            var f = new MathFont ();
            f.path = file;
            f.family = family;
            f.blob = new Hb.Blob.from_file (file);
            if (f.blob.get_length () == 0) return null;
            f.hb_face = new Hb.Face (f.blob, 0);
            f.has_math = Hb.math_has_data (f.hb_face);
            if (need_math && !f.has_math) return null;
            f.upem = f.hb_face.get_upem ();
            f.hb_font = new Hb.Font (f.hb_face);
            f.hb_font.set_scale ((int) f.upem, (int) f.upem);
            FT.Face ftf;
            if (FT.new_face (ft_lib, file, 0, out ftf) != 0) return null;
            f.face = CairoFt.create_font_face (ftf, 0);
            if (f.has_math) {
                for (int i = 0; i < MathConst.COUNT; i++) {
                    int32 v = Hb.math_constant (f.hb_font, i);
                    if (i <= 1 || i == MathConst.RADICAL_DEGREE_BOTTOM_RAISE_PERCENT) f.constants[i] = v;
                    else f.constants[i] = v / f.upem;
                }
                if (f.constants[0] <= 0) f.constants[0] = 70;
                if (f.constants[1] <= 0) f.constants[1] = 50;
            } else {
                f.synthesize_constants ();
            }
            return f;
        }

        private void synthesize_constants () {
            double[] c = {
                70, 50, 1.3, 1.3, 0.15, 0.25, 0.45, 0.66,
                0.15, 0.35, 0.2, 0.41, 0.33, 0.11, 0.25, 0.16,
                0.35, 0.05, 0.11, 0.2, 0.17, 0.6, 0.44, 0.68,
                0.34, 0.69, 0.12, 0.28, 0.11, 0.6, 0.2, 0.17,
                0.39, 0.68, 0.34, 0.69, 0.04, 0.12, 0.04, 0.04,
                0.12, 0.35, 0.1, 0.12, 0.04, 0.04, 0.12, 0.04,
                0.04, 0.05, 0.15, 0.04, 0.04, 0.28, -0.56, 60
            };
            for (int i = 0; i < MathConst.COUNT; i++) constants[i] = c[i];
            if (hb_font != null) {
                uint g = glyph ('x');
                if (g != 0) {
                    double asc, desc, l, r;
                    extents (g, out asc, out desc, out l, out r);
                    constants[MathConst.ACCENT_BASE_HEIGHT] = asc;
                }
                uint p = glyph ('+');
                if (p != 0) {
                    double asc, desc, l, r;
                    extents (p, out asc, out desc, out l, out r);
                    constants[MathConst.AXIS_HEIGHT] = (asc - desc) / 2.0;
                }
            }
        }

        public double get (MathConst c) {
            return constants[c];
        }

        public double script_scale (int level) {
            if (level <= 0) return 1.0;
            if (level == 1) return constants[0] / 100.0;
            double s = constants[1] / 100.0;
            for (int i = 2; i < level; i++) s *= constants[0] / 100.0;
            return s;
        }

        public uint glyph (unichar c) {
            if (hb_font == null) return 0;
            uint32 g;
            if (!hb_font.get_nominal_glyph ((uint32) c, out g)) return 0;
            return g;
        }

        public bool has_char (unichar c) {
            return glyph (c) != 0;
        }

        public Shaped shape (string text, int script_level) {
            if (hb_font == null) return new Shaped ();
            string key = "%d:%s".printf (script_level, text);
            if (shape_cache.has_key (key)) return shape_cache[key];
            var buf = new Hb.Buffer ();
            buf.add_utf8 (text, -1, 0, -1);
            buf.guess_segment_properties ();
            buf.set_direction (Hb.Direction.LTR);
            Hb.Feature[] feats = {};
            if (script_level > 0 && has_math) {
                Hb.Feature f;
                if (Hb.feature_from_string ("ssty=%d".printf (int.min (script_level, 2)), -1, out f)) feats += f;
            }
            Hb.shape (hb_font, buf, feats);
            unowned Hb.GlyphInfo[] infos = buf.get_glyph_infos ();
            unowned Hb.GlyphPosition[] pos = buf.get_glyph_positions ();
            var res = new Shaped ();
            uint[] gl = new uint[infos.length];
            double[] adv = new double[infos.length];
            uint[] cl = new uint[infos.length];
            for (int i = 0; i < infos.length; i++) {
                gl[i] = infos[i].codepoint;
                adv[i] = pos[i].x_advance / upem;
                cl[i] = infos[i].cluster;
            }
            res.glyphs = gl;
            res.advances = adv;
            res.clusters = cl;
            shape_cache[key] = res;
            return res;
        }

        public double advance (uint g) {
            if (hb_font == null) return 0.5;
            return hb_font.get_glyph_h_advance (g) / upem;
        }

        public void extents (uint g, out double ascent, out double descent, out double left, out double right) {
            ascent = 0;
            descent = 0;
            left = 0;
            right = 0;
            if (hb_font == null) return;
            Hb.GlyphExtents e;
            if (!hb_font.get_glyph_extents (g, out e)) return;
            ascent = e.y_bearing / upem;
            descent = -(e.y_bearing + e.height) / upem;
            left = e.x_bearing / upem;
            right = (e.x_bearing + e.width) / upem;
        }

        public double italic (uint g) {
            if (!has_math) return 0;
            return Hb.math_italics_correction (hb_font, g) / upem;
        }

        public double top_accent (uint g) {
            if (!has_math) return advance (g) / 2.0;
            return Hb.math_top_accent_attachment (hb_font, g) / upem;
        }

        public bool is_extended_shape (uint g) {
            if (!has_math) return false;
            return Hb.math_is_extended_shape (hb_face, g);
        }

        public double min_connector_overlap (bool vertical) {
            if (!has_math) return 0;
            return Hb.math_min_connector_overlap (hb_font, vertical ? Hb.Direction.BTT : Hb.Direction.LTR) / upem;
        }

        public void variants (uint g, bool vertical, out uint[] glyphs, out double[] sizes) {
            glyphs = {};
            sizes = {};
            if (!has_math) return;
            var list = new Hb.MathGlyphVariant[64];
            uint count = 64;
            Hb.math_glyph_variants (hb_font, g, vertical ? Hb.Direction.BTT : Hb.Direction.LTR, 0, ref count, list);
            uint[] gl = {};
            double[] sz = {};
            for (uint i = 0; i < count && i < 64; i++) {
                gl += list[i].glyph;
                sz += list[i].advance / upem;
            }
            glyphs = gl;
            sizes = sz;
        }

        public GlyphPart[] assembly (uint g, bool vertical, out double italic_correction) {
            italic_correction = 0;
            GlyphPart[] res = {};
            if (!has_math) return res;
            var parts = new Hb.MathGlyphPart[32];
            uint count = 32;
            int32 ic;
            Hb.math_glyph_assembly (hb_font, g, vertical ? Hb.Direction.BTT : Hb.Direction.LTR, 0, ref count, parts, out ic);
            italic_correction = ic / upem;
            for (uint i = 0; i < count && i < 32; i++) {
                var p = GlyphPart ();
                p.glyph = parts[i].glyph;
                p.start_connector = parts[i].start_connector_length / upem;
                p.end_connector = parts[i].end_connector_length / upem;
                p.full_advance = parts[i].full_advance / upem;
                p.extender = (parts[i].flags & 1) != 0;
                res += p;
            }
            return res;
        }
    }
}
