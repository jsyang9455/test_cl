/**
 * 입력값 유효성 검사 모듈
 */
const Validator = (() => {
  const EMAIL_REGEX = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;

  function validateEmail(value) {
    if (!value.trim()) return '이메일을 입력해 주세요.';
    if (!EMAIL_REGEX.test(value.trim())) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  function validateName(value) {
    const trimmed = value.trim();
    if (!trimmed) return '이름을 입력해 주세요.';
    if (trimmed.length > 10) return '이름은 10자 이내로 입력해 주세요.';
    return null;
  }

  function validatePassword(value) {
    if (!value) return '비밀번호를 입력해 주세요.';
    if (value.length < 4) return '비밀번호는 최소 4자 이상이어야 합니다.';
    if (value.length > 10) return '비밀번호는 10자 이내로 입력해 주세요.';
    return null;
  }

  function validatePasswordConfirm(password, confirm) {
    if (!confirm) return '비밀번호를 다시 입력해 주세요.';
    if (password !== confirm) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  function validateAgree(checked) {
    if (!checked) return '이용약관에 동의해 주세요.';
    return null;
  }

  /**
   * 비밀번호 강도 측정
   * @returns {{ score: 0|1|2|3, label: string, color: string }}
   */
  function measureStrength(password) {
    if (!password) return { score: 0, label: '', color: '' };
    let score = 0;
    if (password.length >= 6) score++;
    if (/[A-Z]/.test(password) || /[a-z]/.test(password)) score++;
    if (/[0-9]/.test(password)) score++;
    if (/[^A-Za-z0-9]/.test(password)) score++;

    const levels = [
      { score: 0, label: '',        color: '' },
      { score: 1, label: '약함',    color: '#ef4444' },
      { score: 2, label: '보통',    color: '#f59e0b' },
      { score: 3, label: '강함',    color: '#22c55e' },
      { score: 4, label: '매우 강함', color: '#16a34a' },
    ];
    return levels[Math.min(score, 4)];
  }

  return {
    validateEmail,
    validateName,
    validatePassword,
    validatePasswordConfirm,
    validateAgree,
    measureStrength,
  };
})();
