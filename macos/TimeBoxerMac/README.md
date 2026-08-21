# TimeBoxer Mac prototype

This directory contains the first native macOS enforcement prototype. It keeps the React child/parent UI and adds an AppKit host, application monitoring, a full-screen shield, and a JavaScript-to-Swift message bridge.

## Enforcement boundary

The default policy is `enforce`. A configured entertainment application is allowed only while a Play timer has issued a non-expired native permission. Otherwise TimeBoxer hides it, requests a graceful quit, shows the shield, and records a family event. The prototype never force-terminates applications.

The local policy is created on first launch at:

```text
~/Library/Application Support/TimeBoxer/family-policy.json
```

浏览器家长端、Mac 孩子端和原生规则共用的完整状态保存在：

```text
~/Library/Application Support/TimeBoxer/family-state.json
```

`family-policy.json` 是从完整状态派生出的原生监管快照；`family-state.json` 才是本机双端同步的权威状态。

TimeBoxer registers itself to start at login. Turning that setting off or quitting the app requires the shared parent PIN. Force Quit and administrator-level removal are not yet prevented; production-grade tamper resistance requires a privileged helper or Apple system parental-control capabilities.

The current monitor identifies native applications through the family Bundle ID list and the macOS `public.app-category.games` category. It cannot distinguish YouTube or a web game from homework inside the same browser; URL-level control requires a browser extension, Network Extension, or Apple Family Controls.

## Build and test

```bash
swift test --package-path macos/TimeBoxerMac
bash macos/TimeBoxerMac/scripts/build-app.sh
```

The ad-hoc signed development app is assembled at:

```text
macos/TimeBoxerMac/build/TimeBoxer.app
```

The script uses ad-hoc signing for local testing. Public distribution will require a full Xcode installation, Developer ID signing, Hardened Runtime, notarization, and a signed installer.

The current development Mac has Xcode 16.4 installed, selected, licensed, and initialized. The equivalent terminal setup for another Mac is:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -license
xcodebuild -version
```

The locally verified app is installed at `/Applications/TimeBoxer.app`. Eight native rule/state XCTest cases pass.

## Safe shield demo

The menu bar item includes `Show Demo Shield`. It displays the shield without monitoring or terminating an application. The three actions intentionally keep access to Earn Time, Ask Parent, and homework.

## Next native milestones

- Replace the local JSON policy with authenticated family/device sync.
- Move monitoring into a tamper-resistant privileged background helper.
- Send heartbeat, block and tamper/offline events to the remote parent service.
- Add browser extensions first, then evaluate a Network Extension content filter.
- Add Developer ID signing and notarized distribution.
