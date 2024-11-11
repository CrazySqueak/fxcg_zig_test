const std = @import("std");


// == Options (edit these if needed)
/// Name of the project (the g3a will be placed at the path zig-out/${PROJECT_NAME}.g3a)
const PROJECT_NAME = "skeleton";
/// Name of the project to display in the Main Menu
const PROJECT_NICE_NAME = "Zig Example";

/// Path to the GCC cross-compiler executable
const GCC_PATH = "../../toolchain/bin" ++ "/" ++ "sh3eb-elf-gcc";
/// Path to the mkg3a executable
const MKG3A_PATH = "../../toolchain/bin" ++ "/" ++ "mkg3a";

/// Path to the libfxcg include files
const LIBFXCG_INCLUDE_DIR = "../../libfxcg/include";
/// Path to the libfxcg lib files
const LIBFXCG_LIB_DIR = "../../libfxcg/lib";
/// Path to the libfxcg linker script
const LIBFXCG_LINKER_SCRIPT = "../../libfxcg/toolchain/prizm.x";


// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .powerpc,  // PowerPC is big-endian and 32-bit. close enough i guess
            .os_tag = .freestanding,  // Unsupported OS. syscalls provided by libfxcg
            .ofmt = .c,  // Output C code, to allow for cross-compilation using GCC (since LLVM doesn't support SH3)
        },
    });

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    
    // == Paths
    const gcc_exe = b.path(GCC_PATH);
    
    const libfxcg_include = b.path(LIBFXCG_INCLUDE_DIR);
    const libfxcg_lib = b.path(LIBFXCG_LIB_DIR);
    const libfxcg_linker_script = b.path(LIBFXCG_LINKER_SCRIPT);
    
    const cgutil_dir = b.path("../../cgutil");
    const cgutil_include = cgutil_dir;
    
    const zigstub_dir = b.path("../../zigstub");
    
    const zig_h_include = try fuckWhoeverDesignedZigDotH(b);
    const h_workaround_include = zigstub_dir.path(b,"missing_headers_workaround");
    
    const mkg3a_exe = b.path(MKG3A_PATH);
    
    // == GCC flags
    const GCC_BOTH_FLAGS = .{"-mb", "-m4a-nofpu", "-mhitachi", "-nostdlib", "-DTARGET_PRIZM=1"};
    const GCC_COMPILE_FLAGS = GCC_BOTH_FLAGS ++ .{"-Os","-Wall","-ffunction-sections","-fdata-sections","-flto"};
    const GCC_ZIG_COMPILE_FLAGS = GCC_COMPILE_FLAGS ++ .{"-Wno-all"};
    const GCC_LINK_FLAGS = GCC_BOTH_FLAGS ++ .{"-flto","-Wl,-static","-Wl,-gc-sections"};
    
    const GCC_INCLUDES = [_]std.Build.LazyPath{zig_h_include,libfxcg_include,cgutil_include};
    const GCC_LIB_NAMES = [_][]const u8{"c", "fxcg", "gcc"};
    
    // == Artifacts (generated C files)
    
    // fxcg_c (libfxcg c imports)
    const fxcg_c = b.createModule(.{ .root_source_file = zigstub_dir.path(b,"fxcg_c.zig") });
    fxcg_c.addIncludePath(libfxcg_include);
    // cgutil (cg utilities)
    const cgutil = b.createModule(.{ .root_source_file = cgutil_dir.path(b, "cgutil.zig") });
    cgutil.addIncludePath(libfxcg_include);
    cgutil.addIncludePath(cgutil_include);
    cgutil.addImport("fxcg_c", fxcg_c);
    
    // src/main
    const main = b.createModule(.{ .root_source_file = b.path("src/main.zig") });
    main.addIncludePath(libfxcg_include);
    main.addImport("fxcg_c", fxcg_c);
    main.addImport("cgutil", cgutil);
    
    // zig stub
    const zigstub = b.addObject(.{
        .name = "target",
        .root_source_file = zigstub_dir.path(b, "main.zig"),
        .target = target,
        .optimize = optimize,
    });
    zigstub.root_module.addImport("fxcg_c", fxcg_c);
    zigstub.root_module.addImport("cgutil", cgutil);
    zigstub.root_module.addImport("main", main);
    zigstub.linkLibC();
    
    main.addImport("zigstub", &zigstub.root_module);
    
    // == CROSS-COMPILATION // LINKING
    // Use GCC to compile the generated C code
    const gcc_compile = b.addSystemCommand(&[_][]const u8{gcc_exe.src_path.sub_path} ++ GCC_ZIG_COMPILE_FLAGS);
    for (&GCC_INCLUDES)|include| gcc_compile.addPrefixedDirectoryArg("-I",include);
    gcc_compile.addPrefixedDirectoryArg("-isystem",h_workaround_include);
    gcc_compile.addArg("-c"); gcc_compile.addArtifactArg(zigstub);
    gcc_compile.addArg("-o"); const gcc_compile_out = gcc_compile.addOutputFileArg("main.o");
    
    // Use GCC to compile the cgutil c code
    //const cgutil_gcc_compile = b.step("cgutil","Builds cgutil");
    var cgutil_member_objects = std.ArrayList(std.Build.LazyPath).init(b.allocator);
    inline for ([_][]const u8{"keyupdate.c","nonblockingdma.c","openmainmenu.c","rtc_datetime.c"}) |cgutil_member_name| {
        const in_file = cgutil_dir.path(b, cgutil_member_name);
        const out_filename = cgutil_member_name[0..(cgutil_member_name.len-2)] ++ ".o";
        
        const compile = b.addSystemCommand(&[_][]const u8{gcc_exe.src_path.sub_path} ++ GCC_COMPILE_FLAGS);
        for (&GCC_INCLUDES)|include| compile.addPrefixedDirectoryArg("-I",include);
        compile.addPrefixedDirectoryArg("-isystem",h_workaround_include);
        compile.addArg("-c"); compile.addFileArg(in_file);
        compile.addArg("-o"); const out_file = compile.addOutputFileArg(out_filename);
        
        //cgutil_gcc_compile.dependOn(&compile.step);
        try cgutil_member_objects.append(out_file);
    }
    
    // Use GCC to link the code together (alongside libfxcg)
    const gcc_link = b.addSystemCommand(&[_][]const u8{gcc_exe.src_path.sub_path} ++ GCC_LINK_FLAGS);
    gcc_link.addPrefixedFileArg("-T", libfxcg_linker_script);
    gcc_link.addFileArg(gcc_compile_out);
    for (cgutil_member_objects.items)|cgutil_item| gcc_link.addFileArg(cgutil_item);
    gcc_link.addPrefixedDirectoryArg("-L", libfxcg_lib);
    inline for (&GCC_LIB_NAMES)|lib_name| gcc_link.addArg("-l" ++ lib_name);
    gcc_link.addArg("-o"); const target_bin = gcc_link.addOutputFileArg(PROJECT_NAME ++ ".bin");
    
    // Use MKG3A to create the g3a addin file
    const mkg3a = b.addSystemCommand(&[_][]const u8{mkg3a_exe.src_path.sub_path, "-n", "basic:" ++ PROJECT_NICE_NAME});
    mkg3a.addArg("-i"); mkg3a.addPrefixedFileArg("uns:",b.path("unselected.bmp"));
    mkg3a.addArg("-i"); mkg3a.addPrefixedFileArg("sel:",b.path("selected.bmp"));
    mkg3a.addFileArg(target_bin);
    const output_g3a = mkg3a.addOutputFileArg(PROJECT_NAME ++ ".g3a");
    b.getInstallStep().dependOn(&b.addInstallFile(output_g3a, PROJECT_NAME ++ ".g3a").step);
}

fn fuckWhoeverDesignedZigDotH(b: *std.Build) !std.Build.LazyPath {
    const env_data = b.run(&.{"zig", "env"});
    
    const EnvStruct = struct { lib_dir: []const u8 };  // the only field we care about
    const json_data = try std.json.parseFromSlice(EnvStruct, b.allocator, env_data, .{ .ignore_unknown_fields = true });
    defer json_data.deinit();
    
    const lib_dir = json_data.value.lib_dir;
    const zig_h_dir = lib_dir;  // same dir
    return .{ .cwd_relative = zig_h_dir };
}