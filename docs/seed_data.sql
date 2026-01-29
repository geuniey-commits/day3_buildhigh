-- ============================================================
-- BUILD-HIGH 초기 데이터 세팅 (Seeding)
-- 생성일: 2025-01-29
-- 목적: UI 테스트 및 개발 환경 초기 데이터 제공
-- ============================================================

-- ============================================================
-- 0. 공통 코드 테이블 생성 (없는 경우)
-- ============================================================

-- 공통 코드 마스터 테이블
CREATE TABLE IF NOT EXISTS bh_code_master (
  code_group VARCHAR(50) PRIMARY KEY,
  code_group_name VARCHAR(100) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 공통 코드 상세 테이블
CREATE TABLE IF NOT EXISTS bh_code_value (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_group VARCHAR(50) NOT NULL REFERENCES bh_code_master(code_group) ON DELETE CASCADE,
  code_value VARCHAR(50) NOT NULL,
  code_name VARCHAR(100) NOT NULL,
  code_name_en VARCHAR(100),
  description TEXT,
  sort_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(code_group, code_value)
);

-- updated_at 트리거 함수 (이미 존재할 수 있음)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 공통 코드 테이블 트리거
DROP TRIGGER IF EXISTS update_bh_code_master_updated_at ON bh_code_master;
CREATE TRIGGER update_bh_code_master_updated_at
  BEFORE UPDATE ON bh_code_master
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_bh_code_value_updated_at ON bh_code_value;
CREATE TRIGGER update_bh_code_value_updated_at
  BEFORE UPDATE ON bh_code_value
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 1. 공통 코드 마스터 데이터 삽입
-- ============================================================

-- 신청 상태 마스터 (BH_ST_APPLICATION)
INSERT INTO bh_code_master (code_group, code_group_name, description, is_active)
VALUES 
  ('BH_ST_APPLICATION', '신청 상태', '프로젝트 지원/매칭 신청 상태 코드', TRUE)
ON CONFLICT (code_group) DO NOTHING;

-- 유저 권한 마스터 (BH_USER_ROLE)
INSERT INTO bh_code_master (code_group, code_group_name, description, is_active)
VALUES 
  ('BH_USER_ROLE', '유저 권한', '사용자 권한 레벨 코드', TRUE)
ON CONFLICT (code_group) DO NOTHING;

-- ============================================================
-- 2. 공통 코드 상세 데이터 삽입
-- ============================================================

-- 신청 상태 상세 코드
INSERT INTO bh_code_value (code_group, code_value, code_name, code_name_en, description, sort_order, is_active)
VALUES 
  ('BH_ST_APPLICATION', 'PENDING', '대기중', 'Pending', '지원 신청이 접수되어 검토 대기 중인 상태', 1, TRUE),
  ('BH_ST_APPLICATION', 'APPROVED', '승인됨', 'Approved', '지원 신청이 승인되어 매칭이 완료된 상태', 2, TRUE),
  ('BH_ST_APPLICATION', 'REJECTED', '거절됨', 'Rejected', '지원 신청이 거절된 상태', 3, TRUE),
  ('BH_ST_APPLICATION', 'WITHDRAWN', '철회됨', 'Withdrawn', '지원자가 신청을 철회한 상태', 4, TRUE)
ON CONFLICT (code_group, code_value) DO NOTHING;

-- 유저 권한 상세 코드
INSERT INTO bh_code_value (code_group, code_value, code_name, code_name_en, description, sort_order, is_active)
VALUES 
  ('BH_USER_ROLE', 'USER', '일반 사용자', 'User', '기본 사용자 권한 (게시글 작성/조회 가능)', 1, TRUE),
  ('BH_USER_ROLE', 'ADMIN', '관리자', 'Admin', '시스템 관리자 권한 (모든 기능 접근 가능)', 2, TRUE),
  ('BH_USER_ROLE', 'MODERATOR', '모더레이터', 'Moderator', '커뮤니티 모더레이터 권한 (게시글 관리 가능)', 3, TRUE)
ON CONFLICT (code_group, code_value) DO NOTHING;

-- ============================================================
-- 3. 테스트용 유저 프로필 데이터 삽입
-- 주의: 실제 auth.users에 해당 UUID가 존재해야 합니다.
-- 로컬 개발 환경에서는 Supabase Dashboard에서 먼저 테스트 유저를 생성하거나
-- 아래 UUID를 auth.users에 수동으로 매핑해야 합니다.
-- ============================================================

-- 테스트 유저 1: 김민수 (프론트엔드 개발자)
INSERT INTO profiles (id, username, avatar_url, tech_stack, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000001'::UUID,
    '김민수',
    NULL,
    ARRAY['React', 'TypeScript', 'Next.js', 'Tailwind CSS', 'Zustand'],
    NOW() - INTERVAL '30 days',
    NOW() - INTERVAL '30 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 테스트 유저 2: 이지은 (백엔드 개발자)
INSERT INTO profiles (id, username, avatar_url, tech_stack, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000002'::UUID,
    '이지은',
    NULL,
    ARRAY['Node.js', 'Express', 'PostgreSQL', 'TypeScript', 'Docker'],
    NOW() - INTERVAL '25 days',
    NOW() - INTERVAL '25 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 테스트 유저 3: 박준호 (풀스택 개발자)
INSERT INTO profiles (id, username, avatar_url, tech_stack, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000003'::UUID,
    '박준호',
    NULL,
    ARRAY['Next.js', 'TypeScript', 'Prisma', 'Supabase', 'AWS'],
    NOW() - INTERVAL '20 days',
    NOW() - INTERVAL '20 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 테스트 유저 4: 최수진 (AI/ML 엔지니어)
INSERT INTO profiles (id, username, avatar_url, tech_stack, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000004'::UUID,
    '최수진',
    NULL,
    ARRAY['Python', 'PyTorch', 'TensorFlow', 'OpenAI API', 'LangChain'],
    NOW() - INTERVAL '15 days',
    NOW() - INTERVAL '15 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 테스트 유저 5: 정태영 (모바일 개발자)
INSERT INTO profiles (id, username, avatar_url, tech_stack, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000005'::UUID,
    '정태영',
    NULL,
    ARRAY['React Native', 'TypeScript', 'Expo', 'Firebase', 'GraphQL'],
    NOW() - INTERVAL '10 days',
    NOW() - INTERVAL '10 days'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 4. 테스트용 게시글 데이터 삽입
-- ============================================================

-- 게시글 1: 김민수 - Next.js 기반 이커머스 플랫폼 개발 (Development)
INSERT INTO posts (
  id, author_id, title, category, content, summary, tags, contact, created_at, updated_at
)
VALUES 
  (
    '10000000-0000-0000-0000-000000000001'::UUID,
    '00000000-0000-0000-0000-000000000001'::UUID,
    'Next.js 기반 이커머스 플랫폼 개발 프로젝트 모집',
    'Development',
    '# 프로젝트 개요

AI 기반 상품 추천 시스템을 갖춘 모던 이커머스 플랫폼을 개발하고 있습니다. 
현재 프론트엔드 개발이 진행 중이며, 백엔드 및 AI 엔지니어를 모집하고 있습니다.

## 주요 기능
- 실시간 재고 관리 시스템
- AI 기반 개인화 상품 추천
- 결제 시스템 연동 (토스페이먼츠, 아임포트)
- 관리자 대시보드

## 기술 스택
- Frontend: Next.js 15, TypeScript, Tailwind CSS, Zustand
- Backend: Node.js, Express, PostgreSQL
- AI: OpenAI API, LangChain
- Infrastructure: AWS, Docker

## 모집 인원
- 백엔드 개발자 2명 (Node.js/Express 경험 필수)
- AI/ML 엔지니어 1명 (추천 시스템 경험 우대)
- DevOps 엔지니어 1명 (AWS, Docker 경험 필수)

## 예상 기간
- 3개월 (2025년 2월 ~ 4월)
- 주 3회 온라인 미팅, 주 1회 오프라인 미팅

## 지원 방법
아래 디스코드 링크로 연락주시면 상세한 프로젝트 계획서를 공유드리겠습니다.',
    ARRAY[
      'Next.js 15 기반의 모던 이커머스 플랫폼 개발 프로젝트입니다.',
      'AI 기반 상품 추천 시스템과 실시간 재고 관리 기능을 포함합니다.',
      '백엔드 개발자 2명, AI/ML 엔지니어 1명, DevOps 엔지니어 1명을 모집합니다.'
    ],
    ARRAY['Next.js', 'TypeScript', 'Node.js', 'OpenAI API', 'AWS'],
    'https://discord.gg/buildhigh-ecommerce',
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '5 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 게시글 2: 이지은 - 딥러닝 스터디 그룹 (Study)
INSERT INTO posts (
  id, author_id, title, category, content, summary, tags, contact, created_at, updated_at
)
VALUES 
  (
    '10000000-0000-0000-0000-000000000002'::UUID,
    '00000000-0000-0000-0000-000000000002'::UUID,
    'Transformer 아키텍처 심화 스터디 모집',
    'Study',
    '# 스터디 소개

Transformer 아키텍처를 중심으로 한 딥러닝 심화 스터디를 진행합니다.
논문 리뷰와 함께 PyTorch로 직접 구현해보는 실습 중심의 스터디입니다.

## 스터디 내용
- Attention Mechanism 기초부터 심화까지
- Transformer, BERT, GPT 아키텍처 분석
- 논문 구현 from scratch
- 최신 논문 리뷰 (Vision Transformer, LLM 등)

## 진행 방식
- 주 1회 온라인 미팅 (2시간)
- 주 1회 논문 리뷰 발표
- 개인 프로젝트 진행 및 코드 리뷰

## 모집 대상
- 딥러닝 기초 지식이 있는 분
- PyTorch 사용 경험이 있는 분
- 논문 읽기와 구현에 관심이 있는 분

## 예상 기간
- 2개월 (2025년 2월 ~ 3월)
- 총 8주 과정

## 준비물
- Python, PyTorch 환경 설정
- 논문 자료는 스터디에서 제공

## 지원 방법
이메일로 간단한 자기소개와 함께 연락주세요!',
    ARRAY[
      'Transformer 아키텍처 중심의 딥러닝 심화 스터디입니다.',
      '논문 리뷰와 PyTorch 구현을 함께 진행하는 실습 중심 스터디입니다.',
      '딥러닝 기초 지식과 PyTorch 경험이 있는 분들을 모집합니다.'
    ],
    ARRAY['Python', 'PyTorch', 'Transformer', 'Deep Learning', 'NLP'],
    'lee.jieun@example.com',
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '4 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 게시글 3: 박준호 - 피트니스 트래킹 앱 프로젝트 (Project)
INSERT INTO posts (
  id, author_id, title, category, content, summary, tags, contact, created_at, updated_at
)
VALUES 
  (
    '10000000-0000-0000-0000-000000000003'::UUID,
    '00000000-0000-0000-0000-000000000003'::UUID,
    '모바일 퍼스트 피트니스 트래커 앱 개발',
    'Project',
    '# 프로젝트 소개

모바일 퍼스트 디자인으로 사용자 경험을 중시하는 피트니스 트래킹 앱을 개발합니다.
소셜 기능과 챌린지 시스템을 통해 운동 동기를 부여하는 것이 목표입니다.

## 핵심 기능
- 운동 기록 및 통계 분석
- 챌린지 및 그룹 운동 기능
- 친구 추가 및 소셜 피드
- Apple Health, Google Fit 연동

## 기술 스택
- Frontend: React Native, TypeScript, Expo
- Backend: Node.js, GraphQL, PostgreSQL
- Real-time: Supabase Realtime
- Storage: Supabase Storage

## 모집 인원
- React Native 개발자 2명
- 백엔드 개발자 1명 (GraphQL 경험 우대)
- UI/UX 디자이너 1명

## 프로젝트 목표
- 3개월 내 MVP 출시
- 앱스토어/플레이스토어 배포
- 초기 사용자 1,000명 확보

## 작업 방식
- 애자일 스프린트 (2주 단위)
- 주 2회 온라인 미팅
- GitHub을 통한 코드 리뷰

## 지원 방법
디스코드로 연락주시면 프로젝트 상세 계획서와 디자인 시안을 공유드리겠습니다.',
    ARRAY[
      '모바일 퍼스트 피트니스 트래킹 앱 개발 프로젝트입니다.',
      '소셜 기능과 챌린지 시스템을 통해 운동 동기를 부여합니다.',
      'React Native 개발자 2명, 백엔드 개발자 1명, UI/UX 디자이너 1명을 모집합니다.'
    ],
    ARRAY['React Native', 'TypeScript', 'GraphQL', 'Supabase', 'Expo'],
    'https://discord.gg/buildhigh-fitness',
    NOW() - INTERVAL '3 days',
    NOW() - INTERVAL '3 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 게시글 4: 최수진 - AI 챗봇 개발 프로젝트 (Development)
INSERT INTO posts (
  id, author_id, title, category, content, summary, tags, contact, created_at, updated_at
)
VALUES 
  (
    '10000000-0000-0000-0000-000000000004'::UUID,
    '00000000-0000-0000-0000-000000000004'::UUID,
    '고객 서비스 AI 챗봇 개발 프로젝트',
    'Development',
    '# 프로젝트 개요

고객 서비스 자동화를 위한 AI 챗봇을 개발합니다.
LLM 기반의 자연어 이해와 멀티턴 대화 관리가 핵심 기능입니다.

## 주요 기능
- 자연어 기반 고객 문의 응답
- 컨텍스트 유지 멀티턴 대화
- 지식 베이스 연동 (RAG)
- 대화 로그 분석 및 개선

## 기술 스택
- LLM: OpenAI GPT-4, Claude API
- Framework: LangChain, LlamaIndex
- Backend: Python FastAPI, PostgreSQL
- Frontend: React, TypeScript

## 모집 인원
- AI/ML 엔지니어 2명 (LLM 경험 필수)
- 백엔드 개발자 1명 (FastAPI 경험 우대)
- 프론트엔드 개발자 1명 (React 경험 필수)

## 프로젝트 일정
- 4개월 (2025년 2월 ~ 5월)
- Phase 1: 프로토타입 개발 (2개월)
- Phase 2: 프로덕션 배포 및 최적화 (2개월)

## 지원 방법
이메일로 포트폴리오와 함께 연락주세요.',
    ARRAY[
      '고객 서비스 자동화를 위한 AI 챗봇 개발 프로젝트입니다.',
      'LLM 기반 자연어 이해와 멀티턴 대화 관리가 핵심 기능입니다.',
      'AI/ML 엔지니어 2명, 백엔드 개발자 1명, 프론트엔드 개발자 1명을 모집합니다.'
    ],
    ARRAY['Python', 'OpenAI API', 'LangChain', 'FastAPI', 'React'],
    'choi.sujin@example.com',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '2 days'
  )
ON CONFLICT (id) DO NOTHING;

-- 게시글 5: 정태영 - React Native 스터디 (Study)
INSERT INTO posts (
  id, author_id, title, category, content, summary, tags, contact, created_at, updated_at
)
VALUES 
  (
    '10000000-0000-0000-0000-000000000005'::UUID,
    '00000000-0000-0000-0000-000000000005'::UUID,
    'React Native 실전 앱 개발 스터디',
    'Study',
    '# 스터디 소개

React Native를 활용한 실전 앱 개발 스터디입니다.
이론보다는 실제 프로젝트를 진행하면서 배우는 실습 중심 스터디입니다.

## 스터디 내용
- React Native 기초 및 환경 설정
- 네비게이션, 상태 관리 (Zustand, Redux)
- 네이티브 모듈 연동
- 앱스토어 배포 프로세스

## 진행 방식
- 주 2회 온라인 미팅 (각 2시간)
- 개인/팀 프로젝트 진행
- 코드 리뷰 및 피드백

## 모집 대상
- React 기초 지식이 있는 분
- 모바일 앱 개발에 관심이 있는 분
- 실제 앱을 만들어보고 싶은 분

## 예상 기간
- 6주 (2025년 2월 ~ 3월 중순)
- 총 12회 세션

## 준비물
- Node.js, React Native CLI 설치
- Expo 계정 생성 (선택사항)

## 지원 방법
디스코드로 연락주시면 스터디 커리큘럼을 공유드리겠습니다.',
    ARRAY[
      'React Native를 활용한 실전 앱 개발 스터디입니다.',
      '이론보다는 실제 프로젝트를 진행하면서 배우는 실습 중심 스터디입니다.',
      'React 기초 지식이 있는 분들을 모집합니다.'
    ],
    ARRAY['React Native', 'TypeScript', 'Expo', 'Zustand', 'Mobile'],
    'https://discord.gg/buildhigh-rn-study',
    NOW() - INTERVAL '1 day',
    NOW() - INTERVAL '1 day'
  )
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5. 테스트용 게시글 지원 데이터 삽입 (선택사항)
-- ============================================================

-- 김민수의 게시글에 이지은이 지원
INSERT INTO post_applications (id, post_id, applicant_id, status, message, created_at, updated_at)
VALUES 
  (
    '20000000-0000-0000-0000-000000000001'::UUID,
    '10000000-0000-0000-0000-000000000001'::UUID,
    '00000000-0000-0000-0000-000000000002'::UUID,
    'pending',
    '백엔드 개발자로 지원합니다. Node.js와 Express 경험이 있으며, 이커머스 프로젝트에 관심이 많습니다.',
    NOW() - INTERVAL '4 days',
    NOW() - INTERVAL '4 days'
  )
ON CONFLICT (post_id, applicant_id) DO NOTHING;

-- 박준호의 게시글에 최수진이 지원
INSERT INTO post_applications (id, post_id, applicant_id, status, message, created_at, updated_at)
VALUES 
  (
    '20000000-0000-0000-0000-000000000002'::UUID,
    '10000000-0000-0000-0000-000000000003'::UUID,
    '00000000-0000-0000-0000-000000000004'::UUID,
    'approved',
    'AI/ML 엔지니어로 지원합니다. 추천 시스템 개발 경험이 있어 도움이 될 것 같습니다.',
    NOW() - INTERVAL '2 days',
    NOW() - INTERVAL '2 days'
  )
ON CONFLICT (post_id, applicant_id) DO NOTHING;

-- ============================================================
-- 6. 테스트용 사용자 활동 로그 데이터 삽입 (선택사항)
-- ============================================================

-- 김민수의 활동 로그
INSERT INTO user_activities (id, user_id, activity_type, metadata, created_at)
VALUES 
  (
    '30000000-0000-0000-0000-000000000001'::UUID,
    '00000000-0000-0000-0000-000000000001'::UUID,
    'post_create',
    '{"post_id": "10000000-0000-0000-0000-000000000001", "category": "Development"}'::jsonb,
    NOW() - INTERVAL '5 days'
  ),
  (
    '30000000-0000-0000-0000-000000000002'::UUID,
    '00000000-0000-0000-0000-000000000001'::UUID,
    'login',
    '{}'::jsonb,
    NOW() - INTERVAL '1 day'
  )
ON CONFLICT DO NOTHING;

-- 이지은의 활동 로그
INSERT INTO user_activities (id, user_id, activity_type, metadata, created_at)
VALUES 
  (
    '30000000-0000-0000-0000-000000000003'::UUID,
    '00000000-0000-0000-0000-000000000002'::UUID,
    'post_create',
    '{"post_id": "10000000-0000-0000-0000-000000000002", "category": "Study"}'::jsonb,
    NOW() - INTERVAL '4 days'
  ),
  (
    '30000000-0000-0000-0000-000000000004'::UUID,
    '00000000-0000-0000-0000-000000000002'::UUID,
    'application_create',
    '{"application_id": "20000000-0000-0000-0000-000000000001", "post_id": "10000000-0000-0000-0000-000000000001"}'::jsonb,
    NOW() - INTERVAL '4 days'
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- 7. 검증 쿼리 (데이터 삽입 확인용)
-- ============================================================

-- 공통 코드 마스터 확인
-- SELECT * FROM bh_code_master ORDER BY code_group;

-- 공통 코드 상세 확인
-- SELECT * FROM bh_code_value ORDER BY code_group, sort_order;

-- 프로필 확인
-- SELECT id, username, tech_stack, created_at FROM profiles ORDER BY created_at;

-- 게시글 확인
-- SELECT id, title, category, author_id, created_at FROM posts ORDER BY created_at DESC;

-- 게시글 지원 확인
-- SELECT pa.id, p.title, pr.username as applicant_name, pa.status 
-- FROM post_applications pa
-- JOIN posts p ON pa.post_id = p.id
-- JOIN profiles pr ON pa.applicant_id = pr.id;

-- 사용자 활동 로그 확인
-- SELECT ua.id, pr.username, ua.activity_type, ua.created_at
-- FROM user_activities ua
-- JOIN profiles pr ON ua.user_id = pr.id
-- ORDER BY ua.created_at DESC;

-- ============================================================
-- 완료 메시지
-- ============================================================

-- 데이터 삽입이 완료되었습니다.
-- 위의 검증 쿼리를 실행하여 데이터가 정상적으로 삽입되었는지 확인하세요.
