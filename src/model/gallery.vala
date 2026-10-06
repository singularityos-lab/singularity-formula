namespace Singularity.Apps.Formula {

    public class GalleryItem {
        public string title;
        public string category;
        public string latex;
        public bool featured;

        public GalleryItem (string title, string category, string latex, bool featured) {
            this.title = title;
            this.category = category;
            this.latex = latex;
            this.featured = featured;
        }
    }

    public class Gallery {
        private static Gee.ArrayList<GalleryItem>? items;

        public static Gee.List<GalleryItem> all () {
            if (items != null) return items;
            items = new Gee.ArrayList<GalleryItem> ();
            add (_("Quadratic Formula"), _("Algebra"), "x=\\frac{-b\\pm\\sqrt{b^2-4ac}}{2a}", true);
            add (_("Binomial Theorem"), _("Algebra"), "(x+y)^n=\\sum_{k=0}^{n}\\binom{n}{k}x^{n-k}y^k", true);
            add (_("Geometric Series"), _("Algebra"), "\\sum_{k=0}^{\\infty}ar^k=\\frac{a}{1-r},\\quad |r|<1");
            add (_("Arithmetic Sum"), _("Algebra"), "\\sum_{i=1}^{n}i=\\frac{n(n+1)}{2}");
            add (_("Absolute Value"), _("Algebra"), "|x|=\\begin{cases} x & x\\geq 0 \\\\ -x & x<0 \\end{cases}", true);
            add (_("Pythagorean Theorem"), _("Geometry"), "a^2+b^2=c^2", true);
            add (_("Law of Cosines"), _("Geometry"), "c^2=a^2+b^2-2ab\\cos\\gamma");
            add (_("Area of a Circle"), _("Geometry"), "A=\\pi r^2");
            add (_("Trigonometric Identity"), _("Geometry"), "\\sin^2\\theta+\\cos^2\\theta=1");
            add (_("Euler's Identity"), _("Analysis"), "e^{i\\pi}+1=0", true);
            add (_("Euler's Formula"), _("Analysis"), "e^{i\\varphi}=\\cos\\varphi+i\\sin\\varphi");
            add (_("Definition of the Derivative"), _("Analysis"), "f'(x)=\\lim_{h\\to 0}\\frac{f(x+h)-f(x)}{h}", true);
            add (_("Fundamental Theorem of Calculus"), _("Analysis"), "\\int_{a}^{b}f(x)\\,dx=F(b)-F(a)");
            add (_("Taylor Series"), _("Analysis"), "f(x)=\\sum_{n=0}^{\\infty}\\frac{f^{(n)}(a)}{n!}(x-a)^n", true);
            add (_("Gaussian Integral"), _("Analysis"), "\\int_{-\\infty}^{\\infty}e^{-x^2}\\,dx=\\sqrt{\\pi}", true);
            add (_("Integration by Parts"), _("Analysis"), "\\int u\\,dv=uv-\\int v\\,du");
            add (_("Fourier Transform"), _("Analysis"), "\\hat{f}(\\xi)=\\int_{-\\infty}^{\\infty}f(x)e^{-2\\pi ix\\xi}\\,dx");
            add (_("Matrix"), _("Linear Algebra"), "A=\\begin{pmatrix} a_{11} & a_{12} \\\\ a_{21} & a_{22} \\end{pmatrix}", true);
            add (_("Determinant"), _("Linear Algebra"), "\\det A=\\begin{vmatrix} a & b \\\\ c & d \\end{vmatrix}=ad-bc");
            add (_("Eigenvalues"), _("Linear Algebra"), "A\\mathbf{v}=\\lambda\\mathbf{v}");
            add (_("Matrix Product"), _("Linear Algebra"), "(AB)_{ij}=\\sum_{k=1}^{n}a_{ik}b_{kj}");
            add (_("Bayes' Theorem"), _("Probability"), "P(A\\mid B)=\\frac{P(B\\mid A)\\,P(A)}{P(B)}", true);
            add (_("Normal Distribution"), _("Probability"), "f(x)=\\frac{1}{\\sigma\\sqrt{2\\pi}}e^{-\\frac{1}{2}\\left(\\frac{x-\\mu}{\\sigma}\\right)^2}", true);
            add (_("Expected Value"), _("Probability"), "E[X]=\\sum_{i}x_i\\,p_i");
            add (_("Variance"), _("Probability"), "\\operatorname{Var}(X)=E\\left[(X-\\mu)^2\\right]");
            add (_("Newton's Second Law"), _("Physics"), "\\mathbf{F}=m\\mathbf{a}");
            add (_("Mass and Energy"), _("Physics"), "E=mc^2", true);
            add (_("Schrödinger Equation"), _("Physics"), "i\\hbar\\frac{\\partial}{\\partial t}\\Psi=\\hat{H}\\Psi");
            add (_("Maxwell's Equations"), _("Physics"), "\\begin{aligned} \\nabla\\cdot\\mathbf{E} & =\\frac{\\rho}{\\varepsilon_0} \\\\ \\nabla\\cdot\\mathbf{B} & =0 \\\\ \\nabla\\times\\mathbf{E} & =-\\frac{\\partial\\mathbf{B}}{\\partial t} \\\\ \\nabla\\times\\mathbf{B} & =\\mu_0\\mathbf{J}+\\mu_0\\varepsilon_0\\frac{\\partial\\mathbf{E}}{\\partial t} \\end{aligned}");
            add (_("Wave Equation"), _("Physics"), "\\frac{\\partial^2u}{\\partial t^2}=c^2\\nabla^2u");
            add (_("Ideal Gas Law"), _("Chemistry"), "pV=nRT");
            add (_("Reaction Rate"), _("Chemistry"), "k=Ae^{-\\frac{E_a}{RT}}");
            add (_("Fermat's Little Theorem"), _("Number Theory"), "a^{p}\\equiv a\\pmod{p}");
            add (_("Euler Product"), _("Number Theory"), "\\zeta(s)=\\sum_{n=1}^{\\infty}\\frac{1}{n^s}=\\prod_{p}\\frac{1}{1-p^{-s}}");
            return items;
        }

        private static void add (string title, string category, string latex, bool featured = false) {
            items.add (new GalleryItem (title, category, latex, featured));
        }
    }
}
