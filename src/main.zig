const std = @import("std");

pub fn main() !void {
    _ = try std.heap.c_allocator.alloc(u128, 2000000);
    return error.TestErrorThatIsVeryVeryVeryVeryLong;
}