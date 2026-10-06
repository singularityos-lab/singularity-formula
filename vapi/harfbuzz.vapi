[CCode (cheader_filename = "hb.h,hb-ot.h")]
namespace Hb {
    [Compact]
    [CCode (cname = "hb_blob_t", free_function = "hb_blob_destroy")]
    public class Blob {
        [CCode (cname = "hb_blob_create_from_file")]
        public Blob.from_file (string path);
        [CCode (cname = "hb_blob_get_length")]
        public uint get_length ();
    }

    [Compact]
    [CCode (cname = "hb_face_t", free_function = "hb_face_destroy")]
    public class Face {
        [CCode (cname = "hb_face_create")]
        public Face (Blob blob, uint index);
        [CCode (cname = "hb_face_get_upem")]
        public uint get_upem ();
        [CCode (cname = "hb_face_get_glyph_count")]
        public uint get_glyph_count ();
    }

    [CCode (cname = "hb_glyph_extents_t", has_type_id = false)]
    public struct GlyphExtents {
        public int32 x_bearing;
        public int32 y_bearing;
        public int32 width;
        public int32 height;
    }

    [CCode (cname = "hb_ot_math_glyph_variant_t", has_type_id = false)]
    public struct MathGlyphVariant {
        public uint32 glyph;
        public int32 advance;
    }

    [CCode (cname = "hb_ot_math_glyph_part_t", has_type_id = false)]
    public struct MathGlyphPart {
        public uint32 glyph;
        public int32 start_connector_length;
        public int32 end_connector_length;
        public int32 full_advance;
        public uint flags;
    }

    [CCode (cname = "hb_direction_t", cprefix = "HB_DIRECTION_", has_type_id = false)]
    public enum Direction {
        INVALID,
        LTR,
        RTL,
        TTB,
        BTT
    }

    [CCode (cname = "hb_feature_t", has_type_id = false)]
    public struct Feature {
        public uint32 tag;
        public uint32 value;
        public uint start;
        public uint end;
    }

    [CCode (cname = "hb_glyph_info_t", has_type_id = false)]
    public struct GlyphInfo {
        public uint32 codepoint;
        public uint32 mask;
        public uint32 cluster;
    }

    [CCode (cname = "hb_glyph_position_t", has_type_id = false)]
    public struct GlyphPosition {
        public int32 x_advance;
        public int32 y_advance;
        public int32 x_offset;
        public int32 y_offset;
    }

    [Compact]
    [CCode (cname = "hb_buffer_t", free_function = "hb_buffer_destroy")]
    public class Buffer {
        [CCode (cname = "hb_buffer_create")]
        public Buffer ();
        [CCode (cname = "hb_buffer_add_utf8")]
        public void add_utf8 (string text, int text_length, uint item_offset, int item_length);
        [CCode (cname = "hb_buffer_guess_segment_properties")]
        public void guess_segment_properties ();
        [CCode (cname = "hb_buffer_set_direction")]
        public void set_direction (Direction direction);
        [CCode (cname = "hb_buffer_get_glyph_infos", array_length_pos = 0.1, array_length_type = "guint")]
        public unowned GlyphInfo[] get_glyph_infos ();
        [CCode (cname = "hb_buffer_get_glyph_positions", array_length_pos = 0.1, array_length_type = "guint")]
        public unowned GlyphPosition[] get_glyph_positions ();
    }

    [Compact]
    [CCode (cname = "hb_font_t", free_function = "hb_font_destroy")]
    public class Font {
        [CCode (cname = "hb_font_create")]
        public Font (Face face);
        [CCode (cname = "hb_font_set_scale")]
        public void set_scale (int x_scale, int y_scale);
        [CCode (cname = "hb_font_get_nominal_glyph")]
        public bool get_nominal_glyph (uint32 unicode, out uint32 glyph);
        [CCode (cname = "hb_font_get_glyph_h_advance")]
        public int32 get_glyph_h_advance (uint32 glyph);
        [CCode (cname = "hb_font_get_glyph_extents")]
        public bool get_glyph_extents (uint32 glyph, out GlyphExtents extents);
    }

    [CCode (cname = "hb_feature_from_string")]
    public bool feature_from_string (string str, int len, out Feature feature);

    [CCode (cname = "hb_shape")]
    public void shape (Font font, Buffer buffer, [CCode (array_length_type = "guint")] Feature[]? features);

    [CCode (cname = "hb_ot_math_has_data")]
    public bool math_has_data (Face face);

    [CCode (cname = "hb_ot_math_get_constant")]
    public int32 math_constant (Font font, int constant);

    [CCode (cname = "hb_ot_math_get_glyph_italics_correction")]
    public int32 math_italics_correction (Font font, uint32 glyph);

    [CCode (cname = "hb_ot_math_get_glyph_top_accent_attachment")]
    public int32 math_top_accent_attachment (Font font, uint32 glyph);

    [CCode (cname = "hb_ot_math_is_glyph_extended_shape")]
    public bool math_is_extended_shape (Face face, uint32 glyph);

    [CCode (cname = "hb_ot_math_get_min_connector_overlap")]
    public int32 math_min_connector_overlap (Font font, Direction direction);

    [CCode (cname = "hb_ot_math_get_glyph_variants")]
    public uint math_glyph_variants (Font font, uint32 glyph, Direction direction, uint start_offset, ref uint count, [CCode (array_length = false)] MathGlyphVariant[] variants);

    [CCode (cname = "hb_ot_math_get_glyph_assembly")]
    public uint math_glyph_assembly (Font font, uint32 glyph, Direction direction, uint start_offset, ref uint count, [CCode (array_length = false)] MathGlyphPart[] parts, out int32 italics_correction);
}
