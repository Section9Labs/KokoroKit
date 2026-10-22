// SPDX-License-Identifier: Apache-2.0 OR MIT
import Foundation

/// Deliberate local readings for common unadapted English loans. These are not
/// language switches and cannot change narrator identity. Established variants
/// differ between regions; source notes and competing readings are documented.
/// Never replace ordinary ambiguous words (e.g. red, pie, sale, chat) globally.
enum LoanwordReadings {
    static func spanish(_ word: String, dialect: SpanishDialect) -> String? {
        if word == "wifi" { return dialect == .spain ? "ˈwifi" : "ˈwajfaj" }
        // Keep the reviewed software spelling in SpanishLexicon (its phrase
        // allophones are already covered by listening/regression tests).
        return spanish[word]
    }
    static let spanish: [String: String] = [
        "hardware": "ˈhaɾɡweɾ", "firmware": "ˈfiɾmweɾ", "malware": "ˈmalweɾ",
        "streaming": "esˈtɾimin", "marketing": "ˈmaɾketin", "podcast": "ˈpodkast",
        "podcasts": "ˈpodkasts", "online": "onˈlajn", "offline": "ofˈlajn",
        "feedback": "ˈfidbak", "backup": "ˈbakap", "browser": "ˈbɾawseɾ",
        "router": "ˈruteɾ", "smartphone": "esˈmaɾtfon", "smartphones": "esˈmaɾtfons",
        "email": "iˈmejl", "emails": "iˈmejls", "newsletter": "ˈnjusleteɾ",
        "spoiler": "esˈpojleɾ", "spoilers": "esˈpojleɾs", "thriller": "ˈθɾileɾ",
        "thrillers": "ˈθɾileɾs", "bestseller": "bestˈseleɾ",
        "bestsellers": "bestˈseleɾs", "show": "ˈʃow", "shows": "ˈʃows",
        "jogging": "ˈʝoɡin", "parking": "ˈpaɾkin", "camping": "ˈkampin",
        "casting": "ˈkastin", "leasing": "ˈlisin", "ranking": "ˈrankin"
    ]
    static let french: [String: String] = [
        "software":"sɔftwɛʁ", "hardware":"aʁdwɛʁ", "firmware":"fiʁmwɛʁ",
        "streaming":"stʁimiŋ", "marketing":"maʁkɛtiŋ", "podcast":"pɔdkast",
        "podcasts":"pɔdkast", "wifi":"wifi", "newsletter":"njuzlɛtœʁ",
        "feedback":"fidbak", "backup":"bakœp", "smartphone":"smaʁtfɔn",
        "smartphones":"smaʁtfɔn", "spoiler":"spɔjlœʁ", "spoilers":"spɔjlœʁ",
        "thriller":"tʁilœʁ", "thrillers":"tʁilœʁ", "show":"ʃo", "shows":"ʃo",
        "parking":"paʁkiŋ", "camping":"kɑ̃piŋ", "casting":"kastiŋ", "jogging":"dʒɔɡiŋ"
    ]
    static let italian: [String: String] = [
        "software":"ˈsɔftwɛr", "hardware":"ˈardwɛr", "firmware":"ˈfirmwɛr",
        "streaming":"ˈstrimiŋ", "marketing":"ˈmarketiŋ", "podcast":"ˈpɔdkast",
        "wifi":"ˈwajfaj", "online":"onˈlajn", "offline":"ofˈlajn",
        "feedback":"ˈfidbɛk", "backup":"ˈbɛkap", "browser":"ˈbrawzer",
        "router":"ˈruter", "smartphone":"ˈsmartfon", "email":"ˈimɛjl",
        "newsletter":"ˈnjuzlɛtter", "spoiler":"ˈspɔjler", "thriller":"ˈθriller",
        "bestseller":"bestˈsɛller", "show":"ˈʃɔw", "jogging":"ˈdʒɔɡɡiŋ",
        "parking":"ˈparkiŋ", "camping":"ˈkampiŋ", "casting":"ˈkastiŋ"
    ]
    static let portuguese: [String: String] = [
        "software":"ˈsɔfʧiwɛɾ", "hardware":"ˈhaɾdwɛɾ", "firmware":"ˈfiɾmwɛɾ",
        "streaming":"isˈtɾimiŋ", "marketing":"ˈmaɾkeʧiŋ", "podcast":"ˈpɔdkasʧi",
        "podcasts":"ˈpɔdkasʧis", "wifi":"ˈwajfaj", "online":"õˈlajni",
        "offline":"ɔfˈlajni", "feedback":"ˈfidbɛki", "backup":"ˈbɛkapi",
        "smartphone":"isˈmaɾʧifõni", "smartphones":"isˈmaɾʧifõnis",
        "email":"iˈmɛjw", "emails":"iˈmɛjws", "spoiler":"isˈpɔjleɾ",
        "spoilers":"isˈpɔjleɾs", "show":"ˈʃow", "shows":"ˈʃows",
        "shopping":"ˈʃɔpiŋ", "ranking":"ˈhɐ̃kiŋ"
    ]
}
