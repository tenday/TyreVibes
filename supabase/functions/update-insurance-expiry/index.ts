// Edge Function: Aggiornamento Scadenze Assicurazioni
// Controlla le scadenze delle assicurazioni RCA e invia notifiche

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { supabaseAdmin, VehicleInsurance, NotificationPayload } from '../_shared/supabase.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Gestione CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔍 Controllo scadenze assicurazioni...')

    // Recupera tutte le assicurazioni con data di scadenza
    const { data: insurances, error: fetchError } = await supabaseAdmin
      .from('vehicle_insurances')
      .select('*, plates!inner(id, plate, user_id)')
      .not('rca_expiry', 'is', null)

    if (fetchError) {
      console.error('❌ Errore nel recupero assicurazioni:', fetchError)
      throw fetchError
    }

    console.log(`📋 Trovate ${insurances?.length || 0} assicurazioni da controllare`)

    const now = new Date()
    const notifications: NotificationPayload[] = []
    const updatePromises: Promise<any>[] = []

    for (const insurance of insurances || []) {
      const expiryDate = new Date(insurance.rca_expiry)
      const daysUntilExpiry = Math.ceil((expiryDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))

      console.log(`🚗 Veicolo ${insurance.plates.plate}: scadenza tra ${daysUntilExpiry} giorni`)

      // Determina se inviare notifica in base ai giorni rimanenti
      let shouldNotify = false
      let priority: 'low' | 'medium' | 'high' | 'critical' = 'low'
      let message = ''

      if (daysUntilExpiry < 0) {
        // Scaduta
        shouldNotify = true
        priority = 'critical'
        message = `⚠️ La tua assicurazione RCA per ${insurance.plates.plate} è SCADUTA! Rinnovala immediatamente.`
      } else if (daysUntilExpiry <= 7) {
        // Scade entro 7 giorni
        shouldNotify = true
        priority = 'critical'
        message = `🚨 La tua assicurazione RCA per ${insurance.plates.plate} scade tra ${daysUntilExpiry} giorni!`
      } else if (daysUntilExpiry <= 15) {
        // Scade entro 15 giorni
        shouldNotify = true
        priority = 'high'
        message = `⚠️ La tua assicurazione RCA per ${insurance.plates.plate} scade tra ${daysUntilExpiry} giorni. Ricordati di rinnovarla!`
      } else if (daysUntilExpiry <= 30) {
        // Scade entro 30 giorni
        shouldNotify = true
        priority = 'medium'
        message = `📅 La tua assicurazione RCA per ${insurance.plates.plate} scade tra ${daysUntilExpiry} giorni.`
      }

      if (shouldNotify && insurance.plates.user_id) {
        notifications.push({
          user_id: insurance.plates.user_id,
          title: 'Scadenza Assicurazione RCA',
          body: message,
          data: {
            plate: insurance.plates.plate,
            expiry_date: insurance.rca_expiry,
            days_until_expiry: daysUntilExpiry,
            insurance_company: insurance.rca_company,
            policy_number: insurance.rca_policy_number
          },
          priority,
          type: 'insurance'
        })
      }

      // Aggiorna il campo updated_at
      updatePromises.push(
        supabaseAdmin
          .from('vehicle_insurances')
          .update({ updated_at: now.toISOString() })
          .eq('id', insurance.id)
      )
    }

    // Esegui tutti gli aggiornamenti
    await Promise.all(updatePromises)
    console.log(`✅ Aggiornati ${updatePromises.length} record`)

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

        // Recupera i device tokens dell'utente per inviare push notification
        const { data: deviceTokens } = await supabaseAdmin
          .from('device_tokens')
          .select('token, platform')
          .eq('user_id', notification.user_id)
          .eq('active', true)

        if (deviceTokens && deviceTokens.length > 0) {
          console.log(`📱 Trovati ${deviceTokens.length} dispositivi per utente ${notification.user_id}`)

          // TODO: Integrare con servizio push notification (FCM/APNS)
          // Per ora salviamo solo nel DB, il client recupererà le notifiche
        }
      }
    }

    const result = {
      success: true,
      checked: insurances?.length || 0,
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
