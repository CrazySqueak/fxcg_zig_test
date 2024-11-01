const std = @import("std");
const fxcg = @import("root").modules.fxcg_c;
const c = struct {
    pub const open_main_menu = @cImport({ @cInclude("openmainmenu.h"); });
    pub const keyupdate = @cImport({ @cInclude("keyupdate.h"); });
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
    
    /// Force-open the Main Menu
    /// Useful if you've received an input from a non-blocking method and need to open the menu
    pub inline fn openMainMenu() void {
        c.open_main_menu.SaveAndOpenMainMenu();
    }
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
            .tag_type = c_int,
            .fields = enum_fields,
            .decls = &[0]std.builtin.Type.Declaration{},
            .is_exhaustive = false,  // non-exhaustive
        }};
    });
    
    /// A wrapper for GetKey.
    /// Blocks until the user presses a key.
    /// See https://prizm.cemetech.net/Syscalls/Keyboard/GetKey/ for details.
    pub fn getKey() GetKey_Result {
        // Draw status bar (sometimes it doesn't get drawn for some reason)
        if (ui.status_bar.getMode() == .always) fxcg.display.DisplayStatusArea();
        
        // Call GetKey
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
        
        // All done
        return @enumFromInt(key);
    }
};
