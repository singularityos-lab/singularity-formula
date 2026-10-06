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

void test_left_scripts () {
    var d = doc_of ("{}_{6}^{14}C");
    check (d.root.size == 2 && d.root[0] is Scripts && ((Scripts) d.root[0]).pre, "empty group with scripts before a base is a left script");
    check_eq (d.to_latex (), "{}_{6}^{14}C", "left scripts written back");
    var p = doc_of ("\\prescript{14}{6}{C}");
    check (p.root.size == 2 && ((Scripts) p.root[0]).pre, "prescript command");
    check_eq (p.to_latex (), "{}_{6}^{14}C", "prescript normalized");
    string um = d.to_unicodemath ();
    try {
        var back = FormulaDoc.parse_linear (um, LinearSyntax.UNICODEMATH);
        check (back.root.size == 2 && back.root[0] is Scripts && ((Scripts) back.root[0]).pre, "left scripts survive UnicodeMath: " + um);
    } catch (ParseError e) {
        check (false, "UnicodeMath left scripts: " + e.message);
    }
    string mml = d.to_mathml (false, false);
    check (mml.contains ("<mmultiscripts>") && mml.contains ("<mprescripts/>"), "left scripts in MathML");
    var tail = doc_of ("x={}^{2}");
    check (!(tail.root[tail.root.size - 1] is Scripts && ((Scripts) tail.root[tail.root.size - 1]).pre), "trailing empty base stays a normal script");
    var ed = new Editor (new FormulaDoc ());
    ed.insert_prescripts ();
    ed.type_text ("6");
    check (ed.row.parent is Scripts && ((Scripts) ed.row.parent).pre, "editor inserts left scripts");
}

void test_enclose () {
    var d = doc_of ("\\enclose{top,bottom,verticalstrike}{x}");
    var e = d.root[0] as Enclose;
    check (e != null && e.notation == "top bottom verticalstrike", "enclose notation parsed");
    var font = MathFont.get_default (null);
    var engine = new LayoutEngine (font, 20);
    var box = engine.layout (d.root, true);
    int rules = 0;
    foreach (var c in box.children) foreach (var it in c.box.items) if (it.kind == ItemKind.RULE) rules++;
    check (rules == 3, "two borders and one vertical strike drawn, got %d".printf (rules));
    var ed = new Editor (doc_of ("\\boxed{y}"));
    var enc = ed.doc.root[0] as Enclose;
    ed.set_caret (enc.body, 1);
    ed.toggle_enclose_note ("top");
    check_eq (((Enclose) ed.doc.root[0]).notation, "bottom left right", "hiding the top border");
    ed.toggle_enclose_note ("top");
    check_eq (((Enclose) ed.doc.root[0]).notation, "box", "showing it again restores the box");
    ed.toggle_enclose_note ("horizontalstrike");
    check (Editor.has_note ((Enclose) ed.doc.root[0], "horizontalstrike"), "adding a strike");
}

void test_line_breaking () {
    var d = doc_of ("a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p=q+r+s+t+u+v+w");
    var font = MathFont.get_default (null);
    var engine = new LayoutEngine (font, 20);
    var wide = DocLayout.build (d, engine);
    check (wide.box.line_count == 1, "no breaking without a width");
    double full = wide.width;
    d.line_width = full / 20.0 / 3.0;
    var engine2 = new LayoutEngine (font, 20);
    var narrow = DocLayout.build (d, engine2);
    check (narrow.box.line_count >= 3, "long equation broken into lines, got %d".printf (narrow.box.line_count));
    check (narrow.width <= full / 2.0, "broken equation is narrower");
    check (narrow.ascent + narrow.descent > wide.ascent + wide.descent, "broken equation is taller");
    check (narrow.box.caret_ys.length == d.root.size + 1, "every caret has a line");
    d.wrap_right = true;
    var engine3 = new LayoutEngine (font, 20);
    var right = DocLayout.build (d, engine3);
    check (right.box.line_count >= 3, "right aligned wrapping");
    d.justification = Singularity.Equations.Justification.LEFT;
    string mml = d.to_mathml (false, false);
    check (mml.contains ("data-justification=\"left\""), "justification stored in MathML");
    try {
        var back = FormulaDoc.parse_any (mml);
        check (back.justification == Singularity.Equations.Justification.LEFT, "justification read back");
    } catch (ParseError e) {
        check (false, e.message);
    }
}

void test_numbering () {
    var d = doc_of ("\\begin{aligned}a&=b\\label{first}\\\\c&=d\\label{second}\\\\e&=\\eqref{first}+\\ref{second}\\end{aligned}");
    d.numbered = true;
    var t = d.lines_table ();
    check (t != null && t.names[0] == "first" && t.names[1] == "second", "labels stored on lines");
    var refs = d.references ();
    check_eq (refs["first"] ?? "", "1", "first reference");
    check_eq (refs["second"] ?? "", "2", "second reference");
    check (d.to_latex ().contains ("\\label{first}") && d.to_latex ().contains ("\\eqref{first}"), "labels and references in LaTeX: " + d.to_latex ());
    d.number_style = Singularity.Equations.NumberStyle.BRACKETS;
    d.first_number = 5;
    string mml = d.to_mathml (false, false);
    check (mml.contains ("[5]") && mml.contains ("data-ref=\"first\"") && mml.contains (">[5]</mtext>"), "numbers and references in MathML: " + mml);
    try {
        var back = FormulaDoc.parse_any (mml);
        check (back.numbered && back.first_number == 5 && back.number_style == Singularity.Equations.NumberStyle.BRACKETS, "numbering options read back");
        var bt = back.lines_table ();
        check (bt != null && bt.names[0] == "first", "line names read back");
        var labs = back.labels ();
        check_eq (labs[1] ?? "", "6", "numbers continue from the first number");
    } catch (ParseError e) {
        check (false, e.message);
    }
    var font = MathFont.get_default (null);
    var dl = DocLayout.build (d, new LayoutEngine (font, 20));
    check (dl.labels.length == 3 && dl.labels[0] != null, "numbers laid out");
    check_eq (d.unique_label (), "eq1", "fresh label name");
}

void test_autocorrect () {
    string path = Path.build_filename (Environment.get_tmp_dir (), "formula-ac-%u.json".printf (Random.next_int ()));
    var ac = new Singularity.Equations.AutoCorrect (path);
    ac.set_entry ("\\RR", "ℝ");
    ac.set_entry ("\\qf", "x=(-b±√(b^2-4ac))/2a");
    ac.add_function ("Tr");
    Symbols.autocorrect = ac;
    var ed = new Editor (new FormulaDoc ());
    ed.type_text ("\\RR ");
    check (ed.doc.root.size == 1 && ((Token) ed.doc.root[0]).text == "ℝ", "custom autocorrect entry");
    ed.type_text ("\\degree ");
    check (ed.doc.root.size == 2 && ((Token) ed.doc.root[1]).text == "°", "Word default entry without a built-in command");
    var ed2 = new Editor (new FormulaDoc ());
    ed2.type_text ("a<=b");
    check_eq (ed2.doc.to_latex (), "a\\leq b", "operator autocorrect");
    ac.remove_entry ("<=");
    var ed3 = new Editor (new FormulaDoc ());
    ed3.type_text ("a<=b");
    check_eq (ed3.doc.to_latex (), "a<=b", "removed operator entry is not applied");
    var ed4 = new Editor (new FormulaDoc ());
    ed4.type_text ("\\qf ");
    check (ed4.doc.to_latex ().contains ("\\frac"), "multi-character replacement is parsed: " + ed4.doc.to_latex ());
    check (Symbols.is_function ("Tr") && Symbols.is_function ("sin"), "user recognized function");
    var ed5 = new Editor (new FormulaDoc ());
    ed5.type_text ("Tr");
    check (ed5.doc.root.size == 1 && ((Token) ed5.doc.root[0]).text == "Tr", "typed user function merges into one name");
    ac.remove_function ("sin");
    check (!Symbols.is_function ("sin"), "removed function is no longer recognized");
    Symbols.autocorrect = null;
    FileUtils.remove (path);
}

void test_linear () {
    var ed = new Editor (doc_of ("\\frac{a}{b}+c"));
    ed.set_caret (ed.doc.root, 0);
    ed.anchor = 0;
    ed.set_caret (ed.doc.root, 1, true);
    ed.toggle_linear (LinearSyntax.UNICODEMATH);
    check (ed.doc.root[0] is Token && ((Token) ed.doc.root[0]).linear, "selection shown in linear form");
    check (!(ed.doc.root[ed.doc.root.size - 1] as Token).linear, "the rest stays professional");
    ed.toggle_linear (LinearSyntax.UNICODEMATH);
    check (ed.doc.root[0] is Frac, "back to professional: " + ed.doc.to_latex ());
    check_eq (ed.doc.to_latex (), "\\frac{a}{b}+c", "round trip through linear form");
    var all = new Editor (doc_of ("\\sqrt{x}"));
    all.toggle_linear (LinearSyntax.LATEX);
    check_eq (all.doc.to_latex (), "\\text{\\textbackslash{}sqrt\\{x\\}}", "whole equation to linear LaTeX");
    all.toggle_linear (LinearSyntax.LATEX);
    check (all.doc.root[0] is Radical, "whole equation back to professional");
}

void test_matrix_alignment () {
    var ed = new Editor (doc_of ("\\begin{pmatrix}a&b\\\\c&d\\end{pmatrix}"));
    var t = (Table) ed.doc.root[0];
    ed.set_caret (t.cell (0, 1), 1);
    check (ed.table_align_column ('r'), "column alignment changed");
    check_eq (t.columns, "cr", "second column right aligned");
    ed.table_set_spacing (2.0, 0.5);
    string latex = ed.doc.to_latex ();
    check (latex.has_prefix ("\\left( \\begin{array}{cr}"), "aligned matrix written as an array: " + latex);
    string mml = ed.doc.to_mathml (false, false);
    check (mml.contains ("columnalign=\"center right\"") && mml.contains ("columnspacing=\"2em\"") && mml.contains ("rowspacing=\"0.5em\""), "alignment and spacing in MathML: " + mml);
    try {
        var back = FormulaDoc.parse_any (mml);
        var bt = back.root[0] as Table;
        check (bt != null && bt.column_gap == 2.0 && bt.row_gap == 0.5 && bt.columns == "cr", "alignment and spacing read back");
        string omml = WordFormat.omml_of (back);
        check (omml.contains ("<m:cGp m:val=\"440\"/>") && omml.contains ("<m:mcJc m:val=\"right\"/>"), "alignment and spacing in OMML: " + omml);
        var ob = WordFormat.doc_from_omml (omml);
        var otb = ob.root[0] as Table;
        if (otb == null && ob.root[0] is Fenced) otb = ((Fenced) ob.root[0]).body[0] as Table;
        check (otb != null && Math.fabs (otb.column_gap - 2.0) < 0.01, "spacing survives OMML");
    } catch (Error e) {
        check (false, e.message);
    }
}

void test_speech () {
    var d = doc_of ("x^{2}+\\frac{1}{2}");
    string s = Singularity.Equations.Speech.describe (d.to_mathml (false, false));
    check_eq (s, "x squared plus 1 over 2", "spoken formula");
}

int main (string[] args) {
    test_left_scripts ();
    test_enclose ();
    test_line_breaking ();
    test_numbering ();
    test_autocorrect ();
    test_linear ();
    test_matrix_alignment ();
    test_speech ();
    return finish ("features");
}
