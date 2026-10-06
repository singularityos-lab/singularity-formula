using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

Row mml (string xml) {
    try {
        return MathmlReader.parse (xml).root;
    } catch (ParseError e) {
        check (false, "mathml parse error: " + e.message + " in " + xml);
        return new Row ();
    }
}

void roundtrip (string tex) {
    var a = latex (tex);
    string xml = MathmlWriter.write (a, true, null, true);
    var b = mml (xml);
    check (a.equals (b), "mathml round trip of " + tex + "\n  " + dump (a) + "\n  " + dump (b) + "\n" + xml);
    string compact = MathmlWriter.write (a, true, tex, false);
    var c = mml (compact);
    check (a.equals (c), "compact mathml round trip of " + tex);
}

void contains (string tex, string fragment) {
    string xml = MathmlWriter.write (latex (tex), true, null, false);
    check (xml.contains (fragment), "mathml of " + tex + " contains " + fragment + "\n  " + xml);
}

void reads (string xml, string want) {
    check_eq (dump (mml (xml)), want, "read " + xml);
}

int main () {
    contains ("x", "<mi>x</mi>");
    contains ("12.5", "<mn>12.5</mn>");
    contains ("a+b", "<mo>+</mo>");
    contains ("x^2", "<msup><mi>x</mi><mn>2</mn></msup>");
    contains ("x_i^2", "<msubsup><mi>x</mi><mi>i</mi><mn>2</mn></msubsup>");
    contains ("\\frac{a}{b}", "<mfrac><mi>a</mi><mi>b</mi></mfrac>");
    contains ("\\sqrt{x}", "<msqrt><mi>x</mi></msqrt>");
    contains ("\\sqrt[3]{x}", "<mroot><mi>x</mi><mn>3</mn></mroot>");
    contains ("\\sum_{i=1}^n", "<munderover><mo>\u2211</mo>");
    contains ("\\int_0^1", "<msubsup><mo>\u222b</mo>");
    contains ("\\hat{x}", "<mover accent=\"true\"><mi>x</mi><mo stretchy=\"false\">^</mo></mover>");
    contains ("\\overline{x}", "<mo stretchy=\"true\">\u203e</mo>");
    contains ("\\left( x \\right)", "<mo fence=\"true\" form=\"prefix\">(</mo>");
    contains ("\\mathbb{R}", "<mi mathvariant=\"double-struck\">R</mi>");
    contains ("\\text{if }", "<mtext>if\u00a0</mtext>");
    contains ("\\sin x", "<mi>sin</mi><mo>\u2061</mo><mi>x</mi>");
    contains ("\\begin{pmatrix} a & b \\end{pmatrix}", "<mtable><mtr><mtd><mi>a</mi></mtd><mtd><mi>b</mi></mtd></mtr></mtable>");
    contains ("\\begin{aligned} a &= b \\end{aligned}", "columnalign=\"right left\"");
    contains ("\\binom{n}{k}", "<mfrac linethickness=\"0\">");
    contains ("\\boxed{x}", "<menclose notation=\"box\">");
    contains ("\\textcolor{red}{x}", "<mstyle mathcolor=\"red\">");
    contains ("\\,", "<mspace width=\"0.1667em\"/>");

    roundtrip ("x^{2}+y^{2}=z^{2}");
    roundtrip ("\\frac{-b\\pm\\sqrt{b^{2}-4ac}}{2a}");
    roundtrip ("\\sum_{i=1}^{n}i=\\frac{n(n+1)}{2}");
    roundtrip ("\\int_{0}^{\\infty}e^{-x^{2}}\\,dx=\\frac{\\sqrt{\\pi}}{2}");
    roundtrip ("e^{i\\pi}+1=0");
    roundtrip ("\\lim_{x\\to 0}\\frac{\\sin x}{x}=1");
    roundtrip ("\\binom{n}{k}=\\frac{n!}{k!(n-k)!}");
    roundtrip ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}");
    roundtrip ("\\begin{vmatrix} 1 & 2 \\\\ 3 & 4 \\end{vmatrix}");
    roundtrip ("f(x)=\\begin{cases} x & x\\geq 0 \\\\ -x & \\text{otherwise} \\end{cases}");
    roundtrip ("\\begin{aligned} a & =b+c \\\\  & =d \\end{aligned}");
    roundtrip ("\\hat{x}+\\vec{v}+\\overline{z}+\\tilde{a}+\\dot{b}");
    roundtrip ("\\mathbf{F}=m\\mathbf{a}");
    roundtrip ("\\mathbb{R}^{n}");
    roundtrip ("\\left\\langle \\psi\\middle|\\phi\\right\\rangle");
    roundtrip ("\\left[\\frac{a}{b}\\right]");
    roundtrip ("\\sqrt[3]{x+1}");
    roundtrip ("\\overbrace{a+b}^{n}");
    roundtrip ("\\underbrace{1+\\cdots+1}_{k}");
    roundtrip ("\\text{area}=\\pi r^{2}");
    roundtrip ("\\nabla\\times\\mathbf{E}=-\\frac{\\partial\\mathbf{B}}{\\partial t}");
    roundtrip ("f'(x)");
    roundtrip ("\\xrightarrow[x]{f}");
    roundtrip ("\\boxed{E=mc^{2}}");
    roundtrip ("\\cancel{x}");
    roundtrip ("\\begin{array}{c|l} a & b \\\\ c & d \\end{array}");
    roundtrip ("\\dfrac{1}{2}+\\tfrac{1}{3}");
    roundtrip ("\\textcolor{red}{x}");
    roundtrip ("\\{x\\mid x>0\\}");
    roundtrip ("\\oint_{C}\\mathbf{F}\\cdot d\\mathbf{r}");
    roundtrip ("\\overset{!}{=}");
    roundtrip ("\\underset{n}{\\arg\\max}");
    roundtrip ("\\phantom{x}+\\hphantom{y}");
    roundtrip ("{}_{2}^{4}He");
    roundtrip ("\\int\\limits_{a}^{b}f");
    roundtrip ("\\sum\\nolimits_{i}a_{i}");

    reads ("<math><mi>x</mi></math>", "[i:x]");
    reads ("<math xmlns=\"http://www.w3.org/1998/Math/MathML\"><mrow><mi>a</mi><mo>+</mo><mi>b</mi></mrow></math>", "[i:a o:+ i:b]");
    reads ("<m:math xmlns:m=\"http://www.w3.org/1998/Math/MathML\"><m:mfrac><m:mn>1</m:mn><m:mn>2</m:mn></m:mfrac></m:math>", "[frac{[n:1],[n:2]}]");
    reads ("<math><mfenced><mi>a</mi><mi>b</mi></mfenced></math>", "[fenced(()){[i:a o:, i:b]}]");
    reads ("<math><mrow><mo>(</mo><mfrac><mi>a</mi><mi>b</mi></mfrac><mo>)</mo></mrow></math>", "[fenced(()){[frac{[i:a],[i:b]}]}]");
    reads ("<math><mi>" + Symbols.cp (0x1d431) + "</mi></math>", "[i:x/bold]");
    reads ("<math><mi>\u211d</mi></math>", "[i:R/double-struck]");
    reads ("<math><mi>" + Symbols.cp (0x1d465) + "</mi></math>", "[i:x]");
    reads ("<math><mo>-</mo><mn>3</mn></math>", "[o:\u2212 n:3]");
    reads ("<math><mi>f</mi><mo>\u2061</mo><mi>x</mi></math>", "[i:f i:x]");
    reads ("<math><mspace width=\"thinmathspace\"/></math>", "[sp(3)]");
    reads ("<math><mstyle displaystyle=\"true\"><mfrac><mn>1</mn><mn>2</mn></mfrac></mstyle></math>", "[frac{[n:1],[n:2]}]");
    reads ("<math><mtable><mlabeledtr><mtd><mtext>(1)</mtext></mtd><mtd><mi>x</mi></mtd></mlabeledtr></mtable></math>", "[i:x]");
    reads ("<math><semantics><mi>y</mi><annotation encoding=\"application/x-tex\">y</annotation></semantics></math>", "[i:y]");
    reads ("<math><menclose><mi>x</mi></menclose></math>", "[enclose{[i:x]}]");
    reads ("<math><merror><mtext>bad</mtext></merror></math>", "[t:b/normal t:a/normal t:d/normal]");
    reads ("<math><mmultiscripts><mi>X</mi><mi>a</mi><none/><mprescripts/><mi>b</mi><mi>c</mi></mmultiscripts></math>", "[scripts{_[i:b]^[i:c]} i:X scripts{_[i:a]}]");

    try {
        var r = MathmlReader.parse ("<math><mtable><mlabeledtr><mtd><mtext>(2.1)</mtext></mtd><mtd><mi>x</mi></mtd></mlabeledtr></mtable></math>");
        check_eq (r.tag ?? "", "2.1", "tag from mlabeledtr");
        string xml = MathmlWriter.write (r.root, true, null, false, "7");
        check (xml.contains ("<mlabeledtr><mtd><mtext>(7)</mtext></mtd>"), "labeled row written");
    } catch (ParseError e) {
        check (false, e.message);
    }
    try {
        MathmlReader.parse ("not xml at all");
        check (false, "garbage should fail");
    } catch (ParseError e) {
        check (true, "garbage rejected");
    }

    return finish ("mathml");
}
