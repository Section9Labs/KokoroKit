// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Section9Labs and contributors

// Bounded, independently authored broad transcriptions, not imported dictionary
// rows. These fix high-impact exceptions to spelling rules. They deliberately do
// not resolve ambiguous homographs (Italian ancora/principi, Portuguese gosto).
// Sources, accent choices and limitations: docs/ROMANCE-POLISH-2026-10.md.
enum RomanceLexicon {
    static let frenchNames: [String: String] = [
        "jean": "ʒɑ̃", "jeanne": "ʒan", "jacques": "ʒak", "marc": "maʁk",
        "paul": "pɔl", "pierre": "pjɛʁ", "louis": "lwi", "luc": "lyk",
        "lise": "liz", "hélène": "elɛn", "françois": "fʁɑ̃swa", "marie": "maʁi",
        // Audited against the existing dictionary/fallback before addition.
        "chloé": "kloe", "achille": "akil", "gabriel": "gabʁijɛl", "bastien": "bastjɛ̃",
        "thibault": "tibo", "geneviève": "ʒənəvjɛv", "sébastien": "sebastjɛ̃",
        "adrien": "adʁijɛ̃", "lucien": "lysjɛ̃", "fabien": "fabjɛ̃", "henriette": "ɑ̃ʁjɛt",
        "anaïs": "anais", "boris": "bɔʁis", "ivan": "ivan", "daniel": "danjɛl",
        "robert": "ʁɔbɛʁ", "gilbert": "ʒilbɛʁ", "albert": "albɛʁ", "alfred": "alfʁɛd",
        "proust": "pʁust", "flaubert": "flobɛʁ", "verne": "vɛʁn", "musset": "mysɛ",
        "gautier": "gotje", "daudet": "dodɛ", "saëns": "sɑ̃s",
        "shakespeare": "ʃɛkspiʁ", "dickens": "dikɛns", "tolkien": "tɔlkjɛn",
        "metz": "mɛs", "rouen": "ʁwɑ̃", "caen": "kɑ̃", "laon": "lɑ̃", "auxerre": "osɛʁ", "aix": "ɛks"
    ]

    static let french: [String: String] = ["podcast": "podkast", "email": "imɛl", "thriller": "tʁilœʁ"]
    static let frenchCompounds: [String: String] = ["week-end": "wikɛnd", "week-ends": "wikɛnd",
                                                      "e-mail": "imɛl", "e-mails": "imɛl"]

    // Unstressed fragments are used only immediately before a written apostrophe
    // and another word. Ordinary words never take this lookup path.
    static let italianElisions: [String: String] = [
        "l": "l", "d": "d", "m": "m", "t": "t", "s": "s", "c": "ʧ",
        "v": "v", "un": "un", "all": "all", "dall": "dall", "dell": "dell",
        "nell": "nell", "sull": "sull", "quell": "kwell", "quest": "kwest",
        "sant": "sant", "buon": "bwɔn"
    ]

    static let italian: [String: String] = [
        // Treccani fòglio: open stressed vowel, independently authored reading.
        "foglio": "ˈfɔʎʎo", "fogli": "ˈfɔʎʎi",
        // Narrative vocabulary: antepenultimate stress cannot be inferred from spelling.
        "abitano": "ˈabitano", "abitava": "abiˈtava", "abitavano": "abiˈtavano",
        "arrivano": "arˈrivano", "arrivavano": "arriˈvavano", "aspettano": "asˈpɛttano",
        "avevano": "aˈvevano", "erano": "ˈɛrano", "dissero": "ˈdissero",
        "disse": "ˈdisse", "chiese": "ˈkjɛze", "rispose": "risˈpoze",
        "sorrise": "sorˈrize", "sembrano": "ˈsembrano", "sembrava": "semˈbrava",
        "sembravano": "semˈbravano", "parlano": "ˈparlano", "parlavano": "parˈlavano",
        "guardano": "ˈgwardano", "guardavano": "gwarˈdavano", "pensano": "ˈpɛnsano",
        "pensavano": "penˈsavano", "possono": "ˈpɔssono", "vogliono": "ˈvɔʎʎono",
        "dicono": "ˈdikono", "vedono": "ˈvedono", "sentono": "ˈsɛntono",
        "aprono": "ˈaprono", "prendono": "ˈprɛndono", "leggono": "ˈlɛdʤono",
        "scrivono": "ˈskrivono", "vivono": "ˈvivono", "sanno": "ˈsanno",
        "aveva": "aˈveva", "era": "ˈɛra", "sua": "ˈsua", "suo": "ˈsuo",
        "sue": "ˈsue", "suoi": "swɔj", "mia": "ˈmia", "mio": "ˈmio", "mie": "ˈmie",
        "miei": "mjɛj", "tua": "ˈtua", "tuo": "ˈtuo", "tue": "ˈtue", "tuoi": "twɔj",
        "paura": "paˈura", "paese": "paˈeze", "poeta": "poˈɛta",
        "anima": "ˈanima", "angolo": "ˈaŋgolo", "attimo": "ˈattimo",
        "camera": "ˈkamera", "macchina": "ˈmakkina", "giovane": "ˈʤovane",
        "giovani": "ˈʤovani", "povero": "ˈpɔvero", "povera": "ˈpɔvera",
        "sorridono": "sorˈridono", "rispondono": "risˈpondono",
        // Common native names; foreign and ambiguous name readings stay out.
        "maria": "maˈria", "giovanni": "ʤoˈvanni", "giuseppe": "ʤuˈzɛppe",
        "giulia": "ˈʤulja", "giulio": "ˈʤuljo", "pietro": "ˈpjɛtro",
        "andrea": "anˈdrɛa", "paolo": "ˈpaolo", "stefano": "ˈstɛfano",
        "davide": "ˈdavide", "nicola": "niˈkɔla", "michele": "miˈkɛle",
        // Literary vocabulary with observed fallback stress/vowel errors.
        "spirito": "ˈspirito", "spiriti": "ˈspiriti", "secolo": "ˈsɛkolo", "secoli": "ˈsɛkoli",
        "principe": "ˈprinʧipe", "capitolo": "kaˈpitolo", "capitoli": "kaˈpitoli",
        "pericolo": "peˈrikolo", "pericoli": "peˈrikoli", "popolo": "ˈpɔpolo", "popoli": "ˈpɔpoli",
        "mistero": "misˈtɛro", "misteri": "misˈtɛri", "ricordo": "riˈkɔrdo", "ricordi": "riˈkɔrdi",
        "silenzio": "siˈlɛntsjo", "silenzi": "siˈlɛntsi", "tenebra": "ˈtɛnebra", "tenebre": "ˈtɛnebre",
        "lacrima": "ˈlakrima", "lacrime": "ˈlakrime", "oceano": "oˈʧɛano", "oceani": "oˈʧɛani",
        "isola": "ˈizola", "isole": "ˈizole", "nuvola": "ˈnuvola", "nuvole": "ˈnuvole",
        "favola": "ˈfavola", "favole": "ˈfavole", "miracolo": "miˈrakolo", "miracoli": "miˈrakoli",
        "immagine": "imˈmaʤine", "immagini": "imˈmaʤini", "origine": "oˈriʤine", "origini": "oˈriʤini",
        "margine": "ˈmarʤine", "margini": "ˈmarʤini", "abito": "ˈabito", "abiti": "ˈabiti",
        "debole": "ˈdebole", "deboli": "ˈdeboli", "timido": "ˈtimido", "timida": "ˈtimida",
        "pallido": "ˈpallido", "pallida": "ˈpallida", "pallidi": "ˈpallidi", "pallide": "ˈpallide",
        "semplice": "ˈsempliʧe", "semplici": "ˈsempliʧi", "simile": "ˈsimile", "simili": "ˈsimili",
        "utile": "ˈutile", "utili": "ˈutili", "inutile": "iˈnutile", "inutili": "iˈnutili",
        "nobile": "ˈnɔbile", "nobili": "ˈnɔbili", "libero": "ˈlibero", "libera": "ˈlibera",
        "liberi": "ˈliberi", "libere": "ˈlibere", "fragile": "ˈfraʤile", "fragili": "ˈfraʤili",
        "rapido": "ˈrapido", "rapida": "ˈrapida", "rapidi": "ˈrapidi", "rapide": "ˈrapide",
        "tenero": "ˈtɛnero", "tenera": "ˈtɛnera", "teneri": "ˈtɛneri",
        "vivere": "ˈvivere", "ridere": "ˈridere", "piangere": "ˈpjanʤere", "perdere": "ˈpɛrdere",
        "credere": "ˈkredere", "scrivere": "ˈskrivere", "chiedere": "ˈkjɛdere", "chiudere": "ˈkjudere",
        "nascere": "ˈnaʃʃere", "crescere": "ˈkreʃʃere", "conoscere": "koˈnoʃʃere",
        "rispondere": "risˈpondere", "sorridere": "sorˈridere", "correre": "ˈkorrere", "mettere": "ˈmɛttere",
        "aspettavano": "aspetˈtavano", "raccontano": "rakˈkontano", "raccontavano": "rakkonˈtavano",
        "ricordano": "riˈkɔrdano", "ricordavano": "rikorˈdavano", "dormono": "ˈdɔrmono",
        "cadono": "ˈkadono", "escono": "ˈɛskono", "tornano": "ˈtornano", "tornavano": "torˈnavano",
        // Native name readings; no blanket override for principi/esercito/tenere.
        "giacomo": "ˈʤakomo", "elena": "ˈɛlena", "ettore": "ˈɛttore", "cesare": "ˈʧezare",
        "lucia": "luˈʧia", "claudio": "ˈklawdjo", "claudia": "ˈklawdja", "sergio": "ˈsɛrʤo",
        "giorgio": "ˈʤɔrʤo", "gabriele": "gabriˈɛle", "raffaele": "raffaˈɛle", "emanuele": "emaˈnwɛle",
        "sofia": "soˈfia", "euridice": "euˈridiʧe", "persefone": "perˈsɛfone", "penelope": "peˈnɛlope",
        "omero": "oˈmɛro", "aristotele": "arisˈtɔtele", "socrate": "ˈsɔkrate", "rachele": "raˈkɛle",
        "noemi": "noˈɛmi", "enea": "eˈnɛa", "shakespeare": "ˈʃɛkspir",
        "computer": "komˈpjuter", "internet": "ˈinternet", "hotel": "oˈtɛl",
        "autobus": "ˈawtobus", "yogurt": "ˈjɔgurt", "weekend": "wiˈkɛnd"
    ]

    static let portuguese: [String: String] = [
        // Function words and productive written contractions retain weak stress.
        "no": "nu", "na": "na", "nos": "nus", "nas": "nas",
        "ao": "aw", "aos": "aws", "à": "a", "às": "as",
        "num": "nũ", "numa": "ˈnũmɐ", "nuns": "nũs", "numas": "ˈnũmɐs",
        "pelo": "ˈpelu", "pela": "ˈpelɐ", "pelos": "ˈpelus", "pelas": "ˈpelɐs",
        "dele": "ˈdeli", "dela": "ˈdɛlɐ", "deles": "ˈdelis", "delas": "ˈdɛlɐs",
        "nele": "ˈneli", "nela": "ˈnɛlɐ", "neles": "ˈnelis", "nelas": "ˈnɛlɐs",
        "desta": "ˈdɛstɐ", "dessa": "ˈdɛsɐ",
        "daquele": "daˈkeli", "daquela": "daˈkɛlɐ", "neste": "ˈnesʧi",
        "nesta": "ˈnɛstɐ", "nesse": "ˈnesi", "nessa": "ˈnɛsɐ",
        "naquele": "naˈkeli", "naquela": "naˈkɛlɐ", "àquele": "aˈkeli", "àquela": "aˈkɛlɐ",
        // Vowel quality, nasalization and exceptional x/qu/gu readings.
        "era": "ˈɛɾɐ", "eram": "ˈɛɾɐ̃w̃", "tinha": "ˈʧĩɲɐ", "tinham": "ˈʧĩɲɐ̃w̃",
        "vinha": "ˈvĩɲɐ", "minha": "ˈmĩɲɐ", "minhas": "ˈmĩɲɐs",
        "disseram": "ʤiˈsɛɾɐ̃w̃", "quiseram": "kiˈzɛɾɐ̃w̃", "fizeram": "fiˈzɛɾɐ̃w̃",
        "quase": "ˈkwazi", "quatro": "ˈkwatɾu", "cinquenta": "sĩˈkwẽtɐ",
        "enquanto": "ẽˈkwɐ̃tu", "tranquilo": "tɾɐ̃ˈkwilu", "tranquila": "tɾɐ̃ˈkwilɐ",
        "linguiça": "lĩˈgwisɐ", "linguística": "lĩˈgwisʧikɐ",
        "próximo": "ˈpɾɔsimu", "próxima": "ˈpɾɔsimɐ", "máximo": "ˈmasimu",
        "táxi": "ˈtaksi", "tóxico": "ˈtɔksiku", "fixo": "ˈfiksu", "fixa": "ˈfiksɐ",
        "trouxe": "ˈtɾowsi", "trouxeram": "tɾowˈsɛɾɐ̃w̃", "exemplo": "eˈzẽplu",
        "exército": "eˈzɛɾsitu", "exame": "eˈzɐ̃mi", "exames": "eˈzɐ̃mis",
        "ruim": "huˈĩ", "ruins": "huˈĩs", "juiz": "ʒuˈis", "juízes": "ʒuˈizis",
        "joão": "ʒuˈɐ̃w̃", "josé": "ʒoˈzɛ", "antônio": "ɐ̃ˈtõnju",
        "antónio": "ɐ̃ˈtɔnju", "pedro": "ˈpedɾu", "carlos": "ˈkaɾlus",
        // Lexical /x/ readings and mid-vowel quality cannot be guessed from spelling.
        "excesso": "eˈsɛsu", "exceto": "eˈsɛtu", "externo": "esˈtɛɾnu", "externa": "esˈtɛɾnɐ",
        "texto": "ˈtɛstu", "textos": "ˈtɛstus", "sexo": "ˈsɛksu", "sexual": "seksuˈaw",
        "auxílio": "awˈsilju", "auxiliar": "awsiliˈaɾ", "táxis": "ˈtaksis",
        "ossos": "ˈɔsus", "povos": "ˈpɔvus", "ovos": "ˈɔvus", "corvos": "ˈkɔɾvus",
        "esforços": "esˈfɔɾsus", "porcos": "ˈpɔɾkus", "jogos": "ˈʒɔgus", "tijolos": "ʧiˈʒɔlus",
        "fogos": "ˈfɔgus", "corpo": "ˈkɔɾpu", "corpos": "ˈkɔɾpus",
        "jovem": "ˈʒɔvẽj̃", "jovens": "ˈʒɔvẽj̃s",
        "tiveram": "ʧiˈvɛɾɐ̃w̃", "estiveram": "esʧiˈvɛɾɐ̃w̃", "puderam": "puˈdɛɾɐ̃w̃",
        "souberam": "sowˈbɛɾɐ̃w̃", "couberam": "kowˈbɛɾɐ̃w̃", "houveram": "owˈvɛɾɐ̃w̃",
        "vieram": "viˈɛɾɐ̃w̃", "puseram": "puˈzɛɾɐ̃w̃", "deram": "ˈdɛɾɐ̃w̃",
        "guerra": "ˈgɛhɐ", "guerras": "ˈgɛhɐs", "guiar": "giˈaɾ", "guia": "ˈgiɐ", "guias": "ˈgiɐs",
        "aguenta": "aˈgwẽtɐ", "aguentar": "agwẽˈtaɾ", "frequente": "fɾeˈkwẽʧi", "frequentes": "fɾeˈkwẽʧis",
        "sequência": "seˈkwẽsjɐ", "consequência": "kõseˈkwẽsjɐ", "frequência": "fɾeˈkwẽsjɐ",
        "miguel": "miˈgɛw", "daniel": "daniˈɛw", "gabriel": "gabɾiˈɛw", "rafael": "hafaˈɛw",
        "isabel": "izaˈbɛw", "manuel": "manuˈɛw", "guilherme": "giˈʎɛɾmi", "luiz": "luˈis",
        "pizza": "ˈpitsɐ", "pizzas": "ˈpitsɐs", "site": "ˈsajʧi", "show": "ʃow",
        "shopping": "ˈʃɔpĩ", "internet": "ĩteɾˈnɛʧi", "email": "iˈmejw", "online": "õˈlajni",
        "futebol": "futeˈbɔw"
    ]
}
