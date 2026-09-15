# Get started with DeskPet

1. Open the DMG and drag DeskPet to Applications.
2. Open DeskPet. Choose **Add a Pet** and select a folder containing `pet.json` and `spritesheet.webp`. Artwork is not included; see [pet format](pets.md).
3. Open the paw icon in the menu bar to adjust your pet. Changes apply immediately.

## Your companion

Drag the pet to move it. It reacts to coding activity and displays completion or permission captions. Click a waiting or completed pet to return to the corresponding supported agent session.

Use **＋** in settings to add another pet. Select it from the pet menu.

## Start with macOS

Turn on **Open at Login** in settings. macOS may ask you to approve DeskPet in System Settings →
General → Login Items, and the switch opens that panel when approval is pending.

Earlier versions started through an `ai.deskpet` LaunchAgent. Turning the switch either way now
retires that agent, so startup is controlled in one place. The switch stays off until you turn it on.

## Connect your agents

Orca status and supported CLI process activity are detected locally. Exact prompt/completion events for Codex and OpenCode require hooks; process activity alone cannot identify permission requests reliably.

For hook integration, follow the source installation in [README](../README.md). Restart OpenCode after installation and trust the Codex hook through `/hooks`. Orca's internal Codex may require its own hook trust.

Orca focus integration depends on its installed runtime version. If clicking does not open the expected session, use Orca directly and report your Orca version in an issue.

## 한국어

DMG를 열어 DeskPet을 Applications로 옮긴 뒤 실행하세요. **펫 추가**에서 펫 폴더를 선택하면 설치됩니다. 메뉴바 발바닥 아이콘에서 크기·말풍선·움직임을 조절할 수 있습니다.

macOS와 함께 켜려면 설정에서 **로그인 시 실행**을 켜세요. 승인이 필요하면 시스템 설정의 로그인 항목이 열립니다. 예전 버전이 쓰던 `ai.deskpet` LaunchAgent는 이 스위치를 건드리면 정리됩니다.

펫 그림은 포함되지 않습니다. Codex·OpenCode의 정확한 완료/승인 대기 알림에는 README의 소스 설치와 훅 신뢰가 필요합니다. 앱만 설치하면 로컬 Orca 상태와 지원되는 CLI 활동을 감지합니다.
