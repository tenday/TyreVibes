// Edge Function: Aggiornamento Stato Bollo Auto
// Controlla lo stato del pagamento del bollo auto e invia notifiche

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { supabaseAdmin, Vehicle, NotificationPayload } from '../_shared/supabase.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface BolloData {
  isPaid: boolean
  amount?: number
  expiryDate?: string
  isExpired: boolean
  paymentDeadline?: string
  vehicleType?: string
}

serve(async (req) => {
  // Gestione CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔍 Controllo stato bollo auto...')

    // Recupera tutti i veicoli con targa
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
    const updatePromises: Promise<any>[] = []
    let checkedCount = 0
    let errorCount = 0

    for (const vehicle of vehicles || []) {
      try {
        // Calcola la scadenza del bollo (generalmente annuale)
        // Il bollo scade l'ultimo giorno del mese successivo alla scadenza precedente
        const currentMonth = now.getMonth() + 1
        const currentYear = now.getFullYear()

        // Per semplicità, assumiamo scadenza a dicembre di ogni anno
        // In produzione, dovremmo recuperare la data effettiva dal database
        const bolloExpiryDate = new Date(currentYear, 11, 31) // 31 dicembre

        // Se siamo già oltre dicembre, la scadenza è per l'anno prossimo
        if (now > bolloExpiryDate) {
          bolloExpiryDate.setFullYear(currentYear + 1)
        }

        const daysUntilExpiry = Math.ceil((bolloExpiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

        console.log(`🚗 Veicolo ${vehicle.plates.plate}: bollo scade tra ${daysUntilExpiry} giorni`)

        // Calcola importo bollo (usa il BolloCalculator esistente)
        let bolloAmount = 0
        if (vehicle.power_kw) {
          const powerKW = parseFloat(vehicle.power_kw)
          const emissionClass = vehicle.emission_class || 'EURO_0'

          // Tariffe base semplificate (in produzione usare BolloCalculator.swift)
          const baseRates: { [key: string]: number } = {
            'EURO_0': 3.0,
            'EURO_1': 2.9,
            'EURO_2': 2.8,
            'EURO_3': 2.7,
            'EURO_4': 2.58,
            'EURO_5': 2.58,
            'EURO_6': 2.58
          }

          const ratePerKW = baseRates[emissionClass] || 3.0

          // Calcolo base: potenza * tariffa
          if (powerKW <= 100) {
            bolloAmount = powerKW * ratePerKW
          } else {
            bolloAmount = (100 * ratePerKW) + ((powerKW - 100) * 4.50)
          }

          // Superbollo per potenza > 185 KW
          if (powerKW > 185) {
            const superBolloKW = powerKW - 185
            bolloAmount += superBolloKW * 20
          }

          bolloAmount = Math.round(bolloAmount * 100) / 100
        }

        // Determina se inviare notifica
        let shouldNotify = false
        let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
        let message = ''

        if (daysUntilExpiry < 0) {
          // Bollo scaduto
          shouldNotify = true
          priority = 'critical'
          message = `⚠️ Il bollo auto per ${vehicle.plates.plate} è SCADUTO! Importo da pagare: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 7) {
          shouldNotify = true
          priority = 'critical'
          message = `🚨 Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni! Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 15) {
          shouldNotify = true
          priority = 'high'
          message = `⚠️ Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni. Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 30) {
          shouldNotify = true
          priority = 'medium'
          message = `📅 Il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni. Importo: €${bolloAmount.toFixed(2)}`
        } else if (daysUntilExpiry <= 60) {
          shouldNotify = true
          priority = 'low'
          message = `💡 Promemoria: il bollo auto per ${vehicle.plates.plate} scade tra ${daysUntilExpiry} giorni.`
        }

        if (shouldNotify && vehicle.plates.user_id) {
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
        }

        // Salva/aggiorna lo stato del bollo nel database
        const { error: upsertError } = await supabaseAdmin
          .from('bollo_status')
          .upsert({
            vehicle_id: vehicle.id,
            plate_id: vehicle.plates.id,
            expiry_date: bolloExpiryDate.toISOString(),
            amount: bolloAmount,
            is_paid: false, // Impostare in base a verifica API ACI se disponibile
            last_checked: now.toISOString(),
            updated_at: now.toISOString()
          }, {
            onConflict: 'vehicle_id'
          })

        if (upsertError) {
          console.warn(`⚠️ Errore aggiornamento bollo per ${vehicle.plates.plate}:`, upsertError.message)
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
