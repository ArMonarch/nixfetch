package nixfetch

import "base:runtime"
import "core:encoding/base64"
import "core:fmt"
import "core:os"
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
ICON_OS            :: " " // nf-linux-nixos
ICON_HOST          :: "󰌢 " // nf-md-laptop
ICON_KERNEL        :: " " // nf-fa-linux
ICON_UPTIME        :: "󰅐 " // nf-md-clock_outline
ICON_PACKAGES      :: "󰏗 " // nf-md-package_variant
ICON_SHELL         :: " " // nf-oct-terminal
ICON_DISPLAY       :: "󰍹 " // nf-md-monitor
ICON_DESKTOP       :: " " // nf-fa-window_maximize
ICON_THEME         :: "󰏘 " // nf-md-palette
ICON_ICONS         :: "󰉏 " // nf-md-folder_image
ICON_CURSOR        :: "󰆿 " // nf-md-cursor_default
ICON_TERMINAL      :: "󰆍 " // nf-md-console
ICON_TERMINAL_FONT :: " " // nf-fa-font
ICON_CPU           :: " " // nf-oct-cpu
ICON_GPU           :: "󰢮 " // nf-md-expansion_card
ICON_MEMORY        :: "󰍛 " // nf-md-memory
ICON_SWAP          :: "󰓡 " // nf-md-swap_horizontal
ICON_DISK          :: "󰋊 " // nf-md-harddisk
ICON_LOCAL_IP      :: "󰩠 " // nf-md-ip_network
ICON_BATTERY       :: "󰁹 " // nf-md-battery
ICON_LOCALE        :: "󰇧 " // nf-md-earth
ICON_OS_AGE        :: "󰃭 " // nf-md-calendar
ICON_COLORS        :: " " // nf-fa-paint_brush
// odinfmt: enable

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

	sys.user_info = get_user_info(uts, context.temp_allocator) or_return
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
	user, user_set := os.lookup_env("USER", context.temp_allocator)
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

// the terminal as TERM_PROGRAM names it (ghostty, WezTerm, tmux, ...), "unknown" when unset
get_terminal_info :: proc(allocator: runtime.Allocator) -> (string, Error) {
	program, ok := os.lookup_env("TERM_PROGRAM", allocator)
	if !ok || program == "" do return "unknown", nil
	return program, nil
}

print_system_information :: proc(sys: ^SystemInformation) -> (string, Error) {
	image, _ := os.lookup_env("NIXFETCH_IMAGE", context.allocator)
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

	// the fields are written first, so for the image go back to the first field's line, column 1;
	// the cursor already sits on the last field's line, hence one line fewer. CSI 0 A would still
	// move up one, so nothing is written when there is a single line.
	layout_fields_count :: 1
	if has_image {
		strings.write_byte(builder, '\r')
		fmt.sbprintf(builder, "\x1b[%dA", layout_fields_count - 1)
		write_kitty_image(builder, image)
	}
	return nil
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
