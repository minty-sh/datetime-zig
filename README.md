# datetime-zig

A lightweight and thoroughly tested datetime library written in Zig, whose dependency is *just* the Zig standard library.

## Table of Contents

- [Examples](#examples)
  - [Display the current datetime in UTC](#display-the-current-datetime-in-utc)
  - [Working with civil dates](#working-with-civil-dates)
  - [Adding durations to a datetime](#adding-durations-to-a-datetime)
- [Install](#install)
  - [zig fetch](#zig-fetch)
  - [In build.zig](#in-buildzig)
- [License](#license)

## Examples

### Display the current datetime in UTC

```zig
const std = @import("std");
const datetime = @import("datetime");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const now_unix_secs = std.time.timestamp();
    const now_utc = datetime.DateTime.fromEpoch(now_unix_secs);
    const now_utc_str = try now_utc.strftime(allocator, "%Y-%m-%d %H:%M:%S");
    defer allocator.free(now_utc_str);
    std.debug.print("Current UTC Datetime: {s}\n", .{now_utc_str});
}
```

### Working with civil dates

```zig
const std = @import("std");
const datetime = @import("datetime");

pub fn main() !void {
    // Create a specific civil date
    const civil_date = datetime.CivilDate{ .year = 2023, .month = 10, .day = 27 };
    std.debug.print("Civil Date: {d}-{d}-{d}\n", .{civil_date.year, civil_date.month, civil_date.day});
}
```

### Adding durations to a datetime

```zig
const std = @import("std");
const datetime = @import("datetime");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Get the current UTC datetime
    const now_unix_secs = std.time.timestamp();
    const now_utc = datetime.DateTime.fromEpoch(now_unix_secs);

    // Add a duration
    const duration = datetime.Duration.fromSeconds(3600); // 1 hour
    const future_datetime = now_utc.add(duration);
    const future_datetime_str = try future_datetime.strftime(allocator, "%Y-%m-%d %H:%M:%S");
    defer allocator.free(future_datetime_str);
    std.debug.print("Datetime in 1 hour: {s}\n", .{future_datetime_str});
}
```

## Install

You can download the library with:

### zig fetch

```bash
zig fetch --save git+https://github.com/minty-sh/datetime-zig
```

### In build.zig

In your `build.zig`, add the following to your `build` function:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const datetime_dep = b.dependency("datetime", .{
        .target = target,
    });

    const exe = b.addExecutable(.{
        .name = "your_project_name",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "datetime", .module = datetime_dep.module("datetime") },
        },
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&b.addRunArtifact(exe).step);
}
```

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
