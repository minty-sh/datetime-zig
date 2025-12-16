const std = @import("std");
const DateError = @import("datetime.zig").DateError;

pub fn findTimetype(tz: *const std.tz.Tz, unix_secs: i64) !*const std.tz.Timetype {
    if (tz.transitions.len == 0) {
        if (tz.timetypes.len > 0) return &tz.timetypes[0];
        return DateError.NoTimetypeFound;
    }

    const index = std.sort.upperBound(std.tz.Transition, tz.transitions, unix_secs, transitionCompare);

    if (index == 0) {
        // before first transition, find default non-DST timetype
        for (tz.timetypes) |*tt| {
            if (!tt.isDst()) {
                return tt;
            }
        }
        // fallback to first if no non-dst found
        if (tz.timetypes.len > 0) return &tz.timetypes[0];
        return DateError.NoTimetypeFound;
    }

    return tz.transitions[index - 1].timetype;
}

pub fn transitionCompare(context: i64, item: std.tz.Transition) std.math.Order {
    return std.math.order(context, item.ts);
}

pub const NoTimetypeFound = error{};