const std = @import("std");
const epoch = std.time.epoch;

const constants = @import("constants.zig");
const humanize_mod = @import("humanize.zig");
const tz_helpers = @import("tz_helpers.zig");
pub const time_units = @import("time_units.zig");
pub const Duration = @import("duration.zig").Duration;

pub const CivilDate = @import("civil_date.zig").CivilDate;
const parse = @import("format_parse_helpers.zig");

pub const DateError = error{
    BadFormat,
    InvalidMonth,
    InvalidDay,
    InvalidTime,
    NoTimetypeFound,
};

/// Represents a specific point in time, with a Unix timestamp and an offset from UTC.
pub const DateTime = struct {
    /// seconds since Unix epoch (1970-01-01T00:00:00Z)
    unix_secs: i64,
    /// offset from UTC in seconds (e.g. +02:30 => 9000)
    offset_seconds: i32,

    /// Create from unix seconds + offset
    pub fn fromUnix(unix_secs: i64, offset_seconds: i32) DateTime {
        return DateTime{
            .unix_secs = unix_secs,
            .offset_seconds = offset_seconds,
        };
    }

    /// Create from unix seconds, assuming an Unix epoch
    pub fn fromUnixEpoch(unix_secs: i64) DateTime {
        return DateTime{
            .unix_secs = unix_secs,
            .offset_seconds = 0,
        };
    }

    /// Create from numeric components (year, month, day, hour, minute, second).
    /// If month/day/time components are omitted (pass 0 for optional ints),
    /// defaults are month=1, day=1, hour=0, min=0, sec=0.
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
        if (m < 1 or m > 12) return DateError.InvalidMonth;
        const month_enum: epoch.Month = @enumFromInt(m);
        const days_in_month: i32 = @intCast(epoch.getDaysInMonth(@intCast(y), month_enum));

        if (d < 1 or d > days_in_month) return DateError.InvalidDay;
        if (hh < 0 or hh > 23) return DateError.InvalidTime;
        if (mm_ < 0 or mm_ > 59) return DateError.InvalidTime;
        if (ss < 0 or ss > 60) return DateError.InvalidTime; // allow leap second (60)

        const days = CivilDate.days_from_civil(y, m, d);
        const seconds_in_day: i64 = @intCast(hh * 3600 + mm_ * 60 + ss);
        const local_secs: i64 = days * 86400 + seconds_in_day;
        // convert local -> utc by subtracting offset
        const offset_i64: i64 = @intCast(offset_seconds);
        const utc_secs = local_secs - offset_i64;
        return DateTime{ .unix_secs = utc_secs, .offset_seconds = offset_seconds };
    }

    /// Parse an RFC3339 / ISO8601-like string
    /// Accepts: YYYY-MM-DDTHH:MM[:SS][.frac](Z|+HH:MM|-HH:MM)
    pub fn fromRfc3339(s: []const u8) !DateTime {
        // quick, permissive parser
        var i: usize = 0;
        const len = s.len;

        // parse 4-digit year (allow negative years? here we require >= 0)
        if (len < 4) return DateError.BadFormat;
        const year = parse.parseIntDigits(s, &i, 4) catch return DateError.BadFormat;

        if (!parse.expect(s, i, '-')) return DateError.BadFormat;
        i += 1;
        const month = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;
        if (!parse.expect(s, i, '-')) return DateError.BadFormat;
        i += 1;
        const day = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;

        if (!parse.expect(s, i, 'T') and !parse.expect(s, i, 't') and !parse.expect(s, i, ' ')) {
            // allow just date (YYYY-MM-DD) -> midnight UTC
            // but RFC3339 requires time; being permissive: accept date-only
            const dt = try DateTime.fromComponents(@intCast(year), @intCast(month), @intCast(day), null, null, null, 0);
            return dt;
        }
        // skip separator
        i += 1;

        const hour = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;
        if (!parse.expect(s, i, ':')) return DateError.BadFormat;
        i += 1;
        const minute = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;

        var second: i32 = 0;
        if (parse.expect(s, i, ':')) {
            i += 1;
            second = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;
        }

        // optional fractional seconds: skip them
        if (i < len and s[i] == '.') {
            // skip '.' then digits
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
                const oh = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;
                if (!parse.expect(s, i, ':')) return DateError.BadFormat;
                i += 1;
                const om = parse.parseIntDigits(s, &i, 2) catch return DateError.BadFormat;
                offset_seconds = @as(i32, sign * (@as(i32, oh) * 3600 + @as(i32, om) * 60));
            } else {
                return DateError.BadFormat;
            }
        }

        // Now convert local date/time with offset -> unix UTC seconds
        const y_i = @as(i32, year);
        const m_i = @as(i32, month);
        const d_i = @as(i32, day);
        const h_i = @as(i32, hour);
        const min_i = @as(i32, minute);
        const sec_i = @as(i32, second);

        const days = CivilDate.days_from_civil(y_i, m_i, d_i);
        const local_secs: i64 = days * 86400 + @as(i64, h_i * 3600 + min_i * 60 + sec_i);
        const utc_secs: i64 = local_secs - @as(i64, offset_seconds);

        return DateTime{ .unix_secs = utc_secs, .offset_seconds = offset_seconds };
    }

    /// Format this DateTime into RFC3339 string using its offset.
    /// Allocates the returned string using given allocator.
    pub fn formatRfc3339(self: DateTime, allocator: std.mem.Allocator) ![]u8 {
        // convert utc seconds -> local seconds by adding offset
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        const days = @divFloor(local_secs, 86400);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @divFloor(rem, 3600));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @divFloor(rem, 60));
        const second = @as(u8, @mod(rem, 60));

        const result = CivilDate.from_days(days);
        const y = result.year;
        const m = result.month;
        const d = result.day;

        // compose timezone suffix
        var tz_buf: [6]u8 = undefined; // "Z" or "+HH:MM"
        var tz_slice: []const u8 = undefined;
        if (self.offset_seconds == 0) {
            tz_buf[0] = 'Z';
            tz_slice = tz_buf[0..1];
        } else {
            const sign = if (self.offset_seconds >= 0) '+' else '-';
            const off_abs = if (self.offset_seconds >= 0) self.offset_seconds else -self.offset_seconds;
            const off_h = @divFloor(off_abs, 3600);
            const off_m = @mod(off_abs, 3600) / 60;
            // format into tz_buf
            tz_buf[0] = @as(u8, sign);
            tz_buf[1] = parse.charDigit(@divFloor(off_h, 10));
            tz_buf[2] = parse.charDigit(@mod(off_h, 10));
            tz_buf[3] = ':';
            tz_buf[4] = parse.charDigit(@divFloor(off_m, 10));
            tz_buf[5] = parse.charDigit(@mod(off_m, 10));
            tz_slice = tz_buf[0..6];
        }

        // allocate a buffer with exact needed length: "YYYY-MM-DDTHH:MM:SS" + tz
        // 19 chars for base + tz.len
        const base_len = 19;
        const tz_len = tz_slice.len;
        const total = base_len + tz_len;
        var out = try allocator.alloc(u8, total);
        // write into out
        var idx: usize = 0;
        // YYYY-
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
        std.mem.copy(u8, out[idx..], tz_slice);
        return out;
    }

    /// Return "YYYY-MM-DD" by allocating a small string
    pub fn formatDate(self: DateTime, allocator: std.mem.Allocator) ![]u8 {
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        const days = @divFloor(local_secs, 86400);
        const result = CivilDate.from_days(days);
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
    pub fn toCivilDate(self: DateTime) CivilDate {
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        const days = @divFloor(local_secs, 86400);
        return CivilDate.from_days(days);
    }

    /// Calculates the duration between two DateTime instances.
    pub fn diff(self: DateTime, other: DateTime) Duration {
        return Duration.fromSeconds(self.unix_secs - other.unix_secs);
    }

    /// Adds a duration to this DateTime instance, returning a new DateTime.
    pub fn add(self: DateTime, d: Duration) DateTime {
        return DateTime.fromUnix(self.unix_secs + d.seconds, self.offset_seconds);
    }

    /// Subtracts a duration from this DateTime instance, returning a new DateTime.
    pub fn sub(self: DateTime, d: Duration) DateTime {
        return DateTime.fromUnix(self.unix_secs - d.seconds, self.offset_seconds);
    }

    /// Adds a specified number of days to the DateTime.
    pub fn addDays(self: DateTime, days: i64) DateTime {
        return self.add(Duration.fromSeconds(days * 86400));
    }

    /// Subtracts a specified number of days from the DateTime.
    pub fn subDays(self: DateTime, days: i64) DateTime {
        return self.sub(Duration.fromSeconds(days * 86400));
    }

    /// Adds a specified number of weeks to the DateTime.
    pub fn addWeeks(self: DateTime, weeks: i64) DateTime {
        return self.add(Duration.fromSeconds(weeks * 7 * 86400));
    }

    /// Subtracts a specified number of weeks from the DateTime.
    pub fn subWeeks(self: DateTime, weeks: i64) DateTime {
        return self.sub(Duration.fromSeconds(weeks * 7 * 86400));
    }

    /// Adds a specified number of months to the DateTime. Handles day clamping (e.g., adding 1 month to Jan 31st results in Feb 28th/29th).
    pub fn addMonths(self: DateTime, months: i64) !DateTime {
        const cd = self.toCivilDate();
        const total_months = @as(i64, cd.year) * 12 + @as(i64, cd.month - 1) + months;
        const new_year: i64 = @divFloor(total_months, 12);
        const new_month: u8 = @intCast(@mod(total_months, 12) + 1);

        var new_day: i32 = cd.day;
        const days_in_new_month: i32 = @intCast(epoch.getDaysInMonth(@intCast(new_year), @enumFromInt(new_month)));
        if (new_day > days_in_new_month) {
            new_day = days_in_new_month;
        }

        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @intCast(@divFloor(rem, 3600)));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @intCast(@divFloor(rem, 60)));
        const second = @as(u8, @intCast(@mod(rem, 60)));

        return DateTime.fromComponents(@intCast(new_year), new_month, @intCast(new_day), hour, minute, second, self.offset_seconds);
    }

    /// Subtracts a specified number of months from the DateTime. Delegates to addMonths with a negative value.
    pub fn subMonths(self: DateTime, months: i64) !DateTime {
        return self.addMonths(-months);
    }

    /// Adds a specified number of years to the DateTime. Handles leap year day clamping (e.g., adding 1 year to Feb 29th in a non-leap year results in Feb 28th).
    pub fn addYears(self: DateTime, years: i64) !DateTime {
        const cd = self.toCivilDate();
        const new_year: i64 = @as(i64, cd.year) + years;
        var new_day = cd.day;

        if (cd.month == 2 and cd.day == 29 and !epoch.isLeapYear(@intCast(new_year))) {
            new_day = 28;
        }

        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @intCast(@divFloor(rem, 3600)));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @intCast(@divFloor(rem, 60)));
        const second = @as(u8, @intCast(@mod(rem, 60)));

        return DateTime.fromComponents(@intCast(new_year), @intCast(cd.month), @intCast(new_day), hour, minute, second, self.offset_seconds);
    }

    /// Subtracts a specified number of years from the DateTime. Delegates to addYears with a negative value.
    pub fn subYears(self: DateTime, years: i64) !DateTime {
        return self.addYears(-years);
    }

    /// Returns the day of the week for this DateTime.
    pub fn dayOfWeek(self: DateTime) time_units.DayOfWeek {
        const days = @divFloor(self.unix_secs, 86400);
        const dow = @mod(days + 4, 7);
        return @enumFromInt(@as(u3, @intCast(dow)));
    }

    /// Returns true if the DateTime falls on a weekday (Monday-Friday).
    pub fn isWeekday(self: DateTime) bool {
        return switch (self.dayOfWeek()) {
            .saturday, .sunday => false,
            else => true,
        };
    }

    /// Returns true if the DateTime falls on a weekend (Saturday or Sunday).
    pub fn isWeekend(self: DateTime) bool {
        return !self.isWeekday();
    }

    /// Adds a specified number of business days (Monday-Friday) to the DateTime. Skips weekends.
    pub fn addBusinessDays(self: DateTime, days: i64) DateTime {
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

    /// Returns the day of the year (1-366) for this DateTime.
    pub fn dayOfYear(self: DateTime) u16 {
        const cd = self.toCivilDate();
        const first_day_of_year = CivilDate.days_from_civil(cd.year, 1, 1);
        const this_day = CivilDate.days_from_civil(cd.year, cd.month, cd.day);
        return @intCast(this_day - first_day_of_year + 1);
    }

    /// Returns the ISO week date (year and week number) for this DateTime.
    pub fn isoWeek(self: DateTime) !struct { year: i32, week: u8 } {
        const dow = self.dayOfWeek(); // sunday=0
        const iso_dow = if (dow == .sunday) 7 else @intFromEnum(dow);

        // Thursday of the current week
        const thursday = self.addDays(4 - @as(i64, iso_dow));
        const th_cd = thursday.toCivilDate();
        const iso_year = th_cd.year;

        const first_day_of_iso_year = try DateTime.fromComponents(iso_year, 1, 4, 0, 0, 0, 0);
        const first_thursday_dow = first_day_of_iso_year.dayOfWeek();
        const first_thursday_iso_dow = if (first_thursday_dow == .sunday) 7 else @intFromEnum(first_thursday_dow);

        // Monday of week 1
        const week1_monday = first_day_of_iso_year.subDays(@as(i64, first_thursday_iso_dow) - 1);

        const diff_secs = thursday.unix_secs - week1_monday.unix_secs;
        const diff_days = @divFloor(diff_secs, 86400);
        const week_num = @divFloor(diff_days, 7) + 1;

        return .{ .year = iso_year, .week = @intCast(week_num) };
    }

    /// Truncates the DateTime to the beginning of the specified TimeUnit.
    pub fn truncate(self: DateTime, unit: time_units.TimeUnit) !DateTime {
        const cd = self.toCivilDate();
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @intCast(@divFloor(rem, 3600)));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @intCast(@divFloor(rem, 60)));
        const second = @as(u8, @intCast(@mod(rem, 60)));

        return switch (unit) {
            .year => DateTime.fromComponents(cd.year, 1, 1, 0, 0, 0, self.offset_seconds),
            .month => DateTime.fromComponents(cd.year, @intCast(cd.month), 1, 0, 0, 0, self.offset_seconds),
            .day => DateTime.fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), 0, 0, 0, self.offset_seconds),
            .hour => DateTime.fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, 0, 0, self.offset_seconds),
            .minute => DateTime.fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, minute, 0, self.offset_seconds),
            .second => DateTime.fromComponents(cd.year, @intCast(cd.month), @intCast(cd.day), hour, minute, second, self.offset_seconds),
        };
    }

    /// Rounds the DateTime to the nearest specified TimeUnit. Rounds up for half or more.
    pub fn round(self: DateTime, unit: time_units.TimeUnit) !DateTime {
        const cd = self.toCivilDate();
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @intCast(@divFloor(rem, 3600)));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @intCast(@divFloor(rem, 60)));
        const second = @as(u8, @intCast(@mod(rem, 60)));

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
                // This implementation has second precision, so rounding to second is a no-op on truncation
                return self.truncate(.second);
            },
        }
    }

    /// Formats the DateTime according to the provided format string.
    /// Recognizes common format specifiers like %Y, %m, %d, %H, %M, %S, %B, %b, %A, %a.
    pub fn strftime(self: DateTime, allocator: std.mem.Allocator, fmt_str: []const u8) ![]u8 {
        var result = try std.ArrayList(u8).initCapacity(allocator, 0);
        const writer = result.writer(allocator);
        const cd = self.toCivilDate();
        const local_secs = self.unix_secs + @as(i64, self.offset_seconds);
        var rem = @mod(local_secs, 86400);
        if (rem < 0) {
            rem += 86400;
        }
        const hour = @as(u8, @intCast(@divFloor(rem, 3600)));
        rem = @mod(rem, 3600);
        const minute = @as(u8, @intCast(@divFloor(rem, 60)));
        const second = @as(u8, @intCast(@mod(rem, 60)));

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
                        try std.fmt.format(writer, "{d:04}", .{year});
                    },
                    'm' => {
                        const month: u32 = @intCast(cd.month);
                        try std.fmt.format(writer, "{d:02}", .{month});
                    },
                    'd' => {
                        const day: u32 = @intCast(cd.day);
                        try std.fmt.format(writer, "{d:02}", .{day});
                    },
                    'H' => try std.fmt.format(writer, "{d:02}", .{hour}),
                    'M' => try std.fmt.format(writer, "{d:02}", .{minute}),
                    'S' => try std.fmt.format(writer, "{d:02}", .{second}),
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
        return result.toOwnedSlice(allocator);
    }

    /// Returns a human-readable string representing the time difference between this DateTime and a given 'now' DateTime.
    pub fn humanize(self: DateTime, now: DateTime, allocator: std.mem.Allocator) ![]u8 {
        const diff_secs = self.unix_secs - now.unix_secs;

        if (diff_secs >= 0) { // future or now
            return humanize_mod.humanize_future(diff_secs, allocator);
        } else { // past
            return humanize_mod.humanize_past(-diff_secs, allocator);
        }
    }

    /// Converts this DateTime to a different timezone specified by `tz_name`.
    pub fn toTimezone(self: DateTime, allocator: std.mem.Allocator, tz_name: []const u8) !DateTime {
        // TODO: Linux-only
        const tz_path = try std.fmt.allocPrint(allocator, "/usr/share/zoneinfo/{s}", .{tz_name});
        defer allocator.free(tz_path);

        const file = try std.fs.cwd().openFile(tz_path, .{});
        defer file.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = try file.readAll(&buffer);
        var stream = std.io.fixedBufferStream(buffer[0..bytes_read]);
        var tz_data = try std.tz.Tz.parse(allocator, stream.reader());
        defer tz_data.deinit();

        const timetype = try tz_helpers.findTimetype(&tz_data, self.unix_secs);
        return DateTime.fromUnix(self.unix_secs, timetype.offset);
    }
};
