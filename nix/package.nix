{
  lib,
  stdenv,
  odin-bin,
  llvmPackages,
  glibc,
  # link libc into the binary, so it runs on any Linux and not just NixOS
  static ? false,
}:
stdenv.mkDerivation {
  pname = "nixfetch";
  version = "0.4.11";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../src
      ../build.odin
    ];
  };

  nativeBuildInputs = [
    odin-bin."dev-2026-07a"
    llvmPackages.bintools-unwrapped
  ];

  buildInputs = lib.optional static glibc.static;

  buildPhase = ''
    runHook preBuild
    # with glibc.static on the search path the build script finds libc.a too, so link it statically as well
    odin run build.odin -file ${lib.optionalString static "-extra-linker-flags:-static"} -- build -o:aggressive -link:${if static then "static" else "dynamic"}
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
