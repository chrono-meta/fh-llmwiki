# forge-wiki

**[English](README.md)** · 한국어 · **[日本語](README.ja.md)** · **[中文](README.zh.md)**

LLM 에이전트 — 그리고 함께 일하는 사람 — 을 위한 거버넌스 내장 마크다운 위키.

에이전트 지식 도구 대부분은 완전 자동 메모리(mem0, Zep, Letta — 승인 개념 자체가 없음)
아니면 인간 큐레이션 서비스, 둘 중 하나다. forge-wiki는 그 중간을 지킨다:
**에이전트가 쓰고, 사람이 게이트하고, 인덱스는 스스로 유지된다.**

## 세 가지 설계 약속

1. **콘텐츠는 큐레이션, 최신성은 파생.** `INDEX.md`의 `AUTO-INDEX` 블록은 프런트매터와
   파일명 날짜에서 재생성된다 — 이 블록의 머지 충돌은 손으로 푸는 게 아니라 재생성으로
   해소된다. 동시 다중-writer 시뮬레이션으로 검증 (`tests/` 참고 — 최대 50 writer,
   오염 주입 포함).
2. **OKF v0.1 호환.** 파일은 마크다운 + YAML 프런트매터(`type`, `description`),
   예약 `index.md`, 링크=관계 엣지 — 어떤 OKF 소비자도 읽을 수 있고, 락인 없음.
3. **스코프 쓰기, 게이트 머지.** 각 writer는 자기 파일만 소유하고, 타인 파일 변경은
   조용한 수정이 아니라 제안(PR/핸드오프)이다. HITL은 기능 플래그가 아니라 쓰기
   프로토콜 그 자체다. 휴먼 게이트는 **입맛** — 개인·조직의 판단 — 을 얹는 곳이지 결함을
   잡는 곳이 아니다: 기능 무결성은 기계 층의 책임이고, 리뷰어에게 닿기 전에 시뮬레이션으로
   검증된다.

## 빠른 시작

설치할 게 없다: 파이썬 파일 하나, `python3` 외 의존성 없음. 한 번 clone 해서 아무 데나
두고 경로로 호출하면 된다.

```sh
git clone https://github.com/chrono-meta/forge-wiki.git ~/tools/forge-wiki
alias fw='python3 ~/tools/forge-wiki/bin/fw.py'   # 선택 — 아래 예시는 전부 `fw` 사용

cd your-knowledge-repo   # 위키를 담을 레포 — 위에서 clone 한 곳이 아니다
fw init                  # Phase-0 감사 + 비덮어쓰기 스캐폴드 (signals/ 생성)
mkdir -p memory          # 나머지 섹션은 직접 — 섹션은 그냥 디렉터리다
# 섹션 디렉터리에 마크다운 파일을 넣고
fw sync --write          # 최신성 인덱스 + llms.txt 재생성
fw doctor                # 신선도 + 죽은 포인터 리포트
```

**성공 판정**: `INDEX.md`에 파일들이 섹션별로 나열된 `AUTO-INDEX` 블록이 생기고
`fw check`가 exit 0. `doctor`는 조언용이라 **0이 아닌 종료코드는 리포트지 설치 실패가 아니다.**

이제 레포는 이런 모양이다:

```
your-knowledge-repo/
├── INDEX.md      위쪽은 큐레이션 포인터, 아래쪽은 생성된 AUTO-INDEX 블록
├── AGENTS.md     init이 덧붙인 위키 프로토콜 블록 — 에이전트 대면 계약
├── llms.txt      sync --write 마다 생성
├── memory/
└── signals/
```

`INDEX.md`에서 머지 충돌이 나면: 아무 쪽이나 택하고 `fw heal --write`. 끝.

## 우리 조직의 인스턴스

`fw init`은 돌아가는 인덱스를 준다. 하지만 *거기에 무엇을 담을지*는 말해주지 않는다 —
그 결정이 이 위키를 당신 것으로 만들고, 어떤 도구도 대신해줄 수 없다.

이 도구가 상정하는 짝: **하네스는 방법론과 게이트를 지고, 위키는 조직 맥락을 진다.**
서로를 대체하지 않는다. 맥락 착지소가 없는 하네스는 매 세션 같은 조직적 사실을 다시
유도해내고, 하네스가 없는 위키는 무엇이 들어올지에 게이트가 없다.

약 2개월의 일일 운영을 견딘 섹션 축 (981개 파일 — 상위 4개 섹션이 그중 73%):

| 섹션 | 담는 것 | 들어오는 시점 |
|---|---|---|
| `memory/` | 발견한 세션보다 오래 사는 사실 | 다시 필요해질 사실이고 코드에서 유도되지 않을 때 |
| `tracks/<project>/` | 프로젝트별 작업 기록, 누적 | 그 프로젝트 작업이 다시 읽을 가치를 냈을 때 |
| `signals/` | 나중에 중요해질 *수도* 있는 관찰·측정 | 알아챈 순간 — 값어치가 날지 알기 전에 기록 |
| `handoff/` | 머신·세션·사람 사이로 넘기는 상태 | 다음 독자가 지금 쓰는 사람이 아닐 때 |
| `audit/` | 케이던스에 따른 주기 점검 | 케이던스가 발동할 때, 내키는 때가 아니라 |
| `digests/` | 반복 외부 스캔 | 자동 잡이 산출물을 떨굴 때 |

**두 개로 시작해라** — `memory/`와 `signals/`. 나머지는 어떤 파일이 기존 섹션에 정말로
안 맞는 첫 순간에 생겨나게 두면 된다. 디렉터리 추가는 싸다. **아무도 쓰지 않는 섹션은
채우라는 신호가 아니라 지우라는 신호다.**

**둘 중 어디에?** 질문 두 개면 대부분 갈린다. *이건 코드에서 다시 유도할 수 있나?* —
있으면 `memory/`에 넣을 게 아니다. *판정이 났나?* — 안 났으면 결정 기록이 아니라
`signals/` 항목이다.

`examples/org-instance/`가 최소 뼈대다. **아직 `init` 하지 않은** 레포에 복사해라 —
자기 `INDEX.md`를 갖고 오는데 `fw init`은 기존 INDEX.md를 덮어쓰지 않는다:

```sh
cp -r ~/tools/forge-wiki/examples/org-instance/. your-knowledge-repo/
cd your-knowledge-repo
fw init          # 복사된 INDEX.md는 그대로 두고, AGENTS.md 블록만 덧붙인다
fw sync --write
```

## 서브커맨드

| cmd | 하는 일 | 실패 방향 |
|---|---|---|
| `init` | 상태 감사 + 스캐폴드 (절대 덮어쓰지 않음) | 기존 파일 있으면 거부 |
| `sync [--write]` | AUTO-INDEX 블록 재생성 | 기본 dry-run |
| `heal [--write]` | 충돌 마커/중복 블록 정리 후 sync | 큐레이션 영역 충돌은 사람 몫 |
| `lint` | 프런트매터 리포트 | 리포트만, 절대 고쳐쓰지 않음 |
| `doctor` | 신선도 + 죽은 포인터 리포트 | 조언만 |
| `check` | 인덱스 드리프트 게이트 | 드리프트 시 exit 1 (CI 차단) |

## 위키가 여럿일 때 — 회사 · 조직 · 프로젝트 · 개인

기밀 경계 하나에 위키 하나, 위키끼리는 링크 목록(레지스트리)으로만 잇고 내용은 복제하지 않는다.
그 계약이 [`LAYERS.md`](LAYERS.md)다(층 L0–L3 · 언제 레포를 나누나 · 개인 위키에서 조직 위키로 올리기).
기계가 확인할 수 있는 부분은 `bin/fw_layers.py` 가 본다:

```sh
python3 bin/fw_layers.py declare .          # 이 위키가 자기 층을 밝히고 상위 위키를 가리키나
python3 bin/fw_layers.py links .            # 위키 안 링크가 다 열리나
python3 bin/fw_layers.py promote notes/x.md ../org-wiki/signals --patterns <조직 패턴 파일>   # 푸시 전에 스크럽
python3 bin/fw_layers.py split-report .     # «레포를 둘로 나눠야 하나» 의 근거 숫자 — 판정은 안 한다
```

DB · MCP 관문은 조건이 실제로 생겼을 때만 붙이는 어댑터다. 각각 [`adapters/`](adapters/README.md)
의 작업 설명서이고 기본으로 배선된 것은 없다. `examples/federation/` 은 위키 셋짜리 예시,
`tests/test_layers.sh` 가 그 앵커다.

## 상태

v0.1 — 약 2개월간 매일 운영된 비공개 운영자 위키에서 추출: **마크다운 981개 파일,
57일 중 50일 커밋, 멀티머신** (2026-07-21 실측 — `git ls-files '*.md' | wc -l`;
저장소 자체는 비공개). `tests/`의 동시성 시뮬레이션이 모든 견고성 주장의 회귀 앵커다:
시뮬이 측정하지 않은 것은 여기서 주장하지 않는다.

## 유통 표면

- `llms.txt` — `sync --write`마다 생성 (인덱스처럼 파생물).
- `bin/fw_mcp.py` — 무의존 읽기전용 MCP 서버 (`wiki_index` / `wiki_get` / `wiki_search`).
  읽기는 MCP로, 쓰기는 git + 게이트로 — 이 비대칭은 빠진 기능이 아니라 쓰기 프로토콜이다.
  `claude mcp add forge-wiki -- python3 <abs>/bin/fw_mcp.py <wiki_root>`

전체 계약은 `SPEC.md` 참고.
