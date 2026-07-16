// Edge Function: Aggiornamento Stato Bollo Auto
// NUOVE FUNZIONALITÀ:
// 1. Notifiche GIORNALIERE per scadenze imminenti/scadute
// 2. Auto-refresh dati tramite license plate reader API
// 3. Stop notifiche solo al rinnovo/pagamento effettivo

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
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

const JOBS_SECRET = Deno.env.get('BACKGROUND_JOBS_SECRET') ?? ''

function isAuthorized(req: Request): boolean {
  if (!JOBS_SECRET) {
    console.error('❌ BACKGROUND_JOBS_SECRET non configurato')
    return false
  }

  const authHeader = req.headers.get('authorization')
  const cronHeader = req.headers.get('x-cron-secret')

  if (cronHeader === JOBS_SECRET) return true
  if (authHeader === `Bearer ${JOBS_SECRET}`) return true

  return false
}

interface NotificationPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, any>
  priority: 'low' | 'medium' | 'high' | 'critical'
  type: 'insurance' | 'bollo' | 'revision' | 'general'
}

// Chiama l'API per aggiornare i dati
async function refreshVehicleData(plate: string, userId: string): Promise<boolean> {
  try {
    console.log(`🔄 Auto-refresh dati per targa ${plate}...`)
    const url = `${BASE_API_URL}/v1/check_plate?plate=${encodeURIComponent(plate)}`
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${supabaseServiceKey}`,
        'Content-Type': 'application/json'
      }
    })

    if (response.ok) {
      console.log(`✅ Dati aggiornati per ${plate}`)
      return true
    }
    return false
  } catch (error) {
    console.error(`❌ Errore refresh ${plate}:`, error)
    return false
  }
}

async function logAutoRefresh(vehicleId: number, plate: string, success: boolean, error?: string) {
  await supabaseAdmin.from('auto_refresh_log').insert({
    vehicle_id: vehicleId,
    plate: plate,
    refresh_type: 'bollo_expired',
    refresh_date: new Date().toISOString(),
    success: success,
    error_message: error || null,
    data_updated: success
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST' || !isAuthorized(req)) {
    return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 401
    })
  }

  try {
    console.log('🔍 Controllo stato bollo + auto-refresh + notifiche giornaliere...')

    const { data: vehicles, error: fetchError } = await supabaseAdmin
      .from('vehicles')
      .select('*, plates!inner(id, plate, user_id, region_code)')
      .not('plates.plate', 'is', null)

    if (fetchError) {
      console.error('❌ Errore nel recupero veicoli:', fetchError)
      throw fetchError
    }

    console.log(`📋 Trovati ${vehicles?.length || 0} veicoli da controllare`)

    const now = new Date()
    const notifications: NotificationPayload[] = []
    let refreshedCount = 0
    let notifiedCount = 0

    for (const vehicle of vehicles || []) {
      try {
        const currentMonth = now.getMonth() + 1
        const currentYear = now.getFullYear()
        const bolloExpiryDate = new Date(currentYear, 11, 31) // 31 dicembre

        if (now > bolloExpiryDate) {
          bolloExpiryDate.setFullYear(currentYear + 1)
        }

        const daysUntilExpiry = Math.ceil((bolloExpiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

        console.log(`🚗 Veicolo ${vehicle.plates.plate}: bollo scade tra ${daysUntilExpiry} giorni`)

        // Calcola importo bollo
        let bolloAmount = 0
        if (vehicle.power_kw) {
          const powerKW = parseFloat(vehicle.power_kw)
          const emissionClass = vehicle.emission_class || 'EURO_0'

          const baseRates: { [key: string]: number } = {
            'EURO_0': 3.0, 'EURO_1': 2.9, 'EURO_2': 2.8, 'EURO_3': 2.7,
            'EURO_4': 2.58, 'EURO_5': 2.58, 'EURO_6': 2.58
          }

          const ratePerKW = baseRates[emissionClass] || 3.0

          if (powerKW <= 100) {
            bolloAmount = powerKW * ratePerKW
          } else {
            bolloAmount = (100 * ratePerKW) + ((powerKW - 100) * 4.50)
          }

          if (powerKW > 185) {
            const superBolloKW = powerKW - 185
            bolloAmount += superBolloKW * 20
          }

          bolloAmount = Math.round(bolloAmount * 100) / 100
        }

        // ========================================
        // AUTO-REFRESH: Se scaduto, aggiorna dati
        // ========================================
        if (daysUntilExpiry < 0) {
          console.log(`⚠️ Bollo SCADUTO per ${vehicle.plates.plate} - avvio auto-refresh...`)

          const refreshSuccess = await refreshVehicleData(
            vehicle.plates.plate,
            vehicle.plates.user_id
          )

          await logAutoRefresh(
            vehicle.id,
            vehicle.plates.plate,
            refreshSuccess,
            refreshSuccess ? undefined : 'Refresh failed'
          )

          if (refreshSuccess) {
            refreshedCount++
          }
        }

        // ========================================
        // NOTIFICHE GIORNALIERE
        // ========================================
        const { data: shouldNotify } = await supabaseAdmin
          .rpc('should_notify_today', {
            p_vehicle_id: vehicle.id,
            p_notification_type: 'bollo',
            p_expiry_date: bolloExpiryDate.toISOString()
          })

        if (!shouldNotify) {
          console.log(`⏭️ ${vehicle.plates.plate}: notifica già inviata oggi, skip`)
          continue
        }

        let shouldSendNotification = false
        let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
        let message = ''

        if (daysUntilExpiry < 0) {
          // Scaduto - notifica GIORNALIERA
          shouldSendNotification = true
          priority = 'critical'
          const daysOverdue = Math.abs(daysUntilExpiry)
          message = `⚠️ URGENTE: Il bollo auto per ${vehicle.plates.plate} è SCADUTO da ${daysOverdue} giorni! Paga subito €${bolloAmount.toFixed(2)} per evitare sanzioni.`
        } else if (daysUntilExpiry <= 7) {
          shouldSendNotification = true
          priority = 'critical'
          message = `🚨 Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni! Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 15) {
          shouldSendNotification = true
          priority = 'high'
          message = `⚠️ Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni. Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 30) {
          shouldSendNotification = true
          priority = 'medium'
          message = `📅 Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni. Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 60) {
          shouldSendNotification = true
          priority = 'low'
          message = `💡 Promemoria: il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni.`
        }

        if (shouldSendNotification && vehicle.plates.user_id) {
          notifications.push({
            user_id: vehicle.plates.user_id,
            title: 'Scadenza Bollo Auto',
            body: message,
            data: {
              plate: vehicle.plates.plate,
              expiry_date: bolloExpiryDate.toISOString(),
              days_until_expiry: daysUntilExpiry,
              amount: bolloAmount,
              make: vehicle.make,
              model: vehicle.model,
              power_kw: vehicle.power_kw,
              emission_class: vehicle.emission_class
            },
            priority,
            type: 'bollo'
          })

          await supabaseAdmin.rpc('track_notification', {
            p_user_id: vehicle.plates.user_id,
            p_vehicle_id: vehicle.id,
            p_plate: vehicle.plates.plate,
            p_notification_type: 'bollo',
            p_expiry_date: bolloExpiryDate.toISOString()
          })

          notifiedCount++
        }

        // Salva/aggiorna lo stato del bollo
        await supabaseAdmin
          .from('bollo_status')
          .upsert({
            vehicle_id: vehicle.id,
            plate_id: vehicle.plates.id,
            expiry_date: bolloExpiryDate.toISOString(),
            amount: bolloAmount,
            is_paid: false,
            last_checked: now.toISOString(),
            updated_at: now.toISOString()
          }, {
            onConflict: 'vehicle_id'
          })

      } catch (vehicleError) {
        console.error(`❌ Errore elaborazione veicolo ${vehicle.id}:`, vehicleError)
      }
    }

    // Invia notifiche
    for (const notification of notifications) {
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
    }

    const result = {
      success: true,
      checked: vehicles?.length || 0,
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
