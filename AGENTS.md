# nixfetch

A fast, minimal system information fetch tool for Linux, written in Odin —
system info printed beside a NixOS logo, or a custom image over the Kitty
graphics protocol. The user drives design — no fixed architecture or roadmap;
implement each change as guided, and ask when direction is unclear.

## Layout

`src/` is the program: `main.odin` collects and prints, `lib.odin` gathers
each field, `logo.odin` holds the logos. `build.odin` is the build system
(`odin run build.odin -file -- build|run|clean`), output under `target/`.
`nix/` and `flake.nix` package it; `.github/workflows/release.yml` builds
releases on `vX.Y.Z` tags.

## Commits

Messages are to the point and follow `feat|chore|refactor|fix(scope): <message>`.
No Co-Authored-By or other trailers.
