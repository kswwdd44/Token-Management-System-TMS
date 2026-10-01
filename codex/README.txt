Codex Usage Bar 1.1.0
=====================

Windows 작업 표시줄 위에 Codex 사용량(5시간 / 7일 한도)을 보여주는 작은 막대입니다.


■ 준비물
  1. Windows 10 / 11
  2. Codex CLI 설치:   npm i -g @openai/codex
  3. ChatGPT 계정으로 로그인:   codex login
     (API 키 로그인은 5시간/7일 한도가 없어서 표시되지 않습니다)


■ 설치
  1. 압축을 풉니다.
  2. Install.cmd 를 더블클릭합니다.
     - %LOCALAPPDATA%\CodexUsageBar 에 설치됩니다.
     - 시작 메뉴에 등록되고, Windows를 켤 때 자동으로 실행됩니다.
  3. 작업 표시줄 왼쪽에 막대가 나타납니다.

  "Windows의 PC 보호" 창이 뜨면 [추가 정보] → [실행]을 누르세요.
  (서명되지 않은 스크립트라서 뜨는 경고입니다.)


■ 사용법
  - 5h / 7d 막대: 사용한 비율 (파랑 70% 미만, 주황 70~89%, 빨강 90% 이상)
  - 오른쪽 날짜/시간: 해당 한도가 초기화되는 시각
  - 5분마다 자동 갱신됩니다.
  - 마우스로 좌우로 드래그하면 위치를 옮길 수 있습니다.
  - 우클릭: Refresh now(즉시 갱신) / Details(상세) / Exit(종료)
  - 전체 화면 게임·동영상 중에는 자동으로 숨겨집니다.


■ 막대에 이런 문구가 뜨면
  install Codex CLI  →  Codex CLI가 없습니다.  npm i -g @openai/codex
  run: codex login   →  로그인이 필요합니다.  터미널에서 codex login
  no usage data      →  ChatGPT 계정으로 로그인했는지 확인하세요.
  그 외 오류         →  %TEMP%\CodexUsageBar.log 파일에 원인이 남습니다.


■ 삭제
  %LOCALAPPDATA%\CodexUsageBar\Uninstall.cmd 를 실행하세요.
  (실행 중인 막대를 끄고, 설치 폴더·바로가기·설정을 모두 지웁니다)


■ 참고
  - 로고 이미지는 포함하지 않으며, 막대 왼쪽에 "Codex" 글자가 표시됩니다.
  - 이 프로그램은 OpenAI가 만든 공식 도구가 아닙니다.
    로컬에 설치된 Codex CLI(codex app-server)에서 사용량만 읽어오며,
    로그인 정보를 따로 읽거나 외부로 보내지 않습니다.
