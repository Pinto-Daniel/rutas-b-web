export const siteConfig = {
  formalName: 'Rutas B de Barcelona',
  shortName: 'Rutas B',
  tagline: 'Barcelona se entiende mejor cuando alguien te enseña a mirarla.',
  defaultLocale: 'es',
  offeredLanguages: ['Español', 'English'],
  understoodLanguages: ['Català', 'Português'],
  modules: {
    routes: true,
    compare: true,
    guide: true,
    reviews: false,
    faq: true,
    contact: true,
    booking: true,
    admin: true
  },
  routeOrder: ['sagrada-familia', 'barcino', 'cafeborn']
} as const;

export type SiteModule = keyof typeof siteConfig.modules;

export function moduleEnabled(module: SiteModule) {
  return siteConfig.modules[module];
}
