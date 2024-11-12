const std = @import("std");
const fxcg = @import("fxcg_c");
const c = struct {
    pub const open_main_menu = @cImport({ @cInclude("openmainmenu.h"); });
    pub const keyupdate = @cImport({ @cInclude("keyupdate.h"); });
    pub const rtc_datetime = @cImport({ @cInclude("rtc_datetime.h"); });
    pub const nonblockingdma = @cImport({ @cInclude("nonblockingdma.h"); });
};

pub const ui = struct {
    pub const status_bar = struct {
        pub const Mode = enum {
            /// Disabled entirely
            disable,
            /// Only visible if explicitly drawn using DisplayStatusArea
            explicit,
            /// Automatically drawn during GetKey and several screen-display wrapper functions here, or if DisplayStatusArea is called.
            always,
        };
        var current_mode: Mode = .explicit;  // (default, i think)
        
        pub fn switchMode(new_mode: Mode) void {
            const old_mode = current_mode;
            switch (old_mode) {
                .disable => switch (new_mode) {
                    .disable => return,
                    .explicit => fxcg.display.EnableStatusArea(0),
                    .always => { fxcg.display.EnableStatusArea(2); fxcg.display.EnableDisplayHeader(2, 2); },
                },
                .explicit => switch (new_mode) {
                    .disable => fxcg.display.EnableStatusArea(3),
                    .explicit => return,
                    .always => fxcg.display.EnableDisplayHeader(2,2),
                },
                .always => switch (new_mode) {
                    .disable => { fxcg.display.EnableStatusArea(3); fxcg.display.EnableDisplayHeader(0,0); },
                    .explicit => fxcg.display.EnableDisplayHeader(0,0),
                    .always => return,
                },
            }
            current_mode = new_mode;
        }
        pub inline fn getMode() Mode {
            return current_mode;
        }
    };
    
    /// Redraw the UI according to the corresponding modes set in this wrapper
    pub fn drawDefaultUI() void {
        // Draw status bar
        if (ui.status_bar.getMode() == .always) fxcg.display.DisplayStatusArea();
    }
    
    /// Force-open the Main Menu
    /// Useful if you've received an input from a non-blocking method and need to open the menu
    pub inline fn openMainMenu() void {
        c.open_main_menu.SaveAndOpenMainMenu();
    }
};

pub const display = struct {
    /// Get the VRAM Address for this calculator model / OS version
    pub fn getVRAMAddress() *[VRAM_WIDTH*VRAM_HEIGHT]Color565 {
        if (cached_vram_addr) |vram| return vram
        else {
            @branchHint(.unlikely);
            cached_vram_addr = @alignCast(@ptrCast(fxcg.display.GetVRAMAddress()));
            return cached_vram_addr.?;
        }
    }
    
    var cached_vram_addr: ?*[VRAM_WIDTH*VRAM_HEIGHT]Color565 = null;
    pub const VRAM_WIDTH = fxcg.display.LCD_WIDTH_PX;
    pub const VRAM_HEIGHT = fxcg.display.LCD_HEIGHT_PX;
    
    pub const Color565Raw = fxcg.display.color_t;
    pub const Color565 = packed struct { b: u5, g: u6, r: u5, // (zig packed structs go from LSB to MSB)
        pub inline fn from_raw(raw: Color565Raw) Color565 {
            return @bitCast(raw);
        }
        pub inline fn to_raw(self: Color565) Color565Raw {
            return @bitCast(self);
        }
        pub inline fn from_rgb(r: u8, g: u8, b: u8) Color565 {
            return .{
                .r = @intCast(r>>3),
                .g = @intCast(g>>2),
                .b = @intCast(b>>3),
            };
        }
        pub inline fn from_rgb_int(rgb: u32) Color565 {
            return Color565.from_rgb(@intCast((rgb&0xFF0000)>>16),@intCast((rgb&0x00FF00)>>8),@intCast(rgb&0x0000FF));
        }
    };
    comptime { std.debug.assert(@sizeOf(Color565Raw) == @sizeOf(Color565)); std.debug.assert(@alignOf(Color565Raw) == @alignOf(Color565)); }
    
    // Define colour constants
    // (we define them as an instance of a struct as we can't create defs programatically)
    fn decl_colours_type() type {
        // We use reflection to obtain the defined colour constants
        const fxcg_display_ty = @typeInfo(fxcg.display).@"struct";
        var struct_fields: []const std.builtin.Type.StructField = &.{};
        
        @setEvalBranchQuota(10_000);
        for (fxcg_display_ty.decls) |decl| {
            if (std.mem.startsWith(u8, decl.name, "COLOR_")) {
                struct_fields = struct_fields ++ .{.{ .name=decl.name[6..], .type=Color565, .default_value=&Color565.from_raw(@field(fxcg.display,decl.name)), .is_comptime=false, .alignment=@alignOf(Color565) }};
            }
        }
        
        return @Type(.{.@"struct" = .{ .layout = .auto, .fields = struct_fields, .decls = &.{}, .is_tuple = false }});
    }
    pub const colors: decl_colours_type() = .{};
    comptime { 
        std.debug.assert(std.meta.eql(Color565.from_raw(fxcg.display.COLOR_RED), Color565.from_rgb(255,0,0)));
        std.debug.assert(std.meta.eql(colors.LIME,Color565.from_rgb(0,255,0))); std.debug.assert(std.meta.eql(colors.GREEN,Color565.from_rgb(0,128,0)));
        std.debug.assert(std.meta.eql(colors.BLUE,Color565.from_rgb(0,0,255)));
    }
    
    /// Draws the current buffer to the screen, blocking until it is done.
    pub inline fn putDisp_DD() void {
        ui.drawDefaultUI();
        // Push to display
        fxcg.display.Bdisp_PutDisp_DD();
    }
    
    /// Low-level. Used for non-blocking DMA.
    /// Unlike the other wrappers, these wrappers do not call the drawDefaultUI() wrapper function.
    /// See https://prizm.cemetech.net/Useful_Routines/Non-blocking_DMA/ and https://www.cemetech.net/forum/viewtopic.php?p=292621#292621
    pub const nonblocking = struct {
        pub const DMAMode = union(enum) {
            /// Akin to Bdisp_PutDisp_DD_stripe
            stripe: struct { y1: c_uint, y2: c_uint },
            /// Akin to Bdisp_PutDisp_DD
            full: void,
        };
        
        var transfer_ongoing: bool = false;
        /// Start a transfer.
        /// Whether a transfer is ongoing is kept in a global variable and is asserted against (as you can't start a transfer when one is ongoing),
        /// but is only updated once you call wait() to wait for the transfer to complete.
        /// It is recommended that you call wait() immediately before start() unless you are certain you called it earlier.
        pub inline fn start(mode: DMAMode) void {
            std.debug.assert(!transfer_ongoing);
            // Start the transfer
            switch (mode) {
                .stripe => |stripe_args| c.nonblockingdma.DoDMAlcdNonblockStrip(stripe_args.y1,stripe_args.y2),
                .full => c.nonblockingdma.DoDMAlcdNonblock(),
            }
            // All good
            transfer_ongoing = true;
        }
        /// Wait until the ongoing transfer has finished.
        pub inline fn wait() void {
            c.nonblockingdma.DmaWaitNext();
            transfer_ongoing = false;  // we know the transfer has finished
        }
    };
};

pub const input = struct {
    pub const GetKey_Result = @Type(gkdef:{
        // We use reflection to obtain the defined keycode constants
        const fxcg_keyboard_ty = @typeInfo(fxcg.keyboard).@"struct";
        var enum_fields: []const std.builtin.Type.EnumField = &.{};
        
        @setEvalBranchQuota(10_000);
        for (fxcg_keyboard_ty.decls) |decl| {
            if (std.mem.startsWith(u8, decl.name, "KEY_") and !std.mem.startsWith(u8,decl.name,"KEY_PRGM")) {
                enum_fields = enum_fields ++ .{.{ .name=decl.name[4..], .value=@field(fxcg.keyboard,decl.name) }};
            }
        }
        break :gkdef .{ .@"enum" = .{
            .tag_type = u16,
            .fields = enum_fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,  // non-exhaustive
        }};
    });
    
    /// A wrapper for GetKey.
    /// Draws the current buffer to the screen, and blocks until the user presses a key.
    /// See https://prizm.cemetech.net/Syscalls/Keyboard/GetKey/ for details.
    pub fn getKey() GetKey_Result {
        // Redraw the UI (sometimes doesn't get drawn for some reason)
        ui.drawDefaultUI();
        
        // Call GetKey
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
        
        // All done
        return @enumFromInt(key);
    }
    
    pub const PrgmKey = @Type(pkdef:{
        // We use reflection to obtain the defined keycode constants
        const fxcg_keyboard_ty = @typeInfo(fxcg.keyboard).@"struct";
        var enum_fields: []const std.builtin.Type.EnumField = &.{};
        
        @setEvalBranchQuota(10_000);
        for (fxcg_keyboard_ty.decls) |decl| {
            if (std.mem.startsWith(u8,decl.name,"KEY_PRGM_")) {
                enum_fields = enum_fields ++ .{.{ .name=decl.name[9..], .value=@field(fxcg.keyboard,decl.name) }};
            }
        }
        break :pkdef .{ .@"enum" = .{
            .tag_type = u8,
            .fields = enum_fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,  // non-exhaustive
        }};
    });
    
    /// The keyupdate() family of non-blocking input functions
    pub const keyupdate = struct {
        /// Should be called once per frame, before reading input, in order to update the input values.
        pub inline fn key_update() void {
            c.keyupdate.keyupdate();
        }
        /// Open the Main Menu if the MENU key is pressed. Should be called after key_update() unless you have a good reason not to.
        pub inline fn handle_menu_key() void {
            if (keydownlast(PrgmKey.MENU)) {
                ui.openMainMenu();  // open the menu
                // Update state to match now that the menu is closed
                key_update();
            }
        }
        
        inline fn keydownlast(key: PrgmKey) bool {
            // No assert is needed (even if key is 255, the word checked is based on the row number (%10), not the column number)
            return c.keyupdate.keydownlast(@intFromEnum(key)) != 0;
        }
        inline fn keydown2ndlast(key: PrgmKey) bool {
            // No assert is needed (even if key is 255, the word checked is based on the row number (%10), not the column number)
            return c.keyupdate.keydownhold(@intFromEnum(key)) != 0;
        }
        
        /// Returns true if the key was down during the last keyupdate() call.
        pub inline fn key_down(key: PrgmKey) bool {
            return keydownlast(key);
        }
        /// Returns true if the key was down during the last two keyupdate() calls.
        pub inline fn key_held(key: PrgmKey) bool {
            return keydownlast(key) and keydown2ndlast(key);
        }
        /// Returns true if the key was down during the last keyupdate() call, but not the one before.
        pub inline fn key_pressed(key: PrgmKey) bool {
            return keydownlast(key) and !keydown2ndlast(key);
        }
        /// Returns true if the key was down during the second-last keyupdate() call, but not the one after.
        pub inline fn key_released(key: PrgmKey) bool {
            return keydown2ndlast(key) and !keydownlast(key);
        }
    };
};

pub const rtc = struct {
    pub const date = struct {
        pub const DayOfWeek = enum(u3) {
            monday = 1,
            tuesday = 2,
            wednesday = 3,
            thursday = 4,
            friday = 5,
            saturday = 6,
            sunday = 7,
        };
        pub const RTCDateTime = struct {
            day_of_week: DayOfWeek,
            date: Date, time: Time,
        };
        pub const Date = struct {
            day: u5 = 1, month: u4 = 1, year: u14 = 2024,
        };
        pub const Time = struct {
            second: u6 = 0, minute: u6 = 0, hour: u5 = 0,
        };
        
        
        /// Get the current RTC date/time
        pub fn get_date() RTCDateTime {
            var rtc_setup: c.rtc_datetime.rtc_setup = undefined;
            c.rtc_datetime.RTC_Read(&rtc_setup);
            
            return .{
                .day_of_week = @enumFromInt(rtc_setup.dayofweek),
                .time = .{ 
                    .second = @intCast(rtc_setup.second),
                    .minute = @intCast(rtc_setup.minute),
                    .hour = @intCast(rtc_setup.hour),
                },
                .date = .{
                    .day = @intCast(rtc_setup.day),
                    .month = @intCast(rtc_setup.month),
                    .year = @intCast(rtc_setup.year),
                },
            };
        }
        /// Set the current RTC date/time
        pub fn set_date(new: RTCDateTime) void {
            const rtc_setup: c.rtc_datetime.rtc_setup = .{
                .dayofweek = @intFromEnum(new.day_of_week),
                .second = new.time.second,
                .minute = new.time.minute,
                .hour = new.time.hour,
                .day = new.date.day,
                .month = new.date.month,
                .year = new.date.year,
            };
            c.rtc_datetime.RTC_Set(&rtc_setup);
        }
        
        /// Simple sanity check for RTC settings (which are wiped if you segfault or change the batteries).
        /// Returns true if the RTC's set date is during or after the year 2024 A.D.
        /// As time travel nor FTL travel have been invented yet (and likely never will be), the date being set to before 2024 (when this function was written) is clearly a misconfiguration.
        pub inline fn is_rtc_sane() bool {
            return get_date().date.year < 2024;
        }
        /// A version of is_rtc_date_sane that returns an error if the date is not sane
        pub fn get_date_sane() !RTCDateTime {
            const rtc_date = get_date();
            if (rtc_date.date.year < 2024) return error.RtcYearInPast
            else return rtc_date;
        }
    };
    pub const time = struct {
        /// Sleep for the given number of milliseconds
        pub fn sleep_millis(millis: usize) void {
            const INNERWAIT_MAX = 2000;
            var millis_remaining = millis;
            while (millis_remaining > INNERWAIT_MAX) { fxcg.system.OS_InnerWait_ms(INNERWAIT_MAX); millis_remaining -= INNERWAIT_MAX; }
            if (millis_remaining > 0) { fxcg.system.OS_InnerWait_ms(millis_remaining); millis_remaining -= millis_remaining; }
        }
        
        /// Get the "tick count" of the RTC timer.
        /// Ticks at 128Hz but resets at midnight.
        pub fn get_rtc_ticks() u32 {
            return fxcg.rtc.RTC_GetTicks();
        }
        pub const RTC_TICKS_PER_SECOND = 128;
        
        /// Limits the maximum number of calls to .tick() per second
        /// Useful for framerate limiting and similar uses
        pub const RateLimiter = struct {
            last_tick: u32,
            
            /// fn tick_tock(rtc_ticks_per_frame) delta_time_in_rtc_ticks
            pub fn tick_tock(self: *@This(), rtc_ticks_per_frame: u32) u32 {
                const new_tick = get_rtc_ticks();
                const old_tick = self.last_tick;
                self.last_tick = new_tick;
                if (new_tick < old_tick) {
                    // abnormal operation
                    // midnight has passed and the tick value has wrapped around
                    // we cannot guarantee what to do here,
                    // so the best port of call is just to skip this instant
                    return rtc_ticks_per_frame;
                }
                const elapsed = new_tick - old_tick;
                if (elapsed >= rtc_ticks_per_frame) {
                    // We overran
                    return elapsed;
                }
                const ticks_to_sleep = rtc_ticks_per_frame - elapsed;
                const time_to_sleep_ms = (ticks_to_sleep * 1000) / RTC_TICKS_PER_SECOND;
                sleep_millis(time_to_sleep_ms);
                return rtc_ticks_per_frame;
            }
        };
    };
};
pub const timers = struct {
    /// An OS-provided timer, that fires at a predictable interval.
    pub const Timer = struct {
        handler: *const fn() callconv(.C) void,
        /// N.B. Timer precision is not in ms, but instead 25Hz "ticks".
        freq_ms: u32,
        
        /// The current timer slot (if running), or zero if not running
        slot: ?c_int,
        
        const Self = @This();
        pub fn is_running(self: Self) bool {
            return self.slot != null;
        }
        pub fn start(self: *Self) !void {
            if (self.is_running()) return;
            
            const slot = fxcg.system.Timer_Install(0,self.handler,self.freq_ms);
            if (slot < 0) return error.TooManyTimers;
            const ok = fxcg.system.Timer_Start(slot);
            if (ok != 0) return error.TimerStartFailed;
            
            self.slot = slot;  // All good
        }
        pub fn stop(self: *Self) void {
            if (!self.is_running()) return;
            const slot = self.slot.?; self.slot = null;
            
            const ok = fxcg.system.Timer_Stop(slot);
            if (ok != 0){} // ???
            const ok2 = fxcg.system.Timer_Deinstall(slot);
            if (ok2 != 0) return error.TimerStopFailed;
        }
    };
    
    /// The number of currently running timers
    var running_timers_count: u8 = 0;
    /// Returns true if any timers are running
    pub inline fn are_timers_running() bool {
        return running_timers_count != 0;
    }
};

/// Functions for accessing storage memory.
pub const bfile = struct {
    inline fn _err_if_timers_running() !void {
        // See https://prizm.cemetech.net/Incompatibility_between_Bfile_Syscalls_and_Timers/
        if (timers.are_timers_running()) return error.BfileWhenTimerRunning;
    }
    
    pub const MutPath = [*:0]u16; pub const Path = [*:0]const u16;
    pub const SEP = '\\'; pub const ROOT = "\\\\fls0"; pub const ROOT_PATH: Path = rpev:{ var buf: [ROOT.len:0]u16 = undefined; str_to_path(&buf, ROOT); break :rpev buf; };
    /// Convert from a string filename to a Path, writing to the provided buffer.
    pub inline fn str_to_path(dest: []u16, src: [:0]const u8) !MutPath {
        fxcg.file.Bfile_StrToName_ncpy(dest.ptr, src, dest.len);  // (if strlen(src) < dest.len, dest is padded appropriately)
        if (dest[dest.len-1] != 0) return error.SourcePathLongerThanDest;  // (no room for the null terminator)
        return @ptrCast(dest);
    }
    /// Convert from a Path to a string filename, writing to the provided buffer.
    pub inline fn path_to_str(dest: []u8, src: Path) ![*:0]u8 {
        fxcg.file.Bfile_NameToStr_ncpy(dest.ptr, src, dest.len);
        if (dest[dest.len-1] != 0) return error.SourcePathLongerThanDest;  // (no room for the null terminator)
        return @ptrCast(dest);
    }
    
    const CreateMode = enum(c_int) {
        file = fxcg.file.CREATEMODE_FILE,
        folder = fxcg.file.CREATEMODE_FOLDER,
    };
    /// https://prizm.cemetech.net/Syscalls/Bfile/Bfile_CreateEntry_OS/
    pub fn mkfile(filename: Path, size: c_uint) !void {
        try _err_if_timers_running();
        var size_cause_they_forgot_to_const_their_ptr = size;
        const result = fxcg.file.Bfile_CreateEntry_OS(filename, @intFromEnum(CreateMode.file), &size_cause_they_forgot_to_const_their_ptr);
        if (result < 0) return error.BfileCreateFailed;
    }
    /// https://prizm.cemetech.net/Syscalls/Bfile/Bfile_CreateEntry_OS/
    pub fn mkdir(filename: Path) !void {
        try _err_if_timers_running();
        const result = fxcg.file.Bfile_CreateEntry_OS(filename, @intFromEnum(CreateMode.folder), null);
        if (result < 0) return error.BfileCreateFailed;
    }
    /// https://prizm.cemetech.net/Syscalls/Bfile/Bfile_DeleteEntry/
    pub fn delete(filename: Path) !void {
        try _err_if_timers_running();
        const result = fxcg.file.Bfile_DeleteEntry(filename);
        if (result < 0) return error.BfileDeleteFailed;
    }
    /// https://prizm.cemetech.net/Syscalls/Bfile/Bfile_RenameEntry/
    pub fn rename(src: Path, dest: Path) !void {
        try _err_if_timers_running();
        const result = fxcg.file.Bfile_RenameEntry(src,dest);
        if (result < 0) return error.BfileRenameFailed;
    }
    
    pub fn get_free_space() !c_int {
        try _err_if_timers_running();
        var result: c_int = undefined;
        const err = fxcg.file.Bfile_GetMediaFree_OS(ROOT_PATH,&result);
        if (err < 0) return error.BfileGetMediaFreeFailed;
        return result;
    }
    
    pub const OpenMode = enum(c_int) {
        read = fxcg.file.READ,
        read_share = fxcg.file.READ_SHARE,
        write = fxcg.file.WRITE,
        read_write = fxcg.file.READWRITE,
        read_write_share = fxcg.file.READWRITE_SHARE,
    };
    /// https://prizm.cemetech.net/Syscalls/Bfile/Bfile_OpenFile_OS/
    pub fn open(filename: Path, mode: OpenMode) !OpenFile {
        try _err_if_timers_running();
        
        // Open
        const result = fxcg.file.Bfile_OpenFile_OS(filename, @intFromEnum(mode), 0);
        if (result < 0) return error.BfileOpenFailed;
        
        // TODO: Refuse to open files which are in subdirectories and not using the first handle
        // https://prizm.cemetech.net/Syscalls/Bfile/Bfile_OpenFile_OS/#comments
        
        // Add to "open handles" list
        try open_file_handles.?.append(result);
        // And return
        return .{.handle=result};
    }
    
    pub const OpenFile = struct {
        handle: c_int,
        
        const Self = @This();
        /// Close the file.
        pub fn close(self: *Self) !void {
            try _err_if_timers_running();
            
            // Remove from "open handles" list
            const index = for (open_file_handles.?.items, 0..) |h,i| { if (h == self.handle) break i; } else undefined;
            _=open_file_handles.?.swapRemove(index);
            // And close
            _=fxcg.file.Bfile_CloseFile_OS(self.handle);
            self.* = undefined;
        }
        
        /// Read from the file into buf.
        /// Returns a slice of buf containing the bytes read.
        /// If pos is -1, reads from the current position. Otherwise, seeks to the given position before reading.
        inline fn _read_impl(self: *Self, buf: []u8, pos: c_int) ![]u8 {
            try _err_if_timers_running();
            
            // We read in chunks to ensure we don't encounter issues
            // See https://prizm.cemetech.net/Syscalls/Bfile/Bfile_ReadFile_OS/#comments for details
            var n_read: usize = 0;
            var pos_seek = pos;
            
            const CHUNK_SIZE = 256*1024;
            var it = std.mem.window(u8, buf, CHUNK_SIZE, CHUNK_SIZE);
            while (it.next()) |buf_chunk| {
                const n = fxcg.file.Bfile_ReadFile_OS(self.handle,buf_chunk.ptr,@intCast(buf_chunk.len),pos_seek);
                if (n < 0) return error.BfileReadFailed;
                
                pos_seek = -1;  // (continue from the current position next time)
                n_read += n;
            }
            
            // All done.
            return buf[0..n_read];
        }
        /// Read from the file into buf.
        /// Returns a slice of buf containing the bytes read.
        pub fn read(self: *Self, buf: []u8) ![]u8 {
            return self._read_impl(buf, -1);
        }
        /// Seek to position pos, then read from the file into buf.
        /// Returns a slice of buf containing the bytes read.
        /// (if buf has a length of zero, does not seek)
        pub fn seek_and_read(self: *Self, buf: []u8, pos: c_int) ![]u8 {
            return self._read_impl(buf, pos);
        }
        /// Write into the file from buf
        /// WARNING: buf must not be in the flash! See https://prizm.cemetech.net/Syscalls/Bfile/Bfile_WriteFile_OS/#comments for details.
        pub fn write(self: *Self, buf: []const u8) !void {
            try _err_if_timers_running();
            const result = fxcg.file.Bfile_WriteFile_OS(self.handle,buf.ptr,@intCast(buf.len));
            if (result < 0) return error.BfileWriteFailed;
        }
        
        /// Seek to the given position (relative to the start of the file)
        /// Returns the new position. Expands the file if abs_pos > size.
        pub fn seek(self: *Self, abs_pos: c_int) !c_int {
            try _err_if_timers_running();
            return fxcg.file.Bfile_SeekFile_OS(self.handle, abs_pos);
        }
        /// Get the current position in the file. (relative to the start of the file)
        pub fn tell(self: *Self) !c_int {
            try _err_if_timers_running();
            return fxcg.file.Bfile_TellFile_OS(self.handle);
        }
        /// Get the total size of the file.
        pub fn get_size(self: *Self) !c_int {
            try _err_if_timers_running();
            return fxcg.file.Bfile_GetFileSize_OS(self.handle);
        }
    };
    
    /// A list of open file handles. Used to avoid issues with leaking handles, as leaked handles are gone forever (until you reboot the calculator from scratch).
    /// This is necessary because file handles, unlike timers and the heap, are not cleaned up when you close the AddIn.
    var open_file_handles: ?std.ArrayList(c_int) = null;
    /// Used internally.
    pub fn __init_bfile() !void {
        open_file_handles = try std.ArrayList(c_int).initCapacity(std.heap.c_allocator, 16);  // 16 handles max i think
    }
    /// Used internally. Cleans up any leaked file handles. This may be called multiple times.
    pub fn __deinit_bfile() enum { ok, leaked } {
        defer open_file_handles = null;
        if (open_file_handles) |*ofh| {
            defer ofh.deinit();
            if (ofh.items.len != 0) {
                for (ofh.items) |handle| {
                    // Close outstanding files to avoid leaking them
                    _=fxcg.file.Bfile_CloseFile_OS(handle);
                }
                return .leaked;
            }
            return .ok;
        } else return .ok;
    }
};
