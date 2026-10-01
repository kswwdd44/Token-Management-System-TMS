# Token-Management-System-TMS

Windows 작업 표시줄 위에 **Claude**와 **Codex** 사용량(5시간 / 7일 한도)을 보여주는 작은 막대입니다.
PowerShell 스크립트로만 만들어져 있어서 따로 빌드하거나 설치할 프로그램이 없습니다.

| 폴더 | 내용 | 필요한 것 |
|---|---|---|
| [`claude/`](claude/) | Claude 사용량 막대 | Claude Code + 구독 계정 로그인 (`claude /login`) |
| [`codex/`](codex/) | Codex 사용량 막대 | Codex CLI + ChatGPT 계정 로그인 (`codex login`) |

둘 중 하나만 써도 되고, 둘 다 설치하면 Codex 막대가 Claude 막대 오른쪽에 나란히 붙습니다.

## 설치

1. 이 저장소를 내려받습니다 (**Code → Download ZIP**, 또는 Releases의 zip).
2. 쓰고 싶은 폴더(`claude` 또는 `codex`)에서 `Install.cmd`를 더블클릭합니다.
3. 작업 표시줄 왼쪽에 막대가 나타납니다. Windows를 켤 때마다 자동으로 실행됩니다.

"Windows의 PC 보호" 창이 뜨면 **추가 정보 → 실행**을 누르세요. 서명되지 않은 스크립트라서 뜨는 경고입니다.

자세한 사용법, 오류 문구별 해결 방법, 삭제 방법은 각 폴더의 `README.txt`에 있습니다.

## 기능

- 5h / 7d 사용률 막대와 초기화 시각 표시
- 70% 이상 주황, 90% 이상 빨강
- 5분마다 자동 갱신, 우클릭으로 즉시 갱신
- 좌우로 드래그해서 위치 이동
- 전체 화면 게임·동영상 중에는 자동으로 숨김

## 동작 방식

- **Claude**: 이 PC에 저장된 Claude Code 로그인 정보로 `api.anthropic.com`의 사용량 주소에 요청합니다.
  로그인 토큰이 만료되기 전에 `claude -p`를 한 번 실행해서 로그인을 갱신합니다 (아주 적은 사용량이 듭니다).
- **Codex**: 설치된 Codex CLI의 `codex app-server`에 사용량을 물어봅니다.

두 막대 모두 로그인 정보를 다른 곳으로 보내지 않습니다.

## 주의

- 이 프로젝트는 Anthropic이나 OpenAI가 만든 공식 도구가 아니며, 두 회사와 관련이 없습니다.
  "Claude"는 Anthropic의, "Codex"와 "ChatGPT"는 OpenAI의 상표입니다.
- 로고나 상표 이미지는 포함하지 않으며, 막대에는 제품 이름이 글자로만 표시됩니다.
- Claude 막대가 쓰는 사용량 주소는 공식 문서로 공개된 API가 아닙니다.
  예고 없이 바뀌거나 막힐 수 있습니다. 사용 여부는 각자 이용약관을 확인하고 판단하세요.

## 라이선스

[MIT](LICENSE)
