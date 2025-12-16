const std = @import("std");

pub fn humanize_future(seconds: i64, allocator: std.mem.Allocator) ![]u8 {
    if (seconds < 60) {
        if (seconds == 1) return std.fmt.allocPrint(allocator, "in 1 second", .{});
        return std.fmt.allocPrint(allocator, "in {d} seconds", .{seconds});
    }

    const minutes = @divFloor(seconds, 60);
    if (minutes < 60) {
        if (minutes == 1) return std.fmt.allocPrint(allocator, "in 1 minute", .{});
        return std.fmt.allocPrint(allocator, "in {d} minutes", .{minutes});
    }

    const hours = @divFloor(minutes, 60);
    if (hours < 24) {
        if (hours == 1) return std.fmt.allocPrint(allocator, "in 1 hour", .{});
        return std.fmt.allocPrint(allocator, "in {d} hours", .{hours});
    }

    const days = @divFloor(hours, 24);
    if (days < 30) {
        if (days == 1) return std.fmt.allocPrint(allocator, "in 1 day", .{});
        return std.fmt.allocPrint(allocator, "in {d} days", .{days});
    }

    const months = @divFloor(days, 30);
    if (months < 12) {
        if (months == 1) return std.fmt.allocPrint(allocator, "in 1 month", .{});
        return std.fmt.allocPrint(allocator, "in {d} months", .{months});
    }

    const years = @divFloor(months, 12);
    if (years == 1) return std.fmt.allocPrint(allocator, "in 1 year", .{});

    return std.fmt.allocPrint(allocator, "in {d} years", .{years});
}

pub fn humanize_past(seconds: i64, allocator: std.mem.Allocator) ![]u8 {
    if (seconds < 60) {
        if (seconds == 1) return std.fmt.allocPrint(allocator, "1 second ago", .{});
        return std.fmt.allocPrint(allocator, "{d} seconds ago", .{seconds});
    }

    const minutes = @divFloor(seconds, 60);
    if (minutes < 60) {
        if (minutes == 1) return std.fmt.allocPrint(allocator, "1 minute ago", .{});
        return std.fmt.allocPrint(allocator, "{d} minutes ago", .{minutes});
    }

    const hours = @divFloor(minutes, 60);
    if (hours < 24) {
        if (hours == 1) return std.fmt.allocPrint(allocator, "1 hour ago", .{});
        return std.fmt.allocPrint(allocator, "{d} hours ago", .{hours});
    }

    const days = @divFloor(hours, 24);
    if (days < 30) {
        if (days == 1) return std.fmt.allocPrint(allocator, "1 day ago", .{});
        return std.fmt.allocPrint(allocator, "{d} days ago", .{days});
    }

    const months = @divFloor(days, 30);
    if (months < 12) {
        if (months == 1) return std.fmt.allocPrint(allocator, "1 month ago", .{});
        return std.fmt.allocPrint(allocator, "{d} months ago", .{months});
    }

    const years = @divFloor(months, 12);
    if (years == 1) return std.fmt.allocPrint(allocator, "1 year ago", .{});

    return std.fmt.allocPrint(allocator, "{d} years ago", .{years});
}
