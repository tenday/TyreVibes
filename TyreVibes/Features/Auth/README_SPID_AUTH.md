# Sistema di Autenticazione SPID tramite ACI - Versione Semplificata

Sistema di autenticazione SPID utilizzando il portale mobile di ACI (Automobile Club d'Italia) - Bollonet.

## 🔑 URL di Login

```
https://login.aci.it/index.php/?do=loginSpidMobile&application_key=bollonet&purl=
```

Quando l'utente preme "Accedi con SPID", si apre direttamente questa pagina nella WebView.

## 🔄 Flusso

1. Utente preme "Accedi con SPID"
2. Si apre WebView con URL di login
3. Utente sceglie provider SPID e inserisce credenziali
4. WebView intercetta automaticamente i cookie di sessione
5. Cookie salvati, autenticazione completata

## 💻 Utilizzo

```swift
@State private var showAuth = false

Button("Accedi con SPID") {
    showAuth = true
}
.fullScreenCover(isPresented: $showAuth) {
    ACISPIDAuthScreen()
}
```

## 🍪 Cookie

Dopo l'autenticazione, i cookie sono disponibili in:

```swift
let cookies = ACISPIDAuthService.shared.getAuthCookies()
```

**BUILD SUCCEEDED** ✅
