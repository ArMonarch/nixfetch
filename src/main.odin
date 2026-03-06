package nixfetch

// struct to hold all the fields we need in order to print the fetch.
FetchFields :: struct {
	user_info:    string,
	os_name:      string,
	host_info:    string,
	kernel_info:  string,
	shell_info:   string,
	desktop_info: string,
	uptime:       string,
	memory_info:  string,
	swap_info:    string,
	colors:       string,
}

// collect all system info and print the fetch output
main :: proc() {
	fetch_fields := FetchFields {
		user_info    = get_username_and_hostname(),
		os_name      = get_osname(),
		host_info    = get_host_info(),
		kernel_info  = get_kernel_info(),
		shell_info   = get_shell_info(),
		desktop_info = get_desktop_info(),
		uptime       = get_uptime(),
		memory_info  = get_memory_info(),
		swap_info    = get_swap_info(),
		colors       = get_colored_dots(),
	}

	print_fetch_fields(&fetch_fields)
}
