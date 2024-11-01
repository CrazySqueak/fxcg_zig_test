const std = @import("std");

pub const modules = struct {
    pub const fxcg_c = @import("fxcg_c.zig");
    pub const logbuf = @import("logbuf.zig");
    
    pub const program_root = @import("src/main.zig");
};
const fxcg = modules.fxcg_c;
const logbuf = modules.logbuf;

const program = modules.program_root;

const logger = &logbuf.logger;

pub const std_options = .{
    .logFn = logbuf.stdLogFn,
};

pub export fn main() void {
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    logger.print("Starting AddIn...\n", .{});
    _=logger.puts("Beep Boop...\n");
    logbuf.display_log();
    
    // Call main
    const result = program.main();
    // Error handling
    _ = result catch |err|{
        logger.next_line();
        logger.set_line_format(.{.colour = fxcg.display.TEXT_COLOR_RED});
        logger.print("main() returned err:\n{s}", .{@errorName(err)});
        // TODO: Error return trace?
    };
    
    logger.next_line();
    logger.set_line_format(.{});
    _=logger.puts("main() has exited.\nPress MENU to exit.\nUse \xe5\xea/\xe5\xeb to scroll.\n");
    logbuf.display_log();
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    logger.next_line();
    logger.set_line_format(.{ .colour = fxcg.display.TEXT_COLOR_RED });
    logger.print("Panic: {s}\n", .{msg});
    logbuf.display_log();
    while (true) {
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
    }
}