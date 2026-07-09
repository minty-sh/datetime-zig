const std = @import("std");

pub fn humanizeFuture(seconds: i64, allocator: std.mem.Allocator) ![]u8 {
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

pub fn humanizePast(seconds: i64, allocator: std.mem.Allocator) ![]u8 {
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

test "humanize functions" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const cases = [_]struct {
        seconds: i64,
        future: []const u8,
        past: []const u8,
    }{
        .{ .seconds = 1, .future = "in 1 second", .past = "1 second ago" },
        .{ .seconds = 59, .future = "in 59 seconds", .past = "59 seconds ago" },
        .{ .seconds = 60, .future = "in 1 minute", .past = "1 minute ago" },
        .{ .seconds = 60 * 59, .future = "in 59 minutes", .past = "59 minutes ago" },
        .{ .seconds = 60 * 60, .future = "in 1 hour", .past = "1 hour ago" },
        .{ .seconds = 60 * 60 * 23, .future = "in 23 hours", .past = "23 hours ago" },
        .{ .seconds = 60 * 60 * 24, .future = "in 1 day", .past = "1 day ago" },
        .{ .seconds = 60 * 60 * 24 * 29, .future = "in 29 days", .past = "29 days ago" },
        .{ .seconds = 60 * 60 * 24 * 30, .future = "in 1 month", .past = "1 month ago" },
        .{ .seconds = 60 * 60 * 24 * 30 * 11, .future = "in 11 months", .past = "11 months ago" },
        .{ .seconds = 60 * 60 * 24 * 30 * 12, .future = "in 1 year", .past = "1 year ago" },
        .{ .seconds = 60 * 60 * 24 * 30 * 12 * 2, .future = "in 2 years", .past = "2 years ago" },
    };

    for (cases) |c| {
        const f = try humanizeFuture(c.seconds, allocator);
        defer allocator.free(f);
        try testing.expectEqualStrings(c.future, f);

        const p = try humanizePast(c.seconds, allocator);
        defer allocator.free(p);
        try testing.expectEqualStrings(c.past, p);
    }
}
