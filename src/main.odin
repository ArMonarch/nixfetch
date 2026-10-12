package nixfetch

import "core:fmt"
import "core:mem"
import "core:os"
import "core:terminal"

ARENA_SIZE :: 4 * mem.Megabyte

// zeroed .bss, so the kernel only backs the pages the arena actually touches; no allocation at startup
arena_buffer: [ARENA_SIZE]byte

Error :: enum {
	None,
	Arena_Out_Of_Memory,
}

main :: proc() {
	assert(terminal.color_enabled == true, "terminal must accept colors escape codes")

	arena: mem.Arena
	mem.arena_init(&arena, arena_buffer[:])
	context.allocator = mem.arena_allocator(&arena)
	context.temp_allocator = context.allocator

	if err := run(); err != nil {
		fmt.eprintfln("nixfetch: arena full, raise ARENA_SIZE")
		os.exit(1)
	}
}

run :: proc() -> Error {
	sys: SystemInformation
	collect_system_information(&sys) or_return
	str := print_system_information(&sys) or_return
	assert(len(str) != 0, "system information must not be nil")
	fmt.println(str)
	return nil
}
