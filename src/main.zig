const std = @import("std");
const smp_allocator = std.heap.smp_allocator;
const format = @import("format.zig");

test {
    _ = format;
}

const help_message = "Usage: html-coder [SOURCE FILE] [OUTPUT FILE]\n";

const FormatError = error{
    NoInputFile,
    NoOutputFile,
};

pub fn formatFromArgs() !void {
    var args = std.process.args();
    _ = args.skip();

    const input_path = args.next() orelse {
        return error.NoInputFile;
    };

    const output_path = args.next() orelse {
        return error.NoOutputFile;
    };

    var output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var data = try std.fs.cwd().readFileAlloc(
        smp_allocator,
        input_path,
        std.math.maxInt(usize),
    );

    // Adding an EOF char for the formater.
    data = try smp_allocator.realloc(data, data.len + 1);
    data[data.len - 1] = 0;

    var writer_buf: [128]u8 = undefined;
    var writer = output_file.writer(&writer_buf);

    try format.format(data, &writer.interface);
    try writer.end();
}

pub fn main() !void {
    formatFromArgs() catch |e| switch (e) {
        error.NoInputFile,
        error.NoOutputFile,
        => try std.fs.File.stdout().writeAll(help_message),
        else => return e,
    };
}
