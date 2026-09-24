import Foundation

/// Un trajecte de transport (aeroport o entre ciutats), amb les estacions
/// de sortida i d'arribada i les opcions de tren/autobús per fer-lo.
struct TransportRoute: Identifiable, Hashable {
    struct Option: Identifiable, Hashable {
        let id = UUID()
        let name: String          // p. ex. "Narita Express (N'EX)"
        let from: String          // estació de sortida (nom per als mapes)
        let to: String            // estació d'arribada
        let duration: String      // durada aproximada
        let detail: String        // andana, freqüència, bitllet, JR Pass…
        let jrPass: Bool          // inclòs al JR Pass
    }

    let id: String
    let title: String             // "Osaka → Hiroshima"
    let icon: String              // SF Symbol
    let kind: Kind
    let summary: String           // consell general del trajecte
    let options: [Option]

    enum Kind: String { case airport = "Aeroports", intercity = "Trajectes", local = "Dins la zona" }
}

/// Dades fixes de transport per ciutat. Les durades són aproximades
/// (consulta sempre l'horari a Google Maps / Navitime abans d'agafar-lo).
enum TransportData {
    static func routes(for cityId: String) -> [TransportRoute] {
        byCity[cityId] ?? []
    }

    static let byCity: [String: [TransportRoute]] = [
        "tokyo": tokyo,
        "osaka": osaka,
        "kyoto": kyoto,
        "hiroshima": hiroshima,
        "himeji": himeji,
        "nara": nara,
        "wakayama": wakayama,
        "hakone": hakone,
        "kamakura": kamakura,
        "nikko": nikko,
    ]

    // MARK: - Tòquio

    static let tokyo: [TransportRoute] = [
        TransportRoute(
            id: "tokyo-narita", title: "Tòquio ⇄ Aeroport de Narita (NRT)", icon: "airplane.departure", kind: .airport,
            summary: "Narita és a 60 km de la ciutat. Les dues opcions ràpides són el Narita Express de JR (des de l'estació de Tòquio, Shinagawa o Shinjuku) i el Skyliner de Keisei (des d'Ueno o Nippori). Tots dos tenen seients reservats: compra el bitllet a la màquina o al taulell abans de pujar. Calcula arribar a l'aeroport 3 h abans d'un vol internacional.",
            options: [
                .init(name: "Narita Express (N'EX)", from: "Tokyo Station", to: "Narita Airport Terminal 1", duration: "≈ 55-60 min",
                      detail: "Surt de les andanes subterrànies Sobu (B5) de l'estació de Tòquio, cada 30 min aprox. Para a Shinagawa i a Shinjuku (≈ 80 min). Seient reservat obligatori. Bitllet ≈ 3.070 ¥; l'N'EX Round Trip Ticket per a estrangers surt més a compte.", jrPass: true),
                .init(name: "Keisei Skyliner", from: "Keisei Ueno Station", to: "Narita Airport Terminal 1", duration: "≈ 41 min (36 des de Nippori)",
                      detail: "El tren més ràpid fins a Narita. Surt de Keisei-Ueno (a tocar del parc d'Ueno) i de Nippori (correspondència amb la línia JR Yamanote) cada 20-40 min. Bitllet ≈ 2.570 ¥; hi ha pack Skyliner + metro.", jrPass: false),
                .init(name: "Airport Limousine Bus", from: "Tokyo City Air Terminal", to: "Narita Airport Terminal 1", duration: "≈ 75-120 min segons trànsit",
                      detail: "Autobusos directes des dels grans hotels i estacions (Tokyo Station Yaesu, Shinjuku Busta, T-CAT). Còmode amb maletes, però depèn del trànsit. ≈ 3.600 ¥; l'Airport Bus TYO-NRT (≈ 1.500 ¥) surt de Tokyo Station Yaesu.", jrPass: false),
            ]),
        TransportRoute(
            id: "tokyo-haneda", title: "Tòquio ⇄ Aeroport de Haneda (HND)", icon: "airplane", kind: .airport,
            summary: "Si el vol surt de Haneda, és molt més a prop: el Monorail des de Hamamatsucho (línia Yamanote) o la línia Keikyu des de Shinagawa hi arriben en un quart d'hora.",
            options: [
                .init(name: "Tokyo Monorail", from: "Hamamatsucho Station", to: "Haneda Airport Terminal 3", duration: "≈ 15-20 min",
                      detail: "Cada 4-5 min des de Hamamatsucho (JR Yamanote / Keihin-Tohoku). Inclòs al JR Pass. ≈ 500 ¥.", jrPass: true),
                .init(name: "Keikyu Airport Line", from: "Shinagawa Station", to: "Haneda Airport Terminal 3", duration: "≈ 15 min",
                      detail: "Trens ràpids (Airport Express) des de Shinagawa; molts continuen pel metro Asakusa (Shimbashi, Nihombashi, Asakusa) sense transbord. ≈ 330 ¥.", jrPass: false),
            ]),
        TransportRoute(
            id: "tokyo-fuji", title: "Tòquio → Mont Fuji (Kawaguchiko)", icon: "mountain.2.fill", kind: .intercity,
            summary: "La base més còmoda per veure el Fuji és el llac Kawaguchiko (Fuji Five Lakes). Tot surt de Shinjuku: el tren directe Fuji Excursion o els autobusos d'autopista des de la terminal Busta Shinjuku (sortida sud de l'estació). Amb bon temps, al matí és quan el cim es veu més net.",
            options: [
                .init(name: "Limited Express Fuji Excursion", from: "Shinjuku Station", to: "Kawaguchiko Station", duration: "≈ 1 h 55 min",
                      detail: "Tren directe sense transbords (JR Chuo + Fujikyu). 2-3 sortides al matí des de Shinjuku (≈ 7:30, 8:30, 9:30). Seient reservat obligatori: reserva'l amb dies d'antelació, s'esgota. El tram Otsuki–Kawaguchiko (Fujikyu) no està inclòs al JR Pass (≈ 1.170 ¥ extra).", jrPass: true),
                .init(name: "Autobús d'autopista (Keio / Fujikyu)", from: "Busta Shinjuku", to: "Kawaguchiko Station", duration: "≈ 1 h 50 min - 2 h 15 min",
                      detail: "Sortides cada 30 min aprox. des de la terminal Busta Shinjuku (4a planta, sobre l'estació). ≈ 2.200 ¥. Reserva per internet (highway-buses.jp). També arriba a Fuji-Q Highland i al llac Yamanakako.", jrPass: false),
                .init(name: "Tren local via Otsuki", from: "Shinjuku Station", to: "Kawaguchiko Station", duration: "≈ 2 h 30 min",
                      detail: "JR Chuo Line (limited express Kaiji/Azusa fins a Otsuki, ≈ 1 h) + Fujikyu Railway fins a Kawaguchiko (≈ 55 min). Més transbords però amb més horaris. Al Fujikyu hi ha el tren temàtic Fujisan View Express.", jrPass: true),
            ]),
        TransportRoute(
            id: "tokyo-hakone", title: "Tòquio → Hakone", icon: "tram.fill", kind: .intercity,
            summary: "Hakone-Yumoto és el punt d'entrada. El Romancecar d'Odakyu des de Shinjuku hi va directe; amb JR Pass és millor el Shinkansen fins a Odawara i després el tren Hakone Tozan. Un cop allà, el Hakone Free Pass (2 dies) cobreix tren de muntanya, funicular, telefèric, vaixell pirata i autobusos.",
            options: [
                .init(name: "Odakyu Romancecar", from: "Shinjuku Station", to: "Hakone-Yumoto Station", duration: "≈ 1 h 25 min",
                      detail: "Tren panoràmic directe, cada 30-60 min des de l'estació Odakyu de Shinjuku (sortida oest). Seient reservat. ≈ 2.470 ¥ o suplement ≈ 1.200 ¥ amb el Hakone Free Pass (que inclou el trajecte Shinjuku–Odawara en tren normal).", jrPass: false),
                .init(name: "Shinkansen Tokaido fins a Odawara", from: "Tokyo Station", to: "Odawara Station", duration: "≈ 35 min + 15 min Tozan",
                      detail: "Kodama o Hikari (no tots els Hikari paren a Odawara) des de l'estació de Tòquio o Shinagawa. A Odawara, transbord al tren Hakone Tozan fins a Hakone-Yumoto (15 min). Amb JR Pass és l'opció més ràpida. Es pot visitar el castell d'Odawara pel camí.", jrPass: true),
                .init(name: "Tren local Odakyu", from: "Shinjuku Station", to: "Odawara Station", duration: "≈ 1 h 30 min + 15 min Tozan",
                      detail: "Rapid Express Odakyu sense seient reservat (inclòs al Hakone Free Pass). Transbord a Odawara al tren Hakone Tozan.", jrPass: false),
            ]),
        TransportRoute(
            id: "tokyo-kamakura", title: "Tòquio → Kamakura", icon: "tram.fill", kind: .intercity,
            summary: "Excursió d'un dia fàcil: menys d'una hora de tren. Baixa a Kita-Kamakura si vols començar pels temples zen (Engaku-ji, Kencho-ji) i acabar al centre, o a Kamakura per anar directe al Hachimangu i al Gran Buda (tren Enoden fins a Hase).",
            options: [
                .init(name: "JR Yokosuka Line", from: "Tokyo Station", to: "Kamakura Station", duration: "≈ 55 min (Kita-Kamakura 52)",
                      detail: "Directe des de les andanes subterrànies de l'estació de Tòquio (també para a Shimbashi i Shinagawa). Cada 10-15 min. ≈ 950 ¥.", jrPass: true),
                .init(name: "JR Shonan-Shinjuku Line", from: "Shinjuku Station", to: "Kamakura Station", duration: "≈ 1 h",
                      detail: "Directe des de Shinjuku, Shibuya i Ebisu (trens amb destinació Zushi). Cada 15-30 min. ≈ 950 ¥.", jrPass: true),
                .init(name: "Odakyu + Enoden (per la costa)", from: "Shinjuku Station", to: "Kamakura Station", duration: "≈ 1 h 30 min",
                      detail: "Odakyu fins a Fujisawa i tren Enoden per la costa (Enoshima, Kamakura-Koko-Mae, Hase). L'Enoshima-Kamakura Free Pass d'Odakyu (≈ 1.640 ¥) inclou tot el dia d'Enoden.", jrPass: false),
            ]),
        TransportRoute(
            id: "tokyo-nikko", title: "Tòquio → Nikko (Tōshōgū i pont Shinkyō)", icon: "tram.fill", kind: .intercity,
            summary: "Dues maneres: els trens Tobu des d'Asakusa (més barats, i l'estació Tobu-Nikko és a 20 min a peu del Shinkyo) o JR amb Shinkansen fins a Utsunomiya i tren local (millor amb JR Pass). Les dues estacions de Nikko són a 200 m l'una de l'altra; els autobusos als santuaris i a Chuzenji surten de davant.",
            options: [
                .init(name: "Tobu Limited Express (Spacia X / Revaty Kegon)", from: "Tobu Asakusa Station", to: "Tobu-Nikko Station", duration: "≈ 1 h 50 min",
                      detail: "Directe des d'Asakusa (edifici Matsuya, sobre el metro Ginza/Asakusa); alguns surten de Tokyo Skytree i Kita-Senju. Seient reservat; ≈ 3.050 ¥ (Spacia X una mica més). El Nikko Pass (All Area / World Heritage) inclou el trajecte en tren normal + busos de Nikko.", jrPass: false),
                .init(name: "Tobu tren ràpid (sense reserva)", from: "Tobu Asakusa Station", to: "Tobu-Nikko Station", duration: "≈ 2 h 10 min",
                      detail: "Trens Rapid/Section Rapid amb transbord a Minami-Kurihashi. Més barat (≈ 1.400 ¥) i inclòs al Nikko Pass sense suplement.", jrPass: false),
                .init(name: "JR Tohoku Shinkansen + JR Nikko Line", from: "Tokyo Station", to: "Nikko Station", duration: "≈ 1 h 40 min - 2 h",
                      detail: "Shinkansen Yamabiko/Nasuno fins a Utsunomiya (≈ 50 min) i transbord a la línia JR Nikko (≈ 45 min, cada 30-60 min). Tot inclòs al JR Pass. També hi ha el limited express JR-Tobu «Nikko» directe des de Shinjuku (≈ 2 h, no inclòs al JR Pass del tot).", jrPass: true),
            ]),
        TransportRoute(
            id: "tokyo-kyoto", title: "Tòquio ⇄ Kyoto / Osaka (Shinkansen)", icon: "train.side.front.car", kind: .intercity,
            summary: "El Tokaido Shinkansen surt cada 5-10 min de l'estació de Tòquio (andanes 14-19) i de Shinagawa. Nozomi (el més ràpid, no inclòs al JR Pass ordinari), Hikari (inclòs) i Kodama (para a totes). Seu a la dreta (seients D/E) anant cap a Kyoto per veure el Fuji.",
            options: [
                .init(name: "Nozomi", from: "Tokyo Station", to: "Kyoto Station", duration: "≈ 2 h 10 min (Shin-Osaka 2 h 25)",
                      detail: "Cada 10 min. ≈ 14.170 ¥ amb seient reservat. Els vagons 1-3 són sense reserva. No es pot fer servir amb el JR Pass sense el suplement Nozomi.", jrPass: false),
                .init(name: "Hikari", from: "Tokyo Station", to: "Kyoto Station", duration: "≈ 2 h 40 min (Shin-Osaka 2 h 55)",
                      detail: "Cada 30 min. Inclòs al JR Pass: reserva el seient a la màquina verda o al taulell.", jrPass: true),
            ]),
        TransportRoute(
            id: "tokyo-local", title: "Moure's per Tòquio", icon: "map", kind: .local,
            summary: "Amb una targeta Suica/Pasmo (també al Wallet de l'iPhone) es paga tot: JR Yamanote, metro Tokyo Metro/Toei, autobusos i fins i tot màquines de begudes. La Yamanote (verda) és el cercle que uneix Tòquio, Ueno, Ikebukuro, Shinjuku, Shibuya i Shinagawa; el metro cobreix la resta. Eviteu l'hora punta de 7:30 a 9:00.",
            options: [
                .init(name: "JR Yamanote Line (cercle)", from: "Tokyo Station", to: "Shinjuku Station", duration: "≈ 15-30 min segons tram",
                      detail: "Cada 2-4 min. Una volta sencera són 60 min. Inclosa al JR Pass; també les línies JR Chuo (ràpida Tòquio–Shinjuku, 14 min), Sobu i Keihin-Tohoku.", jrPass: true),
                .init(name: "Tokyo Metro + Toei (bitllet 24/48/72 h)", from: "Ginza Station", to: "Asakusa Station", duration: "—",
                      detail: "El Tokyo Subway Ticket per a turistes (24 h ≈ 800 ¥, 72 h ≈ 1.500 ¥) cobreix les 13 línies de metro (no JR). Es compra a l'aeroport o a les oficines Bic Camera.", jrPass: false),
            ]),
    ]

    // MARK: - Osaka

    static let osaka: [TransportRoute] = [
        TransportRoute(
            id: "osaka-kix", title: "Osaka ⇄ Aeroport de Kansai (KIX)", icon: "airplane.departure", kind: .airport,
            summary: "L'aeroport és en una illa artificial a 50 km al sud. Des de Shin-Osaka/Tennoji, el Haruka de JR; des de Namba, el Rapi:t de Nankai (més barat). Els dos tenen seient reservat i porta-maletes. Calcula 1 h fins a l'aeroport i arriba-hi 3 h abans del vol.",
            options: [
                .init(name: "JR Limited Express Haruka", from: "Shin-Osaka Station", to: "Kansai Airport Station", duration: "≈ 50 min (Tennoji 35, Osaka Station 45)",
                      detail: "Cada 30 min. Des de 2023 para també a l'estació d'Osaka (andanes subterrànies Umekita). Continua fins a Kyoto (≈ 80 min). Inclòs al JR Pass; el Haruka one-way discount ticket per a estrangers costa ≈ 1.800 ¥ des d'Osaka.", jrPass: true),
                .init(name: "Nankai Rapi:t", from: "Nankai Namba Station", to: "Kansai Airport Station", duration: "≈ 38-45 min",
                      detail: "Tren blau «Iron Man» des de Nankai Namba (sud de Namba, sobre el gran magatzem Takashimaya), cada 30 min. ≈ 1.490 ¥ (descompte per a turistes ≈ 1.300 ¥ comprat en línia/Klook). Els Airport Express de Nankai sense reserva triguen 45-50 min i costen 970 ¥.", jrPass: false),
                .init(name: "JR Kansai Airport Rapid", from: "Osaka Station", to: "Kansai Airport Station", duration: "≈ 65-70 min",
                      detail: "Tren normal sense reserva des d'Osaka Station (andanes 1-2, via Tennoji). Atenció: el tren es divideix a Hineno — puja als 4 vagons de davant (Kansai Airport). ≈ 1.210 ¥.", jrPass: true),
                .init(name: "Autobús Limousine", from: "Osaka Station JR Highway Bus Terminal", to: "Kansai Airport Terminal 1", duration: "≈ 50-60 min",
                      detail: "Des d'Umeda (Herbis Osaka / Shin-Hankyu Hotel), Namba OCAT i Universal City, cada 15-30 min. ≈ 1.800 ¥. Còmode amb maletes grans.", jrPass: false),
            ]),
        TransportRoute(
            id: "osaka-itami", title: "Osaka ⇄ Aeroport d'Itami (ITM, vols domèstics)", icon: "airplane", kind: .airport,
            summary: "Per als vols dins del Japó (Tòquio-Haneda, Sapporo, Okinawa). És a 20 km al nord.",
            options: [
                .init(name: "Monorail + Hankyu", from: "Hankyu Umeda Station", to: "Osaka Airport Station", duration: "≈ 30 min",
                      detail: "Hankyu Takarazuka Line fins a Hotarugaike i Osaka Monorail una parada. ≈ 430 ¥.", jrPass: false),
                .init(name: "Autobús Limousine", from: "Osaka Station", to: "Osaka Itami Airport", duration: "≈ 30 min",
                      detail: "Des d'Umeda (Shin-Hankyu Hotel) i Namba OCAT cada 15-20 min. ≈ 650 ¥.", jrPass: false),
            ]),
        TransportRoute(
            id: "osaka-hiroshima", title: "Osaka → Hiroshima", icon: "train.side.front.car", kind: .intercity,
            summary: "Shinkansen Sanyo des de Shin-Osaka (estació al nord, línia de metro Midosuji des d'Umeda/Namba, 6-15 min). Nozomi i Mizuho són els més ràpids; amb JR Pass ordinari cal agafar Sakura o Hikari. Seu a l'esquerra (seients A) anant cap a Hiroshima per veure el castell de Himeji des del tren.",
            options: [
                .init(name: "Shinkansen Nozomi / Mizuho", from: "Shin-Osaka Station", to: "Hiroshima Station", duration: "≈ 1 h 25 min",
                      detail: "Cada 10-15 min. ≈ 10.600 ¥ amb seient reservat. Sense reserva als vagons 1-3. No inclòs al JR Pass sense suplement.", jrPass: false),
                .init(name: "Shinkansen Sakura / Hikari", from: "Shin-Osaka Station", to: "Hiroshima Station", duration: "≈ 1 h 30 min - 1 h 40 min",
                      detail: "Sakura (cada 30 min aprox.) inclòs al JR Pass, para a Shin-Kobe, Himeji, Okayama i Fukuyama. Els Kodama triguen 2 h 20 min. Ideal per parar a Himeji o Kurashiki/Okayama pel camí.", jrPass: true),
            ]),
        TransportRoute(
            id: "osaka-kyoto", title: "Osaka → Kyoto", icon: "tram.fill", kind: .intercity,
            summary: "Mitja hora de tren. JR des de l'estació d'Osaka és el més ràpid a l'estació de Kyoto; Hankyu des d'Umeda arriba directament al centre (Kawaramachi/Gion) i Keihan a Gion-Shijo, Fushimi Inari i Tofuku-ji. El Shinkansen només val la pena si ja tens el JR Pass i ets a Shin-Osaka.",
            options: [
                .init(name: "JR Special Rapid (Shin-kaisoku)", from: "Osaka Station", to: "Kyoto Station", duration: "≈ 29 min",
                      detail: "Cada 15 min des de les andanes 8-10 d'Osaka Station. Sense reserva. ≈ 580 ¥. Inclòs al JR Pass. Els «Rapid» triguen 45 min.", jrPass: true),
                .init(name: "Hankyu Kyoto Line (Limited Express)", from: "Osaka-Umeda Station", to: "Kyoto-Kawaramachi Station", duration: "≈ 43-45 min",
                      detail: "Des d'Osaka-Umeda (gran estació de 9 andanes al nord d'Umeda), cada 10 min. ≈ 410 ¥. Para a Karasuma (centre) i arriba a Kawaramachi, al costat de Gion i Nishiki. També a Arashiyama amb transbord a Katsura.", jrPass: false),
                .init(name: "Keihan Main Line (Limited Express)", from: "Yodoyabashi Station", to: "Gion-Shijo Station", duration: "≈ 50 min",
                      detail: "Des de Yodoyabashi (metro Midosuji) o Kyobashi, cada 10 min. ≈ 430 ¥. Para a Fushimi-Inari, Tofukuji, Kiyomizu-Gojo, Gion-Shijo i Demachiyanagi (tren a Kurama). Els trens Premium Car tenen seient reservat.", jrPass: false),
                .init(name: "Shinkansen", from: "Shin-Osaka Station", to: "Kyoto Station", duration: "≈ 13-15 min",
                      detail: "Qualsevol Shinkansen. ≈ 1.450 ¥ sense reserva. Només té sentit amb JR Pass o si vas des de Shin-Osaka.", jrPass: true),
            ]),
        TransportRoute(
            id: "osaka-nara", title: "Osaka → Nara", icon: "tram.fill", kind: .intercity,
            summary: "Kintetsu des d'Osaka-Namba deixa a 5 min a peu del parc dels cérvols (l'estació JR de Nara és a 20 min a peu del parc). Amb JR Pass, el Yamatoji Rapid des d'Osaka Station/Tennoji també és bo.",
            options: [
                .init(name: "Kintetsu Nara Line (Rapid Express)", from: "Osaka-Namba Station", to: "Kintetsu-Nara Station", duration: "≈ 40 min",
                      detail: "Des d'Osaka-Namba (sota Namba, cap a l'est), cada 15-20 min. ≈ 680 ¥ sense reserva; els Limited Express amb seient reservat triguen 35 min (+ 520 ¥). Kintetsu-Nara és al costat del parc i de Kofuku-ji.", jrPass: false),
                .init(name: "JR Yamatoji Rapid", from: "Osaka Station", to: "Nara Station", duration: "≈ 50 min (Tennoji 35)",
                      detail: "Cada 15-20 min des d'Osaka Station (andana 1, via línia Loop) i Tennoji. ≈ 820 ¥. Inclòs al JR Pass. Des de JR Nara, autobús o 20 min a peu fins al parc; també para a Horyu-ji.", jrPass: true),
            ]),
        TransportRoute(
            id: "osaka-wakayama", title: "Osaka → Wakayama (castell i ciutat)", icon: "tram.fill", kind: .intercity,
            summary: "Una hora i quart fins a la ciutat de Wakayama. JR Kishuji Rapid des d'Osaka Station/Tennoji (JR Pass) o Nankai des de Namba. Des de Wakayama es continua cap a Kimiidera i Marina City.",
            options: [
                .init(name: "JR Kishuji Rapid (línia Hanwa)", from: "Osaka Station", to: "Wakayama Station", duration: "≈ 1 h 25 min (Tennoji 1 h 10)",
                      detail: "Cada 15-30 min via Tennoji. ≈ 1.270 ¥. Inclòs al JR Pass. Els limited express Kuroshio hi arriben en 60 min (seient reservat).", jrPass: true),
                .init(name: "Nankai Main Line (Express / Limited Express Southern)", from: "Nankai Namba Station", to: "Wakayamashi Station", duration: "≈ 1 h (Southern 58 min)",
                      detail: "Des de Nankai Namba. ≈ 930 ¥ (Southern amb seient reservat + 520 ¥). Wakayamashi és a 10 min a peu del castell.", jrPass: false),
            ]),
        TransportRoute(
            id: "osaka-kumano", title: "Osaka → Kumano (Nachi Taisha) i Kii-Katsuura", icon: "tram.fill", kind: .intercity,
            summary: "És lluny: gairebé 4 h de tren Kuroshio fins a Kii-Katsuura, la base per a Nachi (autobús de 30 min fins a Daimonzaka / Nachi-san). Val la pena dormir-hi una nit en un onsen. Reserva el Kuroshio amb antelació; seu a la dreta (mar) anant cap al sud.",
            options: [
                .init(name: "JR Limited Express Kuroshio", from: "Shin-Osaka Station", to: "Kii-Katsuura Station", duration: "≈ 3 h 50 min (Tennoji 3 h 35)",
                      detail: "Surt de Shin-Osaka (i para a Osaka Station Umekita i Tennoji) cada 1-2 h; només alguns arriben fins a Kii-Katsuura/Shingu. Seient reservat recomanat. ≈ 7.000 ¥. Inclòs al JR Pass. A Kii-Katsuura, l'autobús Kumano Kotsu cap a Nachi surt de davant l'estació.", jrPass: true),
                .init(name: "Autobús Kumano Kotsu (Kii-Katsuura → Nachi)", from: "Kii-Katsuura Station", to: "Nachi-san", duration: "≈ 30 min (Daimonzaka 20)",
                      detail: "Cada 1-2 h aprox. Baixa a Daimonzaka per pujar a peu (30 min) o a Nachi-san (final) per anar directe al santuari i la cascada. ≈ 630 ¥. Hi ha un bitllet de dia il·limitat.", jrPass: false),
            ]),
        TransportRoute(
            id: "osaka-local", title: "Moure's per Osaka", icon: "map", kind: .local,
            summary: "La línia de metro Midosuji (vermella) és l'eix: Shin-Osaka – Umeda – Shinsaibashi – Namba – Tennoji. La targeta Icoca (o Suica) funciona a tot arreu. L'Osaka Amazing Pass (1 o 2 dies) inclou metro, busos i entrada gratuïta a 40 atraccions (castell, Umeda Sky Building, nòria, creuer).",
            options: [
                .init(name: "Metro Midosuji Line", from: "Umeda Station", to: "Namba Station", duration: "≈ 8 min",
                      detail: "Cada 2-4 min. ≈ 240 ¥. El bitllet de dia de metro Enjoy Eco Card costa 820 ¥ (620 en cap de setmana).", jrPass: false),
                .init(name: "JR Osaka Loop Line", from: "Osaka Station", to: "Tennoji Station", duration: "≈ 20 min",
                      detail: "Cercle que uneix Osaka Station, Kyobashi, el castell (Osakajokoen), Tsuruhashi, Tennoji, Shin-Imamiya (Shinsekai) i Nishikujo (Universal). Inclòs al JR Pass.", jrPass: true),
            ]),
    ]

    // MARK: - Kyoto

    static let kyoto: [TransportRoute] = [
        TransportRoute(
            id: "kyoto-kix", title: "Kyoto ⇄ Aeroport de Kansai (KIX)", icon: "airplane.departure", kind: .airport,
            summary: "El Haruka és directe des de l'estació de Kyoto (andana 30) fins a l'aeroport en uns 75-80 min.",
            options: [
                .init(name: "JR Limited Express Haruka", from: "Kyoto Station", to: "Kansai Airport Station", duration: "≈ 75-80 min",
                      detail: "Cada 30 min. Inclòs al JR Pass. Haruka discount ticket per a estrangers ≈ 2.200 ¥.", jrPass: true),
                .init(name: "Autobús Limousine", from: "Kyoto Station Hachijo Exit", to: "Kansai Airport Terminal 1", duration: "≈ 90-105 min",
                      detail: "Des de la sortida Hachijo (sud) de l'estació, cada 30 min. ≈ 2.800 ¥.", jrPass: false),
            ]),
        TransportRoute(
            id: "kyoto-osaka", title: "Kyoto → Osaka", icon: "tram.fill", kind: .intercity,
            summary: "JR Special Rapid a Osaka Station (29 min), Hankyu de Kawaramachi a Umeda (45 min) o Keihan de Gion-Shijo a Yodoyabashi (50 min).",
            options: [
                .init(name: "JR Special Rapid", from: "Kyoto Station", to: "Osaka Station", duration: "≈ 29 min",
                      detail: "Cada 15 min, andanes 4-5. ≈ 580 ¥. Inclòs al JR Pass.", jrPass: true),
                .init(name: "Hankyu Kyoto Line", from: "Kyoto-Kawaramachi Station", to: "Osaka-Umeda Station", duration: "≈ 45 min",
                      detail: "Des del centre (Kawaramachi / Karasuma), cada 10 min. ≈ 410 ¥.", jrPass: false),
            ]),
        TransportRoute(
            id: "kyoto-tokyo", title: "Kyoto → Tòquio (Shinkansen)", icon: "train.side.front.car", kind: .intercity,
            summary: "Andanes 11-14 de l'estació de Kyoto (costat Hachijo). Nozomi 2 h 10 min; Hikari (JR Pass) 2 h 40 min. Seu a l'esquerra (seients A) anant cap a Tòquio per veure el mont Fuji, cap a Shizuoka.",
            options: [
                .init(name: "Nozomi", from: "Kyoto Station", to: "Tokyo Station", duration: "≈ 2 h 10 min",
                      detail: "Cada 10 min. ≈ 14.170 ¥ reservat. Per a l'equipatge de més de 160 cm cal reservar seient amb espai (oversized baggage).", jrPass: false),
                .init(name: "Hikari", from: "Kyoto Station", to: "Tokyo Station", duration: "≈ 2 h 40 min",
                      detail: "Cada 30 min. Inclòs al JR Pass.", jrPass: true),
            ]),
        TransportRoute(
            id: "kyoto-nara", title: "Kyoto → Nara", icon: "tram.fill", kind: .intercity,
            summary: "Kintetsu des de l'estació de Kyoto (sud, costat Hachijo) és el més ràpid i deixa al costat del parc; JR Nara Line (JR Pass) para a Inari i Uji.",
            options: [
                .init(name: "Kintetsu Limited Express", from: "Kyoto Station", to: "Kintetsu-Nara Station", duration: "≈ 35 min (Express 45 min)",
                      detail: "Cada 30 min; ≈ 1.280 ¥ reservat o 760 ¥ als Express sense reserva.", jrPass: false),
                .init(name: "JR Nara Line (Miyakoji Rapid)", from: "Kyoto Station", to: "Nara Station", duration: "≈ 45 min",
                      detail: "Cada 30 min, andanes 8-10. ≈ 720 ¥. Inclòs al JR Pass. Para a Inari (Fushimi Inari) i Uji.", jrPass: true),
            ]),
        TransportRoute(
            id: "kyoto-local", title: "Moure's per Kyoto", icon: "map", kind: .local,
            summary: "L'autobús és el rei (bitllet de dia de bus 700 ¥; el de bus + metro 1.100 ¥), però va molt ple: per Higashiyama i Arashiyama sovint és millor combinar el metro (línies Karasuma i Tozai), els trens Keihan/Hankyu/Randen i caminar. Icoca serveix a tot.",
            options: [
                .init(name: "Metro Karasuma + Tozai", from: "Kyoto Station", to: "Higashiyama Station", duration: "≈ 15 min",
                      detail: "Karasuma (nord-sud) i Tozai (est-oest, Nijo – Higashiyama – Keage – Yamashina). ≈ 260 ¥.", jrPass: false),
                .init(name: "JR Sagano Line (a Arashiyama)", from: "Kyoto Station", to: "Saga-Arashiyama Station", duration: "≈ 15 min",
                      detail: "Andanes 32-33. Inclòs al JR Pass. L'estació és a 10 min a peu del bosc de bambú.", jrPass: true),
            ]),
    ]

    // MARK: - Hiroshima

    static let hiroshima: [TransportRoute] = [
        TransportRoute(
            id: "hiroshima-miyajima", title: "Hiroshima → Miyajima", icon: "ferry.fill", kind: .local,
            summary: "Tren JR Sanyo fins a Miyajimaguchi (≈ 28 min) i ferri JR de 10 min: tot inclòs al JR Pass. Alternativa panoràmica: vaixell directe des del Parc de la Pau (45 min).",
            options: [
                .init(name: "JR Sanyo Line + JR Ferry", from: "Hiroshima Station", to: "Miyajimaguchi Station", duration: "≈ 28 min + 10 min ferri",
                      detail: "Trens cap a Iwakuni cada 10-15 min (andanes 1-2). El moll és a 3 min de l'estació; ferris JR i Matsudai cada 10-15 min (≈ 200 ¥ + 100 ¥ de taxa de l'illa). L'últim ferri de tornada és cap a les 22:00.", jrPass: true),
                .init(name: "Tramvia Hiroden línia 2", from: "Hiroshima Station", to: "Hiroden-miyajima-guchi Station", duration: "≈ 70 min",
                      detail: "Més lent però barat (≈ 270 ¥) i passa pel centre; útil des del Parc de la Pau (parada Genbaku Dome-mae).", jrPass: false),
                .init(name: "World Heritage Sea Route (vaixell)", from: "Motoyasu Pier Hiroshima", to: "Miyajima Pier", duration: "≈ 45 min",
                      detail: "Surt del moll Motoyasu, al costat de la Cúpula, cada 30-60 min. ≈ 2.400 ¥. Sense transbords i amb vistes des del riu i la badia.", jrPass: false),
            ]),
        TransportRoute(
            id: "hiroshima-osaka", title: "Hiroshima → Osaka / Himeji", icon: "train.side.front.car", kind: .intercity,
            summary: "Shinkansen Sanyo des de l'estació de Hiroshima (sortida nord / Shinkansen-guchi). Nozomi 1 h 25 min a Shin-Osaka; Sakura (JR Pass) 1 h 35 min. Himeji és a 1 h.",
            options: [
                .init(name: "Nozomi / Mizuho", from: "Hiroshima Station", to: "Shin-Osaka Station", duration: "≈ 1 h 25 min",
                      detail: "Cada 10-15 min. Himeji en ≈ 60 min. Sense JR Pass ordinari.", jrPass: false),
                .init(name: "Sakura / Hikari", from: "Hiroshima Station", to: "Shin-Osaka Station", duration: "≈ 1 h 35 min",
                      detail: "Inclòs al JR Pass. Para a Himeji (≈ 1 h) i Okayama (per a Kurashiki).", jrPass: true),
            ]),
        TransportRoute(
            id: "hiroshima-local", title: "Moure's per Hiroshima", icon: "map", kind: .local,
            summary: "Els tramvies Hiroden arriben a tot arreu (tarifa plana ≈ 220 ¥, Icoca acceptada). L'autobús turístic Meipuru-pu (inclòs al JR Pass) fa el circuit estació – Parc de la Pau – castell.",
            options: [
                .init(name: "Tramvia Hiroden (línies 2 i 6)", from: "Hiroshima Station", to: "Genbaku Dome-mae", duration: "≈ 15-20 min",
                      detail: "Es paga en baixar. Parades: Hatchobori (centre/Hondori), Genbaku Dome-mae (Parc de la Pau).", jrPass: false),
                .init(name: "Meipuru-pu Sightseeing Loop Bus", from: "Hiroshima Station", to: "Peace Memorial Park", duration: "≈ 15-20 min",
                      detail: "Tres rutes (taronja, verda, lila) des de la sortida nord de l'estació. Gratuït amb JR Pass; ≈ 220 ¥ per trajecte.", jrPass: true),
            ]),
    ]

    // MARK: - Himeji

    static let himeji: [TransportRoute] = [
        TransportRoute(
            id: "himeji-osaka", title: "Osaka ⇄ Himeji", icon: "train.side.front.car", kind: .intercity,
            summary: "El castell és a 15-20 min a peu de l'estació per l'avinguda Otemae-dori (es veu des de la sortida nord). Shinkansen des de Shin-Osaka en mitja hora, o JR Special Rapid des d'Osaka Station en una hora sense reserva.",
            options: [
                .init(name: "Shinkansen Nozomi / Sakura / Hikari", from: "Shin-Osaka Station", to: "Himeji Station", duration: "≈ 30 min",
                      detail: "Sakura i Hikari inclosos al JR Pass; Nozomi no. ≈ 3.280 ¥ sense reserva.", jrPass: true),
                .init(name: "JR Special Rapid (Kobe Line)", from: "Osaka Station", to: "Himeji Station", duration: "≈ 62 min",
                      detail: "Cada 15 min des de les andanes 5-6 d'Osaka Station. ≈ 1.520 ¥. Inclòs al JR Pass. Para a Sannomiya (Kobe).", jrPass: true),
                .init(name: "Sanyo Electric Railway (Direct Express)", from: "Hanshin Osaka-Umeda Station", to: "Sanyo-Himeji Station", duration: "≈ 1 h 35 min",
                      detail: "Alternativa barata (≈ 1.320 ¥) des de Hanshin Umeda; l'estació Sanyo-Himeji és al costat de la JR.", jrPass: false),
            ]),
        TransportRoute(
            id: "himeji-shosha", title: "Himeji → Mont Shosha (Engyo-ji)", icon: "bus.fill", kind: .local,
            summary: "Autobús Shinki núm. 8 des de la parada 10 de la terminal nord de l'estació fins al telefèric (≈ 30 min), i telefèric de 4 min. Bitllet combinat bus + telefèric ≈ 1.600 ¥.",
            options: [
                .init(name: "Bus Shinki 8 + Shosha Ropeway", from: "Himeji Station", to: "Mount Shosha Ropeway", duration: "≈ 30 min + 4 min telefèric",
                      detail: "Cada 20-30 min. Des de l'estació superior, 20 min a peu (o minibús) fins al Maniden.", jrPass: false),
            ]),
    ]

    // MARK: - Nara

    static let nara: [TransportRoute] = [
        TransportRoute(
            id: "nara-osaka", title: "Nara ⇄ Osaka / Kyoto", icon: "tram.fill", kind: .intercity,
            summary: "Kintetsu-Nara és al costat del parc; JR Nara a 20 min a peu (o bus). Kintetsu a Osaka-Namba 40 min i a Kyoto 35-45 min; JR Yamatoji Rapid a Osaka 50 min i JR Nara Line a Kyoto 45 min.",
            options: [
                .init(name: "Kintetsu Nara Line", from: "Kintetsu-Nara Station", to: "Osaka-Namba Station", duration: "≈ 40 min",
                      detail: "Rapid Express cada 15-20 min, ≈ 680 ¥.", jrPass: false),
                .init(name: "JR Yamatoji Rapid", from: "Nara Station", to: "Osaka Station", duration: "≈ 50 min",
                      detail: "Inclòs al JR Pass. Para a Horyu-ji (12 min) i Tennoji.", jrPass: true),
                .init(name: "Kintetsu Kyoto Line", from: "Kintetsu-Nara Station", to: "Kyoto Station", duration: "≈ 35-45 min",
                      detail: "Limited Express (reservat) o Express directes cada 30 min.", jrPass: false),
            ]),
        TransportRoute(
            id: "nara-local", title: "Moure's per Nara", icon: "map", kind: .local,
            summary: "El parc, Todai-ji, Kasuga Taisha i Naramachi es fan a peu des de Kintetsu-Nara. Per a Horyu-ji, tren JR fins a Horyuji (12 min) + 20 min a peu o bus; per a Yoshino, Kintetsu des de Yamato-Yagi/Kashiharajingu-mae (≈ 1 h 30 min des de Nara).",
            options: [
                .init(name: "Bus Nara Kotsu (circular)", from: "Kintetsu-Nara Station", to: "Todaiji Daibutsuden Kasuga Taisha-mae", duration: "≈ 10 min",
                      detail: "Línies 1 i 2 (circular) cada 10 min, ≈ 250 ¥. Bitllet de dia ≈ 600 ¥.", jrPass: false),
                .init(name: "JR Yamatoji Line (Horyu-ji)", from: "Nara Station", to: "Horyuji Station", duration: "≈ 12 min",
                      detail: "Inclòs al JR Pass. Des de l'estació, bus 72 (8 min) o 20 min a peu fins al temple.", jrPass: true),
            ]),
    ]

    // MARK: - Wakayama

    static let wakayama: [TransportRoute] = [
        TransportRoute(
            id: "wakayama-osaka", title: "Wakayama ⇄ Osaka", icon: "tram.fill", kind: .intercity,
            summary: "JR Kishuji Rapid a Osaka Station (1 h 25 min) / Tennoji (1 h 10 min), o Nankai des de Wakayamashi a Namba (1 h).",
            options: [
                .init(name: "JR Kishuji Rapid", from: "Wakayama Station", to: "Osaka Station", duration: "≈ 1 h 25 min",
                      detail: "Cada 15-30 min. Inclòs al JR Pass. Kuroshio (reservat) en 60 min.", jrPass: true),
                .init(name: "Nankai Main Line", from: "Wakayamashi Station", to: "Nankai Namba Station", duration: "≈ 1 h",
                      detail: "Express cada 30 min, ≈ 930 ¥. Wakayamashi és a 10 min del castell; de JR Wakayama hi ha bus o 25 min a peu.", jrPass: false),
            ]),
        TransportRoute(
            id: "wakayama-kumano", title: "Wakayama → Kii-Katsuura / Nachi / Shingu", icon: "tram.fill", kind: .intercity,
            summary: "Limited Express Kuroshio per la línia Kisei resseguint la costa: Kii-Katsuura en 2 h 45 min, Shingu (Hayatama Taisha) en 3 h. Des de Kii-Katsuura, bus a Nachi (30 min). Per a Hongu Taisha, bus des de Shingu (1 h).",
            options: [
                .init(name: "JR Limited Express Kuroshio", from: "Wakayama Station", to: "Kii-Katsuura Station", duration: "≈ 2 h 45 min",
                      detail: "Cada 1-2 h; només alguns arriben a Kii-Katsuura/Shingu. Inclòs al JR Pass. Seient a la dreta cap al sud per veure el mar.", jrPass: true),
                .init(name: "Bus Kumano Kotsu", from: "Kii-Katsuura Station", to: "Nachi-san", duration: "≈ 30 min",
                      detail: "Baixa a Daimonzaka per pujar a peu pel camí de pedra (30 min) o al final per anar directe al santuari.", jrPass: false),
            ]),
        TransportRoute(
            id: "wakayama-local", title: "Moure's per Wakayama", icon: "map", kind: .local,
            summary: "El castell és al centre; Kimiidera (JR Kinokuni Line, 6 min) i Marina City (bus des de Kainan o Wakayama) queden al sud. El tren a Kishi (gat Tama) surt de JR Wakayama, andana 9.",
            options: [
                .init(name: "JR Kinokuni Line (Kimiidera)", from: "Wakayama Station", to: "Kimiidera Station", duration: "≈ 6 min",
                      detail: "Inclòs al JR Pass. 10 min a peu fins al temple.", jrPass: true),
                .init(name: "Bus Wakayama (Marina City)", from: "Wakayama Station", to: "Wakayama Marina City", duration: "≈ 30-40 min",
                      detail: "Autobús Wakayama Bus línia 121/117 des de l'estació JR. ≈ 500 ¥.", jrPass: false),
            ]),
    ]

    // MARK: - Hakone

    static let hakone: [TransportRoute] = [
        TransportRoute(
            id: "hakone-tokyo", title: "Hakone ⇄ Tòquio", icon: "tram.fill", kind: .intercity,
            summary: "Romancecar directe de Hakone-Yumoto a Shinjuku (85 min) o tren Tozan fins a Odawara i Shinkansen a Tòquio (35 min, JR Pass).",
            options: [
                .init(name: "Odakyu Romancecar", from: "Hakone-Yumoto Station", to: "Shinjuku Station", duration: "≈ 1 h 25 min",
                      detail: "Cada 30-60 min. Seient reservat (suplement ≈ 1.200 ¥ amb Hakone Free Pass).", jrPass: false),
                .init(name: "Hakone Tozan + Shinkansen", from: "Hakone-Yumoto Station", to: "Tokyo Station", duration: "≈ 15 min + 35 min",
                      detail: "Tozan fins a Odawara (cada 15 min) i Kodama/Hikari a Tòquio o Shinagawa. Inclòs al JR Pass (el Tozan Odawara–Yumoto no).", jrPass: true),
            ]),
        TransportRoute(
            id: "hakone-loop", title: "El circuit de Hakone (Hakone Free Pass)", icon: "arrow.triangle.2.circlepath", kind: .local,
            summary: "Recorregut clàssic en cercle: tren Tozan (Yumoto → Gora, 40 min) → funicular (Gora → Sounzan, 10 min) → telefèric Ropeway (Sounzan → Owakudani → Togendai, 30 min) → vaixell pirata pel llac Ashi (Togendai → Hakone-machi / Moto-Hakone, 30 min) → bus Hakone Tozan de tornada a Yumoto (40 min). Tot inclòs al Free Pass (2 dies ≈ 6.100 ¥ des de Shinjuku, 5.000 ¥ des d'Odawara).",
            options: [
                .init(name: "Tren Hakone Tozan", from: "Hakone-Yumoto Station", to: "Gora Station", duration: "≈ 40 min",
                      detail: "Tren de muntanya amb tres ziga-zagues. Para a Tonosawa, Miyanoshita, Chokoku-no-Mori (museu a l'aire lliure).", jrPass: false),
                .init(name: "Hakone Ropeway", from: "Sounzan Station", to: "Togendai Station", duration: "≈ 30 min",
                      detail: "Passa per Owakudani (vall volcànica, ous negres). Pot tancar per vent o gas: comprova-ho al matí.", jrPass: false),
                .init(name: "Bus Hakone Tozan (línia H)", from: "Moto-Hakone", to: "Hakone-Yumoto Station", duration: "≈ 35-40 min",
                      detail: "Cada 15-20 min. Tancament del cercle des del llac Ashi; també va al santuari de Hakone i a l'avinguda de cedres.", jrPass: false),
            ]),
    ]

    // MARK: - Kamakura

    static let kamakura: [TransportRoute] = [
        TransportRoute(
            id: "kamakura-tokyo", title: "Kamakura ⇄ Tòquio", icon: "tram.fill", kind: .intercity,
            summary: "JR Yokosuka Line a Tòquio (55 min) i Shonan-Shinjuku Line a Shinjuku/Shibuya (1 h), tots dos inclosos al JR Pass, cada 10-15 min.",
            options: [
                .init(name: "JR Yokosuka Line", from: "Kamakura Station", to: "Tokyo Station", duration: "≈ 55 min",
                      detail: "Para a Kita-Kamakura, Yokohama, Shinagawa i Shimbashi.", jrPass: true),
                .init(name: "JR Shonan-Shinjuku Line", from: "Kamakura Station", to: "Shinjuku Station", duration: "≈ 1 h",
                      detail: "Directe a Ebisu, Shibuya, Shinjuku i Ikebukuro.", jrPass: true),
            ]),
        TransportRoute(
            id: "kamakura-enoden", title: "Tren Enoden (Kamakura → Hase → Enoshima)", icon: "tram.fill", kind: .local,
            summary: "El tramvia-tren de la costa: Kamakura – Hase (Gran Buda, Hase-dera, 5 min) – Kamakura-Koko-Mae (el pas a nivell famós) – Enoshima (25 min) – Fujisawa. Bitllet de dia Noriorikun ≈ 800 ¥.",
            options: [
                .init(name: "Enoden", from: "Kamakura Station", to: "Hase Station", duration: "≈ 5 min (Enoshima 25)",
                      detail: "Cada 12 min. Molt ple els caps de setmana al migdia. Des de Hase, 10 min a peu fins al Gran Buda.", jrPass: false),
                .init(name: "Bus a Hokoku-ji / Sugimoto-dera", from: "Kamakura Station", to: "Jomyoji", duration: "≈ 10 min",
                      detail: "Bus Keikyu 23/24/36 des de la sortida est de l'estació fins a la parada Jomyoji (bosc de bambú de Hokoku-ji).", jrPass: false),
            ]),
    ]

    // MARK: - Nikko

    static let nikko: [TransportRoute] = [
        TransportRoute(
            id: "nikko-tokyo", title: "Nikko ⇄ Tòquio", icon: "tram.fill", kind: .intercity,
            summary: "Tobu limited express a Asakusa (1 h 50 min) o JR Nikko Line fins a Utsunomiya + Shinkansen a Tòquio (JR Pass). Les dues estacions són a l'inici del carrer que puja al Shinkyo (20 min a peu o bus).",
            options: [
                .init(name: "Tobu Limited Express (Kegon / Spacia X)", from: "Tobu-Nikko Station", to: "Tobu Asakusa Station", duration: "≈ 1 h 50 min",
                      detail: "Seient reservat; reserva la tornada en arribar si viatges en temporada de tardor.", jrPass: false),
                .init(name: "JR Nikko Line + Shinkansen", from: "Nikko Station", to: "Tokyo Station", duration: "≈ 45 min + 50 min",
                      detail: "Tren local a Utsunomiya i Yamabiko/Nasuno a Tòquio. Inclòs al JR Pass.", jrPass: true),
            ]),
        TransportRoute(
            id: "nikko-local", title: "Moure's per Nikko", icon: "bus.fill", kind: .local,
            summary: "Bus Tobu World Heritage (cercle, cada 10-15 min) des de les estacions fins a Shinkyo, Toshogu i Taiyuin (≈ 500 ¥ de dia). Per al llac Chuzenji i les cascades Kegon, bus Tobu cap a Chuzenji Onsen / Yumoto Onsen (≈ 50 min per la carretera Irohazaka).",
            options: [
                .init(name: "World Heritage Loop Bus", from: "Tobu-Nikko Station", to: "Nishisando", duration: "≈ 10 min",
                      detail: "Parades Shinkyo, Omotesando i Nishisando (Toshogu i Taiyuin). Inclòs al Nikko Pass.", jrPass: false),
                .init(name: "Bus Tobu a Chuzenji / Yumoto", from: "Tobu-Nikko Station", to: "Chuzenji Onsen", duration: "≈ 50 min",
                      detail: "Cada 30 min aprox. Inclòs al Nikko All Area Pass. Pot haver-hi molt trànsit els caps de setmana d'octubre-novembre.", jrPass: false),
            ]),
    ]
}
