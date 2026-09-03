#!/usr/bin/env python3
"""Merge the strings the compiler extracted into Resources/Localizable.xcstrings.

Xcode syncs the catalog itself when it builds; `xcodebuild` only writes the per-file
`.stringsdata` (SWIFT_EMIT_LOC_STRINGS) and leaves the catalog alone. This does the
sync: every key the app target emits goes into the catalog, keys no longer emitted are
marked stale, and anything already in the catalog — plural variations, translations,
comments — is kept.

    Scripts/l10n/sync-catalog.py [DerivedData/HandwrittenJournal-xxxx]

Without an argument the newest DerivedData for the project is used.
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "HandwrittenJournal/Resources/Localizable.xcstrings")

def derived_data(arg):
    if arg:
        return arg
    candidates = glob.glob(os.path.expanduser("~/Library/Developer/Xcode/DerivedData/HandwrittenJournal-*"))
    if not candidates:
        sys.exit("no DerivedData for HandwrittenJournal — build first")
    return max(candidates, key=os.path.getmtime)

def extracted(dd):
    keys = {}
    pattern = os.path.join(dd, "Build/Intermediates.noindex/HandwrittenJournal.build/*/HandwrittenJournal.build/Objects-normal/*/*.stringsdata")
    files = glob.glob(pattern)
    if not files:
        sys.exit(f"no .stringsdata under {dd} — build the app target with SWIFT_EMIT_LOC_STRINGS=YES")
    for path in files:
        data = json.load(open(path))
        for entry in data.get("tables", {}).get("Localizable", []):
            key = entry["key"]
            comment = entry.get("comment")
            keys.setdefault(key, comment)
    return keys

def main():
    dd = derived_data(sys.argv[1] if len(sys.argv) > 1 else None)
    keys = extracted(dd)
    catalog = json.load(open(CATALOG))
    strings = catalog.setdefault("strings", {})
    added = 0
    for key, comment in keys.items():
        entry = strings.setdefault(key, {})
        if entry is not strings.get(key) or "extractionState" in entry and entry["extractionState"] == "stale":
            entry.pop("extractionState", None)
        if key not in strings or strings[key] is entry and added is not None and not entry:
            pass
        if comment and "comment" not in entry:
            entry["comment"] = comment
    for key in list(strings):
        if key not in keys:
            if strings[key].get("extractionState") == "manual":
                continue
            strings[key]["extractionState"] = "stale"
    before = set(json.load(open(CATALOG)).get("strings", {}))
    added = len(set(keys) - before)
    stale = sum(1 for k, v in strings.items() if v.get("extractionState") == "stale")
    catalog["sourceLanguage"] = catalog.get("sourceLanguage", "en")
    catalog["version"] = catalog.get("version", "1.0")
    catalog["strings"] = dict(sorted(strings.items()))
    with open(CATALOG, "w") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False, sort_keys=False)
        f.write("\n")
    print(f"{len(keys)} keys extracted from {os.path.basename(dd)}; {added} added, {stale} stale; {len(strings)} in the catalog")

if __name__ == "__main__":
    main()
