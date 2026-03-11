package nixfetch

import "core:os"
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
	fetch_fields := FetchFields {
		user_info     = get_username_and_hostname(),
		os_name       = get_osname(),
		host_info     = get_host_info(),
		kernel_info   = get_kernel_info(),
		shell_info    = get_shell_info(),
		desktop_info  = get_desktop_info(),
		uptime        = get_uptime(),
		memory_info   = get_memory_info(),
		swap_info     = get_swap_info(),
		terminal_info = get_terminal_info(),
		colors        = get_colored_dots(),
	}

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

	// use kitty graphics protocol to display the image if the terminal supports it
	// otherwise fall back to the ansi colored nix logo
	if nixfetch_image_found &&
	   nixfetch_image_value != "" &&
	   (fetch_fields.terminal_info == "ghostty" || fetch_fields.terminal_info == "kitty") {
		pretty_print(&fetch_fields, nixfetch_image_value)
	} else {
		pretty_print(&fetch_fields)
	}

}
