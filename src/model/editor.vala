namespace Singularity.Apps.Formula {

    public class UndoState {
        public Row root;
        public int[] path;
        public int index;
        public string? tag;

        public UndoState (Row root, int[] path, int index, string? tag) {
            this.root = root;
            this.path = path;
            this.index = index;
            this.tag = tag;
        }
    }

    public class Editor : Object {
        public FormulaDoc doc { get; private set; }
        public Row row { get; private set; }
        public int index { get; private set; }
        public int anchor = -1;
        public string? pending;
        public bool text_mode;
        private bool expect_brace;
        private Row? auto_slot;
        private Gee.ArrayList<UndoState> undo_stack = new Gee.ArrayList<UndoState> ();
        private Gee.ArrayList<UndoState> redo_stack = new Gee.ArrayList<UndoState> ();
        private string coalesce = "";

        public signal void changed ();
        public signal void moved ();

        public Editor (FormulaDoc doc) {
            this.doc = doc;
            row = doc.root;
            index = doc.root.size;
        }

        public bool can_undo {
            get { return undo_stack.size > 0; }
        }

        public bool can_redo {
            get { return redo_stack.size > 0; }
        }

        public bool has_selection {
            get { return anchor >= 0 && anchor != index; }
        }

        public int sel_start {
            get { return has_selection ? int.min (anchor, index) : index; }
        }

        public int sel_end {
            get { return has_selection ? int.max (anchor, index) : index; }
        }

        public static int[] path_of (Row r) {
            int[] rev = {};
            Row cur = r;
            while (cur.parent != null) {
                var owner = cur.parent;
                var slots = owner.slots ();
                int si = 0;
                for (int i = 0; i < slots.length; i++) if (slots[i] == cur) si = i;
                var prow = owner.parent as Row;
                if (prow == null) break;
                rev += si;
                rev += prow.index_of (owner);
                cur = prow;
            }
            int[] path = new int[rev.length];
            for (int i = 0; i < rev.length; i++) path[i] = rev[rev.length - 1 - i];
            return path;
        }

        public static Row? row_at_path (Row root, int[] path) {
            Row cur = root;
            for (int i = 0; i + 1 < path.length; i += 2) {
                if (path[i] < 0 || path[i] >= cur.size) return null;
                var slots = cur[path[i]].slots ();
                if (path[i + 1] < 0 || path[i + 1] >= slots.length) return null;
                cur = slots[path[i + 1]];
            }
            return cur;
        }

        private UndoState snap () {
            return new UndoState (doc.root.copy_row (), path_of (row), index, doc.tag);
        }

        private void restore (UndoState s) {
            var copy = s.root.copy_row ();
            doc.set_root (copy);
            doc.tag = s.tag;
            var r = row_at_path (copy, s.path);
            row = r ?? copy;
            index = int.min (s.index, row.size);
            anchor = -1;
            pending = null;
        }

        public void checkpoint (string group = "") {
            if (group != "" && coalesce == group && undo_stack.size > 0) return;
            undo_stack.add (snap ());
            if (undo_stack.size > 300) undo_stack.remove_at (0);
            redo_stack.clear ();
            coalesce = group;
        }

        private void end_coalesce () {
            coalesce = "";
        }

        public void undo () {
            if (undo_stack.size == 0) return;
            redo_stack.add (snap ());
            restore (undo_stack.remove_at (undo_stack.size - 1));
            coalesce = "";
            notify_change ();
        }

        public void redo () {
            if (redo_stack.size == 0) return;
            undo_stack.add (snap ());
            restore (redo_stack.remove_at (redo_stack.size - 1));
            coalesce = "";
            notify_change ();
        }

        private void notify_change () {
            doc.modified = true;
            doc.changed ();
            changed ();
            moved ();
        }

        public void reset (FormulaDoc d) {
            doc = d;
            row = d.root;
            index = d.root.size;
            anchor = -1;
            pending = null;
            text_mode = false;
            undo_stack.clear ();
            redo_stack.clear ();
            moved ();
        }

        public void replace_root (Row root, string? tag, bool keep_undo = true) {
            if (keep_undo) checkpoint ("sync");
            doc.set_root (root);
            doc.tag = tag;
            row = root;
            index = root.size;
            anchor = -1;
            pending = null;
            doc.modified = true;
            doc.changed ();
            changed ();
            moved ();
        }

        public void set_caret (Row r, int i, bool extend = false) {
            if (extend && r == row) {
                if (anchor < 0) anchor = index;
            } else {
                anchor = -1;
            }
            if (!extend || r != row) {
                row = r;
            }
            index = i.clamp (0, r.size);
            if (pending != null) finish_pending ();
            text_mode = false;
            end_coalesce ();
            moved ();
        }

        public void select_node (Node n) {
            var p = n.parent as Row;
            if (p == null) return;
            row = p;
            int i = p.index_of (n);
            anchor = i;
            index = i + 1;
            moved ();
        }

        public void select_all () {
            row = doc.root;
            anchor = 0;
            index = row.size;
            moved ();
        }

        public void clear_selection () {
            anchor = -1;
        }

        private static bool enterable (Node n) {
            return !(n is Token) && !(n is Space) && n.slots ().length > 0;
        }

        private bool step_right () {
            if (index < row.size) {
                var n = row[index];
                if (enterable (n)) {
                    row = n.slots ()[0];
                    index = 0;
                } else {
                    index++;
                }
                return true;
            }
            var owner = row.parent;
            if (owner == null) return false;
            var slots = owner.slots ();
            for (int i = 0; i < slots.length; i++) {
                if (slots[i] == row && i + 1 < slots.length) {
                    row = slots[i + 1];
                    index = 0;
                    return true;
                }
            }
            var prow = owner.parent as Row;
            if (prow == null) return false;
            row = prow;
            index = prow.index_of (owner) + 1;
            return true;
        }

        private bool step_left () {
            if (index > 0) {
                var n = row[index - 1];
                if (enterable (n)) {
                    var slots = n.slots ();
                    row = slots[slots.length - 1];
                    index = row.size;
                } else {
                    index--;
                }
                return true;
            }
            var owner = row.parent;
            if (owner == null) return false;
            var slots = owner.slots ();
            for (int i = 0; i < slots.length; i++) {
                if (slots[i] == row && i > 0) {
                    row = slots[i - 1];
                    index = row.size;
                    return true;
                }
            }
            var prow = owner.parent as Row;
            if (prow == null) return false;
            row = prow;
            index = prow.index_of (owner);
            return true;
        }

        public void move_right (bool extend = false) {
            if (pending != null) finish_pending ();
            text_mode = false;
            end_coalesce ();
            if (extend) {
                if (anchor < 0) anchor = index;
                if (index < row.size) index++;
                moved ();
                return;
            }
            if (has_selection) {
                index = sel_end;
                anchor = -1;
                moved ();
                return;
            }
            anchor = -1;
            step_right ();
            moved ();
        }

        public void move_left (bool extend = false) {
            if (pending != null) finish_pending ();
            text_mode = false;
            end_coalesce ();
            if (extend) {
                if (anchor < 0) anchor = index;
                if (index > 0) index--;
                moved ();
                return;
            }
            if (has_selection) {
                index = sel_start;
                anchor = -1;
                moved ();
                return;
            }
            anchor = -1;
            step_left ();
            moved ();
        }

        public void home (bool extend = false) {
            if (extend && anchor < 0) anchor = index;
            if (!extend) anchor = -1;
            index = 0;
            moved ();
        }

        public void end (bool extend = false) {
            if (extend && anchor < 0) anchor = index;
            if (!extend) anchor = -1;
            index = row.size;
            moved ();
        }

        private void collect_slots (Row r, Gee.ArrayList<Row> list) {
            list.add (r);
            foreach (var n in r.items) {
                if (n is Token || n is Space) continue;
                foreach (var s in n.slots ()) collect_slots (s, list);
            }
        }

        public void next_slot (bool backwards = false) {
            if (pending != null) finish_pending ();
            var list = new Gee.ArrayList<Row> ();
            collect_slots (doc.root, list);
            int at = list.index_of (row);
            if (at < 0) return;
            int n = list.size;
            for (int k = 1; k <= n; k++) {
                int j = backwards ? (at - k + n * 2) % n : (at + k) % n;
                var cand = list[j];
                if (cand.size == 0 || k == n) {
                    row = cand;
                    index = backwards ? cand.size : 0;
                    anchor = -1;
                    moved ();
                    return;
                }
            }
            if (!backwards) {
                row = list[(at + 1) % n];
                index = 0;
            } else {
                row = list[(at - 1 + n) % n];
                index = row.size;
            }
            anchor = -1;
            moved ();
        }

        public Row selection_copy () {
            if (!has_selection) return new Row ();
            return row.slice (sel_start, sel_end);
        }

        private Row take_selection () {
            var r = new Row ();
            if (!has_selection) return r;
            int s = sel_start;
            int e = sel_end;
            for (int i = s; i < e; i++) r.append (row.remove_at (s));
            index = s;
            anchor = -1;
            return r;
        }

        public void delete_selection () {
            if (!has_selection) return;
            checkpoint ();
            take_selection ();
            notify_change ();
        }

        private void put (Node n) {
            row.insert (index, n);
            index++;
        }

        private Row? operand_before () {
            int i = index;
            while (i > 0) {
                var n = row[i - 1];
                var t = n as Token;
                if (t != null && t.kind == TokenKind.OPERATOR && !t.prime) {
                    var cls = t.forced_class != AtomClass.NONE ? t.forced_class : Symbols.char_class (t.text);
                    if (cls == AtomClass.BIN || cls == AtomClass.REL || cls == AtomClass.PUNCT || cls == AtomClass.OPEN || Symbols.is_large_op (t.text)) break;
                }
                if (n is Space) break;
                i--;
            }
            if (i == index) return null;
            var r = new Row ();
            for (int k = i; k < index; k++) r.append (row.remove_at (i));
            index = i;
            return r;
        }

        private void enter_first_empty (Node n, int preferred = -1) {
            var slots = n.slots ();
            if (preferred >= 0 && preferred < slots.length) {
                row = slots[preferred];
                index = row.size;
                return;
            }
            foreach (var s in slots) {
                if (s.size == 0) {
                    row = s;
                    index = 0;
                    return;
                }
            }
            var p = n.parent as Row;
            if (p != null) {
                row = p;
                index = p.index_of (n) + 1;
            }
        }

        public void insert_node (Node n, int slot = -1, bool wrap = true) {
            if (pending != null) finish_pending ();
            checkpoint ();
            var sel = has_selection ? take_selection () : null;
            put (n);
            if (sel != null && wrap && n.slots ().length > 0) {
                var slots = n.slots ();
                var target = slots.length > 1 && n is Radical && ((Radical) n).index != null ? slots[1] : slots[0];
                target.move_from (sel);
            }
            if (n.slots ().length > 0 && !(n is Scripts)) enter_first_empty (n, slot);
            else if (n is Scripts) enter_first_empty (n, slot);
            expect_brace = n.slots ().length > 0 && !(n is Fenced);
            notify_change ();
        }

        public void insert_row (Row r) {
            if (r.size == 0) return;
            if (pending != null) finish_pending ();
            checkpoint ();
            if (has_selection) take_selection ();
            var items = new Gee.ArrayList<Node> ();
            items.add_all (r.items);
            r.clear ();
            foreach (var n in items) put (n);
            notify_change ();
        }

        public void insert_fraction (bool from_operand) {
            if (pending != null) finish_pending ();
            checkpoint ();
            Row? num = null;
            if (has_selection) num = take_selection ();
            else if (from_operand) num = operand_before ();
            var f = new Frac (num, null);
            put (f);
            if (num != null && num.size > 0) {
                row = f.den;
                index = 0;
            } else {
                row = f.num;
                index = 0;
            }
            expect_brace = true;
            notify_change ();
        }

        public void insert_script (bool sup) {
            if (pending != null) finish_pending ();
            checkpoint ();
            if (has_selection) {
                var sel = take_selection ();
                var g = sel.size == 1 ? sel.remove_at (0) : new Group (sel);
                put (g);
            }
            Scripts? s = index > 0 ? row[index - 1] as Scripts : null;
            if (s != null && !s.pre) {
                if (sup && s.sup == null) s.set_sup (new Row ());
                if (!sup && s.sub == null) s.set_sub (new Row ());
                row = sup ? s.sup : s.sub;
                index = row.size;
                expect_brace = true;
                notify_change ();
                return;
            }
            s = new Scripts (sup ? null : new Row (), sup ? new Row () : null);
            put (s);
            row = sup ? s.sup : s.sub;
            index = 0;
            expect_brace = true;
            notify_change ();
        }

        public void insert_subsup () {
            if (pending != null) finish_pending ();
            checkpoint ();
            var s = new Scripts (new Row (), new Row ());
            put (s);
            row = s.sub;
            index = 0;
            notify_change ();
        }

        public void insert_big_operator (string ch, bool with_limits) {
            if (pending != null) finish_pending ();
            checkpoint ();
            var sel = has_selection ? take_selection () : null;
            put (new Token.op (ch));
            Scripts? s = null;
            if (with_limits) {
                s = new Scripts (new Row (), new Row ());
                put (s);
            }
            if (sel != null) {
                var items = new Gee.ArrayList<Node> ();
                items.add_all (sel.items);
                sel.clear ();
                foreach (var n in items) put (n);
            }
            if (s != null) {
                row = s.sub;
                index = 0;
            }
            notify_change ();
        }

        public void insert_fenced (string open, string close) {
            var f = new Fenced (open, close);
            insert_node (f);
            if (f.body.size > 0) {
                row = f.body;
                index = f.body.size;
                moved ();
            }
        }

        public void insert_table (TableKind kind, int rows, int cols) {
            var t = new Table.sized (kind, rows, cols);
            insert_node (t);
        }

        public void insert_accent (string mark, bool stretchy, bool under) {
            if (!has_selection && index > 0 && !stretchy && row[index - 1] is Token) {
                var t = (Token) row[index - 1];
                if (t.kind != TokenKind.OPERATOR || t.text.char_count () == 1) {
                    checkpoint ();
                    row.remove_at (index - 1);
                    index--;
                    var b = new Row ();
                    b.append (t);
                    put (new Accent (mark, b, stretchy, under));
                    notify_change ();
                    return;
                }
            }
            insert_node (new Accent (mark, null, stretchy, under));
        }

        public void insert_text_mode () {
            text_mode = !text_mode;
            end_coalesce ();
            moved ();
        }

        private Table? current_table (out int r, out int c) {
            r = -1;
            c = -1;
            Row cur = row;
            while (cur != null) {
                var t = cur.parent as Table;
                if (t != null && t.locate (cur, out r, out c)) return t;
                var owner = cur.parent;
                if (owner == null) return null;
                cur = owner.parent as Row;
            }
            return null;
        }

        public bool in_table () {
            int r, c;
            return current_table (out r, out c) != null;
        }

        public void table_insert_row (bool below) {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null) return;
            checkpoint ();
            int at = below ? r + 1 : r;
            t.insert_row (at, t.column_count);
            int col = t.kind == TableKind.ALIGN && t.column_count > 1 ? 1 : 0;
            row = t.cell (at, col);
            index = 0;
            notify_change ();
        }

        public void table_insert_column (bool right) {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null) return;
            checkpoint ();
            int at = right ? c + 1 : c;
            t.insert_column (at);
            row = t.cell (r, at);
            index = 0;
            notify_change ();
        }

        public void table_delete_row () {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null) return;
            checkpoint ();
            if (t.row_count <= 1) {
                remove_table (t);
                return;
            }
            t.remove_row (r);
            Row? next = t.cell (int.min (r, t.row_count - 1), c);
            row = next != null ? next : t.cell (0, 0);
            index = 0;
            notify_change ();
        }

        public void table_delete_column () {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null) return;
            checkpoint ();
            if (t.column_count <= 1) {
                remove_table (t);
                return;
            }
            t.remove_column (c);
            Row? next = t.cell (r, int.min (c, t.column_count - 1));
            row = next != null ? next : t.cell (0, 0);
            index = 0;
            notify_change ();
        }

        private void remove_table (Table t) {
            var p = t.parent as Row;
            if (p == null) return;
            int at = p.index_of (t);
            p.remove_at (at);
            row = p;
            index = at;
            notify_change ();
        }

        public void next_cell () {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null) {
                next_slot ();
                return;
            }
            if (c + 1 < t.rows[r].size) {
                row = t.cell (r, c + 1);
            } else if (r + 1 < t.row_count) {
                row = t.cell (r + 1, 0);
            } else {
                var p = t.parent as Row;
                if (p != null) {
                    row = p;
                    index = p.index_of (t) + 1;
                    anchor = -1;
                    moved ();
                    return;
                }
            }
            index = 0;
            anchor = -1;
            moved ();
        }

        public void new_line () {
            if (pending != null) finish_pending ();
            int r, c;
            var t = current_table (out r, out c);
            if (t != null && (t.kind == TableKind.ALIGN || t.kind == TableKind.GATHER || t.kind == TableKind.CASES || t.kind.is_matrix () || t.kind == TableKind.ARRAY)) {
                table_insert_row (true);
                return;
            }
            if (row != doc.root) return;
            checkpoint ();
            var before = new Row ();
            var after = new Row ();
            for (int i = 0; i < index; i++) before.append (row[i].copy ());
            for (int i = index; i < row.size; i++) after.append (row[i].copy ());
            var table = new Table (TableKind.ALIGN);
            table.add_row_cells (split_at_relation (before));
            table.add_row_cells (split_at_relation (after));
            var root = new Row ();
            root.append (table);
            doc.set_root (root);
            table.tags[0] = doc.tag;
            doc.tag = null;
            row = table.cell (1, 1);
            index = 0;
            anchor = -1;
            notify_change ();
        }

        private static Gee.ArrayList<Row> split_at_relation (Row r) {
            var cells = new Gee.ArrayList<Row> ();
            int at = -1;
            for (int i = 0; i < r.size; i++) {
                var t = r[i] as Token;
                if (t != null && t.kind == TokenKind.OPERATOR && Symbols.char_class (t.text) == AtomClass.REL) {
                    at = i;
                    break;
                }
            }
            var left = new Row ();
            var right = new Row ();
            for (int i = 0; i < r.size; i++) {
                if (at < 0 || i < at) {
                    if (at < 0) right.append (r[i].copy ());
                    else left.append (r[i].copy ());
                } else {
                    right.append (r[i].copy ());
                }
            }
            if (at < 0 && r.size > 0) {
                left.move_from (right);
            }
            cells.add (left);
            cells.add (right);
            return cells;
        }

        public void backspace () {
            if (pending != null) {
                if (pending.length > 0) pending = pending.substring (0, pending.length - 1);
                else pending = null;
                changed ();
                moved ();
                return;
            }
            if (has_selection) {
                delete_selection ();
                return;
            }
            if (index > 0) {
                var n = row[index - 1];
                if (n is Token || n is Space) {
                    checkpoint ("delete");
                    row.remove_at (index - 1);
                    index--;
                    notify_change ();
                    return;
                }
                bool empty = true;
                foreach (var s in n.slots ()) if (s.size > 0) empty = false;
                if (empty) {
                    checkpoint ();
                    row.remove_at (index - 1);
                    index--;
                    notify_change ();
                    return;
                }
                anchor = index - 1;
                moved ();
                return;
            }
            var owner = row.parent;
            if (owner == null) return;
            var prow = owner.parent as Row;
            if (prow == null) return;
            int r = -1, c = -1;
            var t = owner as Table;
            if (t != null && t.locate (row, out r, out c) && (r > 0 || c > 0)) {
                row = c > 0 ? t.cell (r, c - 1) : t.cell (r - 1, t.rows[r - 1].size - 1);
                index = row.size;
                moved ();
                return;
            }
            bool all_empty = true;
            foreach (var s in owner.slots ()) if (s.size > 0) all_empty = false;
            int at = prow.index_of (owner);
            if (all_empty) {
                checkpoint ();
                prow.remove_at (at);
                row = prow;
                index = at;
                notify_change ();
                return;
            }
            if (owner is Fenced || owner is Group || owner is Style || owner is Accent || owner is Enclose || (owner is Radical && ((Radical) owner).index == null)) {
                checkpoint ();
                var body = owner.slots ()[0];
                prow.remove_at (at);
                int k = at;
                var items = new Gee.ArrayList<Node> ();
                items.add_all (body.items);
                body.clear ();
                foreach (var it in items) prow.insert (k++, it);
                row = prow;
                index = at;
                notify_change ();
                return;
            }
            row = prow;
            anchor = at;
            index = at + 1;
            moved ();
        }

        public void delete_forward () {
            if (pending != null) return;
            if (has_selection) {
                delete_selection ();
                return;
            }
            if (index < row.size) {
                var n = row[index];
                if (n is Token || n is Space) {
                    checkpoint ("delete");
                    row.remove_at (index);
                    notify_change ();
                    return;
                }
                bool empty = true;
                foreach (var s in n.slots ()) if (s.size > 0) empty = false;
                if (empty) {
                    checkpoint ();
                    row.remove_at (index);
                    notify_change ();
                    return;
                }
                anchor = index + 1;
                moved ();
            }
        }

        private static bool autodetect_function (string name) {
            if (name == "ln") return true;
            if (name.length < 3 && (Symbols.autocorrect == null || !Symbols.autocorrect.is_function (name) || Symbols.autocorrect.is_default_function (name))) return false;
            return Symbols.is_function (name);
        }

        private void merge_function () {
            var sb = new StringBuilder ();
            int start = index;
            while (start > 0) {
                var t = row[start - 1] as Token;
                if (t == null || t.kind != TokenKind.IDENT || t.variant != MathVariant.DEFAULT) break;
                if (t.text.char_count () > 1 && !Symbols.is_function (t.text)) break;
                sb.prepend (t.text);
                start--;
                if (t.text.char_count () > 1) break;
            }
            string all = sb.str;
            for (int len = all.length; len >= 2; len--) {
                string cand = all.substring (all.length - len);
                if (!autodetect_function (cand)) continue;
                int count = 0;
                int acc = 0;
                for (int i = index - 1; i >= 0 && acc < len; i--) {
                    acc += ((Token) row[i]).text.length;
                    count++;
                }
                if (acc != len) continue;
                for (int i = 0; i < count; i++) row.remove_at (index - count);
                index -= count;
                var f = new Token.ident (cand);
                f.forced_class = AtomClass.OP;
                put (f);
                return;
            }
        }

        private bool combine_operator (string ch) {
            if (index == 0) return false;
            var p = row[index - 1] as Token;
            if (p == null || p.kind != TokenKind.OPERATOR) return false;
            string? r = null;
            string pair = p.text + ch;
            switch (pair) {
                case "<=": r = "\u2264"; break;
                case ">=": r = "\u2265"; break;
                case "!=": r = "\u2260"; break;
                case "\u2212>": r = "\u2192"; break;
                case "=>": r = "\u21d2"; break;
                case "<\u2212": r = "\u2190"; break;
                case "+\u2212": r = "\u00b1"; break;
                case "\u2212+": r = "\u2213"; break;
                case "<<": r = "\u226a"; break;
                case ">>": r = "\u226b"; break;
                case "~=": r = "\u2245"; break;
                case "==": r = "\u2261"; break;
                case "<>": r = "\u2260"; break;
                case "\u2264>": r = "\u21d4"; break;
                case "\u2190>": r = "\u2194"; break;
                default: break;
            }
            if (r == null) return false;
            p.text = r;
            return true;
        }

        public void type_text (string text) {
            int i = 0;
            unichar c;
            while (text.get_next_char (ref i, out c)) insert_char (c);
        }

        public void insert_char (unichar c) {
            if (pending != null) {
                if (c.isalpha () && c < 128) {
                    pending += c.to_string ();
                    changed ();
                    moved ();
                    return;
                }
                finish_pending ();
                if (c == ' ') return;
            }
            if (!text_mode && in_linear () && !has_selection) {
                checkpoint ("type");
                var lt = new Token.plain (c.to_string ());
                lt.variant = MathVariant.NORMAL;
                lt.linear = true;
                put (lt);
                notify_change ();
                return;
            }
            bool eb = expect_brace;
            expect_brace = false;
            if (!text_mode && eb && c == '{') auto_slot = null;
            if (!text_mode && auto_slot != null && row == auto_slot && row.size > 0 && ends_operand (c)) {
                var owner = row.parent;
                var prow = owner != null ? owner.parent as Row : null;
                auto_slot = null;
                if (prow != null) {
                    row = prow;
                    index = prow.index_of (owner) + 1;
                    moved ();
                }
                if (c == ' ') return;
            }
            if (!text_mode && latex_brace (c, eb)) return;
            if (text_mode) {
                if (has_selection) {
                    checkpoint ();
                    take_selection ();
                } else {
                    checkpoint ("type");
                }
                var t = new Token.plain (c.to_string ());
                t.variant = MathVariant.NORMAL;
                put (t);
                notify_change ();
                return;
            }
            if (c == '\\') {
                if (has_selection) delete_selection ();
                pending = "";
                changed ();
                moved ();
                return;
            }
            if (c == ' ') return;
            if (c == '^') {
                insert_script (true);
                auto_slot = row;
                return;
            }
            if (c == '_') {
                insert_script (false);
                auto_slot = row;
                return;
            }
            if (c == '/') {
                insert_fraction (true);
                if (row.parent is Frac && ((Frac) row.parent).den == row) auto_slot = row;
                return;
            }
            if (c == '\'') {
                checkpoint ("type");
                var pt = new Token.op ("\u2032");
                pt.prime = true;
                Scripts? s = index > 0 ? row[index - 1] as Scripts : null;
                if (s != null && s.sup != null && LatexParser.is_prime_row (s.sup)) {
                    s.sup.append (pt);
                } else {
                    var ns = new Scripts (null, new Row.with ({ pt }));
                    put (ns);
                }
                notify_change ();
                return;
            }
            string ch = c.to_string ();
            string? close = Symbols.matching_close (ch);
            if (ch == "|") {
                var f = row.parent as Fenced;
                if (f != null && f.close == "|" && index == row.size && row.size > 0) {
                    exit_fenced (f);
                    return;
                }
            }
            if (close != null && (ch == "(" || ch == "[" || ch == "{" || ch == "|")) {
                insert_fenced (ch, close);
                return;
            }
            if (ch == ")" || ch == "]" || ch == "}") {
                var f = row.parent as Fenced;
                if (f != null && f.close == ch && index == row.size) {
                    exit_fenced (f);
                    return;
                }
            }
            if (c == '&' && in_table ()) {
                next_cell ();
                return;
            }
            if (has_selection) {
                checkpoint ();
                take_selection ();
            } else {
                checkpoint ("type");
            }
            bool ellipsis = c == '.' && index >= 2 && row[index - 1] is Token && ((Token) row[index - 1]).text == "." && row[index - 2] is Token && ((Token) row[index - 2]).text == ".";
            if (ellipsis) {
                row.remove_at (index - 1);
                row.remove_at (index - 2);
                index -= 2;
                put (new Token.op ("\u2026"));
            } else if (c.isdigit () || (c == '.' && index > 0 && row[index - 1] is Token && ((Token) row[index - 1]).kind == TokenKind.NUMBER && ((Token) row[index - 1]).text != ".")) {
                put (new Token.number (ch));
            } else if (c.isalpha ()) {
                var sym = Symbols.by_char (ch);
                if (sym != null && sym.largeop) {
                    put (new Token.op (ch));
                } else {
                    put (new Token.ident (ch));
                    if (c < 128) merge_function ();
                    else if (index >= 2) {
                        var f = row[index - 2] as Token;
                        if (f != null && f.kind == TokenKind.IDENT && f.text.char_count () > 1 && Symbols.is_function (f.text + ch)) {
                            f.text = f.text + ch;
                            row.remove_at (index - 1);
                            index--;
                        }
                    }
                }
            } else {
                string op = ch;
                if (op == "-") op = "\u2212";
                if (op == "*") op = "\u22c5";
                if (Symbols.autocorrect != null || !combine_operator (op)) {
                    if (op == "." && index >= 2 && row[index - 1] is Token && ((Token) row[index - 1]).text == "." && row[index - 2] is Token && ((Token) row[index - 2]).text == ".") {
                        row.remove_at (index - 1);
                        row.remove_at (index - 2);
                        index -= 2;
                        put (new Token.op ("\u2026"));
                    } else {
                        var sym = Symbols.by_char (op);
                        var t = new Token (sym != null && sym.category == "greek" ? TokenKind.IDENT : TokenKind.OPERATOR, op);
                        put (t);
                        autocorrect_operators ();
                    }
                }
            }
            notify_change ();
        }

        private static bool ends_operand (unichar c) {
            if (c == ' ') return true;
            string s = c.to_string ();
            if (s == "-") s = "\u2212";
            var cls = Symbols.char_class (s);
            return cls == AtomClass.BIN || cls == AtomClass.REL || cls == AtomClass.PUNCT || c == ')' || c == ']' || c == '}' || c == '|';
        }

        private bool latex_brace (unichar c, bool eb) {
            if (c == '{' && eb) return true;
            if (c == '[' && eb && row.size == 0) {
                var rad = row.parent as Radical;
                if (rad != null && rad.index == null && rad.body == row) {
                    checkpoint ();
                    rad.set_index (new Row ());
                    row = rad.index;
                    index = 0;
                    notify_change ();
                    return true;
                }
            }
            if (c == ']') {
                var rad = row.parent as Radical;
                if (rad != null && rad.index == row) {
                    row = rad.body;
                    index = rad.body.size;
                    expect_brace = true;
                    moved ();
                    return true;
                }
            }
            if (c == '}') {
                var owner = row.parent;
                if (owner == null || owner is Table || (owner is Fenced && ((Fenced) owner).close == "}")) return false;
                var slots = owner.slots ();
                for (int i = 0; i < slots.length; i++) {
                    if (slots[i] != row) continue;
                    if (i + 1 < slots.length) {
                        row = slots[i + 1];
                        index = row.size;
                        expect_brace = true;
                        moved ();
                        return true;
                    }
                }
                var prow = owner.parent as Row;
                if (prow == null) return false;
                row = prow;
                index = prow.index_of (owner) + 1;
                moved ();
                return true;
            }
            return false;
        }

        private void exit_fenced (Fenced f) {
            var p = f.parent as Row;
            if (p == null) return;
            row = p;
            index = p.index_of (f) + 1;
            anchor = -1;
            end_coalesce ();
            moved ();
        }

        public void finish_pending () {
            string? name = pending;
            pending = null;
            if (name == null) return;
            if (name == "") {
                checkpoint ();
                put (new Token.op ("\\"));
                notify_change ();
                return;
            }
            var ac = Symbols.autocorrect;
            if (ac != null && ac.is_custom ("\\" + name)) {
                string? rep = ac.lookup ("\\" + name);
                if (rep != null && insert_replacement (rep)) return;
            }
            if (!known_command (name) && ac != null) {
                string? rep = ac.lookup ("\\" + name);
                if (rep != null && insert_replacement (rep)) return;
            }
            run_command (name);
        }

        public static bool known_command (string name) {
            double sp;
            if (Symbols.named_space (name, out sp)) return true;
            switch (name) {
                case "frac": case "over": case "dfrac": case "binom": case "sqrt": case "root": case "text":
                case "matrix": case "pmatrix": case "bmatrix": case "vmatrix": case "Bmatrix": case "Vmatrix":
                case "cases": case "aligned": case "align": case "left": case "boxed": case "cancel":
                case "overset": case "underset": case "lim": case "prescript": case "eqref":
                    return true;
                default:
                    break;
            }
            MathVariant v;
            if (Symbols.font_command (name, out v)) return true;
            if (Symbols.accent (name) != null) return true;
            if (Symbols.is_function (name)) return true;
            return Symbols.by_command (name) != null;
        }

        public bool insert_replacement (string text) {
            if (text == "") return false;
            if (text.char_count () == 1) {
                unichar c = text.get_char (0);
                if ((c >= 0x300 && c <= 0x36f) || (c >= 0x20d0 && c <= 0x20ff)) {
                    var info = Symbols.accent_for_mark (text, false, false);
                    insert_accent (info != null ? info.mark : text, false, false);
                    return true;
                }
                checkpoint ();
                var sym = Symbols.by_char (text);
                if (sym != null && sym.largeop) {
                    insert_big_operator (text, false);
                    return true;
                }
                bool letter = c.isalpha () || (sym != null && sym.category == "greek");
                put (new Token (letter ? TokenKind.IDENT : TokenKind.OPERATOR, text));
                notify_change ();
                return true;
            }
            try {
                var res = UnicodeMath.parse_result (text);
                if (res.root.size == 0) return false;
                insert_row (res.root);
                return true;
            } catch (ParseError e) {
                return false;
            }
        }

        private bool autocorrect_operators () {
            var ac = Symbols.autocorrect;
            if (ac == null || !ac.enabled) return false;
            var sb = new StringBuilder ();
            int count = 0;
            for (int i = index - 1; i >= 0 && count < 4; i--) {
                var t = row[i] as Token;
                if (t == null || t.kind != TokenKind.OPERATOR || t.prime || t.text.char_count () != 1) break;
                string ch = t.text == "\u2212" ? "-" : (t.text == "\u22c5" ? "*" : t.text);
                sb.prepend (ch);
                count++;
            }
            if (count < 2) return false;
            string tail = sb.str;
            foreach (var key in ac.operator_keys ()) {
                if (key.char_count () < 2 || key.char_count () > count || !tail.has_suffix (key)) continue;
                string? rep = ac.lookup (key);
                if (rep == null || rep.char_count () != 1) continue;
                int n = key.char_count ();
                for (int k = 0; k < n; k++) row.remove_at (index - 1 - k);
                index -= n;
                var sym = Symbols.by_char (rep);
                put (new Token (sym != null && sym.category == "greek" ? TokenKind.IDENT : TokenKind.OPERATOR, rep));
                return true;
            }
            return false;
        }

        private static bool is_linear (Node n) {
            var t = n as Token;
            return t != null && t.linear;
        }

        public bool in_linear () {
            if (index > 0 && is_linear (row[index - 1])) return true;
            return index < row.size && is_linear (row[index]);
        }

        public void toggle_linear (LinearSyntax syntax) {
            if (pending != null) finish_pending ();
            if (!has_selection) {
                if (in_linear ()) {
                    int a = index;
                    int b = index;
                    while (a > 0 && is_linear (row[a - 1])) a--;
                    while (b < row.size && is_linear (row[b])) b++;
                    anchor = a;
                    index = b;
                } else {
                    anchor = 0;
                    index = row.size;
                }
            }
            if (!has_selection) return;
            bool all_linear = true;
            for (int i = sel_start; i < sel_end; i++) if (!is_linear (row[i])) all_linear = false;
            if (all_linear) {
                var sb = new StringBuilder ();
                for (int i = sel_start; i < sel_end; i++) sb.append (((Token) row[i]).text);
                ParseResult res;
                try {
                    if (syntax == LinearSyntax.LATEX) res = LatexParser.parse (sb.str);
                    else res = UnicodeMath.parse_result (sb.str);
                } catch (ParseError e) {
                    return;
                }
                Row parsed = res.root;
                checkpoint ();
                take_selection ();
                var items = new Gee.ArrayList<Node> ();
                items.add_all (parsed.items);
                parsed.clear ();
                int start = index;
                foreach (var n in items) put (n);
                anchor = start;
                notify_change ();
                return;
            }
            checkpoint ();
            var sel = take_selection ();
            string text = syntax == LinearSyntax.LATEX ? LatexWriter.write (sel) : UnicodeMath.write (sel);
            int start = index;
            int i = 0;
            unichar c;
            while (text.get_next_char (ref i, out c)) {
                var t = new Token.plain (c.to_string ());
                t.variant = MathVariant.NORMAL;
                t.linear = true;
                put (t);
            }
            anchor = start;
            notify_change ();
        }

        public Enclose? current_enclose () {
            Row? cur = row;
            while (cur != null) {
                var owner = cur.parent;
                if (owner == null) return null;
                if (owner is Enclose) return (Enclose) owner;
                cur = owner.parent as Row;
            }
            return null;
        }

        public static bool has_note (Enclose e, string note) {
            var words = new Gee.HashSet<string> ();
            foreach (var w in e.notation.split (" ")) if (w != "") words.add (w);
            bool all = words.contains ("box") || words.contains ("roundedbox") || words.contains ("circle");
            if (note == "top" || note == "bottom" || note == "left" || note == "right") return all || words.contains (note);
            return words.contains (note);
        }

        public void toggle_enclose_note (string note) {
            var e = current_enclose ();
            if (e == null) return;
            checkpoint ();
            var words = new Gee.ArrayList<string> ();
            foreach (var w in e.notation.split (" ")) {
                if (w == "") continue;
                if (w == "box" || w == "roundedbox" || w == "circle") {
                    foreach (var side in new string[] { "top", "bottom", "left", "right" }) words.add (side);
                    continue;
                }
                words.add (w);
            }
            if (words.contains (note)) words.remove (note);
            else words.add (note);
            bool full = words.contains ("top") && words.contains ("bottom") && words.contains ("left") && words.contains ("right");
            var result = new Gee.ArrayList<string> ();
            if (full) result.add ("box");
            foreach (var w in words) {
                if (full && (w == "top" || w == "bottom" || w == "left" || w == "right")) continue;
                result.add (w);
            }
            if (result.size == 0) {
                var p = e.parent as Row;
                if (p != null) {
                    int at = p.index_of (e);
                    p.remove_at (at);
                    var items = new Gee.ArrayList<Node> ();
                    items.add_all (e.body.items);
                    e.body.clear ();
                    int k = at;
                    foreach (var it in items) p.insert (k++, it);
                    row = p;
                    index = k;
                    anchor = -1;
                }
            } else {
                e.notation = string.joinv (" ", result.to_array ());
            }
            notify_change ();
        }

        public bool table_align_column (char align) {
            int r, c;
            var t = current_table (out r, out c);
            if (t == null || t.kind == TableKind.ALIGN || t.kind == TableKind.GATHER || t.kind == TableKind.CASES) return false;
            checkpoint ();
            int n = t.column_count;
            var sb = new StringBuilder ();
            for (int i = 0; i < n; i++) sb.append_c (i == c ? align : t.column_align (i));
            t.columns = sb.str;
            notify_change ();
            return true;
        }

        public Table? table_at_caret () {
            int r, c;
            return current_table (out r, out c);
        }

        public void table_set_spacing (double column_gap, double row_gap) {
            var t = table_at_caret ();
            if (t == null) return;
            checkpoint ();
            t.column_gap = column_gap;
            t.row_gap = row_gap;
            notify_change ();
        }

        public void insert_prescripts () {
            if (pending != null) finish_pending ();
            checkpoint ();
            var s = new Scripts (new Row (), new Row ());
            s.pre = true;
            put (s);
            row = s.sub;
            index = 0;
            notify_change ();
        }

        public void run_command (string name) {
            double sp;
            if (Symbols.named_space (name, out sp)) {
                checkpoint ();
                put (new Space (sp));
                notify_change ();
                return;
            }
            switch (name) {
                case "frac":
                case "over":
                    insert_fraction (false);
                    return;
                case "dfrac":
                    var df = new Frac ();
                    df.display = 1;
                    insert_node (df);
                    return;
                case "binom":
                    var bf = new Frac ();
                    bf.line = false;
                    var bf_body = new Row ();
                    bf_body.append (bf);
                    var fen = new Fenced ("(", ")", bf_body);
                    insert_node (fen);
                    row = bf.num;
                    index = 0;
                    moved ();
                    return;
                case "sqrt":
                    insert_node (new Radical ());
                    return;
                case "root":
                    insert_node (new Radical (null, new Row ()), 0);
                    return;
                case "text":
                    insert_text_mode ();
                    return;
                case "matrix":
                case "pmatrix":
                case "bmatrix":
                case "vmatrix":
                case "Bmatrix":
                case "Vmatrix":
                    TableKind k = TableKind.MATRIX;
                    if (name == "pmatrix") k = TableKind.PMATRIX;
                    if (name == "bmatrix") k = TableKind.BMATRIX;
                    if (name == "vmatrix") k = TableKind.VMATRIX;
                    if (name == "Bmatrix") k = TableKind.BRACE_MATRIX;
                    if (name == "Vmatrix") k = TableKind.DOUBLE_VMATRIX;
                    insert_table (k, 2, 2);
                    return;
                case "cases":
                    insert_table (TableKind.CASES, 2, 2);
                    return;
                case "aligned":
                case "align":
                    insert_table (TableKind.ALIGN, 2, 2);
                    return;
                case "left":
                    insert_fenced ("(", ")");
                    return;
                case "boxed":
                    insert_node (new Enclose ("box"));
                    return;
                case "cancel":
                    insert_node (new Enclose ("updiagonalstrike"));
                    return;
                case "overset":
                    insert_node (new UnderOver (null, null, new Row ()), 0);
                    return;
                case "underset":
                    insert_node (new UnderOver (null, new Row (), null), 1);
                    return;
                case "prescript":
                    insert_prescripts ();
                    return;
                case "lim":
                    checkpoint ();
                    var lt = new Token.ident ("lim");
                    lt.forced_class = AtomClass.OP;
                    put (lt);
                    var ls = new Scripts (new Row (), null);
                    put (ls);
                    row = ls.sub;
                    index = 0;
                    notify_change ();
                    return;
                default:
                    break;
            }
            MathVariant v;
            if (Symbols.font_command (name, out v)) {
                if (has_selection) {
                    checkpoint ();
                    for (int i = sel_start; i < sel_end; i++) {
                        var t = row[i] as Token;
                        if (t != null) t.variant = v;
                    }
                    notify_change ();
                }
                return;
            }
            var acc = Symbols.accent (name);
            if (acc != null) {
                insert_accent (acc.mark, acc.stretchy, acc.under);
                return;
            }
            if (Symbols.is_function (name)) {
                checkpoint ();
                var f = new Token.ident (name);
                f.forced_class = AtomClass.OP;
                put (f);
                notify_change ();
                return;
            }
            var sym = Symbols.by_command (name);
            if (sym != null) {
                if (sym.largeop) {
                    insert_big_operator (sym.ch, false);
                    return;
                }
                checkpoint ();
                var t = new Token ((sym.category == "greek" || (sym.cls == AtomClass.ORD && sym.ch.get_char (0).isalpha ())) ? TokenKind.IDENT : TokenKind.OPERATOR, sym.ch);
                put (t);
                notify_change ();
                return;
            }
            checkpoint ();
            var err = new Token.ident ("\\" + name);
            err.error = true;
            put (err);
            notify_change ();
        }

        public void apply_variant (MathVariant v) {
            if (!has_selection) return;
            checkpoint ();
            for (int i = sel_start; i < sel_end; i++) set_variant (row[i], v);
            notify_change ();
        }

        private static void set_variant (Node n, MathVariant v) {
            var t = n as Token;
            if (t != null) {
                if (t.kind != TokenKind.OPERATOR) t.variant = v;
                return;
            }
            foreach (var s in n.slots ()) foreach (var c in s.items) set_variant (c, v);
        }

        public void wrap_style (string? color, int display) {
            var st = new Style ();
            st.color = color;
            st.display = display;
            if (display >= 0) st.script_level = 0;
            insert_node (st);
        }

        public Node? current_owner () {
            return row.parent;
        }
    }
}
