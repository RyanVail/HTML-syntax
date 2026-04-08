const std = @import("std");
const Writer = std.Io.Writer;

pub fn writeLineNum(writer: *Writer, line: usize) Writer.Error!void {
    try writer.writeAll("<span class=cln>");
    try writer.printInt(line, 10, .lower, .{
        .width = 3,
        .fill = '0',
    });
    try writer.writeAll("</span> ");
}
