package nixfetch

import "base:intrinsics"
import "core:c/libc"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:sys/linux"

// which layout to print, fixed at build time: -define:NIXFETCH_LAYOUT=Glacier
//   Flurry  - icon, label, ":", value, with a color palette row      (image 1)
//   Frost   - user@host, a dashed rule, "Label: value" lines         (image 2)
//   Glacier - fields grouped into titled boxes                       (image 3)
//   Icicle  - short upper-case labels, memory drawn as a bar         (image 4)
LAYOUT :: #config(NIXFETCH_LAYOUT, "Flurry")
#assert(
	LAYOUT == "Flurry" || LAYOUT == "Frost" || LAYOUT == "Glacier" || LAYOUT == "Icicle",
	"NIXFETCH_LAYOUT must be one of Flurry, Frost, Glacier or Icicle",
)

// print "<icon> <label> : <value>" when true, "<label> : <value>" when false: -define:NIXFETCH_ICONS=false
SHOW_ICONS :: #config(NIXFETCH_ICONS, true)

// nerd font icon printed before each field's label
ICON_OS :: "" // nf-linux-nixos
ICON_HOST :: "\U000f0322" // nf-md-laptop
ICON_KERNEL :: "" // nf-fa-linux
ICON_UPTIME :: "\U000f0150" // nf-md-clock_outline
ICON_PACKAGES :: "\U000f03d7" // nf-md-package_variant
ICON_SHELL :: "" // nf-oct-terminal
ICON_DISPLAY :: "\U000f0379" // nf-md-monitor
ICON_DESKTOP :: "" // nf-fa-window_maximize
ICON_THEME :: "\U000f03d8" // nf-md-palette
ICON_ICONS :: "\U000f024f" // nf-md-folder_image
ICON_CURSOR :: "\U000f01bf" // nf-md-cursor_default
ICON_TERMINAL :: "\U000f018d" // nf-md-console
ICON_TERMINAL_FONT :: "" // nf-fa-font
ICON_CPU :: "" // nf-oct-cpu
ICON_GPU :: "\U000f08ae" // nf-md-expansion_card
ICON_MEMORY :: "\U000f035b" // nf-md-memory
ICON_SWAP :: "\U000f04e1" // nf-md-swap_horizontal
ICON_DISK :: "\U000f02ca" // nf-md-harddisk
ICON_LOCAL_IP :: "\U000f0a60" // nf-md-ip_network
ICON_BATTERY :: "\U000f0079" // nf-md-battery
ICON_LOCALE :: "\U000f01e7" // nf-md-earth
ICON_OS_AGE :: "\U000f00ed" // nf-md-calendar
ICON_COLORS :: "" // nf-fa-paint_brush

// every field any layout prints, already formatted for that layout. Only the fields
// the chosen layout uses get filled; the strings live in the arena main sets up.
System :: struct {
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

// ANSI escapes; the 16 base colors, so the output follows the terminal's own theme
RESET :: "\x1b[0m"
BOLD :: "\x1b[1m"
ITALIC :: "\x1b[3m"
FG_RED :: "\x1b[31m"
FG_GREEN :: "\x1b[32m"
FG_YELLOW :: "\x1b[33m"
FG_BLUE :: "\x1b[34m"
FG_MAGENTA :: "\x1b[35m"
FG_CYAN :: "\x1b[36m"
FG_WHITE :: "\x1b[37m"
FG_GRAY :: "\x1b[90m"

// ---------------------------------------------------------------------------
// Helpers. Everything allocates from context.allocator, which is main's arena.
// These go to the syscalls directly: core:os heap-allocates a handle per open
// file and keeps a temp arena of its own, both outside main's arena.
// ---------------------------------------------------------------------------

// the whole file, or "" when it cannot be read
read_file :: proc(path: string) -> string {
	fd, errno := linux.open(strings.clone_to_cstring(path), {})
	if errno != .NONE do return ""
	defer linux.close(fd)

	// /proc files report a size of 0 and sysfs ones 4096, so read to the end
	// whatever the size says, growing the buffer when it fills
	size := 4096
	stat: linux.Stat
	if linux.fstat(fd, &stat) == .NONE && int(stat.size) >= size do size = int(stat.size) + 1

	buf, err := mem.alloc_bytes_non_zeroed(size)
	if err != nil do return ""
	n := 0
	for {
		if n == len(buf) {
			bigger, grow_err := mem.alloc_bytes_non_zeroed(2 * len(buf))
			if grow_err != nil do return ""
			copy(bigger, buf)
			buf = bigger
		}
		read, read_errno := linux.read(fd, buf[n:])
		if read_errno != .NONE do return ""
		if read == 0 do break
		n += read
	}
	return string(buf[:n])
}

// the names in a directory, sorted, without "." and ".."
list_dir :: proc(path: string) -> []string {
	fd, errno := linux.open(strings.clone_to_cstring(path), {.DIRECTORY})
	if errno != .NONE do return nil
	defer linux.close(fd)

	names := make([dynamic]string)
	buf: [8192]u8
	for {
		n, read_errno := linux.getdents(fd, buf[:])
		if read_errno != .NONE || n <= 0 do break
		offset := 0
		for entry in linux.dirent_iterate_buf(buf[:n], &offset) {
			name := linux.dirent_name(entry)
			if name != "." && name != ".." do append(&names, strings.clone(name))
		}
	}
	slice.sort(names[:])
	return names[:]
}

// the first line of a sysfs style file, without its newline
read_line :: proc(path: string) -> string {
	content := read_file(path)
	if end := strings.index_byte(content, '\n'); end >= 0 do return content[:end]
	return content
}

// the variable's value, or "" when it is not set; it points into the environment, no copy
env :: proc(key: cstring) -> string {
	return string(libc.getenv(key))
}

// $XDG_CONFIG_HOME, falling back to ~/.config
config_dir :: proc() -> string {
	if dir := env("XDG_CONFIG_HOME"); dir != "" do return dir
	return strings.concatenate({env("HOME"), "/.config"})
}

// the value of the first "<key><sep><value>" line; a ' ' sep means any run of blanks,
// as in kitty.conf. Whitespace around the separator is ignored.
parse_field :: proc(content: string, key: string, sep: byte) -> string {
	rest := content
	for line in strings.split_lines_iterator(&rest) {
		if !strings.has_prefix(line, key) do continue
		value := line[len(key):]
		if sep == ' ' {
			if len(value) == 0 || (value[0] != ' ' && value[0] != '\t') do continue
			return strings.trim_space(value)
		}
		value = strings.trim_left(value, " \t")
		if len(value) == 0 || value[0] != sep do continue
		return strings.trim_space(value[1:])
	}
	return ""
}

// follows every symlink in path, "" when it does not exist
real_path :: proc(path: string) -> string {
	fd, errno := linux.open(strings.clone_to_cstring(path), {.PATH})
	if errno != .NONE do return ""
	defer linux.close(fd)

	buf: [4096]u8
	link := strings.clone_to_cstring(fmt.tprintf("/proc/self/fd/%d", fd))
	n, read_errno := linux.readlink(link, buf[:])
	if read_errno != .NONE do return ""
	return strings.clone(string(buf[:n]))
}

// the version in a nix store path: "/nix/store/<hash>-bash-interactive-5.3p9/bin/bash" is "5.3p9"
store_version :: proc(path: string) -> string {
	STORE :: "/nix/store/"
	if !strings.has_prefix(path, STORE) do return ""
	name := path[len(STORE):]
	if slash := strings.index_byte(name, '/'); slash >= 0 do name = name[:slash]
	dash := strings.last_index_byte(name, '-')
	if dash < 0 || dash + 1 >= len(name) || name[dash + 1] < '0' || name[dash + 1] > '9' do return ""
	return name[dash + 1:]
}

// "7.26 GiB / 14.97 GiB (48%)", the percentage colored by how full it is
format_usage :: proc(used, total: u64) -> string {
	GIB :: f64(1024 * 1024 * 1024)
	percent := f64(used) / f64(total) * 100
	return fmt.aprintf(
		"%.2f GiB / %.2f GiB (%s%.0f%%%s)",
		f64(used) / GIB,
		f64(total) / GIB,
		usage_color(percent),
		percent,
		RESET,
	)
}

// "[ ■■■■■■■■■─────────── ]", the filled part colored by how full it is
format_usage_bar :: proc(used, total: u64) -> string {
	WIDTH :: 20
	percent := f64(used) / f64(total) * 100
	filled := clamp(int(math.round(percent / 100 * WIDTH)), 0, WIDTH)

	b := strings.builder_make()
	strings.write_string(&b, "[ ")
	strings.write_string(&b, usage_color(percent))
	for _ in 0 ..< filled do strings.write_string(&b, "■")
	strings.write_string(&b, FG_GRAY)
	for _ in filled ..< WIDTH do strings.write_string(&b, "─")
	strings.write_string(&b, RESET + " ]")
	return strings.to_string(b)
}

usage_color :: proc(percent: f64) -> string {
	if percent < 50 do return FG_GREEN
	if percent < 80 do return FG_YELLOW
	return FG_RED
}

// ---------------------------------------------------------------------------
// Fields. Each returns "" when it cannot tell, and layouts leave that row out.
// ---------------------------------------------------------------------------

// colored "user@host"
get_user_info :: proc(uts: ^linux.UTS_Name) -> string {
	user := env("USER")
	if user == "" do user = "user"
	host := string(cstring(&uts.nodename[0]))
	return fmt.aprintf(FG_BLUE + BOLD + "%s" + RESET + "@" + FG_BLUE + BOLD + "%s" + RESET, user, host)
}

// PRETTY_NAME from /etc/os-release, "NixOS 26.05 (Yarara)"
get_os_name :: proc() -> string {
	return strings.trim(parse_field(read_file("/etc/os-release"), "PRETTY_NAME", '='), "\"")
}

// the machine's model from DMI, "Legion 5 15ITH6H (82JH)"
get_host_info :: proc() -> string {
	DMI :: "/sys/devices/virtual/dmi/id/"
	name := strings.trim_space(read_file(DMI + "product_name"))
	version := strings.trim_space(read_file(DMI + "product_version"))

	// Lenovo puts a type code like "82JH" in product_name and the model in product_version
	if strings.contains(version, " ") && !strings.contains(name, " ") {
		return fmt.aprintf("%s (%s)", version, name)
	}
	return name
}

// "Linux 6.12.60 (x86_64)"
get_kernel_info :: proc(uts: ^linux.UTS_Name) -> string {
	return fmt.aprintf(
		"%s %s (%s)",
		cstring(&uts.sysname[0]),
		cstring(&uts.release[0]),
		cstring(&uts.machine[0]),
	)
}

// "2 days, 3 hours, 39 mins"
get_uptime :: proc() -> string {
	info: linux.Sys_Info
	if linux.sysinfo(&info) != .NONE do return ""

	days := info.uptime / 86400
	hours := info.uptime / 3600 % 24
	mins := info.uptime / 60 % 60

	b := strings.builder_make()
	if days > 0 do fmt.sbprintf(&b, "%d %s", days, days == 1 ? "day" : "days")
	if hours > 0 {
		if len(b.buf) > 0 do strings.write_string(&b, ", ")
		fmt.sbprintf(&b, "%d %s", hours, hours == 1 ? "hour" : "hours")
	}
	if mins > 0 || len(b.buf) == 0 {
		if len(b.buf) > 0 do strings.write_string(&b, ", ")
		fmt.sbprintf(&b, "%d %s", mins, mins == 1 ? "min" : "mins")
	}
	return strings.to_string(b)
}

// "205 (nix-system), 14 (nix-user)". Counting needs `nix-store --query --references`,
// which takes tens of milliseconds, so counts are cached per profile store path and
// only recounted when a rebuild points the profile somewhere new.
get_packages_info :: proc() -> string {
	Profile :: struct {
		path:  string,
		label: string,
	}
	profiles := [?]Profile {
		{"/run/current-system/sw", "nix-system"},
		{strings.concatenate({"/etc/profiles/per-user/", env("USER")}), "nix-user"},
	}

	cache_dir := env("XDG_CACHE_HOME")
	if cache_dir == "" do cache_dir = strings.concatenate({env("HOME"), "/.cache"})
	cache_dir = strings.concatenate({cache_dir, "/nixfetch"})
	cache_path := strings.concatenate({cache_dir, "/packages"})
	cache := read_file(cache_path)

	result := strings.builder_make()
	fresh := strings.builder_make()
	stale := false

	for profile in profiles {
		target := real_path(profile.path)
		if target == "" do continue

		count, found := cached_count(cache, target)
		if !found {
			count, found = count_references(target)
			if !found do continue
			stale = true
		}
		fmt.sbprintf(&fresh, "%s %d\n", target, count)

		if count == 0 do continue
		if len(result.buf) > 0 do strings.write_string(&result, ", ")
		fmt.sbprintf(&result, "%d (%s)", count, profile.label)
	}

	// a cache that cannot be written only costs the next run a recount
	if stale && os.make_directory_all(cache_dir) == nil {
		_ = os.write_entire_file(cache_path, strings.to_string(fresh))
	}
	return strings.to_string(result)
}

// looks up "<store path> <count>" in the package cache
cached_count :: proc(cache: string, target: string) -> (count: int, found: bool) {
	rest := cache
	for line in strings.split_lines_iterator(&rest) {
		space := strings.last_index_byte(line, ' ')
		if space < 0 || line[:space] != target do continue
		return strconv.parse_int(line[space + 1:], 10)
	}
	return 0, false
}

// the number of store paths a profile refers to directly, which is its installed packages
count_references :: proc(target: string) -> (count: int, ok: bool) {
	state, stdout, _, err := os.process_exec(
		{command = {"nix-store", "--query", "--references", target}},
		context.allocator,
	)
	if err != nil || state.exit_code != 0 do return 0, false
	return strings.count(string(stdout), "\n"), true
}

// "bash 5.3p9"; the version comes from the shell's nix store path, which is cheaper
// than running it with --version
get_shell_info :: proc() -> string {
	path := env("SHELL")
	if path == "" do return ""

	name := path
	if slash := strings.last_index_byte(path, '/'); slash >= 0 do name = path[slash + 1:]
	if version := store_version(real_path(path)); version != "" {
		return fmt.aprintf("%s %s", name, version)
	}
	return name
}

// every connected display, "1920x1080 @ 60 Hz in 15\" [Built-in]", comma separated
get_display_info :: proc() -> string {
	result := strings.builder_make()
	for name in list_dir("/sys/class/drm") {
		// "card1-eDP-1" is a connector, "card1" the gpu it hangs off
		dash := strings.index_byte(name, '-')
		if !strings.has_prefix(name, "card") || dash < 0 do continue

		dir := strings.concatenate({"/sys/class/drm/", name, "/"})
		if read_line(strings.concatenate({dir, "status"})) != "connected" do continue

		width, height, refresh, inches: int
		edid := read_file(strings.concatenate({dir, "edid"}))
		if len(edid) >= 128 {
			width, height, refresh, inches = parse_edid(transmute([]u8)edid)
		}
		if width == 0 {
			// no usable edid, the first listed mode is the preferred one
			mode := read_line(strings.concatenate({dir, "modes"}))
			x := strings.index_byte(mode, 'x')
			if x < 0 do continue
			width, _ = strconv.parse_int(mode[:x], 10)
			height, _ = strconv.parse_int(mode[x + 1:], 10)
		}

		if len(result.buf) > 0 do strings.write_string(&result, ", ")
		fmt.sbprintf(&result, "%dx%d", width, height)
		if refresh > 0 do fmt.sbprintf(&result, " @ %d Hz", refresh)
		if inches > 0 do fmt.sbprintf(&result, " in %d\"", inches)

		connector := name[dash + 1:]
		if strings.has_prefix(connector, "eDP") ||
		   strings.has_prefix(connector, "LVDS") ||
		   strings.has_prefix(connector, "DSI") {
			strings.write_string(&result, " [Built-in]")
		}
	}
	return strings.to_string(result)
}

// the preferred mode and screen size out of an EDID base block
parse_edid :: proc(edid: []u8) -> (width, height, refresh, inches: int) {
	// the first detailed timing descriptor is the preferred mode; a zero pixel clock
	// means the slot holds something else
	t := edid[54:72]
	clock := int(t[0]) | int(t[1]) << 8 // in 10 kHz
	if clock == 0 do return

	width = int(t[2]) | int(t[4] >> 4) << 8
	h_blank := int(t[3]) | int(t[4] & 0xf) << 8
	height = int(t[5]) | int(t[7] >> 4) << 8
	v_blank := int(t[6]) | int(t[7] & 0xf) << 8
	if total := (width + h_blank) * (height + v_blank); total > 0 {
		refresh = int(math.round(f64(clock) * 10_000 / f64(total)))
	}

	// bytes 21 and 22 are the screen's width and height in cm
	cm := math.sqrt(f64(edid[21]) * f64(edid[21]) + f64(edid[22]) * f64(edid[22]))
	inches = int(math.round(cm / 2.54))
	return
}

// "niri (Wayland)"
get_desktop_info :: proc() -> string {
	desktop := env("XDG_CURRENT_DESKTOP")
	if desktop == "" do desktop = env("DESKTOP_SESSION")
	if desktop == "" do return ""

	switch env("XDG_SESSION_TYPE") {
	case "wayland":
		return fmt.aprintf("%s (Wayland)", desktop)
	case "x11":
		return fmt.aprintf("%s (X11)", desktop)
	}
	return desktop
}

// gtk2, gtk3 and gtk4 settings files, read once for the theme, icons and cursor fields
read_gtk_settings :: proc() -> [3]string {
	config := config_dir()
	return {
		read_file(strings.concatenate({env("HOME"), "/.gtkrc-2.0"})),
		read_file(strings.concatenate({config, "/gtk-3.0/settings.ini"})),
		read_file(strings.concatenate({config, "/gtk-4.0/settings.ini"})),
	}
}

// "rose-pine-gtk [GTK2/3/4]", naming every gtk version that sets key
get_gtk_setting :: proc(gtk: [3]string, key: string) -> string {
	name := ""
	versions := strings.builder_make()
	for content, i in gtk {
		value := strings.trim(parse_field(content, key, '='), "\"")
		if value == "" do continue
		if name == "" do name = value
		strings.write_string(&versions, len(versions.buf) == 0 ? "GTK" : "/")
		strings.write_int(&versions, i + 2)
	}
	if name == "" do return ""
	return fmt.aprintf("%s [%s]", name, strings.to_string(versions))
}

// "BreezeX-RosePine-Linux (32px)", from the env the compositor exports, else gtk
get_cursor_info :: proc(gtk: [3]string) -> string {
	name := env("XCURSOR_THEME")
	size := env("XCURSOR_SIZE")
	for content in gtk {
		if name == "" do name = strings.trim(parse_field(content, "gtk-cursor-theme-name", '='), "\"")
		if size == "" do size = parse_field(content, "gtk-cursor-theme-size", '=')
	}
	if name == "" do return ""
	if size == "" do return name
	return fmt.aprintf("%s (%spx)", name, size)
}

// "ghostty 1.3.1"
get_terminal_info :: proc() -> string {
	if name := env("TERM_PROGRAM"); name != "" {
		if version := env("TERM_PROGRAM_VERSION"); version != "" {
			return fmt.aprintf("%s %s", name, version)
		}
		return name
	}

	// kitty and foot say who they are through TERM instead
	term := env("TERM")
	if strings.has_prefix(term, "xterm-") && term != "xterm-256color" do return term[len("xterm-"):]
	return term
}

// "Iosevka Nerd Font (13.5pt)", from the terminal's own config
get_terminal_font :: proc(terminal: string) -> string {
	family, size: string
	switch {
	case strings.has_prefix(terminal, "ghostty"):
		config := read_file(strings.concatenate({config_dir(), "/ghostty/config"}))
		family = parse_field(config, "font-family", '=')
		size = parse_field(config, "font-size", '=')
	case strings.has_prefix(terminal, "kitty"):
		config := read_file(strings.concatenate({config_dir(), "/kitty/kitty.conf"}))
		family = parse_field(config, "font_family", ' ')
		size = parse_field(config, "font_size", ' ')
	}
	family = strings.trim(family, "\"")
	if family == "" do return ""

	if points, ok := strconv.parse_f64(size); ok {
		// ghostty writes 13.5 as "13.500000"
		return fmt.aprintf("%s (%spt)", family, strings.trim_right(fmt.tprintf("%.2f", points), ".0"))
	}
	return family
}

// "Intel Core i7-11800H (16) @ 4.60 GHz"
get_cpu_info :: proc() -> string {
	content := read_file("/proc/cpuinfo")
	model := parse_field(content, "model name", ':')
	if model == "" do return ""

	b := strings.builder_make()

	// drop the "(R)" and "(TM)" noise and the base clock baked into the name,
	// the max clock is printed separately
	if at := strings.index(model, " @ "); at >= 0 do model = model[:at]
	next: for i := 0; i < len(model); {
		for noise in ([?]string{"(R)", "(TM)", "(r)", "(tm)"}) {
			if strings.has_prefix(model[i:], noise) {
				i += len(noise)
				continue next
			}
		}
		strings.write_byte(&b, model[i])
		i += 1
	}

	// every logical cpu gets its own "processor" record
	threads := strings.count(content, "\nprocessor")
	if strings.has_prefix(content, "processor") do threads += 1
	if threads > 0 do fmt.sbprintf(&b, " (%d)", threads)

	max_khz := strings.trim_space(read_file("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"))
	if khz, ok := strconv.parse_int(max_khz, 10); ok {
		fmt.sbprintf(&b, " @ %.2f GHz", f64(khz) / 1_000_000)
	}
	return strings.to_string(b)
}

// the pci id database; builds can bake a path in with -define:NIXFETCH_PCI_IDS=<path>,
// and NIXFETCH_PCI_IDS in the environment overrides both
PCI_IDS :: #config(NIXFETCH_PCI_IDS, "")

@(rodata)
PCI_IDS_PATHS := [?]string {
	"/usr/share/hwdata/pci.ids",
	"/usr/share/misc/pci.ids",
	"/run/current-system/sw/share/hwdata/pci.ids",
}

read_pci_ids :: proc() -> string {
	if path := env("NIXFETCH_PCI_IDS"); path != "" do return read_file(path)
	when PCI_IDS != "" {
		if db := read_file(PCI_IDS); db != "" do return db
	}
	for path in PCI_IDS_PATHS {
		if db := read_file(path); db != "" do return db
	}
	return ""
}

// finds a vendor and device name in the pci id database; both alias db
pci_ids_lookup :: proc(db, vendor_id, device_id: string) -> (vendor, device: string) {
	rest := db
	in_vendor := false
	for line in strings.split_lines_iterator(&rest) {
		if len(line) == 0 || line[0] == '#' do continue

		// vendors sit at column zero, their devices one tab in, subsystems two
		if line[0] != '\t' {
			if in_vendor do return
			if strings.has_prefix(line, vendor_id) {
				in_vendor = true
				vendor = strings.trim_space(line[len(vendor_id):])
			}
			continue
		}
		if !in_vendor || strings.has_prefix(line, "\t\t") do continue
		if strings.has_prefix(line[1:], device_id) {
			device = strings.trim_space(line[1 + len(device_id):])
			return
		}
	}
	return
}

// every pci gpu, "NVIDIA GeForce RTX 3060 Laptop GPU, Intel UHD Graphics"
get_gpu_info :: proc() -> string {
	// loaded on the first gpu the driver cannot name
	pci_ids: Maybe(string)
	result := strings.builder_make()

	for name in list_dir("/sys/class/drm") {
		if !strings.has_prefix(name, "card") || strings.contains(name, "-") do continue

		uevent := read_file(strings.concatenate({"/sys/class/drm/", name, "/device/uevent"}))
		pci_id := strings.to_lower(parse_field(uevent, "PCI_ID", '='))
		if len(pci_id) != 9 do continue // "vvvv:dddd", only pci gpus have one
		vendor_id, device_id := pci_id[:4], pci_id[5:]

		if len(result.buf) > 0 do strings.write_string(&result, ", ")

		// the proprietary nvidia driver knows its card's marketing name
		if parse_field(uevent, "DRIVER", '=') == "nvidia" {
			slot := parse_field(uevent, "PCI_SLOT_NAME", '=')
			info := read_file(strings.concatenate({"/proc/driver/nvidia/gpus/", slot, "/information"}))
			if model := parse_field(info, "Model", ':'); model != "" {
				strings.write_string(&result, model)
				continue
			}
		}

		if pci_ids == nil do pci_ids = read_pci_ids()
		vendor, device := pci_ids_lookup(pci_ids.?, vendor_id, device_id)
		vendor = short_vendor(vendor_id, vendor)
		if device == "" {
			fmt.sbprintf(&result, "%s [%s]", vendor, pci_id)
			continue
		}
		// "TigerLake-H GT1 [UHD Graphics]": the bracketed name is the one people know
		if open := strings.index_byte(device, '['); open >= 0 && strings.has_suffix(device, "]") {
			device = device[open + 1:len(device) - 1]
		}
		fmt.sbprintf(&result, "%s %s", vendor, device)
	}
	return strings.to_string(result)
}

// "Advanced Micro Devices, Inc. [AMD/ATI]" is just AMD on a fetch line
short_vendor :: proc(vendor_id, vendor: string) -> string {
	switch vendor_id {
	case "10de":
		return "NVIDIA"
	case "8086":
		return "Intel"
	case "1002", "1022":
		return "AMD"
	}
	return vendor if vendor != "" else vendor_id
}

// used and total bytes of ram, or of swap, from /proc/meminfo
read_meminfo :: proc(swap: bool) -> (used, total: u64, ok: bool) {
	content := read_file("/proc/meminfo")
	kb :: proc(content, key: string) -> (u64, bool) {
		value := strings.trim_suffix(parse_field(content, key, ':'), " kB")
		n, ok := strconv.parse_u64(value, 10)
		return n * 1024, ok
	}

	if swap {
		total = kb(content, "SwapTotal") or_return
		free := kb(content, "SwapFree") or_return
		return total - free, total, true
	}
	total = kb(content, "MemTotal") or_return
	available := kb(content, "MemAvailable") or_return
	return total - available, total, true
}

// "7.26 GiB / 14.97 GiB (48%)"
get_memory_info :: proc() -> string {
	used, total, ok := read_meminfo(false)
	if !ok || total == 0 do return ""
	return format_usage(used, total)
}

// "[ ■■■■■■■■■─────────── ]"
get_memory_bar :: proc() -> string {
	used, total, ok := read_meminfo(false)
	if !ok || total == 0 do return ""
	return format_usage_bar(used, total)
}

// "1.20 GiB / 8.00 GiB (15%)", or "Disabled"
get_swap_info :: proc() -> string {
	used, total, ok := read_meminfo(true)
	if !ok do return ""
	if total == 0 do return "Disabled"
	return format_usage(used, total)
}

// "183.52 GiB / 944.85 GiB (19%) - btrfs" for the root filesystem
get_disk_info :: proc() -> string {
	stat: linux.Stat_FS
	if linux.statfs("/", &stat) != .NONE || stat.blocks == 0 do return ""
	total := u64(stat.blocks) * u64(stat.bsize)
	used := u64(stat.blocks - stat.bfree) * u64(stat.bsize)

	// statfs's magic cannot tell ext2/3/4 apart, /proc/mounts names the type outright;
	// lines read "<device> <mount point> <type> ..."
	mounts := read_file("/proc/mounts")
	for line in strings.split_lines_iterator(&mounts) {
		fields := strings.fields(line)
		if len(fields) >= 3 && fields[1] == "/" {
			return fmt.aprintf("%s - %s", format_usage(used, total), fields[2])
		}
	}
	return format_usage(used, total)
}

// the struct ifreq that SIOCGIFADDR and SIOCGIFNETMASK fill in
Ifreq :: struct {
	name: [16]u8,
	addr: linux.Sock_Addr_In,
	_:    [8]u8,
}
SIOCGIFADDR :: 0x8915
SIOCGIFNETMASK :: 0x891b

// "192.168.18.5/24 (wlp0s20f3)" for the interface holding the default route
get_local_ip :: proc() -> string {
	// /proc/net/route columns are tab separated: interface, destination, gateway, ...
	iface := ""
	routes := read_file("/proc/net/route")
	for line in strings.split_lines_iterator(&routes) {
		fields := strings.split(line, "\t")
		if len(fields) > 1 && fields[1] == "00000000" {
			iface = fields[0]
			break
		}
	}
	if iface == "" || len(iface) >= 16 do return ""

	fd, errno := linux.socket(.INET, .DGRAM, {}, .HOPOPT) // protocol 0, the default for the type
	if errno != .NONE do return ""
	defer linux.close(fd)

	request: Ifreq
	copy(request.name[:], iface)
	if int(linux.ioctl(fd, SIOCGIFADDR, uintptr(&request))) < 0 do return ""
	address := request.addr.sin_addr
	if int(linux.ioctl(fd, SIOCGIFNETMASK, uintptr(&request))) < 0 do return ""
	prefix := intrinsics.count_ones(transmute(u32)request.addr.sin_addr)

	return fmt.aprintf(
		"%d.%d.%d.%d/%d (%s)",
		address[0],
		address[1],
		address[2],
		address[3],
		prefix,
		iface,
	)
}

// "60% [Not charging]" for the first battery
get_battery_info :: proc() -> string {
	for name in list_dir("/sys/class/power_supply") {
		dir := strings.concatenate({"/sys/class/power_supply/", name, "/"})
		if read_line(strings.concatenate({dir, "type"})) != "Battery" do continue
		capacity := read_line(strings.concatenate({dir, "capacity"}))
		if capacity == "" do continue

		if status := read_line(strings.concatenate({dir, "status"})); status != "" {
			return fmt.aprintf("%s%% [%s]", capacity, status)
		}
		return fmt.aprintf("%s%%", capacity)
	}
	return ""
}

// "en_US.UTF-8"
get_locale :: proc() -> string {
	if locale := env("LC_ALL"); locale != "" do return locale
	return env("LANG")
}

// "272 days", counted from when the root filesystem was created
get_os_age :: proc() -> string {
	stx: linux.Statx
	if linux.statx(linux.AT_FDCWD, "/", {}, {.BTIME}, &stx) != .NONE do return ""
	if .BTIME not_in stx.mask do return ""
	now, errno := linux.clock_gettime(.REALTIME)
	if errno != .NONE do return ""

	days := (i64(now.time_sec) - stx.btime.sec) / 86400
	return fmt.aprintf("%d %s", days, days == 1 ? "day" : "days")
}
