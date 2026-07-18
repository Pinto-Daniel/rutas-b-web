import { createClient } from 'npm:@supabase/supabase-js@2';
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
};

serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  const authorization = request.headers.get('Authorization');
  if (!authorization) return new Response(JSON.stringify({ error: 'authentication_required' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const userClient = createClient(supabaseUrl, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error: userError } = await userClient.auth.getUser();
  if (userError || !user) return new Response(JSON.stringify({ error: 'authentication_required' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  const adminClient = createClient(supabaseUrl, serviceKey);
  const { data: admin } = await adminClient.from('admin_profiles').select('active').eq('id', user.id).maybeSingle();
  if (!admin?.active) return new Response(JSON.stringify({ error: 'admin_access_required' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  const token = Deno.env.get('GITHUB_DEPLOY_TOKEN');
  if (!token) return new Response(JSON.stringify({ error: 'deploy_secret_missing' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

  const githubResponse = await fetch('https://api.github.com/repos/Pinto-Daniel/rutas-b-web/actions/workflows/deploy.yml/dispatches', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ ref: 'main' }),
  });

  if (!githubResponse.ok) return new Response(JSON.stringify({ error: 'github_dispatch_failed' }), { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
});
