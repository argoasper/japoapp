# -*- coding: utf-8 -*-
"""Validator for data.json — re-run after any edit. Exits non-zero on error."""
import json
import re
import sys
import urllib.parse

PATH = sys.argv[1] if len(sys.argv) > 1 else "data.json"
JAPAN_LAT = (24.0, 46.0)
JAPAN_LNG = (122.0, 146.5)
MAX_STOPS_PER_ROUTE = 10

errors = []
warnings = []

with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

places = data["places"]
cities = data["cities"]
city_ids = {c["id"] for c in cities}
cat_meta_ids = set(data["catMeta"].keys())

# ids unique
ids = [p["id"] for p in places]
dupes = {i for i in ids if ids.count(i) > 1}
if dupes:
    errors.append(f"duplicate place ids: {dupes}")

# required non-null fields
required = ["id", "seq", "city", "cityName", "name", "desc", "cats", "google", "apple"]
for p in places:
    for field in required:
        if p.get(field) in (None, ""):
            errors.append(f"{p.get('id')}: missing required field '{field}'")
    if p["city"] not in city_ids:
        errors.append(f"{p['id']}: unknown city '{p['city']}'")
    for c in p["cats"]:
        if c not in cat_meta_ids:
            errors.append(f"{p['id']}: unknown category '{c}'")
    if p.get("priority") not in (None, "alta", "mitjana", "baixa"):
        errors.append(f"{p['id']}: invalid priority '{p.get('priority')}'")
    expected_label = {"alta": "Imprescindible", "mitjana": "Recomanat", "baixa": "Si hi ha temps", None: None}.get(p.get("priority"))
    if p.get("priorityLabel") != expected_label:
        errors.append(f"{p['id']}: priorityLabel '{p.get('priorityLabel')}' doesn't match priority '{p.get('priority')}'")
    lat, lng = p.get("lat"), p.get("lng")
    if (lat is None) != (lng is None):
        errors.append(f"{p['id']}: lat/lng partially set")
    if lat is not None:
        if not (JAPAN_LAT[0] <= lat <= JAPAN_LAT[1]):
            errors.append(f"{p['id']}: lat {lat} out of Japan bounding box")
        if not (JAPAN_LNG[0] <= lng <= JAPAN_LNG[1]):
            errors.append(f"{p['id']}: lng {lng} out of Japan bounding box")
    for field in ("google", "apple", "wiki"):
        v = p.get(field)
        if v:
            parsed = urllib.parse.urlparse(v)
            if not (parsed.scheme in ("http", "https") and parsed.netloc):
                errors.append(f"{p['id']}: malformed URL in '{field}': {v}")
    # No more Catalan/parenthetical text leaking into the map query.
    q = urllib.parse.unquote_plus(p["google"].split("query=")[-1]) if "query=" in p.get("google", "") else ""
    if q and re.search(r"[àèéíòóúïüç]", q, re.I):
        warnings.append(f"{p['id']}: google query still has accented Catalan chars: {q!r}")

# seq contiguous 0..N-1
seqs = sorted(p["seq"] for p in places)
if seqs != list(range(len(places))):
    errors.append(f"seq is not contiguous 0..{len(places)-1} (got {len(seqs)} values, range {seqs[0]}-{seqs[-1]})")

# routes
# Note: `groupIds` is legacy metadata carried over from an earlier HTML
# version of this app. It is decoded by the Swift model but never read by
# any view (confirmed against CityDetailView.swift, which only renders
# `label`, `url` and `stops`), so it is NOT validated against `stops` here —
# that would be inventing an invariant the app doesn't rely on.
for c in cities:
    for r in c["routes"]:
        if "/maps/dir/" not in r["url"]:
            errors.append(f"{c['id']}: route '{r['label']}' url doesn't look like a directions URL")
            continue
        waypoints = [seg for seg in r["url"].split("/maps/dir/", 1)[-1].split("/") if seg]
        if r["stops"] > MAX_STOPS_PER_ROUTE:
            errors.append(f"{c['id']}: route '{r['label']}' has {r['stops']} stops (> {MAX_STOPS_PER_ROUTE})")
        if r["stops"] != len(waypoints):
            errors.append(f"{c['id']}: route '{r['label']}' stops={r['stops']} but url has {len(waypoints)} waypoints")

print(f"{len(places)} places, {len(cities)} cities, {sum(len(c['routes']) for c in cities)} routes")
print(f"Coordinates: {sum(1 for p in places if p.get('lat') is not None)}/{len(places)}")
print(f"Warnings: {len(warnings)}")
for w in warnings:
    print("  WARN:", w)

if errors:
    print(f"\n{len(errors)} ERRORS:")
    for e in errors:
        print("  ERROR:", e)
    sys.exit(1)
else:
    print("\nOK — 0 errors")
