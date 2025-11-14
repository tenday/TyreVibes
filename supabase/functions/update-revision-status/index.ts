// Edge Function: Aggiornamento Stato Revisioni
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

function calculateNextRevisionDate(lastRevisionDate: Date, vehicleAge: number, isCommercial: boolean = false): Date {
  const nextRevision = new Date(lastRevisionDate)

  if (vehicleAge <= 4) {
    nextRevision.setFullYear(nextRevision.getFullYear() + 4)
  } else if (isCommercial) {
    nextRevision.setFullYear(nextRevision.getFullYear() + 1)
  } else {
    nextRevision.setFullYear(nextRevision.getFullYear() + 2)
  }

  nextRevision.setMonth(nextRevision.getMonth() + 1, 0)
  return nextRevision
}

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
    refresh_type: 'revision_expired',
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

  try {
    console.log('🔍 Controllo scadenze revisioni + auto-refresh + notifiche giornaliere...')

    const { data: vehicles, error: fetchError } = await supabaseAdmin
      .from('vehicles')
      .select(`
        *,
        plates!inner(id, plate, user_id, registration_date),
        vehicle_revisions(id, plate_id, data_revisione, km_revisione, esito_revisione)
      `)
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
        let lastRevisionDate: Date | null = null
        let lastRevisionKm: string | null = null

        if (vehicle.vehicle_revisions && vehicle.vehicle_revisions.length > 0) {
          const sortedRevisions = vehicle.vehicle_revisions
            .filter((r: any) => r.data_revisione)
            .sort((a: any, b: any) => {
              return new Date(b.data_revisione).getTime() - new Date(a.data_revisione).getTime()
            })

          if (sortedRevisions.length > 0) {
            lastRevisionDate = new Date(sortedRevisions[0].data_revisione)
            lastRevisionKm = sortedRevisions[0].km_revisione
          }
        }

        if (!lastRevisionDate && vehicle.plates.registration_date) {
          lastRevisionDate = new Date(vehicle.plates.registration_date)
        }

        if (!lastRevisionDate) {
          console.warn(`⚠️ Nessuna data disponibile per ${vehicle.plates.plate}`)
          continue
        }

        const vehicleAge = now.getFullYear() - lastRevisionDate.getFullYear()
        const isCommercial = vehicle.vehicle_type === 'commercial' ||
                            vehicle.use === 'COMMERCIALE' ||
                            vehicle.category?.includes('N')

        const nextRevisionDate = calculateNextRevisionDate(lastRevisionDate, vehicleAge, isCommercial)
        const daysUntilRevision = Math.ceil((nextRevisionDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

        console.log(`🚗 Veicolo ${vehicle.plates.plate}: revisione tra ${daysUntilRevision} giorni`)

        // ========================================
        // AUTO-REFRESH: Se scaduta, aggiorna dati
        // ========================================
        if (daysUntilRevision < 0) {
          console.log(`⚠️ Revisione SCADUTA per ${vehicle.plates.plate} - avvio auto-refresh...`)

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
            p_notification_type: 'revision',
            p_expiry_date: nextRevisionDate.toISOString()
          })

        if (!shouldNotify) {
          console.log(`⏭️ ${vehicle.plates.plate}: notifica già inviata oggi, skip`)
          continue
        }

        let shouldSendNotification = false
        let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
        let message = ''

        if (daysUntilRevision < 0) {
          // Scaduta - notifica GIORNALIERA
          shouldSendNotification = true
          priority = 'critical'
          const daysOverdue = Math.abs(daysUntilRevision)
          message = `⚠️ URGENTE: La revisione per ${vehicle.plates.plate} è SCADUTA da ${daysOverdue} giorni! Prenota immediatamente per evitare sanzioni.`
        } else if (daysUntilRevision <= 7) {
          shouldSendNotification = true
          priority = 'critical'
          message = `🚨 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni! Prenota urgentemente.`
        } else if (daysUntilRevision <= 15) {
          shouldSendNotification = true
          priority = 'high'
          message = `⚠️ La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni. Prenota al più presto.`
        } else if (daysUntilRevision <= 30) {
          shouldSendNotification = true
          priority = 'high'
          message = `📅 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni. Ricordati di prenotare!`
        } else if (daysUntilRevision <= 60) {
          shouldSendNotification = true
          priority = 'medium'
          message = `💡 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni (${nextRevisionDate.toLocaleDateString('it-IT')}).`
        }

        if (shouldSendNotification && vehicle.plates.user_id) {
          notifications.push({
            user_id: vehicle.plates.user_id,
            title: 'Scadenza Revisione Periodica',
            body: message,
            data: {
              plate: vehicle.plates.plate,
              next_revision_date: nextRevisionDate.toISOString(),
              days_until_revision: daysUntilRevision,
              last_revision_date: lastRevisionDate.toISOString(),
              last_revision_km: lastRevisionKm,
              vehicle_age: vehicleAge,
              is_commercial: isCommercial,
              make: vehicle.make,
              model: vehicle.model
            },
            priority,
            type: 'revision'
          })

          await supabaseAdmin.rpc('track_notification', {
            p_user_id: vehicle.plates.user_id,
            p_vehicle_id: vehicle.id,
            p_plate: vehicle.plates.plate,
            p_notification_type: 'revision',
            p_expiry_date: nextRevisionDate.toISOString()
          })

          notifiedCount++
        }

        // Salva/aggiorna lo stato della revisione
        await supabaseAdmin
          .from('revision_status')
          .upsert({
            vehicle_id: vehicle.id,
            plate_id: vehicle.plates.id,
            last_revision_date: lastRevisionDate.toISOString(),
            next_revision_date: nextRevisionDate.toISOString(),
            last_revision_km: lastRevisionKm,
            is_expired: daysUntilRevision < 0,
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
