pub const month_names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
pub const month_abbrs = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
pub const day_names = [_][]const u8{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
pub const day_abbrs = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };

const std = @import("std");

test "constants integrity" {
    const testing = std.testing;

    try testing.expect(month_names.len == 12);
    try testing.expect(month_abbrs.len == 12);
    try testing.expect(day_names.len == 7);
    try testing.expect(day_abbrs.len == 7);
}
