uname := "ArMonarch"
name := "nixfetch"
src := "src"

# build debug binary (no optimization)
build-debug:
  [ -d target/debug ] || mkdir -p target/debug
  odin build {{src}} -out:target/debug/{{name}} -o:none -debug

# build minimal binary (minimal optimization)
build-minimal:
  [ -d target/minimal ] || mkdir -p target/minimal
  odin build {{src}} -out:target/minimal/{{name}} -o:minimal

# build size binary (size optimization)
build-size:
  [ -d target/size ] || mkdir -p target/size
  odin build {{src}} -out:target/size/{{name}} -o:size

# build speed binary (speed optimization)
build-speed:
  [ -d target/speed ] || mkdir -p target/speed
  odin build {{src}} -out:target/speed/{{name}} -o:speed

# build aggressive binary (aggressive optimization)
build-aggressive:
  [ -d target/aggressive ] || mkdir -p target/aggressive
  odin build {{src}} -out:target/aggressive/{{name}} -o:aggressive

# build profile binary (aggressive optimization + debug symbols for profiling)
build-profile:
  [ -d target/profile ] || mkdir -p target/profile
  odin build {{src}} -out:target/profile/{{name}} -o:aggressive -debug

# build and run debug binary
run-debug: build-debug
  ./target/debug/{{name}}

# build and run minimal binary
run-minimal: build-minimal
  ./target/minimal/{{name}}

# build and run size binary
run-size: build-size
  ./target/size/{{name}}

# build and run speed binary
run-speed: build-speed
  ./target/speed/{{name}}

# build and run aggressive binary
run-aggressive: build-aggressive
  ./target/aggressive/{{name}}

# build and test memleak with valgrind
memcheck: build-debug
  valgrind --tool=memcheck --track-origins=yes --leak-check=full -s ./target/debug/nixfetch

profile: build-profile
  perf record -F 9999 -g --call-graph dwarf -- ./target/profile/{{name}}
  perf script report flamegraph

alias build:= build-debug
alias run:= run-debug
