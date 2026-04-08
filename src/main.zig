const std = @import("std");
const smp_allocator = std.heap.smp_allocator;
const python = @import("python.zig");
const csv = @import("csv.zig");

const help_message =
    \\Usage: html-coder [OPTIONS...] [SOURCE FILE] [OUTPUT FILE]
    \\
    \\ Options:
    \\  -t [python, csv]       specify the type of the source file
    \\
;

const FormatError = error{
    NoInputFile,
    NoOutputFile,
};

const format_start = "<div class=cblock><pre style=margin:0>";
const format_end = "</pre></div>";

pub const FileType = enum {
    const Self = @This();

    python,
    csv,

    pub fn fromStr(str: []const u8) ?Self {
        return std.meta.stringToEnum(Self, str);
    }

    pub fn getExtension(self: Self) []const u8 {
        return switch (self) {
            .python => "py",
            .csv => "csv",
        };
    }

    const map = b: {
        const Map = std.StaticStringMap(Self);
        const KV = struct { []const u8, FileType };

        const fields = @typeInfo(Self).@"enum".fields;
        var entries: [fields.len]KV = undefined;

        for (fields, 0..) |field, i| {
            const value: Self = @enumFromInt(field.value);
            entries[i] = .{ getExtension(value), value };
        }

        break :b Map.initComptime(entries);
    };

    pub fn fromExtension(extension: []const u8) ?Self {
        return map.get(extension);
    }
};

pub const Options = struct {
    file_type: ?FileType = null,
};

pub const ArgsParse = struct {
    const Self = @This();

    iter: std.process.ArgIterator,
    peeked: ?[]const u8 = null,

    pub fn init() Self {
        return .{ .iter = std.process.args() };
    }

    pub fn skip(self: *Self) void {
        if (self.peeked != null) {
            self.peeked = null;
        } else {
            _ = self.iter.skip();
        }
    }

    pub fn peek(self: *Self) ?[]const u8 {
        if (self.peeked != null) {
            return self.peeked;
        } else {
            self.peeked = self.iter.next();
            return self.peeked;
        }
    }

    pub fn next(self: *Self) ?[]const u8 {
        if (self.peeked != null) {
            const p = self.peeked;
            self.peeked = null;
            return p;
        } else {
            return self.iter.next();
        }
    }
};

pub const OptionsError = error{
    InvalidOption,
    ExpectedType,
    InvalidType,
};

pub fn parseOptions(args: *ArgsParse) OptionsError!Options {
    var options: Options = .{};

    while (true) {
        const p = args.peek() orelse break;

        // Not an option.
        if (p.len != 2 or p[0] != '-') {
            break;
        }

        // Consuming the option arg.
        args.skip();

        switch (p[1]) {
            't' => {
                const type_name = args.next() orelse {
                    return error.ExpectedType;
                };

                if (FileType.fromStr(type_name)) |file_type| {
                    options.file_type = file_type;
                } else {
                    return error.InvalidType;
                }
            },
            else => return error.InvalidOption,
        }
    }

    return options;
}

pub fn formatFromArgs() !void {
    var args = ArgsParse.init();
    _ = args.skip();

    // Parsing the command line options.
    var options = try parseOptions(&args);

    const input_path = args.next() orelse {
        return error.NoInputFile;
    };

    // Try to determine the file type from the input file's extension.
    if (options.file_type == null) {
        const ext = std.fs.path.extension(input_path);
        if (ext.len > 1) {
            options.file_type = FileType.fromExtension(ext[1..]) orelse {
                return error.UnknownFileType;
            };
        }
    }

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
    var file_writer = output_file.writer(&writer_buf);
    const writer = &file_writer.interface;

    try writer.writeAll(format_start);

    switch (options.file_type.?) {
        .python => try python.format(data, writer),
        .csv => try csv.format(data, writer),
    }

    try writer.writeAll(format_end);
    try writer.flush();
}

pub fn main() !void {
    formatFromArgs() catch |e| switch (e) {
        error.NoInputFile,
        error.NoOutputFile,
        => try std.fs.File.stdout().writeAll(help_message),
        else => return e,
    };
}
