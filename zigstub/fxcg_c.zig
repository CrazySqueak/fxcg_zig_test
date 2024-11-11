
pub const libfxcg_all = @cImport({
    @cInclude("fxcg/app.h");
    @cInclude("fxcg/display.h");
    @cInclude("fxcg/file.h");
    @cInclude("fxcg/heap.h");
    @cInclude("fxcg/keyboard.h");
    @cInclude("fxcg/misc.h");
    @cInclude("fxcg/registers.h");
    @cInclude("fxcg/rtc.h");
    @cInclude("fxcg/serial.h");
    @cInclude("fxcg/system.h");
    @cInclude("fxcg/tmu.h");
    @cInclude("fxcg/usb.h");
});

pub const app = @cImport({
    @cInclude("fxcg/app.h");
});
pub const display = @cImport({
    @cInclude("fxcg/display.h");
});
pub const file = @cImport({
    @cInclude("fxcg/file.h");
});
pub const heap = @cImport({
    @cInclude("fxcg/heap.h");
});
pub const keyboard = @cImport({
    @cInclude("fxcg/keyboard.h");
});
pub const misc = @cImport({
    @cInclude("fxcg/misc.h");
});
pub const registers = @cImport({
    @cInclude("fxcg/registers.h");
});
pub const rtc = @cImport({
    @cInclude("fxcg/rtc.h");
});
pub const serial = @cImport({
    @cInclude("fxcg/serial.h");
});
pub const system = @cImport({
    @cInclude("fxcg/system.h");
});
pub const tmu = @cImport({
    @cInclude("fxcg/tmu.h");
});
pub const usb = @cImport({
    @cInclude("fxcg/usb.h");
});
