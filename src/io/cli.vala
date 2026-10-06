namespace Singularity.Apps.Formula {

    public class Cli {
        public static string metrics_json (Exporter ex, double scale) {
            double w, h;
            DocLayout dl;
            ex.extent (out w, out h, out dl);
            double baseline = ex.padding + dl.ascent;
            return "{\"width\": %s, \"height\": %s, \"baseline\": %s, \"scale\": %s, \"lines\": %d}".printf (
                Format.num (w), Format.num (h), Format.num (baseline), Format.num (scale), dl.box.line_count);
        }

        public static int render (string[] args) {
            string? input = null;
            string? output = null;
            double size = 36;
            double scale = 2;
            double padding = -1;
            double width = 0;
            string? family = null;
            string? mathml_out = null;
            string justify = "";
            bool numbered = false;
            bool inline = false;
            bool metrics = false;
            for (int i = 2; i < args.length; i++) {
                string a = args[i];
                if (a == "--size" && i + 1 < args.length) size = double.parse (args[++i]);
                else if (a == "--scale" && i + 1 < args.length) scale = double.parse (args[++i]);
                else if (a == "--font" && i + 1 < args.length) family = args[++i];
                else if (a == "--padding" && i + 1 < args.length) padding = double.parse (args[++i]);
                else if (a == "--width" && i + 1 < args.length) width = double.parse (args[++i]);
                else if (a == "--justify" && i + 1 < args.length) justify = args[++i];
                else if (a == "--mathml-out" && i + 1 < args.length) mathml_out = args[++i];
                else if (a == "--numbered") numbered = true;
                else if (a == "--inline") inline = true;
                else if (a == "--metrics") metrics = true;
                else if (a == "--transparent") continue;
                else if (input == null) input = a;
                else if (output == null) output = a;
            }
            if (input == null || output == null) {
                stderr.printf ("%s\n", _("Usage: singularity-formula --render FORMULA OUTPUT [--size N] [--scale N] [--font FAMILY] [--numbered] [--inline] [--metrics] [--padding N] [--width POINTS] [--justify left|center|right|center-group] [--mathml-out FILE]"));
                return 2;
            }
            try {
                FormulaDoc doc;
                if (FileUtils.test (input, FileTest.IS_REGULAR)) doc = Formats.load (input);
                else doc = FormulaDoc.parse_any (input);
                if (numbered) doc.numbered = true;
                if (inline) doc.display = false;
                if (width > 0 && size > 0) doc.line_width = width / size;
                if (justify != "") doc.justification = Singularity.Equations.Justification.from_mathml (justify);
                var font = MathFont.get_default (family);
                var kind = FileKind.for_path (output);
                var ex = new Exporter (doc, font, size);
                if (padding >= 0) ex.padding = padding;
                if (kind == FileKind.PNG) {
                    ex.write_png (output, scale);
                } else if (kind == FileKind.SVG) {
                    ex.write_svg (output);
                } else if (kind == FileKind.PDF) {
                    ex.write_pdf (output);
                } else {
                    Formats.save (doc, output, font, size);
                }
                if (mathml_out != null) FileUtils.set_contents (mathml_out, doc.to_mathml (true, true));
                if (metrics) stdout.printf ("%s\n", metrics_json (ex, kind == FileKind.PNG ? scale : 1.0));
            } catch (Error e) {
                stderr.printf ("%s\n", e.message);
                return 1;
            }
            return 0;
        }
    }
}
