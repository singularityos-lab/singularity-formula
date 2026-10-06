using Singularity.Apps.Formula;
using Singularity.Apps.Formula.Test;
using Singularity.Equations;

async void run_checks (MainLoop loop) {
    check (Equation.editor_available (), "the Formula helper is available");
    var eq = new Equation.from_latex ("\\frac{a}{b}+x^{2}");
    bool ok = yield eq.render (12, 2);
    check (ok, "LaTeX equation rendered through the helper");
    check (eq.mathml.contains ("<mfrac>"), "MathML produced from LaTeX: " + eq.mathml);
    check (eq.width_pt > 10 && eq.ascent_pt > 5 && eq.descent_pt > 1, "metrics %.1f x %.1f + %.1f".printf (eq.width_pt, eq.ascent_pt, eq.descent_pt));
    check (eq.texture != null && eq.texture.get_width () > 20, "texture loaded");
    var surf = new Cairo.ImageSurface (Cairo.Format.ARGB32, 200, 80);
    var cr = new Cairo.Context (surf);
    eq.paint (cr, 10, 50, 1.0);
    surf.flush ();
    unowned uint8[] data = surf.get_data ();
    int ink = 0;
    for (int i = 3; i < surf.get_stride () * surf.get_height (); i += 4) if (data[i] > 0) ink++;
    check (ink > 50, "the equation paints on a Cairo context (%d pixels)".printf (ink));

    var inl = Equation.from_omml ("<m:oMath><m:sSup><m:e><m:r><m:t>e</m:t></m:r></m:e><m:sup><m:r><m:t>x</m:t></m:r></m:sup></m:sSup></m:oMath>");
    ok = yield inl.render (12, 2);
    check (ok && !inl.display, "inline OMML equation rendered");
    double inline_height = inl.ascent_pt + inl.descent_pt;

    var longeq = new Equation.from_latex ("a+b+c+d+e+f+g+h+i+j+k+l+m+n+o+p+q+r+s+t+u+v+w+x+y+z=0");
    ok = yield longeq.render (12, 2);
    double wide = longeq.width_pt;
    longeq.max_width_pt = wide / 3.0;
    ok = yield longeq.render (12, 2);
    check (ok && longeq.width_pt < wide * 0.6 && longeq.ascent_pt + longeq.descent_pt > inline_height * 2, "long equation broken to the column width (%.0f < %.0f)".printf (longeq.width_pt, wide));
    loop.quit ();
}

int main (string[] args) {
    var loop = new MainLoop ();
    run_checks.begin (loop);
    loop.run ();
    return finish ("helper");
}
