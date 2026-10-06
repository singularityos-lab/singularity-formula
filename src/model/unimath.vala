namespace Singularity.Apps.Formula {

    public class Unimath {
        private const MathVariant[] LATIN_ORDER = {
            MathVariant.BOLD, MathVariant.ITALIC, MathVariant.BOLD_ITALIC, MathVariant.SCRIPT, MathVariant.BOLD_SCRIPT,
            MathVariant.FRAKTUR, MathVariant.DOUBLE_STRUCK, MathVariant.BOLD_FRAKTUR, MathVariant.SANS_SERIF,
            MathVariant.BOLD_SANS_SERIF, MathVariant.SANS_SERIF_ITALIC, MathVariant.SANS_SERIF_BOLD_ITALIC, MathVariant.MONOSPACE
        };

        private const MathVariant[] GREEK_ORDER = {
            MathVariant.BOLD, MathVariant.ITALIC, MathVariant.BOLD_ITALIC, MathVariant.BOLD_SANS_SERIF, MathVariant.SANS_SERIF_BOLD_ITALIC
        };

        private const MathVariant[] DIGIT_ORDER = {
            MathVariant.BOLD, MathVariant.DOUBLE_STRUCK, MathVariant.SANS_SERIF, MathVariant.BOLD_SANS_SERIF, MathVariant.MONOSPACE
        };

        private const uint[] HOLES = {
            0x1d455, 0x210e, 0x1d49d, 0x212c, 0x1d4a0, 0x2130, 0x1d4a1, 0x2131, 0x1d4a3, 0x210b, 0x1d4a4, 0x2110,
            0x1d4a7, 0x2112, 0x1d4a8, 0x2133, 0x1d4ad, 0x211b, 0x1d4ba, 0x212f, 0x1d4bc, 0x210a, 0x1d4c4, 0x2134,
            0x1d506, 0x212d, 0x1d50b, 0x210c, 0x1d50c, 0x2111, 0x1d515, 0x211c, 0x1d51d, 0x2128,
            0x1d53a, 0x2102, 0x1d53f, 0x210d, 0x1d545, 0x2115, 0x1d547, 0x2119, 0x1d548, 0x211a, 0x1d549, 0x211d, 0x1d551, 0x2124
        };

        private static int latin_index (MathVariant v) {
            for (int i = 0; i < LATIN_ORDER.length; i++) if (LATIN_ORDER[i] == v) return i;
            return -1;
        }

        private static unichar fill_hole (uint cp) {
            for (int i = 0; i + 1 < HOLES.length; i += 2) if (HOLES[i] == cp) return (unichar) HOLES[i + 1];
            return (unichar) cp;
        }

        private static int greek_offset (unichar c) {
            if (c >= 0x391 && c <= 0x3a9) return c == 0x3a2 ? 17 : (int) (c - 0x391);
            if (c == 0x3f4) return 17;
            if (c == 0x2207) return 25;
            if (c >= 0x3b1 && c <= 0x3c9) return 26 + (int) (c - 0x3b1);
            switch (c) {
                case 0x2202: return 51;
                case 0x3f5: return 52;
                case 0x3d1: return 53;
                case 0x3f0: return 54;
                case 0x3d5: return 55;
                case 0x3f1: return 56;
                case 0x3d6: return 57;
                default: return -1;
            }
        }

        public static unichar styled (unichar c, MathVariant v) {
            if (v == MathVariant.DEFAULT || v == MathVariant.NORMAL) return c;
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
                int idx = latin_index (v);
                if (idx < 0) return c;
                uint off = c >= 'a' ? 26 + (c - 'a') : (c - 'A');
                return fill_hole (0x1d400 + (uint) idx * 52 + off);
            }
            if (c >= '0' && c <= '9') {
                for (int i = 0; i < DIGIT_ORDER.length; i++) {
                    if (DIGIT_ORDER[i] == v) return (unichar) (0x1d7ce + i * 10 + (c - '0'));
                }
                return c;
            }
            int g = greek_offset (c);
            if (g >= 0) {
                for (int i = 0; i < GREEK_ORDER.length; i++) {
                    if (GREEK_ORDER[i] == v) return (unichar) (0x1d6a8 + i * 58 + g);
                }
                return c;
            }
            if (v == MathVariant.ITALIC) {
                if (c == 0x131) return 0x1d6a4;
                if (c == 0x237) return 0x1d6a5;
            }
            return c;
        }

        public static unichar from_styled (unichar c, out MathVariant v) {
            v = MathVariant.DEFAULT;
            for (int i = 0; i + 1 < HOLES.length; i += 2) {
                if (HOLES[i + 1] == c) {
                    c = (unichar) HOLES[i];
                    break;
                }
            }
            if (c >= 0x1d400 && c < 0x1d400 + 13 * 52) {
                uint off = c - 0x1d400;
                v = LATIN_ORDER[off / 52];
                uint k = off % 52;
                return k < 26 ? (unichar) ('A' + k) : (unichar) ('a' + k - 26);
            }
            if (c == 0x1d6a4) {
                v = MathVariant.ITALIC;
                return 0x131;
            }
            if (c == 0x1d6a5) {
                v = MathVariant.ITALIC;
                return 0x237;
            }
            if (c >= 0x1d6a8 && c < 0x1d6a8 + 5 * 58) {
                uint off = c - 0x1d6a8;
                v = GREEK_ORDER[off / 58];
                int g = (int) (off % 58);
                if (g < 25) return g == 17 ? (unichar) 0x3f4 : (unichar) (0x391 + g);
                if (g == 25) return 0x2207;
                if (g < 51) return (unichar) (0x3b1 + g - 26);
                unichar[] tail = { 0x2202, 0x3f5, 0x3d1, 0x3f0, 0x3d5, 0x3f1, 0x3d6 };
                return tail[g - 51];
            }
            if (c >= 0x1d7ce && c <= 0x1d7ff) {
                uint off = c - 0x1d7ce;
                v = DIGIT_ORDER[off / 10];
                return (unichar) ('0' + off % 10);
            }
            return c;
        }

        public static bool italic_by_default (unichar c) {
            if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) return true;
            if (c >= 0x3b1 && c <= 0x3c9) return true;
            if (c == 0x3f5 || c == 0x3d1 || c == 0x3f0 || c == 0x3d5 || c == 0x3f1 || c == 0x3d6) return true;
            if (c == 0x131 || c == 0x237) return true;
            return false;
        }
    }
}
