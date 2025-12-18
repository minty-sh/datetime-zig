const std = @import("std");
const DateTime = @import("DateTime.zig");


pub fn findTimetype(tz: *const std.tz.Tz, unix_secs: i64) !*const std.tz.Timetype {
    if (tz.transitions.len == 0) {
        if (tz.timetypes.len > 0) return &tz.timetypes[0];
        return DateTime.Error.NoTimetypeFound;
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
        return DateTime.Error.NoTimetypeFound;
    }

    return tz.transitions[index - 1].timetype;
}

pub fn transitionCompare(context: i64, item: std.tz.Transition) std.math.Order {
    return std.math.order(context, item.ts);
}



test "transitionCompare" {
    const testing = std.testing;
    const Transition = std.tz.Transition;
    const Order = std.math.Order;

    const transition1 = Transition{ .ts = 100, .timetype = undefined };
    const transition2 = Transition{ .ts = 200, .timetype = undefined };

    try testing.expectEqual(Order.lt, transitionCompare(50, transition1));
    try testing.expectEqual(Order.eq, transitionCompare(100, transition1));
    try testing.expectEqual(Order.gt, transitionCompare(150, transition1));

    try testing.expectEqual(Order.lt, transitionCompare(150, transition2));
    try testing.expectEqual(Order.eq, transitionCompare(200, transition2));
    try testing.expectEqual(Order.gt, transitionCompare(250, transition2));
}
