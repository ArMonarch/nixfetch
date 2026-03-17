{
  lib,
  just,
  stdenv,
  odin-bin,
  llvmPackages,
}:
stdenv.mkDerivation {
  pname = "nixfetch";
  version = "0.4.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./../src
      ./../justfile
    ];
  };

  nativeBuildInputs = [
    just
    odin-bin."dev-2026-03".latest
    llvmPackages.bintools-unwrapped
  ];

  buildPhase = ''
    runHook preBuild
    just build-aggressive
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
