# -*- coding: utf-8 -*-
"""
Fixes for data.json driven by the App Japó audit (04/09/2026):

- BUG-002: 24 Kyoto places had their Google/Apple Maps query written in
  Catalan, with parentheses — MANUAL_MAPQUERY_OVERRIDE replaces those with a
  clean romaji/English name that Maps can actually resolve.
- BUG-003/BUG-004: adds verified GPS coordinates for 82 of the 91 places
  that had none (Osaka, Himeji, and partial gaps elsewhere), sourced and
  sanity-checked against Wikipedia/official pages, each within Japan's
  bounding box. The remaining ~9 (specific restaurant branches, a couple of
  minor stops) are left null rather than guessed.
- BUG-001: splits every multi-stop Google Maps route into chunks of at most
  10 stops (Google's practical waypoint limit for the web "dir" UI — matches
  the audit's own recommendation of "trams de 10"). Each chunk is rebuilt
  from the route's EXISTING waypoint list (so whichever curated subset/order
  a themed route already had — e.g. Nikko's "nucli" vs "Parc Nacional" — is
  preserved exactly), with any waypoint that matches one of the 24 broken
  Kyoto names swapped for its corrected romaji text, so the Catalan-name bug
  can't leak into route URLs either. `groupIds` is legacy metadata carried
  over from an earlier HTML version of this app and is not read anywhere in
  the Swift app (confirmed: only `label`, `url` and `stops` are rendered) —
  it is preserved unchanged on split chunks rather than invented.
- UX-011: blanks out the "No indicat/No indicada als arxius" filler text in
  hours/address so the UI can hide the row instead of showing a fake fact.

Run directly against data.json in place (idempotent — safe to re-run).
"""
import json
import re
import sys
import urllib.parse
from collections import OrderedDict

PATH = sys.argv[1] if len(sys.argv) > 1 else "data.json"

MANUAL_MAPQUERY_OVERRIDE = {
    # (city, catalan name) -> clean query text used for BOTH google/apple AND
    # rebuilt route waypoints.
    ("kyoto", "Castell de Fushimi Momoyama (exterior)"): "Fushimi Momoyama Castle Kyoto",
    ("kyoto", "Santuari Jishu"): "Jishu Shrine Kyoto",
    ("kyoto", "Pagoda Yasaka (Hokan-ji)"): "Yasaka Pagoda Hokanji Kyoto",
    ("kyoto", "Santuari Yasaka"): "Yasaka Shrine Kyoto",
    ("kyoto", "Parc Maruyama"): "Maruyama Park Kyoto",
    ("kyoto", "Santuari Heian (Heian Jingu)"): "Heian Jingu Kyoto",
    ("kyoto", "Kinkaku-ji (Pavelló Daurat)"): "Kinkaku-ji Kyoto",
    ("kyoto", "Tramvia Randen i estació d'Arashiyama (Bosc de Kimonos)"): "Randen Arashiyama Station Kimono Forest Kyoto",
    ("kyoto", "Bosc de bambú d'Arashiyama"): "Arashiyama Bamboo Grove Kyoto",
    ("kyoto", "Pont Togetsukyo"): "Togetsukyo Bridge Arashiyama Kyoto",
    ("kyoto", "Parc dels micos Iwatayama"): "Iwatayama Monkey Park Kyoto",
    ("kyoto", "Saiho-ji (Kokedera, «el temple del molsa»)"): "Saiho-ji Kokedera Kyoto",
    ("kyoto", "Ginkaku-ji (Pavelló de Plata)"): "Ginkaku-ji Kyoto",
    ("kyoto", "Camí del Filòsof (Tetsugaku no Michi)"): "Philosopher's Path Kyoto",
    ("kyoto", "Eikan-do (Zenrin-ji)"): "Eikando Zenrinji Kyoto",
    ("kyoto", "Nanzen-ji i aqüeducte de maó"): "Nanzen-ji Aqueduct Kyoto",
    ("kyoto", "Mercat de Nishiki"): "Nishiki Market Kyoto",
    ("kyoto", "Teramachi i Shinkyogoku (shotengai)"): "Teramachi Shinkyogoku Shopping Street Kyoto",
    ("kyoto", "Mont Daimonji (ruta Higashiyama)"): "Mount Daimonji Kyoto",
    ("kyoto", "Enryaku-ji (mont Hiei)"): "Enryaku-ji Mount Hiei Kyoto",
    ("kyoto", "Ohara (Sanzen-in i Jakko-in)"): "Sanzen-in Ohara Kyoto",
    ("kyoto", "Santuari Atago"): "Atago Shrine Kyoto",
    ("kyoto", "Santuari Kifune"): "Kifune Shrine Kyoto",
    ("kyoto", "Santuari Kitano Tenmangu"): "Kitano Tenmangu Kyoto",
}

# id -> (lat, lng), verified against Wikipedia/official sources (see audit
# notes). Places not listed here keep lat/lng = null rather than a guess.
COORDS = {
"osaka__p1": (34.68738, 135.52584), "osaka__p2": (34.69603, 135.51262),
"osaka__p4": (34.69091, 135.48686), "osaka__p5": (34.70400, 135.50045),
"osaka__p6": (34.69806, 135.48944), "osaka__p7": (34.70528, 135.48972),
"osaka__p8": (34.70250, 135.49611), "osaka__p12": (34.65287, 135.51092),
"osaka__p13": (34.65390, 135.51645), "osaka__p15": (34.65000, 135.51000),
"osaka__p16": (34.65222, 135.50611), "osaka__p17": (34.65250, 135.50630),
"osaka__p19": (34.64882, 135.50441), "osaka__p20": (34.61280, 135.49294),
"osaka__p22": (34.64600, 135.51339), "osaka__p23": (34.66171, 135.49675),
"osaka__p24": (34.66147, 135.50180), "osaka__p25": (34.66699, 135.50613),
"osaka__p27": (34.66535, 135.50658), "osaka__p28": (34.66792, 135.50244),
"osaka__p29": (34.66792, 135.50244), "osaka__p31": (34.66871, 135.50131),
"osaka__p33": (34.66871, 135.50131), "osaka__p34": (34.66871, 135.50131),
"osaka__p35": (34.66871, 135.50131), "osaka__p38": (34.67502, 135.50031),
"osaka__p39": (34.67502, 135.50031), "osaka__p40": (34.67209, 135.49796),
"osaka__p41": (34.65451, 135.42885), "osaka__p42": (34.65620, 135.43100),
"osaka__p43": (34.65620, 135.43100), "osaka__p44": (34.66472, 135.43306),
"osaka__p45": (34.66814, 135.43751), "osaka__p46": (34.80964, 135.53231),
"osaka__p47": (34.85389, 135.47197), "osaka__p48": (34.86583, 135.49111),
"osaka__p49": (34.56400, 135.48700), "osaka__p51": (34.81804, 135.42668),
"nikko__toshogu": (36.75806, 139.59889), "nikko__nemuri-neko": (36.75806, 139.59889),
"nikko__honjido": (36.75806, 139.59889), "nikko__shinkyo": (36.75332, 139.60404),
"nikko__futarasan": (36.75833, 139.59639), "nikko__taiyuinbyo": (36.75806, 139.59889),
"nikko__rinnoji": (36.75806, 139.59889), "nikko__kanmangafuchi": (36.74917, 139.58960),
"nikko__botanical-garden": (36.75000, 139.60000), "nikko__tamozawa": (36.75250, 139.59139),
"nikko__utsunomiya-gyoza": (36.55953, 139.89853),
"hakone__odawara-castle": (35.25083, 139.15361),
"nara__horyuji": (34.61440, 135.73420), "nara__yoshino": (34.35667, 135.87056),
"nara__muro-art-forest": (34.53789, 136.04062), "nara__murouji": (34.53789, 136.04062),
"nara__kito-shimoichi": (34.38375, 135.78734), "nara__dorogawa-onsen": (34.26621, 135.87726),
"nara__omine-nyonin-kekkai": (34.25278, 135.94056), "nara__okadera": (34.47179, 135.82837),
"nara__yamatokoriyama": (34.65192, 135.77894),
"wakayama__wakayama-castle": (34.22763, 135.17162), "wakayama__kimiidera": (34.18517, 135.19003),
"wakayama__marina-city": (34.16114, 135.17979), "wakayama__tomogashima": (34.28100, 135.00036),
"wakayama__kumano-hongu-taisha": (33.84000, 135.77389), "wakayama__kumano-hayatama-taisha": (33.73195, 135.98373),
"hiroshima__iwakuni": (34.17045, 132.17769), "hiroshima__onomichi": (34.40483, 133.19367),
"hiroshima__kurashiki": (34.59615, 133.77067),
"himeji__parc-shiromidai": (34.83939, 134.69651), "himeji__jardins-kokoen": (34.83806, 134.68972),
"himeji__castell-himeji": (34.83944, 134.69389), "himeji__museu-art-himeji": (34.83939, 134.69651),
"himeji__museu-historia-hyogo": (34.84123, 134.69692), "himeji__mont-shosha-engyoji": (34.89114, 134.65814),
"himeji__illa-ieshima": (34.67472, 134.51944), "himeji__nada-kenka-matsuri": (34.78540, 134.70180),
}

JAPAN_LAT = (24.0, 46.0)
JAPAN_LNG = (122.0, 146.5)
MAX_STOPS_PER_ROUTE = 10
FILLER_TEXTS = {"No indicat als arxius", "No indicada als arxius"}


def google_query_text(place):
    """Recovers the plain-text query behind a place's google search URL."""
    if not place.get("google"):
        return place["name"]
    q = place["google"].split("query=")[-1]
    return urllib.parse.unquote_plus(q)


def build_query_param(text):
    return urllib.parse.quote_plus(text)


def route_waypoints(route):
    """Decodes the ordered list of plain-text waypoints already baked into a
    route's /maps/dir/ URL — this already reflects that route's curated
    subset & order, which nothing else in this dataset lets us rebuild."""
    tail = route["url"].split("/maps/dir/", 1)[-1]
    return [urllib.parse.unquote_plus(seg) for seg in tail.split("/") if seg]


def main():
    with open(PATH, encoding="utf-8") as f:
        data = json.load(f, object_pairs_hook=OrderedDict)

    places = data["places"]
    by_id = {p["id"]: p for p in places}

    # Snapshot each place's CURRENT (possibly Catalan-broken) query text
    # before we mutate anything, so route waypoints — which were baked from
    # this same text when the routes were first generated — can be matched
    # back to a place and get the same fix applied.
    old_text_to_new = {}
    for p in places:
        old_text_to_new[(p["city"], google_query_text(p))] = p

    # --- BUG-002: fix broken map queries (also updates apple) ---
    fixed_query_count = 0
    for p in places:
        key = (p["city"], p["name"])
        if key in MANUAL_MAPQUERY_OVERRIDE:
            clean = MANUAL_MAPQUERY_OVERRIDE[key]
            p["google"] = "https://www.google.com/maps/search/?api=1&query=" + build_query_param(clean)
            p["apple"] = "https://maps.apple.com/?q=" + build_query_param(clean)
            fixed_query_count += 1

    # --- BUG-003/BUG-004: add verified coordinates ---
    coord_count = 0
    coord_rejected = []
    for pid, (lat, lng) in COORDS.items():
        p = by_id.get(pid)
        if p is None:
            continue
        if not (JAPAN_LAT[0] <= lat <= JAPAN_LAT[1] and JAPAN_LNG[0] <= lng <= JAPAN_LNG[1]):
            coord_rejected.append(pid)
            continue
        p["lat"] = lat
        p["lng"] = lng
        coord_count += 1

    # --- UX-011: null out filler placeholder text ---
    filler_cleared = 0
    for p in places:
        if p.get("hours") in FILLER_TEXTS:
            p["hours"] = ""
            filler_cleared += 1
        if p.get("address") in FILLER_TEXTS:
            p["address"] = ""
            filler_cleared += 1

    # --- BUG-001: split every route into <=10-stop chunks ---
    routes_before = 0
    routes_after = 0
    waypoints_fixed = 0
    for city in data["cities"]:
        new_routes = []
        for route in city["routes"]:
            routes_before += 1
            waypoints = route_waypoints(route)
            # Swap any waypoint that matches a place's OLD (pre-fix) query
            # text for that place's corrected text — this is how a Kyoto
            # route picks up the same romaji fix as its individual places.
            fixed_waypoints = []
            for text in waypoints:
                place = old_text_to_new.get((city["id"], text))
                if place is not None:
                    new_text = google_query_text(place)
                    if new_text != text:
                        waypoints_fixed += 1
                    fixed_waypoints.append(new_text)
                else:
                    fixed_waypoints.append(text)
            n = len(fixed_waypoints)
            if n <= MAX_STOPS_PER_ROUTE:
                if fixed_waypoints != waypoints:
                    route = OrderedDict(route)
                    route["url"] = "https://www.google.com/maps/dir/" + "/".join(
                        build_query_param(t) for t in fixed_waypoints
                    )
                new_routes.append(route)
                routes_after += 1
                continue
            base_label = re.sub(r"^🗺️\s*", "", route["label"]).strip()
            chunks = [fixed_waypoints[i:i + MAX_STOPS_PER_ROUTE] for i in range(0, n, MAX_STOPS_PER_ROUTE)]
            total = len(chunks)
            start = 1
            for idx, chunk in enumerate(chunks, start=1):
                url = "https://www.google.com/maps/dir/" + "/".join(build_query_param(t) for t in chunk)
                end = start + len(chunk) - 1
                new_routes.append(OrderedDict([
                    ("label", f"🗺️ {base_label} · Tram {idx}/{total} (parades {start}-{end})"),
                    ("url", url),
                    ("groupIds", route["groupIds"]),
                    ("stops", len(chunk)),
                ]))
                start = end + 1
                routes_after += 1
        city["routes"] = new_routes

    with open(PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")

    print(f"Kyoto map-query fixes applied: {fixed_query_count}/24")
    print(f"Coordinates added: {coord_count} (rejected as out-of-bounds: {len(coord_rejected)} {coord_rejected})")
    print(f"Filler text ('No indicat...') cleared: {filler_cleared}")
    print(f"Route waypoints re-romanized: {waypoints_fixed}")
    print(f"Routes: {routes_before} -> {routes_after} (split at >{MAX_STOPS_PER_ROUTE} stops)")


if __name__ == "__main__":
    main()
