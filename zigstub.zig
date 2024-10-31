const std = @import("std");

const fxcg = @import("fxcg_c.zig");
const program = @import("src/main.zig");

/// A buffer for printing debug information to.
/// This acts as a ring buffer, so if it fills up, new log messages will
/// overwrite old ones.
const LogBuffer = struct {
    /// The current cursor position (the next position to be written)
    cursor: u16,
    /// The buffer containing log data, in row-major order.
    /// Columns 0-20 (inclusive) for a row are the text. Columns 21+ are formatting data.
    buffer: [BUFFER_LINES*BUFFER_ROW_LEN]u8,
    
    pub const FormatInfo = packed struct {
        mode: u1,
        colour: u3,
        _reserved: u4 = 0,
    };
    pub const BUFFER_COLS = 21;
    pub const BUFFER_ROW_LEN = BUFFER_COLS + @sizeOf(FormatInfo);
    pub const BUFFER_LINES = 1000;
    const Self = @This();
    
    fn new() Self {
        return .{
            .cursor = 0,
            .buffer = [_]u8{0} ** (BUFFER_LINES*BUFFER_ROW_LEN),
        };
    }
    inline fn get_line_for(pos: u16) u16 {
        return @divTrunc(pos,BUFFER_ROW_LEN);
    }
    inline fn get_col_for(pos: u16) u16 {
        return pos%BUFFER_ROW_LEN;
    }
    
    fn get_line_fmt_ptr(self: *Self, pos: u16) *[@sizeOf(FormatInfo)]u8 {
        return self.buffer[get_line_for(pos)..][BUFFER_COLS..][0..@sizeOf(FormatInfo)];
    }
    /// Set the formatting for the current line
    pub fn set_line_format(self: *Self, format: FormatInfo) void {
        const data: [@sizeOf(FormatInfo)]u8 = @bitCast(format);
        @memcpy(self.get_line_fmt_ptr(self.cursor), &data);
    }
    
    /// Put a character at the current position, then advance by 1 column.
    pub fn putchar(self: *Self, char: u8) void {
        self.buffer[self.cursor] = char;
        self.next_col();
    }
    /// Write the given string into the buffer at the current position.
    /// Correctly handles '\n' (but no other control codes).
    pub fn puts(self: *Self, string: []const u8) !usize {
        var i: usize = 0;
        for (string) |c| {
            if (c == '\n') self.next_line()
            else self.putchar(c);
            i += 1;
        }
        return i;
    }
    /// Print to the buffer using std.fmt
    pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
        try std.fmt.format(self.writer(), fmt, args);
    }
    
    pub const Writer = std.io.GenericWriter(*Self, error{}, puts);
    pub fn writer(self: *Self) Writer {
        return .{ .context=self };
    }
    
    /// Move ahead by 1 column. Automatically skips the formatting area at the end of the line.
    pub fn next_col(self: *Self) void {
        const old_pos = self.cursor;
        self.cursor += 1;
        while (get_col_for(self.cursor) >= BUFFER_COLS) self.cursor += 1;
        self.cursor %= @intCast(self.buffer.len);
        const new_pos = self.cursor;
        
        // Copy down the formatting info (if needed)
        if (get_line_for(old_pos) != get_line_for(new_pos))
            @memcpy(self.get_line_fmt_ptr(new_pos), self.get_line_fmt_ptr(old_pos));
    }
    /// Move to the start of the next line, blanking the remainder.
    pub fn next_line(self: *Self) void {
        while (get_col_for(self.cursor) != 0) self.putchar(' ');
    }
    
    pub const Reader = struct {
        logger: *const Self,
        cursor: i17,
        
        const RSelf = @This();
    };
};
var logger = LogBuffer.new();

pub export fn main() void {
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    try logger.print("Starting AddIn...\n", .{});
    
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