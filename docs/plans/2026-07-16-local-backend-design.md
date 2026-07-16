# TyreVibes Local Backend Design

## Obiettivo

Ripristinare tutte le funzionalità dell'app senza un hosting applicativo a pagamento. Il progetto Supabase ospitato resta il sistema di autenticazione e continua a servire le funzionalità che l'app usa direttamente tramite Supabase SDK. Il backend Express già presente in `server.js` e il relativo database MySQL vengono eseguiti sul Mac.

Il sistema deve essere raggiungibile sia dal simulatore iOS sia da un iPhone fisico collegato alla stessa rete Wi-Fi del Mac.

## Vincoli

- Riutilizzare `server.js`, gli schema SQL e i modelli esistenti.
- Non introdurre nuove funzionalità o nuove entità di dominio.
- Gli utenti e i dati precedenti possono essere abbandonati; si parte da zero.
- Conservare Supabase ospitato per autenticazione e accessi diretti già presenti nell'app.
- Conservare MySQL, perché `server.js` usa `mysql2`, placeholder `?` e sintassi MySQL.
- Non mostrare all'utente dettagli tecnici delle richieste durante la ricerca della targa.
- Il backend locale è disponibile solo quando il Mac è acceso e, per l'iPhone, sulla stessa rete locale.

## Architettura

```text
iOS Simulator / iPhone
    |-- Supabase SDK + Auth ------> Supabase ospitato
    |                                  |
    |                                  `-- JWT utente
    |
    `-- REST /api/v1 + Bearer JWT -> server.js sul Mac:3000
                                         |
                                         `-- MySQL locale / database tyrevibes
```

Supabase emette il JWT. `server.js` verifica lo stesso token tramite `SUPABASE_JWT_SECRET`. Nessuna chiave privilegiata o password MySQL viene inclusa nell'app iOS.

## Backend locale

`server.js` resta il contratto principale delle API e continua a montare le route sia su `/v1` sia su `/api/v1`. Verrà aggiunto soltanto il materiale operativo mancante per eseguirlo localmente:

- manifest Node con le dipendenze effettivamente importate (`express`, `mysql2`, `jsonwebtoken`, `sharp`);
- configurazione ambiente locale non versionata per credenziali MySQL e JWT secret;
- avvio in ascolto sull'interfaccia LAN;
- endpoint health esistente usato per la verifica;
- script di avvio e inizializzazione ripetibili.

SecNeo rimarrà disabilitato localmente salvo configurazione esplicita, come già previsto dal backend.

## Database MySQL

Lo schema MySQL esistente in `database/schema.sql` sarà la base. Le tabelle e colonne ulteriori richieste da `server.js` saranno definite esclusivamente a partire dalle query SQL, dalle route e dai modelli già presenti nel repository. Non verranno create entità applicative nuove.

L'inizializzazione dovrà essere idempotente e includere:

- schema principale esistente;
- migrazioni SQL già presenti;
- strutture per targhe, associazione utenti-veicoli, immagini, assicurazione, revisioni e pneumatici supportati richieste dalle route esistenti;
- tabelle manutenzione e profilo che `server.js` oggi crea a runtime;
- impostazioni utente e strutture di analisi pneumatici già presenti.

Il database parte vuoto. Il backup resterà un semplice dump MySQL locale.

## Configurazione iOS e rete

L'app continuerà a usare URL e chiave anon Supabase ospitati. `BASE_URL` verrà separato dalla configurazione Supabase e punterà al backend sul Mac.

- Simulatore: può raggiungere il Mac tramite indirizzo locale configurato.
- iPhone: usa l'indirizzo IPv4 LAN del Mac, per esempio `http://192.168.x.x:3000/api`.
- La configurazione locale deve essere centralizzata e non duplicata nei servizi Swift.
- Verrà verificata la policy App Transport Security necessaria per traffico HTTP solo sulla rete locale.

L'indirizzo non può essere fissato inventando un IP: uno script ricaverà l'IPv4 attivo del Mac e produrrà la configurazione di sviluppo appropriata.

## Flusso autenticazione

1. L'utente crea un nuovo account o accede tramite Supabase.
2. L'app riceve una sessione e il relativo access token.
3. Le chiamate a `server.js` inviano `Authorization: Bearer <token>` tramite i helper esistenti.
4. `server.js` verifica firma e scadenza con il JWT secret di Supabase.
5. Le route usano l'identificativo `sub` autenticato per limitare l'accesso ai dati MySQL dell'utente.

## Flusso targa

1. L'utente inserisce o scansiona la targa.
2. La ricerca veicolo già implementata recupera i dati senza mostrare WebView, endpoint o log tecnici.
3. Il salvataggio chiama il backend locale autenticato.
4. `server.js` salva veicolo, targa, relazione utente-veicolo e dati accessori disponibili nel MySQL locale.
5. Il garage rilegge i dati dalle route esistenti.

## Gestione errori

- Backend irraggiungibile: messaggio applicativo comprensibile, senza URL o dettagli interni.
- MySQL non disponibile: health check non sano e log dettagliato soltanto sul Mac.
- JWT assente/scaduto: risposta `401`, rinnovo sessione tramite Supabase e nuovo tentativo secondo il comportamento esistente.
- iPhone fuori LAN: errore di connettività esplicito; nessun fallback verso il vecchio hosting.

## Verifica

La consegna sarà verificata con:

- avvio pulito di MySQL e inizializzazione completa dello schema;
- avvio di `server.js` e risposta positiva di `/api/v1/health`;
- registrazione di un nuovo account Supabase;
- chiamata autenticata dal simulatore;
- ricerca e salvataggio della targa di prova `FN841WA`;
- rilettura del veicolo nel garage;
- operazioni principali su profilo, pneumatici, analisi e manutenzione;
- prova equivalente da iPhone sulla stessa Wi-Fi;
- build e test Xcode esistenti;
- aggiornamento del grafo Graphify dopo le modifiche.

## Fuori ambito

- Accesso al backend da Internet o da reti differenti.
- Recupero degli account o dei dati del vecchio hosting.
- Sostituzione di Supabase con un servizio di autenticazione locale.
- Migrazione di `server.js` a PostgreSQL o SQLite.
- Nuove API o nuove funzionalità di prodotto.
