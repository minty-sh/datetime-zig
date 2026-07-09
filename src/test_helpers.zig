const std = @import("std");

/// Formats `got` (an allocator-returning string), asserts it equals `want`, and frees it.
/// Collapses the repeated format -> defer free -> expectEqualStrings pattern in tests.
pub fn expectFormat(allocator: std.mem.Allocator, want: []const u8, got: anyerror![]u8) !void {
    const s = try got;
    defer allocator.free(s);
    try std.testing.expectEqualStrings(want, s);
}

/// Builds a `std.Io.Threaded` and returns both the Io handle and the owning instance
/// so the caller can `defer ti.threaded.deinit()`.
pub fn makeTestIo(a: std.mem.Allocator) struct { io: std.Io, threaded: std.Io.Threaded } {
    var threaded = std.Io.Threaded.init(a, .{});
    return .{ .io = threaded.io(), .threaded = threaded };
}
