package nixfetch

import "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:terminal/ansi"

// ANSI foreground color escape sequences
FG_BLACK :: "\x1b[" + ansi.FG_BLACK + "m"
FG_RED :: "\x1b[" + ansi.FG_RED + "m"
FG_GREEN :: "\x1b[" + ansi.FG_GREEN + "m"
FG_YELLOW :: "\x1b[" + ansi.FG_YELLOW + "m"
FG_BLUE :: "\x1b[" + ansi.FG_BLUE + "m"
FG_MAGENTA :: "\x1b[" + ansi.FG_MAGENTA + "m"
FG_CYAN :: "\x1b[" + ansi.FG_CYAN + "m"
FG_WHITE :: "\x1b[" + ansi.FG_WHITE + "m"

// resets terminal color back to default
FG_RESET :: "\x1b[" + ansi.RESET + "m"


// returns colored "user@hostname~" string
get_username_and_hostname :: proc(allocator := context.allocator) -> string {
	username: string
	if value, found := os.lookup_env("USER", allocator); found == true {
		username = value
	} else {
		username = strings.clone("unknown")
	}
	defer delete(username)

	// get hostname via uname syscall
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)

	hostname := strings.clone_from_cstring(cstring(&uts_name.nodename[0]))
	defer delete(hostname)

	cap := 5 + len(username) + 1 + 5 + len(hostname) + 4 + 1
	result := strings.builder_make(len = 0, cap = cap)
	// build colored "user@hostname~" output
	strings.write_string(&result, FG_YELLOW)
	strings.write_string(&result, username)
	strings.write_rune(&result, '@')
	strings.write_string(&result, FG_GREEN)
	strings.write_string(&result, hostname)
	strings.write_string(&result, "\x1b[" + ansi.RESET + "m")
	strings.write_rune(&result, '~')

	return strings.to_string(result)
}

// reads PRETTY_NAME from /etc/os-release
get_osname :: proc(allocator := context.allocator) -> string {
	data, err := os.read_entire_file("/etc/os-release", allocator)
	if err != nil {
		return strings.clone("unknown")
	}
	defer delete(data)
	content := string(data)

	occurance_index := strings.index(content[:], "PRETTY_NAME=")
	if occurance_index == -1 {
		return strings.clone("unknown")
	}

	breakline_occurance_index := occurance_index
	for ; content[breakline_occurance_index] != '\n'; breakline_occurance_index += 1 {}

	result := strings.clone(content[occurance_index + 13:breakline_occurance_index - 1])
	return result
}

// returns "product_name (product_family)" from DMI sysfs
get_host_info :: proc(allocator := context.allocator) -> string {
	product_name_data, product_name_err := os.read_entire_file(
		"/sys/devices/virtual/dmi/id/product_name",
		allocator,
	)
	if product_name_err != nil {
		return strings.clone("unknown")
	}
	defer delete(product_name_data)

	product_family_data, product_family_err := os.read_entire_file(
		"/sys/devices/virtual/dmi/id/product_family",
		context.allocator,
	)
	if product_family_err != nil {
		return strings.clone("unknown")
	}
	defer delete(product_family_data)

	result := strings.builder_make(0, len(product_name_data) + len(product_family_data) + 3)
	strings.write_string(&result, string(product_name_data[0:len(product_name_data) - 1]))
	strings.write_string(&result, " (")
	strings.write_string(&result, string(product_family_data[0:len(product_family_data) - 1]))
	strings.write_string(&result, ")")
	return strings.to_string(result)
}

// returns "sysname release (machine)" via uname syscall
get_kernel_info :: proc() -> string {
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)

	system := string(cstring(&uts_name.sysname[0]))
	release := string(cstring(&uts_name.release[0]))
	machine := string(cstring(&uts_name.machine[0]))

	result := strings.builder_make(0, len(system) + len(release) + len(machine) + 4)
	strings.write_string(&result, system)
	strings.write_rune(&result, ' ')
	strings.write_string(&result, release)
	strings.write_string(&result, " (")
	strings.write_string(&result, machine)
	strings.write_string(&result, ")")

	return strings.to_string(result)
}

// returns "desktop_name (session_type)" from XDG env vars
get_desktop_info :: proc(allocator := context.allocator) -> string {
	session: string
	defer delete(session)

	if value, success := os.lookup_env("XDG_CURRENT_DESKTOP", allocator); success != true {
		session = strings.clone("unknown", allocator)
	} else {
		session = value
	}

	desktop: string
	defer delete(desktop)
	if value, success := os.lookup_env("XDG_SESSION_TYPE", allocator); success != true {
		desktop = strings.clone("unknown", allocator)
	} else {
		desktop = value
	}

	result := strings.builder_make(0, len(session) + len(desktop) + 3)
	strings.write_string(&result, session)
	strings.write_string(&result, " (")
	strings.write_string(&result, desktop)
	strings.write_string(&result, ")")
	return strings.to_string(result)
}


// returns shell name (basename of $SHELL)
get_shell_info :: proc() -> string {
	shell_path: string
	if value, success := os.lookup_env("SHELL", context.allocator); success != true {
		return strings.clone("unknown")
	} else {
		shell_path = value
	}
	defer delete(shell_path)

	// extract shell name from path
	last_slash := strings.last_index(shell_path, "/")
	shell_name := last_slash >= 0 ? shell_path[last_slash + 1:] : shell_path

	return strings.clone(shell_name)
}

// returns system uptime via sysinfo syscall, formatted as "Xd, Xh, Xm"
get_uptime :: proc() -> string {
	info: linux.Sys_Info
	if err := linux.sysinfo(&info); err != .NONE {
		return strings.clone("infinity")
	}

	// convert total seconds into days, hours, minutes
	days := info.uptime / 86400
	hours := (info.uptime / 3600) % 24
	mins := (info.uptime / 60) % 60

	result := strings.builder_make(0, 32)

	if days > 0 {
		strings.write_int(&result, days)
		strings.write_string(&result, days == 1 ? " day" : "days")
	}

	if hours > 0 {
		if len(result.buf) != 0 {
			strings.write_string(&result, ", ")
		}
		strings.write_int(&result, hours)
		strings.write_string(&result, hours == 1 ? " hour" : " hours")
	}

	if mins > 0 {
		if len(result.buf) != 0 {
			strings.write_string(&result, ", ")
		}
		strings.write_int(&result, mins)
		strings.write_string(&result, mins == 1 ? " minute" : " minutes")
	}

	if len(result.buf) == 0 {
		strings.write_string(&result, "less than a minute")
	}

	return strings.to_string(result)
}

// parses a kB value from a /proc/meminfo line like "MemTotal:       16384000 kB"
parse_meminfo_value :: proc(content: string, key: string) -> int {
	idx := strings.index(content, key)
	if idx == -1 {
		return -1
	}

	// skip past the key
	start := idx + len(key)

	// skip whitespace
	for start < len(content) && content[start] == ' ' {
		start += 1
	}

	// read digits
	end := start
	for end < len(content) && content[end] >= '0' && content[end] <= '9' {
		end += 1
	}

	if start == end {
		return -1
	}

	// parse the number
	value := 0
	for i := start; i < end; i += 1 {
		value = value * 10 + int(content[i] - '0')
	}

	return value
}

// returns "used MiB / total MiB" from /proc/meminfo
get_memory_info :: proc() -> string {
	fd, err := os.open("/proc/meminfo", os.O_RDONLY)
	if err != os.ERROR_NONE {
		return strings.clone("unknown")
	}
	defer os.close(fd)

	buf: [2096]byte
	n, read_err := os.read(fd, buf[:])
	if read_err != os.ERROR_NONE || n == 0 {
		return strings.clone("unknown")
	}

	content := string(buf[:n])

	total_kb := parse_meminfo_value(content, "MemTotal:")
	available_kb := parse_meminfo_value(content, "MemAvailable:")

	if total_kb < 0 || available_kb < 0 {
		return strings.clone("unknown")
	}

	used_gib := f64(total_kb - available_kb) / f64(1024 * 1024)
	total_gib := f64(total_kb) / f64(1024 * 1024)
	percentage_use := (used_gib / total_gib) * 100

	return fmt.aprintf("%.2f GiB / %.2f GiB (%.0f%%)", used_gib, total_gib, percentage_use)
}

// returns "used GiB / total GiB (X%)" from /proc/meminfo swap fields
get_swap_info :: proc() -> string {
	fd, err := os.open("/proc/meminfo", os.O_RDONLY)
	if err != os.ERROR_NONE {
		return strings.clone("unknown")
	}
	defer os.close(fd)

	buf: [2096]byte
	n, read_err := os.read(fd, buf[:])
	if read_err != os.ERROR_NONE || n == 0 {
		return strings.clone("unknown")
	}

	content := string(buf[:n])

	total_kb := parse_meminfo_value(content, "SwapTotal:")
	free_kb := parse_meminfo_value(content, "SwapFree:")

	if total_kb < 0 || free_kb < 0 {
		return strings.clone("unknown")
	}

	if total_kb == 0 {
		return strings.clone("N/A")
	}

	used_gib := f64(total_kb - free_kb) / f64(1024 * 1024)
	total_gib := f64(total_kb) / f64(1024 * 1024)
	percentage_use := (used_gib / total_gib) * 100

	return fmt.aprintf("%.2f GiB / %.2f GiB (%.0f%%)", used_gib, total_gib, percentage_use)
}

// returns terminal name from TERM_PROGRAM env var
get_terminal_info :: proc() -> string {
	if value, found := os.lookup_env("TERM_PROGRAM", context.allocator); found {
		return value
	}
	return strings.clone("unknown")
}

// returns a row of 6 colored dot glyphs
get_colored_dots :: proc() -> string {
	GLYPH :: "  "
	// final capacity:
	// GLYPH * 6,
	// 6 ansi_colors (5 bytes each: \x1b[XXm),
	// 1 ansi_reset (4 bytes: \x1b[0m)
	cap := (len(GLYPH) * 6) + (5 * 6) + 4
	result := strings.builder_make(len = 0, cap = cap)

	strings.write_string(&result, FG_RED + GLYPH)
	strings.write_string(&result, FG_YELLOW + GLYPH)
	strings.write_string(&result, FG_BLUE + GLYPH)
	strings.write_string(&result, FG_MAGENTA + GLYPH)
	strings.write_string(&result, FG_CYAN + GLYPH)
	strings.write_string(&result, FG_WHITE + GLYPH)
	strings.write_string(&result, FG_RESET)

	return strings.to_string(result)
}

get_fetch_fields_array :: proc(fetch_fields: ^FetchFields) -> [dynamic]string {
	KeyVal :: struct {
		label, value: string,
	}

	array := make([dynamic]string)
	user_info := strings.clone(fetch_fields.user_info)
	append(&array, user_info)

	fields := [?]KeyVal {
		{"OS", fetch_fields.os_name},
		{"Host", fetch_fields.host_info},
		{"Kernel", fetch_fields.kernel_info},
		{"Shell", fetch_fields.shell_info},
		{"Desktop", fetch_fields.desktop_info},
		{"Memory", fetch_fields.memory_info},
		{"Swap", fetch_fields.swap_info},
		{"Terminal", fetch_fields.terminal_info},
		{"Uptime", fetch_fields.uptime},
		{"Colors", fetch_fields.colors},
	}

	for f in fields {
		formatted_string := fmt.aprintf("%s%-8s %s : %s", FG_BLUE, f.label, FG_RESET, f.value)
		append(&array, formatted_string)
	}

	return array
}

// prints all fetch fields formatted inside the NixOS logo
pretty_print_fetch_fields_with_logo :: proc(fetch_fields: ^FetchFields) {
	buffer := strings.builder_make(0, 4096)
	defer strings.builder_destroy(&buffer)
	nix_logo := nix_logo_ansi_colored()
	defer delete(nix_logo)
	fetch_array := get_fetch_fields_array(fetch_fields)
	defer delete(fetch_array)
	defer drop(&fetch_array)

	min_len := min(len(nix_logo), len(fetch_array))

	// Print logo lines side by side with fetch fields
	for index in 0 ..< min_len {
		strings.write_string(&buffer, nix_logo[index])
		strings.write_string(&buffer, fetch_array[index])
		strings.write_string(&buffer, "\n")
	}

	// Print remaining logo lines if the logo is taller than the fetch fields
	for index in min_len ..< len(nix_logo) {
		strings.write_string(&buffer, nix_logo[index])
		strings.write_string(&buffer, "\n")
	}

	// Print remaining fetch fields with padding if there are more fields than logo lines
	for index in min_len ..< len(fetch_array) {
		for _ in 0 ..< APPRENT_WIDTH {
			strings.write_string(&buffer, " ")
		}
		strings.write_string(&buffer, fetch_array[index])
		strings.write_string(&buffer, "\n")
	}

	fmt.println(strings.to_string(buffer))
}

// prints fetch fields with a custom image using the kitty graphics protocol
// falls back to the logo variant if the image path is invalid
pretty_print_fetch_fields_with_image :: proc(fetch_fields: ^FetchFields, image_path: string) {
	if !os.is_file(image_path) {
		fmt.println("Error: NIXFETCH_IMAGE is not a valid file")
		pretty_print(fetch_fields)
		return
	}

	if !strings.has_suffix(image_path, ".png") {
		fmt.println("Error: NIXFETCH_IMAGE must be a png image")
		pretty_print(fetch_fields)
		return
	}

	// base64 encode the file path for the kitty graphics protocol
	encoded_path, err := base64.encode(transmute([]byte)image_path)
	if err != nil {
		return
	}
	defer delete(encoded_path)

	array := get_fetch_fields_array(fetch_fields)
	defer delete(array)
	defer drop(&array)

	fmt.print("\n")
	// print fetch fields first, padded left to leave space for the image
	for item in array {
		for _ in 0 ..< APPRENT_WIDTH {
			fmt.print(" ")
		}
		fmt.println(item)
	}

	// move cursor back to the top and render the image via kitty graphics protocol
	fmt.printf("\x1b[%dA", len(array))
	fmt.printfln("  \x1b_Ga=T,f=100,t=f,c=%d;%s\x1b\\", APPRENT_WIDTH - 5, encoded_path)
}

// overloaded proc: dispatches to logo or image variant based on arguments
pretty_print :: proc {
	pretty_print_fetch_fields_with_logo,
	pretty_print_fetch_fields_with_image,
}

drop_fetch_fields :: proc(fetch_fields: ^FetchFields) {
	// delete all fetch_fields values
	defer delete(fetch_fields.user_info)
	defer delete(fetch_fields.os_name)
	defer delete(fetch_fields.host_info)
	defer delete(fetch_fields.kernel_info)
	defer delete(fetch_fields.shell_info)
	defer delete(fetch_fields.desktop_info)
	defer delete(fetch_fields.memory_info)
	defer delete(fetch_fields.swap_info)
	defer delete(fetch_fields.terminal_info)
	defer delete(fetch_fields.uptime)
	defer delete(fetch_fields.colors)
}

drop_array_strings :: proc(array: ^[dynamic]string) {
	for val in array {
		delete(val)
	}
}

drop :: proc {
	drop_fetch_fields,
	drop_array_strings,
}
