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
LINKER :: "lld"

// Every flag takes a value; `-help` is the only switch and is handled on its own.
Flag :: struct {
	name:    string,
	arg:     string,
	// Empty means any value is accepted.
	allowed: []string,
	help:    string,
}

Command :: struct {
	name:     string,
	blurb:    string,
	pos:      string,
	pos_help: string,
	flags:    []Flag,
	run:      proc(p: ^Parse) -> int,
}

// Flag values are keyed by name: `-out:target/x` is values["out"] = "target/x".
Parse :: struct {
	positional: string,
	values:     map[string]string,
	help:       bool,
}

// Mirrors the compiler's grammar: `<command> [package] [flags...]`. The positional has to
// come first, as with `odin build`, since the first token is taken as the path whatever it
// looks like.
parse :: proc(cmd: ^Command, args: []string) -> (p: Parse, ok: bool) {
	args := args

	if len(args) > 0 && !strings.has_prefix(args[0], "-") && cmd.pos != "" {
		p.positional = args[0]
		args = args[1:]
	}

	for arg in args {
		if !strings.has_prefix(arg, "-") {
			fmt.eprintfln("Invalid flag: %s", arg)
			return p, false
		}

		body := arg[1:]
		if body == "help" {
			p.help = true
			return p, true
		}

		// The compiler accepts either `:` or `=` as the separator, so this does too.
		name, value := body, ""
		if index := strings.index_any(body, ":="); index >= 0 {
			name, value = body[:index], body[index + 1:]
		}

		flag := find_flag(cmd, name)
		if flag == nil {
			fmt.eprintfln("Unknown flag: '%s'", name)
			return p, false
		}
		if value == "" {
			fmt.eprintfln("Flag missing value: '%s'", name)
			return p, false
		}
		if len(flag.allowed) > 0 && !slice.contains(flag.allowed, value) {
			fmt.eprintfln("Invalid value for -%s:%s, got %s", name, flag.arg, value)
			fmt.eprintfln("Valid options:")
			for option in flag.allowed do fmt.eprintfln("\t%s", option)
			return p, false
		}
		// A repeated flag is a mistake, not something for the map to silently overwrite.
		if name in p.values {
			fmt.eprintfln("Flag set twice: '%s'", name)
			return p, false
		}

		p.values[name] = value
	}

	return p, true
}

find_flag :: proc(cmd: ^Command, name: string) -> ^Flag {
	for &flag in cmd.flags {
		if flag.name == name do return &flag
	}
	return nil
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

// Output goes to TARGET/<level>, one directory per optimization level, so builds sit side
// by side instead of overwriting one another.
cmd_build :: proc(p: ^Parse) -> int {
	out := fmt.tprintf("%s/%s", TARGET, p.values["o"] or_else "debug")
	if !os.exists(out) {
		if err := os.make_directory_all(out); err != nil {
			fmt.eprintfln("could not create %s: %v", out, err)
			return 1
		}
	}

	command := compiler_command("build", p)
	append(&command, fmt.tprintf("-out:%s/%s", out, NAME))
	return run(..command[:])
}

// `odin run` deletes the executable on exit, so nothing is written to TARGET.
cmd_run :: proc(p: ^Parse) -> int {
	command := compiler_command("run", p)
	return run(..command[:])
}

cmd_clean :: proc(p: ^Parse) -> int {
	path := TARGET
	if p.positional != "" {
		// A level is a single directory name; anything else could walk out of TARGET.
		if strings.contains(p.positional, "/") || p.positional == ".." {
			fmt.eprintfln("Invalid level: %s", p.positional)
			return 1
		}
		path = fmt.tprintf("%s/%s", TARGET, p.positional)
	}

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

// The flags shared by `build` and `run`, built in one place so the two cannot drift apart.
// No -o is a debug build.
compiler_command :: proc(verb: string, p: ^Parse) -> [dynamic]string {
	src := p.positional if p.positional != "" else SRC
	optimization := p.values["o"] or_else "debug"
	link := p.values["link"] or_else "dynamic"

	command := make([dynamic]string, context.temp_allocator)
	append(&command, "odin", verb, src)
	switch optimization {
	case "debug":
		append(&command, "-debug")
	case "speed", "size", "aggressive":
		append(&command, fmt.tprintf("-o:%s", optimization))
		append(&command, "-disable-assert", "-no-bounds-check")
	case:
		append(&command, fmt.tprintf("-o:%s", optimization))
	}
	when ODIN_OS == .Darwin do append(&command, "-use-single-module")
	append(&command, "-linker:" + LINKER)
	// Static pulls libc into the binary, so it runs on any Linux of its architecture, not
	// only on systems with the glibc it was built against.
	if link == "static" do append(&command, "-extra-linker-flags:-static")
	return command
}

commands :: proc() -> []Command {
	PACKAGE :: "The package defaults to '" + SRC + "' when omitted."

	BUILD_FLAGS :: []Flag {
		{
			name = "o",
			arg = "<level>",
			allowed = []string{"none", "minimal", "size", "speed", "aggressive"},
			help = "Sets the optimization mode, defaulting to a debug build.",
		},
		{
			name = "link",
			arg = "<mode>",
			allowed = []string{"dynamic", "static"},
			help = "Links libc dynamically or statically, defaulting to dynamic.",
		},
	}

	@(static) table := [?]Command {
		{
			name = "build",
			blurb = "Compiles " + NAME + " as an executable.",
			pos = "package",
			pos_help = PACKAGE,
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
			pos_help = "Removes only '" + TARGET + "/<level>' when given, all of it when not.",
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
	for cmd in commands() do fmt.eprintfln("\t%-10s %s", cmd.name, cmd.blurb)
	fmt.eprintfln("")
	fmt.eprintfln("For further details on a command, invoke command help:")
	fmt.eprintfln("\te.g. `odin run build.odin -file -- build -help`")
}

print_command_help :: proc(cmd: ^Command) {
	fmt.eprintfln("Usage:")
	fmt.eprintfln("\todin run build.odin -file -- %s <%s> [arguments]", cmd.name, cmd.pos)
	fmt.eprintfln("")
	fmt.eprintfln("\t%s\t%s", cmd.name, cmd.blurb)
	fmt.eprintfln("\t\t%s", cmd.pos_help)

	for flag in cmd.flags {
		fmt.eprintfln("")
		fmt.eprintfln("\t-%s:%s", flag.name, flag.arg)
		fmt.eprintfln("\t\t%s", flag.help)
		if len(flag.allowed) > 0 {
			fmt.eprintfln("\t\tAvailable options:")
			for option in flag.allowed do fmt.eprintfln("\t\t\t-%s:%s", flag.name, option)
		}
	}
}

// Exits with the command's status, so a failed compile fails the nix build that runs this.
main :: proc() {
	if len(os.args) < 2 {
		print_usage()
		os.exit(1)
	}

	name := os.args[1]
	for &cmd in commands() {
		if cmd.name != name do continue

		p, ok := parse(&cmd, os.args[2:])
		if !ok do os.exit(1)
		if p.help {
			print_command_help(&cmd)
			return
		}
		os.exit(cmd.run(&p))
	}

	fmt.eprintfln("unknown command: %s", name)
	fmt.eprintfln("")
	print_usage()
	os.exit(1)
}

// Echoes the command, then runs it with this process's stdio and returns its exit code.
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
