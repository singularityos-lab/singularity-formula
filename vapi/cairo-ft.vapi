[CCode (cheader_filename = "cairo-ft.h")]
namespace CairoFt {
    [CCode (cname = "cairo_ft_font_face_create_for_ft_face")]
    public Cairo.FontFace create_font_face (FT.Face face, int load_flags);
}
