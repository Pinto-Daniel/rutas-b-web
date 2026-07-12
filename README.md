# Rutas B de Barcelona

Aplicación comercial pública y panel administrativo modular para Rutas B.

## Arquitectura

- Astro + TypeScript.
- Salida estática compatible con GitHub Pages.
- Datos iniciales de rutas en `src/data/routes.ts`.
- Módulos activables en `src/config/site.ts`.
- Supabase previsto para autenticación, reservas, disponibilidad e imágenes.

## Desarrollo

```bash
pnpm install
pnpm dev
```

## Agregar o retirar módulos

Cambiar `siteConfig.modules` en `src/config/site.ts`. Cada área se mantiene separada para poder activarla o retirarla sin afectar el resto.

## Agregar o retirar rutas

Editar `src/data/routes.ts`. Una ruta con `published: false` desaparece del catálogo y de las páginas generadas. No se deben incluir guiones completos ni información privada en este archivo.

## Estado

Primera maqueta funcional. Los formularios validan localmente, pero no transmiten datos hasta conectar Supabase.
