import { supabase, supabaseConfigured } from './supabase';

export interface BookingRequest {
  route: string; date: string; time: 'morning'|'midday'|'afternoon'|'flexible';
  language: 'es'|'en'; people: number; modality: 'shared'|'private'|'partner';
  name: string; email: string; phone?: string; notes?: string; website?: string;
}

export async function submitBooking(payload: BookingRequest) {
  if (!supabaseConfigured || !supabase) {
    return { mode: 'demo' as const, reference: `DEMO-${Date.now().toString().slice(-6)}`, duplicate: false };
  }
  const { data, error } = await supabase.rpc('submit_booking_request', { payload });
  if (error) throw new Error(error.message);
  return { mode: 'connected' as const, reference: data.reference as string, duplicate: Boolean(data.duplicate) };
}
