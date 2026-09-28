package nixfetch

import "base:runtime"
import "core:mem"
import "core:os"
import "core:strings"
import "core:sys/linux"

// every allocation of the run comes out of this one block, freed once at exit;
// the kernel only backs the pages that actually get touched
ARENA_SIZE :: 8 * mem.Megabyte

main :: proc() {
	backing, err := mem.alloc_bytes_non_zeroed(ARENA_SIZE, allocator = runtime.heap_allocator())
	if err != nil do os.exit(1)
	defer mem.free_bytes(backing, runtime.heap_allocator())

	arena: mem.Arena
	mem.arena_init(&arena, backing)
	context.allocator = mem.arena_allocator(&arena)
	context.temp_allocator = context.allocator

	sys: System
	collect(&sys)
	lines := layout_lines(&sys)

	// the whole fetch goes out in a single write, unless the pipe takes it in parts
	b := strings.builder_make()
	render(&b, lines[:])
	out := b.buf[:]
	for len(out) > 0 {
		n, errno := linux.write(linux.Fd(1), out)
		if errno == .EINTR do continue
		if errno != .NONE do os.exit(1)
		out = out[n:]
	}
}
