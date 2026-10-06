[CCode (cheader_filename = "ft2build.h,freetype/freetype.h")]
namespace FT {
    [SimpleType]
    [CCode (cname = "FT_Library", has_type_id = false)]
    public struct Library {
    }

    [SimpleType]
    [CCode (cname = "FT_Face", has_type_id = false)]
    public struct Face {
    }

    [CCode (cname = "FT_Init_FreeType")]
    public int init (out Library library);

    [CCode (cname = "FT_New_Face")]
    public int new_face (Library library, string path, long index, out Face face);
}
