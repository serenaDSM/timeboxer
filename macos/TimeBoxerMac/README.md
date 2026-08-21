# TimeBoxer Mac prototype

This directory contains the native macOS child enforcement client. Its release
bundle contains only the React child UI plus an AppKit host, application monitoring,
a full-screen shield, and a JavaScript-to-Swift message bridge. Parent controls now
belong to the separate iPhone project.

## Enforcement boundary

The default policy is `enforce`. A configured entertainment application is allowed only while a Play timer has issued a non-expired native permission. Otherwise TimeBoxer hides it, requests a graceful quit, shows the shield, and records a family event. The monitor checks every running application once per second. If a blocked application is still running two seconds after the quit request, TimeBoxer force-terminates it.

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

TimeBoxer scans the child Mac's installed applications once at launch and then every minute. Game categories and known streaming clients are suggested for protection; broad categories such as Video or Entertainment are intentionally not auto-selected because they also contain communication and creative tools. The exact protected Bundle ID list is controlled by the parent and shared with the native monitor. It also reads the front Safari or Chrome tab. When a parent-selected built-in or custom domain is opened outside approved Play time, TimeBoxer first replaces the restricted tab with a safe new tab so background audio stops, then hides the browser and displays the shield. macOS asks the parent for browser Automation permission; strict enforcement hides the browser instead of silently allowing access when that permission is unavailable.

This Apple Events browser check is a practical local prototype, not the public-distribution endpoint. Broader browser coverage and tamper-resistant URL filtering still require a browser extension, Network Extension, or Apple Family Controls.

## Build and test

```bash
swift test --package-path macos/TimeBoxerMac
bash macos/TimeBoxerMac/scripts/build-app.sh
```

The ad-hoc signed development app is assembled and strictly verified at:

```text
/private/tmp/timeboxer-mac-build/TimeBoxer.app
```

The repository is stored in a File Provider-managed Documents directory, which
can immediately add Finder metadata to an app bundle and invalidate its signature.
The distributable output therefore stays outside the repository.

The script uses ad-hoc signing for local testing. Public distribution will require a full Xcode installation, Developer ID signing, Hardened Runtime, notarization, and a signed installer.

The current development Mac has Xcode 16.4 installed, selected, licensed, and initialized. The equivalent terminal setup for another Mac is:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
xcodebuild -license
xcodebuild -version
```

The locally verified app is installed at `/Applications/TimeBoxer.app`. Sixteen native rule/state/classification XCTest cases pass.

## Safe shield demo

The menu bar item includes `Show Demo Shield`. It displays the shield without monitoring or terminating an application. The three actions intentionally keep access to Earn Time, Ask Parent, and homework.

## Browser protection test

1. In the parent dashboard, leave `YouTube` selected under Website protection.
2. Make sure no Play timer is running, then open YouTube in Safari or Chrome.
3. Approve the one-time macOS Automation request for TimeBoxer. The browser should hide, the shield should appear, and the family activity list should record the block.
4. Click `Return to homework` and open a non-entertainment site such as Google Docs; it should remain available.
5. Start a Play timer and open YouTube again; it should remain available until the timer ends.

If Automation permission is declined, strict mode hides the browser and asks for parent approval instead of silently allowing unmonitored browsing. Permission can be changed later in System Settings under Privacy & Security > Automation.

## Next native milestones

- Replace the local JSON policy with authenticated family/device sync.
- Move monitoring into a tamper-resistant privileged background helper.
- Send heartbeat, block and tamper/offline events to the remote parent service.
- Add browser extensions first, then evaluate a Network Extension content filter.
- Add Developer ID signing and notarized distribution.
