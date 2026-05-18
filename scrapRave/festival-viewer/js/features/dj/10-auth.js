// Feature module extracted from monolith (viewer auth)
function normalizeBearerToken(value) {
  const token = String(value || '').trim();
  if (!token) return '';
  return token.toLowerCase().startsWith('bearer ') ? token : `Bearer ${token}`;
}

function getStoredViewerToken() {
  try {
    return normalizeBearerToken(localStorage.getItem(RAVER_AUTH_TOKEN_KEY) || '');
  } catch (_error) {
    return '';
  }
}

function setStoredViewerToken(token) {
  try {
    const value = normalizeBearerToken(token);
    if (value) localStorage.setItem(RAVER_AUTH_TOKEN_KEY, value);
    else localStorage.removeItem(RAVER_AUTH_TOKEN_KEY);
  } catch (_error) {
    // ignore
  }
}

function getStoredViewerUser() {
  try {
    const raw = localStorage.getItem(RAVER_AUTH_USER_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : null;
  } catch (_error) {
    return null;
  }
}

function setStoredViewerUser(user) {
  try {
    if (user && typeof user === 'object') localStorage.setItem(RAVER_AUTH_USER_KEY, JSON.stringify(user));
    else localStorage.removeItem(RAVER_AUTH_USER_KEY);
  } catch (_error) {
    // ignore
  }
}

function clearStoredViewerAuth() {
  try {
    localStorage.removeItem(RAVER_AUTH_TOKEN_KEY);
    localStorage.removeItem(RAVER_AUTH_USER_KEY);
  } catch (_error) {
    // ignore
  }
}

function getViewerAuthDisplayName() {
  const user = authState.user || {};
  return String(user.displayName || user.username || '').trim();
}

function getViewerAuthHeaders() {
  const token = normalizeBearerToken(authState.token);
  if (!token) return {};
  return { Authorization: token };
}

function setViewerLoginStatus(text, kind = '') {
  const el = document.getElementById('auth-login-status');
  if (!el) return;
  el.textContent = String(text || '');
  el.classList.toggle('error', kind === 'error');
  el.classList.toggle('ok', kind === 'ok');
}

function refreshViewerAuthButtons() {
  const loginBtn = document.getElementById('auth-login-open-btn');
  const logoutBtn = document.getElementById('auth-logout-btn');
  const closeBtn = document.getElementById('auth-login-close-btn');
  const name = getViewerAuthDisplayName();
  const hasToken = !!normalizeBearerToken(authState.token);
  if (loginBtn) {
    loginBtn.textContent = hasToken ? `账号: ${name || '已登录'}` : '登录';
  }
  if (logoutBtn) {
    logoutBtn.style.display = hasToken ? '' : 'none';
  }
  if (closeBtn) {
    closeBtn.style.display = hasToken ? '' : 'none';
  }
}

function openViewerLogin() {
  const overlay = document.getElementById('auth-gate-overlay');
  if (overlay) overlay.classList.add('open');
  document.body.classList.add('auth-locked');
  const name = getViewerAuthDisplayName();
  if (normalizeBearerToken(authState.token)) {
    setViewerLoginStatus(`当前已登录：${name || '未知账号'}，可继续切换账号`, 'ok');
  }
  refreshViewerAuthButtons();
}

function closeViewerLogin() {
  const overlay = document.getElementById('auth-gate-overlay');
  if (overlay) overlay.classList.remove('open');
  document.body.classList.remove('auth-locked');
  refreshViewerAuthButtons();
}

function fillDefaultViewerLogin() {
  const identifierInput = document.getElementById('auth-login-identifier');
  const passwordInput = document.getElementById('auth-login-password');
  if (identifierInput) identifierInput.value = 'uploadtester';
  if (passwordInput) passwordInput.value = '123456';
}

async function submitViewerLogin() {
  if (authState.loggingIn) return;
  const identifierInput = document.getElementById('auth-login-identifier');
  const passwordInput = document.getElementById('auth-login-password');
  const submitBtn = document.getElementById('auth-login-submit-btn');

  const identifier = String(identifierInput?.value || '').trim();
  const password = String(passwordInput?.value || '').trim();
  if (!identifier || !password) {
    setViewerLoginStatus('请输入账号和密码', 'error');
    return;
  }

  authState.loggingIn = true;
  if (submitBtn) submitBtn.disabled = true;
  setViewerLoginStatus('登录中...', '');

  try {
    const resp = await apiPost('/api/raver/auth/login', {
      identifier,
      password,
    });
    const token = normalizeBearerToken(resp?.token || '');
    if (!token) {
      throw new Error('登录成功但未返回 token');
    }
    authState.token = token;
    authState.user = (resp?.user && typeof resp.user === 'object') ? resp.user : null;
    setStoredViewerToken(token);
    setStoredViewerUser(authState.user);
    setViewerLoginStatus('登录成功', 'ok');
    closeViewerLogin();
    await startViewerAppIfNeeded();
    if (typeof refreshReviewPendingCount === 'function') {
      void refreshReviewPendingCount();
    }
  } catch (error) {
    const msg = String(error?.message || '未知错误');
    setViewerLoginStatus(`登录失败：${msg}`, 'error');
  } finally {
    authState.loggingIn = false;
    if (submitBtn) submitBtn.disabled = false;
    refreshViewerAuthButtons();
  }
}

function logoutViewerAuth() {
  authState.token = '';
  authState.user = null;
  clearStoredViewerAuth();
  if (typeof setReviewPendingCount === 'function') {
    setReviewPendingCount(0, {});
  }
  refreshViewerAuthButtons();
  openViewerLogin();
}

async function restoreViewerAuth() {
  authState.token = getStoredViewerToken();
  authState.user = getStoredViewerUser();
  refreshViewerAuthButtons();
  if (!authState.token) {
    openViewerLogin();
    return false;
  }
  try {
    await apiGet('/api/raver/profile/me', getViewerAuthHeaders());
    closeViewerLogin();
    if (typeof refreshReviewPendingCount === 'function') {
      void refreshReviewPendingCount();
    }
    return true;
  } catch (_error) {
    authState.token = '';
    authState.user = null;
    clearStoredViewerAuth();
    openViewerLogin();
    setViewerLoginStatus('登录已过期，请重新登录', 'error');
    return false;
  }
}
