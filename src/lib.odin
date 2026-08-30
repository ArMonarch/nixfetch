package nixfetch

import "base:runtime"
import "core:encoding/base64"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
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


// allocates and returns colored "user@hostname~" string using context.allocator
get_username_and_hostname :: proc(
	uts_name: ^linux.UTS_Name,
	allocator := context.allocator,
) -> string {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	username: string
	found: bool
	if username, found = os.lookup_env("USER", context.temp_allocator); found != true {
		username = strings.clone("unknown")
	}
	hostname := strings.clone_from_cstring(cstring(&uts_name.nodename[0]), context.temp_allocator)

	// capacity := len(user) + len(hostname) + (~)1 + (@)1
	//             (FG_YELLOW)5 + (FG_RED)5 + (FG_GREEN)5 + (FG_RESET)4
	cap := len(username) + len(hostname) + 1 + 1 + 5 + 5 + 5 + 4
	result := strings.builder_make(len = 0, cap = cap, allocator = allocator)

	// build colored "user@hostname~" output
	strings.write_string(&result, FG_YELLOW)
	strings.write_string(&result, username)
	strings.write_string(&result, FG_RED)
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
get_kernel_info :: proc(uts_name: ^linux.UTS_Name) -> string {
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
	desktop: string
	session: string
	success: bool

	if desktop, success = os.lookup_env("XDG_CURRENT_DESKTOP", allocator); success != true {
		session = strings.clone("unknown", allocator)
	}
	defer delete(desktop)

	if session, success = os.lookup_env("XDG_SESSION_TYPE", allocator); success != true {
		desktop = strings.clone("unknown", allocator)
	}
	defer delete(session)

	result := strings.builder_make(0, len(desktop) + len(session) + 3)
	strings.write_string(&result, desktop)
	strings.write_string(&result, " (")
	strings.write_string(&result, session)
	strings.write_string(&result, ")")
	return strings.to_string(result)
}


// returns shell name (basename of $SHELL)
get_shell_info :: proc() -> string {
	shell_path: string
	success: bool
	if shell_path, success = os.lookup_env("SHELL", context.allocator); success != true {
		return strings.clone("unknown")
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
	if err != nil {
		return strings.clone("unknown")
	}
	defer os.close(fd)

	buf: [2096]byte
	n, read_err := os.read(fd, buf[:])
	if read_err != nil || n == 0 {
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

	result := strings.builder_make(len = 0, cap = 128)
	fmt.sbprintf(&result, "%.2f GiB / %.2f GiB (%.0f%%)", used_gib, total_gib, percentage_use)

	return strings.to_string(result)
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

	result := strings.builder_make(len = 0, cap = 128)
	fmt.sbprintf(&result, "%.2f GiB / %.2f GiB (%.0f%%)", used_gib, total_gib, percentage_use)

	return strings.to_string(result)
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

// reads the value out of the first "<key><sep> <value>" line of a /proc or /sys style file
parse_field :: proc(content: string, key: string, sep: byte) -> string {
	idx := strings.index(content, key)
	if idx == -1 {
		return ""
	}

	rest := content[idx + len(key):]
	line_end := strings.index_byte(rest, '\n')
	if line_end == -1 {
		line_end = len(rest)
	}

	// the separator has to sit on the same line as the key
	sep_idx := strings.index_byte(rest[:line_end], sep)
	if sep_idx == -1 {
		return ""
	}

	return strings.trim_space(rest[sep_idx + 1:line_end])
}

// reads a sysfs file that holds nothing but a single base 10 integer
read_int_file :: proc(path: string, allocator := context.allocator) -> (value: int, ok: bool) {
	data, err := os.read_entire_file(path, allocator)
	if err != nil {
		return 0, false
	}
	defer delete(data)

	return strconv.parse_int(strings.trim_space(string(data)), 10)
}

// writes the cpu model name with the vendor noise ("(R)", "(TM)") and the baked in
// base frequency stripped out, the max frequency is reported separately
write_cpu_model :: proc(builder: ^strings.Builder, model: string) {
	NOISE :: [?]string{"(R)", "(TM)", "(r)", "(tm)"}

	name := model
	if at := strings.index(name, " @ "); at != -1 {
		name = name[:at]
	}

	next: for i := 0; i < len(name); {
		for noise in NOISE {
			if strings.has_prefix(name[i:], noise) {
				i += len(noise)
				continue next
			}
		}

		strings.write_byte(builder, name[i])
		i += 1
	}
}

// returns "model (threads) @ max GHz" from /proc/cpuinfo and the cpufreq sysfs entries
get_cpu_info :: proc(allocator := context.allocator) -> string {
	data, err := os.read_entire_file("/proc/cpuinfo", allocator)
	if err != nil {
		return strings.clone("unknown")
	}
	defer delete(data)
	content := string(data)

	model := parse_field(content, "model name", ':')
	if model == "" {
		return strings.clone("unknown")
	}

	// every logical cpu gets its own "processor" record
	threads := strings.count(content, "\nprocessor")
	if strings.has_prefix(content, "processor") {
		threads += 1
	}

	result := strings.builder_make(0, 128)
	write_cpu_model(&result, model)

	if threads > 0 {
		fmt.sbprintf(&result, " (%d)", threads)
	}

	// cpuinfo_max_freq is the hardware limit in kHz, fall back to what cpu0 is clocked at now
	if khz, ok := read_int_file(
		"/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq",
		allocator,
	); ok {
		fmt.sbprintf(&result, " @ %.2f GHz", f64(khz) / (1000 * 1000))
	} else if mhz, parsed := strconv.parse_f64(parse_field(content, "cpu MHz", ':')); parsed {
		fmt.sbprintf(&result, " @ %.2f GHz", mhz / 1000)
	}

	return strings.to_string(result)
}

// paths shipping the pci id database, NIXFETCH_PCI_IDS overrides the lookup
@(rodata)
PCI_IDS_PATHS := [?]string {
	"/usr/share/hwdata/pci.ids",
	"/usr/share/misc/pci.ids",
	"/run/current-system/sw/share/hwdata/pci.ids",
	"/var/lib/pciutils/pci.ids",
}

// vendors we can still name when no pci id database is installed
@(rodata)
PCI_VENDORS := [?]struct {
	id:   string,
	name: string,
} {
	{"10de", "NVIDIA"},
	{"8086", "Intel"},
	{"1002", "AMD"},
	{"1022", "AMD"},
	{"15ad", "VMware"},
	{"1af4", "Red Hat"},
	{"1a03", "ASPEED"},
}

// returns the contents of the first pci id database found, or "" when none is installed
read_pci_ids :: proc(allocator := context.allocator) -> string {
	if path, found := os.lookup_env("NIXFETCH_PCI_IDS", allocator); found {
		defer delete(path)
		if data, err := os.read_entire_file(path, allocator); err == nil {
			return string(data)
		}
	}

	for path in PCI_IDS_PATHS {
		if data, err := os.read_entire_file(path, allocator); err == nil {
			return string(data)
		}
	}

	return ""
}

// resolves a pci id pair against an already loaded pci id database.
// both returned strings alias `db` and stay valid only as long as it does.
pci_ids_lookup :: proc(
	db: string,
	vendor_id: string,
	device_id: string,
) -> (
	vendor, device: string,
) {
	rest := db
	in_vendor := false

	for len(rest) > 0 {
		line: string
		if end := strings.index_byte(rest, '\n'); end != -1 {
			line, rest = rest[:end], rest[end + 1:]
		} else {
			line, rest = rest, ""
		}

		if len(line) == 0 || line[0] == '#' {
			continue
		}

		// vendor records sit at column zero, their devices are indented by a single tab
		if line[0] != '\t' {
			// walked past the whole vendor block without matching the device
			if in_vendor {
				return
			}

			if strings.has_prefix(line, vendor_id) {
				in_vendor = true
				vendor = strings.trim_space(line[len(vendor_id):])
			}
			continue
		}

		// a double tab marks a subsystem record, not a device
		if !in_vendor || strings.has_prefix(line, "\t\t") {
			continue
		}

		if strings.has_prefix(line[1:], device_id) {
			device = strings.trim_space(line[1 + len(device_id):])
			return
		}
	}

	return
}

// the database spells vendors out in full, shorten the common ones to fit a fetch line
shorten_pci_vendor :: proc(vendor: string) -> string {
	switch {
	case strings.has_prefix(vendor, "NVIDIA"):
		return "NVIDIA"
	case strings.has_prefix(vendor, "Intel"):
		return "Intel"
	case strings.has_prefix(vendor, "Advanced Micro Devices"):
		return "AMD"
	}

	return vendor
}

// the nvidia driver publishes the marketing name that the pci id alone cannot give us
get_nvidia_model :: proc(pci_slot: string, allocator := context.allocator) -> string {
	path := strings.concatenate({"/proc/driver/nvidia/gpus/", pci_slot, "/information"}, allocator)
	defer delete(path)

	data, err := os.read_entire_file(path, allocator)
	if err != nil {
		return ""
	}
	defer delete(data)

	model := parse_field(string(data), "Model", ':')
	return model == "" ? "" : strings.clone(model, allocator)
}

// returns every pci gpu found under /sys/class/drm, comma separated
get_gpu_info :: proc(allocator := context.allocator) -> string {
	cards, err := os.read_directory_by_path("/sys/class/drm", -1, allocator)
	if err != nil {
		return strings.clone("unknown")
	}
	defer os.file_info_slice_delete(cards, allocator)

	// readdir order is not stable, sort so the cards always print in the same order
	slice.sort_by(cards, proc(a, b: os.File_Info) -> bool {
		return a.name < b.name
	})

	pci_ids := read_pci_ids(allocator)
	defer delete(pci_ids, allocator)

	result := strings.builder_make(0, 128)

	for card in cards {
		// "card0" is the device itself, "card0-HDMI-A-1" is one of its connectors
		if !strings.has_prefix(card.name, "card") || strings.contains(card.name, "-") {
			continue
		}

		uevent_path := strings.concatenate(
			{"/sys/class/drm/", card.name, "/device/uevent"},
			allocator,
		)
		defer delete(uevent_path)

		data, read_err := os.read_entire_file(uevent_path, allocator)
		if read_err != nil {
			continue
		}
		defer delete(data)

		// only pci gpus carry a PCI_ID, formatted as "VVVV:DDDD"
		uevent := string(data)
		pci_id := parse_field(uevent, "PCI_ID", '=')
		if len(pci_id) != 9 {
			continue
		}

		ids := strings.to_lower(pci_id, allocator)
		defer delete(ids)
		vendor_id, device_id := ids[:4], ids[5:]

		if len(result.buf) != 0 {
			strings.write_string(&result, ", ")
		}

		// the proprietary driver knows the name of its own card
		if parse_field(uevent, "DRIVER", '=') == "nvidia" {
			slot := parse_field(uevent, "PCI_SLOT_NAME", '=')
			if model := get_nvidia_model(slot, allocator); model != "" {
				defer delete(model)
				strings.write_string(&result, model)
				continue
			}
		}

		vendor, device := pci_ids_lookup(pci_ids, vendor_id, device_id)
		if device != "" {
			strings.write_string(&result, shorten_pci_vendor(vendor))
			strings.write_rune(&result, ' ')
			strings.write_string(&result, device)
			continue
		}

		// without a database all we can name is the vendor, so print the raw ids alongside
		for known in PCI_VENDORS {
			if known.id == vendor_id {
				strings.write_string(&result, known.name)
				strings.write_rune(&result, ' ')
				break
			}
		}
		fmt.sbprintf(&result, "[%s]", ids)
	}

	if len(result.buf) == 0 {
		strings.builder_destroy(&result)
		return strings.clone("unknown")
	}

	return strings.to_string(result)
}

// returns the filesystem type mounted at "/" according to /proc/mounts
get_root_fstype :: proc(allocator := context.allocator) -> string {
	data, err := os.read_entire_file("/proc/mounts", allocator)
	if err != nil {
		return ""
	}
	defer delete(data)

	// every line reads "<device> <mountpoint> <type> <options> <dump> <pass>"
	content := string(data)
	for line in strings.split_lines_iterator(&content) {
		device_end := strings.index_byte(line, ' ')
		if device_end == -1 {
			continue
		}

		rest := line[device_end + 1:]
		mount_end := strings.index_byte(rest, ' ')
		if mount_end == -1 || rest[:mount_end] != "/" {
			continue
		}

		rest = rest[mount_end + 1:]
		type_end := strings.index_byte(rest, ' ')
		if type_end == -1 {
			type_end = len(rest)
		}

		return strings.clone(rest[:type_end], allocator)
	}

	return ""
}

// returns "used GiB / total GiB (X%) - fstype" for the root filesystem
get_filesystem_info :: proc(allocator := context.allocator) -> string {
	stat: linux.Stat_FS
	if err := linux.statfs("/", &stat); err != .NONE {
		return strings.clone("unknown")
	}

	GIB :: f64(1024 * 1024 * 1024)
	total_gib := f64(stat.blocks) * f64(stat.bsize) / GIB
	used_gib := f64(stat.blocks - stat.bfree) * f64(stat.bsize) / GIB
	percentage_use := total_gib > 0 ? (used_gib / total_gib) * 100 : 0

	result := strings.builder_make(0, 128)
	fmt.sbprintf(&result, "%.2f GiB / %.2f GiB (%.0f%%)", used_gib, total_gib, percentage_use)

	// the magic number in Stat_FS cannot tell ext2/3/4 apart, /proc/mounts names the type outright
	if fstype := get_root_fstype(allocator); fstype != "" {
		defer delete(fstype)
		fmt.sbprintf(&result, " - %s", fstype)
	}

	return strings.to_string(result)
}

KeyVal :: struct {
	label: string,
	value: ^string,
}

sysinfo_fmts :: proc(target: ^[dynamic]KeyVal, sysinfo: ^SystemInfo) {
	append(
		target,
		KeyVal{FG_BLUE + "OS" + FG_RESET, &sysinfo.os_name},
		KeyVal{FG_BLUE + "Host" + FG_RESET, &sysinfo.host_info},
		KeyVal{FG_BLUE + "Kernel" + FG_RESET, &sysinfo.kernel_info},
		KeyVal{FG_BLUE + "Shell" + FG_RESET, &sysinfo.shell_info},
		KeyVal{FG_BLUE + "Desktop" + FG_RESET, &sysinfo.desktop_info},
		KeyVal{FG_BLUE + "CPU" + FG_RESET, &sysinfo.cpu_info},
		KeyVal{FG_BLUE + "GPU" + FG_RESET, &sysinfo.gpu_info},
		KeyVal{FG_BLUE + "Memory" + FG_RESET, &sysinfo.memory_info},
		KeyVal{FG_BLUE + "Swap" + FG_RESET, &sysinfo.swap_info},
		KeyVal{FG_BLUE + "Disk" + FG_RESET, &sysinfo.filesystem_info},
		KeyVal{FG_BLUE + "Terminal" + FG_RESET, &sysinfo.terminal_info},
		KeyVal{FG_BLUE + "Uptime" + FG_RESET, &sysinfo.uptime},
		KeyVal{FG_BLUE + "Colors" + FG_RESET, &sysinfo.colors},
	)

	// fmt.sbprintf(&builder, "%s%-8s %s : %s", FG_BLUE, f.label, FG_RESET, f.value)
}

// prints all fetch fields formatted inside the NixOS logo
pretty_print_sysinfo_with_logo :: proc(sysinfo: ^SystemInfo) {
	buffer := strings.builder_make(0, 4096)
	defer strings.builder_destroy(&buffer)

	// build key-value pairs from fetch fields for side-by-side printing with the logo
	fetches := make([dynamic]KeyVal)
	defer delete(fetches)
	sysinfo_fmts(&fetches, sysinfo)
	min_len := min(len(NIX_LOGO_BLACK_WHITE), len(fetches))

	// Print logo lines side by side with fetch fields
	for index in 0 ..< min_len {
		strings.write_string(&buffer, NIX_LOGO_BLACK_WHITE[index])
		fmt.sbprintf(&buffer, "%-18s : %s", fetches[index].label, fetches[index].value^)
		strings.write_string(&buffer, "\n")
	}

	// Print remaining logo lines if the logo is taller than the fetch fields
	for index in min_len ..< len(NIX_LOGO_BLACK_WHITE) {
		strings.write_string(&buffer, NIX_LOGO_BLACK_WHITE[index])
		strings.write_string(&buffer, "\n")
	}

	// Print remaining fetch fields with padding if there are more fields than logo lines
	for index in min_len ..< len(fetches) {
		for _ in 0 ..< APPRENT_WIDTH {
			strings.write_string(&buffer, " ")
		}
		fmt.sbprintf(&buffer, "%-18s : %s", fetches[index].label, fetches[index].value^)
		strings.write_string(&buffer, "\n")
	}

	fmt.println(strings.to_string(buffer))
}

// prints fetch fields with a custom image using the kitty graphics protocol
// falls back to the logo variant if the image path is invalid
pretty_print_sysinfo_with_image :: proc(sysinfo: ^SystemInfo, image_path: string) {
	if !os.is_file(image_path) {
		fmt.eprintln("Error: NIXFETCH_IMAGE is not a valid file")
		return
	}

	if !strings.has_suffix(image_path, ".png") {
		fmt.eprintln("Error: NIXFETCH_IMAGE must be a png image")
		return
	}

	// base64 encode the file path for the kitty graphics protocol
	encoded_path, err := base64.encode(transmute([]byte)image_path)
	if err != nil {
		return
	}
	defer delete(encoded_path)

	fetches := make([dynamic]KeyVal)
	defer delete(fetches)
	sysinfo_fmts(&fetches, sysinfo)

	fmt.print("\n")
	// print fetch fields first, padded left to leave space for the image
	for item in fetches {
		for _ in 0 ..< APPRENT_WIDTH {
			fmt.print(" ")
		}
		fmt.printfln("%-18s : %s", item.label, item.value^)
	}

	// move cursor back to the top and render the image via kitty graphics protocol
	fmt.printf("\x1b[%dA", len(fetches))
	fmt.printfln("  \x1b_Ga=T,f=100,t=f,c=%d;%s\x1b\\", APPRENT_WIDTH - 5, encoded_path)
}

// overloaded proc: dispatches to logo or image variant based on arguments
pretty_print_sysinfo :: proc {
	pretty_print_sysinfo_with_logo,
	pretty_print_sysinfo_with_image,
}

// populates a SystemInfo struct by gathering all system info.
// all string values are heap-allocated and must be freed via drop().
create_sysinfo :: proc(sysinfo: ^SystemInfo) {
	// get hostname via uname syscall
	uts_name: linux.UTS_Name
	linux.uname(&uts_name)

	sysinfo^ = SystemInfo {
		user_info       = get_username_and_hostname(&uts_name),
		os_name         = get_osname(),
		host_info       = get_host_info(),
		kernel_info     = get_kernel_info(&uts_name),
		shell_info      = get_shell_info(),
		desktop_info    = get_desktop_info(),
		uptime          = get_uptime(),
		// cpu_info        = get_cpu_info(),
		// gpu_info        = get_gpu_info(),
		memory_info     = get_memory_info(),
		swap_info       = get_swap_info(),
		filesystem_info = get_filesystem_info(),
		terminal_info   = get_terminal_info(),
		colors          = get_colored_dots(),
	}
}

// frees all heap-allocated string values in a SystemInfo struct.
destroy_sysinfo :: proc(sysinfo: ^SystemInfo) {
	// delete all sysinfo values
	defer delete(sysinfo.user_info)
	defer delete(sysinfo.os_name)
	defer delete(sysinfo.host_info)
	defer delete(sysinfo.kernel_info)
	defer delete(sysinfo.shell_info)
	defer delete(sysinfo.desktop_info)
	defer delete(sysinfo.cpu_info)
	defer delete(sysinfo.gpu_info)
	defer delete(sysinfo.memory_info)
	defer delete(sysinfo.swap_info)
	defer delete(sysinfo.filesystem_info)
	defer delete(sysinfo.terminal_info)
	defer delete(sysinfo.uptime)
	defer delete(sysinfo.colors)
}
