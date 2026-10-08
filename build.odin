// nixfetch's build script, written in Odin itself.
//
//   odin run build.odin -file -- <command> [arguments]
package main

import "core:fmt"
import "core:os"

NAME :: "nixfetch"
SRC :: "src"
TARGET :: "target"
LINKER :: "lld"

// Enum member names are the accepted values, matched exactly: -o:speed.
Optimization :: enum {
	debug, // zero value, so leaving -o off is a debug build
	minimal,
	size,
	speed,
	aggressive,
}

// Enum member names are the accepted values, matched exactly: -o:speed.
Link :: enum {
	Static,
	Dynamic,
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: build <build|run|clean> [arguments]")
		os.exit(1)
	}

	return
}
