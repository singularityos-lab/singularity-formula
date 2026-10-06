using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

MathFont? writer_font () {
    foreach (var fam in new string[] { "FreeSans", "Cantarell", "Inter", "Bitstream Charter" }) {
        string matched;
        string? file = MathFont.find_file (fam, out matched);
        if (file == null || matched != fam) continue;
        var f = MathFont.load_file (file, fam, false);
        if (f != null) return f;
    }
    return null;
}

Gee.ArrayList<InkStroke> written (MathFont f, string ch, double x, double y, double size, uint seed) {
    var list = new Gee.ArrayList<InkStroke> ();
    var strokes = InkRecognizer.glyph_strokes (f, ch, false, 64, false);
    if (strokes == null) return list;
    var rnd = new Rand.with_seed (seed);
    foreach (var s in strokes) {
        var t = new InkStroke ();
        foreach (var p in s.points) t.add (x + p.x * size / 64.0 + rnd.double_range (-0.6, 0.6), y - size * 0.78 + p.y * size / 64.0 + rnd.double_range (-0.6, 0.6));
        list.add (t);
    }
    return list;
}

InkStroke line (double x0, double y0, double x1, double y1) {
    var s = new InkStroke ();
    for (int i = 0; i <= 20; i++) s.add (x0 + (x1 - x0) * i / 20.0, y0 + (y1 - y0) * i / 20.0);
    return s;
}

int main (string[] args) {
    var rec = InkRecognizer.get_default ();
    rec.user_path = Path.build_filename (Environment.get_tmp_dir (), "ink-test-%u.json".printf (Random.next_int ()));
    check (rec.templates.size > 150, "templates built from the installed fonts: %d".printf (rec.templates.size));
    var f = writer_font ();
    if (f == null) f = MathFont.get_default (null);
    string sample = "0123456789abcdefghknpqrstuvwxyz+=()<>∑∫";
    int total = 0;
    int right = 0;
    int top3 = 0;
    int i = 0;
    unichar c;
    var misses = new StringBuilder ();
    while (sample.get_next_char (ref i, out c)) {
        string ch = c.to_string ();
        var strokes = written (f, ch, 0, 0, 48, (uint) c);
        if (strokes.size == 0) continue;
        total++;
        var cands = rec.classify (strokes, 3);
        if (cands.size > 0 && cands[0].symbol == ch) right++;
        else misses.append (ch).append ("=").append (cands.size > 0 ? cands[0].symbol : "?").append (" ");
        foreach (var cand in cands) if (cand.symbol == ch) top3++;
    }
    double acc = total > 0 ? (double) right / total : 0;
    double acc3 = total > 0 ? (double) top3 / total : 0;
    print ("ink: %s writing, top-1 %d/%d (%.0f%%), top-3 %d/%d (%.0f%%); misses: %s\n", f.family, right, total, acc * 100, top3, total, acc3 * 100, misses.str);
    check (acc >= 0.7, "top-1 accuracy on a font never used for templates is at least 70%%, got %.0f%%".printf (acc * 100));
    check (acc3 >= 0.9, "top-3 accuracy is at least 90%%, got %.0f%%".printf (acc3 * 100));

    var parser = new InkParser (rec);
    var strokes = new Gee.ArrayList<InkStroke> ();
    strokes.add_all (written (f, "x", 0, 100, 48, 1));
    strokes.add_all (written (f, "2", 26, 84, 26, 2));
    check_eq (parser.recognize (strokes), "x^{2}", "superscript recognized");

    strokes.clear ();
    strokes.add_all (written (f, "1", 14, 88, 48, 3));
    strokes.add (line (4, 96, 50, 96));
    strokes.add_all (written (f, "2", 14, 140, 48, 4));
    check_eq (parser.recognize (strokes), "\\frac{1}{2}", "fraction recognized");

    strokes.clear ();
    strokes.add_all (written (f, "a", 0, 100, 48, 5));
    strokes.add (line (30, 88, 52, 88));
    strokes.add (line (41, 77, 41, 99));
    strokes.add_all (written (f, "b", 56, 100, 48, 6));
    string plus = parser.recognize (strokes);
    check (parser.symbols.size == 3, "crossing strokes form one plus sign, got %d symbols".printf (parser.symbols.size));
    check_eq (plus, "a+b", "sum recognized");

    strokes.clear ();
    strokes.add_all (written (f, "y", 0, 100, 48, 7));
    strokes.add (line (30, 84, 52, 84));
    strokes.add (line (30, 93, 52, 93));
    strokes.add_all (written (f, "3", 58, 100, 48, 8));
    check_eq (parser.recognize (strokes), "y=3", "two parallel lines form an equals sign");

    strokes.clear ();
    strokes.add_all (written (f, "k", 0, 100, 48, 9));
    strokes.add_all (written (f, "n", 28, 110, 26, 10));
    check_eq (parser.recognize (strokes), "k_{n}", "subscript recognized");

    var odd = new Gee.ArrayList<InkStroke> ();
    odd.add (line (0, 0, 10, 30));
    odd.add (line (10, 30, 20, 0));
    odd.add (line (20, 0, 30, 30));
    rec.learn ("ω", odd);
    var again = rec.classify (odd, 1);
    check (again.size == 1 && again[0].symbol == "ω", "a corrected symbol is learned");
    check (rec.user_template_count () == 1, "one user template stored");
    var rec2 = new InkRecognizer.from_fonts (new Gee.ArrayList<MathFont> ());
    rec2.user_path = rec.user_path;
    check (FileUtils.test (rec.user_path, FileTest.EXISTS), "user templates saved");
    rec.forget_user ();
    FileUtils.remove (rec.user_path);
    return finish ("ink");
}
