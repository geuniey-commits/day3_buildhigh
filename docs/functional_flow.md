# Build-High 기능적 구현 흐름 리스트 (Data Flow 중심)

> **원칙**: 화면 중심이 아닌 **데이터 흐름 중심**으로 구현 단계를 나열합니다.  
> 각 단계는 "데이터 페칭 → 상태 관리 → UI 바인딩" 형태로 구성됩니다.

---

## Phase 1: Foundation (공통 유틸리티 및 기본 데이터 연결)

### 1. Supabase 클라이언트 인스턴스 생성 및 세션 관리
**데이터 흐름**: 환경 변수 로드 → Supabase 클라이언트 생성 → 세션 쿠키 관리

- **구현 위치**: `lib/supabase/server.ts`, `lib/supabase/client.ts`, `lib/supabase/middleware.ts`
- **기술 스택**: `@supabase/ssr` (`createServerClient`, `createBrowserClient`)
- **상태**: ✅ 기본 구현 완료
- **확인 사항**:
  - [ ] 서버 컴포넌트에서 `createClient()` 호출 시 쿠키 기반 세션 자동 관리 확인
  - [ ] 클라이언트 컴포넌트에서 `createClient()` 호출 시 브라우저 세션 자동 관리 확인
  - [ ] 미들웨어에서 `createClient(request)` 호출 시 요청별 세션 갱신 확인

---

### 2. Google OAuth 인증 플로우 (Client → Supabase → Callback → Session)
**데이터 흐름**: 사용자 클릭 → OAuth URL 리다이렉트 → Google 인증 → 콜백 코드 수신 → 세션 교환 → 쿠키 저장

- **구현 위치**: 
  - 클라이언트: `components/domain/auth/google-sign-in-button.tsx`
  - 콜백: `app/api/auth/callback/route.ts` (✅ 구현됨)
- **기술 스택**: 
  - `supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo } })`
  - `supabase.auth.exchangeCodeForSession(code)`
- **상태**: ⚠️ 콜백만 구현됨, OAuth 시작 버튼 미구현
- **구현 단계**:
  1. `google-sign-in-button.tsx`에서 `createClient()` 호출
  2. 버튼 클릭 시 `signInWithOAuth()` 실행
  3. `redirectTo`를 `http://localhost:3000/api/auth/callback` (또는 배포 도메인)로 설정
  4. 콜백 라우트에서 `exchangeCodeForSession()`으로 세션 쿠키 설정 (✅ 완료)
  5. 성공 시 `/` 또는 `/(dashboard)`로 리다이렉트

---

### 3. 전역 세션 상태 관리 (Client-side)
**데이터 흐름**: 초기 세션 조회 → `onAuthStateChange` 구독 → 상태 업데이트 → Context 전파

- **구현 위치**: `components/domain/auth/auth-provider.tsx` (✅ 구현됨)
- **기술 스택**: `supabase.auth.getSession()`, `supabase.auth.onAuthStateChange()`, React Context
- **상태**: ✅ 구현 완료
- **확인 사항**:
  - [ ] `app/layout.tsx`에서 `AuthProvider`로 전체 앱 감싸기
  - [ ] `useAuth()` 훅으로 전역 세션 상태 접근 가능 확인
  - [ ] 로그아웃 시 `supabase.auth.signOut()` 호출 후 상태 자동 업데이트 확인

---

### 4. 라우트 가드 미들웨어 (세션 검증 및 보호 라우트 제어)
**데이터 흐름**: 요청 수신 → 세션 쿠키 확인 → 인증 상태 검증 → 보호 라우트 리다이렉트

- **구현 위치**: 프로젝트 루트 `middleware.ts` (❌ 미구현)
- **기술 스택**: Next.js Middleware, `lib/supabase/middleware.ts`의 `createClient(request)`
- **상태**: ❌ 미구현
- **구현 단계**:
  1. 프로젝트 루트에 `middleware.ts` 생성
  2. 보호 대상 라우트 패턴 정의: `/`, `/posts/*`, `/profile`, `/api/posts/*`
  3. 허용 대상 라우트: `/login`, `/api/auth/callback`, 정적 리소스
  4. 보호 라우트 접근 시 `supabase.auth.getUser()`로 세션 확인
  5. 미인증 시 `/login`으로 리다이렉트
  6. 인증된 경우 `supabaseResponse` 반환하여 세션 갱신

---

### 5. 프로필 자동 생성 트리거 (DB 레벨)
**데이터 흐름**: Google 로그인 성공 → `auth.users` INSERT → 트리거 실행 → `profiles` INSERT

- **구현 위치**: `supabase/migrations/20250129000005_create_triggers.sql` (✅ 구현됨)
- **기술 스택**: PostgreSQL Trigger (`handle_new_user()`)
- **상태**: ✅ 구현 완료
- **확인 사항**:
  - [ ] Google OAuth 메타데이터(`raw_user_meta_data`)에서 `username`, `avatar_url` 추출 확인
  - [ ] 최초 로그인 직후 `profiles` 테이블에 레코드 자동 생성 확인
  - [ ] 트리거 실패 시 에러 로그 확인

---

## Phase 2: Core Logic (주요 비즈니스 기능의 Read/Write)

### 6. 프로필 데이터 조회 (Server Component → DB → Props)
**데이터 흐름**: 페이지 렌더 → `createClient()` → `profiles.select().eq('id', user.id).single()` → 데이터 반환 → UI 바인딩

- **구현 위치**: 
  - 서버: `app/(dashboard)/profile/page.tsx` (현재 Client Component, ⚠️ 변경 필요)
  - 훅: `hooks/use-profile.ts` (✅ 구현됨, 클라이언트용)
- **기술 스택**: 
  - Server Component: `createClient()` (server) → `supabase.from('profiles').select().eq('id', user.id).single()`
  - Client Component: `useProfile()` 훅 사용
- **상태**: ⚠️ 클라이언트 훅만 구현됨, 서버 컴포넌트 패턴 미적용
- **구현 옵션**:
  - **옵션 A (권장)**: `app/(dashboard)/profile/page.tsx`를 Server Component로 변경, 데이터 페칭 후 Client Component에 props 전달
  - **옵션 B**: 현재 구조 유지, `useProfile()` 훅 사용 (클라이언트 사이드 페칭)

---

### 7. 프로필 데이터 수정 (Client → API → DB → 상태 갱신)
**데이터 흐름**: 폼 제출 → `useProfile().updateProfile()` → `supabase.from('profiles').update().eq('id', user.id)` → RLS 검증 → DB 업데이트 → 로컬 상태 갱신

- **구현 위치**: `hooks/use-profile.ts` (✅ 구현됨)
- **기술 스택**: `supabase.from('profiles').update(updates).eq('id', user.id).select().single()`
- **RLS 정책**: `auth.uid() = id` (본인만 수정 가능)
- **상태**: ✅ 기본 구현 완료
- **확인 사항**:
  - [ ] `tech_stack` 배열 업데이트 정상 동작 확인
  - [ ] 업데이트 후 `select().single()`로 최신 데이터 반환 확인
  - [ ] RLS 정책 위반 시 에러 처리 확인

---

### 8. 게시글 목록 조회 (Server Component → DB → Props → UI 렌더)
**데이터 흐름**: 페이지 렌더 → `createClient()` → `posts.select().order('created_at', { ascending: false })` → 작성자 프로필 JOIN → 데이터 반환 → DiscoveryPage props → 카드 리스트 렌더

- **구현 위치**: 
  - 서버: `app/page.tsx` (현재 인증 체크만, ⚠️ 데이터 페칭 미구현)
  - UI: `components/posts/DiscoveryPage.tsx` (현재 목업 데이터 사용)
- **기술 스택**: 
  - Server Component: `createClient()` → `supabase.from('posts').select('*, author:profiles!posts_author_id_fkey(id, username, avatar_url)').order('created_at', { ascending: false })`
- **상태**: ❌ 목업 데이터 사용 중, 실제 DB 연동 필요
- **구현 단계**:
  1. `app/page.tsx`에서 인증 확인 후 `createClient()` 호출
  2. `posts` 테이블에서 목록 조회 (작성자 프로필 JOIN 포함)
  3. `summary`(TEXT[]), `tags`(TEXT[]) 데이터 변환
  4. `DiscoveryPage`에 props로 전달
  5. `DiscoveryPostCard`에서 `summaryLines`, `techTags`, `authorName` 바인딩

---

### 9. 게시글 상세 조회 (Server Component → DB → Props → UI 렌더)
**데이터 흐름**: URL 파라미터 수신 → `createClient()` → `posts.select().eq('id', id).single()` → 작성자 프로필 JOIN → 데이터 반환 → PostDetail 컴포넌트 props → UI 렌더

- **구현 위치**: `app/(dashboard)/posts/[id]/page.tsx` (✅ 구현됨)
- **기술 스택**: `supabase.from('posts').select('*, author:profiles!posts_author_id_fkey(id, username, avatar_url)').eq('id', id).single()`
- **상태**: ✅ 구현 완료
- **확인 사항**:
  - [ ] `tags` 배열이 정상적으로 뱃지로 렌더링되는지 확인
  - [ ] `summary` 배열이 3줄 요약으로 표시되는지 확인
  - [ ] 작성자 정보(`author.username`, `author.avatar_url`) 정상 표시 확인

---

### 10. 게시글 생성 (Client → API Route → AI 처리 → DB 저장)
**데이터 흐름**: 폼 제출 → `/api/posts` POST → `createClient()` → 인증 확인 → 입력 검증 → `generateSummaryAndTags()` 호출 → Gemini API 요청 → 응답 파싱 → `posts.insert()` → RLS 검증 → DB 저장 → 응답 반환

- **구현 위치**: 
  - 클라이언트: `app/(dashboard)/posts/new/page.tsx` (✅ 폼 제출 구현됨)
  - API: `app/api/posts/route.ts` (✅ 기본 구조 구현됨)
  - AI: `lib/ai/gemini.ts` (⚠️ 파싱 로직 TODO)
- **기술 스택**: 
  - API Route: `createClient()` (server) → `supabase.auth.getUser()` → `generateSummaryAndTags()` → `supabase.from('posts').insert()`
  - AI: `fetch()` → Gemini API → JSON 응답 파싱
- **상태**: ⚠️ AI 응답 파싱 미구현
- **구현 단계**:
  1. `lib/ai/gemini.ts`에서 Gemini API 응답 파싱 로직 구현
  2. 응답에서 `summary`(3줄 배열), `tags`(5개 배열) 추출
  3. 에러 발생 시 fallback 정책 결정 (저장 중단 vs 기본값 저장)
  4. `app/api/posts/route.ts`에서 파싱된 데이터를 `posts.insert()`에 전달
  5. 성공 시 클라이언트에서 `/`로 리다이렉트

---

### 11. 게시글 삭제 (Client → API Route → DB 삭제 → 목록 갱신)
**데이터 흐름**: 삭제 버튼 클릭 → 확인 모달 → `/api/posts/[id]` DELETE → `createClient()` → 인증 확인 → `posts.delete().eq('id', id)` → RLS 검증 → DB 삭제 → 응답 반환 → 목록 갱신

- **구현 위치**: 
  - API: `app/api/posts/[id]/route.ts` (✅ DELETE 구현됨)
  - UI: 상세 페이지 또는 목록 카드 (❌ 삭제 버튼 미구현)
- **기술 스택**: `supabase.from('posts').delete().eq('id', id)`
- **RLS 정책**: `auth.uid() = author_id` (작성자만 삭제 가능)
- **상태**: ⚠️ API만 구현됨, UI 삭제 버튼 미구현
- **구현 단계**:
  1. `app/(dashboard)/posts/[id]/page.tsx` 또는 `DiscoveryPostCard`에 삭제 버튼 추가
  2. 작성자만 삭제 버튼 노출 (`post.author_id === user.id`)
  3. 삭제 확인 모달 구현
  4. 확인 시 `/api/posts/[id]` DELETE 요청
  5. 성공 시 목록 페이지로 리다이렉트 또는 목록 갱신

---

### 12. 통계 데이터 집계 (Server Component → DB 집계 → Props → UI 렌더)
**데이터 흐름**: 페이지 렌더 → `createClient()` → `posts.select('id', { count: 'exact', head: true })` → `profiles.select('id', { count: 'exact', head: true })` → `post_applications.select('id', { count: 'exact', head: true }).eq('status', 'accepted')` → 집계 결과 반환 → DiscoveryStatCards props → UI 렌더

- **구현 위치**: 
  - 서버: `app/page.tsx` (❌ 집계 로직 미구현)
  - UI: `components/posts/DiscoveryStatCards.tsx` (현재 고정값 0)
- **기술 스택**: `supabase.from('posts').select('*', { count: 'exact', head: true })`
- **상태**: ❌ 미구현
- **구현 단계**:
  1. `app/page.tsx`에서 `createClient()` 호출
  2. `posts` 테이블에서 총 게시글 수 집계 (`count: 'exact'`)
  3. `profiles` 테이블에서 총 유저 수 집계
  4. `post_applications` 테이블에서 `status='accepted'`인 매칭 완료 수 집계
  5. 집계 결과를 `DiscoveryStatCards`에 props로 전달
  6. 카드 컴포넌트에서 동적 값 표시

---

## Phase 3: Interaction & Feedback (상태 변경, 알림, 에러 핸들링)

### 13. 카테고리 필터링 (Client State → 필터링 로직 → UI 업데이트)
**데이터 흐름**: 필터 버튼 클릭 → `activeCategory` 상태 업데이트 → `posts.filter(category === activeCategory)` → 필터링된 목록 렌더

- **구현 위치**: `components/posts/DiscoveryFilters.tsx` (✅ UI 구현됨), `components/posts/DiscoveryPage.tsx` (⚠️ 목업 데이터 필터링만)
- **기술 스택**: React `useState`, `useMemo`
- **상태**: ⚠️ 목업 데이터 필터링만 구현됨, 실제 DB 쿼리 필터링 필요
- **구현 옵션**:
  - **옵션 A (권장)**: Server Component에서 `activeCategory`를 쿼리 파라미터로 받아 `posts.select().eq('category', category)` 쿼리 실행
  - **옵션 B**: 클라이언트에서 전체 데이터를 받아 필터링 (비효율적)

---

### 14. 검색 기능 (Client State → 쿼리 파라미터 → Server Query → UI 업데이트)
**데이터 흐름**: 검색어 입력 → `searchQuery` 상태 업데이트 → Server Component에서 `posts.select().or('title.ilike.%query%,tags.cs.{query}')` → 필터링된 목록 반환 → UI 업데이트

- **구현 위치**: `components/posts/DiscoveryFilters.tsx` (✅ UI 구현됨), `app/page.tsx` (❌ 검색 쿼리 미구현)
- **기술 스택**: Supabase `or()`, `ilike()`, `cs()` (contains)
- **상태**: ❌ 미구현
- **구현 단계**:
  1. `DiscoveryFilters`에서 검색어를 URL 쿼리 파라미터로 전달 (`?search=...`)
  2. `app/page.tsx`에서 `searchParams` 수신
  3. `posts.select().or('title.ilike.%query%,tags.cs.{query}')` 쿼리 실행
  4. 필터링된 결과를 `DiscoveryPage`에 전달

---

### 15. 로딩 상태 관리 (데이터 페칭 중 → 로딩 UI 표시)
**데이터 흐름**: 데이터 페칭 시작 → `loading: true` → 로딩 스피너/스켈레톤 UI 표시 → 데이터 수신 → `loading: false` → 실제 데이터 UI 표시

- **구현 위치**: 각 데이터 페칭 컴포넌트
- **기술 스택**: React `useState`, `useEffect`, Suspense (선택)
- **상태**: ⚠️ 일부만 구현됨 (`useProfile`, `usePosts` 훅에 `loading` 상태 있음)
- **구현 단계**:
  1. Server Component: `loading.tsx` 파일 생성 (Next.js Suspense 활용)
  2. Client Component: `useState<boolean>`로 `loading` 상태 관리
  3. 데이터 페칭 전 `setLoading(true)`, 완료 후 `setLoading(false)`
  4. 로딩 중 스피너 또는 스켈레톤 UI 표시

---

### 16. 에러 핸들링 및 사용자 피드백 (에러 발생 → 상태 저장 → UI 표시)
**데이터 흐름**: API/DB 에러 발생 → `error` 상태 저장 → 에러 메시지 UI 표시 → 사용자 액션 (재시도/취소)

- **구현 위치**: 각 API Route, 데이터 페칭 컴포넌트
- **기술 스택**: `try-catch`, React `useState`, Toast/Alert 컴포넌트
- **상태**: ⚠️ 기본 에러 처리만 구현됨, 사용자 피드백 UI 미구현
- **구현 단계**:
  1. API Route에서 명확한 에러 메시지 반환 (`{ error: string }`)
  2. 클라이언트에서 `error` 상태 관리
  3. 에러 발생 시 Toast 또는 Alert 컴포넌트로 사용자에게 표시
  4. 네트워크 에러, 인증 에러, 검증 에러 등 타입별 메시지 분기

---

### 17. 빈 상태(Empty State) 처리 (데이터 없음 → 빈 상태 UI 표시)
**데이터 흐름**: 데이터 조회 → 결과 없음 → `EmptyState` 컴포넌트 렌더 → CTA 버튼 표시

- **구현 위치**: `components/domain/shared/empty-state.tsx` (✅ 구현됨)
- **기술 스택**: 조건부 렌더링 (`posts.length === 0`)
- **상태**: ✅ 컴포넌트 구현됨, 실제 데이터 연동 시 적용 필요
- **확인 사항**:
  - [ ] 게시글 목록이 비어있을 때 `EmptyState` 표시 확인
  - [ ] "첫 번째 프로젝트의 주인공이 되어보세요!" 메시지 및 CTA 버튼 동작 확인

---

### 18. 폼 유효성 검사 및 실시간 피드백 (입력 → 검증 → 에러 표시)
**데이터 흐름**: 사용자 입력 → 검증 함수 실행 → 에러 상태 업데이트 → 에러 메시지 UI 표시 → 제출 버튼 비활성화

- **구현 위치**: `app/(dashboard)/posts/new/page.tsx` (✅ 일부 구현됨), `app/(dashboard)/profile/page.tsx`
- **기술 스택**: `lib/utils/validations.ts` (✅ 구현됨), React `useState`, `useEffect`
- **상태**: ⚠️ 제목 검증만 구현됨, 본문/카테고리 검증 보강 필요
- **구현 단계**:
  1. `validations.ts`에서 `validatePostContent()`, `validateCategory()` 함수 활용
  2. 입력 필드별 `onChange` 핸들러에서 실시간 검증
  3. 에러 메시지를 필드 하단에 표시
  4. 모든 검증 통과 시에만 제출 버튼 활성화

---

### 19. 성공 피드백 (작업 완료 → 성공 메시지 표시 → 리다이렉트)
**데이터 흐름**: 작업 성공 → 성공 상태 저장 → Toast/Alert 표시 → (선택) 리다이렉트

- **구현 위치**: 각 폼 제출 핸들러
- **기술 스택**: React `useState`, Toast 컴포넌트, `useRouter().push()`
- **상태**: ⚠️ 일부만 구현됨 (프로필 저장 시 성공 메시지 있음)
- **구현 단계**:
  1. 게시글 생성 성공 시 "게시글이 성공적으로 작성되었습니다" Toast 표시
  2. 프로필 업데이트 성공 시 "프로필이 저장되었습니다" 메시지 표시 (✅ 구현됨)
  3. 삭제 성공 시 "게시글이 삭제되었습니다" 메시지 표시
  4. 성공 후 적절한 페이지로 리다이렉트

---

### 20. 카테고리 값 정합성 수정 (DB 스키마 → 마이그레이션 → 타입 재생성)
**데이터 흐름**: DB 스키마 확인 → 소문자 enum으로 변경 → 마이그레이션 실행 → 타입 재생성 → 코드 동기화

- **구현 위치**: `supabase/migrations/`, `types/database.ts`
- **기술 스택**: PostgreSQL `ALTER TABLE`, Supabase CLI `gen types`
- **상태**: ⚠️ 불일치 존재 (UI: 소문자, DB: 대문자)
- **구현 단계**:
  1. `ALTER TABLE posts DROP CONSTRAINT ...` (기존 CHECK 제약 제거)
  2. `CREATE TYPE post_category AS ENUM ('development', 'study', 'project')`
  3. `ALTER TABLE posts ALTER COLUMN category TYPE post_category USING category::lowercase::post_category`
  4. Supabase CLI로 `types/database.ts` 재생성
  5. UI 코드(`DiscoveryFilters`, `NewPostPage`)에서 소문자 값 사용 확인

---

## 구현 우선순위 요약

### 즉시 구현 필요 (Phase 1 완료를 위한 필수)
1. **#2**: Google OAuth 버튼 구현 (로그인 플로우 완성)
2. **#4**: 라우트 가드 미들웨어 구현 (보안 강화)
3. **#10**: AI 응답 파싱 로직 구현 (게시글 생성 완성)

### 핵심 기능 구현 (Phase 2)
4. **#8**: 게시글 목록 조회 (Discovery 페이지 실제 데이터 연동)
5. **#12**: 통계 데이터 집계 (대시보드 스탯 카드)
6. **#11**: 게시글 삭제 UI (삭제 버튼 및 확인 모달)

### 사용자 경험 개선 (Phase 3)
7. **#13**: 카테고리 필터링 (서버 쿼리 기반)
8. **#14**: 검색 기능 (제목/태그 검색)
9. **#15-19**: 로딩/에러/성공 피드백 UI

### 정합성 개선 (선택)
10. **#20**: 카테고리 값 정합성 수정 (DB/UI 동기화)

---

## 체크리스트 형식 (컨펌용)

각 단계 구현 후 아래 항목을 확인하세요:

- [ ] **데이터 페칭**: Supabase 쿼리가 정상 실행되는가?
- [ ] **상태 관리**: 데이터가 컴포넌트 상태에 정상 반영되는가?
- [ ] **UI 바인딩**: 데이터가 UI에 정상 표시되는가?
- [ ] **에러 처리**: 에러 발생 시 사용자에게 적절한 피드백이 제공되는가?
- [ ] **RLS 정책**: RLS 정책이 의도대로 동작하는가?
- [ ] **타입 안정성**: TypeScript 타입 에러가 없는가?
