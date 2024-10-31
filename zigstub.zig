const std = @import("std");

const fxcg = @import("fxcg_c.zig");
const program = @import("src/main.zig");

const LogBuffer = struct {
    buffer: [BUFFER_LINES*BUFFER_COLS]u8,
    
    const BUFFER_COLS = 21;
    const BUFFER_LINES = 1000;
};

pub export fn main() void {
    // Call main
    const result = program.main();
    // Error handling
    _ = result catch |err|{
        fxcg.display.Bdisp_AllClr_VRAM();
        fxcg.display.PrintXY(1,1, "--main() returned error", fxcg.display.TEXT_MODE_NORMAL, fxcg.display.TEXT_COLOR_RED);
        var errbuf: [2+21+1]u8 = undefined;
        const errtext: [*:0]const u8 = std.fmt.bufPrintZ(&errbuf, "--{s}", .{ @errorName(err) }) catch efmt: {
            // Out of space
            errbuf[2+21] = 0;  // add null terminator
            errbuf[2+21-1] = '.';  // add ellipsis
            errbuf[2+21-2] = '.';
            // And return errbuf
            break :efmt @ptrCast(&errbuf);
        };
        fxcg.display.PrintXY(1,2, errtext, fxcg.display.TEXT_MODE_NORMAL, fxcg.display.TEXT_COLOR_RED);
    };
    
    fxcg.display.PrintXY(1,7, "--Press EXE to exit", fxcg.display.TEXT_MODE_NORMAL, fxcg.display.TEXT_COLOR_BLACK);
    
    while (true) {
        var key: c_int = undefined;
        _ = fxcg.keyboard.GetKey(&key);

        if (key == fxcg.keyboard.KEY_CTRL_EXE) {
            break;
        }
    }
 
    return;
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, something_else: ?usize) noreturn {
    _ = msg; _ = error_return_trace; _ = something_else;
    while (true) {}
}