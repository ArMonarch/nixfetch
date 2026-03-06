package nixfetch

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
get_username_and_hostname :: proc() -> string {
	username: string
	if value, found := os.lookup_env("USER"); found == true {
		username = value
	} else {
		username = "unknown_user"
	}

	// get hostname via uname syscall
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)
	hostname := strings.clone_from_cstring(cstring(&uts_name.nodename[0]))

	cap := 5 + len(username) + 1 + 5 + len(hostname) + 4 + 1
	result := strings.builder_make(len = 0, cap = cap)

	// build colored "user@hostname~" output
	strings.write_string(&result, FG_YELLOW)
	strings.write_string(&result, username)
	strings.write_rune(&result, '@')
	strings.write_string(&result, FG_GREEN)
	strings.write_string(&result, string(cstring(&uts_name.nodename[0])))
	strings.write_string(&result, "\x1b[" + ansi.RESET + "m")
	strings.write_rune(&result, '~')

	return strings.to_string(result)
}

// reads PRETTY_NAME from /etc/os-release
get_osname :: proc() -> string {
	data, success := os.read_entire_file("/etc/os-release")
	if success != true {
		return "unknown"
	}
	content := string(data)

	occurance_index := strings.index(content[:], "PRETTY_NAME=")
	if occurance_index == -1 {
		return "unknown"
	}

	breakline_occurance_index := occurance_index
	for ; content[breakline_occurance_index] != '\n'; breakline_occurance_index += 1 {}

	result := string(content[occurance_index + 13:breakline_occurance_index - 1])
	return result
}

// returns "product_name (product_family)" from DMI sysfs
get_host_info :: proc() -> string {
	product_name_data, success_product_name := os.read_entire_file(
		"/sys/devices/virtual/dmi/id/product_name",
	)
	if success_product_name != true {
		return "unknown"
	}

	product_family_data, success_product_family := os.read_entire_file(
		"/sys/devices/virtual/dmi/id/product_family",
	)
	if success_product_family != true {
		return "unknown"
	}

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
get_desktop_info :: proc() -> string {
	session: string

	if value, success := os.lookup_env("XDG_CURRENT_DESKTOP"); success != true {
		session = "unknown"
	} else {
		session = value
	}

	desktop: string
	if value, success := os.lookup_env("XDG_SESSION_TYPE"); success != true {
		desktop = "unknown"
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
	if value, success := os.lookup_env("SHELL"); success != true {
		return "unknown"
	} else {
		shell_path = value
	}

	// extract shell name from path
	last_slash := strings.last_index(shell_path, "/")
	shell_name := last_slash >= 0 ? shell_path[last_slash + 1:] : shell_path

	return shell_name
}

// returns system uptime via sysinfo syscall, formatted as "Xd, Xh, Xm"
get_uptime :: proc() -> string {
	info: linux.Sys_Info
	if err := linux.sysinfo(&info); err != .NONE {
		return "infinity"
	}

	// convert total seconds into days, hours, minutes
	days := info.uptime / 86400
	hours := (info.uptime / 3600) % 24
	mins := (info.uptime / 60) % 60

	result := strings.builder_make(0, 32)

	if days > 0 {
		strings.write_string(&result, fmt.aprint(days))
		strings.write_string(&result, days == 1 ? " day" : "days")
	}

	if hours > 0 {
		if len(result.buf) != 0 {
			strings.write_string(&result, ", ")
		}
		strings.write_string(&result, fmt.aprint(hours))
		strings.write_string(&result, hours == 1 ? " hour" : " hours")
	}

	if mins > 0 {
		if len(result.buf) != 0 {
			strings.write_string(&result, ", ")
		}
		strings.write_string(&result, fmt.aprint(mins))
		strings.write_string(&result, mins == 1 ? " minute" : " minutes")
	}

	if len(result.buf) == 0 {
		strings.write_string(&result, "less than a minute")
	}

	return strings.to_string(result)
}

// returns "used MiB / total MiB" from /proc/meminfo
get_memory_info :: proc() -> string {
	fd, err := os.open("/proc/meminfo", os.O_RDONLY)
	if err != os.ERROR_NONE {
		return "unknown"
	}
	defer os.close(fd)

	buf: [4096]byte
	n, read_err := os.read(fd, buf[:])
	if read_err != os.ERROR_NONE || n == 0 {
		return "unknown"
	}

	content := string(buf[:n])

	total_kb := parse_meminfo_value(content, "MemTotal:")
	available_kb := parse_meminfo_value(content, "MemAvailable:")

	if total_kb < 0 || available_kb < 0 {
		return "unknown"
	}

	used_gib := f64(total_kb - available_kb) / f64(1024 * 1024)
	total_gib := f64(total_kb) / f64(1024 * 1024)
	percentage_use := (used_gib / total_gib) * 100

	return fmt.aprintf("%f GiB / %f GiB (%.0f%%)", used_gib, total_gib, percentage_use)
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

// returns a row of 6 colored dot glyphs
get_colored_dots :: proc() -> string {
	GLYPH :: "  "
	// final capacity
	// GLYPH * 6,
	// 6 ansi_colors(4),
	// 1 ansi_reset(4)
	result := strings.builder_make(0, (len(GLYPH) * 6) + (4 * 6) + 4)

	strings.write_string(&result, FG_RED + GLYPH)
	strings.write_string(&result, FG_YELLOW + GLYPH)
	strings.write_string(&result, FG_BLUE + GLYPH)
	strings.write_string(&result, FG_MAGENTA + GLYPH)
	strings.write_string(&result, FG_CYAN + GLYPH)
	strings.write_string(&result, FG_WHITE + GLYPH)
	strings.write_string(&result, FG_RESET)

	return strings.to_string(result)
}

// prints all fetch fields formatted inside the NixOS logo
print_fetch_fields :: proc(fetch_fields: ^FetchFields) {
	buffer := strings.builder_make(len = 0, cap = 1024)

	fmt.printfln(
		nixos_logo_fmt(),
		fetch_fields.user_info,
		FG_BLUE + "OS" + FG_RESET,
		fetch_fields.os_name,
		FG_BLUE + "Host" + FG_RESET,
		fetch_fields.host_info,
		FG_BLUE + "Kernel" + FG_RESET,
		fetch_fields.kernel_info,
		FG_BLUE + "Shell" + FG_RESET,
		fetch_fields.shell_info,
		FG_BLUE + "Desktop" + FG_RESET,
		fetch_fields.desktop_info,
		FG_BLUE + "Uptime" + FG_RESET,
		fetch_fields.uptime,
		FG_BLUE + "Memory" + FG_RESET,
		fetch_fields.memory_info,
		FG_BLUE + "Colors" + FG_RESET,
		fetch_fields.colors,
	)

	result := strings.to_string(buffer)
	fmt.print(result)
}
