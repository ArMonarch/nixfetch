package nixfetch

// struct to hold all the fields we need in order to print the fetch.
FetchFields :: struct {
	user_info:    string,
	os_name:      string,
	host_info:    string,
	kernel_info:  string,
	memory_info:  string,
	swap_info:    string,
	desktop_info: string,
	colors:       string,
}

main :: proc() {
	fetch_fields := FetchFields {
		user_info = get_username_and_hostname(),
		os_name   = get_osname(),
		host_info = get_host_info(),
		colors    = get_colored_dots(),
	}

	print_fetch_fields(&fetch_fields)
}
