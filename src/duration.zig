/// Represents a duration in seconds.
pub const Duration = struct {
    seconds: i64,

    /// Creates a Duration instance from a given number of seconds.
    pub fn fromSeconds(s: i64) Duration {
        return .{ .seconds = s };
    }
};