// ============================================================
// SISTEMA MISERICORDIA — app.js
// Lee las vistas creadas en supabase/schema.sql y las pinta.
// ============================================================

const connStatus = document.getElementById('connStatus');

// ---------- Tabs ----------
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById('tab-' + btn.dataset.tab).classList.add('active');
  });
});

function badgeFor(estado) {
  const map = {
    'Pendiente': 'badge-pendiente',
    'En proceso': 'badge-en-proceso',
    'Completado': 'badge-completado',
  };
  const cls = map[estado] || 'badge-pendiente';
  return `<span class="badge ${cls}">${estado ?? '—'}</span>`;
}

// ---------- Dashboard ----------
async function loadDashboard() {
  const { data: kpis, error: kpiErr } = await supabaseClient
    .from('vista_dashboard_kpis').select('*').single();
  if (!kpiErr && kpis) {
    document.getElementById('kpiTotal').textContent = kpis.total_items ?? '–';
    document.getElementById('kpiCargados').textContent = kpis.items_cargados ?? '–';
    document.getElementById('kpiPendientes').textContent = kpis.items_pendientes ?? '–';
    document.getElementById('kpiPct').textContent = (kpis.pct_cargado ?? '–') + '%';
  }

  const { data: top } = await supabaseClient.from('vista_top_articulos').select('*');
  const topBody = document.querySelector('#tableTop tbody');
  topBody.innerHTML = (top || []).map(r => `
    <tr><td>${r.codigo}</td><td>${r.descripcion ?? ''}</td><td>${r.unidades_despachadas}</td></tr>
  `).join('') || '<tr><td colspan="3">Sin datos todavía.</td></tr>';

  const { data: transp } = await supabaseClient.from('vista_items_por_transporte').select('*');
  const transpBody = document.querySelector('#tableTransporte tbody');
  transpBody.innerHTML = (transp || []).map(r => `
    <tr><td>${r.transporte ?? '—'}</td><td>${r.items}</td></tr>
  `).join('') || '<tr><td colspan="2">Sin datos todavía.</td></tr>';
}

// ---------- Pedidos ----------
let pedidosCache = [];

async function loadPedidos() {
  const { data, error } = await supabaseClient
    .from('vista_pedidos_estado').select('*').order('fecha_ingreso', { ascending: false });
  if (error) { console.error(error); return; }
  pedidosCache = data || [];
  renderPedidos(pedidosCache);
}

function renderPedidos(rows) {
  const body = document.querySelector('#tablePedidos tbody');
  body.innerHTML = rows.map(r => `
    <tr>
      <td>${r.numero_pedido}</td>
      <td>${r.cliente ?? '—'}</td>
      <td>${r.destino ?? '—'}</td>
      <td>${badgeFor(r.estado_general)}</td>
      <td>${r.total_items}</td>
      <td>${r.items_despachados}</td>
      <td>${r.fecha_ingreso ?? '—'}</td>
      <td>${r.fecha_completado ?? '—'}</td>
    </tr>
  `).join('') || '<tr><td colspan="8">Sin pedidos todavía.</td></tr>';
}

document.getElementById('pedidosSearch').addEventListener('input', (e) => {
  const q = e.target.value.trim().toLowerCase();
  renderPedidos(pedidosCache.filter(r =>
    (r.numero_pedido || '').toLowerCase().includes(q) ||
    (r.cliente || '').toLowerCase().includes(q)
  ));
});

// ---------- Stock ----------
let stockCache = [];

async function loadStock() {
  const { data, error } = await supabaseClient
    .from('vista_stock_consolidado').select('*').order('codigo');
  if (error) { console.error(error); return; }
  stockCache = data || [];
  renderStock(stockCache);
}

function renderStock(rows) {
  const body = document.querySelector('#tableStock tbody');
  body.innerHTML = rows.map(r => `
    <tr>
      <td>${r.codigo}</td>
      <td>${r.descripcion ?? ''}</td>
      <td>${r.categoria ?? ''}</td>
      <td>${r.stock_a}</td>
      <td>${r.stock_b}</td>
      <td>${r.stock_ge}</td>
      <td class="${r.total < 10 ? 'stock-bajo' : ''}">${r.total}</td>
    </tr>
  `).join('') || '<tr><td colspan="7">Sin stock cargado todavía.</td></tr>';
}

document.getElementById('stockSearch').addEventListener('input', (e) => {
  const q = e.target.value.trim().toLowerCase();
  renderStock(stockCache.filter(r =>
    (r.codigo || '').toLowerCase().includes(q) ||
    (r.descripcion || '').toLowerCase().includes(q)
  ));
});

// ---------- Init ----------
(async function init() {
  try {
    await Promise.all([loadDashboard(), loadPedidos(), loadStock()]);
    connStatus.textContent = 'conectado a Supabase · actualizado ' + new Date().toLocaleTimeString('es-AR');
  } catch (err) {
    console.error(err);
    connStatus.textContent = 'No se pudo conectar a Supabase. Revisá js/supabaseClient.js';
  }
})();
