namespace Singularity.Apps.Formula {

    public enum FileKind {
        MATHML,
        ODF,
        LATEX,
        UNICODEMATH,
        SVG,
        PNG,
        PDF,
        DOCX,
        OMML;

        public static FileKind for_path (string path) {
            string p = path.down ();
            if (p.has_suffix (".odf")) return ODF;
            if (p.has_suffix (".tex") || p.has_suffix (".latex")) return LATEX;
            if (p.has_suffix (".txt") || p.has_suffix (".um")) return UNICODEMATH;
            if (p.has_suffix (".svg")) return SVG;
            if (p.has_suffix (".png")) return PNG;
            if (p.has_suffix (".pdf")) return PDF;
            if (p.has_suffix (".docx")) return DOCX;
            if (p.has_suffix (".omml")) return OMML;
            return MATHML;
        }

        public string extension () {
            switch (this) {
                case ODF: return "odf";
                case LATEX: return "tex";
                case UNICODEMATH: return "txt";
                case SVG: return "svg";
                case PNG: return "png";
                case PDF: return "pdf";
                case DOCX: return "docx";
                case OMML: return "omml";
                default: return "mml";
            }
        }
    }

    public class Formats {
        public const string ODF_MIME = "application/vnd.oasis.opendocument.formula";

        public static FormulaDoc load (string path) throws Error {
            uint8[] data;
            FileUtils.get_data (path, out data);
            var doc = load_bytes (data, path);
            doc.path = path;
            doc.modified = false;
            return doc;
        }

        public static bool is_zip (uint8[] data) {
            return data.length > 4 && data[0] == 'P' && data[1] == 'K' && data[2] == 3 && data[3] == 4;
        }

        public static FormulaDoc load_bytes (uint8[] data, string name) throws Error {
            if (WordFormat.is_docx (data)) return WordFormat.read_docx (data);
            if (is_zip (data)) return read_odf (data);
            string text = ((string) data).make_valid ((ssize_t) data.length);
            if (text.contains ("oMath") && !text.contains ("<math")) {
                var found = WordFormat.equations_in_xml (text);
                if (found.size > 0) return WordFormat.doc_from_omml (found[0]);
            }
            var kind = FileKind.for_path (name);
            if (kind == FileKind.LATEX) {
                string body = strip_tex_document (text);
                return FormulaDoc.parse_linear (body, LinearSyntax.LATEX);
            }
            if (kind == FileKind.UNICODEMATH) return FormulaDoc.parse_any (text);
            return FormulaDoc.parse_any (text);
        }

        public static string strip_tex_document (string text) {
            string t = text;
            int b = t.index_of ("\\begin{document}");
            int e = t.index_of ("\\end{document}");
            if (b >= 0 && e > b) t = t.substring (b + 16, e - b - 16);
            t = t.strip ();
            string[] envs = { "equation*", "equation", "displaymath", "math" };
            foreach (var env in envs) {
                string open = "\\begin{" + env + "}";
                string close = "\\end{" + env + "}";
                if (t.has_prefix (open) && t.has_suffix (close)) {
                    t = t.substring (open.length, t.length - open.length - close.length).strip ();
                    break;
                }
            }
            if (t.has_prefix ("\\[") && t.has_suffix ("\\]")) t = t.substring (2, t.length - 4);
            if (t.has_prefix ("$$") && t.has_suffix ("$$") && t.length > 4) t = t.substring (2, t.length - 4);
            else if (t.has_prefix ("$") && t.has_suffix ("$") && t.length > 2) t = t.substring (1, t.length - 2);
            return t.strip ();
        }

        public static FormulaDoc read_odf (uint8[] data) throws Error {
            var zip = new ZipReader (data);
            string? content = zip.read_text ("content.xml");
            if (content == null) throw new IOError.INVALID_DATA (_("The file has no formula content"));
            var reader = new MathmlReader ();
            var res = reader.read (content);
            var doc = new FormulaDoc.from_result (res);
            doc.display = reader.display;
            return doc;
        }

        public static uint8[] write_odf (FormulaDoc doc) throws Error {
            var zip = new ZipWriter ();
            zip.add_text ("mimetype", ODF_MIME, false);
            zip.add_text ("content.xml", odf_content (doc));
            zip.add_text ("meta.xml", odf_meta ());
            zip.add_text ("META-INF/manifest.xml", odf_manifest ());
            return zip.finish ();
        }

        public static string odf_content (FormulaDoc doc) {
            string star = StarMathWriter.write (doc.root);
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + doc.to_mathml (true, true, star, "StarMath 5.0");
        }

        private static string odf_meta () {
            var now = new DateTime.now_utc ();
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                + "<office:document-meta xmlns:office=\"urn:oasis:names:tc:opendocument:xmlns:office:1.0\" xmlns:meta=\"urn:oasis:names:tc:opendocument:xmlns:meta:1.0\" office:version=\"1.3\">"
                + "<office:meta><meta:generator>Singularity Formula</meta:generator><meta:creation-date>" + now.format ("%Y-%m-%dT%H:%M:%S") + "</meta:creation-date></office:meta></office:document-meta>\n";
        }

        private static string odf_manifest () {
            return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                + "<manifest:manifest xmlns:manifest=\"urn:oasis:names:tc:opendocument:xmlns:manifest:1.0\" manifest:version=\"1.3\">\n"
                + " <manifest:file-entry manifest:full-path=\"/\" manifest:version=\"1.3\" manifest:media-type=\"" + ODF_MIME + "\"/>\n"
                + " <manifest:file-entry manifest:full-path=\"content.xml\" manifest:media-type=\"text/xml\"/>\n"
                + " <manifest:file-entry manifest:full-path=\"meta.xml\" manifest:media-type=\"text/xml\"/>\n"
                + "</manifest:manifest>\n";
        }

        public static string latex_document (FormulaDoc doc) {
            var sb = new StringBuilder ();
            sb.append ("\\documentclass{article}\n\\usepackage{amsmath,amssymb,cancel,xcolor}\n\\begin{document}\n");
            bool numbered = doc.numbered || doc.tag != null;
            sb.append (numbered ? "\\begin{equation}\n" : "\\[\n");
            sb.append (doc.to_latex ()).append ("\n");
            sb.append (numbered ? "\\end{equation}\n" : "\\]\n");
            sb.append ("\\end{document}\n");
            return sb.str;
        }

        public static void save (FormulaDoc doc, string path, MathFont font, double size) throws Error {
            var kind = FileKind.for_path (path);
            switch (kind) {
                case FileKind.ODF:
                    FileUtils.set_data (path, write_odf (doc));
                    break;
                case FileKind.LATEX:
                    FileUtils.set_contents (path, latex_document (doc));
                    break;
                case FileKind.UNICODEMATH:
                    FileUtils.set_contents (path, doc.to_unicodemath () + "\n");
                    break;
                case FileKind.SVG:
                    new Exporter (doc, font, size).write_svg (path);
                    break;
                case FileKind.PDF:
                    new Exporter (doc, font, size).write_pdf (path);
                    break;
                case FileKind.PNG:
                    var ex = new Exporter (doc, font, size);
                    ex.write_png (path, 2.0);
                    break;
                case FileKind.DOCX:
                    FileUtils.set_data (path, WordFormat.write_docx (doc));
                    break;
                case FileKind.OMML:
                    FileUtils.set_contents (path, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + WordFormat.omml_of (doc));
                    break;
                default:
                    FileUtils.set_contents (path, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + doc.to_mathml (true, true));
                    break;
            }
        }
    }
}
