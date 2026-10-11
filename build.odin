// nixfetch's build script, written in Odin itself.
//
//   odin run build.odin -file -- <command> [arguments]
package main

import "core:flags"
import "core:fmt"
import "core:os"
import "core:strings"

// odinfmt: disable
NAME   :: "nixfetch"
SRC    :: "src"
TARGET :: "target"
LINKER :: "lld"
// odinfmt: enable

// Enum member names are the accepted values, matched exactly: -o:speed.
Optimization :: enum {
	debug, // zero value, so leaving -o off is a debug build
	minimal,
	size,
	speed,
	aggressive,
}

Build :: struct {
	o:      Optimization `usage:"Sets the optimization mode: minimal, size, speed or aggressive, defaulting to debug."`,
	layout: int `usage:"Sets the layout nixfetch prints: 110, 252, 269 or 227, defaulting to 110."`,
	static: bool `usage:"Links libc statically, so the binary runs on any Linux of its architecture."`,
	icons:  bool `usage:"Prints a nerd font icon before each label, off unless given."`,
}

Run :: struct {
	o:      Optimization `usage:"Sets the optimization mode: minimal, size, speed or aggressive, defaulting to debug."`,
	layout: int `usage:"Sets the layout nixfetch prints: 110, 252, 269 or 227, defaulting to 110."`,
	static: bool `usage:"Links libc statically, so the binary runs on any Linux of its architecture."`,
	icons:  bool `usage:"Prints a nerd font icon before each label, off unless given."`,
}

Clean :: struct {
	level: Optimization `usage:"Removes only 'target/<level>': debug, minimal, size, speed or aggressive."`,
	all:   bool `usage:"Removes all of 'target'."`,
}

// args[0] is the command's name, which parse_or_exit uses as the program name in its usage and
// errors. On -help it prints the usage and exits 0; on a bad flag, the error and exits 1.
//
// Output goes to TARGET/<level>, one directory per optimization level, so builds sit side
// by side instead of overwriting one another.
cmd_build :: proc(args: []string) -> int {
	opt: Build
	flags.parse_or_exit(&opt, args, .Odin)

	command := compiler_command("build", opt)

	out := fmt.tprintf("%s/%v", TARGET, opt.o)
	if !os.exists(out) {
		if err := os.make_directory_all(out); err != nil {
			fmt.eprintfln("could not create %s: %v", out, err)
			return 1
		}
	}

	append(&command, fmt.tprintf("-out:%s/%s", out, NAME))
	return run_command(..command[:])
}

// `odin run` deletes the executable on exit, so nothing is written to TARGET.
cmd_run :: proc(args: []string) -> int {
	opt: Run
	flags.parse_or_exit(&opt, args, .Odin)

	command := compiler_command("run", opt)
	return run_command(..command[:])
}

// Removes TARGET/<level>, debug when -level is left off, or all of TARGET with -all.
cmd_clean :: proc(args: []string) -> int {
	opt: Clean
	flags.parse_or_exit(&opt, args, .Odin)

	path := TARGET if opt.all else fmt.tprintf("%s/%v", TARGET, opt.level)
	if !os.exists(path) {
		fmt.printfln("nothing to clean at %s", path)
		return 0
	}

	fmt.printfln("\x1b[90m> rm -r %s\x1b[0m", path)
	if err := os.remove_all(path); err != nil {
		fmt.eprintfln("could not remove %s: %v", path, err)
		return 1
	}
	return 0
}

Command :: struct {
	name:  string,
	blurb: string,
	run:   proc(args: []string) -> int,
}

COMMANDS :: []Command {
	{"build", "Compiles " + NAME + " as an executable.", cmd_build},
	{"run", "Same as 'build', but runs the executable instead of keeping it.", cmd_run},
	{"clean", "Removes build output from '" + TARGET + "'.", cmd_clean},
}

print_usage :: proc() {
	fmt.eprintfln("Usage:\n\todin run build.odin -file -- <command> [arguments]")
	fmt.eprintfln("Commands:")
	for cmd in COMMANDS do fmt.eprintfln("\t%-10s %s", cmd.name, cmd.blurb)
}

// Each command gets its own name as args[0], the program name for its usage and errors.
// Exits with the command's status, so a failed compile fails the nix build that runs this.
main :: proc() {
	flags.register_flag_checker(check_flag)

	if len(os.args) < 2 {
		print_usage()
		os.exit(1)
	}

	name := os.args[1]
	if name == "-help" || name == "help" {
		print_usage()
		return
	}

	for cmd in COMMANDS {
		if name != cmd.name do continue
		exit_code := cmd.run(os.args[1:])
		os.exit(exit_code)
	}

	fmt.eprintfln("unknown command: %s\n", name)
	print_usage()
	os.exit(1)
}

// The flags shared by `build` and `run`, built in one place so the two cannot drift apart.
// Takes either's options, which share the o, layout and static fields.
compiler_command :: proc(verb: string, opt: $T) -> (command: [dynamic]string) {
	command = make([dynamic]string, context.temp_allocator)
	append(&command, "odin", verb, SRC)
	switch opt.o {
	case .debug:
		append(&command, "-debug")
	case .minimal:
		append(&command, "-o:minimal")
	case .size, .speed, .aggressive:
		append(&command, fmt.tprintf("-o:%v", opt.o))
		append(&command, "-disable-assert", "-no-bounds-check")
	}
	when ODIN_OS == .Darwin do append(&command, "-use-single-module")
	append(&command, "-linker:" + LINKER)
	// Static pulls libc into the binary, so it runs on any Linux of its architecture, not
	// only on systems with the glibc it was built against.
	if opt.static do append(&command, "-extra-linker-flags:-static")

	// nixfetch's own compile-time settings, see the #config values in src/lib.odin. Layout 0
	// is the flag left off, which leaves nixfetch's own default; check_flag vets the rest.
	if opt.layout != 0 do append(&command, fmt.tprintf("-define:NIXFETCH_LAYOUT=%d", opt.layout))
	append(&command, fmt.tprintf("-define:NIXFETCH_ICONS=%v", opt.icons))
	return command
}

// Registered with core:flags, which calls it for each flag that was set, after its own
// checks. A non-empty return is the error parse_or_exit prints before exiting 1.
check_flag :: proc(model: rawptr, name: string, value: any, args_tag: string) -> (error: string) {
	switch name {
	case "layout":
		switch value.(int) {
		case 110, 252, 269, 227:
		case:
			return fmt.tprintf("Invalid layout: %v, valid layouts are 110, 252, 269 and 227", value)
		}
	}
	return
}

// Echoes the command, then runs it with this process's stdio and returns its exit code.
run_command :: proc(args: ..string) -> int {
	fmt.printfln("\x1b[90m> %s\x1b[0m", strings.join(args, " ", context.temp_allocator))

	desc := os.Process_Desc {
		command = args,
		stdin   = os.stdin,
		stdout  = os.stdout,
		stderr  = os.stderr,
	}

	process, start_err := os.process_start(desc)
	if start_err != nil {
		fmt.eprintfln("could not launch %s: %v", args[0], start_err)
		return 1
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("could not wait on %s: %v", args[0], wait_err)
		return 1
	}

	return state.exit_code
}
