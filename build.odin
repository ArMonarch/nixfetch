// nixfetch's build script, written in Odin itself.
//
//   odin run build.odin -file -- <command> [arguments]
package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

NAME :: "nixfetch"
SRC :: "src"
TARGET :: "target"

// The justfile passed -linker:lld on every target; keep that the default and let
// -linker: override it rather than hardcoding lld into the command.
LINKER :: "lld"

// Every flag that was given, keyed by name: `-out:target/x` is values["out"] = "target/x",
// and a switch like `-vet` is values["vet"] = "".
Parse :: struct {
	positional: string,
	values:     map[string]string,
	help:       bool,
}

Flag :: struct {
	name:    string,
	kind:    enum {
		Nil,
		Enum,
		String,
	},
	arg:     string,
	allowed: []string,
	help:    string,
}

Command :: struct {
	name:     string,
	blurb:    string,
	pos:      string,
	pos_help: string,
	flags:    []Flag,
	run:      proc(cmd: ^Command, p: ^Parse),
}

// Mirrors the compiler's grammar: `<command> [package] [flags...]`. The package has to
// come before the flags — `odin build -debug src` is an error there too, because the
// first token after the command is taken as the path whatever it looks like.
parse :: proc(cmd: ^Command, args: []string) -> (p: Parse, ok: bool) {
	p.values = make(map[string]string, 8, context.allocator)
	args := args

	if len(args) > 0 && !strings.has_prefix(args[0], "-") {
		if cmd.pos == "" {
			fmt.eprintfln("Invalid flag: %s", args[0])
			return p, false
		}
		p.positional = args[0]
		args = args[1:]
	}

	for arg in args {
		// The positional is already gone, so anything left that is not a flag is one
		// argument too many.
		if !strings.has_prefix(arg, "-") {
			fmt.eprintfln("Invalid flag: %s", arg)
			return p, false
		}

		// Short-circuit when help is requested. Named results start zeroed, so this
		// has to say `true` — a bare `return` here reads as a parse failure.
		body := arg[1:]
		if body == "help" {
			p.help = true
			return p, true
		}

		name, text := body, ""
		has_value := false

		// The compiler splits a flag from its value on the first `:` or `=` and accepts
		// either, so `-out:x` and `-out=x` mean the same thing.
		if index := strings.index_any(body, ":="); index >= 0 {
			name, text = body[:index], body[index + 1:]
			has_value = true
		}

		flag := find_flag(cmd, name)
		if flag == nil {
			fmt.eprintfln("Unknown flag: '%s'", name)
			return p, false
		}

		if flag.kind == .Nil && has_value {
			fmt.eprintfln("Flag '%s' does not take a value", name)
			return p, false
		}

		// `-out` and `-out:` are both missing a value as far as the compiler is concerned.
		if flag.kind != .Nil && text == "" {
			fmt.eprintfln("Flag missing for '%s'", name)
			return p, false
		}

		if flag.kind == .Enum && !slice.contains(flag.allowed, text) {
			fmt.eprintfln("Invalid value for -%s:%s, got %s", name, flag.arg, text)
			fmt.eprintfln("Valid options:")
			for option in flag.allowed {
				fmt.eprintfln("\t%s", option)
			}
			return p, false
		}

		// No flag here is repeatable, so a second one is a mistake worth naming rather
		// than letting the map silently keep the last one.
		if name in p.values {
			fmt.eprintfln("Previous flag set: '%s'", name)
			return p, false
		}

		p.values[name] = text
	}

	return p, true
}

find_flag :: proc(cmd: ^Command, name: string) -> ^Flag {
	for &flag in cmd.flags {
		if flag.name == name {
			return &flag
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

// Compiles one package into TARGET/<level>, a directory per optimization level so builds
// sit side by side instead of overwriting one another. An absent -o is a debug build,
// which is what the justfile's default target did.
cmd_build :: proc(cmd: ^Command, parse: ^Parse) {
	src := SRC
	if parse.positional != "" do src = parse.positional
	optimization := parse.values["o"] or_else "debug"
	linker := parse.values["linker"] or_else LINKER
	out := fmt.tprintf("%s/%s", TARGET, optimization)
	if dir_err := create_dir(out); dir_err != nil {
		fmt.eprintfln("could not create %s: %v", out, dir_err)
		return
	}

	command := make([dynamic]string, 0, 8, context.allocator)
	append(&command, "odin", "build", src)
	if optimization == "debug" do append(&command, "-debug")
	if optimization != "debug" do append(&command, fmt.tprintf("-o:%s", optimization))
	if optimization == "speed" do append(&command, "-disable-assert", "-no-bounds-check")
	if optimization == "size" do append(&command, "-disable-assert", "-no-bounds-check")
	if optimization == "aggressive" do append(&command, "-disable-assert", "-no-bounds-check")
	when ODIN_OS == .Darwin do append(&command, "-use-single-module")
	append(&command, fmt.tprintf("-linker:%s", linker))
	append(&command, fmt.tprintf("-out:%s/%s", out, NAME))
	run(..command[:])
}

// Builds and runs in one step. `odin run` deletes the executable it makes on exit, so no
// -out: here and nothing written to TARGET — `build` is the command for when the binary
// itself is the point.
cmd_run :: proc(cmd: ^Command, parse: ^Parse) {
	src := SRC
	if parse.positional != "" do src = parse.positional
	optimization := parse.values["o"] or_else "debug"
	linker := parse.values["linker"] or_else LINKER

	command := make([dynamic]string, 0, 8, context.allocator)
	append(&command, "odin", "run", src)
	if optimization == "debug" do append(&command, "-debug")
	if optimization != "debug" do append(&command, fmt.tprintf("-o:%s", optimization))
	if optimization == "speed" do append(&command, "-disable-assert", "-no-bounds-check")
	if optimization == "size" do append(&command, "-disable-assert", "-no-bounds-check")
	if optimization == "aggressive" do append(&command, "-disable-assert", "-no-bounds-check")
	when ODIN_OS == .Darwin do append(&command, "-use-single-module")
	append(&command, fmt.tprintf("-linker:%s", linker))
	run(..command[:])
}

// No level removes all of TARGET; a level removes just that one directory.
cmd_clean :: proc(cmd: ^Command, parse: ^Parse) {
	path := TARGET
	if parse.positional != "" {
		// A level is one directory name. A separator in it would let `clean` walk out
		// of TARGET, which is not something a build script should be removing.
		if strings.contains(parse.positional, "/") || parse.positional == ".." {
			fmt.eprintfln("Invalid level: %s", parse.positional)
			return
		}
		path = fmt.tprintf("%s/%s", TARGET, parse.positional)
	}

	if !os.exists(path) {
		fmt.printfln("nothing to clean at %s", path)
		return
	}

	fmt.printfln("\x1b[90m> rm -r %s\x1b[0m", path)
	if err := os.remove_all(path); err != nil {
		fmt.eprintfln("could not remove %s: %v", path, err)
	}
}

commands :: proc() -> []Command {
	PACKAGE :: "The package defaults to '" + SRC + "' when omitted."

	// Flags shared by everything that invokes the compiler, declared once so the commands
	// that hand them to it cannot drift apart. A constant slice, so the command table can
	// name it directly from its own initializer.
	BUILD_FLAGS :: []Flag {
		{
			name = "o",
			kind = .Enum,
			arg = "<level>",
			allowed = []string{"none", "minimal", "size", "speed", "aggressive"},
			help = "Sets the optimization mode for compilation.",
		},
		{
			name = "linker",
			kind = .String,
			arg = "<name>",
			help = "Sets the linker to use, defaulting to '" + LINKER + "'.",
		},
	}

	@(static) table := [?]Command {
		{
			name = "build",
			blurb = "Compiles " + NAME + " as an executable.",
			pos = "package",
			pos_help = "Every package under '" + SRC + "' is built when omitted.",
			flags = BUILD_FLAGS,
			run = cmd_build,
		},
		{
			name = "run",
			blurb = "Same as 'build', but runs the executable instead of keeping it.",
			pos = "package",
			pos_help = PACKAGE,
			flags = BUILD_FLAGS,
			run = cmd_run,
		},
		{
			name = "clean",
			blurb = "Removes build output from '" + TARGET + "'.",
			pos = "level",
			pos_help = "Removes only '" +
			TARGET +
			"/<level>' when given, all of '" +
			TARGET +
			"' when not.",
			run = cmd_clean,
		},
	}

	return table[:]
}

// ---------------------------------------------------------------------------
// Help
// ---------------------------------------------------------------------------

print_usage :: proc() {
	fmt.eprintfln("build.odin is a tool for building %s.", NAME)
	fmt.eprintfln("Usage:")
	fmt.eprintfln("\todin run build.odin -file -- command [arguments]")
	fmt.eprintfln("Commands:")
	for cmd in commands() {
		fmt.eprintfln("\t%-10s %s", cmd.name, cmd.blurb)
	}
	fmt.eprintfln("")
	fmt.eprintfln("For further details on a command, invoke command help:")
	fmt.eprintfln("\te.g. `odin run build.odin -file -- build -help`")
}

print_command_help :: proc(cmd: ^Command) {
	fmt.eprintfln("Usage:")
	fmt.eprintfln("\todin run build.odin -file -- %s <%s> [arguments]", cmd.name, cmd.pos)
	fmt.eprintfln("")
	fmt.eprintfln("\t%s\t%s", cmd.name, cmd.blurb)
	if cmd.pos_help != "" {
		fmt.eprintfln("\t\t%s", cmd.pos_help)
	}

	if len(cmd.flags) == 0 {
		return
	}

	fmt.eprintfln("")
	fmt.eprintfln("\tFlags")
	for flag in cmd.flags {
		// A value-carrying flag is written with the separator it is parsed with.
		if flag.arg != "" {
			fmt.eprintfln("\t-%s:%s", flag.name, flag.arg)
		} else {
			fmt.eprintfln("\t-%s", flag.name)
		}
		fmt.eprintfln("\t\t%s", flag.help)
		if flag.kind == .Enum {
			fmt.eprintfln("\t\tAvailable options:")
			for option in flag.allowed {
				fmt.eprintfln("\t\t\t-%s:%s", flag.name, option)
			}
		}
		fmt.eprintfln("")
	}
}

main :: proc() {
	table := commands()

	args := os.args[1:]
	if len(args) == 0 {
		print_usage(); return
	}

	name := args[0]
	rest := args[1:]

	for &cmd in table {
		if cmd.name != name do continue
		p, ok := parse(&cmd, rest)
		if !ok do return
		if p.help {
			print_command_help(&cmd); return
		}
		cmd.run(&cmd, &p)
		return
	}

	fmt.eprintfln("unknown command: %s", name)
	fmt.eprintfln("")
	print_usage()
}

// Echoes the command, then runs it with this process's stdio.
run :: proc(args: ..string) -> int {
	fmt.printfln("\x1b[90m> %s\x1b[0m", strings.join(args, " ", context.temp_allocator))

	desc := os.Process_Desc {
		command = args,
		stdin   = os.stdin,
		stdout  = os.stdout,
		stderr  = os.stderr,
	}

	process, start_err := os.process_start(desc)
	if start_err != nil {
		// valgrind and perf are not in the dev shell, so this is the likely path for
		// memcheck and profile rather than a genuine failure to fork.
		fmt.eprintfln("could not launch %s: %v", args[0], start_err)
		fmt.eprintfln("is %s installed and on PATH?", args[0])
		return 1
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("could not wait on %s: %v", args[0], wait_err)
		return 1
	}

	return state.exit_code
}

create_dir :: proc(path: string) -> (err: os.Error) {
	if os.exists(path) {
		return nil
	}

	os.make_directory_all(path) or_return
	return nil
}
