const std = @import("std");

pub const ParseError = error{BadFormat};

pub inline fn expect(s: []const u8, idx: usize, ch: u8) bool {
    return idx < s.len and s[idx] == ch;
}

pub fn parseIntDigits(s: []const u8, idx_ptr: *usize, digits: usize) !i32 {
    const idx = idx_ptr.*;
    if (idx + digits > s.len) return ParseError.BadFormat;
    var v: i32 = 0;
    var i: usize = 0;
    while (i < digits) : (i += 1) {
        const ch = s[idx + i];
        if (!std.ascii.isDigit(ch)) return ParseError.BadFormat;
        v = v * 10 + (@as(i32, ch) - 48);
    }
    idx_ptr.* = idx + digits;
    return v;
}

pub fn charDigit(n: u8) u8 {
    return 48 + n;
}

pub fn write4digits(buf: []u8, idx_ptr: *usize, n: u32) void {
    const i = idx_ptr.*;
    buf[i + 0] = charDigit(@intCast((n / 1000) % 10));
    buf[i + 1] = charDigit(@intCast((n / 100) % 10));
    buf[i + 2] = charDigit(@intCast((n / 10) % 10));
    buf[i + 3] = charDigit(@intCast(n % 10));
    idx_ptr.* = i + 4;
}

pub fn write2digits(buf: []u8, idx_ptr: *usize, n: u8) void {
    const i = idx_ptr.*;
    buf[i + 0] = charDigit(@intCast((n / 10) % 10));
    buf[i + 1] = charDigit(@intCast(n % 10));
    idx_ptr.* = i + 2;
}

test "expect" {
    const testing = std.testing;
    const slice = "hello";

    try testing.expect(expect(slice, 1, 'e'));
    try testing.expect(!expect(slice, 1, 'H'));
    try testing.expect(!expect(slice, 5, 'o')); // out of bounds
}

test "parseIntDigits" {
    const testing = std.testing;
    const slice = "2023-10-27";
    var idx: usize = 0;

    // Test successful parse
    const year = try parseIntDigits(slice, &idx, 4);
    try testing.expectEqual(@as(i32, 2023), year);
    try testing.expectEqual(@as(usize, 4), idx);

    // Test parse from offset
    idx = 5;
    const month = try parseIntDigits(slice, &idx, 2);
    try testing.expectEqual(@as(i32, 10), month);
    try testing.expectEqual(@as(usize, 7), idx);

    // Test error on non-digit
    idx = 4;
    const non_digit = parseIntDigits(slice, &idx, 1);
    try testing.expectError(ParseError.BadFormat, non_digit);

    // Test error on out of bounds
    idx = 0;
    const out_of_bounds = parseIntDigits(slice, &idx, 20);
    try testing.expectError(ParseError.BadFormat, out_of_bounds);
}

test "charDigit" {
    const testing = std.testing;
    try testing.expectEqual('0', charDigit(0));
    try testing.expectEqual('5', charDigit(5));
    try testing.expectEqual('9', charDigit(9));
}

test "write4digits" {
    const testing = std.testing;
    var buf: [10]u8 = undefined;
    var idx: usize = 0;

    // Write at start
    write4digits(&buf, &idx, 2023);
    try testing.expectEqualStrings("2023", buf[0..4]);
    try testing.expectEqual(@as(usize, 4), idx);

    // Write with leading zero
    idx = 0;
    write4digits(&buf, &idx, 123);
    try testing.expectEqualStrings("0123", buf[0..4]);
    try testing.expectEqual(@as(usize, 4), idx);

    // Write at offset
    idx = 5;
    write4digits(&buf, &idx, 9876);
    try testing.expectEqualStrings("9876", buf[5..9]);
    try testing.expectEqual(@as(usize, 9), idx);
}

test "write2digits" {
    const testing = std.testing;
    var buf: [10]u8 = undefined;
    var idx: usize = 0;

    // Write at start
    write2digits(&buf, &idx, 27);
    try testing.expectEqualStrings("27", buf[0..2]);
    try testing.expectEqual(@as(usize, 2), idx);

    // Write with leading zero
    idx = 0;
    write2digits(&buf, &idx, 7);
    try testing.expectEqualStrings("07", buf[0..2]);
    try testing.expectEqual(@as(usize, 2), idx);

    // Write at offset
    idx = 5;
    write2digits(&buf, &idx, 13);
    try testing.expectEqualStrings("13", buf[5..7]);
    try testing.expectEqual(@as(usize, 7), idx);
}
