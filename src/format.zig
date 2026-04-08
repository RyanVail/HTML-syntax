const std = @import("std");
const assert = std.debug.assert;
const Writer = std.Io.Writer;
const token = @import("token.zig");
const Tokenizer = token.Tokenizer;

const State = enum {
    const Self = @This();

    start,
    fn_name,
    class_name,

    fstring,

    string_double,
    string_single,
};

fn writeLineNum(writer: *Writer, line: usize) Writer.Error!void {
    try writer.writeAll("<span class=cln>");
    try writer.printInt(line, 10, .lower, .{
        .width = 3,
        .fill = '0',
    });
    try writer.writeAll("</span> ");
}

fn formatInternal(data: []const u8, writer: *Writer) Writer.Error!void {
    var tokenizer: Tokenizer = .{ .buffer = data };

    var line: usize = 1;
    try writeLineNum(writer, line);

    var fstring_depth: usize = 0;

    state: switch (State.start) {
        .start => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .fstring => {
                    try writer.writeAll("<span class=cquote>f\"");
                    continue :state .fstring;
                },
                .comment => {
                    try writer.writeAll("<span class=ccom>");
                    try writer.writeAll(tokenizer.getSource(tok));
                    try writer.writeAll("</span>");
                    continue :state .start;
                },
                .quote_double => {
                    if (fstring_depth != 0) {
                        fstring_depth -= 1;

                        try writer.writeAll("\"</span>");
                        continue :state .start;
                    } else {
                        try writer.writeAll("<span class=cquote>\"");
                        continue :state .string_double;
                    }
                },
                .quote_single => {
                    try writer.writeAll("<span class=cquote>'");
                    continue :state .string_single;
                },
                .keyword => |key| {
                    const str = switch (key) {
                        inline else => |k| "<span class=c" ++
                            @tagName(k) ++
                            ">" ++ @tagName(k) ++ "</span>",
                    };

                    try writer.writeAll(str);

                    switch (key) {
                        .def => continue :state .fn_name,
                        .class => continue :state .class_name,
                        else => continue :state .start,
                    }
                },
                .identifier => {
                    const str = tokenizer.getSource(tok);

                    var all_upper = true;
                    for (str) |c| {
                        switch (c) {
                            'a'...'z' => {
                                all_upper = false;
                                break;
                            },
                            else => {},
                        }
                    }

                    if (!all_upper) {
                        try writer.writeAll(str);
                    } else {
                        try writer.writeAll("<span class=cconst>");
                        try writer.writeAll(str);
                        try writer.writeAll("</span>");
                    }

                    continue :state .start;
                },
                .number => {
                    try writer.writeAll("<span class=cnum>");
                    try writer.writeAll(tokenizer.getSource(tok));
                    try writer.writeAll("</span>");
                    continue :state .start;
                },
                .close_brace => {
                    const source = tokenizer.getSource(tok);
                    try writer.writeAll(source);

                    if (fstring_depth != 0) {
                        fstring_depth -= 1;

                        try writer.writeAll("<span class=cquote>");
                        continue :state .fstring;
                    } else {
                        continue :state .start;
                    }
                },
                .open_brace, .unknown_char => {
                    const source = tokenizer.getSource(tok);
                    assert(source.len == 1);

                    try writer.writeByte(source[0]);

                    if (source[0] == '\n') {
                        line += 1;
                        try writeLineNum(writer, line);
                    }

                    continue :state .start;
                },
            }
        },
        .fn_name => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .unknown_char => {
                    try writer.writeAll(tokenizer.getSource(tok));
                    continue :state .fn_name;
                },
                else => {
                    try writer.writeAll("<span class=cfn>");
                    try writer.writeAll(tokenizer.getSource(tok));
                    try writer.writeAll("</span>");
                    continue :state .start;
                },
            }
        },
        .class_name => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .unknown_char => {
                    try writer.writeAll(tokenizer.getSource(tok));
                    continue :state .class_name;
                },
                else => {
                    try writer.writeAll("<span class=cclass-name>");
                    try writer.writeAll(tokenizer.getSource(tok));
                    try writer.writeAll("</span>");
                    continue :state .start;
                },
            }
        },
        .fstring => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .open_brace => {
                    try writer.writeAll("</span>{");
                    fstring_depth += 1;
                    continue :state .start;
                },
                .quote_double => {
                    try writer.writeAll("\"</span>");
                    continue :state .start;
                },
                else => {
                    try writer.writeAll(tokenizer.getSource(tok));
                    continue :state .fstring;
                },
            }
        },
        .string_double => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .quote_double => {
                    try writer.writeAll("\"</span>");
                    continue :state .start;
                },
                else => {
                    try writer.writeAll(tokenizer.getSource(tok));
                    continue :state .string_double;
                },
            }
        },
        .string_single => {
            const tok = tokenizer.next() orelse return;
            switch (tok.tag) {
                .quote_single => {
                    try writer.writeAll("'</span>");
                    continue :state .start;
                },
                else => {
                    try writer.writeAll(tokenizer.getSource(tok));
                    continue :state .string_single;
                },
            }
        },
    }
}

const format_start = "<div class=cblock><pre style=margin:0>";
const format_end = "</pre></div>";

pub fn format(data: []const u8, writer: *Writer) Writer.Error!void {
    try writer.writeAll(format_start);
    try formatInternal(data, writer);
    try writer.writeAll(format_end);
}

const debug_allocator = std.testing.allocator;
const expectEqualSlices = std.testing.expectEqualSlices;

test "format assignment" {
    const expected = "<span class=cln>001</span> " ++
        "a: <span class=cint>int</span> " ++
        "= <span class=cnum>4</span>";

    const str = "a: int = 4\x00";

    var writer = Writer.Allocating.init(debug_allocator);
    defer writer.deinit();

    try formatInternal(str, &writer.writer);
    try expectEqualSlices(u8, expected, writer.written());
}
