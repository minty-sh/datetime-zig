const std = @import("std");
const epoch = std.time.epoch;

/// Represents a civil date (year, month, day) without time components or timezone information.
/// This struct is primarily used for date calculations and conversions.
pub const CivilDate = struct {
    year: i32,
    month: i32,
    day: i32,

    /// Creates a CivilDate from a count of days since the Unix epoch (1970-01-01).
    /// This function performs the inverse operation of `days_since_unix_epoch`.
    pub fn from_days(days: i64) CivilDate {
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
        return CivilDate{ .year = year_result, .month = month, .day = day };
    }

    /// Returns number of days since Unix epoch (1970-01-01)
    pub fn days_since_unix_epoch(y: i32, m: i32, d: i32) i64 {
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
};

test "days_since_unix_epoch" {
    const testing = std.testing;

    // Test case 1: The Unix epoch itself
    try testing.expectEqual(@as(i64, 0), CivilDate.days_since_unix_epoch(1970, 1, 1));

    // Test case 2: A date after the epoch
    try testing.expectEqual(@as(i64, 19657), CivilDate.days_since_unix_epoch(2023, 10, 27));

    // Test case 3: A date before the epoch
    try testing.expectEqual(@as(i64, -3518), CivilDate.days_since_unix_epoch(1960, 5, 15));

    // Test case 4: A leap day (Feb 29, 2000)
    try testing.expectEqual(@as(i64, 11016), CivilDate.days_since_unix_epoch(2000, 2, 29));

    // Test case 5: Day after a leap day
    try testing.expectEqual(@as(i64, 11017), CivilDate.days_since_unix_epoch(2000, 3, 1));

    // Test case 6: A non-leap year (1900)
    try testing.expectEqual(@as(i64, -25508), CivilDate.days_since_unix_epoch(1900, 3, 1));
    try testing.expectEqual(CivilDate.days_since_unix_epoch(1900, 3, 1), CivilDate.days_since_unix_epoch(1900, 2, 28) + 1);

    // Test case 7: Another non-leap year (2100)
    try testing.expectEqual(CivilDate.days_since_unix_epoch(2100, 3, 1), CivilDate.days_since_unix_epoch(2100, 2, 28) + 1);

    // Test case 8: A regular leap year (2004)
    try testing.expectEqual(CivilDate.days_since_unix_epoch(2004, 3, 1), CivilDate.days_since_unix_epoch(2004, 2, 29) + 1);
}

test "from_days" {
    const testing = std.testing;

    // Test case 1: The Unix epoch
    var date = CivilDate.from_days(0);
    try testing.expectEqual(1970, date.year);
    try testing.expectEqual(1, date.month);
    try testing.expectEqual(1, date.day);

    // Test case 2: A date after the epoch
    date = CivilDate.from_days(19657);
    try testing.expectEqual(2023, date.year);
    try testing.expectEqual(10, date.month);
    try testing.expectEqual(27, date.day);

    // Test case 3: A date before the epoch
    date = CivilDate.from_days(-3518);
    try testing.expectEqual(1960, date.year);
    try testing.expectEqual(5, date.month);
    try testing.expectEqual(15, date.day);

    // Test case 4: A leap day (Feb 29, 2000)
    date = CivilDate.from_days(11016);
    try testing.expectEqual(2000, date.year);
    try testing.expectEqual(2, date.month);
    try testing.expectEqual(29, date.day);
}

test "roundtrip conversion" {
    const testing = std.testing;
    var i: i64 = -20000;
    while (i < 20000) : (i += 1) {
        const original_date = CivilDate.from_days(i);
        const days = CivilDate.days_since_unix_epoch(original_date.year, original_date.month, original_date.day);
        const final_date = CivilDate.from_days(days);
        try testing.expectEqual(original_date.year, final_date.year);
        try testing.expectEqual(original_date.month, final_date.month);
        try testing.expectEqual(original_date.day, final_date.day);
        try testing.expectEqual(i, days);
    }
}
