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
        number,
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
                '0'...'9' => {
                    continue :state .number;
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
            .number => switch (self.buffer[self.index]) {
                '0'...'9' => {
                    self.index += 1;
                    continue :state .number;
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
