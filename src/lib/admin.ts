import { supabase, supabaseConfigured } from './supabase';

export async function signInAdmin(email: string, password: string) {
  if (!supabaseConfigured || !supabase) throw new Error('Supabase no está configurado.');
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
  return data;
}

export async function getAdminDashboard() {
  if (!supabase) throw new Error('Supabase no está configurado.');
  const [{ data: profile }, { data: bookings, error }] = await Promise.all([
    supabase.from('admin_profiles').select('display_name,active').single(),
    supabase.from('bookings').select('id,public_reference,preferred_date,participant_count,status,created_at,customers(full_name,email),routes(title)').order('created_at',{ascending:false}).limit(25)
  ]);
  if (error) throw error;
  if (!profile?.active) throw new Error('La cuenta no tiene acceso administrativo activo.');
  return { profile, bookings: bookings ?? [] };
}
