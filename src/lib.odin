package nixfetch

import "base:runtime"
import "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:sys/linux"

// which layout to print, fixed at build time: -define:NIXFETCH_LAYOUT=269
// the default is 110, also used for any unrecognised number;
//   110 Icons   - icon, label, ":", value, with a color palette row      (image 1)
//   252 CLAssic - user@host, a dashed rule, "Label: value" lines         (image 2)
//   269 BOXed   - fields grouped into titled boxes                       (image 3)
//   227 BARs    - short upper-case labels, memory drawn as a bar         (image 4)
LAYOUT :: #config(NIXFETCH_LAYOUT, 110)

// print "<icon> <label> : <value>" when true, "<label> : <value>" when false: -define:NIXFETCH_ICONS=false
SHOW_ICONS :: #config(NIXFETCH_ICONS, true)

// odinfmt: disable
// nerd font icon printed before each field's label
ICON_OS            :: "  " // nf-linux-nixos
ICON_HOST          :: "󰌢  " // nf-md-laptop
ICON_KERNEL        :: "  " // nf-fa-linux
ICON_UPTIME        :: "󰅐  " // nf-md-clock_outline
ICON_PACKAGES      :: "󰏗  " // nf-md-package_variant
ICON_SHELL         :: "  " // nf-oct-terminal
ICON_DISPLAY       :: "󰍹  " // nf-md-monitor
ICON_DESKTOP       :: "  " // nf-fa-window_maximize
ICON_THEME         :: "󰏘  " // nf-md-palette
ICON_ICONS         :: "󰉏  " // nf-md-folder_image
ICON_CURSOR        :: "󰆿  " // nf-md-cursor_default
ICON_TERMINAL      :: "󰆍  " // nf-md-console
ICON_TERMINAL_FONT :: "  " // nf-fa-font
ICON_CPU           :: "  " // nf-oct-cpu
ICON_GPU           :: "󰢮  " // nf-md-expansion_card
ICON_MEMORY        :: "󰍛  " // nf-md-memory
ICON_SWAP          :: "󰓡  " // nf-md-swap_horizontal
ICON_DISK          :: "󰋊  " // nf-md-harddisk
ICON_LOCAL_IP      :: "󰩠  " // nf-md-ip_network
ICON_BATTERY       :: "󰁹  " // nf-md-battery
ICON_LOCALE        :: "󰇧  " // nf-md-earth
ICON_OS_AGE        :: "󰃭  " // nf-md-calendar
ICON_COLORS        :: "  " // nf-fa-paint_brush
// odinfmt: enable

// ANSI escapes; the 16 base colors, so the output follows the terminal's own theme
RESET :: "\x1b[0m"
BOLD :: "\x1b[1m"
ITALIC :: "\x1b[3m"
FG_BLACK :: "\x1b[30m"
FG_RED :: "\x1b[31m"
FG_GREEN :: "\x1b[32m"
FG_YELLOW :: "\x1b[33m"
FG_BLUE :: "\x1b[34m"
FG_MAGENTA :: "\x1b[35m"
FG_CYAN :: "\x1b[36m"
FG_WHITE :: "\x1b[37m"
FG_GRAY :: "\x1b[90m"

// every field any layout prints, already formatted for that layout. Only the fields
// the chosen layout uses get filled; the strings live in the arena main sets up.
SystemInformation :: struct {
	user_info:     string,
	os_name:       string,
	host_info:     string,
	kernel_info:   string,
	uptime:        string,
	packages_info: string,
	shell_info:    string,
	display_info:  string,
	desktop_info:  string,
	theme_info:    string,
	icons_info:    string,
	cursor_info:   string,
	terminal_info: string,
	terminal_font: string,
	cpu_info:      string,
	gpu_info:      string,
	memory_info:   string,
	swap_info:     string,
	disk_info:     string,
	local_ip:      string,
	battery_info:  string,
	locale:        string,
	os_age:        string,
	colors:        string,
}

collect_system_information :: proc(sys: ^SystemInformation) -> Error {
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)

	when LAYOUT == 252 {
		return collect_system_information_layout_252(sys, &uts_name)
	} else when LAYOUT == 269 {
		return collect_system_information_layout_269(sys, &uts_name)
	} else when LAYOUT == 227 {
		return collect_system_information_layout_227(sys, &uts_name)
	} else {
		return collect_system_information_layout_110(sys, &uts_name)
	}
}

collect_system_information_layout_110 :: proc(
	sys: ^SystemInformation,
	uts: ^linux.UTS_Name,
) -> Error {
	assert(sys != nil)
	assert(uts != nil)
	assert(uts.sysname != {})

	// one nf-fa-circle per base color, so the row shows the terminal's own palette
	// odinfmt: disable
	COLORS :: FG_RED + "  " + FG_GREEN + "  " + FG_YELLOW + "  " + FG_BLUE + "  " + FG_MAGENTA + "  " + FG_CYAN + "  " + FG_WHITE + "  " + RESET
	// odinfmt: enable

	sys.user_info = get_user_info(uts, context.temp_allocator) or_return
	sys.os_name = get_os_info(context.allocator) or_return
	sys.host_info = get_host_info(context.allocator) or_return
	sys.kernel_info = get_kernel_info(uts, context.allocator) or_return
	sys.shell_info = get_shell_info(context.allocator) or_return
	sys.desktop_info = get_desktop_info(context.allocator) or_return
	sys.uptime = get_uptime_info(context.allocator) or_return
	meminfo := read_entire_file("/proc/meminfo")
	sys.memory_info = get_memory_info(meminfo, context.allocator) or_return
	sys.swap_info = get_swap_info(meminfo, context.allocator) or_return

	sys.colors = COLORS
	sys.terminal_info = get_terminal_info(context.allocator) or_return
	return nil
}

collect_system_information_layout_252 :: proc(
	sys: ^SystemInformation,
	uts: ^linux.UTS_Name,
) -> Error {
	return nil
}

collect_system_information_layout_269 :: proc(
	sys: ^SystemInformation,
	uts: ^linux.UTS_Name,
) -> Error {
	return nil
}

collect_system_information_layout_227 :: proc(
	sys: ^SystemInformation,
	uts: ^linux.UTS_Name,
) -> Error {
	return nil
}

get_user_info :: proc(uts: ^linux.UTS_Name, allocator: runtime.Allocator) -> (string, Error) {
	user, user_set := get_env("USER", context.temp_allocator)
	if !user_set do user = "user"
	host := string(cstring(&uts.nodename[0]))
	return fmt.aprintf(
			BOLD + FG_BLUE + "%s" + RESET + "@" + FG_GREEN + "%s" + RESET,
			user,
			host,
			allocator = allocator,
		),
		nil
}

// the machine model from DMI as "product_name (product_family)", "82JH (Legion 5 15ITH6H)";
// either one that is empty or unreadable shows as "unknown"
get_host_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	name := read_entire_file("/sys/devices/virtual/dmi/id/product_name")
	family := read_entire_file("/sys/devices/virtual/dmi/id/product_family")
	if name == "" do name = "unknown"
	if family == "" do family = "unknown"
	return fmt.aprintf("%s (%s)", name, family, allocator = allocator), nil
}

// the kernel as uname reports it, "Linux 7.2.7-zen1 (x86_64)"
get_kernel_info :: proc(uts: ^linux.UTS_Name, allocator: runtime.Allocator) -> (string, Error) {
	sysname := string(cstring(&uts.sysname[0]))
	release := string(cstring(&uts.release[0]))
	machine := string(cstring(&uts.machine[0]))
	return fmt.aprintf("%s %s (%s)", sysname, release, machine, allocator = allocator), nil
}

// the login shell's name from SHELL, "fish" for /run/current-system/sw/bin/fish; "unknown" when unset
get_shell_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	shell, ok := get_env("SHELL", allocator)
	if !ok || shell == "" do return "unknown", nil
	return shell[strings.last_index_byte(shell, '/') + 1:], nil
}

// the desktop and its display protocol, "niri (wayland)", from XDG_CURRENT_DESKTOP and
// XDG_SESSION_TYPE; either one that is unset shows as "unknown"
get_desktop_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	desktop, _ := get_env("XDG_CURRENT_DESKTOP", context.temp_allocator)
	session, _ := get_env("XDG_SESSION_TYPE", context.temp_allocator)
	if desktop == "" do desktop = "unknown"
	if session == "" do session = "unknown"
	return fmt.aprintf("%s (%s)", desktop, session, allocator = allocator), nil
}

// how long the system has been up via the sysinfo syscall, "3 days, 22 hours, 14 minutes";
// "unknown" when sysinfo fails
get_uptime_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	info: linux.Sys_Info
	if err := linux.sysinfo(&info); err != .NONE do return "unknown", nil

	// convert total seconds into days, hours, minutes
	days := info.uptime / 86400
	hours := (info.uptime / 3600) % 24
	mins := (info.uptime / 60) % 60

	result: strings.Builder
	if _, err := strings.builder_init(&result, 0, 32, allocator); err != nil {
		return {}, .Arena_Out_Of_Memory
	}

	if days > 0 {
		strings.write_int(&result, days)
		strings.write_string(&result, days == 1 ? " day" : " days")
	}

	if hours > 0 {
		if len(result.buf) != 0 do strings.write_string(&result, ", ")
		strings.write_int(&result, hours)
		strings.write_string(&result, hours == 1 ? " hour" : " hours")
	}

	if mins > 0 {
		if len(result.buf) != 0 do strings.write_string(&result, ", ")
		strings.write_int(&result, mins)
		strings.write_string(&result, mins == 1 ? " minute" : " minutes")
	}

	if len(result.buf) == 0 do strings.write_string(&result, "less than a minute")
	return strings.to_string(result), nil
}

// memory in use as free(1) counts it, MemTotal - MemAvailable: "12.11 GiB / 15.40 GiB (79%)";
// "unknown" when meminfo lacks either
get_memory_info :: proc(meminfo: string, allocator: runtime.Allocator) -> (string, Error) {
	meminfo := meminfo
	total_kib, available_kib := -1, -1
	for line in strings.split_lines_iterator(&meminfo) {
		name, _, rest := strings.partition(line, ":")
		if name != "MemTotal" && name != "MemAvailable" do continue

		if name == "MemTotal" {
			value, ok := strconv.parse_int(
				strings.trim_space(strings.trim_suffix(strings.trim_space(rest), "kB")),
			)
			if ok do total_kib = value
		}
		if name == "MemAvailable" {
			value, ok := strconv.parse_int(
				strings.trim_space(strings.trim_suffix(strings.trim_space(rest), "kB")),
			)
			if ok do available_kib = value
		}
		if total_kib >= 0 && available_kib >= 0 do break
	}

	if total_kib <= 0 || available_kib < 0 do return "unknown", nil
	return format_usage(total_kib - available_kib, total_kib, allocator), nil
}

// swap in use, SwapTotal - SwapFree, in the same form as memory; "disabled" without swap,
// "unknown" when meminfo lacks either
get_swap_info :: proc(meminfo: string, allocator: runtime.Allocator) -> (string, Error) {
	meminfo := meminfo
	total_kib, free_kib := -1, -1
	for line in strings.split_lines_iterator(&meminfo) {
		name, _, rest := strings.partition(line, ":")
		if name != "SwapTotal" && name != "SwapFree" do continue

		if name == "SwapTotal" {
			value, ok := strconv.parse_int(
				strings.trim_space(strings.trim_suffix(strings.trim_space(rest), "kB")),
			)
			if ok do total_kib = value
		}
		if name == "SwapFree" {
			value, ok := strconv.parse_int(
				strings.trim_space(strings.trim_suffix(strings.trim_space(rest), "kB")),
			)
			if ok do free_kib = value
		}
		if total_kib >= 0 && free_kib >= 0 do break
	}

	if total_kib < 0 || free_kib < 0 do return "unknown", nil
	if total_kib == 0 do return "disabled", nil
	return format_usage(total_kib - free_kib, total_kib, allocator), nil
}

// "<used> GiB / <total> GiB (<percent>%)" with the percentage green below 80, yellow below 90,
// red from 90
format_usage :: proc(used_kib, total_kib: int, allocator: runtime.Allocator) -> string {
	KIB_PER_GIB :: 1024 * 1024
	percent := used_kib * 100 / total_kib
	color := FG_GREEN if percent < 80 else (FG_YELLOW if percent < 90 else FG_RED)
	return fmt.aprintf(
		"%.2f GiB / %.2f GiB (%s%d%%" + RESET + ")",
		f64(used_kib) / KIB_PER_GIB,
		f64(total_kib) / KIB_PER_GIB,
		color,
		percent,
		allocator = allocator,
	)
}

// the distribution's PRETTY_NAME from /etc/os-release without its quotes, "NixOS 26.05 (Yarara)";
// "unknown" when the file or the key is missing
get_os_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	os_release := read_entire_file("/etc/os-release")
	for line in strings.split_lines_iterator(&os_release) {
		key, _, value := strings.partition(line, "=")
		if key != "PRETTY_NAME" do continue
		value = strings.trim(value, "\"'")
		if value == "" do break

		name, err := strings.clone(value, allocator)
		if err != nil do return {}, .Arena_Out_Of_Memory
		return name, nil
	}
	return "unknown", nil
}

// an environment variable's value copied into allocator, as os.lookup_env returns it. The
// allocating os.lookup_env builds the key's cstring in core:os's own scratch arena, which mallocs
// 4 MB on first use; the buffer form allocates nothing, so only the value is copied out.
// Values over ENV_VALUE_MAX bytes count as unset.
get_env :: proc(key: string, allocator: runtime.Allocator) -> (value: string, found: bool) {
	ENV_VALUE_MAX :: 2048

	buffer: [ENV_VALUE_MAX]byte
	raw, err := os.lookup_env(buffer[:], key)
	if err != nil do return "", false

	cloned, clone_err := strings.clone(raw, allocator)
	if clone_err != nil do return "", false
	return cloned, true
}

// a file's contents without trailing whitespace or NUL, as /sys and /proc files end in a newline
// and device tree strings in a NUL; "" when the file cannot be read. Straight open/read/close:
// os.read_entire_file also readlinks and stats every file, which doubles the syscalls. The files
// read here are under a page, so anything past READ_FILE_MAX bytes is cut off.
read_entire_file :: proc(path: cstring, allocator := context.temp_allocator) -> string {
	READ_FILE_MAX :: 4096

	fd, open_err := linux.open(path, {.CLOEXEC})
	if open_err != .NONE do return ""
	defer linux.close(fd)

	buffer, alloc_err := make([]byte, READ_FILE_MAX, allocator)
	if alloc_err != nil do return ""

	// a read that comes back short has reached the end, for regular files as for these small
	// /proc and /sys ones, so only a full read is followed by another
	length := 0
	for length < len(buffer) {
		n, read_err := linux.read(fd, buffer[length:])
		if read_err != .NONE do break
		length += n
		if n < len(buffer) - (length - n) do break
	}
	return strings.trim_right(string(buffer[:length]), " \t\r\n\x00")
}

// the terminal as TERM_PROGRAM names it (ghostty, WezTerm, tmux, ...), "unknown" when unset
get_terminal_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	program, ok := get_env("TERM_PROGRAM", allocator)
	if !ok || program == "" do return "unknown", nil
	return program, nil
}

print_system_information :: proc(sys: ^SystemInformation) -> (string, Error) {
	image, _ := get_env("NIXFETCH_IMAGE", context.allocator)
	// the image goes over the Kitty graphics protocol, which only these terminals speak
	if sys.terminal_info != "ghostty" && sys.terminal_info != "kitty" do image = ""

	builder: strings.Builder
	if _, err := strings.builder_init(&builder, context.allocator); err != nil {
		return {}, .Arena_Out_Of_Memory
	}

	err: Error
	when LAYOUT == 252 {
		err = print_system_information_layout_252(&builder, sys, image)
	} else when LAYOUT == 269 {
		err = print_system_information_layout_269(&builder, sys, image)
	} else when LAYOUT == 227 {
		err = print_system_information_layout_227(&builder, sys, image)
	} else {
		err = print_system_information_layout_110(&builder, sys, image)
	}
	if err != nil do return {}, err

	return strings.to_string(builder), nil
}

print_system_information_layout_110 :: proc(
	builder: ^strings.Builder,
	sys: ^SystemInformation,
	image: string,
) -> Error {
	strings.write_string(builder, "\n")
	has_image := image != ""
	width := IMAGE_WIDTH if has_image else LOGO_WIDTH

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[0])
	fmt.sbprintf(builder, "%*s", width, "")
	strings.write_string(builder, sys.user_info)
	strings.write_string(builder, "\n")

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[1])
	write_field(builder, width, ICON_OS, "OS", sys.os_name)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[2])
	write_field(builder, width, ICON_HOST, "Host", sys.host_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[3])
	write_field(builder, width, ICON_KERNEL, "Kernel", sys.kernel_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[4])
	write_field(builder, width, ICON_SHELL, "Shell", sys.shell_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[5])
	write_field(builder, width, ICON_DESKTOP, "Desktop", sys.desktop_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[6])
	write_field(builder, width, ICON_MEMORY, "Memory", sys.memory_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[7])
	write_field(builder, width, ICON_SWAP, "Swap", sys.swap_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[8])
	write_field(builder, width, ICON_TERMINAL, "Terminal", sys.terminal_info)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[9])
	write_field(builder, width, ICON_UPTIME, "Uptime", sys.uptime)

	if !has_image do strings.write_string(builder, NIX_LOGO_ANSI_COLORED[10])
	write_field(builder, width, ICON_COLORS, "Colors", sys.colors)

	// the fields are written first and each ends in a newline, so the cursor sits at column 1 of
	// the line below the last one; for the image go back up to the first field's line
	layout_fields_count :: 11
	if has_image {
		fmt.sbprintf(builder, "\x1b[%dA", layout_fields_count)
		write_kitty_image(builder, image)
	}
	return nil
}

// writes one field's line: the gap beside the logo or image, the label in blue padded to 10 cells,
// ": ", the value and a newline; the label leads with its icon when built with icons,
// -define:NIXFETCH_ICONS=true
write_field :: #force_inline proc(
	builder: ^strings.Builder,
	width: int,
	icon, label, value: string,
) {
	fmt.sbprintf(
		builder,
		"%*s" + FG_BLUE + "%s%-10s" + RESET + ": %s\n",
		width,
		"",
		icon if SHOW_ICONS else "",
		label,
		value,
	)
}

// writes the escape that draws the PNG at path over the Kitty graphics protocol; t=f sends the
// path, not the pixels, so the terminal reads the file itself
write_kitty_image :: #force_inline proc(builder: ^strings.Builder, path: string) {
	encoded_path := base64.encode(transmute([]byte)path, allocator = context.temp_allocator)
	fmt.sbprintf(builder, "  \x1b_Ga=T,f=100,t=f,c=%d;%s\x1b\\", IMAGE_WIDTH - 4, encoded_path)
}

print_system_information_layout_252 :: proc(
	builder: ^strings.Builder,
	sys: ^SystemInformation,
	image: string,
) -> Error {
	strings.write_string(builder, "nixfetch 252")
	return nil
}

print_system_information_layout_269 :: proc(
	builder: ^strings.Builder,
	sys: ^SystemInformation,
	image: string,
) -> Error {
	strings.write_string(builder, "nixfetch 269")
	return nil
}

print_system_information_layout_227 :: proc(
	builder: ^strings.Builder,
	sys: ^SystemInformation,
	image: string,
) -> Error {
	strings.write_string(builder, "nixfetch 227")
	return nil
}

// cells the NixOS logo takes up, so system info lines up on the right
LOGO_WIDTH: int : 39

// cells a custom image takes up over the Kitty graphics protocol
IMAGE_WIDTH: int : 45

// the NixOS logo in ANSI colors, each line padded to LOGO_WIDTH
@(rodata)
NIX_LOGO_ANSI_COLORED := [?]string {
	"  [38;2;82;119;195m       ◢██◣[38;2;127;183;255m     ◥███◣  ◢██◣          ",
	"  [38;2;82;119;195m       ◥███◣[38;2;127;183;255m     ◥███◣◢███◤          ",
	"  [38;2;82;119;195m        ◥███◣[38;2;127;183;255m     ◥██████◤           ",
	"  [38;2;82;119;195m    ◢██████████████[48;2;127;183;255m◣[0m[38;2;127;183;255m████◤[38;2;82;119;195m   ◢◣       ",
	"  [38;2;82;119;195m   ◢████████████████[48;2;127;183;255m◣[0m[38;2;127;183;255m███◣[38;2;82;119;195m  ◢██◣      ",
	"  [38;2;127;183;255m        ◢███◤        ◥███◣[38;2;82;119;195m◢███◤      ",
	"  [38;2;127;183;255m       ◢███◤          ◥██[48;2;82;119;195m◤[0m[38;2;82;119;195m███◤       ",
	"  [38;2;127;183;255m◢█████████◤            ◥[48;2;82;119;195m◤[0m[38;2;82;119;195m████████◣   ",
	"  [38;2;127;183;255m◥████████[48;2;82;119;195m◤[0m[38;2;82;119;195m◣            ◢█████████◤   ",
	"  [38;2;127;183;255m    ◢███[48;2;82;119;195m◤[0m[38;2;82;119;195m██◣          ◢███◤          ",
	"  [38;2;127;183;255m   ◢███◤[38;2;82;119;195m◥███◣        ◢███◤           ",
	"  [38;2;127;183;255m   ◥██◤  [38;2;82;119;195m◥███[48;2;127;183;255m◣[0m[38;2;127;183;255m████████████████◤      ",
	"  [38;2;127;183;255m    ◥◤   [38;2;82;119;195m◢████[48;2;127;183;255m◣[0m[38;2;127;183;255m██████████████◤       ",
	"  [38;2;82;119;195m        ◢██████◣[38;2;127;183;255m     ◥███◣           ",
	"  [38;2;82;119;195m       ◢███◤◥███◣[38;2;127;183;255m     ◥███◣          ",
	"  [38;2;82;119;195m       ◥██◤  ◥███◣[38;2;127;183;255m     ◥██◤[38;0m          ",
}
