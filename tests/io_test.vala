using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

string fixture (string name) {
    return Path.build_filename (Environment.get_variable ("FORMULA_FIXTURES") ?? "tests/fixtures", name);
}

FormulaDoc doc_of (string tex) {
    var d = new FormulaDoc ();
    d.set_root (latex (tex));
    return d;
}

int main () {
    string tmp;
    try {
        tmp = DirUtils.make_tmp ("formula-io-XXXXXX");
    } catch (FileError e) {
        stderr.printf ("%s\n", e.message);
        return 1;
    }

    string[] samples = {
        "x=\\frac{-b\\pm\\sqrt{b^{2}-4ac}}{2a}",
        "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}",
        "\\sum_{i=1}^{n}i^{2}",
        "\\begin{aligned} a & =b \\\\  & =c \\end{aligned}",
        "\\int_{0}^{1}f(x)\\,dx",
        "\\hat{x}+\\overline{y}"
    };
    foreach (var s in samples) {
        var d = doc_of (s);
        uint8[] odf;
        try {
            odf = Formats.write_odf (d);
            check (Formats.is_zip (odf), "odf is a zip for " + s);
            var zr = new ZipReader (odf);
            check_eq (zr.read_text ("mimetype") ?? "", Formats.ODF_MIME, "odf mimetype first");
            check (zr.has ("META-INF/manifest.xml"), "odf manifest");
            var back = Formats.read_odf (odf);
            check (back.root.equals (d.root), "odf round trip of " + s + "\n  " + dump (d.root) + "\n  " + dump (back.root));
            string content = Formats.odf_content (d);
            check (content.contains ("encoding=\"StarMath 5.0\""), "odf keeps a StarMath annotation");
        } catch (Error e) {
            check (false, "odf " + s + ": " + e.message);
        }
        foreach (var ext in new string[] { "mml", "odf", "tex", "txt" }) {
            string path = Path.build_filename (tmp, "f." + ext);
            try {
                Formats.save (d, path, MathFont.get_default (), 20);
                var back = Formats.load (path);
                check (back.root.equals (d.root), "save and load ." + ext + " for " + s + "\n  " + dump (d.root) + "\n  " + dump (back.root));
                FileUtils.remove (path);
            } catch (Error e) {
                check (false, "save/load ." + ext + ": " + e.message);
            }
        }
    }

    try {
        var lo = Formats.load (fixture ("lo-content.xml"));
        check_eq (LatexWriter.write (lo.root), "x=\\frac{-b\\pm\\sqrt{b^{2}-4ac}}{2a}", "LibreOffice content.xml");
        var word = Formats.load (fixture ("word.mml"));
        check_eq (LatexWriter.write (word.root), "\\sum_{k=0}^{n}\\binom{n}{k}x^{k}", "Word MathML");
        var art = Formats.load (fixture ("article.tex"));
        check_eq (LatexWriter.write (art.root), "e^{i\\pi}+1=0", "LaTeX article body");
    } catch (Error e) {
        check (false, "fixture: " + e.message);
    }

    var d3 = doc_of ("\\frac{a}{b}");
    string annotated = d3.to_mathml (true, true);
    check (annotated.contains ("<annotation encoding=\"application/x-tex\">\\frac{a}{b}</annotation>"), "LaTeX annotation is intact\n" + annotated);

    var d2 = doc_of ("E=mc^{2}");
    d2.numbered = true;
    string mml = d2.to_mathml (false, true);
    check (mml.contains ("<mlabeledtr data-auto=\"true\">"), "numbered equation exported as labeled row");
    try {
        var back = FormulaDoc.parse_any (mml);
        check (back.tag == null && back.numbered, "automatic number stays automatic");
        var labs = back.labels ();
        check_eq (labs[0] ?? "", "1", "equation number read back");
        check_eq (LatexWriter.write (back.root), "E=mc^{2}", "numbered body intact");
    } catch (ParseError e) {
        check (false, e.message);
    }
    check (Formats.latex_document (d2).contains ("\\begin{equation}"), "numbered LaTeX document uses equation");

    check_eq (StarMathWriter.write (latex ("\\frac{a}{b}")), "{a} over {b}", "starmath fraction");
    check_eq (StarMathWriter.write (latex ("\\sqrt{x}")), "sqrt{x}", "starmath sqrt");
    check_eq (StarMathWriter.write (latex ("x^{2}")), "{x}^{2}", "starmath superscript");
    check_eq (StarMathWriter.write (latex ("\\sum_{i=1}^{n}i")), "sum from{i = 1} to{n} i", "starmath sum");
    check_eq (StarMathWriter.write (latex ("\\alpha\\leq\\beta")), "%ialpha <= %ibeta", "starmath greek");
    check_eq (StarMathWriter.write (latex ("\\left(x\\right)")), "left ( x right )", "starmath brackets");
    check_eq (StarMathWriter.write (latex ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}")), "left ( matrix{{a} # {b} ## {c} # {d}} right )", "starmath matrix");

    try {
        var any = FormulaDoc.parse_any ("$x^2$");
        check_eq (LatexWriter.write (any.root), "x^{2}", "parse_any strips dollars");
        var um = FormulaDoc.parse_any ("a/b");
        check_eq (LatexWriter.write (um.root), "\\frac{a}{b}", "parse_any takes UnicodeMath");
    } catch (ParseError e) {
        check (false, e.message);
    }

    try {
        Formats.load_bytes ("PK\x03\x04garbage".data, "x.odf");
        check (false, "broken odf should fail");
    } catch (Error e) {
        check (true, "broken odf rejected");
    }
    DirUtils.remove (tmp);
    return finish ("io");
}
