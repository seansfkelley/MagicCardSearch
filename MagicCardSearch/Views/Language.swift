enum Language {
    private static let languages: [String: String] = [
        "en": "English",
        "es": "Spanish",
        "fr": "French",
        "de": "German",
        "it": "Italian",
        "pt": "Portuguese",
        "ja": "Japanese",
        "ko": "Korean",
        "ru": "Russian",
        "zhs": "Simplified Chinese",
        "zht": "Traditional Chinese",
        "he": "Hebrew",
        "la": "Latin",
        "grc": "Ancient Greek",
        "ar": "Arabic",
        "sa": "Sanskrit",
        "px": "Phyrexian",
    ]

    static func name(forCode code: String) -> String {
        return languages[code.lowercased()] ?? code.capitalized
    }
}
