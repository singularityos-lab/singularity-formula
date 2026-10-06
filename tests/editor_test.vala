using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

Editor fresh () {
    return new Editor (new FormulaDoc ());
}

string tex (Editor e) {
    return LatexWriter.write (e.doc.root);
}

void typed (string keys, string want) {
    var e = fresh ();
    e.type_text (keys);
    check_eq (tex (e), want, "typing " + keys);
}

int main () {
    typed ("x+1", "x+1");
    typed ("x^2", "x^{2}");
    typed ("a/b", "\\frac{a}{b}");
    typed ("2x/3", "\\frac{2x}{3}");
    typed ("a+b/c", "a+\\frac{b}{c}");
    typed ("x_i", "x_{i}");
    typed ("(a+b", "(a+b)");
    typed ("(a)+b", "(a)+b");
    typed ("|x|", "|x|");
    typed ("sinx", "\\sin x");
    typed ("sinhx", "\\sinh x");
    typed ("lnx", "\\ln x");
    typed ("a<=b", "a\\leq b");
    typed ("a!=b", "a\\neq b");
    typed ("x->y", "x\\to y");
    typed ("a+-b", "a\\pm b");
    typed ("1...n", "1\\ldots n");
    typed ("\\alpha+\\beta ", "\\alpha+\\beta");
    typed ("\\alpha x", "\\alpha x");
    typed ("\\sqrt 2", "\\sqrt{2}");
    typed ("\\frac 1", "\\frac{1}{}");
    typed ("f'", "f'");
    typed ("3.14", "3.14");
    typed ("a*b", "a\\cdot b");
    typed ("\\foo ", "\\foo");
    typed ("\\frac{a}{b}", "\\frac{a}{b}");
    typed ("\\frac{m_1 m_2}{r^2}", "\\frac{m_{1}m_{2}}{r^{2}}");
    typed ("x_{12}+1", "x_{12}+1");
    typed ("x_{i}^{2}", "x_{i}^{2}");
    typed ("\\sqrt[3]{x}+1", "\\sqrt[3]{x}+1");
    typed ("\\sqrt{2}", "\\sqrt{2}");
    typed ("\\hat{x}", "\\hat{x}");
    typed ("{a}", "\\{a\\}");
    typed ("x^10+1", "x^{10}+1");
    typed ("e^-x", "e^{-x}");
    typed ("a/b+c", "\\frac{a}{b}+c");
    typed ("x_i y_j", "x_{i}y_{j}");

    var e = fresh ();
    e.type_text ("x^2");
    e.move_right ();
    e.type_text ("+1");
    check_eq (tex (e), "x^{2}+1", "move out of a superscript");

    e = fresh ();
    e.type_text ("a/b");
    e.move_right ();
    e.type_text ("+c");
    check_eq (tex (e), "\\frac{a}{b}+c", "move out of a denominator");

    e = fresh ();
    e.insert_fraction (false);
    e.type_text ("1");
    e.next_slot ();
    e.type_text ("2");
    check_eq (tex (e), "\\frac{1}{2}", "tab to the next placeholder");

    e = fresh ();
    e.type_text ("ab");
    e.move_left (true);
    e.move_left (true);
    check (e.has_selection, "shift+left selects");
    e.insert_node (new Radical ());
    check_eq (tex (e), "\\sqrt{ab}", "structure wraps the selection");

    e = fresh ();
    e.type_text ("x+y");
    e.backspace ();
    check_eq (tex (e), "x+", "backspace removes a character");
    e.undo ();
    check_eq (tex (e), "x+y", "undo restores");
    e.redo ();
    check_eq (tex (e), "x+", "redo reapplies");

    e = fresh ();
    e.type_text ("a/b");
    e.move_right ();
    e.backspace ();
    check (e.has_selection, "backspace after a structure selects it first");
    e.backspace ();
    check_eq (tex (e), "", "second backspace deletes it");

    e = fresh ();
    e.insert_fraction (false);
    e.backspace ();
    check_eq (tex (e), "", "backspace in an empty template removes it");

    e = fresh ();
    e.type_text ("(x");
    e.home ();
    e.backspace ();
    check_eq (tex (e), "x", "backspace at the start of brackets unwraps them");

    e = fresh ();
    e.insert_table (TableKind.PMATRIX, 2, 2);
    e.type_text ("a&b&c&d");
    check_eq (tex (e), "\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", "fill a matrix with &");
    e.table_insert_row (true);
    check_eq (tex (e), "\\begin{pmatrix} a & b \\\\ c & d \\\\  &  \\end{pmatrix}", "insert matrix row");
    e.table_delete_row ();
    e.table_insert_column (true);
    check_eq (tex (e), "\\begin{pmatrix} a &  & b \\\\ c &  & d \\end{pmatrix}", "insert matrix column");

    e = fresh ();
    e.type_text ("a=b+c");
    e.new_line ();
    e.type_text ("=d");
    check_eq (tex (e), "\\begin{aligned} a & =b+c \\\\  & =d \\end{aligned}", "enter starts an aligned equation");

    e = fresh ();
    e.type_text ("x");
    e.run_command ("hat");
    check_eq (tex (e), "\\hat{x}", "accent applies to the previous symbol");

    e = fresh ();
    e.insert_big_operator ("\u2211", true);
    e.type_text ("i=1");
    e.next_slot ();
    e.type_text ("n");
    e.move_right ();
    e.type_text ("i");
    check_eq (tex (e), "\\sum_{i=1}^{n}i", "sum with limits template");

    e = fresh ();
    e.insert_text_mode ();
    e.type_text ("if x");
    e.insert_text_mode ();
    e.type_text ("y");
    check_eq (tex (e), "\\text{if x}y", "text mode");

    e = fresh ();
    e.type_text ("ab");
    e.select_all ();
    e.apply_variant (MathVariant.BOLD);
    check_eq (tex (e), "\\mathbf{ab}", "bold selection");

    e = fresh ();
    e.type_text ("x^2");
    int[] path = Editor.path_of (e.row);
    check (path.length == 2 && path[0] == 1 && path[1] == 0, "path of the superscript slot");
    check (Editor.row_at_path (e.doc.root, path) == e.row, "row at path");

    e = fresh ();
    e.type_text ("12");
    e.move_left ();
    e.move_left ();
    e.move_left ();
    check (e.index == 0, "left stops at the start");
    e.end ();
    check (e.index == 2, "end jumps to the end");

    e = fresh ();
    e.type_text ("x^2+y");
    var copy = e.doc.root.copy_row ();
    e.replace_root (latex ("a+b"), null);
    check_eq (tex (e), "a+b", "replace root from the linear editor");
    e.undo ();
    check (e.doc.root.equals (copy), "undo a text sync");

    return finish ("editor");
}
