const std = @import("std");

pub const BadFormatError = error{};

pub inline fn expect(s: []const u8, idx: usize, ch: u8) bool {
    return idx < s.len and s[idx] == ch;
}

pub fn parseIntDigits(s: []const u8, idx_ptr: *usize, digits: usize) !i32 {
    const idx = idx_ptr.*;
    if (idx + digits > s.len) return BadFormatError;
    var v: i32 = 0;
    var i: usize = 0;
    while (i < digits) : (i += 1) {
        const ch = s[idx + i];
        if (!std.ascii.isDigit(ch)) return BadFormatError;
        v = v * 10 + (@as(i32, ch) - 48);
    }
    idx_ptr.* = idx + digits;
    return v;
}

pub fn charDigit(n: i32) u8 {
    return @as(u8, 48 + n);
}

pub fn write4digits(buf: []u8, idx_ptr: *usize, n: u32) void {
    const i = idx_ptr.*;
    buf[i + 0] = charDigit(@as(i32, (n / 1000) % 10));
    buf[i + 1] = charDigit(@as(i32, (n / 100) % 10));
    buf[i + 2] = charDigit(@as(i32, (n / 10) % 10));
    buf[i + 3] = charDigit(@as(i32, n % 10));
    idx_ptr.* = i + 4;
}

pub fn write2digits(buf: []u8, idx_ptr: *usize, n: u8) void {
    const i = idx_ptr.*;
    buf[i + 0] = charDigit(@as(i32, (n / 10) % 10));
    buf[i + 1] = charDigit(@as(i32, n % 10));
    idx_ptr.* = i + 2;
}
