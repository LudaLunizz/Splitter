#!/bin/bash
# Type-checks every driver source file with clang against the real WDK and
# SDK headers, without Windows or Visual Studio (no code is generated or
# linked, so it doesn't replace build.ps1). Catches typos, type errors and
# failed C_ASSERTs on any computer.
#
# Needs zig (which contains clang; https://ziglang.org/download/) and the
# two NuGet packages that driver/packages.config names, unzipped:
#
#   ZIG=~/zig/zig WDK=~/wdk SDK=~/sdk windows/tests/clang_check.sh
#
#   WDK: microsoft.windows.wdk.x64.10.0.28000.2526.nupkg, unzipped
#   SDK: microsoft.windows.sdk.cpp.10.0.28000.2526.nupkg, unzipped
#
# Options: NTDDI=0x0A000008 (Windows 10 2004, the INF's minimum; the
# default) or another target, DBG=1 for the Debug build's defines.
#
# Copyright (c) the BananaSplit authors. MIT licence (see LICENSE).
set -u
here=$(cd "$(dirname "$0")" && pwd)
src=$here/../driver/Source
: "${ZIG:?set ZIG to the zig binary}" "${WDK:?set WDK to the unzipped WDK package}" "${SDK:?set SDK to the unzipped SDK package}"
ver=10.0.28000.0
km=$WDK/c/Include/$ver/km
wshared=$WDK/c/Include/$ver/shared
sshared=$SDK/c/Include/$ver/shared
kmdf=$WDK/c/Include/wdf/kmdf/1.15
for d in "$km" "$wshared" "$sshared" "$kmdf"; do
    [ -d "$d" ] || { echo "missing $d" >&2; exit 2; }
done
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Windows ignores case in #include names and the headers rely on it, so
# clang gets a case-insensitive view of every include folder.
# wdfdevice.h forward-declares enum _WDF_REQUEST_TYPE with ": int", which
# only MSVC lets wdfrequest.h define without it: that one line is patched
# in a copy.
sed '/^typedef enum _WDF_REQUEST_TYPE {/s/{/: int {/' "$kmdf/wdfrequest.h" > "$work/wdfrequest.h"
grep -q '_WDF_REQUEST_TYPE : int {' "$work/wdfrequest.h" || { echo "wdfrequest.h: line to patch not found" >&2; exit 2; }
python3 -I - "$work/vfs.json" "$kmdf/wdfrequest.h" "$work/wdfrequest.h" "$km" "$wshared" "$sshared" "$kmdf" "$src" <<'EOF'
import json, os, sys
out, orig, repl, dirs = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4:]
def tree(path):
    entries = []
    for name in sorted(os.listdir(path)):
        full = os.path.join(path, name)
        if os.path.isdir(full):
            entries.append({'type': 'directory', 'name': name, 'contents': tree(full)})
        elif os.path.isfile(full):
            entries.append({'type': 'file', 'name': name, 'external-contents': repl if full == orig else full})
    return entries
roots = [{'type': 'directory', 'name': os.path.abspath(d), 'contents': tree(os.path.abspath(d))} for d in dirs]
json.dump({'version': 0, 'case-sensitive': 'false', 'roots': roots}, open(out, 'w'))
EOF

defs=(-D_WIN64 -D_AMD64_ -DAMD64 -D_KERNEL_MODE=1 -DDEPRECATE_DDK_FUNCTIONS=1 -DMSC_NOOPT
      -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00 -DWINNT=1 -DNTDDI_VERSION=${NTDDI:-0x0A000008}
      -DKMDF_VERSION_MAJOR=1 -DKMDF_VERSION_MINOR=15 -D_USE_DECLSPECS_FOR_SAL=1 -DSTD_CALL
      -D_WIN32 -DUNICODE -D_UNICODE -DPC_IMPLEMENTATION -DDEBUG_LEVEL=DEBUGLVL_TERSE)
[ "${DBG:-0}" = 1 ] && defs+=(-DDBG=1)
# The warnings switched off are the Microsoft sample's own style (MSVC
# accepts it at /W4).
flags=(--target=x86_64-pc-windows-msvc -fms-extensions -fms-compatibility
       -fms-compatibility-version=19.44 -std=c++14 -fno-exceptions -fno-rtti
       -fsyntax-only -nostdinc -ivfsoverlay "$work/vfs.json" -Wall -Wextra
       -Wno-unknown-pragmas -Wno-microsoft-goto -Wno-unused-parameter
       -Wno-missing-braces -Wno-writable-strings -Wno-invalid-token-paste)
incs=(-I"$src/Inc" -I"$src/Filters" -I"$src/Utilities" -I"$src/Main" -I"$src"
      -isystem "$(dirname "$ZIG")/lib/include" -isystem "$km" -isystem "$km/crt"
      -isystem "$sshared" -isystem "$wshared" -isystem "$kmdf")
rc=0
for f in "$src"/Main/*.cpp "$src"/Filters/*.cpp "$src"/Utilities/*.cpp; do
    if out=$("$ZIG" clang "${flags[@]}" "${defs[@]}" "${incs[@]}" "$f" 2>&1); then
        echo "ok    ${f#"$src"/}"
    else
        echo "FAIL  ${f#"$src"/}"
        rc=1
    fi
    [ -n "$out" ] && echo "$out"
done
exit $rc
