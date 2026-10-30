# 브라우저 배포

플레이 주소: https://Kimminsung415.github.io/minesweeper_Roguelike/

Godot 4.5.1의 단일 스레드 웹 실행본입니다. 접속한 사람마다 독립적으로 플레이합니다.
프로젝트를 실행하는 서버·로그인·사용자 데이터베이스는 없습니다.
GitHub Pages는 docs의 정적 파일만 제공하며 게임은 방문자의 브라우저에서 실행합니다.

## 처음 한 번: Pages 설정

GitHub 저장소 Settings → Pages → Source: Deploy from a branch → main /docs → Save.
배포가 완료되면 위 주소에서 플레이할 수 있습니다. 별도 도메인은 필요 없습니다.
소스 프로젝트와 Windows ZIP만 올려서는 웹 게임이 실행되지 않습니다.

## 업데이트

1. release.json의 버전/빌드를 VERSIONING.md 기준에 따라 갱신하고 CHANGELOG.md에 기록합니다.
2. Godot 4.5.1과 같은 버전의 내보내기 템플릿을 준비합니다.
3. PowerShell 7에서 `./tools/export_web.ps1 -GodotPath 'Godot 콘솔 실행 파일 경로'`를 실행합니다.
4. 생성된 docs 파일 전체와 소스 변경을 main에 커밋하고 push합니다.
5. GitHub Pages 배포 완료 뒤 실제 주소를 열어 확인합니다.

편집기에서는 Project → Export → Web → Export Project → docs/index.html로 내보낼 수도 있습니다.
Thread Support는 꺼 두고 Compatibility 렌더러를 유지합니다.
docs/.gdignore는 편집기가 웹 실행본을 다시 게임 리소스로 가져오지 않도록 하는 파일입니다.
생성된 .js/.wasm/.pck 등은 이름을 바꾸지 말고 HTML과 함께 배포합니다.

## 로컬 확인

`python -m http.server 8765 --bind 127.0.0.1 --directory docs`를 실행하고
http://127.0.0.1:8765 에 접속합니다. index.html 파일을 직접 더블 클릭하는 방식은 사용하지 않습니다.
Pages 경로는 저장소 이름의 대소문자를 포함해 정확히 사용합니다.

## 조작

- 좌클릭: 파기 / 공개 숫자 칸 주변 파기.
- 우클릭: 깃발. 캔버스 안에서 브라우저 메뉴 대신 게임 입력으로 처리합니다.
- Space / Enter: Commit. 게임 화면을 한 번 클릭해 키보드 입력을 활성화합니다.
- 오른쪽 보유 카드: 설명 보기. 상점: 티켓 구매.
- 새로고침/탭 닫기는 현재 런을 초기화합니다. 저장 기능은 아직 없습니다.
- 현재 UI는 PC 마우스/키보드용이며 모바일 터치용 깃발 조작은 추가하지 않았습니다.

## 포함된 고지

Noto Sans KR: assets/fonts/OFL.txt. 원본 출처: https://github.com/google/fonts/tree/main/ofl/notosanskr
영역전개 이미지: assets/IMAGE_SOURCES.md. Godot 고지: LICENSES/ 폴더.
웹 docs/licenses/에도 고지 파일을 함께 제공합니다.
