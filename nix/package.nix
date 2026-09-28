{
  lib,
  stdenv,
  odin-bin,
  llvmPackages,
  hwdata,
  # compile-time settings, e.g. nixfetch.override { layout = "Glacier"; }
  layout ? "Flurry",
  icons ? true,
}:
stdenv.mkDerivation {
  pname = "nixfetch";
  version = "0.4.11";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./../src
      ./../build.odin
    ];
  };

  nativeBuildInputs = [
    odin-bin."dev-2026-09"
    llvmPackages.bintools-unwrapped
  ];

  buildPhase = ''
    runHook preBuild
    odin run build.odin -file -- build -o:aggressive \
      -layout:${layout} \
      -icons:${lib.boolToString icons} \
      -pci-ids:${hwdata}/share/hwdata/pci.ids
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 ./target/aggressive/nixfetch $out/bin/nixfetch
    runHook postInstall
  '';

  meta = with lib; {
    description = "A fast system information fetch tool for NixOS";
    homepage = "https://github.com/ArMonarch/nixfetch";
    license = licenses.mit;
    mainProgram = "nixfetch";
    platforms = platforms.linux;
  };
}
