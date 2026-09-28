package nixfetch

import "core:fmt"

main :: proc() {
	for str in NIX_LOGO_ANSI_COLORED {
		fmt.printfln("%s", str)
	}
}
