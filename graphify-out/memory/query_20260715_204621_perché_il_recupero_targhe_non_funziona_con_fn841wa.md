---
type: "query"
date: "2026-07-15T20:46:21.578727+00:00"
question: "Perché il recupero targhe non funziona con FN841WA?"
contributor: "graphify"
source_nodes: ["Endpoint Chiamato", "code:block10 (GET https://www.tyrevibes.com/api/v1/check_plate?plate=AB123)"]
---

# Q: Perché il recupero targhe non funziona con FN841WA?

## Answer

Il dominio pubblico www.tyrevibes.com risolve a 216.227.142.171: su HTTPS il server nginx chiude l'handshake senza presentare certificato; su HTTP /api/v1/health e /api/v1/check_plate restituiscono 404. L'origine cPanel 198.54.120.13 conserva la configurazione Passenger ma ha certificato scaduto il 15 giugno 2026 e gli endpoint /api risultano 404. I provider di fallback non compensano: Quattroruote richiede reCAPTCHA valido; Allianz risponde 202 con x-amzn-waf-action challenge e body vuoto. Gli endpoint pubblici del Portale dell'Automobilista rispondono per FN841WA, confermando che la targa esiste.

## Source Nodes

- Endpoint Chiamato
- code:block10 (GET https://www.tyrevibes.com/api/v1/check_plate?plate=AB123)