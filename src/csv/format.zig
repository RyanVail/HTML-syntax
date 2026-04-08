const std = @import("std");
const Writer = std.Io.Writer;
const shared = @import("../shared.zig");

pub fn format(data: []const u8, writer: *Writer) Writer.Error!void {
    var line: usize = 1;
    try shared.writeLineNum(writer, 0);

    var col: usize = 0;

    for (data) |c| {
        switch (c) {
            ',' => {
                col += 1;
                try writer.writeAll("</span>,<span class=csv_");
                try writer.printInt(col, 10, .lower, .{});
                try writer.writeByte('>');
            },
            '\n' => {
                try writer.writeAll("</span>\n");
                col = 0;
                line += 1;
                try shared.writeLineNum(writer, line);
                try writer.writeAll("<span class=csv_0>");
            },
            else => try writer.writeByte(c),
        }
    }
}
