namespace Singularity.Apps.Formula.Test {

    public int failures = 0;
    public int passed = 0;

    public void check (bool ok, string what) {
        if (ok) {
            passed++;
        } else {
            failures++;
            stderr.printf ("FAIL: %s\n", what);
        }
    }

    public void check_eq (string got, string want, string what) {
        if (got == want) {
            passed++;
        } else {
            failures++;
            stderr.printf ("FAIL: %s\n  got:  %s\n  want: %s\n", what, got, want);
        }
    }

    public void check_near (double got, double want, double tol, string what) {
        if (Math.fabs (got - want) <= tol) {
            passed++;
        } else {
            failures++;
            stderr.printf ("FAIL: %s\n  got:  %g\n  want: %g (tolerance %g)\n", what, got, want, tol);
        }
    }

    public int finish (string suite) {
        print ("%s: %d passed, %d failed\n", suite, passed, failures);
        return failures == 0 ? 0 : 1;
    }

    public Row latex (string s) {
        try {
            return LatexParser.parse (s).root;
        } catch (ParseError e) {
            failures++;
            stderr.printf ("FAIL: parse error for %s: %s\n", s, e.message);
            return new Row ();
        }
    }

    public string dump (Node n) {
        var sb = new StringBuilder ();
        dump_into (sb, n);
        return sb.str;
    }

    private void dump_into (StringBuilder sb, Node n) {
        if (n is Row) {
            sb.append ("[");
            var r = (Row) n;
            for (int i = 0; i < r.size; i++) {
                if (i > 0) sb.append (" ");
                dump_into (sb, r[i]);
            }
            sb.append ("]");
            return;
        }
        if (n is Token) {
            var t = (Token) n;
            string k = t.kind == TokenKind.IDENT ? "i" : (t.kind == TokenKind.NUMBER ? "n" : (t.kind == TokenKind.OPERATOR ? "o" : "t"));
            sb.append (k).append (":").append (t.text);
            if (t.variant != MathVariant.DEFAULT) sb.append ("/").append (t.variant.to_mathml ());
            return;
        }
        if (n is Space) {
            sb.append ("sp(").append (Format.num (((Space) n).width * 18)).append (")");
            return;
        }
        string name = n.get_type ().name ().replace ("SingularityAppsFormula", "").down ();
        sb.append (name);
        if (n is Fenced) sb.append ("(").append (((Fenced) n).open).append (((Fenced) n).close).append (")");
        if (n is Accent) sb.append ("(").append (((Accent) n).mark).append (")");
        if (n is Table) sb.append ("(").append (((Table) n).kind.env_name ()).append (")");
        if (n is Scripts) {
            var s = (Scripts) n;
            sb.append ("{");
            if (s.sub != null) {
                sb.append ("_");
                dump_into (sb, s.sub);
            }
            if (s.sup != null) {
                sb.append ("^");
                dump_into (sb, s.sup);
            }
            sb.append ("}");
            return;
        }
        sb.append ("{");
        var slots = n.slots ();
        for (int i = 0; i < slots.length; i++) {
            if (i > 0) sb.append (",");
            dump_into (sb, slots[i]);
        }
        sb.append ("}");
    }
}
