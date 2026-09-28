// 游迹 AI 旅游平台 V0.1 — Admin Console SPA

const state = {
  apiBase: localStorage.getItem('youpji_api_base') || 'http://127.0.0.1:8081',
  token: localStorage.getItem('youpji_admin_token') || '',
  user: null,
  currentTab: 'dashboard',
  cache: {},
};

// API Client
async function api(path, options = {}) {
  const url = `${state.apiBase}${path}`;
  const headers = {
    'Content-Type': 'application/json',
    ...(state.token ? { Authorization: `Bearer ${state.token}` } : {}),
    ...options.headers,
  };

  try {
    const res = await fetch(url, { ...options, headers });
    if (res.status === 401) {
      toast('登录会话已过期，请重新登录', 'error');
      logout();
      return null;
    }
    const data = await res.json().catch(() => null);
    if (!res.ok) {
      const msg = data?.message || `请求失败 (${res.status})`;
      toast(msg, 'error');
      throw new Error(msg);
    }
    return data;
  } catch (err) {
    if (!err.message.includes('401')) {
      toast(err.message || '网络连接失败', 'error');
    }
    throw err;
  }
}

// Toast
function toast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const t = document.createElement('div');
  t.className = `toast toast-${type}`;
  t.textContent = message;
  container.appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

// Auth
async function checkAuth() {
  if (!state.token) {
    showLoginModal();
    return false;
  }
  try {
    const user = await api('/api/v1/auth/me');
    if (!user || user.role !== 'admin') {
      toast('无管理员访问权限', 'error');
      logout();
      return false;
    }
    state.user = user;
    document.getElementById('current-user-name').textContent = user.display_name || user.role;
    hideLoginModal();
    return true;
  } catch {
    showLoginModal();
    return false;
  }
}

function login(token) {
  state.token = token;
  localStorage.setItem('youpji_admin_token', token);
  checkAuth().then(ok => {
    if (ok) {
      toast('登录成功');
      loadTab(state.currentTab);
    }
  });
}

function logout() {
  state.token = '';
  state.user = null;
  localStorage.removeItem('youpji_admin_token');
  showLoginModal();
}

function showLoginModal() {
  document.getElementById('login-modal').style.display = 'flex';
}

function hideLoginModal() {
  document.getElementById('login-modal').style.display = 'none';
}

// Navigation
function switchTab(tab) {
  state.currentTab = tab;
  document.querySelectorAll('.nav-item').forEach(el => {
    el.classList.toggle('active', el.dataset.tab === tab);
  });
  loadTab(tab);
}

async function loadTab(tab) {
  const container = document.getElementById('view-container');
  container.innerHTML = '<div style="padding:40px;text-align:center;color:#64748b;">加载中...</div>';

  switch (tab) {
    case 'dashboard':
      await renderDashboard(container);
      break;
    case 'attractions':
      await renderAttractions(container);
      break;
    case 'hours-review':
      await renderHoursReview(container);
      break;
    case 'data-reviews':
      await renderDataReviews(container);
      break;
    case 'users':
      await renderUsers(container);
      break;
    case 'audit-logs':
      await renderAuditLogs(container);
      break;
    case 'settings':
      renderSettings(container);
      break;
    default:
      container.innerHTML = '页面不存在';
  }
}

// 1. Dashboard View
async function renderDashboard(container) {
  try {
    const stats = await api('/api/v1/admin/dashboard');
    if (!stats) return;

    const verifyRate = stats.attractions_count > 0 
      ? Math.round((stats.attractions_verified / stats.attractions_count) * 100) 
      : 0;

    container.innerHTML = `
      <div class="stat-grid">
        <div class="stat-card">
          <div class="stat-label">景区总数</div>
          <div class="stat-value">${stats.attractions_count}</div>
          <div class="stat-sub">已核验: <b>${stats.attractions_verified}</b> · 待核验: ${stats.attractions_pending}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">事实验证达标率</div>
          <div class="stat-value">${verifyRate}%</div>
          <div class="stat-sub">包含官方门票与开放时间双源核验</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">待审核时段</div>
          <div class="stat-value" style="color:var(--warning);">${stats.pending_hours_count}</div>
          <div class="stat-sub"><a href="#" onclick="switchTab('hours-review');return false;" style="color:var(--accent);">立即前往审核 &rarr;</a></div>
        </div>
        <div class="stat-card">
          <div class="stat-label">数据审核任务</div>
          <div class="stat-value">${stats.pending_reviews_count}</div>
          <div class="stat-sub">待审核数据变更提议</div>
        </div>
      </div>

      <div class="stat-grid" style="grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));">
        <div class="stat-card">
          <div class="stat-label">酒店资源</div>
          <div class="stat-value" style="font-size:22px;">${stats.hotels_count}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">特色餐饮</div>
          <div class="stat-value" style="font-size:22px;">${stats.restaurants_count}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">累计规划行程</div>
          <div class="stat-value" style="font-size:22px;">${stats.itineraries_count}</div>
          <div class="stat-sub">近7天新增: ${stats.itineraries_recent_7d}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">注册用户数</div>
          <div class="stat-value" style="font-size:22px;">${stats.users_count}</div>
        </div>
      </div>

      <div class="card">
        <div class="card-header">
          <div class="card-title">V0.1 闭环数据与运营准则</div>
        </div>
        <div class="card-body" style="font-size:14px;line-height:1.7;color:#334155;">
          <p>• <b>铁律 4（AI 不决定事实）</b>：门票、开放时间、交通价格必须查库查源并带验证状态，禁止由大模型凭空断言。</p>
          <p>• <b>来源分级体系</b>：一级（政府/景区官方）&gt; 二级（地图/平台）&gt; 三级（攻略UGC）&gt; 四级（AI生成）。重要事实必须核对一级来源。</p>
          <p>• <b>第一条闭环</b>：贵阳 &rarr; 安顺（黄果树/龙宫/天龙屯堡）高价值两日游路线，全要素数据优先达标。</p>
        </div>
      </div>
    `;
  } catch (e) {
    container.innerHTML = `<div class="card"><div class="card-body" style="color:var(--danger)">加载仪表盘数据失败: ${e.message}</div></div>`;
  }
}

// 2. Attractions View
let attractionPage = 0;
async function renderAttractions(container) {
  const city = state.attractionCity || '';
  const status = state.attractionStatus || '';
  const q = state.attractionQ || '';

  container.innerHTML = `
    <div class="filter-bar">
      <input type="text" id="attr-search" class="input" placeholder="按景区名称/别名搜索..." value="${q}" style="min-width:240px;" />
      <select id="attr-city" class="select">
        <option value="">全部市州</option>
        ${['贵阳', '安顺', '遵义', '六盘水', '毕节', '铜仁', '黔东南', '黔南', '黔西南'].map(c => `<option value="${c}" ${c === city ? 'selected' : ''}>${c}</option>`).join('')}
      </select>
      <select id="attr-status" class="select">
        <option value="">全部验证状态</option>
        <option value="verified" ${status === 'verified' ? 'selected' : ''}>已核验 (verified)</option>
        <option value="pending" ${status === 'pending' ? 'selected' : ''}>待核验 (pending)</option>
        <option value="disputed" ${status === 'disputed' ? 'selected' : ''}>有争议 (disputed)</option>
      </select>
      <button class="btn btn-primary" id="attr-filter-btn">查询</button>
    </div>

    <div class="card">
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>景区名称</th>
              <th>市州</th>
              <th>等级</th>
              <th>门票价格</th>
              <th>开放时间</th>
              <th>验证状态</th>
              <th>来源类型</th>
              <th>置信度</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody id="attr-table-body">
            <tr><td colspan="9" style="text-align:center;">加载中...</td></tr>
          </tbody>
        </table>
      </div>
      <div class="card-header" style="justify-content: flex-end; gap: 10px;">
        <button class="btn btn-outline btn-sm" id="attr-prev-btn">上一页</button>
        <span id="attr-page-info" style="font-size:13px;color:var(--text-muted);display:flex;align-items:center;">第 1 页</span>
        <button class="btn btn-outline btn-sm" id="attr-next-btn">下一页</button>
      </div>
    </div>
  `;

  document.getElementById('attr-filter-btn').onclick = () => {
    state.attractionCity = document.getElementById('attr-city').value;
    state.attractionStatus = document.getElementById('attr-status').value;
    state.attractionQ = document.getElementById('attr-search').value.trim();
    attractionPage = 0;
    fetchAttractionsTable();
  };

  document.getElementById('attr-prev-btn').onclick = () => {
    if (attractionPage > 0) {
      attractionPage--;
      fetchAttractionsTable();
    }
  };

  document.getElementById('attr-next-btn').onclick = () => {
    attractionPage++;
    fetchAttractionsTable();
  };

  fetchAttractionsTable();
}

async function fetchAttractionsTable() {
  const tbody = document.getElementById('attr-table-body');
  if (!tbody) return;

  const params = new URLSearchParams({
    page: attractionPage,
    page_size: 20,
    ...(state.attractionCity ? { city: state.attractionCity } : {}),
    ...(state.attractionStatus ? { verification_status: state.attractionStatus } : {}),
    ...(state.attractionQ ? { q: state.attractionQ } : {}),
  });

  const res = await api(`/api/v1/admin/attractions?${params}`);
  if (!res) return;

  const items = res.items || [];
  document.getElementById('attr-page-info').textContent = `第 ${attractionPage + 1} 页 (${items.length} 条)`;

  if (items.length === 0) {
    tbody.innerHTML = '<tr><td colspan="9" style="text-align:center;color:#94a3b8;">无符合条件记录</td></tr>';
    return;
  }

  tbody.innerHTML = items.map(a => `
    <tr>
      <td><b>${a.name}</b>${a.alias ? `<br><small style="color:#64748b">${a.alias}</small>` : ''}</td>
      <td>${a.city || '-'}</td>
      <td>${a.level || '-'}</td>
      <td>${a.ticket_price != null ? `¥${a.ticket_price}` : '<span style="color:#94a3b8">未知</span>'}</td>
      <td>${a.opening_time ? `${a.opening_time.slice(0,5)} - ${a.closing_time ? a.closing_time.slice(0,5) : '?'}` : '<span style="color:#94a3b8">未核对</span>'}</td>
      <td><span class="badge badge-${a.verification_status}">${a.verification_status}</span></td>
      <td><span style="font-size:12px;color:#475569;">${a.source_type || '-'}</span></td>
      <td>${(a.confidence * 100).toFixed(0)}%</td>
      <td>
        <button class="btn btn-primary btn-sm" onclick="openVerifyModal('${a.id}')">核验/编辑</button>
      </td>
    </tr>
  `).join('');
}

// Verify Modal
window.openVerifyModal = async function(id) {
  const detail = await api(`/api/v1/admin/attractions/${id}`);
  if (!detail) return;
  const base = detail.base || detail;

  const modal = document.createElement('div');
  modal.className = 'modal-overlay';
  modal.id = 'active-modal';
  modal.innerHTML = `
    <div class="modal-content">
      <div class="modal-header">
        <h3 style="font-size:16px;font-weight:600;">核验景区事实 — ${base.name}</h3>
        <button class="btn btn-outline btn-sm" onclick="document.getElementById('active-modal').remove()">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-group">
          <label class="form-label">市州 / 行政区</label>
          <input type="text" class="input" style="width:100%;" value="${base.city || ''} ${base.district || ''}" disabled />
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div class="form-group">
            <label class="form-label">门票价格 (元)</label>
            <input type="number" class="input" id="modal-ticket" style="width:100%;" value="${base.ticket_price ?? ''}" placeholder="例如 160" />
          </div>
          <div class="form-group">
            <label class="form-label">置信度 (0.0 - 1.0)</label>
            <input type="number" step="0.05" class="input" id="modal-confidence" style="width:100%;" value="${base.confidence ?? 0.85}" />
          </div>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <div class="form-group">
            <label class="form-label">开园时间</label>
            <input type="text" class="input" id="modal-open" style="width:100%;" value="${base.opening_time ? base.opening_time.slice(0,5) : ''}" placeholder="HH:MM 如 07:00" />
          </div>
          <div class="form-group">
            <label class="form-label">闭园时间</label>
            <input type="text" class="input" id="modal-close" style="width:100%;" value="${base.closing_time ? base.closing_time.slice(0,5) : ''}" placeholder="HH:MM 如 18:00" />
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">来源权威 URL (支持政府/官网/平台)</label>
          <input type="text" class="input" id="modal-url" style="width:100%;" value="${base.source_url || ''}" placeholder="https://..." />
        </div>
        <div class="form-group">
          <label class="form-label">核验状态标记</label>
          <select id="modal-status" class="select" style="width:100%;">
            <option value="verified" ${base.verification_status === 'verified' ? 'selected' : ''}>已核验 (verified — 事实双全)</option>
            <option value="pending" ${base.verification_status === 'pending' ? 'selected' : ''}>待核验 (pending)</option>
            <option value="disputed" ${base.verification_status === 'disputed' ? 'selected' : ''}>有争议 (disputed)</option>
          </select>
        </div>
      </div>
      <div class="modal-footer">
        <button class="btn btn-outline" onclick="document.getElementById('active-modal').remove()">取消</button>
        <button class="btn btn-primary" onclick="submitVerify('${id}')">确认提交核验</button>
      </div>
    </div>
  `;
  document.body.appendChild(modal);
};

window.submitVerify = async function(id) {
  const ticket = document.getElementById('modal-ticket').value;
  const confidence = parseFloat(document.getElementById('modal-confidence').value) || 0.85;
  const openTime = document.getElementById('modal-open').value.trim();
  const closeTime = document.getElementById('modal-close').value.trim();
  const sourceUrl = document.getElementById('modal-url').value.trim();
  const status = document.getElementById('modal-status').value;

  const payload = {
    verification_status: status,
    confidence: confidence,
    source_url: sourceUrl || null,
    source_type: sourceUrl.includes('gov.cn') ? 'government' : 'official',
    ticket_price: ticket !== '' ? parseInt(ticket, 10) : null,
    opening_time: openTime ? `${openTime}:00`.slice(0, 8) : null,
    closing_time: closeTime ? `${closeTime}:00`.slice(0, 8) : null,
  };

  try {
    await api(`/api/v1/admin/attractions/${id}/verify`, {
      method: 'POST',
      body: JSON.stringify(payload),
    });
    toast('核验状态更新成功！');
    document.getElementById('active-modal').remove();
    fetchAttractionsTable();
  } catch {}
};

// 3. Hours Review View
async function renderHoursReview(container) {
  container.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div class="card-title">待审核高德营业时段 (二级来源候选池)</div>
        <button class="btn btn-outline btn-sm" onclick="loadTab('hours-review')">刷新列表</button>
      </div>
      <div class="card-body">
        <p style="font-size:13px;color:var(--text-muted);margin-bottom:16px;">
          以下时段抽取自高德 POI 营业时间描述（二级来源，confidence=0.55）。
          人工核准后可升级为 verified，并可自动回写景区的每日开闭园时间。
        </p>
        <div id="hours-list" style="display:flex;flex-direction:column;gap:12px;">加载中...</div>
      </div>
    </div>
  `;

  const rows = await api('/api/v1/admin/hours-review?status=pending&limit=30');
  const listEl = document.getElementById('hours-list');
  if (!rows || rows.length === 0) {
    listEl.innerHTML = '<div style="color:#64748b;padding:20px;text-align:center;">暂无待审核营业时段！所有候选时段已完成初审。</div>';
    return;
  }

  listEl.innerHTML = rows.map(h => `
    <div class="card" style="margin-bottom:0;border-left:4px solid var(--warning);">
      <div class="card-header" style="background:#fcfcfc;">
        <div>
          <b style="font-size:15px;">${h.attraction_name}</b>
          <span style="font-size:12px;color:var(--text-muted);margin-left:8px;">${h.city || ''}</span>
          ${h.season ? `<span class="badge" style="background:#f1f5f9;margin-left:8px;">${h.season}</span>` : ''}
        </div>
        <div>
          <span class="badge badge-pending">待核对</span>
        </div>
      </div>
      <div class="card-body" style="display:flex;justify-content:space-between;align-items:center;">
        <div>
          <div style="font-size:16px;font-weight:600;color:var(--primary);margin-bottom:4px;">
            ${h.open_time.slice(0, 5)} - ${h.close_time.slice(0, 5)}
          </div>
          <div style="font-size:13px;color:var(--text-muted);">
            适用星期: ${h.weekday != null ? `周${['日','一','二','三','四','五','六'][h.weekday]}` : '每日'} · 
            来源: ${h.source_type} · ${h.note || '高德地图时段抽取'}
          </div>
        </div>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-success btn-sm" onclick="approveHours('${h.id}')">采纳并回写景区</button>
          <button class="btn btn-danger btn-sm" onclick="rejectHours('${h.id}')">驳回</button>
        </div>
      </div>
    </div>
  `).join('');
}

window.approveHours = async function(id) {
  try {
    await api(`/api/v1/admin/hours-review/${id}/approve`, {
      method: 'POST',
      body: JSON.stringify({ writeback: true }),
    });
    toast('已采纳该时段，并回写景区！');
    loadTab('hours-review');
  } catch {}
};

window.rejectHours = async function(id) {
  const reason = prompt('请输入驳回理由 (如: 与官方公示冲突):');
  if (!reason) return;
  try {
    await api(`/api/v1/admin/hours-review/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    });
    toast('已驳回该时段');
    loadTab('hours-review');
  } catch {}
};

// 4. Data Reviews View
async function renderDataReviews(container) {
  container.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div class="card-title">通用数据审核任务队列</div>
        <button class="btn btn-outline btn-sm" onclick="loadTab('data-reviews')">刷新</button>
      </div>
      <div class="card-body">
        <div id="review-list">加载中...</div>
      </div>
    </div>
  `;

  const rows = await api('/api/v1/admin/data-reviews?status=pending');
  const el = document.getElementById('review-list');
  if (!rows || rows.length === 0) {
    el.innerHTML = '<div style="color:#64748b;padding:20px;text-align:center;">暂无待审核任务</div>';
    return;
  }

  el.innerHTML = rows.map(r => `
    <div class="card" style="margin-bottom:12px;">
      <div class="card-header">
        <b>实体: ${r.entity_type}</b> (ID: ${r.entity_id})
        <span class="badge badge-pending">待审批</span>
      </div>
      <div class="card-body" style="display:flex;justify-content:space-between;align-items:center;">
        <div>
          <div>字段: <code>${r.field || '全量变更'}</code></div>
          <div style="font-size:12px;color:var(--text-muted);margin-top:4px;">提议值: ${JSON.stringify(r.proposed)}</div>
        </div>
        <div style="display:flex;gap:8px;">
          <button class="btn btn-success btn-sm" onclick="approveDataReview('${r.id}')">采纳</button>
          <button class="btn btn-danger btn-sm" onclick="rejectDataReview('${r.id}')">驳回</button>
        </div>
      </div>
    </div>
  `).join('');
}

window.approveDataReview = async function(id) {
  try {
    await api(`/api/v1/admin/data-reviews/${id}/approve`, { method: 'POST' });
    toast('审核采纳成功！');
    loadTab('data-reviews');
  } catch {}
};

window.rejectDataReview = async function(id) {
  const reason = prompt('请输入驳回原因:');
  if (!reason) return;
  try {
    await api(`/api/v1/admin/data-reviews/${id}/reject`, {
      method: 'POST',
      body: JSON.stringify({ reason }),
    });
    toast('已驳回该审核任务');
    loadTab('data-reviews');
  } catch {}
};

// 5. Users View
async function renderUsers(container) {
  container.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div class="card-title">系统用户与角色管理</div>
      </div>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>昵称</th>
              <th>手机 / 邮箱</th>
              <th>当前角色</th>
              <th>注册时间</th>
              <th>操作</th>
            </tr>
          </thead>
          <tbody id="users-table-body">
            <tr><td colspan="6" style="text-align:center;">加载中...</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  `;

  const rows = await api('/api/v1/admin/users?limit=50');
  const tbody = document.getElementById('users-table-body');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;">暂无用户数据</td></tr>';
    return;
  }

  tbody.innerHTML = rows.map(u => `
    <tr>
      <td><small style="color:#64748b;">${u.id.slice(0, 8)}...</small></td>
      <td><b>${u.display_name || '-'}</b></td>
      <td>${u.phone || u.email || '-'}</td>
      <td><span class="badge badge-${u.role}">${u.role}</span></td>
      <td>${new Date(u.created_at).toLocaleDateString()}</td>
      <td>
        ${u.role === 'admin' 
          ? `<button class="btn btn-outline btn-sm" onclick="changeUserRole('${u.id}', 'user')">降为普通用户</button>`
          : `<button class="btn btn-primary btn-sm" onclick="changeUserRole('${u.id}', 'admin')">升为管理员</button>`
        }
      </td>
    </tr>
  `).join('');
}

window.changeUserRole = async function(id, newRole) {
  if (!confirm(`确定要将该用户角色切换为「${newRole}」吗？`)) return;
  try {
    await api(`/api/v1/admin/users/${id}/role`, {
      method: 'PATCH',
      body: JSON.stringify({ role: newRole }),
    });
    toast('角色权限更新成功！');
    loadTab('users');
  } catch {}
};

// 6. Audit Logs View
async function renderAuditLogs(container) {
  container.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div class="card-title">管理操作审计留痕 (全量审计)</div>
      </div>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th>操作时间</th>
              <th>管理员</th>
              <th>动作</th>
              <th>目标实体</th>
              <th>详细信息</th>
            </tr>
          </thead>
          <tbody id="audit-table-body">
            <tr><td colspan="5" style="text-align:center;">加载中...</td></tr>
          </tbody>
        </table>
      </div>
    </div>
  `;

  const rows = await api('/api/v1/admin/audit-logs?limit=50');
  const tbody = document.getElementById('audit-table-body');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="5" style="text-align:center;color:#94a3b8;">暂无审计日志</td></tr>';
    return;
  }

  tbody.innerHTML = rows.map(l => `
    <tr>
      <td style="white-space:nowrap;font-size:12px;color:var(--text-muted);">${new Date(l.created_at).toLocaleString()}</td>
      <td><b>${l.admin_name || l.admin_id.slice(0, 8)}</b></td>
      <td><code>${l.action}</code></td>
      <td>${l.entity_type || '-'} ${l.entity_id ? `<small style="color:#64748b;">(${l.entity_id.slice(0, 6)}...)</small>` : ''}</td>
      <td style="font-size:12px;max-width:300px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
        ${JSON.stringify(l.detail)}
      </td>
    </tr>
  `).join('');
}

// 7. Settings View
function renderSettings(container) {
  container.innerHTML = `
    <div class="card">
      <div class="card-header">
        <div class="card-title">系统与网络配置</div>
      </div>
      <div class="card-body">
        <div class="form-group">
          <label class="form-label">后端 API 服务地址</label>
          <input type="text" class="input" id="cfg-api-base" style="width:100%;max-width:400px;" value="${state.apiBase}" />
          <div style="font-size:12px;color:var(--text-muted);margin-top:6px;">默认 http://127.0.0.1:8081</div>
        </div>
        <button class="btn btn-primary" onclick="saveSettings()">保存配置</button>
      </div>
    </div>
  `;
}

window.saveSettings = function() {
  const base = document.getElementById('cfg-api-base').value.trim();
  if (base) {
    state.apiBase = base;
    localStorage.setItem('youpji_api_base', base);
    toast('API 地址已保存');
  }
};

// Global Init
document.addEventListener('DOMContentLoaded', () => {
  // Navigation tabs
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.onclick = () => switchTab(btn.dataset.tab);
  });

  // Login form
  const loginForm = document.getElementById('login-form');
  if (loginForm) {
    loginForm.onsubmit = async (e) => {
      e.preventDefault();
      const account = document.getElementById('login-account').value.trim();
      const password = document.getElementById('login-password').value;
      try {
        const body = account.includes('@') ? { email: account, password } : { phone: account, password };
        const res = await fetch(`${state.apiBase}/api/v1/auth/login`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        const data = await res.json();
        if (!res.ok) throw new Error(data.message || '登录失败');
        if (data.user?.role !== 'admin') throw new Error('该账号非管理员，无权登录后台');
        login(data.token);
      } catch (err) {
        toast(err.message, 'error');
      }
    };
  }

  // Logout button
  const logoutBtn = document.getElementById('logout-btn');
  if (logoutBtn) {
    logoutBtn.onclick = logout;
  }

  // Auth check & load initial view
  checkAuth().then(ok => {
    if (ok) {
      loadTab('dashboard');
    }
  });
});
