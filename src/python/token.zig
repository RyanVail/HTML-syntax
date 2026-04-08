const std = @import("std");

pub const Keyword = enum {
    const Self = @This();

    import,
    from,
    as,
    def,
    @"for",
    in,
    class,
    self,
    len,
    print,
    @"return",
    @"if",
    @"else",
    __name__,

    bool,
    int,
    str,
    list,
    range,
    chr,

    True,
    False,
    None,

    pub fn fromStr(str: []const u8) ?Self {
        return std.meta.stringToEnum(Self, str);
    }
};

pub const Token = struct {
    const Self = @This();

    pub const Tag = union(enum) {
        quote_double,
        quote_single,

        fstring,

        open_brace,
        close_brace,

        comment,

        keyword: Keyword,
        number,
        identifier,

        unknown_char,
    };

    pub const Loc = struct {
        start: usize,
        end: usize,
    };

    tag: Tag,
    loc: Loc,

    pub fn getSource(self: Self, buffer: []const u8) []const u8 {
        return buffer[self.loc.start..self.loc.end];
    }
};

pub const Tokenizer = struct {
    const Self = @This();

    const State = enum {
        start,
        maybe_f_string,
        comment,
        identifier,

        num,

        // Could be hex, octal, or binary.
        num_zero_prefix,

        num_hex,
        num_octal,
        num_binary,

        // Period found in a number.
        num_float,

        // Checks for '+' or '-' after an exponent.
        num_exp_start,

        // 'e' or 'E' found in a number.
        num_exp,
    };

    buffer: []const u8,
    index: usize = 0,

    pub fn getSource(self: Self, token: Token) []const u8 {
        return token.getSource(self.buffer);
    }

    pub fn next(self: *Self) ?Token {
        var result: Token = .{
            .tag = undefined,
            .loc = .{
                .start = self.index,
                .end = undefined,
            },
        };

        state: switch (State.start) {
            .start => switch (self.buffer[self.index]) {
                0 => return null,
                'f' => {
                    self.index += 1;
                    continue :state .maybe_f_string;
                },
                '"' => {
                    self.index += 1;
                    result.tag = .quote_double;
                },
                '\'' => {
                    self.index += 1;
                    result.tag = .quote_single;
                },
                '{' => {
                    self.index += 1;
                    result.tag = .open_brace;
                },
                '}' => {
                    self.index += 1;
                    result.tag = .close_brace;
                },
                '#' => {
                    result.tag = .comment;
                    continue :state .comment;
                },
                'a'...('f' - 1), ('f' + 1)...'z', 'A'...'Z', '_' => {
                    continue :state .identifier;
                },
                '0' => {
                    self.index += 1;
                    continue :state .num_zero_prefix;
                },
                '1'...'9' => {
                    continue :state .num;
                },
                else => {
                    self.index += 1;
                    result.tag = .unknown_char;
                },
            },
            .comment => switch (self.buffer[self.index]) {
                '\n', 0 => result.tag = .comment,
                else => {
                    self.index += 1;
                    continue :state .comment;
                },
            },
            .maybe_f_string => switch (self.buffer[self.index]) {
                '"' => {
                    self.index += 1;
                    result.tag = .fstring;
                },
                else => {
                    self.index += 1;
                    continue :state .identifier;
                },
            },
            .identifier => switch (self.buffer[self.index]) {
                'a'...'z', 'A'...'Z', '_', '0'...'9' => {
                    self.index += 1;
                    continue :state .identifier;
                },
                else => {
                    result.tag = .identifier;
                    const str = self.buffer[result.loc.start..self.index];
                    if (Keyword.fromStr(str)) |keyword| {
                        result.tag = .{ .keyword = keyword };
                    }
                },
            },
            .num => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    continue :state .num;
                },
                'e', 'E' => {
                    self.index += 1;
                    continue :state .num_exp_start;
                },
                '.' => {
                    self.index += 1;
                    continue :state .num_float;
                },
                else => result.tag = .number,
            },
            .num_float => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    continue :state .num_float;
                },
                'e', 'E' => {
                    self.index += 1;
                    continue :state .num_exp_start;
                },
                else => result.tag = .number,
            },
            .num_exp_start => switch (self.buffer[self.index]) {
                '+', '-' => {
                    self.index += 1;
                    continue :state .num_exp;
                },
                else => continue :state .num_exp,
            },
            .num_exp => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    continue :state .num_exp;
                },
                else => result.tag = .number,
            },
            .num_zero_prefix => switch (self.buffer[self.index]) {
                'x', 'X' => {
                    self.index += 1;
                    continue :state .num_hex;
                },
                'o', 'O' => {
                    self.index += 1;
                    continue :state .num_octal;
                },
                'b', 'B' => {
                    self.index += 1;
                    continue :state .num_binary;
                },
                else => {
                    continue :state .num;
                },
            },
            .num_hex => switch (self.buffer[self.index]) {
                '0'...'9', 'a'...'f', 'A'...'F' => {
                    self.index += 1;
                    continue :state .num_hex;
                },
                else => result.tag = .number,
            },
            .num_octal => switch (self.buffer[self.index]) {
                '0'...'7' => {
                    self.index += 1;
                    continue :state .num_octal;
                },
                else => result.tag = .number,
            },
            .num_binary => switch (self.buffer[self.index]) {
                '0'...'1' => {
                    self.index += 1;
                    continue :state .num_binary;
                },
                else => result.tag = .number,
            },
        }

        result.loc.end = self.index;
        return result;
    }
};

const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

test "tokenize assignment" {
    const str = "a:int=4\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const a = tokenizer.next().?;
    try expectEqual(.identifier, a.tag);
    try expectEqualSlices(u8, "a", a.getSource(str));

    const colon = tokenizer.next().?;
    try expectEqual(.unknown_char, colon.tag);
    try expectEqualSlices(u8, ":", colon.getSource(str));

    const int = tokenizer.next().?;
    try expectEqual(Token.Tag{ .keyword = Keyword.int }, int.tag);
    try expectEqualSlices(u8, "int", int.getSource(str));

    const equal = tokenizer.next().?;
    try expectEqual(.unknown_char, equal.tag);
    try expectEqualSlices(u8, "=", equal.getSource(str));

    const num = tokenizer.next().?;
    try expectEqual(.number, num.tag);
    try expectEqualSlices(u8, "4", num.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize fstring" {
    const str = "f\"a: {}\"\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.fstring, start.tag);
    try expectEqualSlices(u8, "f\"", start.getSource(str));

    const a = tokenizer.next().?;
    try expectEqual(.identifier, a.tag);
    try expectEqualSlices(u8, "a", a.getSource(str));

    const colon = tokenizer.next().?;
    try expectEqual(.unknown_char, colon.tag);
    try expectEqualSlices(u8, ":", colon.getSource(str));

    const space = tokenizer.next().?;
    try expectEqual(.unknown_char, space.tag);
    try expectEqualSlices(u8, " ", space.getSource(str));

    const open_brace = tokenizer.next().?;
    try expectEqual(.open_brace, open_brace.tag);
    try expectEqualSlices(u8, "{", open_brace.getSource(str));

    const close_brace = tokenizer.next().?;
    try expectEqual(.close_brace, close_brace.tag);
    try expectEqualSlices(u8, "}", close_brace.getSource(str));

    const quote = tokenizer.next().?;
    try expectEqual(.quote_double, quote.tag);
    try expectEqualSlices(u8, "\"", quote.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize hex" {
    const hex = "0xAbCdEf0123456789";
    const str = hex ++ "x" ++ "\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.number, start.tag);
    try expectEqualSlices(u8, hex, start.getSource(str));

    const x = tokenizer.next().?;
    try expectEqual(.identifier, x.tag);
    try expectEqualSlices(u8, "x", x.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize octal" {
    const octal = "0O0124567";
    const str = octal ++ "8" ++ "\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.number, start.tag);
    try expectEqualSlices(u8, octal, start.getSource(str));

    const x = tokenizer.next().?;
    try expectEqual(.number, x.tag);
    try expectEqualSlices(u8, "8", x.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize binary" {
    const binary = "0b0001000";
    const str = binary ++ "\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.number, start.tag);
    try expectEqualSlices(u8, binary, start.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize float" {
    const float = "100.05e+05";
    const str = float ++ "\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.number, start.tag);
    try expectEqualSlices(u8, float, start.getSource(str));

    try expectEqual(null, tokenizer.next());
}

test "tokenize exp" {
    const float = "4e-0";
    const str = float ++ "\x00";
    var tokenizer = Tokenizer{ .buffer = str };

    const start = tokenizer.next().?;
    try expectEqual(.number, start.tag);
    try expectEqualSlices(u8, float, start.getSource(str));

    try expectEqual(null, tokenizer.next());
}
