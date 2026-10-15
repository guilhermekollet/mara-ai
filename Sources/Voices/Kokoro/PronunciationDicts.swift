import Foundation

/// Pronunciation dictionaries for Kokoro TTS multilingual support.
///
/// Mara keeps only Spanish (English has its own dictionaries, downloaded with the model).
/// Source: ipa-dict (MIT, open-dict-data/ipa-dict) and standard phonetic references.
enum PronunciationDicts {

    // MARK: - Spanish (125 entries)

    static let es: [String: String] = [
        "adiós": "aðjˈos", "agua": "ˈaɣwa", "ahora": "aˈoɾa", "al": "ˈal",
        "alto": "ˈalto", "amarillo": "ˌamaɾˈiʎo", "amigo": "amˈiɣo",
        "antes": "ˈantes", "aquí": "akˈi", "azul": "aθˈul", "año": "ˈaɲo",
        "bajo": "bˈaxo", "bien": "bjˈen", "blanco": "blˈanko", "boca": "bˈoka",
        "brazo": "bɾˈaθo", "bueno": "bwˈeno", "buenos": "bwˈenos",
        "cabeza": "kaβˈeθa", "café": "kafˈe", "calle": "kˈaʎe", "casa": "kˈasa",
        "cinco": "θˈinko", "ciudad": "θjuðˈad", "comida": "komˈiða",
        "como": "kˈomo", "con": "kˈon", "corazón": "kˌoɾaθˈon", "cosa": "kˈosa",
        "cuando": "kwˈando", "cuatro": "kwˈatɾo", "dar": "dˈaɾ", "de": "dˈe",
        "decir": "deθˈiɾ", "del": "dˈel", "desde": "dˈesðe", "después": "despwˈes",
        "donde": "dˈonde", "dos": "dˈos", "día": "dˈia", "días": "dˈias",
        "el": "ˈel", "ella": "ˈeʎa", "ellas": "ˈeʎas", "ellos": "ˈeʎos",
        "en": "ˈen", "entre": "ˈɛntɾe", "eso": "ˈeso", "estar": "estˈaɾ",
        "esto": "ˈesto", "familia": "famˈilja", "gracias": "ɡɾˈaθjas",
        "grande": "ɡɾˈande", "haber": "aβˈeɾ", "hacer": "aθˈeɾ", "hasta": "ˈasta",
        "hermana": "eɾmˈana", "hermano": "eɾmˈano", "hija": "ˈixa",
        "hijo": "ˈixo", "hola": "ˈola", "hombre": "ˈombɾe", "ir": "ˈiɾ",
        "joven": "xˈoβen", "la": "lˈa", "las": "lˈas", "leche": "lˈetʃe",
        "llegar": "ʎeɣˈaɾ", "los": "lˈos", "madre": "mˈaðɾe", "malo": "mˈalo",
        "mano": "mˈano", "mesa": "mˈesa", "mujer": "muxˈeɾ", "mundo": "mˈundo",
        "muy": "mˈuj", "más": "mˈas", "negro": "nˈeɣɾo", "niña": "nˈiɲa",
        "niño": "nˈiɲo", "no": "nˈo", "nosotros": "nosˈotɾos", "nuevo": "nwˈeβo",
        "nunca": "nˈunka", "ojo": "ˈoxo", "padre": "pˈaðɾe", "pan": "pˈan",
        "para": "pˈaɾa", "país": "paˈis", "pequeño": "pekˈeɲo",
        "perdón": "peɾðˈon", "pero": "pˈeɾo", "pie": "pjˈe", "poder": "poðˈeɾ",
        "por": "pˈoɾ", "porque": "pˈoɾke", "prueba": "pɾuˈeβa",
        "puerta": "pwˈeɾta", "querer": "keɾˈeɾ", "qué": "kˈe", "rojo": "rˈoxo",
        "saber": "saβˈeɾ", "ser": "sˈer", "siempre": "sjˈempɾe", "sin": "sˈin",
        "sobre": "sˈoβɾe", "sí": "sˈi", "también": "tambjˈen", "tener": "tenˈeɾ",
        "tiempo": "tjˈempo", "todo": "tˈoðo", "tres": "tɾˈes", "tú": "tˈu",
        "un": "ˈun", "una": "ˈuna", "uno": "ˈuno", "usted": "ustˈed",
        "ventana": "bentˈana", "ver": "bˈeɾ", "verde": "bˈeɾðe", "vida": "bˈiða",
        "viejo": "bjˈexo", "vino": "bˈino", "yo": "ʝˈo", "él": "ˈel",
    ]
}
