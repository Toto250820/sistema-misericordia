"""
Migra los datos de Sistema_Misericordia_REDISEÑO.xlsx a un seed.sql
listo para correr en el SQL Editor de Supabase (después de schema.sql).

Uso:
    pip install openpyxl pandas --break-system-packages   # si hace falta
    python3 migrate_from_excel.py /ruta/a/Sistema_Misericordia_REDISEÑO.xlsx

Genera: seed.sql (en la misma carpeta de este script)
"""
import sys
import re
import datetime
import pandas as pd

def esc(v):
    """Escapa un valor para SQL. None / NaN / NaT -> NULL."""
    try:
        if pd.isna(v):
            return "NULL"
    except (TypeError, ValueError):
        pass
    if isinstance(v, bool):          # chequear bool ANTES que int (bool es subclase de int en Python)
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if isinstance(v, (datetime.date, datetime.datetime, pd.Timestamp)):
        return f"'{v.isoformat()}'"
    s = str(v).replace("'", "''")
    return f"'{s}'"

def clean_id(v):
    """Normaliza un identificador (código de artículo, N° de pedido, nombre de
    cliente) a texto 'canónico'. Excel/Sheets a veces guarda el mismo dato como
    número en una hoja (2133) y como texto en otra ("2133"), lo que rompe los
    JOIN por igualdad. Acá todo pasa a texto de forma consistente."""
    try:
        if pd.isna(v):
            return None
    except (TypeError, ValueError):
        pass
    if isinstance(v, float) and v.is_integer():
        return str(int(v))
    return str(v).strip()

def esc_id(v):
    """Como esc(), pero siempre entre comillas de texto (para códigos/IDs)."""
    s = clean_id(v)
    if s is None:
        return "NULL"
    return "'" + s.replace("'", "''") + "'"

_date_warnings = []

def esc_date(v, context=""):
    """Parsea fechas de forma tolerante (día primero, como en Argentina).
    Si no se puede interpretar (typos, años imposibles, etc.) devuelve NULL
    y lo deja anotado para avisar al final, en vez de romper el INSERT."""
    try:
        if pd.isna(v):
            return "NULL"
    except (TypeError, ValueError):
        pass
    if isinstance(v, (datetime.date, datetime.datetime, pd.Timestamp)):
        try:
            return f"'{pd.Timestamp(v).date().isoformat()}'"
        except (ValueError, OverflowError):
            _date_warnings.append((context, v))
            return "NULL"
    try:
        ts = pd.to_datetime(v, dayfirst=True, errors='coerce')
    except Exception:
        ts = pd.NaT
    if pd.isna(ts) or ts.year < 1900 or ts.year > 2100:
        _date_warnings.append((context, v))
        return "NULL"
    return f"'{ts.date().isoformat()}'"

def main(xlsx_path):
    out = []
    out.append("-- Generado automáticamente por migrate_from_excel.py")
    out.append("-- Correr DESPUÉS de schema.sql\n")
    out.append("begin;\n")

    # ---- articulos (desde Configuracion) ----
    cfg = pd.read_excel(xlsx_path, sheet_name="Configuracion", usecols="D:H",
                         names=["codigo", "descripcion", "uds_por_bulto", "categoria", "familia_ctzf"],
                         skiprows=1)
    cfg = cfg.dropna(subset=["codigo"])
    out.append("-- articulos")

    TAMANIOS = {"1": "TWIN", "3": "FULL", "4": "QUEEN", "5": "KING"}

    def familia_ctzf(codigo, categoria, valor_hoja):
        # Si la hoja ya trae un valor (override manual, ej. "Fundas"), respetalo.
        if valor_hoja is not None and not pd.isna(valor_hoja):
            return valor_hoja
        # Si no, reconstruimos con la misma regla que usaba Configuracion!H
        # (REGEXEXTRACT del sufijo /N + SWITCH a nombre de tamaño).
        if categoria is None or pd.isna(categoria):
            return None
        m = re.search(r"/([0-9]+)", str(codigo))
        if not m:
            return None
        tam = TAMANIOS.get(m.group(1))
        return f"{categoria} {tam}" if tam else None

    for _, r in cfg.iterrows():
        fam = familia_ctzf(r['codigo'], r['categoria'], r['familia_ctzf'])
        out.append(
            "insert into articulos (codigo, descripcion, uds_por_bulto, categoria, familia_ctzf) "
            f"values ({esc_id(r['codigo'])}, {esc(r['descripcion'])}, {esc(r['uds_por_bulto'])}, "
            f"{esc(r['categoria'])}, {esc(fam)}) "
            "on conflict (codigo) do nothing;"
        )

    # ---- clientes (desde Detalle!B, valores únicos) ----
    det = pd.read_excel(xlsx_path, sheet_name="Detalle")
    clientes = sorted({clean_id(c) for c in det["Cliente"].dropna()} - {None})
    out.append("\n-- clientes")
    for c in clientes:
        out.append(f"insert into clientes (nombre) values ({esc_id(c)}) on conflict (nombre) do nothing;")

    # ---- pedidos (desde General) ----
    gen = pd.read_excel(xlsx_path, sheet_name="General")
    out.append("\n-- pedidos")
    for _, r in gen.iterrows():
        num = clean_id(r.get("Nº de Pedido"))
        if num is None:
            continue
        out.append(
            "insert into pedidos (numero_pedido, cliente_id, destino, observaciones, fecha_ingreso, fecha_completado) "
            f"values ({esc_id(num)}, "
            f"(select id from clientes where nombre = {esc_id(r.get('Cliente'))}), "
            f"{esc(r.get('Destino'))}, {esc(r.get('Observaciones'))}, "
            f"{esc_date(r.get('Fecha de Ingreso'), f'pedidos/{num}/Fecha de Ingreso')}, "
            f"{esc_date(r.get('Fecha Completado'), f'pedidos/{num}/Fecha Completado')}) "
            "on conflict (numero_pedido) do nothing;"
        )

    # ---- pedido_items (desde Detalle + Entregados) ----
    out.append("\n-- pedido_items (Detalle)")
    for _, r in det.iterrows():
        art = r.get("Art")
        if pd.isna(art) and pd.isna(r.get("Nro de Pedido")):
            continue
        estado_val = r.get('Estado') if not pd.isna(r.get('Estado')) else 'Pendiente'
        despachado_val = bool(r.get('Despachado')) if not pd.isna(r.get('Despachado')) else False
        fecha_ctx = f"Detalle/Art={art}/Nro={r.get('Nro de Pedido')}/Fecha de carga"
        out.append(
            "insert into pedido_items (pedido_id, articulo_id, unidades, bultos, pallets, estado, "
            "carga_en, remito_guia, fc, destino, descarga_en, provincia_ciudad, transporte, "
            "valor_aprox, adicional_x_envio, fecha_carga, despachado, observacion) values ("
            f"(select id from pedidos where numero_pedido = {esc_id(r.get('Nro de Pedido'))}), "
            f"(select id from articulos where codigo = {esc_id(art)}), "
            f"{esc(r.get('Unidades'))}, {esc(r.get('Bultos'))}, {esc(r.get('Pallets'))}, "
            f"{esc(estado_val)}, "
            f"{esc(r.get('Carga en'))}, {esc(r.get('Remito/Guia'))}, {esc(r.get('FC'))}, "
            f"{esc(r.get('Destino'))}, {esc(r.get('Descarga en'))}, {esc(r.get('Provincia/Ciudad'))}, "
            f"{esc(r.get('Transporte'))}, {esc(r.get('Valor Aprox'))}, {esc(r.get('Adicional x env'))}, "
            f"{esc_date(r.get('Fecha de carga'), fecha_ctx)}, "
            f"{esc(despachado_val)}, "
            f"{esc(r.get('OBSERVACION'))});"
        )

    # ---- stock (desde Stock General) ----
    sg = pd.read_excel(xlsx_path, sheet_name="Stock General")
    out.append("\n-- stock")
    for _, r in sg.iterrows():
        codigo = r.get("Artículo")
        if pd.isna(codigo):
            continue
        for col, ubic in [("Stock A", "Stock A"), ("Stock B (IDUO)", "Stock B (IDUO)"), ("Stock GE", "Stock GE")]:
            cant = r.get(col)
            out.append(
                "insert into stock (articulo_id, ubicacion, cantidad) values ("
                f"(select id from articulos where codigo = {esc_id(codigo)}), "
                f"{esc(ubic)}, {esc(cant if not pd.isna(cant) else 0)}) "
                "on conflict (articulo_id, ubicacion) do update set cantidad = excluded.cantidad;"
            )

    out.append("\ncommit;")

    with open("seed.sql", "w", encoding="utf-8") as f:
        f.write("\n".join(out))
    print(f"Listo -> seed.sql ({len(out)} líneas)")

    if _date_warnings:
        print(f"\n⚠ {len(_date_warnings)} fecha(s) no se pudieron interpretar y quedaron en NULL:")
        for ctx, val in _date_warnings:
            print(f"   - {ctx}: {val!r}")
        print("   Revisalas a mano en la planilla y volvé a correr el script si querés cargarlas.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python3 migrate_from_excel.py <ruta al xlsx>")
        sys.exit(1)
    main(sys.argv[1])
