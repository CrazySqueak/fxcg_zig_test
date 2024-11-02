const std = @import("std");

pub const modules = struct {
    pub const fxcg_c = @import("fxcg_c.zig");
    pub const cgutil = @import("cgutil/cgutil.zig");
    
    pub const logbuf = @import("logbuf.zig");
    
    pub const program_root = @import("src/main.zig");
};
const fxcg = modules.fxcg_c;
const cgutil = modules.cgutil;
const logbuf = modules.logbuf;

const program = modules.program_root;

const logger = &logbuf.logger;

pub const std_options = .{
    .logFn = logbuf.stdLogFn,
};

pub export fn main() c_int {
    // Setup logger
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    logger.print("Starting AddIn...\n", .{});
    _=logger.puts("Beep Boop...\n");
    logbuf.display_log();
    
    // Set quit handler
    fxcg.system.SetQuitHandler(quit_handler);
    
    {
        // Set up bfile
        cgutil.bfile.__init_bfile() catch @panic("Unable to allocate???");
        defer switch (cgutil.bfile.__deinit_bfile()) {
            .ok => {},  // ok
            .leaked => std.log.warn("File handles leaked after main() exited!", .{}),
        };
        
        // Call main
        const result = program.main();
        // Error handling
        _ = result catch |err|{
            logger.next_line();
            logger.set_line_format(.{.colour = fxcg.display.TEXT_COLOR_RED});
            logger.print("main() returned err:\n{s}", .{@errorName(err)});
            // TODO: Error return trace?
        };
    }
    
    logger.next_line();
    logger.set_line_format(.{});
    _=logger.puts("main() has exited.\nPress MENU to exit.\nUse \xe5\xea/\xe5\xeb to scroll.\n");
    
    halt();
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    logger.next_line();
    logger.set_line_format(.{ .colour = fxcg.display.TEXT_COLOR_RED });
    logger.print("Panic: {s}\n", .{msg});
    logbuf.display_log();
    
    halt();
}

pub fn halt() noreturn {
    while (true){
        logbuf.display_log();
        // Force-open the menu if they choose to EXIT the log.
        // (if they re-enter the addIn it will display the log again)
        cgutil.ui.openMainMenu();
    }
}

pub fn quit_handler() callconv(.C) void {
    // Ensure Bfile handles are cleaned up
    _=cgutil.bfile.__deinit_bfile();
    // All good.
}