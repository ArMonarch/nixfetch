package nixfetch

import "core:os"
import "core:sys/linux"

// struct to hold all the fields we need in order to print the fetch.
FetchFields :: struct {
	user_info:     string,
	os_name:       string,
	host_info:     string,
	kernel_info:   string,
	shell_info:    string,
	desktop_info:  string,
	uptime:        string,
	memory_info:   string,
	swap_info:     string,
	terminal_info: string,
	colors:        string,
}

// collect all system info and print the fetch output
main :: proc() {
	// get hostname via uname syscall
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)

	// gather all system info into fetch fields; drop() frees all heap allocations on exit
	ffields: FetchFields
	new_ffields(&ffields, &uts_name)
	defer drop(&ffields)

	// if environment variable `NIXFETCH_IMAGE=(image path)` is set
	// then the programs tries to output fetch information with the image
	// with kitty graphics protocol
	// this also checks if the terminal supports the kitty graphics protocol
	// if the terminal doesn't support kitty graphics protocol it fall backs
	// to printing ansi nixos logo
	nixfetch_image_value, nixfetch_image_found := os.lookup_env(
		"NIXFETCH_IMAGE",
		context.allocator,
	)
	defer delete(nixfetch_image_value)

	// use kitty graphics protocol to display the image if the terminal supports it
	// otherwise fall back to the ansi colored nix logo
	if nixfetch_image_found &&
	   nixfetch_image_value != "" &&
	   (ffields.terminal_info == "ghostty" || ffields.terminal_info == "kitty") {
		pretty_print(&ffields, nixfetch_image_value)
	} else {
		pretty_print(&ffields)
	}
}
