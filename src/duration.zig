const std = @import("std");
const test_helpers = @import("test_helpers.zig");

/// Represents a signed duration of time with nanosecond precision.
/// Internally stored as a count of nanoseconds (`i128`), which allows lossless
/// conversion to/from any other unit. When a `Duration` is added to a `DateTime`
/// (which is second-resolution), the value is truncated to whole seconds.
pub const Duration = struct {
    nanoseconds: i128,

    /// Comptime unit constants.
    pub const nanosecond: Duration = .{ .nanoseconds = 1 };
    pub const microsecond: Duration = .{ .nanoseconds = std.time.ns_per_us };
    pub const millisecond: Duration = .{ .nanoseconds = std.time.ns_per_ms };
    pub const second: Duration = .{ .nanoseconds = std.time.ns_per_s };
    pub const minute: Duration = .{ .nanoseconds = std.time.ns_per_min };
    pub const hour: Duration = .{ .nanoseconds = std.time.ns_per_hour };
    pub const day: Duration = .{ .nanoseconds = std.time.ns_per_day };
    pub const week: Duration = .{ .nanoseconds = std.time.ns_per_week };

    /// Creates a Duration from a number of nanoseconds.
    pub fn fromNanoseconds(ns: i128) Duration {
        return .{ .nanoseconds = ns };
    }

    /// Creates a Duration from a number of microseconds.
    pub fn fromMicroseconds(us: i128) Duration {
        return .{ .nanoseconds = us * std.time.ns_per_us };
    }

    /// Creates a Duration from a number of milliseconds.
    pub fn fromMilliseconds(ms: i128) Duration {
        return .{ .nanoseconds = ms * std.time.ns_per_ms };
    }

    /// Creates a Duration from a number of seconds.
    pub fn fromSeconds(s: i64) Duration {
        return .{ .nanoseconds = @as(i128, s) * std.time.ns_per_s };
    }

    /// Creates a Duration from a number of minutes.
    pub fn fromMinutes(m: i64) Duration {
        return .{ .nanoseconds = @as(i128, m) * std.time.ns_per_min };
    }

    /// Creates a Duration from a number of hours.
    pub fn fromHours(h: i64) Duration {
        return .{ .nanoseconds = @as(i128, h) * std.time.ns_per_hour };
    }

    /// Creates a Duration from a number of days.
    pub fn fromDays(d: i64) Duration {
        return .{ .nanoseconds = @as(i128, d) * std.time.ns_per_day };
    }

    /// Creates a Duration from a number of weeks.
    pub fn fromWeeks(w: i64) Duration {
        return .{ .nanoseconds = @as(i128, w) * std.time.ns_per_week };
    }

    /// Returns the sum of two durations.
    pub fn add(self: Duration, other: Duration) Duration {
        return .{ .nanoseconds = self.nanoseconds + other.nanoseconds };
    }

    /// Returns the difference of two durations (self - other).
    pub fn sub(self: Duration, other: Duration) Duration {
        return .{ .nanoseconds = self.nanoseconds - other.nanoseconds };
    }

    /// Returns this duration scaled by `factor`.
    pub fn mul(self: Duration, factor: i128) Duration {
        return .{ .nanoseconds = self.nanoseconds * factor };
    }

    /// Returns the duration with the opposite sign.
    pub fn negate(self: Duration) Duration {
        return .{ .nanoseconds = -self.nanoseconds };
    }

    /// Returns the absolute value of this duration.
    pub fn abs(self: Duration) Duration {
        return .{ .nanoseconds = if (self.nanoseconds < 0) -self.nanoseconds else self.nanoseconds };
    }

    /// Returns true if the two durations are exactly equal.
    pub fn eql(self: Duration, other: Duration) bool {
        return self.nanoseconds == other.nanoseconds;
    }

    /// Returns the relative ordering of two durations.
    pub fn order(self: Duration, other: Duration) std.math.Order {
        return std.math.order(self.nanoseconds, other.nanoseconds);
    }

    /// Returns true if self < other.
    pub fn lessThan(self: Duration, other: Duration) bool {
        return self.nanoseconds < other.nanoseconds;
    }

    /// Returns true if self <= other.
    pub fn lessThanEq(self: Duration, other: Duration) bool {
        return self.nanoseconds <= other.nanoseconds;
    }

    /// Returns true if self > other.
    pub fn greaterThan(self: Duration, other: Duration) bool {
        return self.nanoseconds > other.nanoseconds;
    }

    /// Returns true if self >= other.
    pub fn greaterThanEq(self: Duration, other: Duration) bool {
        return self.nanoseconds >= other.nanoseconds;
    }

    /// Returns the duration in nanoseconds.
    pub fn asNanoseconds(self: Duration) i128 {
        return self.nanoseconds;
    }

    /// Returns the duration in microseconds (truncated toward zero).
    pub fn asMicroseconds(self: Duration) i128 {
        return @divTrunc(self.nanoseconds, std.time.ns_per_us);
    }

    /// Returns the duration in milliseconds (truncated toward zero).
    pub fn asMilliseconds(self: Duration) i128 {
        return @divTrunc(self.nanoseconds, std.time.ns_per_ms);
    }

    /// Returns the duration in whole seconds (truncated toward zero).
    pub fn asSeconds(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_s));
    }

    /// Returns the duration in whole minutes (truncated toward zero).
    pub fn asMinutes(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_min));
    }

    /// Returns the duration in whole hours (truncated toward zero).
    pub fn asHours(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_hour));
    }

    /// Returns the duration in whole days (truncated toward zero).
    pub fn asDays(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_day));
    }

    /// Returns the duration in whole weeks (truncated toward zero).
    pub fn asWeeks(self: Duration) i64 {
        return @intCast(@divTrunc(self.nanoseconds, std.time.ns_per_week));
    }

    /// Formats the duration as a compact, human-readable string such as
    /// `"1h30m5s"`, `"5m"`, `"-2s"`, or `"0s"`. Sub-second precision is omitted.
    /// The returned slice is caller-owned and must be freed with `allocator`.
    pub fn format(self: Duration, allocator: std.mem.Allocator) ![]u8 {
        const negative = self.nanoseconds < 0;
        const abs_ns: u128 = @intCast(if (negative) -self.nanoseconds else self.nanoseconds);
        const total_seconds = abs_ns / std.time.ns_per_s;

        const hours = total_seconds / 3600;
        const minutes = (total_seconds % 3600) / 60;
        const seconds = total_seconds % 60;

        var aw: std.Io.Writer.Allocating = .init(allocator);
        errdefer aw.deinit();
        const writer = &aw.writer;

        if (negative) try writer.writeByte('-');
        if (hours > 0) try writer.print("{d}h", .{hours});
        if (minutes > 0) try writer.print("{d}m", .{minutes});
        if (seconds > 0 or (hours == 0 and minutes == 0)) try writer.print("{d}s", .{seconds});

        return aw.toOwnedSlice();
    }

    test "Duration constructors" {
        const testing = std.testing;

        try testing.expectEqual(@as(i128, 1_000_000_000), Duration.fromSeconds(1).nanoseconds);
        try testing.expectEqual(@as(i128, 60_000_000_000), Duration.fromMinutes(1).nanoseconds);
        try testing.expectEqual(@as(i128, 3_600_000_000_000), Duration.fromHours(1).nanoseconds);
        try testing.expectEqual(@as(i128, 86_400_000_000_000), Duration.fromDays(1).nanoseconds);
        try testing.expectEqual(@as(i128, 604_800_000_000_000), Duration.fromWeeks(1).nanoseconds);
        try testing.expectEqual(@as(i128, -1_000_000_000), Duration.fromSeconds(-1).nanoseconds);
    }

    test "Duration arithmetic" {
        const testing = std.testing;

        const a = Duration.fromSeconds(10);
        const b = Duration.fromSeconds(3);
        try testing.expectEqual(Duration.fromSeconds(13), a.add(b));
        try testing.expectEqual(Duration.fromSeconds(7), a.sub(b));
        try testing.expectEqual(Duration.fromSeconds(30), a.mul(3));
        try testing.expectEqual(Duration.fromSeconds(-10), a.negate());
        try testing.expectEqual(Duration.fromSeconds(10), a.negate().abs());
    }

    test "Duration ordering" {
        const testing = std.testing;

        const a = Duration.fromSeconds(10);
        const b = Duration.fromSeconds(20);
        try testing.expect(a.eql(a));
        try testing.expect(a.lessThan(b));
        try testing.expect(b.greaterThan(a));
        try testing.expectEqual(std.math.Order.lt, a.order(b));
        try testing.expect(a.lessThanEq(a));
        try testing.expect(b.greaterThanEq(b));
    }

    test "Duration accessors" {
        const testing = std.testing;

        const d = Duration.fromHours(2).add(Duration.fromMinutes(30)).add(Duration.fromSeconds(5));
        try testing.expectEqual(@as(i64, 2), d.asHours());
        try testing.expectEqual(@as(i64, 150), d.asMinutes());
        try testing.expectEqual(@as(i64, 9005), d.asSeconds());
    }

    test "Duration format" {
        const testing = std.testing;
        const allocator = testing.allocator;

        const cases = [_]struct { d: Duration, want: []const u8 }{
            .{ .d = Duration.fromSeconds(0), .want = "0s" },
            .{ .d = Duration.fromSeconds(5), .want = "5s" },
            .{ .d = Duration.fromSeconds(-2), .want = "-2s" },
            .{ .d = Duration.fromMinutes(5), .want = "5m" },
            .{ .d = Duration.fromHours(1).add(Duration.fromMinutes(30)).add(Duration.fromSeconds(5)), .want = "1h30m5s" },
        };

        for (cases) |c| {
            try test_helpers.expectFormat(allocator, c.want, c.d.format(allocator));
        }
    }
};
