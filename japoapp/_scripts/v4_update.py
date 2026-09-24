# -*- coding: utf-8 -*-
"""v4 — actualització de data.json:

  1. `day` → `zone`: s'eliminen totes les referències a "Dia 1 / Dia 2 / ..."
     (només queda el nom de la zona o del recorregut).
  2. Es netegen les notes que mencionaven dies concrets de l'itinerari.
  3. Descripcions més extenses (v4_descs_a.py / v4_descs_b.py).
  4. S'afegeix l'illa de Miyajima a Hiroshima (8 llocs nous + ruta).
  5. Es renumera `seq` perquè torni a ser contigu.

Ús:  python3 v4_update.py <data.json>     (edita el fitxer in situ, fa .bak)
"""
import json
import re
import shutil
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from v4_descs_a import EXTEND_A            # noqa: E402
from v4_descs_b import REWRITE_B, EXTEND_B  # noqa: E402

PATH = sys.argv[1] if len(sys.argv) > 1 else "data.json"

with open(PATH, encoding="utf-8") as f:
    data = json.load(f)

places = data["places"]

# ---------------------------------------------------------------- 1. day → zone
DAY_PREFIX = re.compile(r"^\s*Dia\s+\d+(\s+opcional)?\s*·\s*", re.I)
DAY_SUFFIX = re.compile(r"\s*·\s*Dies?\s+addicionals?\s*$", re.I)
for p in places:
    zone = p.pop("day", "")
    zone = DAY_PREFIX.sub("", zone)
    zone = DAY_SUFFIX.sub("", zone)
    p["zone"] = zone.strip()

# ---------------------------------------------------------------- 2. notes amb dies
NOTE_FIXES = {
    "kyoto__heian-jingu": (" Punt final habitual del primer dia d'itinerari.", ""),
    "kyoto__nanzenji": ("Canal Okazaki (dia 1)", "Canal Okazaki"),
    "kyoto__teramachi-shinkyogoku": ("Ideal per completar la tarda del tercer dia amb", "Ideal per completar una tarda amb"),
}
for pid, (old, new) in NOTE_FIXES.items():
    for p in places:
        if p["id"] == pid:
            assert old in p["notes"], (pid, p["notes"])
            p["notes"] = p["notes"].replace(old, new).strip()

# ---------------------------------------------------------------- 3. descripcions
by_id = {p["id"]: p for p in places}
for pid, extra in {**EXTEND_A, **EXTEND_B}.items():
    assert pid in by_id, pid
    d = by_id[pid]["desc"].rstrip()
    by_id[pid]["desc"] = d + extra
for pid, new in REWRITE_B.items():
    assert pid in by_id, pid
    by_id[pid]["desc"] = new

# ---------------------------------------------------------------- 4. Miyajima
HIRO = next(c for c in data["cities"] if c["id"] == "hiroshima")


def mk(pid, name, cats, priority, desc, address, hours, duration, notes, tags, q, wiki, lat, lng, order):
    label = {"alta": "Imprescindible", "mitjana": "Recomanat", "baixa": "Si hi ha temps"}[priority]
    return {
        "id": pid, "seq": 0, "city": "hiroshima", "cityName": "Hiroshima", "cityIcon": "🕊️",
        "cityColor": "#5b6b78", "zone": "Miyajima · L'illa del santuari flotant", "order": order,
        "name": name, "cats": cats, "rawCat": cats[0], "priority": priority, "priorityLabel": label,
        "desc": desc, "address": address, "hours": hours, "duration": duration, "notes": notes,
        "tags": tags,
        "google": "https://www.google.com/maps/search/?api=1&query=" + q.replace(" ", "+"),
        "apple": "https://maps.apple.com/?q=" + q.replace(" ", "+"),
        "wiki": wiki, "lat": lat, "lng": lng,
    }


MIYAJIMA = [
    mk("hiroshima__miyajima-ferry", "Ferri a Miyajima (Miyajimaguchi)", ["transport"], "alta",
       "La porta d'entrada a l'illa sagrada d'Itsukushima, coneguda popularment com Miyajima. Des de l'estació de Hiroshima, el tren JR de la línia Sanyo arriba a Miyajimaguchi en uns 25-30 minuts i, a 3 minuts a peu, hi ha el moll d'on surten dos ferris (JR i Matsudai) cada 10-15 minuts que travessen l'estret en només 10 minuts; el de JR està inclòs al JR Pass i fa una passada més a prop del gran torii a l'anada. També hi ha un vaixell directe des del Parc de la Pau (World Heritage Sea Route, 45 minuts) que baixa pel riu Motoyasu i creua la badia: més car, però molt bonic i sense transbordaments. A l'illa cal pagar una petita taxa turística (100 iens) en comprar el bitllet.",
       "Miyajimaguchi, Hatsukaichi, Hiroshima", "Ferris aprox. 6:25 - 22:40 (cada 10-15 min)", "40-45 min des de Hiroshima",
       "Consulta les hores de marea abans d'anar-hi: amb marea alta el torii «flota»; amb marea baixa s'hi pot caminar fins als peus. L'ideal és veure les dues coses en un mateix dia.",
       ["miyajima", "ferri", "transport", "jr pass"], "Miyajimaguchi Ferry Terminal", "https://en.wikipedia.org/wiki/Miyajima_Ferry", 34.3111, 132.3033, 1),
    mk("hiroshima__itsukushima-shrine", "Santuari d'Itsukushima", ["temple"], "alta",
       "Un dels llocs més famosos del Japó i Patrimoni de la Humanitat des de 1996: un santuari xintoista construït sobre pilars damunt del mar, de manera que amb la marea alta els seus passadissos coberts, pintats de vermell bermelló, semblen surar sobre l'aigua. Es va fundar l'any 593 i va adquirir la forma actual el 1168 gràcies a Taira no Kiyomori, el poderós senyor del clan Taira. La visita segueix un recorregut de fusta d'uns 300 metres per la sala principal, l'escenari de teatre Noh (l'únic del Japó construït sobre el mar) i la plataforma des d'on es fa la foto clàssica del gran torii. Antigament l'illa era tan sagrada que ningú no hi podia néixer ni morir, i encara avui no hi ha cementiris. Els cérvols passegen lliurement per tota l'illa, com a Nara.",
       "1-1 Miyajimacho, Hatsukaichi, Hiroshima", "6:30 - 18:00 (varia segons temporada)", "45 min - 1 h",
       "Entrada 300 iens (500 amb el tresor). Al vespre el santuari i el torii s'il·luminen fins a les 23 h, un espectacle molt més tranquil que de dia; si dormiu a l'illa, imprescindible.",
       ["santuari", "patrimoni humanitat", "imprescindible", "miyajima"], "Itsukushima Shrine", "https://en.wikipedia.org/wiki/Itsukushima_Shrine", 34.2960, 132.3198, 2),
    mk("hiroshima__otorii", "Gran Torii flotant (O-torii)", ["monument"], "alta",
       "La gran porta vermella de 16 metres d'alçada plantada al mar davant del santuari, una de les «tres vistes més boniques del Japó» (Nihon Sankei) i probablement la imatge més reproduïda del país. La porta actual és la vuitena, aixecada el 1875 amb dos troncs de camforer de més de 500 anys, i no està enterrada al fons marí: s'aguanta només pel seu pes, amb pedres dins de la biga superior. Va estar coberta per bastides durant una restauració de tres anys que va acabar el 2022, i ara torna a lluir el color bermelló original. Amb marea baixa es pot caminar fins als seus peus, trobar-hi les monedes que els visitants encaixen a l'escorça i veure les petxines enganxades a les columnes; amb marea alta, l'escena des del santuari o des de la platja de l'entrada és la que apareix a totes les postals.",
       "Miyajimacho, Hatsukaichi, Hiroshima", "Sempre visible; il·luminat fins a les 23 h", "20-30 min",
       "La marea canvia unes sis hores entre alta i baixa: la taula de marees està penjada al moll i a l'oficina de turisme. La posta de sol darrere el torii, des del passeig de l'entrada, és el moment més fotogènic.",
       ["torii", "monument", "imprescindible", "miyajima"], "Itsukushima Great Torii", "https://en.wikipedia.org/wiki/Itsukushima_Shrine", 34.2966, 132.3186, 3),
    mk("hiroshima__senjokaku", "Senjokaku i pagoda de cinc pisos", ["temple"], "mitjana",
       "Al turó que domina el santuari d'Itsukushima hi ha dos edificis molt fotogènics: la pagoda Gojunoto, de cinc pisos i 27 metres, construïda el 1407 amb la combinació de vermell i fusta fosca típica de l'època, i just al costat el Senjokaku, el «pavelló dels mil tatamis». Aquest gran saló de fusta obert, sense parets ni sostre acabat, el va fer construir Toyotomi Hideyoshi el 1587 com a biblioteca de sutres per als caiguts a la guerra, però va morir abans d'acabar-lo i va quedar tal com el veiem, inacabat des de fa més de quatre-cents anys. Avui és el santuari Hokoku, dedicat a Hideyoshi; l'interior, ple de plaques votives i pintures antigues penjades del sostre, és fresc a l'estiu i té vistes sobre les teulades del poble i el mar. L'entrada costa 100 iens i s'entra descalç.",
       "1-1 Miyajimacho, Hatsukaichi, Hiroshima", "8:30 - 16:30", "20-30 min",
       "És a un minut de la sortida del santuari, pujant unes escales a l'esquerra; la pagoda no es pot visitar per dins, però es veu des de tot el poble.",
       ["pagoda", "hideyoshi", "miyajima"], "Senjokaku Pavilion Miyajima", "https://en.wikipedia.org/wiki/Toyokuni_Shrine_(Miyajima)", 34.2976, 132.3195, 4),
    mk("hiroshima__daishoin", "Daisho-in", ["temple"], "alta",
       "El gran temple budista de Miyajima, de l'escola Shingon, al peu del mont Misen i molt més antic que la fama del santuari: es diu que el va fundar el monjo Kukai (Kobo Daishi) l'any 806. És un dels temples més encantadors del Japó, amb un recinte que s'enfila per la muntanya ple de racons: les escales d'entrada amb cilindres de sutres que es fan girar per rebre la benedicció, els 500 rakan (deixebles de Buda) de pedra amb gorros de llana de colors i cares diferents, una cova amb 88 icones que resumeixen el pelegrinatge de Shikoku, estàtues de tanuki i de tengu, i un saló amb una imatge del Dalai Lama que hi va fer una cerimònia. La flama sagrada que crema al Reikado del mont Misen es va portar d'aquí. Tot i ser a cinc minuts del santuari, la majoria de visitants no hi arriben, de manera que sol ser tranquil, i l'entrada és gratuïta.",
       "210 Miyajimacho, Hatsukaichi, Hiroshima", "8:00 - 17:00", "45 min - 1 h",
       "Des d'aquí surt el camí de pujada a peu al mont Misen més bonic (ruta Daisho-in, 1,5-2 h de pujada per escales de pedra); a la tardor les arces del temple són de les més boniques de l'illa.",
       ["temple", "budista", "kobo daishi", "miyajima", "imprescindible"], "Daisho-in Temple Miyajima", "https://en.wikipedia.org/wiki/Daish%C5%8D-in", 34.2929, 132.3176, 5),
    mk("hiroshima__momijidani", "Parc Momijidani", ["natura"], "mitjana",
       "La «vall de les arces», un parc natural al peu del mont Misen, a deu minuts a peu del santuari seguint un rierol amb ponts de pedra i fusta, on es concentren unes 700 arces japoneses que a mitjan novembre es tornen de tots els tons de vermell i taronja, amb els cérvols passejant-hi entremig. El parc va ser dissenyat al període Edo per protegir la vall de les riuades i és un dels llocs d'observació del momiji més coneguts del Japó occidental: els famosos dolços de l'illa, els momiji manju (pastissets en forma de fulla d'arç farcits de pasta de mongeta, xocolata o crema), en prenen el nom. Al fons del parc hi ha l'estació inferior del telefèric al mont Misen, i a la vora hi ha el ryokan històric Iwaso, amb una casa de te oberta al públic.",
       "Momijidani Park, Miyajimacho, Hatsukaichi, Hiroshima", "Sempre obert", "30 min",
       "Fora de la tardor és un passeig ombrívol i fresc, ideal per pujar cap al telefèric sense presses; hi ha un autobús gratuït des de prop del santuari fins al telefèric per a qui no vulgui caminar.",
       ["natura", "momiji", "parc", "miyajima"], "Momijidani Park Miyajima", None, 34.2937, 132.3231, 6),
    mk("hiroshima__mont-misen", "Mont Misen (telefèric i cim)", ["mirador"], "alta",
       "El cim sagrat de Miyajima, a 535 metres, amb la vista més espectacular del mar interior de Seto: desenes d'illes verdes, Hiroshima al fons i, en dies clars, fins a l'illa de Shikoku. El Miyajima Ropeway puja des de Momijidani en dos trams (una telecabina petita i una gran cabina) fins a l'estació de Shishiiwa, a 433 metres; des d'allà queda una caminada de 30 minuts per un sender amb escales fins al cim, passant pel Reikado, on crema una flama que, segons la tradició, Kobo Daishi va encendre fa 1.200 anys i que va servir per encendre la Flama de la Pau de Hiroshima, i per un grup de roques gegants amb un temple. A dalt hi ha un observatori de fusta de disseny modern amb bancs a l'ombra. Els qui vulguin fer-ho tot a peu tenen tres rutes de pujada (Momijidani, Daisho-in i Omoto), d'entre una hora i mitja i dues.",
       "Mount Misen, Miyajimacho, Hatsukaichi, Hiroshima", "Telefèric aprox. 9:00 - 16:30 (última baixada 17:00)", "2 h - 2 h 30 min",
       "El telefèric no s'inclou al JR Pass (uns 2.000 iens anada i tornada) i té cues a la tarda i a la tardor: pugeu al matí. Porteu aigua i calçat còmode; al cim no hi ha res per comprar. Una bona combinació és pujar amb telefèric i baixar a peu per Daisho-in.",
       ["mirador", "muntanya", "telefèric", "senderisme", "imprescindible", "miyajima"], "Mount Misen Observatory Miyajima", "https://en.wikipedia.org/wiki/Mount_Misen", 34.2794, 132.3196, 7),
    mk("hiroshima__omotesando-miyajima", "Carrer Omotesando i ostres de Miyajima", ["compres", "restaurant"], "mitjana",
       "El carrer comercial cobert que va del moll dels ferris fins al santuari, de 350 metres, ple de botigues de souvenirs, cafeteries i restaurants, i el millor lloc per tastar les dues especialitats de l'illa: les ostres de Hiroshima, que es crien a les batees que es veuen a la badia i es serveixen a la brasa a les parades del carrer (dues per uns 500 iens) o fregides i en arròs (kaki-meshi), i els momiji manju, que es fabriquen a la vista en màquines antigues i es venen també arrebossats i fregits (age-momiji) en brotxeta. Hi ha també anago-meshi (arròs amb anguila de mar), el plat tradicional de Miyajimaguchi, i les culleres de fusta shakushi gegants, artesania típica de l'illa; la cullera més gran del món, de 7,7 metres, s'exposa a l'entrada del carrer. Les botigues tanquen d'hora, cap a les 17-18 h, quan l'illa es buida.",
       "Omotesando Shopping Street, Miyajimacho, Hatsukaichi, Hiroshima", "Aprox. 9:00 - 18:00", "30-45 min",
       "Els cérvols intenten menjar-se els mapes i les bosses de paper: vigileu. Si voleu sopar a l'illa, reserveu, perquè gairebé tot tanca cap a les 18 h; els ryokan sí que serveixen sopar als hostes.",
       ["compres", "ostres", "momiji manju", "menjar de carrer", "miyajima"], "Omotesando Shopping Street Miyajima", None, 34.2986, 132.3210, 8),
]

# Insereix Miyajima entre el nucli de Hiroshima (Hiroden) i les excursions
insert_after = places.index(by_id["hiroshima__hiroden-trams"]) + 1
for i, p in enumerate(MIYAJIMA):
    places.insert(insert_after + i, p)

HIRO["routes"].append({
    "label": "🗺️ Ruta per Miyajima (del ferri al mont Misen)",
    "url": "https://www.google.com/maps/dir/Miyajima+Pier/Omotesando+Shopping+Street+Miyajima/Itsukushima+Shrine/Senjokaku+Pavilion+Miyajima/Daisho-in+Temple+Miyajima/Momijidani+Park+Miyajima/Mount+Misen+Observatory+Miyajima",
    "groupIds": [],
    "stops": 7,
})

# ---------------------------------------------------------------- 5. seq contigu
for i, p in enumerate(places):
    p["seq"] = i

# ---------------------------------------------------------------- comprovació final
for p in places:
    for k in ("desc", "notes", "zone", "name"):
        assert not re.search(r"\bDia\s+\d", p[k]), (p["id"], k, p[k])
        assert not re.search(r"\bdia\s+\d\b", p[k]), (p["id"], k, p[k])

if os.path.exists(PATH):
    shutil.copy(PATH, PATH + ".v3.bak")
with open(PATH, "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False, indent=1)

lens = [len(p["desc"]) for p in places]
print(f"{len(places)} llocs · desc mín/mediana/màx = {min(lens)}/{sorted(lens)[len(lens)//2]}/{max(lens)} · <260 chars: {sum(1 for x in lens if x < 260)}")
print("zones:", sorted(set(p["zone"] for p in places)))
