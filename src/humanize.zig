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

test "humanize functions" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Test humanize_future
    const s1 = try humanize_future(1, allocator);
    defer allocator.free(s1);
    try testing.expectEqualStrings("in 1 second", s1);

    const s59 = try humanize_future(59, allocator);
    defer allocator.free(s59);
    try testing.expectEqualStrings("in 59 seconds", s59);

    const m1 = try humanize_future(60, allocator);
    defer allocator.free(m1);
    try testing.expectEqualStrings("in 1 minute", m1);

    const m59 = try humanize_future(60 * 59, allocator);
    defer allocator.free(m59);
    try testing.expectEqualStrings("in 59 minutes", m59);

    const h1 = try humanize_future(60 * 60, allocator);
    defer allocator.free(h1);
    try testing.expectEqualStrings("in 1 hour", h1);

    const h23 = try humanize_future(60 * 60 * 23, allocator);
    defer allocator.free(h23);
    try testing.expectEqualStrings("in 23 hours", h23);

    const d1 = try humanize_future(60 * 60 * 24, allocator);
    defer allocator.free(d1);
    try testing.expectEqualStrings("in 1 day", d1);

    const d29 = try humanize_future(60 * 60 * 24 * 29, allocator);
    defer allocator.free(d29);
    try testing.expectEqualStrings("in 29 days", d29);

    const mo1 = try humanize_future(60 * 60 * 24 * 30, allocator);
    defer allocator.free(mo1);
    try testing.expectEqualStrings("in 1 month", mo1);

    const mo11 = try humanize_future(60 * 60 * 24 * 30 * 11, allocator);
    defer allocator.free(mo11);
    try testing.expectEqualStrings("in 11 months", mo11);

    const y1 = try humanize_future(60 * 60 * 24 * 30 * 12, allocator);
    defer allocator.free(y1);
    try testing.expectEqualStrings("in 1 year", y1);

    const y2 = try humanize_future(60 * 60 * 24 * 30 * 12 * 2, allocator);
    defer allocator.free(y2);
    try testing.expectEqualStrings("in 2 years", y2);

    // Test humanize_past
    const s1_past = try humanize_past(1, allocator);
    defer allocator.free(s1_past);
    try testing.expectEqualStrings("1 second ago", s1_past);

    const s59_past = try humanize_past(59, allocator);
    defer allocator.free(s59_past);
    try testing.expectEqualStrings("59 seconds ago", s59_past);

    const m1_past = try humanize_past(60, allocator);
    defer allocator.free(m1_past);
    try testing.expectEqualStrings("1 minute ago", m1_past);

    const m59_past = try humanize_past(60 * 59, allocator);
    defer allocator.free(m59_past);
    try testing.expectEqualStrings("59 minutes ago", m59_past);

    const h1_past = try humanize_past(60 * 60, allocator);
    defer allocator.free(h1_past);
    try testing.expectEqualStrings("1 hour ago", h1_past);

    const h23_past = try humanize_past(60 * 60 * 23, allocator);
    defer allocator.free(h23_past);
    try testing.expectEqualStrings("23 hours ago", h23_past);

    const d1_past = try humanize_past(60 * 60 * 24, allocator);
    defer allocator.free(d1_past);
    try testing.expectEqualStrings("1 day ago", d1_past);

    const d29_past = try humanize_past(60 * 60 * 24 * 29, allocator);
    defer allocator.free(d29_past);
    try testing.expectEqualStrings("29 days ago", d29_past);

    const mo1_past = try humanize_past(60 * 60 * 24 * 30, allocator);
    defer allocator.free(mo1_past);
    try testing.expectEqualStrings("1 month ago", mo1_past);

    const mo11_past = try humanize_past(60 * 60 * 24 * 30 * 11, allocator);
    defer allocator.free(mo11_past);
    try testing.expectEqualStrings("11 months ago", mo11_past);

    const y1_past = try humanize_past(60 * 60 * 24 * 30 * 12, allocator);
    defer allocator.free(y1_past);
    try testing.expectEqualStrings("1 year ago", y1_past);

    const y2_past = try humanize_past(60 * 60 * 24 * 30 * 12 * 2, allocator);
    defer allocator.free(y2_past);
    try testing.expectEqualStrings("2 years ago", y2_past);
}
