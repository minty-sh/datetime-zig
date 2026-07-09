const std = @import("std");
pub const DateTime = @import("DateTime.zig");
pub const CivilDate = @import("CivilDate.zig");

pub const time_units = DateTime.time_units;
pub const DayOfWeek = time_units.DayOfWeek;
pub const Duration = DateTime.Duration;

const test_helpers = @import("test_helpers.zig");

test "DateTime diff" {
    const dt1 = DateTime.fromUnix(1000, 0);
    const dt2 = DateTime.fromUnix(500, 0);
    const d = dt1.diff(dt2);
    try std.testing.expectEqual(@as(i64, 500), d.asSeconds());

    const dt3 = dt1.sub(d);
    try std.testing.expectEqual(dt2.unix_secs, dt3.unix_secs);

    const dt4 = dt2.add(d);
    try std.testing.expectEqual(dt1.unix_secs, dt4.unix_secs);
}

test "Date Arithmetic" {
    const dt1 = try DateTime.fromComponents(2023, 1, 31, 10, 0, 0, 0);

    // add days
    const dt2 = dt1.addDays(1);
    const cd2 = dt2.toCivilDate();
    try std.testing.expectEqual(2023, cd2.year);
    try std.testing.expectEqual(2, cd2.month);
    try std.testing.expectEqual(1, cd2.day);

    // add months, with day clamping
    const dt3 = try dt1.addMonths(1);
    const cd3 = dt3.toCivilDate();
    try std.testing.expectEqual(2023, cd3.year);
    try std.testing.expectEqual(2, cd3.month);
    try std.testing.expectEqual(28, cd3.day);

    // add years, with leap day handling
    const dt4 = try DateTime.fromComponents(2024, 2, 29, 12, 0, 0, 0);
    const dt5 = try dt4.addYears(1);
    const cd5 = dt5.toCivilDate();
    try std.testing.expectEqual(2025, cd5.year);
    try std.testing.expectEqual(2, cd5.month);
    try std.testing.expectEqual(28, cd5.day);

    const dt6 = try dt4.addYears(4);
    const cd6 = dt6.toCivilDate();
    try std.testing.expectEqual(2028, cd6.year);
    try std.testing.expectEqual(2, cd6.month);
    try std.testing.expectEqual(29, cd6.day);
}

test "DayOfWeek and Business Days" {
    // 1970-01-01 was a Thursday
    const dt1 = DateTime.fromUnix(0, 0);
    try std.testing.expectEqual(DayOfWeek.thursday, dt1.dayOfWeek());
    try std.testing.expect(dt1.isWeekday());

    // 2023-10-27 is a Friday
    const dt2 = try DateTime.fromComponents(2023, 10, 27, 0, 0, 0, 0);
    // Add 1 business day to Friday 27th -> Monday 30th
    const dt3 = dt2.addBusinessDays(1);
    const cd3 = dt3.toCivilDate();
    try std.testing.expectEqual(2023, cd3.year);
    try std.testing.expectEqual(10, cd3.month);
    try std.testing.expectEqual(30, cd3.day);
    try std.testing.expectEqual(DayOfWeek.monday, dt3.dayOfWeek());
}

test "ISO Week" {
    // 2023-10-27 is in week 43 of 2023
    const dt1 = try DateTime.fromComponents(2023, 10, 27, 0, 0, 0, 0);
    const iw1 = try dt1.isoWeek();
    try std.testing.expectEqual(2023, iw1.year);
    try std.testing.expectEqual(43, iw1.week);

    // 2021-01-01 is in week 53 of 2020
    const dt2 = try DateTime.fromComponents(2021, 1, 1, 0, 0, 0, 0);
    const iw2 = try dt2.isoWeek();
    try std.testing.expectEqual(2020, iw2.year);
    try std.testing.expectEqual(53, iw2.week);

    // 2010-01-03 was a Sunday, should be in week 53 of 2009
    const dt3 = try DateTime.fromComponents(2010, 1, 3, 0, 0, 0, 0);
    const iw3 = try dt3.isoWeek();
    try std.testing.expectEqual(2009, iw3.year);
    try std.testing.expectEqual(53, iw3.week);
}

test "Truncate and Round" {
    const dt = try DateTime.fromComponents(2023, 10, 27, 10, 30, 45, 0);

    // Truncate
    const trunc_day = try dt.truncate(.day);
    const cd1 = trunc_day.toCivilDate();
    try std.testing.expectEqual(2023, cd1.year);
    try std.testing.expectEqual(10, cd1.month);
    try std.testing.expectEqual(27, cd1.day);
    const local_secs1 = trunc_day.unix_secs + trunc_day.offset_seconds;
    try std.testing.expectEqual(0, @mod(local_secs1, 86400));

    // Round
    const round_hour = try dt.round(.hour); // 10:30 rounds up to 11:00
    const rh_local_secs = round_hour.unix_secs + round_hour.offset_seconds;
    var rh_rem = @mod(rh_local_secs, 86400);
    if (rh_rem < 0) {
        rh_rem += 86400;
    }
    const rh_hour = @divFloor(rh_rem, 3600);
    try std.testing.expectEqual(11, rh_hour);
}

test "Final Features" {
    const allocator = std.testing.allocator;

    // strftime
    const dt1 = try DateTime.fromComponents(2023, 10, 27, 10, 30, 5, 0);
    try test_helpers.expectFormat(allocator, "Friday, October 27, 2023", dt1.strftime(allocator, "%A, %B %d, %Y"));

    // humanize
    const now = try DateTime.fromComponents(2023, 10, 27, 10, 0, 0, 0);
    const five_min_ago = now.sub(Duration.fromSeconds(5 * 60));
    try test_helpers.expectFormat(allocator, "5 minutes ago", five_min_ago.toHumanString(now, allocator));

    // IANA Timezone
    const dt_utc = try DateTime.fromComponents(2023, 11, 5, 10, 0, 0, 0);
    switch (@import("builtin").os.tag) {
        // TODO: don't know if macOS has tzdata
        .linux => {
            var ti = test_helpers.makeTestIo(std.testing.allocator);
            defer ti.threaded.deinit();
            const io = ti.io;
            const dt_ny = dt_utc.toTimezone(io, allocator, "America/New_York") catch |err| {
                if (err == error.FileNotFound or err == DateTime.Error.NoTimetypeFound) return; // skip test if tzdata not found
                return err;
            };
            try std.testing.expectEqual(-5 * 3600, dt_ny.offset_seconds);
            const local_secs = dt_ny.unix_secs + dt_ny.offset_seconds;
            const hour = @divFloor(@mod(local_secs, 86400), 3600);
            try std.testing.expectEqual(5, hour);
        },
        else => return,
    }
}

test "DateTime API additions" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // comparison / ordering
    const a = DateTime.fromUnix(1000, 0);
    const b = DateTime.fromUnix(2000, 0);
    try testing.expect(a.eql(a));
    try testing.expect(a.isBefore(b));
    try testing.expect(b.isAfter(a));
    try testing.expectEqual(std.math.Order.lt, a.order(b));
    try testing.expectEqual(std.math.Order.gt, b.compare(a));

    // utc + toUnix
    const dt = DateTime.fromUnix(1_600_000_000, 3600);
    try testing.expectEqual(@as(i64, 1_600_000_000), dt.toUnix());
    const dt_utc = dt.utc();
    try testing.expectEqual(@as(i32, 0), dt_utc.offset_seconds);

    // fromCivilDate round-trips with toCivilDate
    const dt2 = try DateTime.fromComponents(2023, 10, 27, 10, 30, 0, 0);
    const cd = dt2.toCivilDate();
    const dt2b = try DateTime.fromCivilDate(cd, 10, 30, 0, 0);
    try testing.expect(dt2.eql(dt2b));

    // HTTP date + ISO8601 (delegates to RFC3339, offset 0 -> Z)
    try test_helpers.expectFormat(allocator, "Fri, 27 Oct 2023 10:30:00 GMT", dt2.formatHttp(allocator));
    try test_helpers.expectFormat(allocator, "2023-10-27T10:30:00Z", dt2.formatISO8601(allocator));

    // isoWeek named struct
    const iw = try dt2.isoWeek();
    try testing.expectEqual(@as(i32, 2023), iw.year);
    try testing.expectEqual(@as(u8, 43), iw.week);

    // now() returns a valid (positive) instant
    var ti = test_helpers.makeTestIo(allocator);
    defer ti.threaded.deinit();
    const io = ti.io;
    const now_dt = DateTime.now(io);
    try testing.expect(now_dt.toUnix() > 0);
}
