using Singularity.Equations;

namespace Singularity.Apps.Formula {

    public class WordFormat {
        public const string DOCX_MIME = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

        public static bool is_docx (uint8[] data) {
            if (!Formats.is_zip (data)) return false;
            try {
                var zip = new ZipReader (data);
                return zip.has ("word/document.xml");
            } catch (Error e) {
                return false;
            }
        }

        private static void collect (MathNode n, Gee.ArrayList<string> list) {
            if (n.local == "oMathPara" || n.local == "oMath") {
                list.add (n.to_xml ());
                return;
            }
            foreach (var c in n.children) collect (c, list);
        }

        public static Gee.ArrayList<string> equations_in_xml (string xml) {
            var list = new Gee.ArrayList<string> ();
            var root = MathXml.parse (xml);
            if (root != null) collect (root, list);
            return list;
        }

        public static Gee.ArrayList<string> equations_in_docx (uint8[] data) throws Error {
            var zip = new ZipReader (data);
            string? xml = zip.read_text ("word/document.xml");
            if (xml == null) throw new IOError.INVALID_DATA (_("The document has no body"));
            return equations_in_xml (xml);
        }

        public static FormulaDoc doc_from_omml (string omml) throws Error {
            bool display;
            Justification jc;
            string mml = Omml.to_mathml (omml, out display, out jc);
            var doc = FormulaDoc.parse_any (mml);
            doc.display = display;
            doc.justification = jc;
            return doc;
        }

        public static FormulaDoc read_docx (uint8[] data, int index = 0) throws Error {
            var list = equations_in_docx (data);
            if (list.size == 0) throw new IOError.NOT_FOUND (_("The document contains no equations"));
            return doc_from_omml (list[int.min (index, list.size - 1)]);
        }

        public static string omml_of (FormulaDoc doc, bool html = false) {
            return Omml.from_mathml (doc.to_mathml (false, false), doc.display, doc.justification, html);
        }

        public static string document_xml (FormulaDoc doc) {
            var sb = new StringBuilder ();
            sb.append ("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n");
            sb.append ("<w:document xmlns:w=\"").append (Omml.W_NS).append ("\" xmlns:m=\"").append (Omml.NS).append ("\">");
            sb.append ("<w:body><w:p>");
            string omml = omml_of (doc);
            omml = omml.replace (" xmlns:m=\"" + Omml.NS + "\"", "").replace (" xmlns:w=\"" + Omml.W_NS + "\"", "");
            sb.append (omml);
            sb.append ("</w:p><w:sectPr/></w:body></w:document>");
            return sb.str;
        }

        public static uint8[] write_docx (FormulaDoc doc) throws Error {
            var zip = new ZipWriter ();
            zip.add_text ("[Content_Types].xml", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">"
                + "<Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/>"
                + "<Default Extension=\"xml\" ContentType=\"application/xml\"/>"
                + "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
                + "</Types>");
            zip.add_text ("_rels/.rels", "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
                + "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
                + "<Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/>"
                + "</Relationships>");
            zip.add_text ("word/document.xml", document_xml (doc));
            return zip.finish ();
        }

        public static string clipboard_html (FormulaDoc doc) {
            var eq = new Equation.from_mathml (doc.to_mathml (false, true));
            eq.display = doc.display;
            eq.justification = doc.justification;
            return eq.to_word_html ();
        }
    }
}
