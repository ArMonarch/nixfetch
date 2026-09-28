package nixfetch

// which layout to print, fixed at build time: -define:NIXFETCH_LAYOUT=glacier
//   flurry  - icon, label, "¦", value, with a color palette row      (image 1)
//   frost   - user@host, a dashed rule, "Label: value" lines         (image 2)
//   glacier - fields grouped into titled boxes                       (image 3)
//   icicle  - short upper-case labels, memory drawn as a bar         (image 4)
LAYOUT :: #config(NIXFETCH_LAYOUT, "flurry")
#assert(
	LAYOUT == "flurry" || LAYOUT == "frost" || LAYOUT == "glacier" || LAYOUT == "icicle",
	"NIXFETCH_LAYOUT must be one of flurry, frost, glacier or icicle",
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
