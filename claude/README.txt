Claude Usage Bar 1.0.0
======================

Windows 작업 표시줄 위에 Claude 사용량(5시간 / 7일 한도)을 보여주는 작은 막대입니다.


■ 준비물
  1. Windows 10 / 11
  2. Claude Code 설치:   https://claude.com/claude-code
  3. Claude 구독 계정(Pro / Max / Team 등)으로 로그인:   claude /login
     (API 키 로그인은 5시간/7일 한도가 없어서 표시되지 않습니다)


■ 설치
  1. 압축을 풉니다.
  2. Install.cmd 를 더블클릭합니다.
     - %LOCALAPPDATA%\ClaudeUsageBar 에 설치됩니다.
     - 시작 메뉴에 등록되고, Windows를 켤 때 자동으로 실행됩니다.
  3. 작업 표시줄 왼쪽에 막대가 나타납니다.

  "Windows의 PC 보호" 창이 뜨면 [추가 정보] → [실행]을 누르세요.
  (서명되지 않은 스크립트라서 뜨는 경고입니다.)


■ 사용법
  - 5h / 7d 막대: 사용한 비율 (초록 70% 미만, 주황 70~89%, 빨강 90% 이상)
  - 오른쪽 날짜/시간: 해당 한도가 초기화되는 시각
  - 5분마다 자동 갱신됩니다.
  - 마우스로 좌우로 드래그하면 위치를 옮길 수 있습니다.
  - 우클릭: Refresh now(즉시 갱신) / Details(상세) / Exit(종료)
  - 전체 화면 게임·동영상 중에는 자동으로 숨겨집니다.
  - Windows 밝은/어두운 테마에 맞춰 색이 바뀝니다 (시작할 때 적용).
  - Codex Usage Bar 를 함께 쓰면 그 막대가 이 막대 오른쪽에 붙습니다.


■ 로그인 유지
  로그인 토큰이 만료되기 약 10분 전에, 막대가 Claude Code를 짧게 한 번
  실행(claude -p "ok", Haiku 모델)해서 로그인을 자동으로 갱신합니다.
  이때 아주 적은 양의 사용량이 듭니다.


■ 막대에 이런 문구가 뜨면
  install Claude Code →  Claude Code가 없습니다.  위 준비물 참고
  run: claude /login  →  로그인이 필요합니다.  터미널에서 claude /login
  rate limited, Nm    →  사용량 서버가 잠시 막았습니다. N분 뒤 자동 재시도
  그 외 오류          →  %TEMP%\ClaudeUsageBar.attempts.log 에 기록이 남습니다.


■ 삭제
  %LOCALAPPDATA%\ClaudeUsageBar\Uninstall.cmd 를 실행하세요.
  (실행 중인 막대를 끄고, 설치 폴더·바로가기·설정을 모두 지웁니다)


■ 참고
  - 로고 이미지는 포함하지 않으며, 막대 왼쪽에 "Claude" 글자가 표시됩니다.
  - 이 프로그램은 Anthropic이 만든 공식 도구가 아닙니다.
    이 PC에 저장된 Claude Code 로그인 정보로 Anthropic 사용량 API
    (api.anthropic.com) 에만 요청하며, 그 외 어디에도 보내지 않습니다.
  - 주의: 이 사용량 API는 Anthropic이 공식 문서로 공개한 API가 아닙니다.
    예고 없이 바뀌거나 막힐 수 있고, 그러면 막대가 동작하지 않습니다.
    사용 여부는 각자 Anthropic 이용약관을 확인하고 판단하세요.
