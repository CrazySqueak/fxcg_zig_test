const std = @import("std");

const fxcg = @import("root").modules.fxcg;
const cgutil = @import("root").modules.cgutil;

pub fn main() !void {
    std.log.debug("This is a debug message: {d}", .{1});
    std.log.info("This is an info message: {d}", .{2});
    std.log.warn("This is a warning message: {d}", .{3});
    std.log.err("This is an error message: {d}", .{4});
    
    _=try cgutil.rtc.date.get_date_sane();
    
    std.log.scoped(.beep).info("Hello from beep.", .{});
    return error.TestErrorThatIsVeryVeryVeryVeryLong;
}