import { createClient } from 'npm:@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const json = (body: Record<string, unknown>, status = 200) => new Response(
  JSON.stringify(body),
  { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
);

const escapeHtml = (value: unknown) => String(value ?? '')
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#039;');

serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
  if (!request.headers.get('Authorization')) return json({ error: 'authentication_required' }, 401);

  let reference = '';
  try {
    const body = await request.json();
    reference = String(body?.reference ?? '').trim().toUpperCase();
  } catch {
    return json({ error: 'invalid_payload' }, 400);
  }
  if (!/^[A-F0-9]{10}$/.test(reference)) return json({ error: 'invalid_reference' }, 400);

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );
  const { data: booking, error: claimError } = await supabase
    .rpc('claim_booking_notification', { p_reference: reference });
  if (claimError) return json({ error: 'notification_claim_failed' }, 500);
  if (!booking) return json({ ok: true, skipped: true });

  const labels: Record<string, string> = {
    morning: 'Mañana', midday: 'Mediodía', afternoon: 'Tarde', flexible: 'Flexible',
    shared: 'Individual / compartida', private: 'Grupo privado', partner: 'Hotel, agencia o partner',
    es: 'Español', en: 'English',
  };

  let adminSent = !booking.admin_notification_pending;
  if (booking.admin_notification_pending) {
    const resendKey = Deno.env.get('RESEND_API_KEY');
    const recipient = Deno.env.get('BOOKING_NOTIFICATION_EMAIL');
    const from = Deno.env.get('BOOKING_NOTIFICATION_FROM') || 'Rutas B <onboarding@resend.dev>';
    if (resendKey && recipient) {
      const html = `
        <h1>Nueva solicitud de ruta</h1>
        <p><strong>Referencia:</strong> ${escapeHtml(booking.reference)}</p>
        <p><strong>Ruta:</strong> ${escapeHtml(booking.route_title)}</p>
        <p><strong>Fecha:</strong> ${escapeHtml(booking.preferred_date)}</p>
        <p><strong>Horario:</strong> ${escapeHtml(labels[booking.preferred_time] || booking.preferred_time)}</p>
        <p><strong>Personas:</strong> ${escapeHtml(booking.participant_count)}</p>
        <p><strong>Modalidad:</strong> ${escapeHtml(labels[booking.modality] || booking.modality)}</p>
        <p><strong>Idioma:</strong> ${escapeHtml(labels[booking.language] || booking.language)}</p>
        <hr>
        <p><strong>Cliente:</strong> ${escapeHtml(booking.customer_name)}</p>
        <p><strong>Correo:</strong> ${escapeHtml(booking.customer_email)}</p>
        <p><strong>Teléfono:</strong> ${escapeHtml(booking.customer_phone || 'No indicado')}</p>
        <p><strong>Solicitud especial:</strong> ${escapeHtml(booking.special_requests || 'Ninguna')}</p>
      `;
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from,
          to: [recipient],
          subject: `Nueva reserva ${reference} · ${booking.route_title}`,
          html,
        }),
      });
      adminSent = response.ok;
    }
  }

  let customerSent = !booking.customer_notification_pending;
  if (booking.customer_notification_pending) {
    const webhookUrl = Deno.env.get('CUSTOMER_EMAIL_WEBHOOK_URL');
    const webhookSecret = Deno.env.get('CUSTOMER_EMAIL_WEBHOOK_SECRET');
    if (webhookUrl && webhookSecret) {
      try {
        const response = await fetch(webhookUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            secret: webhookSecret,
            to: booking.customer_email,
            name: booking.customer_name,
            reference: booking.reference,
            route: booking.route_title,
            date: booking.preferred_date,
          }),
        });
        const result = await response.json().catch(() => null);
        customerSent = response.ok && result?.ok === true;
      } catch {
        customerSent = false;
      }
    }
  }

  await supabase.rpc('complete_booking_notification', {
    p_reference: reference,
    p_admin_sent: adminSent,
    p_customer_sent: customerSent,
  });

  if (!adminSent || !customerSent) return json({ error: 'notification_delivery_failed' }, 502);
  return json({ ok: true, admin_sent: adminSent, customer_sent: customerSent });
});
