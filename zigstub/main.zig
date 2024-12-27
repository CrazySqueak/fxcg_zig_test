const std = @import("std");

pub const logbuf = @import("logbuf.zig");

const fxcg = @import("fxcg_c");
const cgutil = @import("cgutil");
const program = @import("main");

const logger = &logbuf.logger;

pub const std_options: std.Options = .{
    .logFn = logbuf.stdLogFn,
};

pub export fn main() c_int {
    // Setup logger
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    logger.print("Starting AddIn...\n", .{});
    
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

/// Used to track if we're stuck in a panic-loop
/// 1st panic = normal, 2nd panic = display then restart, 3rd panic = immediate reboot
var panicking_count: u8 = 0;
pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, first_addr: ?usize) noreturn {
    panicking_count += 1;
    if (panicking_count >= 3) fxcg.system.Restart();
    
    logger.next_line();
    logger.set_line_format(.{ .colour = fxcg.display.TEXT_COLOR_RED });
    if (first_addr) |f_addr| logger.print("Panic at {x}:\n {s}\n", .{f_addr, msg})
    else logger.print("Panic: {s}\n", .{msg});
    
    if (panicking_count >= 2) { _=logger.puts("Double-panic!\n   [EXIT]: Restart   \n"); logbuf.display_log(); fxcg.system.Restart(); }
    
    halt();
}

pub fn halt() noreturn {
    // Display log on loop
    while (true){
        logbuf.display_log();
        // Force-open the menu if they choose to EXIT the log.
        // (if they re-enter the addIn it will display the log again)
        cgutil.ui.openMainMenu();
    }
}

pub export fn quit_handler() void {
    if (panicking_count < 1) panicking_count = 1;  // panicking in a quit handler causes major issues.
    const log_scope = std.log.scoped(.root_quit_h);
    // Allow application to define a quit handler
    // N.B. quit handlers are not reentrant - you cannot stop the user from leaving (additionally, panicking in a quit handler will cause a fuckton of issues)
    if (@hasDecl(program, "quit_handler")) {
        log_scope.debug("Calling program quit handler...",.{});
        defer log_scope.debug("Program quit handler finished.",.{});
        @field(program, "quit_handler")();
    }
    
    // Ensure Bfile handles are cleaned up
    log_scope.debug("Closing Bfile handles...",.{});
    const bfresult = cgutil.bfile.__deinit_bfile();
    log_scope.debug("Bfile handles closed: Ok={}", .{bfresult==.ok});  // For some fucking reason, @tagName() for deinit_result generates a while(true)zig_breakpoint();??? Which expands to "zig_breakpoint_unavailable", which is not documented ANYWHERE. Google returns a single result, which is the commit that added it but on some weird mirror site thing. FUCKING LOVELY!
    // All good.
}