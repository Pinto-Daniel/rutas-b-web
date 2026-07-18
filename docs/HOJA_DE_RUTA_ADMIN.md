# Hoja de ruta — Acceso privado de Rutas B

## Estado actual

- Operativo: autenticación, recuperación de contraseña y resumen de solicitudes.
- Pendiente: Rutas, Disponibilidad, Reservas completas, Mensajes y Reseñas.
- La web pública obtiene las rutas desde `src/data/routes.ts`.
- La migración local `001_initial_schema.sql` está vacía; no debe ejecutarse.

## Fase 0 — Seguridad y base reproducible

1. Exportar estructura y datos actuales de Supabase.
2. Guardar el esquema real como una nueva migración versionada.
3. Confirmar políticas RLS y permisos del administrador.
4. Preservar todas las reservas existentes.
5. Crear una copia separada de imágenes y materiales.

**Termina cuando:** la base puede reconstruirse sin pérdida y existe un respaldo verificable.

## Fase 1 — Reservas

- Listado completo con paginación.
- Búsqueda y filtros por fecha, ruta y estado.
- Ficha de detalle del cliente y la solicitud.
- Cambio controlado de estado: recibida, en revisión, confirmada, cancelada y completada.
- Notas internas y registro de cambios.
- Exportación CSV.

**Termina cuando:** una reserva puede gestionarse de principio a fin sin entrar al panel de Supabase.

## Fase 2 — Mensajes

- Conectar el formulario público de contacto.
- Guardar mensajes mediante una función segura.
- Bandeja de entrada con estados: nuevo, leído, respondido y archivado.
- Filtros por tipo de consulta.
- Acceso rápido al correo del remitente.

**Termina cuando:** los mensajes públicos aparecen en el panel sin exponer datos a usuarios anónimos.

## Fase 3 — Disponibilidad

- Calendario por ruta.
- Bloqueos por fecha o tramo horario.
- Cupo máximo y estado disponible/no disponible.
- Zona horaria fija: Europe/Madrid.
- Validación de disponibilidad en el formulario de solicitud.

**Termina cuando:** el administrador controla las fechas ofrecidas y el formulario evita solicitudes imposibles.

## Fase 4 — Rutas y materiales

- Crear, editar, ordenar, publicar y ocultar rutas.
- Editar títulos, textos, paradas, duración, precios, idiomas y accesibilidad.
- Gestionar fotografía, galería, mapa, folleto y audio.
- Usar Supabase Storage con políticas separadas para lectura pública y escritura administrativa.
- Sincronizar los cambios con GitHub Pages mediante una reconstrucción automática.

**Decisión técnica:** las páginas son estáticas; guardar una ruta en Supabase debe disparar un nuevo despliegue de GitHub Pages para conservar SEO y enlaces directos.

**Termina cuando:** una ruta puede publicarse desde el panel y aparece en la web después del despliegue automático.

## Fase 5 — Reseñas

- Crear o importar reseñas verificadas.
- Vincularlas opcionalmente a una ruta.
- Moderar texto, nombre público y consentimiento.
- Estados: borrador, revisión, publicada y archivada.
- Activar el módulo público solo cuando existan reseñas válidas.

**Termina cuando:** ninguna reseña se publica automáticamente y el administrador controla todo el flujo.

## Fase 6 — Resumen y control final

- Métricas por periodo, ruta y estado.
- Alertas de solicitudes y mensajes pendientes.
- Actividad reciente.
- Auditoría móvil y de accesibilidad.
- Pruebas de permisos anónimos y administrativos.
- Copias de seguridad periódicas.

## Orden recomendado

1. Seguridad y respaldo.
2. Reservas.
3. Mensajes.
4. Disponibilidad.
5. Rutas y materiales.
6. Reseñas.
7. Resumen final.

## Protocolo de trabajo de bajo consumo

- Una fase por tarea nueva.
- Leer este archivo y `BITACORA_PROYECTO.md`.
- No usar subagentes salvo auditorías independientes.
- No ejecutar migraciones antiguas.
- Probar localmente y ejecutar `pnpm run build`.
- Revisar escritorio y celular.
- Aprobar antes de publicar.
- Un commit por fase.
