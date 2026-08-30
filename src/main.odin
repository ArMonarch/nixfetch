package nixfetch

import "core:os"

// struct to hold all the fields we need in order to print the fetch.
SystemInfo :: struct {
	user_info:       string,
	os_name:         string,
	host_info:       string,
	kernel_info:     string,
	shell_info:      string,
	desktop_info:    string,
	uptime:          string,
	cpu_info:        string,
	gpu_info:        string,
	memory_info:     string,
	swap_info:       string,
	filesystem_info: string,
	terminal_info:   string,
	colors:          string,
}

// collect all system info and print the fetch output
main :: proc() {
	// gather all system info into fetch fields; drop() frees all heap allocations on exit
	sysinfo: SystemInfo
	create_sysinfo(&sysinfo)
	defer destroy_sysinfo(&sysinfo)

	// if environment variable `NIXFETCH_IMAGE=(image path)` is set
	// then the programs tries to output fetch information with the image
	// with kitty graphics protocol
	nixfetch_image_value, nixfetch_image_found := os.lookup_env(
		"NIXFETCH_IMAGE",
		context.allocator,
	)
	defer delete(nixfetch_image_value)

	// use kitty graphics protocol to display the image if the terminal supports it
	// otherwise fall back to the ansi colored nix logo
	if nixfetch_image_found &&
	   nixfetch_image_value != "" &&
	   (sysinfo.terminal_info == "ghostty" || sysinfo.terminal_info == "kitty") {
		pretty_print_sysinfo(&sysinfo, nixfetch_image_value)
	} else {
		pretty_print_sysinfo(&sysinfo)
	}
}
