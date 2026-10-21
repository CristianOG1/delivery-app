// Edge Function: confirm-payment
// Después de que el cliente paga en la hoja de Stripe, la app llama aquí.
// NO se confía en la app: se le pregunta a Stripe si el cobro se completó, se
// compara el monto y solo entonces se marca el pedido como pagado y se guarda
// el enlace del recibo.
//
// Secreto requerido: STRIPE_SECRET_KEY (sk_test_...).

import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const stripeKey = Deno.env.get('STRIPE_SECRET_KEY')
    if (!stripeKey) return json({ error: 'Falta configurar STRIPE_SECRET_KEY en Supabase.' }, 500)

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. Usuario autenticado.
    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '')
    const { data: userData, error: userError } = await admin.auth.getUser(token)
    if (userError || !userData.user) return json({ error: 'Debes iniciar sesión.' }, 401)
    const user = userData.user

    const body = await req.json()
    const orderId = String(body?.order_id ?? '')
    if (!orderId) return json({ error: 'Falta el número de pedido.' }, 400)

    // 2. El pedido debe ser de este usuario.
    const { data: pedido, error: pedidoError } = await admin
      .from('orders')
      .select('*')
      .eq('id', orderId)
      .eq('user_id', user.id)
      .maybeSingle()
    if (pedidoError) throw pedidoError
    if (!pedido) return json({ error: 'Pedido no encontrado.' }, 404)

    const completo = async () => {
      const { data, error } = await admin
        .from('orders')
        .select('*, order_items(*)')
        .eq('id', orderId)
        .single()
      if (error) throw error
      return data
    }

    // Si ya estaba pagado, devolvemos el recibo tal cual (llamada repetida).
    if (pedido.status === 'paid') return json({ status: 'paid', order: await completo() })
    if (!pedido.stripe_payment_intent_id) {
      return json({ error: 'Este pedido no tiene un cobro asociado.' }, 400)
    }

    // 3. Preguntarle a Stripe (y traer el cargo para sacar el enlace del recibo).
    const stripeRes = await fetch(
      `https://api.stripe.com/v1/payment_intents/${pedido.stripe_payment_intent_id}?expand[]=latest_charge`,
      { headers: { Authorization: `Bearer ${stripeKey}` } },
    )
    const intent = await stripeRes.json()
    if (!stripeRes.ok) {
      return json({ error: intent?.error?.message ?? 'No se pudo consultar a Stripe.' }, 502)
    }

    if (intent.status !== 'succeeded') {
      return json({ status: intent.status })
    }

    // 4. El monto cobrado debe coincidir con el del pedido.
    const esperado = Math.round(Number(pedido.total) * 100)
    if (intent.amount_received !== esperado || intent.currency !== pedido.currency) {
      console.error('Monto no coincide', { esperado, recibido: intent.amount_received })
      return json({ error: 'El monto cobrado no coincide con el pedido.' }, 409)
    }

    // 5. Marcar como pagado y guardar el recibo.
    const { error: updateError } = await admin
      .from('orders')
      .update({
        status: 'paid',
        paid_at: new Date().toISOString(),
        receipt_url: intent.latest_charge?.receipt_url ?? null,
      })
      .eq('id', orderId)
    if (updateError) throw updateError

    return json({ status: 'paid', order: await completo() })
  } catch (e) {
    console.error(e)
    return json({ error: 'Error interno al confirmar el pago.' }, 500)
  }
})
