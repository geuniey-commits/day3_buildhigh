## Build-High Step-by-step 구현 로드맵 (Supabase SDK + Google OAuth 관점)

### 0) 기준 문서/소스 매핑
- **PRD**: `docs/PRD.md` (Phase1: Google Auth, Profile(tech_stack), Posts CRUD + AI summary/tags)
- **FLOW**: `docs/FLOW.md` (Login → Discovery → New Post → Detail)
- **현재 구현 상태(핵심 파일)**  
  - **Auth 콜백(세션 교환)**: `app/api/auth/callback/route.ts` (✅ `exchangeCodeForSession`)  
  - **SSR/CSR Supabase 클라이언트**: `lib/supabase/server.ts`, `lib/supabase/client.ts`, `lib/supabase/middleware.ts`  
  - **Login UI**: `app/(auth)/login/page.tsx` (TODO) + `components/domain/auth/google-sign-in-button.tsx` (TODO)  
  - **Discovery(UI)**: `app/page.tsx`(인증 체크 후 `DiscoveryPage`) + `components/posts/DiscoveryPage.tsx`(현재 목업)  
  - **Posts API**: `app/api/posts/route.ts`(POST), `app/api/posts/[id]/route.ts`(GET/DELETE)  
  - **AI**: `lib/ai/gemini.ts` (현재 임시/파싱 TODO)  
  - **Profile**: `app/(dashboard)/profile/page.tsx`, `hooks/use-profile.ts`  
  - **DB 마이그레이션**: `supabase/migrations/*` (+ RLS/트리거 포함)

---

## 1) 환경/프로젝트 초기화 (로컬/배포 공통)
### 1-1. Supabase 프로젝트 준비
- **Supabase 프로젝트 생성**
- **Auth Provider: Google 활성화**
  - Google Cloud Console에서 OAuth Client 생성
  - Supabase Dashboard → Authentication → Providers → Google에 Client ID/Secret 설정
  - **Redirect URL**: Supabase 안내값 + 앱 콜백(아래 2-2) 반영

### 1-2. 환경변수 세팅
- **필수**
  - `NEXT_PUBLIC_SUPABASE_URL`
  - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
  - `GEMINI_API_KEY`
- **권장(운영/보안)**
  - Service Role Key는 서버에서만 사용, 클라이언트 번들에 포함 금지
  - `.env.local`은 프로젝트 루트에 두고 VCS 커밋 금지

---

## 2) Auth(구글 OAuth) End-to-End 구현
### 2-1. 로그인 화면 구성
- `app/(auth)/login/page.tsx`
  - **UI**: 로그인 설명 + `GoogleSignInButton` 렌더
  - (선택) URL query(`?error=...`) 처리하여 에러 메시지 표시

### 2-2. Google OAuth 시작 (Client → Supabase)
- `components/domain/auth/google-sign-in-button.tsx` 구현
  - **Supabase SDK**: `supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo } })`
  - `redirectTo`는 **반드시** 앱의 콜백 라우트로 설정:
    - 로컬: `http://localhost:3000/api/auth/callback`
    - 배포: `https://<domain>/api/auth/callback`

### 2-3. OAuth 콜백 처리 (Server Route)
- `app/api/auth/callback/route.ts` (현재 ✅)
  - `code`를 받아 `exchangeCodeForSession(code)`로 세션 쿠키 세팅
  - 성공 후 `/(dashboard)` 혹은 `/`로 리다이렉트
  - 실패 시 `/login?error=...`로 리다이렉트

### 2-4. 세션 유지/갱신 및 라우트 가드(미들웨어)
- 현재: `lib/supabase/middleware.ts`는 “미들웨어용 createServerClient”만 제공
- 해야 할 일:
  - 프로젝트 루트에 `middleware.ts`를 추가해 **세션 갱신/보호 라우트 제어**
  - 보호 대상 예시
    - 페이지: `/`(Discovery), `/posts/*`, `/profile` 등
    - API: `/api/posts/*` 등 (RLS + 서버 세션 이중 체크)
  - 허용 대상 예시
    - `/login`, `/api/auth/callback`, 정적 리소스

### 2-5. 클라이언트 전역 세션 상태(옵션)
- `components/domain/auth/auth-provider.tsx`는 이미 세션 구독 구현(✅)
- 해야 할 일:
  - `app/layout.tsx` 혹은 적절한 client boundary에서 `AuthProvider`로 감싸기
  - 로그아웃 버튼(헤더)에 `supabase.auth.signOut()` 연결

---

## 3) DB 스키마/마이그레이션 정합성(구현 안정화)
### 3-1. Phase1 핵심 테이블
- `profiles`, `posts` (+ 트리거/인덱스/RLS): `supabase/migrations/*`
- `handle_new_user()` 트리거(✅): `supabase/migrations/20250129000005_create_triggers.sql`

### 3-2. 카테고리 값 정합성(중요)
- 현재 UI 작성: `development|study|project` (소문자) (`app/(dashboard)/posts/new/page.tsx`)
- 현재 DB 마이그레이션: `Development|Study|Project` 체크 제약 (`supabase/migrations/20250129000001_create_posts.sql`)
- 해야 할 일(정책: No-Destructive)
  - `ALTER TABLE posts ...`로 category 제약/타입을 소문자 enum으로 통일
  - Discovery UI(필터/카드/목업)도 소문자 기준으로 동기화

### 3-3. RLS 정책 점검
- 현재 RLS는 `supabase/migrations/20250129000006_setup_rls_policies.sql`
- 해야 할 일
  - posts: `INSERT/UPDATE/DELETE`는 작성자만, `SELECT`는 인증 사용자 허용(Phase1)
  - profiles: update는 본인만, select는 공개 범위 정책 확정

---

## 4) Profile(마이페이지) 로직 구현
### 4-1. 프로필 자동 생성(가입 직후)
- DB 트리거가 auth.users → profiles insert(✅)
- 해야 할 일
  - Google 메타데이터(이름/아바타) 매핑이 기대대로 들어오는지 확인
  - 최초 로그인 직후 `/profile` 진입 시 `useProfile()`이 정상 조회되는지 확인

### 4-2. 프로필 조회/수정
- `hooks/use-profile.ts` (✅ 기본 동작)
- `app/(dashboard)/profile/page.tsx` (✅ UI, 저장 버튼)
- 해야 할 일
  - 에러/로딩 UX 보강
  - 업데이트 후 최신값 반영 확인(현재 `.select().single()`로 갱신 구조는 OK)

---

## 5) Posts CRUD + AI Pre-processing (Phase1 핵심)
### 5-1. Create (Client → API Route → AI → DB)
- 작성 화면: `app/(dashboard)/posts/new/page.tsx`
  - 이미 `/api/posts`로 POST 전송(✅)
  - 해야 할 일
    - category enum 정합성 완료(3-2 선행)
    - contact 유효성(필수/선택) 정책 확정
- API: `app/api/posts/route.ts` (✅ 골격)
  - 해야 할 일
    - 입력 검증(제목/본문/카테고리) 강화
    - `generateSummaryAndTags()` 실제 응답 파싱 구현(`lib/ai/gemini.ts`)
    - 실패 시 fallback 저장 정책(저장 중단 vs 기본값 저장) 결정

### 5-2. Read (List/Detail)
- Detail
  - 서버 컴포넌트: `app/(dashboard)/posts/[id]/page.tsx` (✅ DB 조회 + author join)
  - 컴포넌트: `components/domain/posts/post-detail.tsx` (tags 렌더/연락처 버튼)
- List(Discovery)
  - 현재 `DiscoveryPage`는 목업 데이터(❌ 실제 연동 필요)
  - 구현 옵션(권장순)
    - **옵션 A(권장)**: 서버 컴포넌트에서 posts 목록을 조회하고, `DiscoveryPage`에 props로 전달
    - 옵션 B: `/api/posts`에 GET 추가 후, 클라이언트에서 fetch하여 리스트 렌더

### 5-3. Delete
- API: `app/api/posts/[id]/route.ts` DELETE(✅)
- 해야 할 일
  - UI에서 삭제 버튼 노출 조건(작성자만) 및 확인 모달
  - 삭제 후 목록 갱신(현재 `hooks/use-posts.ts`는 fetch 기반으로 처리 가능)

---

## 6) 통계/대시보드(Phase1 최소 구현)
- UI: `components/posts/DiscoveryStatCards.tsx`는 값이 고정(0)
- 해야 할 일(Phase1 MVP)
  - total_posts: `select count(*)`(혹은 `head: true, count: 'exact'`)
  - total_users: 동일
  - matching_count: `post_applications`에서 `status='accepted'`(또는 승인 상태) count
  - 서버 컴포넌트에서 집계 후 props 주입(권장)

---

## 7) Seed/로컬 테스트 데이터로 UI E2E 검증
- `docs/seed_data.sql` 기반으로 초기 데이터 투입
- 해야 할 일
  - RLS 정책 하에서 “실제 로그인 유저”로 조회/작성/삭제가 되는지 검증
  - 카테고리/태그/요약이 UI에 정상 매핑되는지 확인

---

## 8) 타입 생성 및 앱 도메인 타입 정리
- `types/database.ts`
  - Supabase CLI로 스키마 기반 자동 생성
- `types/post.ts`, `types/profile.ts`
  - `Database['public']['Tables'][...]` 기반 타입 alias(✅)
- 해야 할 일
  - category enum 변경 시, `types/database.ts` 재생성 → 앱 타입 컴파일 확인

---

## 9) QA 체크리스트 (PRD/FLOW 기준)
- **Auth**
  - 로그인 전: `/` 접근 시 `/login`으로 리다이렉트 (`app/page.tsx` 기준)
  - 로그인 후: `/api/auth/callback` 처리 완료 후 Discovery 접근 가능
- **Profile**
  - tech_stack 선택/저장/재조회 OK
- **Posts**
  - 작성: AI summary/tags 생성 후 저장 OK
  - 목록: 카드에서 요약 3줄 + 태그 5개 + 작성자 표시 OK
  - 상세: tags badge, contact 링크, 작성자 카드 OK
  - 삭제: 작성자만 삭제 가능(RLS + UI)

