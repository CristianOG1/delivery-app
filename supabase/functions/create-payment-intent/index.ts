// Edge Function: create-payment-intent
// Crea el pedido (pendiente) y el cobro en Stripe. El monto se calcula AQUÍ con
// los precios reales de menu_items: nunca se confía en el precio que manda la app.
//
// Secreto requerido: STRIPE_SECRET_KEY (sk_test_...), en Supabase -> Edge Functions -> Secrets.

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

    // Cliente con permisos de servicio (solo existe en el servidor).
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    )

    // 1. ¿Quién está pagando? Se valida el token de sesión del cliente.
    const token = (req.headers.get('Authorization') ?? '').replace('Bearer ', '')
    const { data: userData, error: userError } = await admin.auth.getUser(token)
    if (userError || !userData.user) return json({ error: 'Debes iniciar sesión para pagar.' }, 401)
    const user = userData.user

    // 2. Validar el carrito que mandó la app (solo ids y cantidades).
    const body = await req.json()
    const items = body?.items
    if (!Array.isArray(items) || items.length === 0 || items.length > 50) {
      return json({ error: 'Tu carrito está vacío.' }, 400)
    }
    const cantidades = new Map<string, number>()
    for (const it of items) {
      const id = String(it?.menu_item_id ?? '')
      const qty = Number(it?.quantity)
      if (!id || !Number.isInteger(qty) || qty < 1 || qty > 50) {
        return json({ error: 'Carrito inválido.' }, 400)
      }
      cantidades.set(id, (cantidades.get(id) ?? 0) + qty)
    }

    // 3. Precios reales desde la base de datos.
    const { data: platillos, error: menuError } = await admin
      .from('menu_items')
      .select('id, name, price, is_available')
      .in('id', [...cantidades.keys()])
    if (menuError) throw menuError
    if (!platillos || platillos.length !== cantidades.size) {
      return json({ error: 'Alguno de los platillos ya no existe.' }, 400)
    }
    const noDisponible = platillos.find((p) => p.is_available === false)
    if (noDisponible) {
      return json({ error: `"${noDisponible.name}" ya no está disponible.` }, 400)
    }

    let totalCentavos = 0
    const lineas = platillos.map((p) => {
      const qty = cantidades.get(String(p.id))!
      const precioCentavos = Math.round(Number(p.price) * 100)
      totalCentavos += precioCentavos * qty
      return {
        menu_item_id: String(p.id),
        name: p.name as string,
        unit_price: precioCentavos / 100,
        quantity: qty,
      }
    })
    if (totalCentavos <= 0) return json({ error: 'El total del pedido no es válido.' }, 400)

    // 4. Crear el pedido en estado "pending".
    const { data: pedido, error: pedidoError } = await admin
      .from('orders')
      .insert({ user_id: user.id, total: totalCentavos / 100, currency: 'mxn', status: 'pending' })
      .select('id')
      .single()
    if (pedidoError) throw pedidoError

    const { error: lineasError } = await admin
      .from('order_items')
      .insert(lineas.map((l) => ({ ...l, order_id: pedido.id })))
    if (lineasError) {
      await admin.from('orders').update({ status: 'failed' }).eq('id', pedido.id)
      throw lineasError
    }

    // 5. Crear el cobro en Stripe (monto en centavos).
    const params = new URLSearchParams()
    params.set('amount', String(totalCentavos))
    params.set('currency', 'mxn')
    params.set('automatic_payment_methods[enabled]', 'true')
    params.set('metadata[order_id]', pedido.id)
    if (user.email) params.set('receipt_email', user.email)

    const stripeRes = await fetch('https://api.stripe.com/v1/payment_intents', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${stripeKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Idempotency-Key': `order-${pedido.id}`,
      },
      body: params,
    })
    const intent = await stripeRes.json()

    if (!stripeRes.ok) {
      await admin.from('orders').update({ status: 'failed' }).eq('id', pedido.id)
      return json({ error: intent?.error?.message ?? 'Stripe rechazó la solicitud.' }, 502)
    }

    await admin
      .from('orders')
      .update({ stripe_payment_intent_id: intent.id })
      .eq('id', pedido.id)

    return json({
      client_secret: intent.client_secret,
      order_id: pedido.id,
      amount: totalCentavos / 100,
    })
  } catch (e) {
    console.error(e)
    return json({ error: 'Error interno al preparar el pago.' }, 500)
  }
})
