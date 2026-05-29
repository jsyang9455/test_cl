/**
 * 회원가입 앱 메인 컨트롤러
 */
(() => {
  // ── DOM 참조 ──
  const form            = document.getElementById('signupForm');
  const emailInput      = document.getElementById('email');
  const nameInput       = document.getElementById('name');
  const pwInput         = document.getElementById('password');
  const pwConfirmInput  = document.getElementById('passwordConfirm');
  const agreeInput      = document.getElementById('agree');
  const togglePwBtn     = document.getElementById('togglePw');
  const submitBtn       = document.getElementById('submitBtn');
  const btnText         = document.getElementById('btnText');
  const btnSpinner      = document.getElementById('btnSpinner');

  const cntName         = document.getElementById('cnt-name');
  const cntPw           = document.getElementById('cnt-password');
  const strengthFill    = document.getElementById('strengthFill');
  const strengthLabel   = document.getElementById('strengthLabel');

  const overlay         = document.getElementById('overlay');
  const confirmBtn      = document.getElementById('confirmBtn');
  const popupName       = document.getElementById('popupName');
  const popupEmail      = document.getElementById('popupEmail');

  // ── 유틸 ──
  function setFieldState(fieldId, inputEl, error) {
    const field = document.getElementById(fieldId);
    const errEl = document.getElementById('err-' + fieldId.replace('field-', ''));
    if (error) {
      inputEl.classList.add('invalid');
      inputEl.classList.remove('valid');
      if (errEl) errEl.textContent = error;
    } else {
      inputEl.classList.remove('invalid');
      inputEl.classList.add('valid');
      if (errEl) errEl.textContent = '';
    }
  }

  function clearFieldState(inputEl, errId) {
    inputEl.classList.remove('valid', 'invalid');
    const errEl = document.getElementById(errId);
    if (errEl) errEl.textContent = '';
  }

  // ── 실시간 글자수 ──
  nameInput.addEventListener('input', () => {
    const len = nameInput.value.length;
    cntName.textContent = `${len} / 10`;
    cntName.style.color = len >= 10 ? '#ef4444' : '#aaa';
  });

  pwInput.addEventListener('input', () => {
    const val = pwInput.value;
    cntPw.textContent = `${val.length} / 10`;
    cntPw.style.color = val.length >= 10 ? '#ef4444' : '#aaa';

    // 강도 바
    const { score, label, color } = Validator.measureStrength(val);
    const pct = score === 0 ? 0 : (score / 4) * 100;
    strengthFill.style.width = pct + '%';
    strengthFill.style.background = color;
    strengthLabel.textContent = label;
    strengthLabel.style.color = color;
  });

  // ── 비밀번호 표시/숨김 ──
  togglePwBtn.addEventListener('click', () => {
    const isText = pwInput.type === 'text';
    pwInput.type = isText ? 'password' : 'text';
    togglePwBtn.textContent = isText ? '👁' : '🙈';
    togglePwBtn.setAttribute('aria-label', isText ? '비밀번호 표시' : '비밀번호 숨김');
  });

  // ── 블러 시 즉시 검증 ──
  emailInput.addEventListener('blur', () => {
    const err = Validator.validateEmail(emailInput.value);
    setFieldState('field-email', emailInput, err);
    if (!err && UserStorage.isEmailTaken(emailInput.value)) {
      setFieldState('field-email', emailInput, '이미 사용 중인 이메일입니다.');
    }
  });

  nameInput.addEventListener('blur', () => {
    const err = Validator.validateName(nameInput.value);
    setFieldState('field-name', nameInput, err);
  });

  pwInput.addEventListener('blur', () => {
    const err = Validator.validatePassword(pwInput.value);
    setFieldState('field-password', pwInput, err);
  });

  pwConfirmInput.addEventListener('blur', () => {
    const err = Validator.validatePasswordConfirm(pwInput.value, pwConfirmInput.value);
    setFieldState('field-passwordConfirm', pwConfirmInput, err);
  });

  // 입력 시 에러 초기화
  [emailInput, nameInput, pwInput, pwConfirmInput].forEach(el => {
    el.addEventListener('input', () => {
      el.classList.remove('invalid');
      const errId = 'err-' + el.id;
      const errEl = document.getElementById(errId);
      if (errEl && el.value.length > 0) errEl.textContent = '';
    });
  });

  // ── 폼 제출 ──
  form.addEventListener('submit', async (e) => {
    e.preventDefault();

    // 전체 검증
    const emailErr   = Validator.validateEmail(emailInput.value)
      || (UserStorage.isEmailTaken(emailInput.value) ? '이미 사용 중인 이메일입니다.' : null);
    const nameErr    = Validator.validateName(nameInput.value);
    const pwErr      = Validator.validatePassword(pwInput.value);
    const pwConfErr  = Validator.validatePasswordConfirm(pwInput.value, pwConfirmInput.value);
    const agreeErr   = Validator.validateAgree(agreeInput.checked);

    setFieldState('field-email', emailInput, emailErr);
    setFieldState('field-name', nameInput, nameErr);
    setFieldState('field-password', pwInput, pwErr);
    setFieldState('field-passwordConfirm', pwConfirmInput, pwConfErr);
    document.getElementById('err-agree').textContent = agreeErr || '';

    if (emailErr || nameErr || pwErr || pwConfErr || agreeErr) {
      // 첫 번째 에러 필드로 포커스
      if (emailErr)  { emailInput.focus(); return; }
      if (nameErr)   { nameInput.focus(); return; }
      if (pwErr)     { pwInput.focus(); return; }
      if (pwConfErr) { pwConfirmInput.focus(); return; }
      return;
    }

    // 로딩 상태
    submitBtn.disabled = true;
    btnText.classList.add('hidden');
    btnSpinner.classList.remove('hidden');

    try {
      // 비밀번호 해싱 (Web Crypto PBKDF2)
      const { hash, salt } = await PasswordCrypto.hashPassword(pwInput.value);

      // 저장
      const result = UserStorage.registerUser({
        email: emailInput.value,
        name: nameInput.value,
        passwordHash: hash,
        passwordSalt: salt,
      });

      if (!result.success) {
        setFieldState('field-email', emailInput, result.message);
        return;
      }

      // 성공 팝업
      popupName.textContent  = nameInput.value.trim();
      popupEmail.textContent = emailInput.value.trim().toLowerCase();
      overlay.classList.remove('hidden');
      confirmBtn.focus();

    } catch (err) {
      alert('오류가 발생했습니다. 다시 시도해 주세요.');
      console.error(err);
    } finally {
      submitBtn.disabled = false;
      btnText.classList.remove('hidden');
      btnSpinner.classList.add('hidden');
    }
  });

  // ── 팝업 닫기 ──
  confirmBtn.addEventListener('click', () => {
    overlay.classList.add('hidden');
    form.reset();
    cntName.textContent    = '0 / 10';
    cntPw.textContent      = '0 / 10';
    strengthFill.style.width = '0%';
    strengthLabel.textContent = '';
    [emailInput, nameInput, pwInput, pwConfirmInput].forEach(el =>
      el.classList.remove('valid', 'invalid')
    );
    emailInput.focus();
  });

  // ESC로 팝업 닫기
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !overlay.classList.contains('hidden')) {
      confirmBtn.click();
    }
  });

  // 오버레이 바깥 클릭 무시 (의도적 닫기만 허용)
})();
