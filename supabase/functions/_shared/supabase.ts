import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? 'https://jbcbrnegmqraivdfmlsn.supabase.co'
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

export const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
})

export interface VehicleInsurance {
  id: number
  plate_id: number
  rca_company?: string
  rca_policy_number?: string
  rca_expiry?: string
  rca_insurance_present?: number
  created_at?: string
  updated_at?: string
}

export interface VehicleRevision {
  id: number
  plate_id: number
  km_revisione?: string
  data_revisione?: string
  esito_revisione?: string
  created_at?: string
  updated_at?: string
}

export interface Vehicle {
  id: number
  user_id?: string
  plate?: string
  make?: string
  model?: string
  power_kw?: string
  fuel_type?: string
  emission_class?: string
  vin?: string
  created_at?: string
  updated_at?: string
}

export interface NotificationPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, any>
  priority: 'low' | 'medium' | 'high' | 'critical'
  type: 'insurance' | 'bollo' | 'revision' | 'general'
}
