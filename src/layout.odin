package nixfetch

import "core:encoding/base64"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:sys/linux"

// fills in only the fields LAYOUT prints, formatted the way it prints them
collect :: proc(sys: ^System) {
	uts: linux.UTS_Name
	linux.uname(&uts)

	when LAYOUT == "Flurry" {
		sys.user_info = get_user_info(&uts)
		sys.os_name = get_os_name()
		sys.kernel_info = get_kernel_info(&uts)
		sys.shell_info = get_shell_info()
		sys.uptime = get_uptime()
		sys.desktop_info = get_desktop_info()
		sys.memory_info = get_memory_info()
		sys.disk_info = get_disk_info()
		sys.colors = COLOR_DOTS
	} else when LAYOUT == "Frost" {
		gtk := read_gtk_settings()
		sys.user_info = get_user_info(&uts)
		sys.os_name = get_os_name()
		sys.host_info = get_host_info()
		sys.kernel_info = get_kernel_info(&uts)
		sys.uptime = get_uptime()
		sys.packages_info = get_packages_info()
		sys.shell_info = get_shell_info()
		sys.display_info = get_display_info()
		sys.desktop_info = get_desktop_info()
		sys.theme_info = get_gtk_setting(gtk, "gtk-theme-name")
		sys.cursor_info = get_cursor_info(gtk)
		sys.terminal_info = get_terminal_info()
		sys.terminal_font = get_terminal_font(sys.terminal_info)
		sys.cpu_info = get_cpu_info()
		sys.gpu_info = get_gpu_info()
		sys.memory_info = get_memory_info()
		sys.swap_info = get_swap_info()
		sys.disk_info = get_disk_info()
		sys.local_ip = get_local_ip()
		sys.battery_info = get_battery_info()
		sys.locale = get_locale()
		sys.colors = COLOR_BLOCKS
	} else when LAYOUT == "Glacier" {
		gtk := read_gtk_settings()
		sys.host_info = get_host_info()
		sys.display_info = get_display_info()
		sys.cpu_info = get_cpu_info()
		sys.gpu_info = get_gpu_info()
		sys.memory_info = get_memory_info()
		sys.disk_info = get_disk_info()
		sys.os_name = get_os_name()
		sys.kernel_info = get_kernel_info(&uts)
		sys.desktop_info = get_desktop_info()
		sys.packages_info = get_packages_info()
		sys.uptime = get_uptime()
		sys.os_age = get_os_age()
		sys.shell_info = get_shell_info()
		sys.terminal_info = get_terminal_info()
		sys.terminal_font = get_terminal_font(sys.terminal_info)
		sys.theme_info = get_gtk_setting(gtk, "gtk-theme-name")
		sys.icons_info = get_gtk_setting(gtk, "gtk-icon-theme-name")
		sys.locale = get_locale()
		sys.colors = COLOR_DIAMONDS
	} else when LAYOUT == "Icicle" {
		gtk := read_gtk_settings()
		sys.os_name = get_os_name()
		sys.host_info = get_host_info()
		sys.uptime = get_uptime()
		sys.packages_info = get_packages_info()
		sys.shell_info = get_shell_info()
		sys.desktop_info = get_desktop_info()
		sys.theme_info = get_gtk_setting(gtk, "gtk-theme-name")
		sys.icons_info = get_gtk_setting(gtk, "gtk-icon-theme-name")
		sys.cursor_info = get_cursor_info(gtk)
		sys.terminal_info = get_terminal_info()
		sys.cpu_info = get_cpu_info()
		sys.gpu_info = get_gpu_info()
		sys.memory_info = get_memory_bar()
	}
}

// the text column, one string per terminal line, in LAYOUT's order
layout_lines :: proc(sys: ^System) -> [dynamic]string {
	lines := make([dynamic]string)

	when LAYOUT == "Flurry" {
		STYLE :: FG_BLUE
		WIDTH :: 11
		SEP :: FG_GRAY + " : " + RESET
		append(&lines, sys.user_info)
		row(&lines, STYLE, ICON_OS, "System", WIDTH, SEP, sys.os_name)
		row(&lines, STYLE, ICON_KERNEL, "Kernel", WIDTH, SEP, sys.kernel_info)
		row(&lines, STYLE, ICON_SHELL, "Shell", WIDTH, SEP, sys.shell_info)
		row(&lines, STYLE, ICON_UPTIME, "Uptime", WIDTH, SEP, sys.uptime)
		row(&lines, STYLE, ICON_DESKTOP, "Desktop", WIDTH, SEP, sys.desktop_info)
		row(&lines, STYLE, ICON_MEMORY, "Memory", WIDTH, SEP, sys.memory_info)
		row(&lines, STYLE, ICON_DISK, "Storage (/)", WIDTH, SEP, sys.disk_info)
		row(&lines, STYLE, ICON_COLORS, "Colors", WIDTH, SEP, sys.colors)
	} else when LAYOUT == "Frost" {
		STYLE :: BOLD + FG_BLUE
		SEP :: ": "
		append(&lines, sys.user_info, strings.repeat("-", visible_width(sys.user_info)))
		row(&lines, STYLE, ICON_OS, "OS", 0, SEP, sys.os_name)
		row(&lines, STYLE, ICON_HOST, "Host", 0, SEP, sys.host_info)
		row(&lines, STYLE, ICON_KERNEL, "Kernel", 0, SEP, sys.kernel_info)
		row(&lines, STYLE, ICON_UPTIME, "Uptime", 0, SEP, sys.uptime)
		row(&lines, STYLE, ICON_PACKAGES, "Packages", 0, SEP, sys.packages_info)
		row(&lines, STYLE, ICON_SHELL, "Shell", 0, SEP, sys.shell_info)
		row(&lines, STYLE, ICON_DISPLAY, "Display", 0, SEP, sys.display_info)
		row(&lines, STYLE, ICON_DESKTOP, "WM", 0, SEP, sys.desktop_info)
		row(&lines, STYLE, ICON_THEME, "Theme", 0, SEP, sys.theme_info)
		row(&lines, STYLE, ICON_CURSOR, "Cursor", 0, SEP, sys.cursor_info)
		row(&lines, STYLE, ICON_TERMINAL, "Terminal", 0, SEP, sys.terminal_info)
		row(&lines, STYLE, ICON_TERMINAL_FONT, "Terminal Font", 0, SEP, sys.terminal_font)
		row(&lines, STYLE, ICON_CPU, "CPU", 0, SEP, sys.cpu_info)
		row(&lines, STYLE, ICON_GPU, "GPU", 0, SEP, sys.gpu_info)
		row(&lines, STYLE, ICON_MEMORY, "Memory", 0, SEP, sys.memory_info)
		row(&lines, STYLE, ICON_SWAP, "Swap", 0, SEP, sys.swap_info)
		row(&lines, STYLE, ICON_DISK, "Disk (/)", 0, SEP, sys.disk_info)
		row(&lines, STYLE, ICON_LOCAL_IP, "Local IP", 0, SEP, sys.local_ip)
		row(&lines, STYLE, ICON_BATTERY, "Battery", 0, SEP, sys.battery_info)
		row(&lines, STYLE, ICON_LOCALE, "Locale", 0, SEP, sys.locale)
		append(&lines, "")
		append(&lines, ..strings.split(sys.colors, "\n"))
	} else when LAYOUT == "Glacier" {
		STYLE :: ITALIC + FG_CYAN
		WIDTH :: 13
		SEP :: FG_GRAY + " » " + RESET
		specs, software, session: [dynamic]string

		row(&specs, STYLE, ICON_HOST, "Host", WIDTH, SEP, sys.host_info)
		row(&specs, STYLE, ICON_DISPLAY, "Display", WIDTH, SEP, sys.display_info)
		row(&specs, STYLE, ICON_CPU, "CPU", WIDTH, SEP, sys.cpu_info)
		row(&specs, STYLE, ICON_GPU, "GPU", WIDTH, SEP, sys.gpu_info)
		row(&specs, STYLE, ICON_MEMORY, "Memory", WIDTH, SEP, sys.memory_info)
		row(&specs, STYLE, ICON_DISK, "Disk", WIDTH, SEP, sys.disk_info)

		row(&software, STYLE, ICON_OS, "OS", WIDTH, SEP, sys.os_name)
		row(&software, STYLE, ICON_KERNEL, "Kernel", WIDTH, SEP, sys.kernel_info)
		row(&software, STYLE, ICON_DESKTOP, "WM", WIDTH, SEP, sys.desktop_info)
		row(&software, STYLE, ICON_PACKAGES, "Packages", WIDTH, SEP, sys.packages_info)
		row(&software, STYLE, ICON_UPTIME, "Uptime", WIDTH, SEP, sys.uptime)
		row(&software, STYLE, ICON_OS_AGE, "OS Age", WIDTH, SEP, sys.os_age)

		row(&session, STYLE, ICON_SHELL, "Shell", WIDTH, SEP, sys.shell_info)
		row(&session, STYLE, ICON_TERMINAL, "Terminal", WIDTH, SEP, sys.terminal_info)
		row(&session, STYLE, ICON_TERMINAL_FONT, "Terminal Font", WIDTH, SEP, sys.terminal_font)
		row(&session, STYLE, ICON_THEME, "Theme", WIDTH, SEP, sys.theme_info)
		row(&session, STYLE, ICON_ICONS, "Icons", WIDTH, SEP, sys.icons_info)
		row(&session, STYLE, ICON_LOCALE, "Locale", WIDTH, SEP, sys.locale)

		// every box as wide as the widest row in any of them, so their edges line up
		width := 0
		for r in specs do width = max(width, visible_width(r))
		for r in software do width = max(width, visible_width(r))
		for r in session do width = max(width, visible_width(r))

		boxed(&lines, ICON_CPU, "System Specs", width, specs[:])
		boxed(&lines, ICON_OS, "Software Specs", width, software[:])
		boxed(&lines, ICON_TERMINAL, "Session", width, session[:])
		append(&lines, strings.concatenate({"  ", sys.colors}))
	} else when LAYOUT == "Icicle" {
		STYLE :: FG_BLUE
		WIDTH :: 7
		SEP :: " "
		row(&lines, STYLE, ICON_OS, "OS:", WIDTH, SEP, sys.os_name)
		row(&lines, STYLE, ICON_HOST, "HOST:", WIDTH, SEP, sys.host_info)
		row(&lines, STYLE, ICON_UPTIME, "UP:", WIDTH, SEP, sys.uptime)
		row(&lines, STYLE, ICON_PACKAGES, "PKGS:", WIDTH, SEP, sys.packages_info)
		row(&lines, STYLE, ICON_SHELL, "SH:", WIDTH, SEP, sys.shell_info)
		row(&lines, STYLE, ICON_DESKTOP, "DE:", WIDTH, SEP, sys.desktop_info)
		row(&lines, STYLE, ICON_THEME, "THEME:", WIDTH, SEP, sys.theme_info)
		row(&lines, STYLE, ICON_ICONS, "ICON:", WIDTH, SEP, sys.icons_info)
		row(&lines, STYLE, ICON_CURSOR, "CUR:", WIDTH, SEP, sys.cursor_info)
		row(&lines, STYLE, ICON_TERMINAL, "TERM:", WIDTH, SEP, sys.terminal_info)
		row(&lines, STYLE, ICON_CPU, "CPU:", WIDTH, SEP, sys.cpu_info)
		row(&lines, STYLE, ICON_GPU, "GPU:", WIDTH, SEP, sys.gpu_info)
		row(&lines, STYLE, ICON_MEMORY, "MEM:", WIDTH, SEP, sys.memory_info)
	}

	return lines
}

// "<icon> <label><padding><sep><value>", left out when the field has no value
row :: proc(lines: ^[dynamic]string, style, icon, label: string, width: int, sep, value: string) {
	if value == "" do return

	b := strings.builder_make()
	strings.write_string(&b, style)
	when SHOW_ICONS {
		strings.write_string(&b, icon)
		strings.write_byte(&b, ' ')
	}
	strings.write_string(&b, label)
	for _ in len(label) ..< width do strings.write_byte(&b, ' ')
	strings.write_string(&b, RESET)
	strings.write_string(&b, sep)
	strings.write_string(&b, value)
	append(lines, strings.to_string(b))
}

// a titled section with its rows between two rules, as Glacier draws them
boxed :: proc(lines: ^[dynamic]string, icon, title: string, width: int, rows: []string) {
	if len(rows) == 0 do return
	rule := strings.repeat("─", width + 2)

	when SHOW_ICONS {
		append(lines, fmt.aprintf(FG_CYAN + "%s ❯ " + RESET + BOLD + "%s" + RESET, icon, title))
	} else {
		append(lines, fmt.aprintf(FG_CYAN + "❯ " + RESET + BOLD + "%s" + RESET, title))
	}
	append(lines, strings.concatenate({FG_GRAY, "┌", rule, "┐", RESET}))
	for r in rows do append(lines, strings.concatenate({"  ", r}))
	append(lines, strings.concatenate({FG_GRAY, "└", rule, "┘", RESET}))
	append(lines, "")
}

// the palette rows each layout ends with
COLOR_DOTS ::
	FG_RED + "● " + FG_GREEN + "● " + FG_YELLOW + "● " + FG_BLUE + "● " + FG_MAGENTA + "● " + FG_CYAN + "●" + RESET
COLOR_DIAMONDS ::
	FG_GRAY + "◆ " + FG_RED + "◆ " + FG_GREEN + "◆ " + FG_YELLOW + "◆ " + FG_BLUE + "◆ " + FG_MAGENTA + "◆ " + FG_CYAN + "◆ " + FG_WHITE + "◆" + RESET
COLOR_BLOCKS ::
	"\x1b[40m   \x1b[41m   \x1b[42m   \x1b[43m   \x1b[44m   \x1b[45m   \x1b[46m   \x1b[47m   " + RESET + "\n" +
	"\x1b[100m   \x1b[101m   \x1b[102m   \x1b[103m   \x1b[104m   \x1b[105m   \x1b[106m   \x1b[107m   " + RESET

// terminal cells s takes up: escape sequences take none, every other code point one
visible_width :: proc(s: string) -> int {
	width := 0
	for i := 0; i < len(s); i += 1 {
		if s[i] == 0x1b && i + 1 < len(s) && s[i + 1] == '[' {
			// a CSI sequence runs up to its final byte, 0x40 to 0x7e
			i += 2
			for i < len(s) && (s[i] < 0x40 || s[i] > 0x7e) do i += 1
			continue
		}
		if s[i] & 0xc0 != 0x80 do width += 1
	}
	return width
}

// ---------------------------------------------------------------------------
// The art column: a png from NIXFETCH_IMAGE, or the NixOS logo when there is none
// ---------------------------------------------------------------------------

// a png's absolute path, since the kitty protocol reads it from another process, and its size in pixels
Image :: struct {
	path:   string,
	width:  u32,
	height: u32,
}

// the image NIXFETCH_IMAGE points at, when it is a png
load_image :: proc() -> (image: Image, ok: bool) {
	path := env("NIXFETCH_IMAGE")
	if path == "" do return

	fd, errno := linux.open(strings.clone_to_cstring(path), {})
	if errno != .NONE do return
	defer linux.close(fd)

	// the 8 byte signature, then the IHDR chunk: length, "IHDR", width, height
	header: [24]u8
	n, _ := linux.read(fd, header[:])
	if n != len(header) || string(header[:8]) != "\x89PNG\r\n\x1a\n" || string(header[12:16]) != "IHDR" {
		return
	}
	be :: proc(b: []u8) -> u32 {return u32(b[0]) << 24 | u32(b[1]) << 16 | u32(b[2]) << 8 | u32(b[3])}
	image.width, image.height = be(header[16:20]), be(header[20:24])
	if image.width == 0 || image.height == 0 do return

	image.path = path
	if !strings.has_prefix(path, "/") {
		cwd: [4096]u8
		size, cwd_errno := linux.getcwd(cwd[:])
		if cwd_errno != .NONE || size < 1 do return
		// getcwd's length counts the terminating nul
		image.path = strings.concatenate({string(cwd[:size - 1]), "/", path})
	}
	return image, true
}

// the terminal rows an IMAGE_WIDTH cell wide image needs to keep its aspect ratio
image_rows :: proc(image: Image) -> int {
	// struct winsize, from TIOCGWINSZ
	Winsize :: struct {
		row, col, xpixel, ypixel: u16,
	}

	// how many times taller a cell is than wide, assumed 2 when the terminal will not say
	cell_ratio := 2.0
	ws: Winsize
	if linux.ioctl(linux.Fd(1), linux.TIOCGWINSZ, uintptr(&ws)) == 0 &&
	   ws.row > 0 &&
	   ws.col > 0 &&
	   ws.xpixel > 0 &&
	   ws.ypixel > 0 {
		cell_ratio = (f64(ws.ypixel) / f64(ws.row)) / (f64(ws.xpixel) / f64(ws.col))
	}
	return int(math.ceil(f64(IMAGE_WIDTH) * f64(image.height) / f64(image.width) / cell_ratio))
}

// writes the art column with lines beside it, centered on the art when it is taller
render :: proc(b: ^strings.Builder, lines: []string) {
	if image, ok := load_image(); ok {
		// the image goes 2 cells in, 3 cells of gap to the text
		TEXT_COLUMN :: 2 + IMAGE_WIDTH + 3
		rows := image_rows(image)
		top := max(0, (rows - len(lines)) / 2)
		encoded, _ := base64.encode(transmute([]u8)image.path)

		// a=T transmit and show, t=f read from a file, C=1 leave the cursor where it is,
		// q=2 no replies, which would otherwise land on the shell's prompt
		fmt.sbprintf(b, "  \x1b_Ga=T,f=100,t=f,c=%d,C=1,q=2;%s\x1b\\\r", IMAGE_WIDTH, encoded)
		for i in 0 ..< max(rows, top + len(lines)) {
			if i >= top && i - top < len(lines) {
				fmt.sbprintf(b, "\x1b[%dC%s" + RESET, TEXT_COLUMN, lines[i - top])
			}
			strings.write_byte(b, '\n')
		}
		return
	}

	logo := NIX_LOGO_ANSI_COLORED[:]
	top := max(0, (len(logo) - len(lines)) / 2)
	for i in 0 ..< max(len(logo), top + len(lines)) {
		if i < len(logo) {
			strings.write_string(b, logo[i])
			strings.write_string(b, RESET)
		} else {
			for _ in 0 ..< LOGO_WIDTH do strings.write_byte(b, ' ')
		}
		if i >= top && i - top < len(lines) {
			strings.write_string(b, lines[i - top])
			strings.write_string(b, RESET)
		}
		strings.write_byte(b, '\n')
	}
}
