-- =============================================================================
-- 헬스케어 앱 PostgreSQL 데이터베이스 스키마
-- 생성일: 2026-05-28
-- 설명: 회원 정보, 건강 관리, 진료 관리 도메인을 포함한 전체 스키마
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. ENUM 타입 정의
-- -----------------------------------------------------------------------------

-- 성별
CREATE TYPE gender_type AS ENUM ('male', 'female', 'other');

-- 혈액형
CREATE TYPE blood_type AS ENUM ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', 'unknown');

-- 소셜 로그인 제공자
CREATE TYPE social_provider AS ENUM ('google', 'naver', 'kakao');

-- 보호자 관계 유형
CREATE TYPE guardian_relation_type AS ENUM ('parent', 'child', 'spouse', 'sibling', 'other');

-- 알러지 분류
CREATE TYPE allergy_category AS ENUM ('drug', 'food', 'environment', 'other');

-- 알러지 반응 심각도
CREATE TYPE allergy_severity AS ENUM ('mild', 'moderate', 'severe');

-- 약물 복용 주기 단위
CREATE TYPE dosage_frequency AS ENUM ('once_daily', 'twice_daily', 'three_times_daily', 'four_times_daily', 'as_needed', 'weekly', 'monthly', 'other');

-- 진료 파일 유형
CREATE TYPE medical_file_type AS ENUM ('image', 'pdf', 'document', 'other');

-- 건강 노트 작성자 유형
CREATE TYPE note_author_type AS ENUM ('self', 'guardian');

-- 회원 계정 상태
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended');

-- 약관 동의 유형
CREATE TYPE consent_type AS ENUM ('privacy_policy', 'terms_of_service', 'marketing');

-- 진료 예약 상태
CREATE TYPE appointment_status AS ENUM ('scheduled', 'completed', 'cancelled', 'no_show');


-- -----------------------------------------------------------------------------
-- 2. 테이블 생성
-- -----------------------------------------------------------------------------

-- =============================================================================
-- [도메인 1] 회원 정보
-- =============================================================================

-- 사용자(회원) 테이블
CREATE TABLE users (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    email           VARCHAR(255)    NOT NULL UNIQUE,
    password_hash   VARCHAR(255),                               -- 소셜 전용 계정은 NULL 허용
    name            VARCHAR(100)    NOT NULL,
    phone           VARCHAR(20),
    status          user_status     NOT NULL DEFAULT 'active',
    last_login_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,                                -- 소프트 딜리트
    CONSTRAINT chk_users_email_format CHECK (email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$')
);

-- 소셜 로그인 연동 계정 테이블
CREATE TABLE social_accounts (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    provider        social_provider NOT NULL,
    provider_uid    VARCHAR(255)    NOT NULL,                   -- 소셜 제공자 고유 ID
    provider_email  VARCHAR(255),                               -- 소셜 계정 이메일(참고용)
    access_token    TEXT,                                       -- 암호화 저장 권장
    refresh_token   TEXT,
    token_expires_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_social_accounts_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_social_provider_uid UNIQUE (provider, provider_uid)
);

-- 보호자-피보호자 관계 테이블
CREATE TABLE guardian_relations (
    id              UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
    guardian_id     UUID                    NOT NULL,           -- 보호자 계정
    dependent_id    UUID                    NOT NULL,           -- 피보호자(자녀 등) 계정
    relation_type   guardian_relation_type  NOT NULL,
    is_primary      BOOLEAN                 NOT NULL DEFAULT FALSE, -- 주 보호자 여부
    accepted_at     TIMESTAMPTZ,                                -- 관계 수락 시점
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_guardian_relations_guardian
        FOREIGN KEY (guardian_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_guardian_relations_dependent
        FOREIGN KEY (dependent_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_guardian_not_self CHECK (guardian_id <> dependent_id),
    CONSTRAINT uq_guardian_dependent UNIQUE (guardian_id, dependent_id)
);


-- =============================================================================
-- [도메인 2] 건강 관리
-- =============================================================================

-- 기본 건강 프로필 테이블 (사용자 1:1)
CREATE TABLE health_profiles (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL UNIQUE,
    birth_date      DATE,
    gender          gender_type,
    height_cm       NUMERIC(5,2)    CHECK (height_cm > 0 AND height_cm < 300),
    weight_kg       NUMERIC(5,2)    CHECK (weight_kg > 0 AND weight_kg < 700),
    blood_type      blood_type      NOT NULL DEFAULT 'unknown',
    emergency_contact_name  VARCHAR(100),
    emergency_contact_phone VARCHAR(20),
    notes           TEXT,                                       -- 기타 특이사항
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_health_profiles_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 복용 약물 / 영양제 테이블
CREATE TABLE medications (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    name            VARCHAR(200)    NOT NULL,                   -- 약물/영양제명
    dosage          VARCHAR(100),                               -- 용량 (예: 500mg)
    frequency       dosage_frequency NOT NULL DEFAULT 'once_daily',
    frequency_detail VARCHAR(200),                             -- frequency = other 일 때 상세 기재
    start_date      DATE,
    end_date        DATE,                                       -- NULL이면 지속 복용
    is_ongoing      BOOLEAN         NOT NULL DEFAULT FALSE,     -- 현재 복용 중 여부
    prescribed_by   VARCHAR(100),                               -- 처방 의사/기관
    purpose         TEXT,                                       -- 복용 목적
    side_effects    TEXT,                                       -- 경험한 부작용
    reminder_times  JSONB,                                      -- 복용 알림 시간 배열 (예: ["08:00","20:00"])
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_medications_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT chk_medications_date_range
        CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_medications_ongoing_consistency
        CHECK (NOT (is_ongoing = TRUE AND end_date IS NOT NULL))
);

-- 알러지 테이블
CREATE TABLE allergies (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    category        allergy_category NOT NULL DEFAULT 'other',
    allergen        VARCHAR(200)    NOT NULL,                   -- 알러겐명 (예: 페니실린, 땅콩)
    reaction        TEXT,                                       -- 반응 증상 설명
    severity        allergy_severity NOT NULL DEFAULT 'mild',
    diagnosed_at    DATE,
    diagnosed_by    VARCHAR(100),                               -- 진단 기관/의사
    is_active       BOOLEAN         NOT NULL DEFAULT TRUE,      -- 현재 유효 여부
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_allergies_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 지병 / 만성질환 테이블
CREATE TABLE chronic_diseases (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    disease_name    VARCHAR(200)    NOT NULL,
    icd10_code      VARCHAR(20),                                -- ICD-10 질병 분류 코드
    diagnosed_at    DATE,
    diagnosed_by    VARCHAR(100),
    is_ongoing      BOOLEAN         NOT NULL DEFAULT TRUE,      -- 현재 진행 중 여부
    treatment_status TEXT,                                      -- 치료 현황
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_chronic_diseases_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 예방 접종 이력 테이블
CREATE TABLE vaccinations (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    vaccine_name    VARCHAR(200)    NOT NULL,                   -- 접종명 (예: 독감, HPV)
    vaccinated_at   DATE            NOT NULL,
    hospital_name   VARCHAR(200),
    lot_number      VARCHAR(100),                               -- 백신 로트 번호
    dose_number     SMALLINT        CHECK (dose_number > 0),    -- 차수 (1차, 2차 ...)
    next_due_date   DATE,                                       -- 다음 접종 예정일
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_vaccinations_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT uq_vaccinations_record
        UNIQUE (user_id, vaccine_name, vaccinated_at, dose_number)
);

-- 건강검진 결과 테이블
CREATE TABLE health_checkups (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    checkup_date    DATE            NOT NULL,
    institution     VARCHAR(200),                               -- 검진 기관
    checkup_type    VARCHAR(100),                               -- 검진 종류 (일반, 암검진 등)
    result_summary  TEXT,                                       -- 결과 요약
    result_detail   JSONB,                                      -- 항목별 수치 (구조화 데이터)
    doctor_opinion  TEXT,                                       -- 의사 소견
    next_checkup_date DATE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_health_checkups_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 건강 노트 (자가진단 / 보호자 코멘트) 테이블
CREATE TABLE health_notes (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,                   -- 노트 대상 사용자
    author_id       UUID            NOT NULL,                   -- 작성자 (본인 또는 보호자)
    author_type     note_author_type NOT NULL DEFAULT 'self',
    title           VARCHAR(300),
    content         TEXT            NOT NULL,
    recorded_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),     -- 증상/관찰 시점
    tags            JSONB,                                      -- 태그 배열 (예: ["두통","발열"])
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_health_notes_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_health_notes_author
        FOREIGN KEY (author_id) REFERENCES users(id) ON DELETE CASCADE
);


-- =============================================================================
-- [도메인 3] 진료 관리
-- =============================================================================

-- 진료 내역 테이블
CREATE TABLE medical_records (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    visit_date      DATE            NOT NULL,
    hospital_name   VARCHAR(200)    NOT NULL,
    department      VARCHAR(100),                               -- 진료과 (예: 내과, 정형외과)
    doctor_name     VARCHAR(100),
    symptoms        TEXT,                                       -- 주요 증상
    diagnosis       TEXT,                                       -- 진단 내용
    treatment       TEXT,                                       -- 치료 내용
    follow_up_date  DATE,                                       -- 다음 내원 예정일
    insurance_type  VARCHAR(50),                                -- 보험 유형 (건강보험, 자비 등)
    cost_amount     NUMERIC(12,2)   CHECK (cost_amount >= 0),   -- 진료비
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_medical_records_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 처방전 테이블
CREATE TABLE prescriptions (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    medical_record_id   UUID        NOT NULL,
    user_id             UUID        NOT NULL,
    prescribed_at       DATE        NOT NULL,
    prescribing_doctor  VARCHAR(100),
    pharmacy_name       VARCHAR(200),
    dispensed_at        TIMESTAMPTZ,                            -- 조제 완료 시점
    notes               TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT fk_prescriptions_medical_record
        FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE CASCADE,
    CONSTRAINT fk_prescriptions_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 처방 약물 상세 테이블 (처방전 1:N)
CREATE TABLE prescription_drugs (
    id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_id     UUID        NOT NULL,
    drug_name           VARCHAR(200) NOT NULL,
    dosage              VARCHAR(100),                           -- 1회 용량 (예: 500mg)
    frequency           dosage_frequency NOT NULL DEFAULT 'three_times_daily',
    frequency_detail    VARCHAR(200),
    duration_days       SMALLINT    CHECK (duration_days > 0),  -- 복용 일수
    quantity            NUMERIC(8,2) CHECK (quantity > 0),      -- 총 조제량
    instructions        TEXT,                                   -- 복용 지시사항
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT fk_prescription_drugs_prescription
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE
);

-- 진료 관련 파일 메타데이터 테이블
CREATE TABLE medical_files (
    id                  UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL,
    medical_record_id   UUID,                                   -- NULL 허용 (직접 업로드 파일)
    prescription_id     UUID,                                   -- NULL 허용
    file_type           medical_file_type NOT NULL DEFAULT 'other',
    original_filename   VARCHAR(500)    NOT NULL,
    stored_filename     VARCHAR(500)    NOT NULL,               -- 스토리지 저장 경로/키
    mime_type           VARCHAR(100)    NOT NULL,
    file_size_bytes     BIGINT          CHECK (file_size_bytes >= 0),
    storage_provider    VARCHAR(50)     NOT NULL DEFAULT 'local', -- s3, gcs, local 등
    storage_url         TEXT,
    description         TEXT,
    uploaded_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT fk_medical_files_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_medical_files_medical_record
        FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE SET NULL,
    CONSTRAINT fk_medical_files_prescription
        FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE SET NULL
);


-- -----------------------------------------------------------------------------
-- 3. 인덱스 생성
-- -----------------------------------------------------------------------------

-- users
CREATE INDEX idx_users_email         ON users(email)         WHERE deleted_at IS NULL;
CREATE INDEX idx_users_phone         ON users(phone)         WHERE deleted_at IS NULL;
CREATE INDEX idx_users_status        ON users(status)        WHERE deleted_at IS NULL;
CREATE INDEX idx_users_deleted_at    ON users(deleted_at);

-- social_accounts
CREATE INDEX idx_social_accounts_user_id     ON social_accounts(user_id)           WHERE deleted_at IS NULL;
CREATE INDEX idx_social_accounts_provider    ON social_accounts(provider, provider_uid) WHERE deleted_at IS NULL;

-- guardian_relations
CREATE INDEX idx_guardian_relations_guardian   ON guardian_relations(guardian_id)   WHERE deleted_at IS NULL;
CREATE INDEX idx_guardian_relations_dependent  ON guardian_relations(dependent_id)  WHERE deleted_at IS NULL;

-- health_profiles
CREATE INDEX idx_health_profiles_user_id  ON health_profiles(user_id)  WHERE deleted_at IS NULL;

-- medications
CREATE INDEX idx_medications_user_id      ON medications(user_id)       WHERE deleted_at IS NULL;
CREATE INDEX idx_medications_is_ongoing   ON medications(user_id, is_ongoing) WHERE deleted_at IS NULL;

-- allergies
CREATE INDEX idx_allergies_user_id        ON allergies(user_id)         WHERE deleted_at IS NULL;
CREATE INDEX idx_allergies_category       ON allergies(user_id, category) WHERE deleted_at IS NULL;

-- chronic_diseases
CREATE INDEX idx_chronic_diseases_user_id ON chronic_diseases(user_id)  WHERE deleted_at IS NULL;
CREATE INDEX idx_chronic_diseases_ongoing ON chronic_diseases(user_id, is_ongoing) WHERE deleted_at IS NULL;

-- vaccinations
CREATE INDEX idx_vaccinations_user_id     ON vaccinations(user_id)      WHERE deleted_at IS NULL;
CREATE INDEX idx_vaccinations_date        ON vaccinations(user_id, vaccinated_at DESC) WHERE deleted_at IS NULL;

-- health_checkups
CREATE INDEX idx_health_checkups_user_id  ON health_checkups(user_id)   WHERE deleted_at IS NULL;
CREATE INDEX idx_health_checkups_date     ON health_checkups(user_id, checkup_date DESC) WHERE deleted_at IS NULL;

-- health_notes
CREATE INDEX idx_health_notes_user_id     ON health_notes(user_id)      WHERE deleted_at IS NULL;
CREATE INDEX idx_health_notes_author_id   ON health_notes(author_id)    WHERE deleted_at IS NULL;
CREATE INDEX idx_health_notes_recorded_at ON health_notes(user_id, recorded_at DESC) WHERE deleted_at IS NULL;

-- medical_records
CREATE INDEX idx_medical_records_user_id      ON medical_records(user_id)               WHERE deleted_at IS NULL;
CREATE INDEX idx_medical_records_visit_date   ON medical_records(user_id, visit_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_medical_records_hospital     ON medical_records(user_id, hospital_name) WHERE deleted_at IS NULL;

-- prescriptions
CREATE INDEX idx_prescriptions_user_id            ON prescriptions(user_id)            WHERE deleted_at IS NULL;
CREATE INDEX idx_prescriptions_medical_record_id  ON prescriptions(medical_record_id)  WHERE deleted_at IS NULL;

-- prescription_drugs
CREATE INDEX idx_prescription_drugs_prescription_id ON prescription_drugs(prescription_id) WHERE deleted_at IS NULL;

-- medical_files
CREATE INDEX idx_medical_files_user_id           ON medical_files(user_id)            WHERE deleted_at IS NULL;
CREATE INDEX idx_medical_files_medical_record_id ON medical_files(medical_record_id)  WHERE deleted_at IS NULL;
CREATE INDEX idx_medical_files_prescription_id   ON medical_files(prescription_id)    WHERE deleted_at IS NULL;
CREATE INDEX idx_medical_files_file_type         ON medical_files(user_id, file_type) WHERE deleted_at IS NULL;

-- 알림 기능용 날짜 인덱스 (검토자 권고)
CREATE INDEX idx_medical_records_follow_up  ON medical_records(follow_up_date)  WHERE deleted_at IS NULL AND follow_up_date IS NOT NULL;
CREATE INDEX idx_vaccinations_next_due      ON vaccinations(next_due_date)       WHERE deleted_at IS NULL AND next_due_date IS NOT NULL;
CREATE INDEX idx_medications_end_date       ON medications(end_date)             WHERE deleted_at IS NULL AND end_date IS NOT NULL;
CREATE INDEX idx_users_last_login_at        ON users(last_login_at)              WHERE deleted_at IS NULL;


-- =============================================================================
-- [도메인 1 보완] 약관 동의 이력 / 비밀번호 재설정 토큰
-- =============================================================================

-- 약관 동의 이력 (개인정보보호법 의무 기록)
CREATE TABLE user_consents (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    consent_type    consent_type    NOT NULL,
    agreed          BOOLEAN         NOT NULL,
    agreed_at       TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    ip_address      INET,
    user_agent      TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_user_consents_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 비밀번호 재설정 토큰
CREATE TABLE password_reset_tokens (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    token_hash      VARCHAR(255)    NOT NULL,                       -- 토큰 해시값 저장 (평문 저장 금지)
    expires_at      TIMESTAMPTZ     NOT NULL,
    used_at         TIMESTAMPTZ,                                    -- 사용 완료 시각 (NULL이면 미사용)
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_prt_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================================
-- [도메인 2 보완] 활력징후 측정 이력
-- =============================================================================

-- 활력징후 측정 이력 (혈압·혈당·체온 등 시계열 데이터)
CREATE TABLE vital_signs (
    id              UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID            NOT NULL,
    measured_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    systolic_bp     SMALLINT        CHECK (systolic_bp BETWEEN 50 AND 300),   -- 수축기 혈압 (mmHg)
    diastolic_bp    SMALLINT        CHECK (diastolic_bp BETWEEN 30 AND 200),  -- 이완기 혈압 (mmHg)
    heart_rate      SMALLINT        CHECK (heart_rate BETWEEN 20 AND 300),    -- 맥박 (bpm)
    blood_glucose   NUMERIC(6,2)    CHECK (blood_glucose > 0),                -- 혈당 (mg/dL)
    body_temp       NUMERIC(4,2)    CHECK (body_temp BETWEEN 30 AND 45),      -- 체온 (°C)
    weight_kg       NUMERIC(5,2)    CHECK (weight_kg > 0 AND weight_kg < 700),
    spo2            SMALLINT        CHECK (spo2 BETWEEN 50 AND 100),          -- 산소포화도 (%)
    notes           TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ,
    CONSTRAINT fk_vital_signs_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- =============================================================================
-- [도메인 3 보완] 진료 예약
-- =============================================================================

-- 진료 예약 / 병원 일정 테이블
CREATE TABLE appointments (
    id                  UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID                NOT NULL,
    appointment_at      TIMESTAMPTZ         NOT NULL,
    hospital_name       VARCHAR(200)        NOT NULL,
    department          VARCHAR(100),
    doctor_name         VARCHAR(100),
    purpose             TEXT,
    status              appointment_status  NOT NULL DEFAULT 'scheduled',
    medical_record_id   UUID,                                       -- 진료 완료 후 연결
    notes               TEXT,
    created_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    deleted_at          TIMESTAMPTZ,
    CONSTRAINT fk_appointments_user
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_appointments_record
        FOREIGN KEY (medical_record_id) REFERENCES medical_records(id) ON DELETE SET NULL
);

-- 추가 인덱스
CREATE INDEX idx_user_consents_user_id          ON user_consents(user_id)             WHERE deleted_at IS NULL;
CREATE INDEX idx_password_reset_tokens_user_id  ON password_reset_tokens(user_id)     WHERE deleted_at IS NULL;
CREATE INDEX idx_password_reset_tokens_expires  ON password_reset_tokens(expires_at)  WHERE deleted_at IS NULL AND used_at IS NULL;
CREATE INDEX idx_vital_signs_user_id            ON vital_signs(user_id)               WHERE deleted_at IS NULL;
CREATE INDEX idx_vital_signs_measured_at        ON vital_signs(user_id, measured_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_appointments_user_id           ON appointments(user_id)              WHERE deleted_at IS NULL;
CREATE INDEX idx_appointments_at                ON appointments(user_id, appointment_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_appointments_status            ON appointments(status)               WHERE deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- 4. 컬럼 / 테이블 코멘트 (COMMENT ON)
-- -----------------------------------------------------------------------------

-- ===== users =====
COMMENT ON TABLE  users                         IS '앱 사용자 계정 테이블. 일반 가입 및 소셜 연동 공통 레코드.';
COMMENT ON COLUMN users.id                      IS '사용자 고유 식별자 (UUID v4)';
COMMENT ON COLUMN users.email                   IS '로그인/연락용 이메일 주소 (unique)';
COMMENT ON COLUMN users.password_hash           IS 'bcrypt 해시 비밀번호. 소셜 전용 계정은 NULL.';
COMMENT ON COLUMN users.name                    IS '사용자 실명 또는 닉네임';
COMMENT ON COLUMN users.phone                   IS '휴대폰 번호 (선택). 개인정보 — 암호화 저장 권장.';
COMMENT ON COLUMN users.status                  IS '계정 활성 상태 (active/inactive/suspended)';
COMMENT ON COLUMN users.last_login_at           IS '마지막 로그인 시각';
COMMENT ON COLUMN users.deleted_at              IS '소프트 딜리트 시각. NULL이면 정상 계정.';

-- ===== social_accounts =====
COMMENT ON TABLE  social_accounts               IS '소셜 로그인(Google/Naver/Kakao) 연동 계정';
COMMENT ON COLUMN social_accounts.provider      IS '소셜 로그인 제공자 (google/naver/kakao)';
COMMENT ON COLUMN social_accounts.provider_uid  IS '소셜 제공자가 발급한 고유 사용자 ID';
COMMENT ON COLUMN social_accounts.access_token  IS 'OAuth 액세스 토큰 (암호화 저장 권장)';
COMMENT ON COLUMN social_accounts.refresh_token IS 'OAuth 리프레시 토큰 (암호화 저장 권장)';

-- ===== guardian_relations =====
COMMENT ON TABLE  guardian_relations            IS '보호자-피보호자 관계. 부모-자녀, 배우자 등 다양한 관계 지원.';
COMMENT ON COLUMN guardian_relations.guardian_id   IS '보호자 역할 사용자 ID';
COMMENT ON COLUMN guardian_relations.dependent_id  IS '피보호자(자녀 등) 사용자 ID';
COMMENT ON COLUMN guardian_relations.is_primary    IS '주 보호자 여부. 피보호자당 1명만 TRUE 권장.';
COMMENT ON COLUMN guardian_relations.accepted_at   IS '피보호자가 관계 요청을 수락한 시각';

-- ===== health_profiles =====
COMMENT ON TABLE  health_profiles               IS '사용자 기본 건강 정보. users 테이블과 1:1 관계.';
COMMENT ON COLUMN health_profiles.height_cm     IS '키(cm). 0 초과 300 미만 제약.';
COMMENT ON COLUMN health_profiles.weight_kg     IS '몸무게(kg). 0 초과 700 미만 제약.';
COMMENT ON COLUMN health_profiles.blood_type    IS '혈액형. 미확인 시 unknown.';
COMMENT ON COLUMN health_profiles.birth_date    IS '생년월일. 민감 개인정보 — 암호화 저장 권장.';
COMMENT ON COLUMN health_profiles.emergency_contact_name  IS '긴급 연락처 이름';
COMMENT ON COLUMN health_profiles.emergency_contact_phone IS '긴급 연락처 전화번호. 개인정보 — 암호화 저장 권장.';

-- ===== medications =====
COMMENT ON TABLE  medications                   IS '복용 중인 약물 및 영양제 목록';
COMMENT ON COLUMN medications.frequency         IS '복용 주기 ENUM. other 선택 시 frequency_detail에 상세 기재.';
COMMENT ON COLUMN medications.reminder_times    IS '복용 알림 시각 JSON 배열. 예: ["08:00","13:00","20:00"]';
COMMENT ON COLUMN medications.is_ongoing        IS 'TRUE이면 현재 복용 중, FALSE이면 복용 완료/중단.';

-- ===== allergies =====
COMMENT ON TABLE  allergies                     IS '약물, 식품, 환경 등 알러지 정보';
COMMENT ON COLUMN allergies.allergen            IS '알러겐 명칭 (예: 페니실린, 새우, 꽃가루)';
COMMENT ON COLUMN allergies.severity            IS '반응 심각도 (mild/moderate/severe)';
COMMENT ON COLUMN allergies.is_active           IS 'FALSE이면 현재는 문제없는 과거 이력.';

-- ===== chronic_diseases =====
COMMENT ON TABLE  chronic_diseases              IS '지병 및 만성질환 목록';
COMMENT ON COLUMN chronic_diseases.icd10_code   IS 'ICD-10 국제 질병 분류 코드 (선택)';
COMMENT ON COLUMN chronic_diseases.is_ongoing   IS 'TRUE이면 현재 진행 중인 질환.';

-- ===== vaccinations =====
COMMENT ON TABLE  vaccinations                  IS '예방접종 이력';
COMMENT ON COLUMN vaccinations.lot_number       IS '백신 로트(제조) 번호. 이상반응 추적 시 활용.';
COMMENT ON COLUMN vaccinations.dose_number      IS '접종 차수 (1, 2, 3, …)';
COMMENT ON COLUMN vaccinations.next_due_date    IS '다음 접종 권장일 (알림 기능 활용)';

-- ===== health_checkups =====
COMMENT ON TABLE  health_checkups               IS '건강검진 결과 기록';
COMMENT ON COLUMN health_checkups.result_detail IS '항목별 수치를 JSON으로 저장. 예: {"혈압": "120/80", "혈당": 95}';
COMMENT ON COLUMN health_checkups.checkup_type  IS '검진 종류. 예: 일반건강검진, 암검진, 직장검진';

-- ===== health_notes =====
COMMENT ON TABLE  health_notes                  IS '자가진단 메모 및 보호자 관찰 코멘트';
COMMENT ON COLUMN health_notes.user_id          IS '노트 대상 사용자 (본인 또는 피보호자)';
COMMENT ON COLUMN health_notes.author_id        IS '실제 작성자 (본인 또는 보호자)';
COMMENT ON COLUMN health_notes.author_type      IS 'self=본인 작성, guardian=보호자 작성';
COMMENT ON COLUMN health_notes.tags             IS '태그 JSON 배열. 예: ["두통","발열","기침"]';
COMMENT ON COLUMN health_notes.recorded_at      IS '증상/관찰이 발생한 실제 시각 (작성 시각과 상이할 수 있음)';

-- ===== medical_records =====
COMMENT ON TABLE  medical_records               IS '병원 방문 진료 내역';
COMMENT ON COLUMN medical_records.department    IS '진료과. 예: 내과, 정형외과, 소아청소년과';
COMMENT ON COLUMN medical_records.cost_amount   IS '본인부담 진료비 (원 단위)';
COMMENT ON COLUMN medical_records.follow_up_date IS '재진 예정일 (알림 기능 활용)';

-- ===== prescriptions =====
COMMENT ON TABLE  prescriptions                 IS '처방전 헤더. 진료 내역 1건에 처방전 N개 가능.';
COMMENT ON COLUMN prescriptions.user_id         IS '진료 기록의 user_id와 반드시 일치해야 함. 애플리케이션에서 일관성 보장 필수.';
COMMENT ON COLUMN prescriptions.dispensed_at    IS '약국 조제 완료 시각. NULL이면 미수령/미조제.';

-- ===== prescription_drugs =====
COMMENT ON TABLE  prescription_drugs            IS '처방전 내 개별 약물 상세 정보';
COMMENT ON COLUMN prescription_drugs.duration_days IS '복용 일수 (예: 3일치, 7일치)';
COMMENT ON COLUMN prescription_drugs.quantity       IS '조제 총 수량 (정/포/mL 등)';
COMMENT ON COLUMN prescription_drugs.instructions   IS '복용 방법 및 주의사항 (예: 식후 30분, 물과 함께)';

-- ===== medical_files =====
COMMENT ON TABLE  medical_files                 IS '진료 관련 첨부 파일 메타데이터. 실제 바이너리는 외부 스토리지 저장.';
COMMENT ON COLUMN medical_files.stored_filename IS '스토리지 내 경로 또는 오브젝트 키';
COMMENT ON COLUMN medical_files.storage_provider IS '파일 저장 스토리지 종류 (local/s3/gcs 등)';
COMMENT ON COLUMN medical_files.storage_url     IS '파일 접근 URL (서명된 URL 또는 CDN 경로)';
COMMENT ON COLUMN medical_files.medical_record_id IS '연결된 진료 내역. 독립 파일이면 NULL.';
COMMENT ON COLUMN medical_files.prescription_id   IS '연결된 처방전. 해당 없으면 NULL.';

-- ===== user_consents =====
COMMENT ON TABLE  user_consents                 IS '약관 동의 이력. 개인정보보호법에 따른 동의 기록 의무.';
COMMENT ON COLUMN user_consents.consent_type    IS '동의 유형 (privacy_policy/terms_of_service/marketing)';
COMMENT ON COLUMN user_consents.agreed          IS 'TRUE=동의, FALSE=철회';
COMMENT ON COLUMN user_consents.ip_address      IS '동의 시점 클라이언트 IP (법적 증빙용)';

-- ===== password_reset_tokens =====
COMMENT ON TABLE  password_reset_tokens         IS '비밀번호 재설정 토큰. 토큰은 반드시 해시 저장.';
COMMENT ON COLUMN password_reset_tokens.token_hash  IS '재설정 토큰의 해시값. 평문 토큰 저장 절대 금지.';
COMMENT ON COLUMN password_reset_tokens.expires_at  IS '토큰 만료 시각. 만료 후 사용 불가.';
COMMENT ON COLUMN password_reset_tokens.used_at     IS '토큰 사용 완료 시각. NULL이면 미사용 상태.';

-- ===== vital_signs =====
COMMENT ON TABLE  vital_signs                   IS '활력징후 측정 이력 (혈압, 맥박, 혈당, 체온 등 시계열).';
COMMENT ON COLUMN vital_signs.systolic_bp       IS '수축기 혈압 (mmHg). 정상 범위 50~300.';
COMMENT ON COLUMN vital_signs.diastolic_bp      IS '이완기 혈압 (mmHg). 정상 범위 30~200.';
COMMENT ON COLUMN vital_signs.spo2              IS '산소포화도 (%). 정상 범위 50~100.';
COMMENT ON COLUMN vital_signs.measured_at       IS '측정 실시 시각. 입력 시각과 다를 수 있음.';

-- ===== appointments =====
COMMENT ON TABLE  appointments                  IS '진료 예약 및 병원 방문 일정';
COMMENT ON COLUMN appointments.appointment_at   IS '예약 일시 (타임존 포함)';
COMMENT ON COLUMN appointments.status           IS '예약 상태 (scheduled/completed/cancelled/no_show)';
COMMENT ON COLUMN appointments.medical_record_id IS '진료 완료 후 생성된 진료 내역과 연결. 예약 단계에서는 NULL.';
