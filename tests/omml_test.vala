using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

FormulaDoc doc_of (string latex) {
    try {
        return FormulaDoc.parse_linear (latex, LinearSyntax.LATEX);
    } catch (ParseError e) {
        check (false, "parse " + latex + ": " + e.message);
        return new FormulaDoc ();
    }
}

string roundtrip (string latex, bool display = true) {
    var d = doc_of (latex);
    d.display = display;
    string omml = WordFormat.omml_of (d);
    try {
        var back = WordFormat.doc_from_omml (omml);
        return back.to_latex ();
    } catch (Error e) {
        check (false, "omml read " + latex + ": " + e.message);
        return "";
    }
}

int main (string[] args) {
    string fixtures = Environment.get_variable ("FORMULA_FIXTURES") ?? "tests/fixtures";
    string[] same = {
        "\\frac{a}{b}", "x^{2}+y^{2}=z^{2}", "\\sqrt{x+1}", "\\sqrt[3]{x}", "a_{i}^{2}",
        "\\sum_{i=1}^{n} i^{2}", "\\int_{0}^{1} f\\left(x\\right)\\,dx", "\\lim_{x\\to 0} \\frac{\\sin x}{x}=1",
        "\\left[a+b\\right]", "\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}", "\\hat{x}+\\bar{y}", "\\overline{AB}",
        "\\underbrace{a+b}_{n}", "\\boxed{E=mc^{2}}", "{}_{6}^{14}C", "\\mathbb{R}\\mathbf{F}",
        "\\binom{n}{k}", "\\left|x\\right|", "\\begin{cases}x&x\\ge 0\\\\-x&x<0\\end{cases}",
        "\\begin{aligned}a&=b+c\\\\d&=e\\end{aligned}", "\\enclose{top,bottom}{x}", "\\cancel{y}"
    };
    foreach (var l in same) {
        string first = roundtrip (l);
        var d = doc_of (first);
        string second = roundtrip (first);
        check_eq (second, first, "OMML round trip is stable for " + l);
        check (!d.is_empty (), "OMML round trip keeps content for " + l);
    }
    check_eq (roundtrip ("\\frac{a}{b}"), "\\frac{a}{b}", "fraction survives OMML");
    check_eq (roundtrip ("\\sqrt[3]{x}"), "\\sqrt[3]{x}", "root survives OMML");
    check_eq (roundtrip ("{}_{6}^{14}C"), "{}_{6}^{14}C", "left scripts survive OMML");
    check_eq (roundtrip ("\\enclose{top,bottom}{x}"), "\\enclose{top,bottom}{x}", "border box sides survive OMML");
    check_eq (roundtrip ("\\sum_{i=1}^{n} i"), "\\sum_{i=1}^{n}i", "n-ary survives OMML");

    var inl = doc_of ("a^{2}");
    inl.display = false;
    string io = WordFormat.omml_of (inl);
    check (io.has_prefix ("<m:oMath ") && !io.contains ("oMathPara"), "inline equation is a bare oMath");
    try {
        var just = doc_of ("x=1");
        just.justification = Singularity.Equations.Justification.RIGHT;
        var jback = WordFormat.doc_from_omml (WordFormat.omml_of (just));
        check (jback.justification == Singularity.Equations.Justification.RIGHT, "justification survives OMML");
        check (jback.display, "display survives OMML");
    } catch (Error e) {
        check (false, e.message);
    }

    uint8[] docx;
    try {
        FileUtils.get_data (Path.build_filename (fixtures, "pandoc-equations.docx"), out docx);
        var eqs = WordFormat.equations_in_docx (docx);
        check (eqs.size == 12, "the Word document has 12 equations, got %d".printf (eqs.size));
        int loaded = 0;
        foreach (var e in eqs) {
            var d = WordFormat.doc_from_omml (e);
            if (!d.is_empty ()) loaded++;
        }
        check (loaded == 12, "every equation of the Word document loads, got %d".printf (loaded));
        var first = Formats.load_bytes (docx, "equations.docx");
        check_eq (first.to_latex (), "a^{2}+b^{2}=c^{2}", "opening a docx shows its first equation");
        var quad = WordFormat.doc_from_omml (eqs[2]);
        check (quad.to_latex ().has_prefix ("x=\\frac{"), "quadratic formula from Word: " + quad.to_latex ());
        var mat = WordFormat.doc_from_omml (eqs[6]);
        check (mat.to_latex ().contains ("\\begin{pmatrix}"), "matrix from Word: " + mat.to_latex ());
        var cases = WordFormat.doc_from_omml (eqs[7]);
        check (cases.to_latex ().contains ("\\begin{cases}"), "cases from Word: " + cases.to_latex ());
        string dir = DirUtils.make_tmp ("formula-omml-XXXXXX");
        int reopened = 0;
        for (int i = 0; i < eqs.size; i++) {
            var eq = Singularity.Equations.Equation.from_omml (eqs[i]);
            if (eq == null) continue;
            check_eq (eq.latex, "", "an Office equation carries no LaTeX (%d)".printf (i));
            string file = Path.build_filename (dir, "eq%d.mml".printf (i));
            FileUtils.set_contents (file, eq.mathml);
            var opened = Formats.load (file);
            var direct = WordFormat.doc_from_omml (eqs[i]);
            if (!opened.is_empty () && opened.to_latex () == direct.to_latex ()) reopened++;
            else check (false, "equation %d reopens for editing: %s / %s".printf (i, opened.to_latex (), direct.to_latex ()));
            FileUtils.remove (file);
        }
        DirUtils.remove (dir);
        check (reopened == 12, "every Office equation without LaTeX reopens in the editor, got %d".printf (reopened));
    } catch (Error e) {
        check (false, "docx fixture: " + e.message);
    }

    try {
        var d = doc_of ("e^{i\\pi}+1=0");
        uint8[] written = WordFormat.write_docx (d);
        check (WordFormat.is_docx (written), "written docx is a Word package");
        var zip = new ZipReader (written);
        check (zip.has ("[Content_Types].xml") && zip.has ("_rels/.rels") && zip.has ("word/document.xml"), "docx parts");
        string doc_xml = zip.read_text ("word/document.xml");
        check (doc_xml.contains ("<m:oMathPara>") && doc_xml.contains ("xmlns:m=\"http://schemas.openxmlformats.org/officeDocument/2006/math\""), "document.xml carries OMML");
        var back = Formats.load_bytes (written, "x.docx");
        check_eq (back.to_latex (), "e^{i\\pi}+1=0", "docx written and read back");
    } catch (Error e) {
        check (false, "write docx: " + e.message);
    }

    string html = WordFormat.clipboard_html (doc_of ("\\frac{1}{2}"));
    check (html.contains ("<!--[if gte msEquation 12]><m:oMathPara>") && html.contains ("<m:f>") && html.contains ("<math"), "clipboard HTML for Word has OMML and MathML");
    var pasted = Singularity.Equations.Equation.from_clipboard ("text/html", new Bytes (html.data));
    check (pasted != null && pasted.mathml.contains ("<mfrac>"), "clipboard HTML reads back");
    return finish ("omml");
}
