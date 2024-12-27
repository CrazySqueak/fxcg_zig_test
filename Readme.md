# PrizmSDK using Zig instead of C, for some reason
**Disclaimer**: This project is a random idea I'm testing out. I make no guarantees that it will work in all circumstances. I also make no guarantees that I will actually maintain this.

Additionally, since LLVM's optimization passes are skipped, quite a few niche zigc features are used, and Zig itself isn't really well-designed for development on low-end systems, no performance or functionality guarantees are made. Attempting to use quite a few stdlib or builtin functions causes weird compiler errors that don't occur on a normal system, and if you genuinely care about making code that works and runs fast on the fx-CG, you should really just suck it up and learn C.

I did this because I could, not because I should.

## SETUP / BUILDING
There are a few steps you need to go through in order to build this. Note that these instructions are for linux only (use WSL if you are on Windows).
1. Clone the repository, using the `--recurse-submodules` flag to download submodules as well.
1. Run `make` with no arguments to set up the cross-compiler (used to compiling programs for the Prizm's SH3 processor). No `make install` is needed.
    - I'd suggest using `make -j$(nproc)` to use all CPU cores for compiling instead of just 1.
    - You'll need an internet connection to automatically download binutils and gcc. If you wish to, you can manually download `binutils-2.43.1.tar.xz` and `gcc-14.2.0.tar.xz`, saving them in the `.build/` directory instead.
    - If you get an error like this: `make: *** No rule to make target 'xxxxxx/libfxcg/Makefile', needed by 'xxxxx/libfxcg/lib/libfxcg.a'.  Stop.`, then you didn't tell Git to download the submodules. Run `git submodule update --init --recursive` before running `make` again.
1. Wait for `make` to finish. This will take a while, most of which will be taken up by downloading and compiling the gcc cross-compiler.
1. Once `make` has finished successfully, your development environment is set up.
1. (optional) Check that everything works by going into `projects/skeleton` and running `zig build` - this should succeed and produce a g3a file at `zig-out/skeleton.g3a`.

## Modules
In addition to zig's `std` module, you can import a few others:
 - `const fxcg = @import("fxcg_c");` - contains all the functions from libfxcg. You can either access them prefixed by the header name (e.g. `fxcg.display.Bdisp_PutDisp_DD()`), or all at once using the `libfxcg_all` submodule (e.g. `fxcg.libfxcg_all.Bdisp_PutDisp_DD()`).
 - `const cgutil = @import("cgutil");` - a collection of utilities. Several of these are from the [Cemetech forums](https://www.cemetech.net/forum/viewforum.php?f=68) and [WikiPrizm](https://prizm.cemetech.net/), and others (especially the zig portion) were written by me. See the [cgutil documentation](./cgutil/README.md) for more info.
 - `const zigstub = @import("zigstub");` - this module contains the subroutines used to glue things together. `zigstub.logbuf.display_log()` is a useful function for displaying the 300-line logging buffer that can be written to using the `std.log` suite of functions.

## The logging buffer
To aid debugging, a log handler has been set up.

Calls to the functions in `std.log` will write to a 300-line logging buffer. This can be manually displayed using the `zigstub.logbuf.display_log()` function, and is automatically done if your `main()` function returns or if your code panics.

Stack traces are currently unavailable due to the odd build system at play.

## Zigstub and you
The `zigstub` module handles quite a few things for you, some of which may trip you up:
 - Your `main()` function is allowed to return, in which case the stub will display your program's log, as well the error if `main()` returned an error.
 - The log handler function is set in `std_options`. As a result, `std_options` currently cannot be modified by your project.
 - It sets a quit handler, which calls some cleanup functions from `cgutil`. Of note is that any Bfile handles opened using cgutil will be cleaned up for you if the user exits the addin.  
   It is **not** recommended to override the quit handler using the normal syscall.  
   Instead, to set your own, you can create a function `pub fn quit_handler() void { ... }` in the root of your project, which will be called on quit (before any cleanup functions are called).
