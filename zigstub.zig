const std = @import("std");
const fxcg = @import("fxcg_c.zig");

const logbuf = @import("logbuf.zig");

const program = @import("src/main.zig");

const logger = &logbuf.logger;

pub const std_options = .{
    .logFn = logbuf.stdLogFn,
};

pub export fn main() void {
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    try logger.print("Starting AddIn...\n", .{});
    _=try logger.puts("Beep Boop...\n");
    logbuf.display_log();
    
    // Call main
    const result = program.main();
    // Error handling
    _ = result catch |err|{
        logger.next_line();
        logger.set_line_format(.{.colour = fxcg.display.TEXT_COLOR_RED});
        try logger.print("main() returned err:\n{s}", .{@errorName(err)});
        // TODO: Error return trace?
    };
    
    logger.next_line();
    logger.set_line_format(.{});
    _=try logger.puts("main() has exited.\nPress MENU to exit.\nUse \xe5\xea/\xe5\xeb to scroll.\n");
    logbuf.display_log();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    logger.next_line();
    logger.set_line_format(.{ .colour = fxcg.display.TEXT_COLOR_RED });
    logger.print("Panic: {s}\n", .{msg}) catch {};
    logbuf.display_log(); _ = error_return_trace;
    while (true) {
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
    }
}