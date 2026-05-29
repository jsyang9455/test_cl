/**
 * 로그인 컨트롤러
 * localStorage에 저장된 사용자 데이터와 대조하여 인증
 */
(() => {
  // ── DOM 참조 ──
  const form         = document.getElementById('loginForm');
  const emailInput   = document.getElementById('email');
  const pwInput      = document.getElementById('password');
  const togglePwBtn  = document.getElementById('togglePw');
  const submitBtn    = document.getElementById('submitBtn');
  const btnText      = document.getElementById('btnText');
  const btnSpinner   = document.getElementById('btnSpinner');

  const alertBanner  = document.getElementById('alertBanner');
  const alertMsg     = document.getElementById('alertMsg');

  const overlay      = document.getElementById('overlay');
  const confirmBtn   = document.getElementById('confirmBtn');
  const popupName    = document.getElementById('popupName');
  const popupEmail   = document.getElementById('popupEmail');

  // ── 유틸 ──
  function showFieldError(inputEl, errId, message) {
    inputEl.classList.add('invalid');
    inputEl.classList.remove('valid');
    document.getElementById(errId).textContent = message;
  }

  function clearFieldError(inputEl, errId) {
    inputEl.classList.remove('invalid', 'valid');
    document.getElementById(errId).textContent = '';
  }

  function showBanner(message) {
    alertMsg.textContent = message;
    alertBanner.classList.remove('hidden');
    // 배너를 제거했다가 다시 추가해 shake 애니메이션 재실행
    alertBanner.classList.remove('shake-reset');
    void alertBanner.offsetWidth;
  }

  function hideBanner() {
    alertBanner.classList.add('hidden');
    alertMsg.textContent = '';
  }

  function setLoading(on) {
    submitBtn.disabled = on;
    btnText.classList.toggle('hidden', on);
    btnSpinner.classList.toggle('hidden', !on);
  }

  // ── 비밀번호 표시/숨김 ──
  togglePwBtn.addEventListener('click', () => {
    const isText = pwInput.type === 'text';
    pwInput.type = isText ? 'password' : 'text';
    togglePwBtn.textContent = isText ? '👁' : '🙈';
    togglePwBtn.setAttribute('aria-label', isText ? '비밀번호 표시' : '비밀번호 숨김');
  });

  // ── 입력 시 에러 초기화 ──
  emailInput.addEventListener('input', () => {
    clearFieldError(emailInput, 'err-email');
    hideBanner();
  });
  pwInput.addEventListener('input', () => {
    clearFieldError(pwInput, 'err-password');
    hideBanner();
  });

  // ── 폼 제출 ──
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    hideBanner();

    const email    = emailInput.value.trim();
    const password = pwInput.value;

    // 기본 입력 검증
    let hasError = false;
    if (!email) {
      showFieldError(emailInput, 'err-email', '이메일을 입력해 주세요.');
      hasError = true;
    }
    if (!password) {
      showFieldError(pwInput, 'err-password', '비밀번호를 입력해 주세요.');
      hasError = true;
    }
    if (hasError) return;

    setLoading(true);

    try {
      // localStorage에서 이메일 일치 사용자 탐색
      const users = UserStorage.getAll();
      const user  = users.find(u => u.email === email.toLowerCase());

      if (!user) {
        // 이메일 미존재 — 계정 정보 노출 방지를 위해 동일 메시지 사용
        showBanner('이메일 또는 비밀번호가 올바르지 않습니다.');
        emailInput.classList.add('invalid');
        pwInput.classList.add('invalid');
        pwInput.value = '';
        emailInput.focus();
        return;
      }

      // 비밀번호 해시 검증
      const isMatch = await PasswordCrypto.verifyPassword(
        password,
        user.passwordHash,
        user.passwordSalt
      );

      if (!isMatch) {
        showBanner('이메일 또는 비밀번호가 올바르지 않습니다.');
        pwInput.classList.add('invalid');
        pwInput.value = '';
        pwInput.focus();
        return;
      }

      // 로그인 성공
      emailInput.classList.add('valid');
      pwInput.classList.add('valid');
      popupName.textContent  = user.name;
      popupEmail.textContent = user.email;
      overlay.classList.remove('hidden');
      confirmBtn.focus();

    } catch (err) {
      showBanner('오류가 발생했습니다. 다시 시도해 주세요.');
      console.error(err);
    } finally {
      setLoading(false);
    }
  });

  // ── 팝업 닫기 ──
  confirmBtn.addEventListener('click', () => {
    overlay.classList.add('hidden');
    form.reset();
    clearFieldError(emailInput, 'err-email');
    clearFieldError(pwInput, 'err-password');
    emailInput.focus();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !overlay.classList.contains('hidden')) {
      confirmBtn.click();
    }
  });
})();
