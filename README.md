# TMS — 작업표시줄에서 바로 보는 AI 사용량

**작업 흐름을 유지하면서, Windows 작업표시줄에서 Claude Code·Codex 사용량을 확인하세요.**

Keep Claude Code and Codex usage visible on your Windows taskbar.

TMS(Token Management System)는 Windows 작업표시줄 위에 **Claude Code**와 **Codex**의 사용량(5시간 / 7일 한도)과 초기화 시각을 표시하는 작은 막대입니다.
PowerShell 스크립트로 만들어져 있어 별도 빌드 없이 실행할 수 있습니다.

## 핵심 장점: 작업표시줄에서 바로 확인

- **사용량 확인을 위한 작업 전환 줄이기** — 별도 사용량 페이지나 설정 창을 매번 열어보는 번거로움을 줄입니다.
- **남은 작업을 계획하기 쉽게** — 사용률과 다음 초기화 시각을 한눈에 확인해, 한도에 가까워졌는지 살펴볼 수 있습니다.
- **Claude Code와 Codex를 나란히** — 두 서비스를 함께 사용할 때 각각의 사용량을 작업표시줄에서 비교할 수 있습니다.
- **작업 화면을 넓게 유지** — 작은 막대로 표시되며, 전체 화면 게임·동영상 중에는 자동으로 숨습니다.

사용량은 **5분마다 자동 갱신**되며, 우클릭 메뉴에서 즉시 새로고침할 수 있습니다.

| 폴더 | 내용 | 필요한 것 |
|---|---|---|
| [`claude/`](claude/) | Claude 사용량 막대 | Claude Code + 구독 계정 로그인 (`claude /login`) |
| [`codex/`](codex/) | Codex 사용량 막대 | Codex CLI + ChatGPT 계정 로그인 (`codex login`) |

둘 중 하나만 써도 되고, 둘 다 설치하면 Codex 막대가 Claude 막대 오른쪽에 나란히 붙습니다.

## v1.2.0 다운로드와 새 기능

[**Windows 배포 ZIP 다운로드**](https://github.com/kswwdd44/Token-Management-System-TMS/releases/download/v1.2.0/TMS-v1.2.0-Windows.zip) · [릴리스 설명](https://github.com/kswwdd44/Token-Management-System-TMS/releases/tag/v1.2.0)

- **로그인 시 자동 실행 설정** — 우클릭 메뉴에서 Windows 로그인 시 실행을 켜고 끌 수 있습니다.
- **공식 초기화권 화면으로 바로 이동** — 왼쪽 제품명을 클릭하고 확인하면 해당 서비스의 공식 사용량 화면이 열립니다. 초기화권은 공식 화면에서 최종 사용합니다.
- **설치 상태 진단** — `Get-TmsStatus.ps1`로 CLI 설치 여부, 저장된 TMS 버전, 자동 실행 바로가기 존재 여부를 확인할 수 있습니다. 진단은 로그인 정보 내용을 읽거나 모델을 실행하지 않습니다.
- **업데이트·삭제 개선** — 설치 폴더 식별자를 확인하고, 삭제 시 로그인 정보와 표시 설정을 보존합니다.

## 설치

1. 이 저장소를 내려받습니다 (**Code → Download ZIP**, 또는 Releases의 zip).
2. 쓰고 싶은 폴더(`claude` 또는 `codex`)에서 `Install.cmd`를 더블클릭합니다.
3. 작업 표시줄 왼쪽에 막대가 나타납니다. Windows 로그인 시 자동으로 실행됩니다. 우클릭 메뉴에서 끌 수 있습니다.

"Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누르세요. 서명되지 않은 스크립트라서 뜨는 경고입니다.

자세한 사용법, 오류 문구별 해결 방법, 삭제 방법은 각 폴더의 `README.txt`에 있습니다.

## 기능

- 5h / 7d 사용률 막대와 초기화 시각 표시
- 70% 이상 주황, 90% 이상 빨강
- 5분마다 자동 갱신, 우클릭으로 즉시 갱신
- 좌우로 드래그해서 위치 이동
- 전체 화면 게임·동영상 중에는 자동으로 숨김
- 왼쪽 제품명 클릭으로 공식 초기화권 사용 화면 이동
- 우클릭으로 로그인 시 자동 실행 설정 변경

## 동작 방식

- **Claude**: 이 PC에 저장된 Claude Code 로그인 정보로 `api.anthropic.com`의 사용량 주소에 요청합니다.
  로그인 토큰이 만료되기 전에 `claude -p`를 한 번 실행해서 로그인을 갱신합니다 (아주 적은 사용량이 듭니다).
- **Codex**: 설치된 Codex CLI의 `codex app-server`에 사용량을 물어봅니다.

TMS는 로그인 정보를 개발자나 Agensi에 보내지 않습니다. Claude 바는 사용량 조회를 위해 인증 정보를 Anthropic 서버로 전송하며, Codex 바는 설치된 Codex CLI의 인증을 사용합니다. 자세한 접근 범위는 [SECURITY-AND-DATA.txt](SECURITY-AND-DATA.txt)에 적혀 있습니다.

## 주의

- 이 프로젝트는 Anthropic이나 OpenAI가 만든 공식 도구가 아니며, 두 회사와 관련이 없습니다.
  "Claude"는 Anthropic의, "Codex"와 "ChatGPT"는 OpenAI의 상표입니다.
- 로고나 상표 이미지는 포함하지 않으며, 막대에는 제품 이름이 글자로만 표시됩니다.
- Claude 막대가 쓰는 사용량 주소는 공식 문서로 공개된 API가 아닙니다.
  예고 없이 바뀌거나 막힐 수 있습니다. 사용 여부는 각자 이용약관을 확인하고 판단하세요.

## 검증 범위와 알려진 제한

- Windows PowerShell 5.1 구문 검사와 별도 테스트 폴더에서의 설치·업데이트·진단·삭제 및 초기화 화면 클릭 연결 검사를 수행했습니다.
- 새 Windows 계정, 재부팅 후 자동 실행, 실제 계정의 인증·사용량 조회는 이번 릴리스 검사에서 검증하지 않았습니다.
- Claude 바의 기존 로그인 토큰·비공개 사용량 API 접근 방식은 공급자의 배포 허용 여부를 별도로 확인해야 합니다. 이 공개 릴리스는 공급자 승인 또는 Agensi 판매 승인을 의미하지 않습니다.
- 문제가 있으면 실행 중인 바를 종료하고 [v1.0.0 릴리스](https://github.com/kswwdd44/Token-Management-System-TMS/releases/tag/v1.0.0)의 설치본으로 되돌릴 수 있습니다.

## 라이선스

[MIT](LICENSE)
