package nixfetch

import "core:strings"
nixos_logo_fmt :: proc() -> string {
	// :........................................:
	// :                                        :
	// :         ◢██◣     ◥███◣  ◢██◣           :
	// :         ◥███◣     ◥███◣◢███◤           :
	// :          ◥███◣     ◥██████◤            :
	// :      ◢███████████████████◤   ◢◣        :
	// :     ◢████████████████████◣  ◢██◣       :
	// :          ◢███◤        ◥███◣◢███◤       :
	// :         ◢███◤          ◥██████◤        :
	// :  ◢█████████◤            ◥█████████◣    :
	// :  ◥█████████◣            ◢█████████◤    :
	// :      ◢██████◣          ◢███◤           :
	// :     ◢███◤◥███◣        ◢███◤            :
	// :     ◥██◤  ◥████████████████████◤       :
	// :      ◥◤   ◢███████████████████◤        :
	// :          ◢██████◣     ◥███◣            :
	// :         ◢███◤◥███◣     ◥███◣           :
	// :         ◥██◤  ◥███◣     ◥██◤           :
	// :                                        :
	// :........................................:

	fmt := strings.builder_make(0)

	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"         ◢██◣     ◥███◣  ◢██◣           ",
	)
	strings.write_string(&fmt, "%s\n")
	strings.write_string(
		&fmt,
		"         ◥███◣     ◥███◣◢███◤           ",
	)
	strings.write_string(&fmt, "%-16s: %s\n")
	strings.write_string(
		&fmt,
		"          ◥███◣     ◥██████◤            ",
	)
	strings.write_string(&fmt, "%-16s: %s\n")
	strings.write_string(
		&fmt,
		"      ◢███████████████████◤   ◢◣        ",
	)

	strings.write_string(&fmt, "%-16s: %s\n")
	strings.write_string(
		&fmt,
		"     ◢████████████████████◣  ◢██◣       ",
	)
	strings.write_string(&fmt, "%-16s: %s\n")
	strings.write_string(
		&fmt,
		"          ◢███◤        ◥███◣◢███◤       ",
	)
	strings.write_string(&fmt, "%-16s: %s\n")
	strings.write_string(
		&fmt,
		"         ◢███◤          ◥██████◤        ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"  ◢█████████◤            ◥█████████◣    ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"  ◥█████████◣            ◢█████████◤    ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"      ◢██████◣          ◢███◤           ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"     ◢███◤◥███◣        ◢███◤            ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"     ◥██◤  ◥████████████████████◤       ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"      ◥◤   ◢███████████████████◤        ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"          ◢██████◣     ◥███◣            ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"         ◢███◤◥███◣     ◥███◣           ",
	)
	strings.write_string(&fmt, "\n")
	strings.write_string(
		&fmt,
		"         ◥██◤  ◥███◣     ◥██◤           ",
	)

	return strings.to_string(fmt)
}
