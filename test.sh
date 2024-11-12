#!/bin/bash

# Check if input argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <input>"
    exit 1
fi

INPUT=$1

# Run moonrun with the specified input
#moonrun target/wasm-gc/release/build/bin/bin.wasm -- test/test_src/${INPUT}.mbt -o test/test_src/${INPUT}.s

cat test/test_src/${INPUT}.s
# Build the executable using zig
zig build-exe -target riscv64-linux -femit-bin=./${INPUT}.out ./test/test_src/${INPUT}.s riscv_rt/zig-out/lib/libmincaml.a -O Debug -fno-strip -mcpu=baseline_rv64


# Run the executable using qemu-riscv64
qemu-riscv64 ./${INPUT}.out
