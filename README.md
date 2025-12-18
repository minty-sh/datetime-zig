# datetime-zig

A lightweight and thoroughly tested datetime library written in Zig, whose dependency is *just* the Zig standard library.

## Example

```zig
const std = @import("std");
const datetime = @import("datetime");
const CivilDate = datetime.CivilDate;
const Duration = datetime.Duration;

pub fn main() !void {
    const allocator = std.heap.page_allocator; // Or another appropriate allocator

    // Get the current UTC datetime
    var now_unix_secs = std.time.timestamp();
    var now_utc = datetime.DateTime.fromUnixEpoch(now_unix_secs);
    const now_utc_str = try now_utc.strftime(allocator, "%Y-%m-%d %H:%M:%S");
    defer allocator.free(now_utc_str);
    std.debug.print("Current UTC Datetime: {s}\n", .{now_utc_str});

    // Create a specific civil date
    var civil_date = CivilDate{ .year = 2023, .month = 10, .day = 27 };
    std.debug.print("Civil Date: {d}-{d}-{d}\n", .{civil_date.year, civil_date.month, civil_date.day});

    // Add a duration
    var duration = Duration.fromSeconds(3600); // 1 hour
    var future_datetime = now_utc.add(duration);
    const future_datetime_str = try future_datetime.strftime(allocator, "%Y-%m-%d %H:%M:%S");
    defer allocator.free(future_datetime_str);
    std.debug.print("Datetime in 1 hour: {s}\n", .{future_datetime_str});
}
```

## Install

You can download the library with:

`zig fetch --save git+https://github.com/minty-sh/datetime-zig`

### In `build.zig`

In your `build.zig`, add the following to your `build` function:

```zig
    const datetime_dep = b.dependency("datetime-zig", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addModule("datetime", datetime_dep.module("datetime"));
```

## License

MIT
