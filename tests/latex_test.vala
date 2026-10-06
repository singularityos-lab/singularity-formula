using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;

void structure (string src, string want) {
    check_eq (dump (latex (src)), want, "structure of " + src);
}

void roundtrip (string src, string? want = null) {
    var a = latex (src);
    string out1 = LatexWriter.write (a);
    check_eq (out1, want ?? src, "write of " + src);
    var b = latex (out1);
    check (a.equals (b), "reparse equality of " + src + " (" + dump (a) + " vs " + dump (b) + ")");
}

void parse_fails (string src) {
    try {
        LatexParser.parse (src);
        check (false, "expected a parse error for " + src);
    } catch (ParseError e) {
        check (LatexParser.error_position (e) >= 0, "error position for " + src);
    }
}

int main () {
    structure ("x", "[i:x]");
    structure ("x+1", "[i:x o:+ n:1]");
    structure ("12.5", "[n:1 n:2 n:. n:5]");
    structure ("a-b", "[i:a o:\u2212 i:b]");
    structure ("x^2", "[i:x scripts{^[n:2]}]");
    structure ("x_i^2", "[i:x scripts{_[i:i]^[n:2]}]");
    structure ("x^12", "[i:x scripts{^[n:1]} n:2]");
    structure ("x^{12}", "[i:x scripts{^[n:1 n:2]}]");
    structure ("f'", "[i:f scripts{^[o:\u2032]}]");
    structure ("f''(x)", "[i:f scripts{^[o:\u2032 o:\u2032]} fenced(()){[i:x]}]");
    structure ("\\frac{a}{b}", "[frac{[i:a],[i:b]}]");
    structure ("\\frac12", "[frac{[n:1],[n:2]}]");
    structure ("a \\over b", "[frac{[i:a],[i:b]}]");
    structure ("{n \\choose k}", "[fenced(()){[frac{[i:n],[i:k]}]}]");
    structure ("\\binom{n}{k}", "[fenced(()){[frac{[i:n],[i:k]}]}]");
    structure ("\\sqrt{x}", "[radical{[i:x]}]");
    structure ("\\sqrt[3]{x}", "[radical{[n:3],[i:x]}]");
    structure ("\\left( x \\right)", "[fenced(()){[i:x]}]");
    structure ("\\left. x \\right|", "[fenced(|){[i:x]}]");
    structure ("\\left\\{ a \\middle| b \\right\\}", "[fenced({}){[i:a o:| i:b]}]");
    structure ("\\alpha+\\Omega", "[i:\u03b1 o:+ i:\u03a9]");
    structure ("\\sum_{i=1}^{n} i", "[o:\u2211 scripts{_[i:i o:= n:1]^[i:n]} i:i]");
    structure ("\\int_0^1 f", "[o:\u222b scripts{_[n:0]^[n:1]} i:f]");
    structure ("\\hat{x}", "[accent(\u0302){[i:x]}]");
    structure ("\\overline{AB}", "[accent(\u203e){[i:A i:B]}]");
    structure ("\\overbrace{a+b}^{n}", "[accent(\u23de){[i:a o:+ i:b]} scripts{^[i:n]}]");
    structure ("\\mathbf{v}", "[i:v/bold]");
    structure ("\\mathbb{R}", "[i:R/double-struck]");
    structure ("\\text{if } x", "[t:i/normal t:f/normal t: /normal i:x]");
    structure ("\\sin x", "[i:sin i:x]");
    structure ("\\operatorname{sgn} x", "[i:sgn i:x]");
    structure ("a\\,b\\quad c", "[i:a sp(3) i:b sp(18) i:c]");
    structure ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}", "[table(pmatrix){[i:a],[i:b],[i:c],[i:d]}]");
    structure ("\\begin{cases} 1 & x>0 \\\\ 0 & \\text{otherwise} \\end{cases}", "[table(cases){[n:1],[i:x o:> n:0],[n:0],[t:o/normal t:t/normal t:h/normal t:e/normal t:r/normal t:w/normal t:i/normal t:s/normal t:e/normal]}]");
    structure ("\\begin{aligned} a &= b \\\\ &= c \\end{aligned}", "[table(aligned){[i:a],[o:= i:b],[],[o:= i:c]}]");
    structure ("x \\not= y", "[i:x o:\u2260 i:y]");
    structure ("\\not\\in", "[o:\u2209]");
    structure ("\\xrightarrow[a]{b}", "[underover{[i:b],[o:\u2192],[i:a]}]");
    structure ("\\boxed{x}", "[enclose{[i:x]}]");
    structure ("\\textcolor{red}{x}", "[style{[i:x]}]");
    structure ("{\\displaystyle x}", "[style{[i:x]}]");
    structure ("\\big( x \\big)", "[o:( i:x o:)]");
    structure ("f(x)", "[i:f fenced(()){[i:x]}]");
    structure ("(a+b)^2", "[fenced(()){[i:a o:+ i:b]} scripts{^[n:2]}]");
    structure ("(\\frac{a}{b})", "[o:( frac{[i:a],[i:b]} o:)]");
    structure ("|x|+|y|", "[fenced(||){[i:x]} o:+ fenced(||){[i:y]}]");
    structure ("\\lim_{x \\to 0}", "[i:lim scripts{_[i:x o:\u2192 n:0]}]");
    structure ("{}^{14}C", "[scripts{^[n:1 n:4]} i:C]");
    structure ("\\{ a \\}", "[fenced({}){[i:a]}]");
    structure ("\\foo", "[i:\\foo]");
    structure ("a % comment\n + b", "[i:a o:+ i:b]");

    roundtrip ("x^{2}+y^{2}=z^{2}");
    roundtrip ("x^2+y^2=z^2", "x^{2}+y^{2}=z^{2}");
    roundtrip ("\\frac{-b\\pm\\sqrt{b^{2}-4ac}}{2a}");
    roundtrip ("\\sum_{i=1}^{n}i=\\frac{n\\left(n+1\\right)}{2}", "\\sum_{i=1}^{n}i=\\frac{n(n+1)}{2}");
    roundtrip ("\\int_{0}^{\\infty}e^{-x^{2}}\\,dx=\\frac{\\sqrt{\\pi}}{2}");
    roundtrip ("e^{i\\pi}+1=0");
    roundtrip ("\\lim_{x\\to 0}\\frac{\\sin x}{x}=1");
    roundtrip ("\\binom{n}{k}=\\frac{n!}{k!\\left(n-k\\right)!}", "\\binom{n}{k}=\\frac{n!}{k!(n-k)!}");
    roundtrip ("\\begin{pmatrix} a & b \\\\ c & d \\end{pmatrix}");
    roundtrip ("\\begin{vmatrix} 1 & 2 \\\\ 3 & 4 \\end{vmatrix}");
    roundtrip ("f\\left(x\\right)=\\begin{cases} x & x\\geq 0 \\\\ -x & \\text{otherwise} \\end{cases}", "f(x)=\\begin{cases} x & x\\geq 0 \\\\ -x & \\text{otherwise} \\end{cases}");
    roundtrip ("\\begin{aligned} a & =b+c \\\\  & =d \\end{aligned}", "\\begin{aligned} a & =b+c \\\\  & =d \\end{aligned}");
    roundtrip ("\\hat{x}+\\vec{v}+\\overline{z}");
    roundtrip ("\\mathbf{F}=m\\mathbf{a}");
    roundtrip ("\\mathbb{R}^{n}");
    roundtrip ("\\left\\langle \\psi\\middle|\\phi\\right\\rangle");
    roundtrip ("\\left[\\frac{a}{b}\\right]");
    roundtrip ("\\sqrt[3]{x+1}");
    roundtrip ("\\overbrace{a+b}^{n}");
    roundtrip ("\\underbrace{1+\\cdots+1}_{k}");
    roundtrip ("\\text{area}=\\pi r^{2}");
    roundtrip ("\\nabla\\times\\mathbf{E}=-\\frac{\\partial\\mathbf{B}}{\\partial t}");
    roundtrip ("f'\\left(x\\right)", "f'(x)");
    roundtrip ("\\xrightarrow[x]{f}");
    roundtrip ("\\boxed{E=mc^{2}}");
    roundtrip ("\\cancel{x}");
    roundtrip ("a\\bmod b");
    roundtrip ("\\operatorname{sgn} x", "\\operatorname{sgn}x");
    roundtrip ("\\begin{array}{c|l} a & b \\\\ c & d \\end{array}");
    roundtrip ("\\dfrac{1}{2}+\\tfrac{1}{3}");
    roundtrip ("\\textcolor{red}{x}");
    roundtrip ("\\alpha\\beta\\gamma");
    roundtrip ("\\left\\lfloor x\\right\\rfloor", "\\lfloor x\\rfloor");
    roundtrip ("\\left\\{ x\\mid x>0\\right\\}", "\\{x\\mid x>0\\}");
    roundtrip ("\\{x\\mid x>0\\}");
    roundtrip ("\\prod_{p}\\frac{1}{1-p^{-s}}");
    roundtrip ("\\oint_{C}\\mathbf{F}\\cdot d\\mathbf{r}");
    roundtrip ("x\\neq y");
    roundtrip ("A\\subseteq B\\cup C");
    roundtrip ("\\forall x\\exists y:x<y", "\\forall x\\exists y:x<y");

    check_eq (LatexWriter.write (latex ("x"), "1.2"), "x\\tag{1.2}", "tag written");
    try {
        var r = LatexParser.parse ("E=mc^2 \\tag{3}");
        check_eq (r.tag ?? "", "3", "tag parsed");
        var r2 = LatexParser.parse ("E=mc^2 \\notag");
        check (r2.notag, "notag parsed");
    } catch (ParseError e) {
        check (false, e.message);
    }

    foreach (var item in Gallery.all ()) {
        var g = latex (item.latex);
        check (g.size > 0, "gallery formula parses: " + item.title);
        var g2 = latex (LatexWriter.write (g));
        check (g.equals (g2), "gallery formula round trip: " + item.title);
    }

    parse_fails ("\\frac{a}{b");
    parse_fails ("a}");
    parse_fails ("\\left( x");
    parse_fails ("\\begin{pmatrix} a \\end{bmatrix}");
    parse_fails ("\\begin{nothing} a \\end{nothing}");
    parse_fails ("a & b");
    parse_fails ("x^");

    return finish ("latex");
}
