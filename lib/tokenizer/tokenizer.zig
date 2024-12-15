const std = @import("std");
const ArrayList = std.ArrayList;

pub const TokError = error{
    IdxError,
};

pub const TokenType: type = usize;
pub const TokenMap: type = std.StaticStringMap(TokenType);

pub const Token: type = struct {
    tokenType: ?TokenType,
    value: [] const u8,
};


fn maxKeyLength(comptime Map: TokenMap) comptime_int {
    comptime {
        var max_len: usize = 0;
        for (Map.keys()) |kv| {
            max_len = @max(max_len, kv.len);
        }
        return max_len;
    }
}

pub fn Tokenizer(comptime tokenMap: TokenMap, comptime delims: [] const u8) type {
    const maxTokLength: comptime_int = maxKeyLength(tokenMap);

    return struct {
        const Self = @This();

        in_stream: [] const u8,
        cur_idx: usize,

        fn is_whitespace(self: *Self) TokError!bool {
            const streamSize: usize = self.in_stream.len;
            if (self.cur_idx >= streamSize) {
                return TokError.IdxError;
            }

            return std.mem.containsAtLeast(u8,
                                        delims,
                                        1,
                                        self.in_stream[self.cur_idx..(self.cur_idx + 1)]);
        }


        fn skip_whitespace(self: *Self) TokError!void {
            const streamSize: usize = self.in_stream.len;
            if (self.cur_idx >= streamSize) {
                return TokError.IdxError;
            }

            while (try self.is_whitespace())  : (self.cur_idx += 1) {}

        }

        fn is_token(str: *const [] const u8) bool {
            return tokenMap.has(str.*);
        }

        fn try_find_token(self: *Self) TokError!?usize {
            const streamSize: usize = self.in_stream.len;
            if (self.cur_idx >= streamSize) {
                return TokError.IdxError;
            }

            var tokLength: usize = @min(@as(usize, maxTokLength), streamSize - self.cur_idx);

            const begIdx = self.cur_idx;
            while (tokLength > 0) : (tokLength -= 1) {
                const isTok = is_token(&self.in_stream[begIdx..(begIdx+tokLength)]);
                if (isTok) {
                    return tokLength;
                }
            }
            return null;
        }

        pub fn get_next_token(self: *Self) TokError!Token {
            try self.skip_whitespace();

            const streamSize: usize = self.in_stream.len;
            if (self.cur_idx >= streamSize) {
                return TokError.IdxError;
            }

            try self.skip_whitespace();
            const tokEndIdx = try self.try_find_token();
            if (tokEndIdx != null) {
                // Found one of the tokens in tokenMap - return default token and it's type
                const tokStr = self.in_stream[self.cur_idx..(self.cur_idx + tokEndIdx.?)];
                self.cur_idx += tokEndIdx.?;
                return Token {
                    .tokenType = tokenMap.get(tokStr) orelse null,
                    .value = tokStr,
                };
            }

            const begIdx = self.cur_idx;

            var isWhitespace: bool = false;
            while (!isWhitespace) : (self.cur_idx += 1) {
                // We reached the end of string - break
                isWhitespace = self.is_whitespace() catch {
                    break;
                };
            }

            const curStr = self.in_stream[begIdx..self.cur_idx];
            return Token {
                .tokenType = tokenMap.get(curStr) orelse null,
                .value = curStr[0..],
            };
        }
    };
}
