package nixfetch

import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"
import "core:terminal/ansi"

FG_BLACK :: "\x1b[" + ansi.FG_BLACK + "m"
FG_RED :: "\x1b[" + ansi.FG_RED + "m"
FG_GREEN :: "\x1b[" + ansi.FG_GREEN + "m"
FG_YELLOW :: "\x1b[" + ansi.FG_YELLOW + "m"
FG_BLUE :: "\x1b[" + ansi.FG_BLUE + "m"
FG_MAGENTA :: "\x1b[" + ansi.FG_MAGENTA + "m"
FG_CYAN :: "\x1b[" + ansi.FG_CYAN + "m"
FG_WHITE :: "\x1b[" + ansi.FG_WHITE + "m"

FG_RESET :: "\x1b[" + ansi.RESET + "m"


// procedure to get the user_name and host_name
get_username_and_hostname :: proc() -> string {
	username: string
	//append `USER` environment varaiable value if found else append unknown
	if value, found := os.lookup_env("USER"); found == true {
		username = value
	} else {
		username = "unknown_user"
	}

	// get the hostname with libc
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)
	hostname := strings.clone_from_cstring(cstring(&uts_name.nodename[0]))

	// final ansi colored username & hostname output
	// ansi_yello_color(\x1b[33m) + len(username) + @ + ansi_green_color(\x1b[??m) + len(hostname) + ansi_reset(\x1b[0m)
	cap := 5 + len(username) + 1 + 5 + len(hostname) + 4 + 1
	result := strings.builder_make(len = 0, cap = cap)

	// append necessary content to makek username & hostname
	strings.write_string(&result, FG_YELLOW)
	strings.write_string(&result, username)
	strings.write_rune(&result, '@')
	strings.write_string(&result, FG_GREEN)
	strings.write_string(&result, string(cstring(&uts_name.nodename[0])))
	strings.write_string(&result, "\x1b[" + ansi.RESET + "m")
	strings.write_rune(&result, '~')

	return strings.to_string(result)
}

// procedure to get the pretty os name
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

// procedure to get the system device info
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

// procedure to pretty print the FetchFields struct to stdout
print_fetch_fields :: proc(fetch_fields: ^FetchFields) {
	buffer := strings.builder_make(len = 0, cap = 1024)

	fmt.printfln(
		nixos_logo_fmt(),
		fetch_fields.user_info,
		FG_BLUE + "System" + FG_RESET,
		fetch_fields.os_name,
		FG_BLUE + "Host" + FG_RESET,
		fetch_fields.host_info,
		FG_BLUE + "Colors" + FG_RESET,
		fetch_fields.colors,
	)

	result := strings.to_string(buffer)
	fmt.print(result)
}
