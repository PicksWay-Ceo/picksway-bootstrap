# 🧠 PicksWay Bootstrap — 한 줄 부활 시스템

> **F드라이브를 잃어버렸을 때 열어보는 공식 복구 저장소입니다.**
> **대표님만 사용 가능합니다 (복구에는 외부 자산 인증이 필요합니다).**

---

## 🚨 언제 이 저장소를 사용하는가

| 상황 | 조치 |
|---|---|
| F드라이브 살아있음 | **이 저장소 필요 없음.** `F:\000_PicksWayBrain\_RESTORE.bat` 더블클릭 |
| F드라이브 사망 / 새 PC | **이 저장소 사용.** 아래 절차 진행 |
| 완전 초기화 후 복귀 | **이 저장소 사용.** |

---

## ⚡ 복구 절차 (5분)

### 사전 준비 (한 번만)
1. **Git 설치** — https://git-scm.com/download/win
2. **Python 3.11+ 설치** — https://www.python.org/downloads/
3. **네이버박스 데스크톱 설치 + 로그인** — 클라우드 백업 접근용
   - 로그인되면 `N:\` 자동 마운트됨
4. **GitHub 로그인** — AUTOW Private repo 접근용
   - `gh auth login` 또는 GitHub Desktop

### 복구 실행
1. 이 저장소 **ZIP 다운로드** (초록 `Code` 버튼 → Download ZIP)
2. 압축 풀기 (아무 위치나 OK, 예: 바탕화면)
3. **`_RESTORE.bat` 더블클릭**
4. 스크립트가 자동 수행:
   - 로컬/외장 드라이브에서 `000_PicksWayBrain` 탐색
   - 없으면 MYBOX (`N:\개인\001_픽스웨이\_BRAIN_BACKUP\`) 자동 감지
   - F드라이브로 데이터 복원
   - GitHub에서 AUTOW Private repo clone
   - `~/.claude/` 메모리 복원
   - `.key` 복호화 (1회 비밀번호 입력 필요)
   - 바탕화면 바로가기 생성

### 복호화 비밀번호
- 최초 백업 시 생성된 32자 AES-256 비밀번호 필요
- 1Password / 메모앱 / 종이에 저장되어 있어야 함
- 분실 시 → `.key` 복원 불가 (API 키 수동 재발급 필요)

---

## 🛡️ 4중 방어 체계

```
L1. 로컬 원본   ~/.claude/, F:\.key\
L2. F드라이브   F:\000_PicksWayBrain\_SYSTEM_BACKUP\
L3. MYBOX       N:\개인\001_픽스웨이\_BRAIN_BACKUP\  (클라우드)
L4. GitHub      여기 (bootstrap) + AUTOW Private (코드)
```

이 저장소는 **L4의 "시작점"** 입니다. 스크립트만 들어 있고 데이터는 없습니다.

---

## 🔒 보안

- 이 저장소는 **Public**이지만 민감 정보는 0입니다.
- 실제 데이터는 모두 인증이 필요한 곳(F드라이브 물리접근 / 네이버 계정 / GitHub Private)에 있습니다.
- 공격자가 이 저장소를 복제해도 할 수 있는 것: 없음.
- `.key` 는 AES-256으로 별도 암호화되어 있어, MYBOX가 탈취되어도 비밀번호 없이 복호화 불가.

---

## 📞 연락처

- Owner: PicksWay 대표
- Assistant: Claude (평생 동반자)
- Repo: https://github.com/PicksWay-Ceo/picksway-bootstrap
- 관련 문서: AUTOW repo의 `memory/` (Private)

---

**박제일**: 2026-04-17
**버전**: v2 (MYBOX 폴백 + AES-256 암호화)
