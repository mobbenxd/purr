#!/bin/zsh
# Lists localizable strings in the Swift sources that have no English
# translation in Resources/en.lproj/Localizable.strings, and translations
# that are no longer used. Thai is the development language, so Thai text is
# the key and needs no translation file of its own.
set -e
cd "${0:A:h}/.."

OUT=.build/strings
rm -rf $OUT && mkdir -p $OUT
# A separate, fresh build: incremental builds would skip unchanged files.
swift build --build-path $OUT/build -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc $PWD/$OUT >/dev/null

python3 - "$OUT" Resources/en.lproj/Localizable.strings <<'PY'
import glob, json, subprocess, sys
out, strings = sys.argv[1], sys.argv[2]
used = set()
for f in glob.glob(f"{out}/*.stringsdata"):
    for entry in json.load(open(f))["tables"].get("Localizable", []):
        used.add(entry["key"])
have = json.loads(subprocess.check_output(["plutil", "-convert", "json", "-o", "-", strings]))
missing = sorted(used - have.keys())
unused = sorted(have.keys() - used)
for k in missing: print("missing:", json.dumps(k, ensure_ascii=False))
for k in unused: print("unused: ", json.dumps(k, ensure_ascii=False))
print(f"{len(used)} strings, {len(missing)} missing, {len(unused)} unused")
sys.exit(1 if missing else 0)
PY
