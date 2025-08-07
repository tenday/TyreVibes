# TyreVibes

## Riguardo al Progetto

TyreVibes è un'applicazione iOS progettata per gli appassionati e i proprietari di auto per gestire i loro veicoli in un "Garage" digitale. Fornisce un'interfaccia fluida per tenere traccia dei dettagli e delle specifiche del veicolo. Il progetto è costruito con tecnologie moderne, con un focus su un'esperienza utente pulita e intuitiva.

## Funzionalità

*   **Autenticazione Utente:** Funzionalità di registrazione e accesso sicure tramite email/password, con opzioni per il social login tramite Google e Apple.
*   **Garage Veicoli:** Un luogo centralizzato per visualizzare e gestire tutti i tuoi veicoli.
*   **Aggiungi Nuovi Veicoli:** Aggiungi facilmente nuove auto al tuo garage.
*   **Scanner Targa:** Una funzione chiave che permette agli utenti di scansionare la targa di un veicolo per recuperare e compilare automaticamente i suoi dettagli.
*   **Inserimento Manuale dei Dati:** Opzione per inserire manualmente le informazioni del veicolo.

## Stack Tecnologico

*   **Frontend:** SwiftUI
*   **Backend:** [Supabase](https://supabase.io/) - Utilizzato per il database, l'autenticazione e altri servizi di backend.

## Come Iniziare

Per ottenere una copia locale funzionante, segui questi semplici passaggi.

### Prerequisiti

*   macOS con Xcode installato.
*   Potrebbe essere necessario un account sviluppatore Apple per alcune funzionalità.

### Installazione

1.  Clona il repository:
    ```sh
    git clone https://github.com/tuo_username/TyreVibes.git
    ```
2.  Apri il progetto in Xcode:
    ```sh
    open TyreVibes/TyreVibes.xcodeproj
    ```
3.  Xcode risolverà automaticamente le dipendenze di Swift Package Manager, incluso Supabase.
4.  Compila ed esegui il progetto su un simulatore o un dispositivo fisico.

## Stato del Progetto

Questo progetto è attualmente nelle prime fasi di sviluppo. Alcune funzionalità non sono completamente implementate e parti dell'interfaccia utente potrebbero utilizzare dati segnaposto.

> **Nota**
> L'interfaccia utente utilizza attualmente dati hardcoded per l'elenco delle auto nel Garage. La connessione a Supabase per il recupero dei dati dinamici deve ancora essere implementata.

## Nota sulla Sicurezza

La versione attuale dell'applicazione ha l'URL di Supabase e la chiave pubblica `anon` hardcoded nel file `SupabaseManager.swift`. Per la produzione, si consiglia vivamente di spostare queste chiavi in un file di configurazione sicuro (ad es. un file `.plist` che non viene inserito nel controllo di versione) o utilizzare variabili d'ambiente per evitare di esporle.
