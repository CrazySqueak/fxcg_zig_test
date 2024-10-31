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
    buffer: [BUFFER_SIZE]u8,
    
    pub const FormatInfo = packed struct {
        mode: u1 = fxcg.display.TEXT_MODE_NORMAL,
        colour: u3 = fxcg.display.TEXT_COLOR_BLACK,
        _reserved: u4 = 0,
    };
    pub const BUFFER_COLS = 21;
    pub const BUFFER_ROW_LEN = BUFFER_COLS + @sizeOf(FormatInfo);
    pub const BUFFER_LINES = 300;
    pub const BUFFER_SIZE: u16 = @intCast(BUFFER_LINES*BUFFER_ROW_LEN);
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
    
    fn get_line_fmt_ptr(self: *Self, line: u16) *[@sizeOf(FormatInfo)]u8 {
        return self.buffer[line*BUFFER_ROW_LEN..][BUFFER_COLS..][0..@sizeOf(FormatInfo)];
    }
    /// Set the formatting for the current line
    pub fn set_line_format(self: *Self, format: FormatInfo) void {
        const data: [@sizeOf(FormatInfo)]u8 = @bitCast(format);
        @memcpy(self.get_line_fmt_ptr(get_line_for(self.cursor)), &data);
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
    pub inline fn writer(self: *Self) Writer {
        return .{ .context=self };
    }
    
    /// Move ahead by 1 column. Automatically skips the formatting area at the end of the line.
    pub fn next_col(self: *Self) void {
        const old_pos = self.cursor;
        self.cursor += 1;
        while (get_col_for(self.cursor) >= BUFFER_COLS) self.cursor += 1;
        self.cursor %= @intCast(BUFFER_SIZE);
        const new_pos = self.cursor;
        
        // Copy down the formatting info (if needed)
        if (get_line_for(old_pos) != get_line_for(new_pos))
            @memcpy(self.get_line_fmt_ptr(get_line_for(new_pos)), self.get_line_fmt_ptr(get_line_for(old_pos)));
    }
    /// Move to the start of the next line, blanking the remainder.
    pub fn next_line(self: *Self) void {
        while (get_col_for(self.cursor) != 0) self.putchar('\x00');
    }
    
    pub const Reader = struct {
        logger: *const Self,
        line: u16,
        
        /// Move the cursor by the given number of lines.
        /// Returns error.CursorOutOfBounds if this crosses the writer. If an error is returned, the cursor will be left at its old position.
        /// If `reverse` is true, moves backwards instead of forwards.
        pub fn move_cursor(self: *RSelf, lines: u16, comptime reverse: bool) !void {
            const old_pos = self.line; const boundrary = get_line_for(self.logger.*.cursor);
            if (!reverse) {
                // Forwards
                var new_pos = old_pos+lines;
                if (old_pos < boundrary and new_pos >= boundrary) return error.CursorOutOfBounds;
                // Handle wraparound
                if (new_pos >= BUFFER_LINES) {
                    const wrapped = new_pos-BUFFER_LINES;
                    // (we wrapped around and immediately overran)
                    if (wrapped >= boundrary) return error.CursorOutOfBounds;
                    // We're ok
                    new_pos = wrapped;
                }
                // All good
                self.line = new_pos;
            } else {
                // Backwards
                var new_pos: i17 = @as(i17,old_pos)-lines;
                if (old_pos >= boundrary and new_pos < boundrary) return error.CursorOutOfBounds;
                // Handle wraparound
                if (new_pos < 0) {
                    const wrapped: u16 = BUFFER_LINES - @as(u16,@intCast(-new_pos));
                    // (we wrapped around and immediately underran)
                    if (wrapped < boundrary) return error.CursorOutOfBounds;
                    // We're ok
                    new_pos = wrapped;
                }
                // All good
                self.line = @intCast(new_pos);
            }
        }
        /// Move the cursor by the given number of lines.
        /// If this cannot be done, moves it as far as possible.
        /// Returns the number of lines travelled.
        pub fn move_cursor_saturating(self: *RSelf, lines: u16, comptime reverse: bool) u16 {
            self.move_cursor(lines,reverse) catch |e|switch(e){
                error.CursorOutOfBounds => {
                    // Oops
                    // Move one-by-one
                    for (0..lines) |i| {
                        self.move_cursor(1,reverse) catch return @intCast(i);
                    }
                    // ??? How did we get here?
                    return lines;
                },
            };
            return lines;
        }
        
        /// Get the text of the current line pointed by the cursor
        pub fn get_line_text(self: *const RSelf) *const [BUFFER_COLS]u8 {
            return self.logger.buffer[self.line*BUFFER_ROW_LEN..][0..BUFFER_COLS];
        }
        /// Get the formatting info of the current line pointed to by the cursor
        pub fn get_format_info(self: *const RSelf) FormatInfo {
            const data: [@sizeOf(FormatInfo)]u8 = @constCast(self.logger).get_line_fmt_ptr(self.line).*;
            return @bitCast(data);
        }
        
        const RSelf = @This();
    };
    pub fn reader(self: *const Self) Reader {
        var end_line: i17 = get_line_for(self.cursor); end_line -= 1;
        if (end_line < 0) end_line += BUFFER_LINES;
        return .{ .logger=self, .line=@intCast(end_line) };
    }
};
var logger = LogBuffer.new();

pub fn display_log() void {
    var reader = logger.reader();
    const LINES_PER_SCREEN = 7;
    // We start on the final line, so we should seek upwards to include the others
    _=reader.move_cursor_saturating(LINES_PER_SCREEN-1,true);
    while(true) {
        fxcg.display.Bdisp_AllClr_VRAM();
        // Display (up to) x lines
        for (1..LINES_PER_SCREEN+1) |_ln| { const line: u16 = @intCast(_ln);
            // Read text into buffer
            var buf: [2+LogBuffer.BUFFER_COLS:0]u8 = undefined;
            @memset(buf[0..2], '-');  // -- prefix
            @memcpy(buf[2..][0..LogBuffer.BUFFER_COLS], reader.get_line_text());
            buf[buf.len] = '\x00';  // null terminator
            // Get format info
            const format = reader.get_format_info();
            // Display line
            fxcg.display.PrintXY(1,line, &buf, format.mode, format.colour);
            
            // Advance cursor
            reader.move_cursor(1, false) catch |e|switch(e){
                error.CursorOutOfBounds => {
                    // No more lines
                    // Move cursor back
                    _=reader.move_cursor_saturating(line-1,true);
                    // Abort early
                    break;
                },
            };
        } else {
            // All done. Move cursor back
            _=reader.move_cursor_saturating(LINES_PER_SCREEN,true);
        }
        
        // Use GetKey to wait for a key
        var key: c_int = undefined;
        _ = fxcg.keyboard.GetKey(&key);
        switch (key) {
            fxcg.keyboard.KEY_CTRL_UP => {
                // Move up one screen (almost)
                _=reader.move_cursor_saturating(LINES_PER_SCREEN-1,true);
            },
            fxcg.keyboard.KEY_CTRL_DOWN => {
                // Move down one screen (almost)
                _=reader.move_cursor_saturating(LINES_PER_SCREEN-1,false);
            },
            fxcg.keyboard.KEY_CTRL_LEFT => {
                // Move up one line
                _=reader.move_cursor_saturating(1,true);
            },
            fxcg.keyboard.KEY_CTRL_RIGHT => {
                // Move down one line
                _=reader.move_cursor_saturating(1,false);
            },
            
            fxcg.keyboard.KEY_CTRL_EXIT => {
                // Exit
                break;
            },
            // TODO: Support saving?
            else => {},  // do nothing
        }
    }
}

pub export fn main() void {
    logger.set_line_format(.{ .mode = fxcg.display.TEXT_MODE_NORMAL, .colour = fxcg.display.TEXT_COLOR_BLACK});
    try logger.print("Starting AddIn...\n", .{});
    _=try logger.puts("Beep Boop...\n");
    display_log();
    
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
    _=try logger.puts("main() has exited.\nPress MENU to exit.\n");
    display_log();
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    logger.next_line();
    logger.set_line_format(.{ .colour = fxcg.display.TEXT_COLOR_RED });
    logger.print("Panic: {s}\n", .{msg}) catch {};
    display_log(); _ = error_return_trace;
    while (true) {
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
    }
}