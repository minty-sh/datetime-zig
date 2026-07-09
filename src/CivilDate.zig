const std = @import("std");
const epoch = std.time.epoch;
const constants = @import("constants.zig");
const DayOfWeek = @import("time_units.zig").DayOfWeek;
const test_helpers = @import("test_helpers.zig");

/// Represents a civil date (year, month, day) without time components or timezone information.
/// This file is the struct type, which is primarily used for date calculations and conversions.
/// ` @This()` can be used to refer to this struct type (CivilDate).
const CivilDate = @This();

year: i32,
month: i32,
day: i32,

/// Creates a CivilDate from a count of days since the Unix epoch (1970-01-01).
/// This function performs the inverse operation of `daysSinceUnixEpoch`.
pub fn fromDays(days: i64) CivilDate {
    // Shift the day count so that calculations work with the Gregorian calendar starting at a reference point
    const shifted_days = @as(i64, days) + 719468;

    // Determine the "era" (400-year block) the date falls into
    const era_index = if (shifted_days >= 0)
        @divFloor(shifted_days, 146097)
    else
        @divFloor(shifted_days - 146096, 146097);

    // Find the number of days within the current 400-year era
    const day_of_era = @as(i64, shifted_days - era_index * 146097);

    // Calculate the year within the 400-year era
    const year_of_era = @divFloor(@as(i64, (@divFloor(day_of_era, 1) - @divFloor(day_of_era, 1460) + @divFloor(day_of_era, 36524) - @divFloor(day_of_era, 146096))), 365);

    // Cast year and era to i32 for later arithmetic
    const year_of_era_i32: i32 = @intCast(year_of_era);
    const era_index_i32: i32 = @intCast(era_index);

    // Combine era and year within era to get the full year
    const year = year_of_era_i32 + era_index_i32 * 400;

    // Cast day_of_era to i32 for day-of-year calculation
    const day_of_era_i32: i32 = @intCast(day_of_era);
    const year_of_era_i32_for_doy: i32 = @intCast(year_of_era);

    // Calculate the day of the year (0-based)
    const day_of_year = day_of_era_i32 - (365 * year_of_era_i32_for_doy + @divFloor(year_of_era_i32_for_doy, 4) - @divFloor(year_of_era_i32_for_doy, 100));

    // Determine month period (0-based March=0...February=11)
    const month_period: i32 = @intCast(@divFloor((5 * @as(i64, day_of_year) + 2), 153));

    // Calculate day of month (1-based)
    const day: i32 = @as(i32, day_of_year - @divFloor(153 * month_period + 2, 5) + 1);

    // Convert month period to 1-based month (January=1...December=12)
    const month: i32 = @as(i32, month_period + @as(i32, if (month_period < 10) 3 else -9));

    // Adjust the year if month is January or February (they belong to previous calendar year in calculation)
    var year_result = year;
    year_result = year_result + @as(i32, if (month <= 2) 1 else 0);

    // Return the resulting CivilDate struct
    return .{ .year = year_result, .month = month, .day = day };
}

/// Creates a CivilDate from its year, month, and day components.
pub fn fromComponents(year: i32, month: i32, day: i32) CivilDate {
    return .{ .year = year, .month = month, .day = day };
}

/// Returns the day of the week for this CivilDate.
pub fn dayOfWeek(self: CivilDate) DayOfWeek {
    const days = daysSinceUnixEpoch(self.year, self.month, self.day);
    const dow = @mod(days + 4, 7);
    return @enumFromInt(@as(u3, @intCast(dow)));
}

/// Returns a new CivilDate offset by `days` days.
pub fn addDays(self: CivilDate, days: i64) CivilDate {
    const d = daysSinceUnixEpoch(self.year, self.month, self.day) + days;
    return fromDays(d);
}

/// Returns a new CivilDate offset by `months` months, with day clamping.
pub fn addMonths(self: CivilDate, months: i64) CivilDate {
    const total_months = @as(i64, self.year) * 12 + @as(i64, self.month - 1) + months;
    const new_year = @divFloor(total_months, 12);
    const new_month = @as(i32, @intCast(@mod(total_months, 12) + 1));
    var new_day = self.day;
    const days_in_new_month = epoch.getDaysInMonth(@intCast(new_year), @enumFromInt(@as(u4, @intCast(new_month))));
    if (new_day > days_in_new_month) new_day = @as(i32, @intCast(days_in_new_month));
    return .{ .year = @intCast(new_year), .month = new_month, .day = new_day };
}

/// Returns a new CivilDate offset by `years` years, with leap-day clamping.
pub fn addYears(self: CivilDate, years: i64) CivilDate {
    const new_year: i64 = @as(i64, self.year) + years;
    var new_day = self.day;
    if (self.month == 2 and self.day == 29 and !epoch.isLeapYear(@intCast(new_year))) {
        new_day = 28;
    }
    return .{ .year = @intCast(new_year), .month = self.month, .day = new_day };
}

/// Formats this CivilDate according to `fmt_str` (date-only strftime specifiers:
/// `%Y`, `%m`, `%d`, `%B`, `%b`, `%A`, `%a`, `%%`). The returned slice is
/// caller-owned and must be freed with `allocator`.
pub fn format(self: CivilDate, allocator: std.mem.Allocator, fmt_str: []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const writer = &aw.writer;

    var i: usize = 0;
    while (i < fmt_str.len) {
        if (fmt_str[i] == '%') {
            i += 1;
            if (i >= fmt_str.len) {
                try writer.writeAll("%");
                break;
            }
            switch (fmt_str[i]) {
                'Y' => try writer.print("{d:04}", .{@as(u32, @intCast(self.year))}),
                'm' => try writer.print("{d:02}", .{@as(u32, @intCast(self.month))}),
                'd' => try writer.print("{d:02}", .{@as(u32, @intCast(self.day))}),
                'B' => try writer.writeAll(constants.month_names[@intCast(self.month - 1)]),
                'b' => try writer.writeAll(constants.month_abbrs[@intCast(self.month - 1)]),
                'A' => try writer.writeAll(constants.day_names[@intFromEnum(self.dayOfWeek())]),
                'a' => try writer.writeAll(constants.day_abbrs[@intFromEnum(self.dayOfWeek())]),
                '%' => try writer.writeAll("%"),
                else => {
                    try writer.writeAll("%");
                    try writer.writeByte(fmt_str[i]);
                },
            }
        } else {
            try writer.writeByte(fmt_str[i]);
        }
        i += 1;
    }
    return aw.toOwnedSlice();
}

/// Returns true if the two CivilDates represent the same calendar date.
pub fn eql(self: CivilDate, other: CivilDate) bool {
    return self.year == other.year and self.month == other.month and self.day == other.day;
}

/// Returns the relative ordering of two CivilDates (chronological).
pub fn order(self: CivilDate, other: CivilDate) std.math.Order {
    return std.math.order(
        daysSinceUnixEpoch(self.year, self.month, self.day),
        daysSinceUnixEpoch(other.year, other.month, other.day),
    );
}

/// Returns true if this CivilDate is chronologically before `other`.
pub fn isBefore(self: CivilDate, other: CivilDate) bool {
    return self.order(other) == .lt;
}

/// Returns true if this CivilDate is chronologically after `other`.
pub fn isAfter(self: CivilDate, other: CivilDate) bool {
    return self.order(other) == .gt;
}

/// Alias for `order`.
pub fn compare(self: CivilDate, other: CivilDate) std.math.Order {
    return self.order(other);
}

/// Creates a CivilDate from a DateTime, discarding time and offset.
pub fn fromDateTime(dt: @import("DateTime.zig")) CivilDate {
    return dt.toCivilDate();
}

/// Returns number of days since Unix epoch (1970-01-01)
pub fn daysSinceUnixEpoch(y: i32, m: i32, d: i32) i64 {
    // Adjust the year if the month is Jan or Feb
    // This effectively treats Jan and Feb as months 13 and 14 of the previous year
    const year_shift: i32 = if (m <= 2) 1 else 0;
    const adjusted_year: i32 = y - year_shift;

    // Calculate the "era" for 400-year cycles
    // This handles negative years correctly
    const era_year_calc: i32 = if (adjusted_year >= 0) adjusted_year else adjusted_year - 399;
    const era: i32 = @divFloor(era_year_calc, 400);

    // Year within the current 400-year era
    const year_of_era: i32 = adjusted_year - era * 400; // [0, 399]

    // Adjust month to a 0-based March=0..February=11 scale
    const month_offset: i32 = if (m > 2) -3 else 9;
    const month_zero_based: i32 = m + month_offset; // [0, 11]

    // Day of year within the era (0-based)
    const day_of_year: i32 = @divFloor((153 * month_zero_based) + 2, 5) + d - 1; // [0, 365]

    // Total days in the era including leap year adjustments
    const day_of_era: i32 = year_of_era * 365 + @divFloor(year_of_era, 4) // add leap days
    - @divFloor(year_of_era, 100) // subtract century non-leap days
    + day_of_year; // add days of current year

    // Total days since Unix epoch (1970-01-01)
    const days: i32 = era * 146097 + day_of_era - 719468;

    return @as(i64, days);
}

test "daysSinceUnixEpoch" {
    const testing = std.testing;

    // Test case 1: The Unix epoch itself
    try testing.expectEqual(@as(i64, 0), CivilDate.daysSinceUnixEpoch(1970, 1, 1));

    // Test case 2: A date after the epoch
    try testing.expectEqual(@as(i64, 19657), CivilDate.daysSinceUnixEpoch(2023, 10, 27));

    // Test case 3: A date before the epoch
    try testing.expectEqual(@as(i64, -3518), CivilDate.daysSinceUnixEpoch(1960, 5, 15));

    // Test case 4: A leap day (Feb 29, 2000)
    try testing.expectEqual(@as(i64, 11016), CivilDate.daysSinceUnixEpoch(2000, 2, 29));

    // Test case 5: Day after a leap day
    try testing.expectEqual(@as(i64, 11017), CivilDate.daysSinceUnixEpoch(2000, 3, 1));

    // Test case 6: A non-leap year (1900)
    try testing.expectEqual(@as(i64, -25508), CivilDate.daysSinceUnixEpoch(1900, 3, 1));
    try testing.expectEqual(CivilDate.daysSinceUnixEpoch(1900, 3, 1), CivilDate.daysSinceUnixEpoch(1900, 2, 28) + 1);

    // Test case 7: Another non-leap year (2100)
    try testing.expectEqual(CivilDate.daysSinceUnixEpoch(2100, 3, 1), CivilDate.daysSinceUnixEpoch(2100, 2, 28) + 1);

    // Test case 8: A regular leap year (2004)
    try testing.expectEqual(CivilDate.daysSinceUnixEpoch(2004, 3, 1), CivilDate.daysSinceUnixEpoch(2004, 2, 29) + 1);
}

test "Days" {
    const testing = std.testing;

    // Test case 1: The Unix epoch
    var date = CivilDate.fromDays(0);
    try testing.expectEqual(1970, date.year);
    try testing.expectEqual(1, date.month);
    try testing.expectEqual(1, date.day);

    // Test case 2: A date after the epoch
    date = CivilDate.fromDays(19657);
    try testing.expectEqual(2023, date.year);
    try testing.expectEqual(10, date.month);
    try testing.expectEqual(27, date.day);

    // Test case 3: A date before the epoch
    date = CivilDate.fromDays(-3518);
    try testing.expectEqual(1960, date.year);
    try testing.expectEqual(5, date.month);
    try testing.expectEqual(15, date.day);

    // Test case 4: A leap day (Feb 29, 2000)
    date = CivilDate.fromDays(11016);
    try testing.expectEqual(2000, date.year);
    try testing.expectEqual(2, date.month);
    try testing.expectEqual(29, date.day);
}

test "roundtrip conversion" {
    const testing = std.testing;
    var i: i64 = -20000;
    while (i < 20000) : (i += 1) {
        const original_date = CivilDate.fromDays(i);
        const days = CivilDate.daysSinceUnixEpoch(original_date.year, original_date.month, original_date.day);
        const final_date = CivilDate.fromDays(days);
        try testing.expectEqual(original_date.year, final_date.year);
        try testing.expectEqual(original_date.month, final_date.month);
        try testing.expectEqual(original_date.day, final_date.day);
        try testing.expectEqual(i, days);
    }
}

test "CivilDate API additions" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // fromComponents + dayOfWeek
    const cd = CivilDate.fromComponents(2023, 10, 27);
    try testing.expectEqual(@as(i32, 2023), cd.year);
    try testing.expectEqual(@as(i32, 10), cd.month);
    try testing.expectEqual(@as(i32, 27), cd.day);
    try testing.expectEqual(DayOfWeek.friday, cd.dayOfWeek());

    // addDays / addMonths / addYears
    const cd2 = cd.addDays(1);
    try testing.expectEqual(@as(i32, 28), cd2.day);

    const cd3 = cd.addMonths(1);
    try testing.expectEqual(@as(i32, 11), cd3.month);
    try testing.expectEqual(@as(i32, 27), cd3.day);

    // Leap-year clamping
    const leap = CivilDate.fromComponents(2024, 2, 29);
    const leap_plus1 = leap.addYears(1);
    try testing.expectEqual(@as(i32, 28), leap_plus1.day);
    const leap_plus4 = leap.addYears(4);
    try testing.expectEqual(@as(i32, 29), leap_plus4.day);

    // format
    try test_helpers.expectFormat(allocator, "Friday, October 27, 2023", cd.format(allocator, "%A, %B %d, %Y"));

    // eql + ordering
    const cd_same = CivilDate.fromComponents(2023, 10, 27);
    const cd_later = CivilDate.fromComponents(2023, 10, 28);
    try testing.expect(cd.eql(cd_same));
    try testing.expect(cd.isBefore(cd_later));
    try testing.expect(cd_later.isAfter(cd));
    try testing.expectEqual(std.math.Order.lt, cd.order(cd_later));

    // fromDateTime
    const dt = @import("DateTime.zig").fromUnix(1_600_000_000, 0);
    const cd4 = CivilDate.fromDateTime(dt);
    try testing.expectEqual(cd4.year, dt.toCivilDate().year);
}
