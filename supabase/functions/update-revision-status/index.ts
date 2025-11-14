// Edge Function: Aggiornamento Stato Revisioni
// Controlla le scadenze delle revisioni periodiche e invia notifiche

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { supabaseAdmin, VehicleRevision, NotificationPayload } from '../_shared/supabase.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Calcola la prossima scadenza revisione
 * - Prima revisione: dopo 4 anni dalla prima immatricolazione
 * - Successive: ogni 2 anni per auto, ogni anno per veicoli commerciali
 */
function calculateNextRevisionDate(lastRevisionDate: Date, vehicleAge: number, isCommercial: boolean = false): Date {
  const nextRevision = new Date(lastRevisionDate)

  if (vehicleAge <= 4) {
    // Prima revisione dopo 4 anni
    nextRevision.setFullYear(nextRevision.getFullYear() + 4)
  } else if (isCommercial) {
    // Veicoli commerciali: revisione annuale
    nextRevision.setFullYear(nextRevision.getFullYear() + 1)
  } else {
    // Auto private: revisione ogni 2 anni
    nextRevision.setFullYear(nextRevision.getFullYear() + 2)
  }

  // La revisione scade l'ultimo giorno del mese
  nextRevision.setMonth(nextRevision.getMonth() + 1, 0)

  return nextRevision
}

serve(async (req) => {
  // Gestione CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔍 Controllo scadenze revisioni...')

    // Recupera tutti i veicoli con le loro revisioni
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
    let checkedCount = 0
    let errorCount = 0

    for (const vehicle of vehicles || []) {
      try {
        // Determina la data dell'ultima revisione
        let lastRevisionDate: Date | null = null
        let lastRevisionKm: string | null = null

        if (vehicle.vehicle_revisions && vehicle.vehicle_revisions.length > 0) {
          // Ordina per data più recente
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

        // Se non c'è revisione, usa la data di immatricolazione
        if (!lastRevisionDate && vehicle.plates.registration_date) {
          lastRevisionDate = new Date(vehicle.plates.registration_date)
        }

        if (!lastRevisionDate) {
          console.warn(`⚠️ Nessuna data disponibile per ${vehicle.plates.plate}`)
          continue
        }

        // Calcola l'età del veicolo
        const vehicleAge = now.getFullYear() - lastRevisionDate.getFullYear()

        // Determina se è veicolo commerciale
        const isCommercial = vehicle.vehicle_type === 'commercial' ||
                            vehicle.use === 'COMMERCIALE' ||
                            vehicle.category?.includes('N')

        // Calcola prossima scadenza
        const nextRevisionDate = calculateNextRevisionDate(lastRevisionDate, vehicleAge, isCommercial)
        const daysUntilRevision = Math.ceil((nextRevisionDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

        console.log(`🚗 Veicolo ${vehicle.plates.plate}: revisione tra ${daysUntilRevision} giorni (${nextRevisionDate.toLocaleDateString('it-IT')})`)

        // Determina se inviare notifica
        let shouldNotify = false
        let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
        let message = ''

        if (daysUntilRevision < 0) {
          // Revisione scaduta
          shouldNotify = true
          priority = 'critical'
          const daysOverdue = Math.abs(daysUntilRevision)
          message = `⚠️ La revisione per ${vehicle.plates.plate} è SCADUTA da ${daysOverdue} giorni! Prenota subito.`
        } else if (daysUntilRevision <= 7) {
          shouldNotify = true
          priority = 'critical'
          message = `🚨 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni! Prenota urgentemente.`
        } else if (daysUntilRevision <= 15) {
          shouldNotify = true
          priority = 'high'
          message = `⚠️ La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni. Prenota al più presto.`
        } else if (daysUntilRevision <= 30) {
          shouldNotify = true
          priority = 'high'
          message = `📅 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni. Ricordati di prenotare!`
        } else if (daysUntilRevision <= 60) {
          shouldNotify = true
          priority = 'medium'
          message = `💡 La revisione per ${vehicle.plates.plate} scade tra ${daysUntilRevision} giorni (${nextRevisionDate.toLocaleDateString('it-IT')}).`
        }

        if (shouldNotify && vehicle.plates.user_id) {
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
        }

        // Salva/aggiorna lo stato della revisione nel database
        const { error: upsertError } = await supabaseAdmin
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

        if (upsertError) {
          console.warn(`⚠️ Errore aggiornamento revisione per ${vehicle.plates.plate}:`, upsertError.message)
        }

        checkedCount++

      } catch (vehicleError) {
        console.error(`❌ Errore elaborazione veicolo ${vehicle.id}:`, vehicleError)
        errorCount++
      }
    }

    // Invia le notifiche
    if (notifications.length > 0) {
      console.log(`📲 Invio ${notifications.length} notifiche...`)

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

        // Recupera i device tokens dell'utente
        const { data: deviceTokens } = await supabaseAdmin
          .from('device_tokens')
          .select('token, platform')
          .eq('user_id', notification.user_id)
          .eq('active', true)

        if (deviceTokens && deviceTokens.length > 0) {
          console.log(`📱 Trovati ${deviceTokens.length} dispositivi per utente ${notification.user_id}`)
          // TODO: Integrare con FCM/APNS
        }
      }
    }

    const result = {
      success: true,
      checked: checkedCount,
      errors: errorCount,
      notifications_sent: notifications.length,
      timestamp: now.toISOString()
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
