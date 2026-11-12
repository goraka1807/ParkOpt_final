import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { validateBookingPassRequest } from '../shared/validation.mjs'

const allowedOrigins = (Deno.env.get('CORS_ALLOWED_ORIGINS') ?? 'http://localhost:5173,https://localhost:5173').split(',').map((origin) => origin.trim()).filter(Boolean)

const buildCorsHeaders = (origin: string | null) => {
  const isAllowed = origin ? allowedOrigins.includes(origin) : true
  return {
    'Access-Control-Allow-Origin': isAllowed && origin ? origin : allowedOrigins[0] ?? '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Vary': 'Origin',
  }
}

Deno.serve(async (req: Request) => {
  const origin = req.headers.get('Origin')
  const corsHeaders = buildCorsHeaders(origin)

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ valid: false, error_code: 'METHOD_NOT_ALLOWED', message: 'Use POST.' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(
        JSON.stringify({ valid: false, error_code: 'UNAUTHENTICATED', message: 'Authorization header with Bearer token is required.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    let body: Record<string, unknown>
    try {
      body = await req.json()
    } catch {
      return new Response(
        JSON.stringify({ valid: false, error_code: 'INVALID_JSON', message: 'Request body must be valid JSON.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const validation = validateBookingPassRequest(body)
    if (!validation.valid) {
      return new Response(
        JSON.stringify({ valid: false, error_code: 'INVALID_INPUT', message: validation.errors[0] ?? 'Request validation failed.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    )

    const { data, error } = await supabase.rpc('verify_booking_pass', {
      p_token: validation.normalized.token,
    })

    if (error) {
      console.error('verify_booking_pass rpc error:', error)
      return new Response(
        JSON.stringify({ valid: false, error_code: 'RPC_ERROR', message: 'Verification failed.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const result = (data ?? { valid: false, error_code: 'INVALID_PASS' }) as {
      valid?: boolean
      error_code?: string
      message?: string
      booking_id?: string
      space_id?: string
      facility_name?: string
      space_name?: string
      starts_at?: string
      ends_at?: string
      status?: string
      pass_status?: string
    }

    if (result.valid) {
      return new Response(
        JSON.stringify({
          valid: true,
          booking_id: result.booking_id,
          space_id: result.space_id,
          facility_name: result.facility_name,
          space_name: result.space_name,
          starts_at: result.starts_at,
          ends_at: result.ends_at,
          status: result.status,
          pass_status: result.pass_status,
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    return new Response(
      JSON.stringify({
        valid: false,
        error_code: result.error_code ?? 'INVALID_PASS',
        message: result.message ?? 'Booking pass is invalid or no longer eligible.',
      }),
      {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('Unexpected error in verify-booking-pass:', error)
    return new Response(
      JSON.stringify({ valid: false, error_code: 'INTERNAL_ERROR', message: 'Unexpected verification failure.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
