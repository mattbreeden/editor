package main

import "core:os"

import tb "shared:termbox"


BufferMode :: enum u8 {
    Normal,
    Insert,
}

Cursor :: struct {
    x: int,
    y: int,
    // Used when x has to be lowered while moving up and down.
    // Example: line y=1 has 10 chars and x is 8. Line y=2 has 3 chars.
    // When moving from y=1 to y=2, the x will be set to 3.
    // When moving back to y=1 this is used to set x back to 8.
    prev_x: int,
}

Buffer :: struct {
    width: int,
    height: int,
    mode: BufferMode,
    text: ^Text,
    cursor: Cursor,
}

buffer_init :: proc(buf: ^Buffer, fd: os.Handle) -> bool {
    buf.mode = BufferMode.Normal;
    buf.cursor.x = 1;
    buf.cursor.y = 1;
    buf.cursor.prev_x = 1;
    buf.text = new(Text);
    ok := text_init(buf.text, fd);
    if !ok {
        unimplemented();
    }
    return true;
}


buffer_handle_event_insert :: proc(buffer: ^Buffer, event: tb.Event) {
    switch true {
    case event.key == tb.Key.ESC:
        buffer.mode = BufferMode.Normal;
    }
}


buffer_handle_event_normal :: proc(buffer: ^Buffer, event: tb.Event) {
    switch true {
    case event.ch == 'i':
        buffer.mode = BufferMode.Insert;
    case event.ch == 'h':
        buffer_move_cursor(buffer, Direction.Left);
    case event.ch == 'j':
        buffer_move_cursor(buffer, Direction.Down);
    case event.ch == 'k':
        buffer_move_cursor(buffer, Direction.Up);
    case event.ch == 'l':
        buffer_move_cursor(buffer, Direction.Right);
    }
}


buffer_handle_event :: proc(buffer: ^Buffer, event: tb.Event) {
    switch buffer.mode {
    case BufferMode.Normal:
        buffer_handle_event_normal(buffer, event);
    case BufferMode.Insert:
        buffer_handle_event_insert(buffer, event);
    }
}


Direction :: enum u8 {
    Up,
    Down,
    Left,
    Right,
}


buffer_move_cursor :: proc(using buffer: ^Buffer, direction: Direction) {
    using Direction;

    switch direction {
    case Direction.Up:
        cursor.y = max(1, cursor.y - 1);

        line_len := line_len(text, cursor.y);
        max_x := line_len == 0 ? 1 : line_len;
        cursor.x = min(max_x, cursor.prev_x);

    case Direction.Down:
        cursor.y = min(buffer.height - 1, len(buffer.text.lines), cursor.y + 1);

        line_len := line_len(text, cursor.y);
        max_x := line_len == 0 ? 1 : line_len;
        cursor.x = min(max_x, cursor.prev_x);

    case Direction.Left:
        cursor.x = max(1, cursor.x - 1);
        cursor.prev_x = cursor.x;

    case Direction.Right:
        line_len := line_len(text, cursor.y);
        if line_len == 0 {
            cursor.x = 1;
        } else {
            cursor.x = min(line_len, cursor.x + 1);
        }
        cursor.prev_x = cursor.x;
    }
}

render_buffer :: proc(buffer: ^Buffer) {
    iterator := TextIterator{};
    text_iterator_init(&iterator, buffer.text);

    line := 1;
    col := 1;
    char: u8;
    more_text: bool;
    for {
        char, more_text = text_iterate_next(&iterator);
        if line > buffer.height do break;
        if col > buffer.width {
            // TODO: skip to next line
        }

        if char == '\n' {
            line += 1;
            col = 1;
            continue;
        }

        // FIXME: handle escape/non-visible characters
        tb.change_cell(i32(col - 1), i32(line - 1), u32(char), tb.Color.DEFAULT, tb.Color.DEFAULT);

        if !more_text do break;

        col += 1;
    }

    tb.set_cursor(cast(i32)buffer.cursor.x - 1, cast(i32)buffer.cursor.y - 1);
    tb.present();
}
