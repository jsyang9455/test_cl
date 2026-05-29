/**
 * localStorage 기반 임시 사용자 저장소
 * 실제 DB 없이 브라우저 로컬에 저장
 */
const UserStorage = (() => {
  const KEY = 'healthcare_users';

  function getAll() {
    try {
      return JSON.parse(localStorage.getItem(KEY) || '[]');
    } catch {
      return [];
    }
  }

  function save(users) {
    try {
      localStorage.setItem(KEY, JSON.stringify(users));
    } catch (e) {
      if (e.name === 'QuotaExceededError') {
        throw new Error('저장 공간이 부족합니다. 브라우저 저장소를 확인해 주세요.');
      }
      throw e;
    }
  }

  function isEmailTaken(email) {
    return getAll().some(u => u.email.toLowerCase() === email.toLowerCase());
  }

  /**
   * 신규 사용자 등록
   * @param {{ email, name, passwordHash, passwordSalt }} userData
   * @returns {{ success: boolean, message: string }}
   */
  function registerUser({ email, name, passwordHash, passwordSalt }) {
    if (isEmailTaken(email)) {
      return { success: false, message: '이미 사용 중인 이메일입니다.' };
    }
    const users = getAll();
    users.push({
      id: crypto.randomUUID(),
      email: email.toLowerCase().trim(),
      name: name.trim(),
      passwordHash,
      passwordSalt,
      createdAt: new Date().toISOString(),
    });
    save(users);
    return { success: true, message: '가입이 완료되었습니다.' };
  }

  function count() {
    return getAll().length;
  }

  return { registerUser, isEmailTaken, getAll, count };
})();
