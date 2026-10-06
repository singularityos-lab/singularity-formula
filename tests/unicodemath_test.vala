using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

Row um (string s) {
    try {
        return UnicodeMath.parse (s);
    } catch (ParseError e) {
        check (false, "unicodemath parse error: " + e.message + " in " + s);
        return new Row ();
    }
}

void structure (string src, string want) {
    check_eq (dump (um (src)), want, "structure of " + src);
}

void same_as_latex (string src, string tex) {
    var a = um (src);
    var b = latex (tex);
    check (a.equals (b), "unicodemath " + src + " equals latex " + tex + "\n  " + dump (a) + "\n  " + dump (b));
}

void roundtrip (string tex) {
    var a = latex (tex);
    string lin = UnicodeMath.write (a);
    var b = um (lin);
    check (a.equals (b), "unicodemath round trip of " + tex + " via " + lin + "\n  " + dump (a) + "\n  " + dump (b));
}

void writes (string tex, string want) {
    check_eq (UnicodeMath.write (latex (tex)), want, "unicodemath of " + tex);
}

int main () {
    structure ("x", "[i:x]");
    structure ("a+b", "[i:a o:+ i:b]");
    structure ("a/b", "[frac{[i:a],[i:b]}]");
    structure ("a+b/c", "[i:a o:+ frac{[i:b],[i:c]}]");
    structure ("(a+b)/c", "[frac{[i:a o:+ i:b],[i:c]}]");
    structure ("x^2", "[i:x scripts{^[n:2]}]");
    structure ("x_ij", "[i:x scripts{_[i:i i:j]}]");
    structure ("x_i^2", "[i:x scripts{_[i:i]^[n:2]}]");
    structure ("x^(a+b)", "[i:x scripts{^[i:a o:+ i:b]}]");
    structure ("x\u00b2", "[i:x scripts{^[n:2]}]");
    structure ("a\u2081", "[i:a scripts{_[n:1]}]");
    structure ("\u221ax", "[radical{[i:x]}]");
    structure ("\u221a(a+b)", "[radical{[i:a o:+ i:b]}]");
    structure ("\u221a(3&x)", "[radical{[n:3],[i:x]}]");
    structure ("\u221bx", "[radical{[n:3],[i:x]}]");
    structure ("(a+b)", "[fenced(()){[i:a o:+ i:b]}]");
    structure ("[x]", "[fenced([]){[i:x]}]");
    structure ("|x|", "[fenced(||){[i:x]}]");
    structure ("\u25a0(a&b@c&d)", "[table(matrix){[i:a],[i:b],[i:c],[i:d]}]");
    structure ("(\u25a0(a&b@c&d))", "[table(pmatrix){[i:a],[i:b],[i:c],[i:d]}]");
    structure ("\u24b8(1&x>0@0&x<0)", "[table(cases){[n:1],[i:x o:> n:0],[n:0],[i:x o:< n:0]}]");
    structure ("\"if \"x", "[t:i/normal t:f/normal t: /normal i:x]");
    structure ("sin x", "[i:sin i:x]");
    structure ("\\alpha+\\beta", "[i:\u03b1 o:+ i:\u03b2]");
    structure ("x\u0302", "[accent(\u0302){[i:x]}]");
    structure ("\u00af(a+b)", "[accent(\u203e){[i:a o:+ i:b]}]");
    structure ("a\u00a6b", "[frac{[i:a],[i:b]}]");
    structure ("f'", "[i:f scripts{^[o:\u2032]}]");
    structure ("\u2211_(i=1)^n i", "[o:\u2211 scripts{_[i:i o:= n:1]^[i:n]} i:i]");
    structure ("lim\u252c(x\u2192 0)", "[i:lim scripts{_[i:x o:\u2192 n:0]}]");
    structure ("a\u2009b", "[i:a sp(3) i:b]");
    structure (Symbols.cp (0x1d431), "[i:x/bold]");
    structure ("x\\(y", "[i:x o:( i:y]");

    same_as_latex ("(-b\u00b1\u221a(b^2-4ac))/2a", "\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}");
    same_as_latex ("e^(i\u03c0)+1=0", "e^{i\\pi}+1=0");
    same_as_latex ("a^2+b^2=c^2", "a^2+b^2=c^2");
    same_as_latex ("\u222b_0^1 f(x)dx", "\\int_0^1 f(x)dx");

    roundtrip ("x^{2}+y^{2}=z^{2}");
    roundtrip ("\\frac{-b\\pm\\sqrt{b^{2}-4ac}}{2a}");
    roundtrip ("\\sum_{i=1}^{n}i=\\frac{n(n+1)}{2}");
    roundtrip ("\\int_{0}^{\\infty}e^{-x^{2}}\\,dx=\\frac{\\sqrt{\\pi}}{2}");
    roundtrip ("\\lim_{x\\to 0}\\frac{\\sin x}{x}=1");
    roundtrip ("\\binom{n}{k}=\\frac{n!}{k!(n-k)!}");
    roundtrip ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}");
    roundtrip ("\\begin{bmatrix} 1 & 0 \\\\ 0 & 1 \\end{bmatrix}");
    roundtrip ("\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}");
    roundtrip ("f(x)=\\begin{cases} x & x\\geq 0 \\\\ -x & \\text{otherwise} \\end{cases}");
    roundtrip ("\\hat{x}+\\vec{v}+\\overline{z}");
    roundtrip ("\\mathbf{F}=m\\mathbf{a}");
    roundtrip ("\\mathbb{R}^{n}");
    roundtrip ("\\left[\\frac{a}{b}\\right]");
    roundtrip ("\\sqrt[3]{x+1}");
    roundtrip ("\\sqrt[n]{x}");
    roundtrip ("\\overbrace{a+b}^{n}");
    roundtrip ("\\text{area}=\\pi r^{2}");
    roundtrip ("\\nabla\\times\\mathbf{E}=-\\frac{\\partial\\mathbf{B}}{\\partial t}");
    roundtrip ("f'(x)");
    roundtrip ("\\boxed{E=mc^{2}}");
    roundtrip ("\\{x\\mid x>0\\}");
    roundtrip ("\\left\\langle \\psi\\middle|\\phi\\right\\rangle");
    roundtrip ("a\\,b\\quad c");
    roundtrip ("\\frac{a+b}{c+d}");
    roundtrip ("\\frac{x^{2}}{2}");
    roundtrip ("x_{i,j}");
    roundtrip ("\\left(\\frac{1}{2}\\right)^{n}");

    writes ("\\frac{a}{b}", "a/b");
    writes ("\\frac{a+b}{c}", "(a+b)/c");
    writes ("x^{2}", "x^2");
    writes ("x^{2n}", "x^(2n)");
    writes ("\\sqrt{x}", "\u221ax");
    writes ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", "\u24a8(a&b@c&d)");
    writes ("\\sin x", "sin x");
    writes ("E=mc^2 ", "E=mc^2");

    try {
        var r = UnicodeMath.parse_result ("E=mc^2#(1)");
        check_eq (r.tag ?? "", "1", "equation number");
    } catch (ParseError e) {
        check (false, e.message);
    }
    try {
        UnicodeMath.parse ("(a+b");
        check (false, "unbalanced paren should fail");
    } catch (ParseError e) {
        check (true, "unbalanced rejected");
    }
    try {
        UnicodeMath.parse ("x^");
        check (false, "dangling script should fail");
    } catch (ParseError e) {
        check (true, "dangling script rejected");
    }
    check_eq (UnicodeMath.autocorrect ("\\alpha+\\infty "), "\u03b1+\u221e", "autocorrect");

    return finish ("unicodemath");
}
