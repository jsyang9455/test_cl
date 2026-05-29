/**
 * 테스트 계정 자동 생성
 * 페이지 로드 시 localStorage에 계정이 없으면 생성
 */
(async () => {
  const TEST_EMAIL    = 'test@example.com';
  const TEST_PASSWORD = 'Test1234!';
  const TEST_NAME     = '테스트';

  if (!UserStorage.isEmailTaken(TEST_EMAIL)) {
    const { hash, salt } = await PasswordCrypto.hashPassword(TEST_PASSWORD);
    UserStorage.registerUser({
      email:        TEST_EMAIL,
      name:         TEST_NAME,
      passwordHash: hash,
      passwordSalt: salt,
    });
    console.log('[seed] 테스트 계정 생성 완료');
  }
})();
