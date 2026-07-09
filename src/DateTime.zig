const std = @import("std");
const epoch = std.time.epoch;

const constants = @import("constants.zig");
const humanize = @import("humanize.zig");
const tz_helpers = @import("tz_helpers.zig");
pub const time_units = @import("time_units.zig");
pub const Duration = @import("duration.zig").Duration;

pub const CivilDate = @import("CivilDate.zig");

const parse = @import("format_parse_helpers.zig");

pub const Error = error{
    BadFormat,
    InvalidMonth,
    InvalidDay,
    InvalidTime,
    InvalidOffset,
    NoTimetypeFound,
};

/// An ISO 8601 week date: the ISO week-numbering year and the week number (1-53).
pub const IsoWeek = struct {
    year: i32,
    week: u8,
};

/// Represents a specific point in time, with a Unix timestamp and an offset from UTC.
/// This file itself is the struct type, referred to as ` @This()` or `DateTime`.
const DateTime = @This();

/// seconds since Unix epoch (1970-01-01T00:00:00Z)
unix_secs: i64,
/// offset from UTC in seconds (e.g. +02:30 => 9000)
offset_seconds: i32,

/// Create from unix seconds + offset
pub fn fromUnix(unix_secs: i64, offset_seconds: i32) DateTime {
    return .{
        .unix_secs = unix_secs,
        .offset_seconds = offset_seconds,
    };
}

/// Create from unix seconds, assuming UTC (offset 0)
pub fn fromEpoch(unix_secs: i64) DateTime {
    return .{
        .unix_secs = unix_secs,
        .offset_seconds = 0,
    };
}

/// Returns the current UTC instant (Unix epoch seconds).
pub fn now(io: std.Io) DateTime {
    return fromEpoch(std.Io.Timestamp.now(io, .real).toSeconds());
}

/// Create from numeric components (year, month, day, hour, minute, second).
/// If month/day/time components are omitted (use null), defaults are month=1, day=1, hour=0, min=0, sec=0.
pub fn fromComponents(
    year: i32,
    month_opt: ?u8,
    day_opt: ?u8,
    hour_opt: ?u8,
    minute_opt: ?u8,
    second_opt: ?u8,
    offset_seconds: i32,
) !DateTime {
    const y = year;
    const m: i32 = if (month_opt) |mm| @intCast(mm) else 1;
    const d: i32 = if (day_opt) |dd| @intCast(dd) else 1;
    const hh: i32 = if (hour_opt) |hh_| @intCast(hh_) else 0;
    const mm_: i32 = if (minute_opt) |mm__| @intCast(mm__) else 0;
    const ss: i32 = if (second_opt) |ss_| @intCast(ss_) else 0;

    // Validate rudimentarily
    if (m < 1 or m > 12) return Error.InvalidMonth;
    const month_enum: epoch.Month = @enumFromInt(m);
    const days_in_month: i32 = @intCast(epoch.getDaysInMonth(@intCast(y), month_enum));

    if (d < 1 or d > days_in_month) return Error.InvalidDay;
    if (hh < 0 or hh > 23) return Error.InvalidTime;
    if (mm_ < 0 or mm_ > 59) return Error.InvalidTime;
    // Reject leap seconds for now
    if (ss < 0 or ss > 59) return Error.InvalidTime;

    if (offset_seconds < -86400 or offset_seconds > 86400) return Error.InvalidOffset;

    const days = CivilDate.daysSinceUnixEpoch(y, m, d);
    const seconds_in_day: i64 = @intCast(hh * 3600 + mm_ * 60 + ss);
    const local_secs: i64 = days * 86400 + seconds_in_day;
    // convert local -> utc by subtracting offset
    const offset_i64: i64 = @intCast(offset_seconds);
    const utc_secs = local_secs - offset_i64;
    return fromUnix(utc_secs, offset_seconds);
}

/// Creates a DateTime from a CivilDate plus time-of-day components and an offset.
pub fn fromCivilDate(cd: CivilDate, hour: u8, minute: u8, second: u8, offset_seconds: i32) !DateTime {
    return fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, minute, second, offset_seconds);
}

/// Parse an RFC3339 / ISO8601-like string
/// Accepts: YYYY-MM-DDTHH:MM[:SS][.frac](Z|+HH:MM|-HH:MM)
pub fn fromRfc3339(s: []const u8) !DateTime {
    var i: usize = 0;
    const len = s.len;

    if (len < 4) return Error.BadFormat;
    const year = parse.parseIntDigits(s, &i, 4) catch return Error.BadFormat;

    if (!parse.expect(s, i, '-')) return Error.BadFormat;
    i += 1;
    const month = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;
    if (!parse.expect(s, i, '-')) return Error.BadFormat;
    i += 1;
    const day = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;

    // If date-only (no time) -> midnight UTC (permissive choice)
    if (!parse.expect(s, i, 'T') and !parse.expect(s, i, 't') and !parse.expect(s, i, ' ')) {
        const dt = try fromComponents(@intCast(year), @intCast(month), @intCast(day), null, null, null, 0);
        return dt;
    }
    // skip separator
    i += 1;

    const hour = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;
    if (!parse.expect(s, i, ':')) return Error.BadFormat;
    i += 1;
    const minute = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;

    var second: i32 = 0;
    if (parse.expect(s, i, ':')) {
        i += 1;
        second = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;
    }

    // optional fractional seconds: skip them
    if (i < len and s[i] == '.') {
        i += 1;
        while (i < len and std.ascii.isDigit(s[i])) : (i += 1) {}
    }

    // timezone: 'Z' or '+/-HH:MM'
    var offset_seconds: i32 = 0;
    if (i >= len) {
        // no tz -> treat as Z
        offset_seconds = 0;
    } else {
        const ch = s[i];
        if (ch == 'Z' or ch == 'z') {
            offset_seconds = 0;
            i += 1;
        } else if (ch == '+' or ch == '-') {
            const sign: i32 = if (ch == '+') 1 else -1;
            i += 1;
            const oh = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;
            if (!parse.expect(s, i, ':')) return Error.BadFormat;
            i += 1;
            const om = parse.parseIntDigits(s, &i, 2) catch return Error.BadFormat;
            offset_seconds = @as(i32, sign * (@as(i32, oh) * 3600 + @as(i32, om) * 60));
        } else {
            return Error.BadFormat;
        }
    }

    if (offset_seconds < -86400 or offset_seconds > 86400) return Error.InvalidOffset;

    // convert local date/time with offset -> unix UTC seconds
    const y_i = @as(i32, year);
    const m_i = @as(i32, month);
    const d_i = @as(i32, day);
    const h_i = @as(i32, hour);
    const min_i = @as(i32, minute);
    const sec_i = @as(i32, second);

    const days = CivilDate.daysSinceUnixEpoch(y_i, m_i, d_i);
    const local_secs: i64 = days * 86400 + @as(i64, h_i * 3600 + min_i * 60 + sec_i);
    const utc_secs: i64 = local_secs - @as(i64, offset_seconds);

    return fromUnix(utc_secs, offset_seconds);
}

/// Format this DateTime into RFC3339 string using its offset.
/// Allocates the returned string using given allocator.
pub fn formatRfc3339(self: @This(), allocator: std.mem.Allocator) ![]u8 {
    // convert utc seconds -> local seconds by adding offset
    const lc = self.local();
    const y = lc.date.year;
    const m = lc.date.month;
    const d = lc.date.day;
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    // compose timezone suffix
    var tz_buf: [6]u8 = undefined; // "Z" or "+HH:MM"
    var tz_slice: []const u8 = undefined;
    if (self.offset_seconds == 0) {
        tz_buf[0] = 'Z';
        tz_slice = tz_buf[0..1];
    } else {
        const sign: u8 = if (self.offset_seconds >= 0) '+' else '-';
        const off_abs = if (self.offset_seconds >= 0) self.offset_seconds else -self.offset_seconds;
        const off_h = @divFloor(off_abs, 3600);
        const off_m = @divFloor(@mod(off_abs, 3600), 60);
        tz_buf[0] = @as(u8, sign);
        tz_buf[1] = parse.charDigit(@intCast(@divFloor(off_h, 10)));
        tz_buf[2] = parse.charDigit(@intCast(@mod(off_h, 10)));
        tz_buf[3] = ':';
        tz_buf[4] = parse.charDigit(@intCast(@divFloor(off_m, 10)));
        tz_buf[5] = parse.charDigit(@intCast(@mod(off_m, 10)));
        tz_slice = tz_buf[0..6];
    }

    // allocate a buffer with exact needed length: "YYYY-MM-DDTHH:MM:SS" + tz
    const base_len = 19;
    const tz_len = tz_slice.len;
    const total = base_len + tz_len;
    var out = try allocator.alloc(u8, total);

    // write into out
    var idx: usize = 0;
    parse.write4digits(out, &idx, @intCast(y));
    out[idx] = '-';
    idx += 1;
    parse.write2digits(out, &idx, @intCast(m));
    out[idx] = '-';
    idx += 1;
    parse.write2digits(out, &idx, @intCast(d));
    out[idx] = 'T';
    idx += 1;
    parse.write2digits(out, &idx, hour);
    out[idx] = ':';
    idx += 1;
    parse.write2digits(out, &idx, minute);
    out[idx] = ':';
    idx += 1;
    parse.write2digits(out, &idx, second);
    // tz
    @memcpy(out[idx..][0..tz_slice.len], tz_slice);
    return out;
}

/// Formats this DateTime as an HTTP-date (IMF-fixdate, RFC 7231), e.g.
/// `"Fri, 27 Oct 2023 10:30:00 GMT"`. The timezone is always rendered as GMT
/// (the instant is interpreted in UTC regardless of `offset_seconds`).
/// Allocates the returned string using the given allocator.
pub fn formatHttp(self: @This(), allocator: std.mem.Allocator) ![]u8 {
    const lc = self.utc().local();
    const cd = lc.date;
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    const day_u: u32 = @intCast(cd.day);
    const year_u: u32 = @intCast(cd.year);

    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const writer = &aw.writer;
    try writer.print("{s}, {d:02} {s} {d:04} {d:02}:{d:02}:{d:02} GMT", .{
        constants.day_abbrs[@intFromEnum(fromUnix(self.unix_secs, 0).dayOfWeek())],
        day_u,
        constants.month_abbrs[@intCast(cd.month - 1)],
        year_u,
        hour,
        minute,
        second,
    });
    return aw.toOwnedSlice();
}

/// Formats this DateTime as an ISO 8601 / RFC 3339 string. This is identical in
/// output to `formatRfc3339` (date, time, and offset), and round-trips back
/// through `fromRfc3339`.
pub fn formatISO8601(self: @This(), allocator: std.mem.Allocator) ![]u8 {
    return self.formatRfc3339(allocator);
}
pub fn formatDate(self: @This(), allocator: std.mem.Allocator) ![]u8 {
    const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
    const days = @divFloor(local_secs, 86400);
    const result = CivilDate.fromDays(days);
    const y = result.year;
    const m = result.month;
    const d = result.day;

    const total = 10;
    var out = try allocator.alloc(u8, total);
    var idx: usize = 0;
    parse.write4digits(out, &idx, @intCast(y));
    out[idx] = '-';
    idx += 1;
    parse.write2digits(out, &idx, @intCast(m));
    out[idx] = '-';
    idx += 1;
    parse.write2digits(out, &idx, @intCast(d));
    return out;
}

/// Return CivilDate (year, month, day) for this DateTime in its own offset.
pub fn toCivilDate(self: @This()) CivilDate {
    const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
    const days = @divFloor(local_secs, 86400);
    return CivilDate.fromDays(days);
}

/// Splits this instant into its local civil date and wall-clock time-of-day,
/// applying `offset_seconds`. Centralizes the h/m/s math duplicated across the
/// formatting and arithmetic helpers.
fn local(self: @This()) struct {
    date: CivilDate,
    hour: u8,
    minute: u8,
    second: u8,
} {
    const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
    const days = @divFloor(local_secs, 86400);
    var rem = local_secs - days * 86400;
    if (rem < 0) rem += 86400;
    const hour: u8 = @intCast(@divFloor(rem, 3600));
    rem -= @as(i64, hour) * 3600;
    const minute: u8 = @intCast(@divFloor(rem, 60));
    const second: u8 = @intCast(@mod(rem, 60));
    return .{ .date = CivilDate.fromDays(days), .hour = hour, .minute = minute, .second = second };
}

/// Returns a copy of this DateTime with the offset set to UTC (0).
pub fn utc(self: @This()) DateTime {
    return fromUnix(self.unix_secs, 0);
}

/// Returns the Unix timestamp (seconds since 1970-01-01T00:00:00Z) of this instant.
pub fn toUnix(self: @This()) i64 {
    return self.unix_secs;
}

/// Calculates the duration between two DateTime instances.
pub fn diff(self: @This(), other: @This()) Duration {
    return Duration.fromSeconds(self.unix_secs - other.unix_secs);
}

/// Returns true if the two DateTimes represent the same instant (ignoring offset).
pub fn eql(self: @This(), other: @This()) bool {
    return self.unix_secs == other.unix_secs;
}

/// Returns the relative ordering of two instants (ignoring offset).
pub fn order(self: @This(), other: @This()) std.math.Order {
    return std.math.order(self.unix_secs, other.unix_secs);
}

/// Returns true if this instant is before `other`.
pub fn isBefore(self: @This(), other: @This()) bool {
    return self.unix_secs < other.unix_secs;
}

/// Returns true if this instant is after `other`.
pub fn isAfter(self: @This(), other: @This()) bool {
    return self.unix_secs > other.unix_secs;
}

/// Alias for `order`, for naming consistency with std comparison conventions.
pub fn compare(self: @This(), other: @This()) std.math.Order {
    return self.order(other);
}

/// Adds a duration to this DateTime instance, returning a new DateTime.
pub fn add(self: @This(), d: Duration) DateTime {
    return fromUnix(self.unix_secs + d.asSeconds(), self.offset_seconds);
}

/// Subtracts a duration from this DateTime instance, returning a new DateTime.
pub fn sub(self: @This(), d: Duration) DateTime {
    return fromUnix(self.unix_secs - d.asSeconds(), self.offset_seconds);
}

/// Adds a specified number of days to the DateTime.
pub fn addDays(self: @This(), days: i64) DateTime {
    return self.add(Duration.fromSeconds(days * 86400));
}

/// Subtracts a specified number of days from the DateTime.
pub fn subDays(self: @This(), days: i64) DateTime {
    return self.sub(Duration.fromSeconds(days * 86400));
}

/// Adds a specified number of weeks to the DateTime.
pub fn addWeeks(self: @This(), weeks: i64) DateTime {
    return self.add(Duration.fromSeconds(weeks * 7 * 86400));
}

/// Subtracts a specified number of weeks from the DateTime.
pub fn subWeeks(self: @This(), weeks: i64) DateTime {
    return self.sub(Duration.fromSeconds(weeks * 7 * 86400));
}

/// Adds a specified number of months to the DateTime. Handles day clamping.
pub fn addMonths(self: @This(), months: i64) !DateTime {
    const cd = self.toCivilDate();
    const total_months = @as(i64, cd.year) * 12 + @as(i64, cd.month - 1) + months;
    const new_year: i64 = @divFloor(total_months, 12);
    const new_month: u8 = @intCast(@mod(total_months, 12) + 1);

    var new_day: i32 = cd.day;
    const days_in_new_month: i32 = @intCast(epoch.getDaysInMonth(@intCast(new_year), @enumFromInt(new_month)));
    if (new_day > days_in_new_month) {
        new_day = days_in_new_month;
    }

    const lc = self.local();
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    return fromComponents(@intCast(new_year), new_month, @intCast(new_day), hour, minute, second, self.offset_seconds);
}

/// Subtracts a specified number of months from the DateTime.
pub fn subMonths(self: @This(), months: i64) !DateTime {
    return self.addMonths(-months);
}

/// Adds a specified number of years to the DateTime. Handles leap year day clamping.
pub fn addYears(self: @This(), years: i64) !DateTime {
    const cd = self.toCivilDate();
    const new_year: i64 = @as(i64, cd.year) + years;
    var new_day = cd.day;

    if (cd.month == 2 and cd.day == 29 and !epoch.isLeapYear(@intCast(new_year))) {
        new_day = 28;
    }

    const lc = self.local();
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    return fromComponents(@intCast(new_year), @intCast(cd.month), @intCast(new_day), hour, minute, second, self.offset_seconds);
}

/// Subtracts a specified number of years from the DateTime.
pub fn subYears(self: @This(), years: i64) !DateTime {
    return self.addYears(-years);
}

/// Returns the day of the week for this DateTime, computed in the local offset.
pub fn dayOfWeek(self: @This()) time_units.DayOfWeek {
    const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
    const days = @divFloor(local_secs, 86400);
    const dow = @mod(days + 4, 7);
    return @enumFromInt(@as(u3, @intCast(dow)));
}

/// Returns true if the DateTime falls on a weekday (Monday-Friday).
pub fn isWeekday(self: @This()) bool {
    return switch (self.dayOfWeek()) {
        .saturday, .sunday => false,
        else => true,
    };
}

/// Returns true if the DateTime falls on a weekend (Saturday or Sunday).
pub fn isWeekend(self: @This()) bool {
    return !self.isWeekday();
}

/// Adds business days (Mon-Fri), skipping weekends.
pub fn addBusinessDays(self: @This(), days: i64) DateTime {
    var result = self;
    var d: i64 = 0;
    const step: i64 = if (days > 0) 1 else -1;
    const count: i64 = if (days > 0) days else -days;

    while (d < count) {
        result = result.addDays(step);
        if (result.isWeekday()) {
            d += 1;
        }
    }
    return result;
}

/// Returns the day of the year (1-366).
pub fn dayOfYear(self: @This()) u16 {
    const cd = self.toCivilDate();
    const first_day_of_year = CivilDate.daysSinceUnixEpoch(cd.year, 1, 1);
    const this_day = CivilDate.daysSinceUnixEpoch(cd.year, cd.month, cd.day);
    return @intCast(this_day - first_day_of_year + 1);
}

/// Returns the ISO week date (year and week number).
pub fn isoWeek(self: @This()) !IsoWeek {
    const dow = self.dayOfWeek();
    const iso_dow = if (dow == .sunday) 7 else @intFromEnum(dow);

    // Thursday of the current week
    const thursday = self.addDays(4 - @as(i64, iso_dow));
    const th_cd = thursday.toCivilDate();
    const iso_year = th_cd.year;

    const first_day_of_iso_year = try fromComponents(iso_year, 1, 4, 0, 0, 0, 0);
    const first_thursday_dow = first_day_of_iso_year.dayOfWeek();
    const first_thursday_iso_dow = if (first_thursday_dow == .sunday) 7 else @intFromEnum(first_thursday_dow);

    // Monday of week 1
    const week1_monday = first_day_of_iso_year.subDays(@as(i64, first_thursday_iso_dow) - 1);

    const diff_secs = thursday.unix_secs - week1_monday.unix_secs;
    const diff_days = @divFloor(diff_secs, 86400);
    const week_num = @divFloor(diff_days, 7) + 1;

    return .{ .year = iso_year, .week = @intCast(week_num) };
}

/// Truncate to beginning of unit.
pub fn truncate(self: @This(), unit: time_units.TimeUnit) !DateTime {
    const cd = self.toCivilDate();
    const lc = self.local();
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    return switch (unit) {
        .year => fromComponents(cd.year, 1, 1, 0, 0, 0, self.offset_seconds),
        .month => fromComponents(cd.year, @intCast(cd.month), 1, 0, 0, 0, self.offset_seconds),
        .day => fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), 0, 0, 0, self.offset_seconds),
        .hour => fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, 0, 0, self.offset_seconds),
        .minute => fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, minute, 0, self.offset_seconds),
        .second => fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, minute, second, self.offset_seconds),
    };
}

/// Round to nearest unit (half-up).
pub fn round(self: @This(), unit: time_units.TimeUnit) !DateTime {
    const cd = self.toCivilDate();
    const lc = self.local();
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    switch (unit) {
        .year => {
            if (cd.month >= 7) {
                return (try self.addYears(1)).truncate(.year);
            }
            return self.truncate(.year);
        },
        .month => {
            const days_in_month = epoch.getDaysInMonth(@intCast(cd.year), @enumFromInt(cd.month));
            if (cd.day > days_in_month / 2) {
                return (try self.addMonths(1)).truncate(.month);
            }
            return self.truncate(.month);
        },
        .day => {
            if (hour >= 12) {
                return self.addDays(1).truncate(.day);
            }
            return self.truncate(.day);
        },
        .hour => {
            if (minute >= 30) {
                return self.add(Duration.fromSeconds(3600)).truncate(.hour);
            }
            return self.truncate(.hour);
        },
        .minute => {
            if (second >= 30) {
                return self.add(Duration.fromSeconds(60)).truncate(.minute);
            }
            return self.truncate(.minute);
        },
        .second => {
            return self.truncate(.second);
        },
    }
}

/// Formats according to format specifiers (%Y, %m, %d, %H, %M, %S, %B, %b, %A, %a).
pub fn strftime(self: @This(), allocator: std.mem.Allocator, fmt_str: []const u8) ![]u8 {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    errdefer aw.deinit();
    const writer = &aw.writer;

    const lc = self.local();
    const cd = lc.date;
    const hour = lc.hour;
    const minute = lc.minute;
    const second = lc.second;

    var i: usize = 0;
    while (i < fmt_str.len) {
        if (fmt_str[i] == '%') {
            i += 1;
            if (i >= fmt_str.len) {
                try writer.writeAll("%");
                break;
            }
            switch (fmt_str[i]) {
                'Y' => {
                    const year: u32 = @intCast(cd.year);
                    try writer.print("{d:04}", .{year});
                },
                'm' => {
                    const month: u32 = @intCast(cd.month);
                    try writer.print("{d:02}", .{month});
                },
                'd' => {
                    const day: u32 = @intCast(cd.day);
                    try writer.print("{d:02}", .{day});
                },
                'H' => try writer.print("{d:02}", .{hour}),
                'M' => try writer.print("{d:02}", .{minute}),
                'S' => try writer.print("{d:02}", .{second}),
                'B' => try writer.writeAll(constants.month_names[@intCast(cd.month - 1)]),
                'b' => try writer.writeAll(constants.month_abbrs[@intCast(cd.month - 1)]),
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

/// Humanize (relative time) using humanize module.
pub fn toHumanString(self: @This(), reference: @This(), allocator: std.mem.Allocator) ![]u8 {
    const diff_secs = self.unix_secs - reference.unix_secs;

    if (diff_secs >= 0) {
        return humanize.humanizeFuture(diff_secs, allocator);
    } else {
        return humanize.humanizePast(-diff_secs, allocator);
    }
}

/// Converts this DateTime to a different timezone specified by `tz_name`, returning a
/// DateTime with the same instant (`unix_secs`) and the timezone's offset at that instant.
/// `io` is the I/O context used to read the IANA tz database at `/usr/share/zoneinfo/{tz_name}`.
pub fn toTimezone(self: @This(), io: std.Io, allocator: std.mem.Allocator, tz_name: []const u8) !DateTime {
    const builtin = @import("builtin");

    if (builtin.os.tag == .windows) {
        // TODO: Keep cross-platform builds happy; we could implement Windows-specific lookup later.
        return Error.NoTimetypeFound;
    } else {
        const tz_path = try std.fmt.allocPrint(allocator, "/usr/share/zoneinfo/{s}", .{tz_name});
        defer allocator.free(tz_path);

        const file_contents = std.Io.Dir.cwd().readFileAlloc(io, tz_path, allocator, .unlimited) catch |err| {
            if (err == error.FileNotFound) return Error.NoTimetypeFound;
            return err;
        };
        defer allocator.free(file_contents);

        var reader = std.Io.Reader.fixed(file_contents);
        var tz_data = try std.tz.Tz.parse(allocator, &reader);
        defer tz_data.deinit();

        const timetype = try tz_helpers.findTimetype(&tz_data, self.unix_secs);
        return fromUnix(self.unix_secs, timetype.offset);
    }
}
