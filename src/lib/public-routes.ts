import { createClient } from '@supabase/supabase-js';
import { publishedRoutes as fallbackRoutes, type TourRoute } from '../data/routes';

export async function getPublicRoutes(): Promise<TourRoute[]> {
  const url = import.meta.env.PUBLIC_SUPABASE_URL;
  const key = import.meta.env.PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return fallbackRoutes;

  const client = createClient(url, key);
  const { data, error } = await client
    .from('routes')
    .select('slug,title,short_description,full_description,offered_languages,meeting_point_public,accessibility,includes,excludes,featured,eyebrow,promise,status_label,display_duration,display_format,display_area,display_starting_point,display_ending_point,audience,display_price_individual,display_price_group,primary_image_path,primary_image_alt,route_stops(title,sort_order),route_media(id,kind,role,storage_path,title,alt_text,mime_type,sort_order,status)')
    .eq('status', 'published')
    .order('sort_order');
  if (error || !data?.length) return fallbackRoutes;

  const publicUrl = (path: string) => !path || path.startsWith('/') || /^https?:/i.test(path) ? path : client.storage.from('route-media').getPublicUrl(path).data.publicUrl;
  return data.map((route: any) => ({
    slug: route.slug,
    title: route.title,
    eyebrow: route.eyebrow || '',
    promise: route.promise || route.short_description || '',
    description: route.full_description || '',
    status: ['Ruta inicial', 'Disponible'].includes(route.status_label) ? 'available' : 'in-development',
    statusLabel: route.status_label || 'En preparación',
    duration: route.display_duration || 'Pendiente de definición',
    format: route.display_format || 'Pendiente de definición',
    area: route.display_area || 'Pendiente de definición',
    languages: (route.offered_languages || []).map((code: string) => code === 'es' ? 'Español' : code === 'en' ? 'English' : code),
    audience: route.audience || [],
    startingPoint: route.display_starting_point || route.meeting_point_public || '',
    endingPoint: route.display_ending_point || '',
    stops: [...(route.route_stops || [])].sort((a: any, b: any) => a.sort_order - b.sort_order).map((stop: any) => stop.title),
    includes: route.includes || [],
    notIncluded: route.excludes || [],
    accessibility: route.accessibility || '',
    priceIndividual: route.display_price_individual || 'Pendiente de definición',
    priceGroup: route.display_price_group || 'Pendiente de definición',
    image: publicUrl(route.primary_image_path || ''),
    imageAlt: route.primary_image_alt || route.title,
    gallery: (route.route_media || []).filter((item: any) => item.kind === 'image' && item.role === 'gallery').sort((a: any,b: any) => a.sort_order-b.sort_order).map((item: any) => ({id:item.id,kind:item.kind,role:item.role,url:publicUrl(item.storage_path),title:item.title||'',altText:item.alt_text||route.title,mimeType:item.mime_type})),
    documents: (route.route_media || []).filter((item: any) => item.role === 'attachment').sort((a: any,b: any) => a.sort_order-b.sort_order).map((item: any) => ({id:item.id,kind:item.kind,role:item.role,url:publicUrl(item.storage_path),title:item.title||'Documento de la ruta',altText:item.alt_text||'',mimeType:item.mime_type})),
    featured: route.featured,
    published: true,
  }));
}
