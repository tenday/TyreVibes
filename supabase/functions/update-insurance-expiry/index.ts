// Edge Function: Aggiornamento Scadenze Assicurazioni
// NUOVE FUNZIONALITÀ:
// 1. Notifiche GIORNALIERE per scadenze imminenti/scadute
// 2. Auto-refresh dati tramite license plate reader API
// 3. Stop notifiche solo al rinnovo effettivo

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'https://jbcbrnegmqraivdfmlsn.supabase.co'
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

const BASE_API_URL = 'https://www.tyrevibes.com/api'

interface NotificationPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, any>
  priority: 'low' | 'medium' | 'high' | 'critical'
  type: 'insurance' | 'bollo' | 'revision' | 'general'
}

// Chiama l'API di license plate check per aggiornare i dati
async function refreshVehicleData(plate: string, userId: string): Promise<boolean> {
  try {
    console.log(`🔄 Auto-refresh dati per targa ${plate}...`)

    const url = `${BASE_API_URL}/v1/check_plate?plate=${encodeURIComponent(plate)}`

    // Usa la service role key per autenticarsi
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json'
      }
    })

    if (response.ok) {
      const data = await response.json()
      console.log(`✅ Dati aggiornati per ${plate}:`, data)
      return true
    } else if (response.status === 404) {
      console.log(`⚠️ Targa ${plate} non trovata nell'API`)
      return false
    } else {
      console.error(`❌ Errore refresh ${plate}: ${response.status}`)
      return false
    }
  } catch (error) {
    console.error(`❌ Errore chiamata API per ${plate}:`, error)
    return false
  }
}

// Registra il refresh nel log
async function logAutoRefresh(vehicleId: number, plate: string, success: boolean, error?: string) {
  await supabaseAdmin.from('auto_refresh_log').insert({
    vehicle_id: vehicleId,
    plate: plate,
    refresh_type: 'insurance_expired',
    refresh_date: new Date().toISOString(),
    success: success,
    error_message: error || null,
    data_updated: success
  })
}

serve(async (req) => {
  // Gestione CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔍 Controllo scadenze assicurazioni + auto-refresh + notifiche giornaliere...')

    // Recupera tutte le assicurazioni con data di scadenza
    const { data: insurances, error: fetchError } = await supabaseAdmin
      .from('vehicle_insurances')
      .select('*, vehicles!inner(id, plate, user_id, make, model)')
      .not('rca_expiry', 'is', null)

    if (fetchError) {
      console.error('❌ Errore nel recupero assicurazioni:', fetchError)
      throw fetchError
    }

    console.log(`📋 Trovate ${insurances?.length || 0} assicurazioni da controllare`)

    const now = new Date()
    const notifications: NotificationPayload[] = []
    let refreshedCount = 0
    let notifiedCount = 0

    for (const insurance of insurances || []) {
      const expiryDate = new Date(insurance.rca_expiry)
      const daysUntilExpiry = Math.ceil((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

      console.log(`🚗 Veicolo ${insurance.vehicles.plate}: scadenza tra ${daysUntilExpiry} giorni`)

      // ========================================
      // AUTO-REFRESH: Se scaduta, aggiorna dati
      // ========================================
      if (daysUntilExpiry < 0) {
        console.log(`⚠️ Assicurazione SCADUTA per ${insurance.vehicles.plate} - avvio auto-refresh...`)

        const refreshSuccess = await refreshVehicleData(
          insurance.vehicles.plate,
          insurance.vehicles.user_id
        )

        await logAutoRefresh(
          insurance.vehicles.id,
          insurance.vehicles.plate,
          refreshSuccess,
          refreshSuccess ? undefined : 'Refresh failed'
        )

        if (refreshSuccess) {
          refreshedCount++
          console.log(`✅ Dati aggiornati per ${insurance.vehicles.plate}`)

          // Se i dati sono stati aggiornati, ricontrolla se è ancora scaduta
          // (in produzione, dovresti rifare il fetch dal DB per vedere i nuovi dati)
        }
      }

      // ========================================
      // NOTIFICHE GIORNALIERE
      // ========================================

      // Verifica se deve notificare oggi usando la funzione SQL
      const { data: shouldNotify } = await supabaseAdmin
        .rpc('should_notify_today', {
          p_vehicle_id: insurance.vehicles.id,
          p_notification_type: 'insurance',
          p_expiry_date: expiryDate.toISOString()
        })

      if (!shouldNotify) {
        console.log(`⏭️ ${insurance.vehicles.plate}: notifica già inviata oggi, skip`)
        continue
      }

      // Determina se inviare notifica in base ai giorni rimanenti
      let shouldSendNotification = false
      let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
      let message = ''

      if (daysUntilExpiry < 0) {
        // Scaduta - notifica GIORNALIERA
        shouldSendNotification = true
        priority = 'critical'
        const daysOverdue = Math.abs(daysUntilExpiry)
        message = `⚠️ URGENTE: La tua assicurazione RCA per ${insurance.vehicles.plate} è SCADUTA da ${daysOverdue} giorni! Rinnovala immediatamente per evitare sanzioni.`
      } else if (daysUntilExpiry <= 7) {
        // Scade entro 7 giorni - notifica GIORNALIERA
        shouldSendNotification = true
        priority = 'critical'
        message = `🚨 La tua assicurazione RCA per ${insurance.vehicles.plate} scade tra ${daysUntilExpiry} giorni! Rinnovala subito.`
      } else if (daysUntilExpiry <= 15) {
        // Scade entro 15 giorni - notifica giornaliera
        shouldSendNotification = true
        priority = 'high'
        message = `⚠️ La tua assicurazione RCA per ${insurance.vehicles.plate} scade tra ${daysUntilExpiry} giorni. Ricordati di rinnovarla!`
      } else if (daysUntilExpiry <= 30) {
        // Scade entro 30 giorni - prima notifica, poi stop fino a 15 giorni
        shouldSendNotification = true
        priority = 'medium'
        message = `📅 La tua assicurazione RCA per ${insurance.vehicles.plate} scade tra ${daysUntilExpiry} giorni.`
      }

      if (shouldSendNotification && insurance.vehicles.user_id) {
        // Crea notifica
        notifications.push({
          user_id: insurance.vehicles.user_id,
          title: 'Scadenza Assicurazione RCA',
          body: message,
          data: {
            plate: insurance.vehicles.plate,
            expiry_date: insurance.rca_expiry,
            days_until_expiry: daysUntilExpiry,
            insurance_company: insurance.rca_company,
            policy_number: insurance.rca_policy_number,
            make: insurance.vehicles.make,
            model: insurance.vehicles.model
          },
          priority,
          type: 'insurance'
        })

        // Traccia la notifica nel DB
        await supabaseAdmin.rpc('track_notification', {
          p_user_id: insurance.vehicles.user_id,
          p_vehicle_id: insurance.vehicles.id,
          p_plate: insurance.vehicles.plate,
          p_notification_type: 'insurance',
          p_expiry_date: expiryDate.toISOString()
        })

        notifiedCount++
        console.log(`📲 Notifica schedulata per ${insurance.vehicles.plate}`)
      }

      // Aggiorna il campo updated_at
      await supabaseAdmin
        .from('vehicle_insurances')
        .update({ updated_at: now.toISOString() })
        .eq('id', insurance.id)
    }

    // Invia le notifiche al database
    if (notifications.length > 0) {
      console.log(`📲 Salvando ${notifications.length} notifiche...`)

      for (const notification of notifications) {
        // Salva la notifica nel database
        await supabaseAdmin.from('notifications').insert({
          user_id: notification.user_id,
          title: notification.title,
          body: notification.body,
          data: notification.data,
          priority: notification.priority,
          type: notification.type,
          read: false,
          created_at: now.toISOString()
        })

        // Recupera i device tokens dell'utente per inviare push notification
        const { data: deviceTokens } = await supabaseAdmin
          .from('device_tokens')
          .select('token, platform')
          .eq('user_id', notification.user_id)
          .eq('active', true)

        if (deviceTokens && deviceTokens.length > 0) {
          console.log(`📱 Trovati ${deviceTokens.length} dispositivi per utente ${notification.user_id}`)
          // TODO: Integrare con servizio push notification (FCM/APNS)
        }
      }
    }

    const result = {
      success: true,
      checked: insurances?.length || 0,
      refreshed: refreshedCount,
      notifications_sent: notifiedCount,
      timestamp: now.toISOString(),
      message: `✅ ${notifiedCount} notifiche giornaliere inviate, ${refreshedCount} veicoli aggiornati via API`
    }

    console.log('✅ Job completato:', result)

    return new Response(
      JSON.stringify(result),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Errore nel job:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500
      }
    )
  }
})
