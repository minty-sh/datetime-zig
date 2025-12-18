/// Represents a duration in seconds.
pub const Duration = struct {
    seconds: i64,

    /// Creates a Duration instance from a given number of seconds.
    pub fn Seconds(s: i64) Duration {
        return .{ .seconds = s };
    }
};

test "Duration" {
    const std = @import("std");
    const testing = std.testing;

    // Test with positive seconds
    var duration = Duration.Seconds(10);
    try testing.expectEqual(@as(i64, 10), duration.seconds);

    // Test with negative seconds
    duration = Duration.Seconds(-10);
    try testing.expectEqual(@as(i64, -10), duration.seconds);

    // Test with zero seconds
    duration = Duration.Seconds(0);
    try testing.expectEqual(@as(i64, 0), duration.seconds);
}
