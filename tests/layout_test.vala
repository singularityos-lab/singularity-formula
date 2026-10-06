using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

MathFont font;
LayoutEngine engine;
const double SIZE = 10.0;

MBox lay (string tex, bool display = true) {
    return engine.layout (latex (tex), display);
}

MBox first (MBox row) {
    return row.children[0].box;
}

void dump_png (string name, string tex) {
    string? dir = Environment.get_variable ("FORMULA_TEST_PNG");
    if (dir == null) return;
    var doc = new FormulaDoc ();
    doc.set_root (latex (tex));
    var ex = new Exporter (doc, font, 40);
    ex.background = Rgba (1, 1, 1, 1);
    try {
        ex.write_png (Path.build_filename (dir, name + ".png"), 1.0);
    } catch (Error e) {
        check (false, e.message);
    }
}

int main () {
    font = MathFont.get_default ("Latin Modern Math");
    if (font.family != "Latin Modern Math" || !font.has_math) {
        print ("layout: Latin Modern Math is not installed, skipping\n");
        return 77;
    }
    engine = new LayoutEngine (font, SIZE);
    double axis = font.get (MathConst.AXIS_HEIGHT) * SIZE;
    double rule = font.get (MathConst.FRACTION_RULE_THICKNESS) * SIZE;

    check_near (font.get (MathConst.AXIS_HEIGHT), 0.25, 1e-9, "Latin Modern axis height is 250 units");
    check_near (font.get (MathConst.FRACTION_RULE_THICKNESS), 0.04, 1e-9, "fraction rule is 40 units");
    check_near (font.script_scale (1), 0.70, 1e-9, "script scale 70 percent");
    check_near (font.script_scale (2), 0.50, 1e-9, "scriptscript scale 50 percent");

    var x = lay ("x");
    check (x.width / SIZE > 0.4 && x.width / SIZE < 0.7, "x has a plausible width (%g)".printf (x.width));
    check_near (x.ascent, 0.431 * SIZE, 0.2, "x height near 431 units");
    var x2 = lay ("x^2");
    var scripts = x2.children[0].box;
    var sup = scripts.children[1];
    double shift_up = font.get (MathConst.SUPERSCRIPT_SHIFT_UP) * SIZE;
    check (-sup.y >= shift_up - 1e-6, "superscript raised at least superscriptShiftUp (%g >= %g)".printf (-sup.y, shift_up));
    check_near (sup.box.children[0].box.items[0].size, 7.0, 1e-9, "superscript set at 70 percent");
    double space_after = font.get (MathConst.SPACE_AFTER_SCRIPT) * SIZE;
    check_near (x2.width, sup.x + sup.box.width + space_after, 1e-6, "width includes spaceAfterScript");

    var xi = lay ("x_i");
    var sub = xi.children[0].box.children[1];
    check (sub.y >= font.get (MathConst.SUBSCRIPT_SHIFT_DOWN) * SIZE - 1e-6, "subscript lowered at least subscriptShiftDown");

    var both = lay ("x_i^2");
    var bs = both.children[0].box;
    var bsup = bs.children[1];
    var bsub = bs.children[2];
    double gap = (-bsup.y - bsup.box.descent) - (bsub.box.ascent - bsub.y);
    check (gap >= font.get (MathConst.SUB_SUPERSCRIPT_GAP_MIN) * SIZE - 1e-6, "sub and superscript gap respected (%g)".printf (gap));

    var fd = lay ("\\frac{a}{b}", true);
    var fb = first (fd);
    var num = fb.children[0];
    var den = fb.children[1];
    double num_up = font.get (MathConst.FRACTION_NUMERATOR_DISPLAY_STYLE_SHIFT_UP) * SIZE;
    check (-num.y >= num_up - 1e-6, "display numerator shift");
    double num_gap = (-num.y - num.box.descent) - (axis + rule / 2);
    check (num_gap >= font.get (MathConst.FRACTION_NUM_DISPLAY_STYLE_GAP_MIN) * SIZE - 1e-6, "display numerator gap (%g)".printf (num_gap));
    double den_gap = (den.y - den.box.ascent) - (-(axis - rule / 2));
    check (den_gap >= font.get (MathConst.FRACTION_DENOM_DISPLAY_STYLE_GAP_MIN) * SIZE - 1e-6, "display denominator gap (%g)".printf (den_gap));
    var rule_item = fb.items[0];
    check_near (rule_item.h, rule, 1e-9, "fraction rule thickness");
    check_near (-(rule_item.y + rule_item.h / 2), axis, 1e-9, "fraction rule centred on the axis");
    check_near (num.box.children.size > 0 ? num.box.children[0].box.items[0].size : 0, SIZE, 1e-9, "display numerator in text style (full size)");

    var ft = lay ("\\frac{a}{b}", false);
    var ftb = first (ft);
    check_near (ftb.children[0].box.children[0].box.items[0].size, 7.0, 1e-9, "inline numerator in script style");
    check (fd.height > ft.height, "display fraction taller than inline");
    var dfrac = first (lay ("\\dfrac{a}{b}", false));
    check_near (dfrac.children[0].box.children[0].box.items[0].size, SIZE, 1e-9, "dfrac forces display style");

    var sq = first (lay ("\\sqrt{x}"));
    double body_top = 0.431 * SIZE;
    check (sq.ascent >= body_top + font.get (MathConst.RADICAL_DISPLAY_STYLE_VERTICAL_GAP) * SIZE, "radical clears the body");
    bool has_rule = false;
    foreach (var it in sq.items) if (it.kind == ItemKind.RULE) has_rule = true;
    check (has_rule, "radical has an overbar rule");

    var sum_d = first (lay ("\\sum_{i=1}^{n}", true));
    check (sum_d.children.size == 3, "display sum places limits above and below");
    check (sum_d.children[1].y < 0 && sum_d.children[2].y > 0, "sum limits above and below");
    var sum_op = sum_d.children[0].box;
    check (sum_op.height >= font.get (MathConst.DISPLAY_OPERATOR_MIN_HEIGHT) * SIZE - 1e-6, "display sum at least displayOperatorMinHeight");
    double mid = (sum_op.ascent - sum_op.descent) / 2;
    check_near (mid, axis, 1e-6, "big operator centred on axis");
    var sum_t = first (lay ("\\sum_{i=1}^{n}", false));
    check (sum_t.children[1].x > 0, "inline sum puts limits at the side");
    var int_d = first (lay ("\\int_0^1", true));
    check (int_d.children[1].x > 0, "integral limits stay at the side in display");

    var fen = first (lay ("\\left( \\frac{a}{b} \\right)", true));
    var open_d = fen.children[0].box;
    var inner = fen.children[1].box;
    check (open_d.height >= inner.height * 0.9, "delimiter grows with a tall body");
    var small = first (lay ("\\left( x \\right)", true));
    check (small.children[0].box.height < open_d.height, "delimiter stays small around x");

    var spaced = lay ("a+b");
    double thin = SIZE / 18.0;
    double plus_left = spaced.carets[1] - lay ("a").width;
    check_near (plus_left, 4 * thin, 1e-6, "medium space before a binary operator");
    var rel = lay ("a=b");
    check_near (rel.carets[1] - lay ("a").width, 5 * thin, 1e-6, "thick space around a relation");
    var unary = lay ("-a");
    check_near (unary.carets[1], unary.children[0].box.width, 1e-6, "leading minus is unary (no space)");
    var scr = lay ("x^{a+b}");
    var sbox = scr.children[0].box.children[1].box;
    check_near (sbox.carets[2] - sbox.carets[1], sbox.children[1].box.width, 1e-6, "no binary spacing in script style");

    var mat = first (lay ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}"));
    check (mat.children.size == 3, "pmatrix has two delimiters and a grid");
    double mid_m = (mat.ascent - mat.descent) / 2;
    check (Math.fabs (mid_m - axis) < 0.5, "matrix centred near the axis");

    var al = lay ("\\begin{aligned} a &= b \\\\ c &= d \\end{aligned}");
    check (al.height > lay ("a=b").height * 1.8, "two aligned lines");

    var acc = first (lay ("\\hat{x}"));
    check (acc.ascent > x.ascent, "accent raises the box");
    var ov = first (lay ("\\overline{x}"));
    check (ov.ascent >= x.ascent + font.get (MathConst.OVERBAR_VERTICAL_GAP) * SIZE, "overline gap");
    var brace = first (lay ("\\overbrace{a+b}^{n}"));
    check (brace.children.size >= 2, "overbrace label above");

    var geo = Geometry.compute (lay ("\\frac{a}{b}+c"), 0, 0);
    check (geo.rows.size == 3, "geometry has the root row and two slots (%d)".printf (geo.rows.size));
    var root_row = latex ("x+y");
    var root_box = engine.layout (root_row, true);
    var g2 = Geometry.compute (root_box, 5, 20);
    var rg = g2.rows[root_row];
    check (rg != null && rg.carets.length == 4, "four caret stops in x+y");
    if (rg != null) {
        check_near (rg.carets[0], 5, 1e-9, "first caret at the origin");
        check (Geometry.nearest_caret (rg, rg.carets[2] + 0.1) == 2, "nearest caret lookup");
    }

    engine.editing = true;
    var ph = engine.layout (latex ("\\frac{}{b}"), true);
    bool placeholder = false;
    var stack = new Gee.ArrayList<MBox> ();
    stack.add (ph);
    while (stack.size > 0) {
        var bx = stack.remove_at (stack.size - 1);
        foreach (var it in bx.items) if (it.kind == ItemKind.PLACEHOLDER) placeholder = true;
        foreach (var c in bx.children) stack.add (c.box);
    }
    check (placeholder, "empty slot draws a placeholder while editing");
    engine.editing = false;

    var doc = new FormulaDoc ();
    doc.set_root (latex ("E=mc^2"));
    doc.numbered = true;
    var dl = DocLayout.build (doc, engine);
    check (dl.labels.length == 1 && dl.labels[0] != null, "numbered equation gets a label");
    check (dl.width > dl.box.width, "label adds width");

    var ex = new Exporter (doc, font, 20);
    string tmp = Path.build_filename (Environment.get_tmp_dir (), "formula-layout-test");
    DirUtils.create_with_parents (tmp, 0755);
    try {
        ex.write_svg (Path.build_filename (tmp, "t.svg"));
        ex.write_pdf (Path.build_filename (tmp, "t.pdf"));
        ex.write_png (Path.build_filename (tmp, "t.png"), 2.0);
        string svg;
        FileUtils.get_contents (Path.build_filename (tmp, "t.svg"), out svg);
        check (svg.contains ("<svg"), "svg written");
        uint8[] pdf;
        FileUtils.get_data (Path.build_filename (tmp, "t.pdf"), out pdf);
        check (pdf.length > 100 && pdf[0] == '%' && pdf[1] == 'P', "pdf written");
        var png = ex.png_bytes (1.0);
        check (png.length > 100 && png[1] == 'P' && png[2] == 'N', "png bytes");
        check (((string) ex.svg_bytes ()).contains ("<svg"), "svg bytes");
        FileUtils.remove (Path.build_filename (tmp, "t.svg"));
        FileUtils.remove (Path.build_filename (tmp, "t.pdf"));
        FileUtils.remove (Path.build_filename (tmp, "t.png"));
        DirUtils.remove (tmp);
    } catch (Error e) {
        check (false, e.message);
    }

    string fam;
    string? serif = MathFont.find_file ("Nimbus Roman", out fam);
    if (serif != null) {
        var plain = MathFont.load_file (serif, fam, false);
        check (plain != null && !plain.has_math, "a text font loads without a MATH table");
        if (plain != null) {
            var pe = new LayoutEngine (plain, SIZE);
            var pb = pe.layout (latex ("\\left(\\frac{a}{b}\\right)^2+\\sqrt{x}+\\sum_{i=1}^{n}i"), true);
            check (pb.width > 0 && pb.height > 0, "fallback font lays out a formula");
            string? dir = Environment.get_variable ("FORMULA_TEST_PNG");
            if (dir != null) {
                var d = new FormulaDoc ();
                d.set_root (latex ("x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}+\\left(\\frac{a}{b}\\right)^2+\\sum_{i=1}^{n}i"));
                var fex = new Exporter (d, plain, 40);
                fex.background = Rgba (1, 1, 1, 1);
                try {
                    fex.write_png (Path.build_filename (dir, "fallback.png"), 1.0);
                } catch (Error e) {
                    check (false, e.message);
                }
            }
        }
    }

    dump_png ("quadratic", "x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}");
    dump_png ("sum", "\\sum_{i=1}^{n} i = \\frac{n(n+1)}{2}");
    dump_png ("gauss", "\\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx = \\sqrt{\\pi}");
    dump_png ("matrix", "A=\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}");
    dump_png ("cases", "|x|=\\begin{cases} x & x\\geq 0 \\\\ -x & x<0 \\end{cases}");
    dump_png ("accents", "\\hat{x}+\\vec{v}+\\overline{AB}+\\widehat{xyz}+\\tilde{n}+\\dot{x}");
    dump_png ("braces", "\\overbrace{a+\\cdots+a}^{k}\\cdot\\underbrace{b+b}_{2}");
    dump_png ("maxwell", "\\nabla\\times\\mathbf{E}=-\\frac{\\partial\\mathbf{B}}{\\partial t}");
    dump_png ("align", "\\begin{aligned} (a+b)^2 &= a^2+2ab+b^2 \\\\ &= b^2+2ab+a^2 \\end{aligned}");
    dump_png ("roots", "\\sqrt[3]{x}+\\sqrt{\\frac{a}{b}}+\\sqrt{x^2+y^2}");
    dump_png ("fences", "\\left[\\left(\\frac{a}{b}\\right)^2\\right]\\left\\langle\\psi\\middle|\\phi\\right\\rangle");
    dump_png ("limits", "\\lim_{x\\to 0}\\frac{\\sin x}{x}=1");
    dump_png ("xarrow", "A\\xrightarrow[g]{f}B\\boxed{E=mc^2}\\cancel{x}");

    return finish ("layout");
}
