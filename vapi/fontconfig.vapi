[CCode (cheader_filename = "fontconfig/fontconfig.h")]
namespace Fc {
    [Compact]
    [CCode (cname = "FcPattern", free_function = "FcPatternDestroy")]
    public class Pattern {
        [CCode (cname = "FcNameParse")]
        public Pattern.parse (string name);
        [CCode (cname = "FcPatternCreate")]
        public Pattern ();
        [CCode (cname = "FcPatternGetString")]
        public int get_string (string object, int n, out unowned string value);
    }

    [Compact]
    [CCode (cname = "FcObjectSet", free_function = "FcObjectSetDestroy")]
    public class ObjectSet {
        [CCode (cname = "FcObjectSetCreate")]
        public ObjectSet ();
        [CCode (cname = "FcObjectSetAdd")]
        public bool add (string object);
    }

    [Compact]
    [CCode (cname = "FcFontSet", free_function = "FcFontSetDestroy")]
    public class FontSet {
        public int nfont;
        [CCode (array_length_cname = "nfont")]
        public unowned Pattern[] fonts;
    }

    [CCode (cname = "FcInit")]
    public bool init ();

    [CCode (cname = "FcConfigSubstitute")]
    public bool config_substitute (void* config, Pattern pattern, int kind);

    [CCode (cname = "FcDefaultSubstitute")]
    public void default_substitute (Pattern pattern);

    [CCode (cname = "FcFontMatch")]
    public Pattern? font_match (void* config, Pattern pattern, out int result);

    [CCode (cname = "FcFontList")]
    public FontSet? font_list (void* config, Pattern pattern, ObjectSet objects);
}
