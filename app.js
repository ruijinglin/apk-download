/**
 * APK 下载中心 - 纯静态版本
 * 数据来源：同目录下的 packages.json
 * 下载链接：指向 Gitee 仓库的 raw 文件地址
 */

// 状态
let state = {
  products: {},
  activeProduct: null,
  activeBuildType: null
};

// 产品颜色
const COLORS = ['#6366f1','#8b5cf6','#ec4899','#f43f5e','#f59e0b','#10b981','#06b6d4','#3b82f6'];
function getColor(name) {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = name.charCodeAt(i) + ((h << 5) - h);
  return COLORS[Math.abs(h) % COLORS.length];
}

// 构建类型标签
const BUILD_LABELS = {
  release: '🟢 Release', debug: '🟡 Debug', staging: '🔵 Staging',
  production: '🟢 Production', beta: '🟠 Beta', alpha: '🔴 Alpha'
};
function getBuildLabel(t) { return BUILD_LABELS[t] || `📦 ${t}`; }

// 工具
function formatSize(bytes) {
  if (!bytes) return '';
  const u = ['B','KB','MB','GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(1024));
  return (bytes / Math.pow(1024, i)).toFixed(1) + ' ' + u[i];
}

function formatTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  const pad = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function countBuilds(product) {
  let c = 0;
  for (const arr of Object.values(product.builds || {})) c += arr.length;
  return c;
}

// 查找线上版本或最新版本
function findOnlineOrLatest(product, types) {
  // 优先找标记了 isOnline 的
  for (const t of types) {
    for (const v of (product.builds[t] || [])) {
      if (v.isOnline) return v;
    }
  }
  // 没有线上标记就返回第一个构建类型的第一个版本
  return product.builds[types[0]]?.[0] || null;
}

// 加载数据
async function loadData() {
  try {
    const res = await fetch('packages.json?' + Date.now());
    const data = await res.json();
    state.products = data.products || {};
  } catch (e) {
    console.error('加载 packages.json 失败:', e);
    state.products = {};
  }

  const keys = Object.keys(state.products);
  if (keys.length === 0) {
    document.getElementById('empty-state').style.display = 'flex';
    document.getElementById('product-detail').style.display = 'none';
    renderSidebar();
    return;
  }

  document.getElementById('empty-state').style.display = 'none';
  renderSidebar();

  // 自动选中第一个或保持当前选中
  if (!state.activeProduct || !state.products[state.activeProduct]) {
    selectProduct(keys[0]);
  } else {
    renderDetail(state.activeProduct);
  }
}

// 侧边栏
function renderSidebar() {
  const nav = document.getElementById('product-nav');
  const entries = Object.entries(state.products);

  if (entries.length === 0) {
    nav.innerHTML = '<div style="padding:20px;text-align:center;color:var(--text-muted);font-size:0.85rem;">暂无产品</div>';
    return;
  }

  nav.innerHTML = entries.map(([key, p]) => {
    const color = getColor(key);
    const count = countBuilds(p);
    const types = Object.keys(p.builds || {}).join(' / ');
    return `
      <div class="nav-item ${state.activeProduct === key ? 'active' : ''}" onclick="selectProduct('${key}')">
        <div class="nav-item-icon" style="background:${color}20;color:${color}">${key[0].toUpperCase()}</div>
        <div class="nav-item-info">
          <div class="nav-item-name">${key}</div>
          <div class="nav-item-meta">${types || '—'} · ${count} 个版本</div>
        </div>
      </div>`;
  }).join('');
}

// 选择产品
function selectProduct(key) {
  state.activeProduct = key;
  state.activeBuildType = null;
  renderSidebar();
  renderDetail(key);
  document.getElementById('sidebar').classList.remove('open');
}

// 产品详情
function renderDetail(key) {
  const p = state.products[key];
  if (!p) return;

  document.getElementById('product-detail').style.display = 'block';
  document.getElementById('topbar-title').textContent = key;

  const types = Object.keys(p.builds || {});
  if (types.length === 0) {
    document.getElementById('product-detail').style.display = 'none';
    document.getElementById('empty-state').style.display = 'flex';
    return;
  }

  if (!state.activeBuildType || !p.builds[state.activeBuildType]) {
    state.activeBuildType = types[0];
  }

  const latestOrOnline = findOnlineOrLatest(p, types);
  const color = getColor(key);

  document.getElementById('product-hero').innerHTML = `
    <div class="hero-info">
      <div class="hero-icon" style="background:${color}20;color:${color}">${key[0].toUpperCase()}</div>
      <div class="hero-text">
        <h2>${key}</h2>
        <p>${p.description || `${types.length} 种构建 · ${countBuilds(p)} 个版本`}</p>
      </div>
    </div>
    <div class="hero-actions">
      ${latestOrOnline ? `
        <a href="${latestOrOnline.downloadUrl}" class="btn btn-accent" download>⬇ 下载${latestOrOnline.isOnline ? '线上版' : '最新版'}</a>
        <button class="btn btn-success" onclick="showQR('${key}','${latestOrOnline.downloadUrl}','v${latestOrOnline.version}')">📷 扫码</button>
      ` : ''}
    </div>`;

  document.getElementById('build-tabs').innerHTML = types.map(t => `
    <button class="build-tab ${state.activeBuildType === t ? 'active' : ''}" onclick="switchTab('${t}')">
      ${getBuildLabel(t)}<span class="tab-count">${p.builds[t].length}</span>
    </button>`).join('');

  renderVersions(p.builds[state.activeBuildType] || []);
}

function switchTab(t) {
  state.activeBuildType = t;
  renderDetail(state.activeProduct);
}

// 版本列表
function renderVersions(versions) {
  const el = document.getElementById('version-list');
  if (versions.length === 0) {
    el.innerHTML = '<div style="text-align:center;padding:40px;color:var(--text-muted);">暂无版本</div>';
    return;
  }

  el.innerHTML = versions.map((v, i) => `
    <div class="version-card ${v.isOnline ? 'is-online' : (i === 0 ? 'is-latest' : '')}">
      <div class="version-badge">
        <span class="version-number">v${v.version}</span>
        ${v.isOnline ? '<span class="online-tag">线上版</span>' : (i === 0 ? '<span class="latest-tag">最新</span>' : '')}
      </div>
      <div class="version-detail">
        <div class="version-filename">${v.filename}</div>
        <div class="version-meta">
          ${v.size ? `<span>📦 ${formatSize(v.size)}</span>` : ''}
          ${v.uploadTime ? `<span>🕐 ${formatTime(v.uploadTime)}</span>` : ''}
        </div>
        ${v.description ? `<div class="version-desc">${v.description}</div>` : ''}
      </div>
      <div class="version-actions">
        <button class="btn-qr-small" onclick="showQR('${state.activeProduct}','${v.downloadUrl}','v${v.version}')" title="扫码下载">📷</button>
        <a href="${v.downloadUrl}" class="btn-download" download>⬇ 下载</a>
      </div>
    </div>`).join('');
}

// 二维码
let qrInstance = null;

function showQR(product, url, version) {
  const modal = document.getElementById('qr-modal');
  document.getElementById('qr-title').textContent = `${product} ${version}`;

  const container = document.getElementById('qr-canvas');
  container.innerHTML = '';

  const fullUrl = url.startsWith('http') ? url : new URL(url, window.location.href).href;

  qrInstance = new QRCode(container, {
    text: fullUrl,
    width: 200,
    height: 200,
    colorDark: '#000000',
    colorLight: '#ffffff',
    correctLevel: QRCode.CorrectLevel.M
  });

  modal.style.display = 'flex';
}

function closeModal() {
  document.getElementById('qr-modal').style.display = 'none';
}

// 事件
document.getElementById('qr-modal').addEventListener('click', e => { if (e.target === e.currentTarget) closeModal(); });
document.getElementById('menu-toggle').addEventListener('click', () => { document.getElementById('sidebar').classList.toggle('open'); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeModal(); });

// 启动
loadData();
