# Sistema Misericordia

App de gestión de pedidos, stock y despachos. Reemplaza la planilla
`Sistema_Misericordia_.xlsx` por una base Supabase (Postgres) + una app
web estática, con el mismo esquema de trabajo que ya usás en ALAV COMEX
(GitHub Pages + Supabase), pero como proyecto totalmente separado.

## Estructura

```
sistema-misericordia/
├── index.html
├── manifest.json
├── css/style.css
├── js/
│   ├── supabaseClient.js       -- ⚠️ acá van tus credenciales
│   └── app.js
├── README.md
└── supabase/
    ├── schema.sql                        -- tablas, vistas y triggers (correr primero)
    ├── migracion_02_vistas_zf_guia.sql   -- vistas de Zona Franca / Guía de Carga
    └── migrate_from_excel.py             -- genera seed.sql desde tu planilla actual
```

## Puesta en marcha (paso a paso)

### 1. Crear el proyecto en Supabase
1. Entrá a [supabase.com](https://supabase.com) → **New project**.
2. Guardá la contraseña de la base y esperá a que termine de crearse (~2 min).

### 2. Cargar el esquema
1. En el proyecto, andá a **SQL Editor**.
2. Pegá todo el contenido de `supabase/schema.sql` → **Run**.
   Esto crea las tablas (`articulos`, `pedidos`, `pedido_items`, `stock`,
   `salidas_zf`, etc.), los triggers de stock automático y las vistas que
   alimentan el Dashboard.

### 3. Migrar los datos actuales de la planilla
```bash
cd supabase
pip install pandas openpyxl --break-system-packages   # si no los tenés
python3 migrate_from_excel.py "/ruta/a/Sistema_Misericordia_REDISEÑO.xlsx"
```
Esto genera `seed.sql`. Pegalo en el SQL Editor de Supabase → **Run**.

> Nota: `migrate_from_excel.py` reconstruye `familia_ctzf` con la misma
> regla que usaba la planilla (tamaño según el sufijo `/N` del código),
> así que no depende de que la fórmula de Google Sheets haya recalculado.

### 4. Conectar la app a tu proyecto
Abrí `js/supabaseClient.js` y completá:
```js
const SUPABASE_URL = "https://TU-PROYECTO.supabase.co";
const SUPABASE_ANON_KEY = "TU-ANON-KEY";
```
(Los sacás de **Project Settings → API** en Supabase.)

### 5. Subir a GitHub Pages
```bash
git init
git add .
git commit -m "Primera version - Sistema Misericordia"
git branch -M main
git remote add origin https://github.com/TU-USUARIO/sistema-misericordia.git
git push -u origin main
```
Después, en el repo de GitHub: **Settings → Pages → Deploy from branch →
main / (root)**. Quedará publicada en
`https://TU-USUARIO.github.io/sistema-misericordia/`.

## Qué trae esta primera versión

- **Dashboard**: KPIs (total/cargados/pendientes/% cargado), Top 10
  artículos despachados, ítems por transporte.
- **Pedidos**: listado con estado automático (Pendiente / En proceso /
  Completado, calculado por la vista `vista_pedidos_estado`) y buscador.
- **Stock**: stock por artículo y ubicación (Stock A / Stock B (IDUO) /
  Stock GE), con el total resaltado en rojo si baja de 10 unidades.

## Qué queda pendiente para siguientes iteraciones

- Formularios para cargar pedidos nuevos y editar stock desde la app
  (hoy la carga es solo lectura; se edita por SQL Editor o Table Editor
  de Supabase).
- Login por usuario (Marina, Carina, etc.) con RLS por rol —
  hoy el RLS está deshabilitado a propósito, igual que en ALAV COMEX,
  para que no bloquee escrituras en esta primera etapa.
- PWA completa (íconos, instalable en el celular).

## Historial de migraciones

- `supabase/schema.sql` — esquema inicial (correr primero, una sola vez).
- `supabase/migracion_02_vistas_zf_guia.sql` — agrega las vistas que usan
  las pantallas de Zona Franca y Guía de Carga. Correr una vez, después
  del schema inicial. No borra ni modifica nada existente.
