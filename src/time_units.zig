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
};

test "TimeUnit and DayOfWeek enums" {
    const testing = @import("std").testing;

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
