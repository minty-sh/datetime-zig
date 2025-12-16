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