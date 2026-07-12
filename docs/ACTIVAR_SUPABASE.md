# Activar Supabase sin publicar secretos

La web funciona en modo demostración mientras las variables de conexión estén vacías.

## 1. Crear la base

Crear un proyecto gratuito en Supabase y ejecutar una sola vez `supabase/migrations/001_initial_schema.sql` en el editor SQL. La migración crea tablas, restricciones, políticas y las tres rutas iniciales; no inventa precios ni reseñas.

## 2. Crear el primer administrador

Crear el usuario en Authentication → Users, copiar su UUID y ejecutar:

```sql
insert into public.admin_profiles (id, display_name)
values ('UUID-DEL-USUARIO', 'Daniel');
```

Una cuenta autenticada sin fila activa en `admin_profiles` no puede leer reservas.

## 3. Variables locales

Copiar `.env.example` como `.env` y completar:

```env
PUBLIC_SUPABASE_URL=https://TU-PROYECTO.supabase.co
PUBLIC_SUPABASE_PUBLISHABLE_KEY=TU_CLAVE_PUBLICABLE
```

Nunca agregar la clave `service_role` ni una clave secreta al repositorio.

## 4. Verificación antes de publicar

- Una persona anónima puede ejecutar `submit_booking_request`.
- Una persona anónima no puede leer `customers` ni `bookings`.
- Un usuario autenticado sin perfil administrativo tampoco puede leerlas.
- El administrador activo puede ver solicitudes.
- Dos envíos iguales en menos de quince minutos devuelven la misma referencia.
- Las solicitudes nunca aparecen en páginas públicas.

## 5. Copias de seguridad

En la etapa gratuita se debe realizar una exportación periódica de la base. Las imágenes requieren una copia separada.
