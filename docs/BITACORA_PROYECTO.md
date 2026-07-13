# Bitácora — Rutas B de Barcelona

## Checkpoint 01: nacimiento de la web

**Fecha:** 13 de julio de 2026  
**Estado:** primera versión funcional, publicada y conectada a Supabase.

### Resultado alcanzado

- Web comercial construida con Astro y TypeScript.
- Repositorio público: https://github.com/Pinto-Daniel/rutas-b-web
- Web pública: https://pinto-daniel.github.io/rutas-b-web/
- Diseño adaptable a escritorio y celular.
- Catálogo inicial: Sagrada Família, Barcino y CafèBorn.
- Fichas de ruta, comparación, solicitud, confirmación, contacto, preguntas, presentación del guía y páginas legales provisionales.
- Panel privado conectado a Supabase para consultar solicitudes y reservas.
- Reserva de prueba `CF7D358C1A` preservada.
- Variables locales protegidas mediante `.env`, ignorado por Git.
- Despliegue automático mediante GitHub Actions y GitHub Pages.

### Correcciones importantes del checkpoint

- Confirmación muestra el título público de la ruta y no el slug técnico.
- Caracteres UTF-8 revisados.
- Cabeceras y títulos preparados para escritorio y móvil.
- Rutas de CSS, imágenes y favicon corregidas para GitHub Pages.
- Publicación comprobada con respuestas HTTP correctas para página, estilos e imágenes.

### Arquitectura modular actual

- Configuración general y activación de módulos: `src/config/site.ts`.
- Contenido de rutas: `src/data/routes.ts`.
- Identidad visual, colores y fuentes: `src/styles/global.css`.
- Imágenes públicas: `public/images/`.
- Los módulos de rutas, disponibilidad, reservas, mensajes y reseñas están desacoplados.
- El panel administra hoy el resumen de reservas; los editores detallados siguen pendientes.

### Checkpoint de marca

Se evaluaron dos archivos sin incorporarlos todavía:

1. **Logo completo “Rutas B de Barcelona”**: recomendado para portadas, folletos y firma institucional.
2. **Isotipo “B”**: recomendado como símbolo general para web, mapas, señalética, redes y materiales.

Antes de utilizarlos se deben preparar versiones transparentes, horizontal, compacta, favicon y variantes negra, verde bosque, blanca y crema. El original no debe alterarse.

### Próximo lote de personalización

- Definir sistema definitivo de logo, tipografías y colores.
- Convertir el panel en centro de contenidos editable.
- Incorporar mapas, folletos, galerías y materiales descargables.
- Completar rutas, precios, disponibilidad, textos legales e idiomas reales.
- Revisar cada cambio localmente en escritorio y móvil antes de publicarlo.

### Regla de continuidad

Este checkpoint es la base estable del proyecto. Las próximas personalizaciones deben ser modulares, reversibles y no deben alterar reservas, Supabase ni la versión pública sin verificación previa.
