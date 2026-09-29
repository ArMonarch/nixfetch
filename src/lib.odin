package nixfetch

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
	when LAYOUT == 252 do return collect_system_information_layout_252(sys)
	when LAYOUT == 269 do return collect_system_information_layout_269(sys)
	when LAYOUT == 227 do return collect_system_information_layout_227(sys)
	return collect_system_information_layout_110(sys)
}

collect_system_information_layout_110 :: proc(sys: ^SystemInformation) -> Error {
	return nil
}

collect_system_information_layout_252 :: proc(sys: ^SystemInformation) -> Error {
	return nil
}

collect_system_information_layout_269 :: proc(sys: ^SystemInformation) -> Error {
	return nil
}

collect_system_information_layout_227 :: proc(sys: ^SystemInformation) -> Error {
	return nil
}

print_system_information :: proc(sys: ^SystemInformation) -> (string, Error) {
	when LAYOUT == 252 do return print_system_information_layout_252(sys)
	when LAYOUT == 269 do return print_system_information_layout_269(sys)
	when LAYOUT == 227 do return print_system_information_layout_227(sys)
	return print_system_information_layout_110(sys)
}

print_system_information_layout_110 :: proc(sys: ^SystemInformation) -> (string, Error) {
	return "nixfetch 110", nil
}

print_system_information_layout_252 :: proc(sys: ^SystemInformation) -> (string, Error) {
	return "nixfetch 252", nil
}

print_system_information_layout_269 :: proc(sys: ^SystemInformation) -> (string, Error) {
	return "nixfetch 269", nil
}

print_system_information_layout_227 :: proc(sys: ^SystemInformation) -> (string, Error) {
	return "nixfetch 227", nil
}

// cells the NixOS logo takes up, so system info lines up on the right
LOGO_WIDTH: int : 39

// cells a custom image takes up over the Kitty graphics protocol
IMAGE_WIDTH: int : 45

// the NixOS logo, each line padded to LOGO_WIDTH
@(rodata)
NIX_LOGO_BLACK_WHITE := [?]string {
	"         ◢██◣     ◥███◣  ◢██◣          ",
	"         ◥███◣     ◥███◣◢███◤          ",
	"          ◥███◣     ◥██████◤           ",
	"      ◢███████████████████◤   ◢◣       ",
	"     ◢████████████████████◣  ◢██◣      ",
	"          ◢███◤        ◥███◣◢███◤      ",
	"         ◢███◤          ◥██████◤       ",
	"  ◢█████████◤            ◥█████████◣   ",
	"  ◥█████████◣            ◢█████████◤   ",
	"      ◢██████◣          ◢███◤          ",
	"     ◢███◤◥███◣        ◢███◤           ",
	"     ◥██◤  ◥████████████████████◤      ",
	"      ◥◤   ◢███████████████████◤       ",
	"          ◢██████◣     ◥███◣           ",
	"         ◢███◤◥███◣     ◥███◣          ",
	"         ◥██◤  ◥███◣     ◥██◤          ",
}

// the ansi colored variant of the NixOS logo
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
