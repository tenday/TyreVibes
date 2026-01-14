import Foundation

struct RAGDocument: Identifiable {
    let id: String
    let title: String
    let content: String
    let tags: [String]
}

struct RAGSnippet: Identifiable {
    let id: String
    let title: String
    let content: String
    let score: Double
}

final class LocalRAGService {
    static let shared = LocalRAGService()

    private let documents: [RAGDocument] = [
        RAGDocument(
            id: "pressure",
            title: "Controllo pressione pneumatici",
            content: "Controlla la pressione a freddo almeno una volta al mese e prima di lunghi viaggi. Usa i valori indicati sul libretto o sul montante porta. Una pressione bassa aumenta usura e consumi.",
            tags: ["pressione", "psi", "bar", "gonfiaggio"]
        ),
        RAGDocument(
            id: "tread",
            title: "Battistrada e usura",
            content: "Se il battistrada scende sotto 3 mm e consigliata la sostituzione. Usura irregolare puo indicare allineamento o bilanciamento da verificare.",
            tags: ["battistrada", "usura", "profondita", "sostituzione"]
        ),
        RAGDocument(
            id: "rotation",
            title: "Rotazione pneumatici",
            content: "La rotazione aiuta a distribuire l usura. Di norma ogni 10.000 km, salvo indicazioni del costruttore.",
            tags: ["rotazione", "inversione", "km"]
        ),
        RAGDocument(
            id: "seasonal",
            title: "Cambio stagionale",
            content: "Valuta il cambio gomme quando le temperature scendono stabilmente sotto 7 gradi. Le invernali migliorano aderenza e frenata a freddo.",
            tags: ["stagionale", "invernali", "estive", "quattro stagioni"]
        ),
        RAGDocument(
            id: "safety",
            title: "Controlli di sicurezza",
            content: "Controlla spalle del pneumatico, tagli o bolle. Se il volante vibra, verifica bilanciamento e allineamento.",
            tags: ["sicurezza", "controllo", "allineamento", "bilanciamento"]
        ),
        RAGDocument(
            id: "app",
            title: "TyreVibes cosa fa",
            content: "TyreVibes aiuta a monitorare pneumatici e manutenzione veicolo, con notifiche, analisi e storico per ogni auto.",
            tags: ["app", "garage", "notifiche", "analisi"]
        )
    ]

    private let stopWords: Set<String> = [
        "il", "lo", "la", "i", "gli", "le", "un", "una", "di", "a", "da", "in", "su",
        "per", "con", "che", "e", "o", "ma", "se", "non", "si", "sono", "hai", "come",
        "cosa", "dove", "quando", "quanto", "perche", "dei", "del", "della", "dello"
    ]

    func retrieve(query: String, maxResults: Int = 3) -> [RAGSnippet] {
        let queryTokens = tokenize(query)
        guard !queryTokens.isEmpty else { return [] }

        let scored = documents.map { doc -> RAGSnippet in
            let titleTokens = tokenize(doc.title)
            let contentTokens = tokenize(doc.content)
            let tagTokens = Set(doc.tags.flatMap { tokenize($0) })

            let titleScore = overlapScore(queryTokens, titleTokens)
            let contentScore = overlapScore(queryTokens, contentTokens)
            let tagScore = overlapScore(queryTokens, tagTokens)

            let score = (2.0 * titleScore) + (1.5 * tagScore) + contentScore
            return RAGSnippet(id: doc.id, title: doc.title, content: doc.content, score: score)
        }

        return scored
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .prefix(maxResults)
            .map { $0 }
    }

    private func tokenize(_ text: String) -> Set<String> {
        let normalized = text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let tokens = normalized.split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 3 && !stopWords.contains($0) }

        return Set(tokens)
    }

    private func overlapScore(_ queryTokens: Set<String>, _ docTokens: Set<String>) -> Double {
        guard !docTokens.isEmpty else { return 0 }
        let overlap = queryTokens.intersection(docTokens).count
        return Double(overlap) / Double(docTokens.count)
    }
}
