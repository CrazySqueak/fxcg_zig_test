const fxcg = @import("root").modules.fxcg_c;

pub const ui = struct {
    pub const status_bar = struct {
        pub const Mode = enum {
            /// Disabled entirely
            disable,
            /// Only visible if explicitly drawn using DisplayStatusArea
            explicit,
            /// Automatically drawn when the wrapper functions are invoked, or if DisplayStatusArea is called.
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
        pub fn getMode() Mode {
            return current_mode;
        }
    };
    
    /// A wrapper for GetKey.
    /// Blocks until the user presses a key.
    /// See https://prizm.cemetech.net/Syscalls/Keyboard/GetKey/ for details.
    pub fn getKey() c_int {
        // Draw status bar (sometimes it doesn't get drawn for some reason)
        if (status_bar.getMode() == .always) fxcg.display.DisplayStatusArea();
        
        // Call GetKey
        var key: c_int = undefined;
        _=fxcg.keyboard.GetKey(&key);
        
        // All done
        return key;
    }
};

// TODO