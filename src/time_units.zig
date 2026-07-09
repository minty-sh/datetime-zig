const std = @import("std");
const constants = @import("constants.zig");

/// Represents a unit of time for truncation and rounding operations.
pub const TimeUnit = enum {
    year,
    month,
    day,
    hour,
    minute,
    second,
};

/// Represents the days of the week, Sunday through Saturday.
pub const DayOfWeek = enum(u3) {
    sunday,
    monday,
    tuesday,
    wednesday,
    thursday,
    friday,
    saturday,

    /// Returns the full name of this day ("Sunday", "Monday", …).
    pub fn name(self: DayOfWeek) []const u8 {
        return constants.day_names[@intFromEnum(self)];
    }

    /// Returns the abbreviated name of this day ("Sun", "Mon", …).
    pub fn abbr(self: DayOfWeek) []const u8 {
        return constants.day_abbrs[@intFromEnum(self)];
    }

    /// Creates a DayOfWeek from an integer (0=sunday, 6=saturday).
    pub fn fromInt(n: u3) DayOfWeek {
        return @enumFromInt(n);
    }
};

test "DayOfWeek helpers" {
    const testing = std.testing;

    try testing.expectEqualStrings("Sunday", DayOfWeek.sunday.name());
    try testing.expectEqualStrings("Sun", DayOfWeek.sunday.abbr());
    try testing.expectEqual(DayOfWeek.sunday, DayOfWeek.fromInt(0));
    try testing.expectEqual(DayOfWeek.saturday, DayOfWeek.fromInt(6));

    try testing.expectEqual(@as(u3, 0), @intFromEnum(DayOfWeek.sunday));
    try testing.expectEqual(@as(u3, 1), @intFromEnum(DayOfWeek.monday));
    try testing.expectEqual(@as(u3, 6), @intFromEnum(DayOfWeek.saturday));

    _ = TimeUnit.year;
    _ = TimeUnit.month;
    _ = TimeUnit.day;
    _ = TimeUnit.hour;
    _ = TimeUnit.minute;
    _ = TimeUnit.second;
}
