# Alibaba SecNeo / Blue Shield Setup (TyreVibes)

Questa repository ora include:
- `Podfile` per mPaaS 10.2.3 + `mPaaS_BlueShield`
- switch Obj-C richiesto da Alibaba: `TyreVibes/Core/Security/MPSignatureInterface+BlueShieldSwitch.m`
- integrazione header lato app (`SecNeoSecurityService`) + verifica lato backend (`server.js`)

## 1) Prerequisiti locali

Installa CocoaPods e plugin mPaaS:

```bash
sudo gem install cocoapods
```

Installa/aggiorna il plugin mPaaS ufficiale (canale standard):

```bash
sh <(curl -s http://mpaas-ios.oss-cn-hangzhou.aliyuncs.com/cocoapods/installmPaaSCocoaPodsPlugin.sh)
```

Per baseline 10.2.3 con funzionalita beta/custom (consigliato per workflow Blue Shield avanzato):

```bash
sh <(curl -s http://mpaas-ios-test.oss-cn-hangzhou.aliyuncs.com/cocoapods/installmPaaSCocoaPodsPlugin.sh)
```

Verifica:

```bash
pod --version
pod plugins installed
pod mpaas version --plugin
```

## 2) Baseline mPaaS

Nel root progetto:

```bash
pod mpaas update baseline --all-versions
```

Poi avvia install:

```bash
pod install
```

Apri il workspace generato:

```bash
open TyreVibes.xcworkspace
```

## 3) Configurazione Blue Shield (console Alibaba)

1. In console mPaaS configura Blue Shield e scarica il file di configurazione.
2. Rinominare in `.config` (se richiesto dalla tua baseline) e inserirlo nella root iOS/progetto secondo guida mPaaS.
3. Verifica che in Podfile sia presente `mPaaS_pod "mPaaS_BlueShield"` e NON `mPaaS_Security`.

## 4) Config app TyreVibes (`Api.plist`)

Chiavi già presenti:
- `SECNEO_ENABLED`
- `SECNEO_APP_KEY`
- `SECNEO_TOKEN`
- `SECNEO_SHARED_SECRET`

Per attivare end-to-end:
- `SECNEO_ENABLED = true`
- compila con token/secret reali solo in configurazioni sicure (non committare segreti di produzione in chiaro).

## 5) Config backend (`server.js`)

Variabili supportate:
- `SECNEO_ENABLED`
- `SECNEO_STRICT`
- `SECNEO_ALLOWED_APP_KEYS`
- `SECNEO_ALLOWED_TOKENS`
- `SECNEO_SHARED_SECRET`
- `SECNEO_VERIFY_URL`
- `SECNEO_VERIFY_TIMEOUT_MS`

Suggerimento rollout:
- start con `SECNEO_ENABLED=true` e `SECNEO_STRICT=false` (monitor warning)
- poi passa a `SECNEO_STRICT=true` quando i token sono stabilizzati.

## 6) Verifica rapida

1. `node --check server.js`
2. Build iOS da workspace (`TyreVibes.xcworkspace`)
3. Chiamata API autenticata: verifica header `X-SecNeo-*` e log backend `[SECNEO]`.

## Note

- In questo ambiente il comando `pod` non era disponibile, quindi `pod install` non è stato eseguito qui.
- Lo switch Obj-C è protetto con `__has_include`, quindi non rompe la build se il framework non è ancora installato.
