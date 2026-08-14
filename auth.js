/**
 * 前端访问密码验证
 * 密码哈希存储在 config.json 中，不在代码里硬编码明文密码
 * 验证通过后 sessionStorage 记录状态，关闭标签页后失效
 */

const AUTH_KEY = 'apk_download_auth';

// SHA-256 哈希
async function sha256(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// 检查是否已登录
function checkAuth() {
  if (sessionStorage.getItem(AUTH_KEY) === 'true') {
    showApp();
  }
}

// 显示主应用
function showApp() {
  document.getElementById('auth-gate').style.display = 'none';
  document.getElementById('app-layout').style.display = 'flex';
  // 触发数据加载
  if (typeof loadData === 'function') loadData();
}

// 处理登录
async function handleLogin(e) {
  e.preventDefault();
  const input = document.getElementById('auth-input');
  const error = document.getElementById('auth-error');
  const password = input.value.trim();

  if (!password) return false;

  try {
    // 从 config.json 读取密码哈希
    const res = await fetch('config.json?' + Date.now());
    const config = await res.json();
    const hash = await sha256(password);

    if (hash === config.passwordHash) {
      sessionStorage.setItem(AUTH_KEY, 'true');
      error.style.display = 'none';
      showApp();
    } else {
      error.style.display = 'block';
      input.value = '';
      input.focus();
    }
  } catch (err) {
    console.error('验证失败:', err);
    error.textContent = '验证失败，请重试';
    error.style.display = 'block';
  }

  return false;
}

// 页面加载时检查
checkAuth();
