pub const month_names = [_][]const u8{ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" };
pub const month_abbrs = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
pub const day_names = [_][]const u8{ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" };
pub const day_abbrs = [_][]const u8{ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" };

test "constants integrity" {
    _ = @import("std").testing;

    // Check month constants
    _ = @import("std").debug.assert(month_names.len == 12);
    _ = @import("std").debug.assert(month_abbrs.len == 12);

    // Check day constants
    _ = @import("std").debug.assert(day_names.len == 7);
    _ = @import("std").debug.assert(day_abbrs.len == 7);
}
