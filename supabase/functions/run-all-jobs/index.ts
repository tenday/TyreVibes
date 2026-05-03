// Edge Function: Orchestrazione di tutti i job di background
// Esegue tutti i job di aggiornamento in sequenza

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? 'https://jbcbrnegmqraivdfmlsn.supabase.co'
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

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

async function runJob(jobName: string): Promise<any> {
  console.log(`🚀 Esecuzione job: ${jobName}`)

  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/${jobName}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
        'x-cron-secret': JOBS_SECRET
      }
    })

    const result = await response.json()
    console.log(`✅ Job ${jobName} completato:`, result)

    return {
      job: jobName,
      success: response.ok,
      result
    }
  } catch (error) {
    console.error(`❌ Errore job ${jobName}:`, error)
    return {
      job: jobName,
      success: false,
      error: error.message
    }
  }
}

serve(async (req) => {
  // Gestione CORS
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
    const startTime = Date.now()
    console.log('🎯 Inizio esecuzione di tutti i job background...')

    // Lista dei job da eseguire
    const jobs = [
      'update-insurance-expiry',
      'update-bollo-status',
      'update-revision-status'
    ]

    // Esegui tutti i job in parallelo per massimizzare performance
    const results = await Promise.all(
      jobs.map(job => runJob(job))
    )

    const endTime = Date.now()
    const duration = endTime - startTime

    // Calcola statistiche
    const totalSuccess = results.filter(r => r.success).length
    const totalErrors = results.filter(r => !r.success).length

    const summary = {
      success: true,
      jobs_executed: jobs.length,
      jobs_successful: totalSuccess,
      jobs_failed: totalErrors,
      duration_ms: duration,
      timestamp: new Date().toISOString(),
      results
    }

    console.log('✅ Tutti i job completati:', summary)

    return new Response(
      JSON.stringify(summary),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error) {
    console.error('❌ Errore nell\'orchestrazione dei job:', error)
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
