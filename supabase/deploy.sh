#!/bin/bash

# Script di deployment per le Supabase Edge Functions
# Autore: Claude Code
# Descrizione: Deploy automatico di tutte le Edge Functions per TyreVibes

set -e  # Exit on error

echo "🚀 Deployment Supabase Edge Functions per TyreVibes"
echo "=================================================="

# Verifica che Supabase CLI sia installato
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI non trovato!"
    echo "📦 Installa con: npm install -g supabase"
    exit 1
fi

echo "✅ Supabase CLI trovato"

# Verifica login
echo "🔐 Verifica autenticazione Supabase..."
if ! supabase projects list &> /dev/null; then
    echo "❌ Non sei autenticato!"
    echo "🔑 Esegui: supabase login"
    exit 1
fi

echo "✅ Autenticazione verificata"

# Link al progetto
PROJECT_REF="jbcbrnegmqraivdfmlsn"
echo "🔗 Link al progetto $PROJECT_REF..."
supabase link --project-ref $PROJECT_REF

# Lista delle funzioni da deployare
FUNCTIONS=(
    "update-insurance-expiry"
    "update-bollo-status"
    "update-revision-status"
    "run-all-jobs"
)

echo ""
echo "📦 Funzioni da deployare:"
for func in "${FUNCTIONS[@]}"; do
    echo "  - $func"
done
echo ""

# Deploy di ogni funzione
for func in "${FUNCTIONS[@]}"; do
    echo "🚀 Deploy di $func..."
    supabase functions deploy $func --no-verify-jwt

    if [ $? -eq 0 ]; then
        echo "✅ $func deployata con successo"
    else
        echo "❌ Errore nel deploy di $func"
        exit 1
    fi
    echo ""
done

echo "=================================================="
echo "✅ Tutte le funzioni sono state deployate con successo!"
echo ""
echo "📋 Prossimi passi:"
echo "  1. Configura i job schedulati nel database (vedi cron-schedule.md)"
echo "  2. Verifica le variabili d'ambiente in Supabase Dashboard"
echo "  3. Testa le funzioni manualmente"
echo ""
echo "🧪 Test rapido:"
echo "  curl -X POST https://jbcbrnegmqraivdfmlsn.supabase.co/functions/v1/run-all-jobs \\"
echo "    -H 'Authorization: Bearer YOUR_ANON_KEY' \\"
echo "    -H 'Content-Type: application/json'"
echo ""
