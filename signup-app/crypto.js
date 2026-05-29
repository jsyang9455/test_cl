/**
 * 브라우저 내장 Web Crypto API를 사용한 비밀번호 해싱
 * PBKDF2 (SHA-256, 100,000 iterations) — bcrypt 대체
 */
const PasswordCrypto = (() => {
  const ITERATIONS = 100_000;
  const KEY_LENGTH = 256;
  const ALGORITHM  = 'SHA-256';

  function bufToHex(buf) {
    return Array.from(new Uint8Array(buf))
      .map(b => b.toString(16).padStart(2, '0'))
      .join('');
  }

  function hexToBuf(hex) {
    const pairs = hex.match(/.{1,2}/g);
    return new Uint8Array(pairs.map(b => parseInt(b, 16)));
  }

  async function generateSalt() {
    const salt = crypto.getRandomValues(new Uint8Array(16));
    return bufToHex(salt);
  }

  async function hash(password, saltHex) {
    const enc = new TextEncoder();
    const keyMaterial = await crypto.subtle.importKey(
      'raw', enc.encode(password), 'PBKDF2', false, ['deriveBits']
    );
    const bits = await crypto.subtle.deriveBits(
      { name: 'PBKDF2', salt: hexToBuf(saltHex), iterations: ITERATIONS, hash: ALGORITHM },
      keyMaterial,
      KEY_LENGTH
    );
    return bufToHex(bits);
  }

  /**
   * @returns {Promise<{hash: string, salt: string}>}
   */
  async function hashPassword(password) {
    const salt = await generateSalt();
    const hashed = await hash(password, salt);
    return { hash: hashed, salt };
  }

  /**
   * @returns {Promise<boolean>}
   */
  async function verifyPassword(password, storedHash, storedSalt) {
    const hashed = await hash(password, storedSalt);
    return hashed === storedHash;
  }

  return { hashPassword, verifyPassword };
})();
