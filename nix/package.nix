{
  lib,
  stdenv,
  autoPatchelfHook,
  odin-bin,
}:
stdenv.mkDerivation {
  pname = "nixfetch";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ./../src
    ];
  };

  nativeBuildInputs = [
    odin-bin."dev-2026-03".latest
    autoPatchelfHook
  ];

  buildPhase = ''
    runHook preBuild
    odin build src -out:nixfetch -o:aggressive
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 nixfetch $out/bin/nixfetch
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
