# TimeBoxer

TimeBoxer 是一款面向家庭的轻量儿童屏幕时间管理应用。孩子通过阅读、运动等任务赚取时间，家长通过独立的 Parent Dashboard 设置上学日、周末和假期规则，并实时查看孩子的使用状态和额外时间申请。

当前版本：`v4.3.0 prototype`

- 线上地址：https://timeboxer-app.netlify.app/
- 项目进展：[PROGRESS.md](./PROGRESS.md)

## v4 原型已实现

- 双端界面：独立的 Child View 与 PIN 保护的 Parent Dashboard。
- 本机双端联动：浏览器家长端、Mac 孩子端和原生监管规则共同使用一份带版本号的家庭状态，并显示 Mac 在线心跳。
- 轻量模板：`Strict Reset`、`Balanced`、`Collaborative`，分别提供上学日、周末和假期的基础额度与每日可赚上限。
- 日期规则：自动识别上学日/周末，家长可以把当天切换为 School Day、Weekend 或 Holiday。
- 今日可用时间：基础额度 + 当日任务奖励 + 家长临时加时 - 今日已使用；任务奖励不跨日滚存。
- 家长审批：孩子可申请额外 10 分钟，家长批准或拒绝后孩子端实时更新。
- 活动流：记录开始任务、开始娱乐、被规则阻止、申请和审批事件。
- 家庭护栏：单次娱乐上限、睡前 60 分钟禁用、实际连续使用达到 20 分钟后进入休息期、公共健康上限 120 分钟。
- 自定义：家长仍可编辑 Earn/Spend 活动、每日额度、孩子姓名、年龄和睡眠时间。
- 家长测试工具：可直接调整当日奖励，并把真实分钟临时压缩为 1–300 秒的快速倒计时；关闭后恢复正式计时与防切屏规则。
- 默认关闭娱乐：Earn 是否完成不再决定监管状态；只有孩子在 TimeBoxer 点击 Play 后，受管娱乐 App 才获得一段有明确截止时间的临时通行证。Mac 孩子端会扫描实际安装的 App，明确的游戏和已知流媒体应用默认建议保护，最终选择由家长端开关决定。
- 家长端手机界面：Parent Dashboard 固定为手机优先的单列信息结构；状态、待审批请求、今日额度和最近动态优先常显，低频设置按类别折叠，在桌面预览时也以 430px 手机画板显示。
- 个性化保护：家长端显示孩子 Mac 实际检测到的应用，同时提供内置网站建议和自定义网站入口。
- 家长提醒中心：孩子申请、受限 App/网站拦截、任务完成和娱乐使用按严重程度进入独立通知中心；违规事件显示首屏红色警告和未读角标，可在测试工具中发送模拟拦截提醒。家长主动授权后，支持浏览器运行期间的系统通知；App 完全关闭后的远程推送仍需后续 iPhone App 与云端服务。

## 独立客户端拆分（进行中）

- `macos/TimeBoxerMac` 是独立的孩子 Mac 客户端。发布构建只打包 Child UI，原生状态栏和 URL 均不能再打开家长界面。
- `ios/TimeBoxerParent` 是独立的 SwiftUI 家长 iPhone 客户端，已包含手机首屏、Mac 在线状态、违规提醒、加时审批、折叠设置与六位配对码流程。
- `contracts` 保存家长端、孩子端和云端共同遵守的策略与设备事件 JSON Schema。
- `supabase` 保存未连接线上项目的本地云端工程，包含多家庭数据结构、RLS、设备凭证和推送令牌的私有存储边界。
- 当前线上账户中没有专用 TimeBoxer Supabase 项目，因此迁移尚未应用到任何在线数据库，不会影响其他项目。

## 保留的核心能力

- Earn：目标倒计时、完成后 Overtime 奖励、提前退出零收益。
- Play：受每日剩余额度、单次上限、睡前保护和护眼冷却共同约束；按实际使用时长计入今日用量。
- 家长控制：应用内 PIN 解锁、任务管理、模板/限额设置、数据清零和 PIN 修改。
- 防作弊：全屏/窗口尺寸、焦点和页面可见性检测；针对手机和 iPad 使用不同策略。
- 数据：Zustand + LocalStorage 本地持久化、累计赚取和消费统计。
- UI：单一绿色立方体 `TIMEBOXER` Logo、白色底板、绿色主色与紫色 Play 辅助色；React 19、Tailwind CSS 4、响应式手机/iPad/桌面布局。

## 本地开发

要求 Node.js 20 或更高版本。

```bash
npm ci
npm run dev
```

默认地址为 `http://localhost:5173/`。

## 质量检查

```bash
npm run lint
npm test
npm run build
npm run build:child
npm run build:parent-preview
npm run ios:build
```

`npm run mac:build` writes its strictly verified child-only bundle to
`/private/tmp/timeboxer-mac-build/TimeBoxer.app`. The output stays outside the
File Provider-managed project directory so Finder metadata cannot invalidate its
signature after the build finishes.

生产构建输出到 `dist/`。

## 本机双端联动演示

1. 打开孩子端：`http://localhost:5173/?view=child`
2. 点击 `Parent` 并输入 PIN，或另开家长端：`http://localhost:5173/?view=parent`
3. 保持 `/Applications/TimeBoxer.app` 运行；家长端标题旁应显示 `Mac child linked · one shared state`。
4. 家长修改计划、奖励或测试时间后，Mac 孩子端和原生规则会更新；孩子完成任务或提出申请后，家长端会轮询更新。

当前本机同步服务通过开发服务器的 `/api/family-state` 接口读写：

```text
~/Library/Application Support/TimeBoxer/family-state.json
```

状态包含统一的基础额度、当日奖励、家长加时、今日使用量、活动、申请、任务和计划字段；`revision` 只在数据变化时增加。Mac 在线状态独立保存在 `mac-heartbeat.json`，不会接触或覆盖家庭业务数据。

## 快速计时测试

1. 进入 `Parent Dashboard`，使用家长 PIN 解锁。
2. 在 `Parent-only testing tools` 中直接设置 `Earned bonus today`。
3. 点击 `10 sec`、`30 sec`、`60 sec`，或在 `Countdown length` 输入 1–300 秒。
4. 返回 Child View 后启动任意 Earn/Play 活动；界面会标明测试秒数对应的真实任务分钟。
5. 点击 `Send test blocked alert` 可验证家长端红色违规卡片、铃铛未读角标和通知中心。
6. 测试结束后点击 `Real time`，恢复正式分钟倒计时；全屏和防切屏在测试与正式模式中都会生效。

测试模式只缩短等待时间。任务奖励、娱乐使用量、每日额度与护眼休息仍按原任务分钟结算。

## macOS 原生原型

`macos/TimeBoxerMac` 已包含第一版原生控制骨架：

- AppKit + WKWebView 外壳，可加载当前 React 生产资源。
- JavaScript → Swift 事件桥和家庭规则快照同步。
- `NSWorkspace` 应用启动、切换和前台应用定时检测。
- 默认 `enforce` 家长控制模式；没有有效 Play 通行证时，会隐藏并请求正常退出明确配置的娱乐 App，但不会强制杀进程。
- 全屏 Shield 保留 Earn、Ask Parent 和 Return to Homework。
- 使用 `SMAppService` 自动注册随登录启动；关闭开机启动或退出 TimeBoxer 需要家长 PIN。
- 本地 `.app` 组装、相对 Web 资源和 ad-hoc 签名脚本。

详细说明：[macos/TimeBoxerMac/README.md](./macos/TimeBoxerMac/README.md)

```bash
npm run mac:test
npm run mac:build
```

当前开发机已安装、选择并完成 Xcode 16.4 首次初始化。原生应用已完成 Release 编译、ad-hoc 签名、安装和首次启动验证；安装位置为 `/Applications/TimeBoxer.app`。标准 `npm run mac:test` 已执行，Swift 规则与状态测试共 8 项通过；`npm run mac:build` 也可直接完成打包。

## 当前数据与安全边界

浏览器仍保留 LocalStorage 作为离线缓存，但在本机开发模式下，浏览器家长端与安装版 Mac 孩子端以统一的 `family-state.json` 为同步状态。清理单端缓存后会从共享状态恢复。

当前同步后端只运行在同一台 Mac 上，用于真实验证两种客户端的数据和原生监管规则。手机家长端在外网访问、跨设备通知和多家庭正式发布，仍需要云端账户、家庭绑定、设备身份、服务端授权和推送通知。

当前 PIN 和 Web 防切屏机制仍不是不可绕过的系统级家长控制。macOS 原型已实现已安装 App 扫描、受管 App 默认关闭、Play 限时放行、登录启动和退出保护；Force Quit、防卸载、独立特权后台 Agent 和远程手机提醒仍是后续工作。Safari/Chrome 已支持家长选择及自定义受限域名，但更广泛浏览器覆盖仍需要浏览器扩展、Network Extension 或 Apple Family Controls。

## 默认设置

- 家长 PIN：`1234`（首次使用后应立即修改）
- 默认方案：Balanced
- 基础额度（上学日/周末/假期）：20 / 30 / 40 分钟
- 可赚奖励上限（上学日/周末/假期）：10 / 20 / 20 分钟
- 单次娱乐上限：20 分钟
- 护眼冷却期：10 分钟
- 正式任务时长范围：10–180 分钟
- 快速测试倒计时：关闭或 1–300 秒（仅家长端可设置）

## 目录

```text
src/App.jsx                 主界面与任务操作
src/policy.js              模板、日期、睡前和可用时间规则引擎
src/components/ChildDashboard.jsx
src/components/ParentDashboard.jsx
src/components/Timer.jsx    Earn/Spend 计时与防切屏逻辑
src/components/Onboarding.jsx
src/store.js                Zustand 持久化状态
src/familyState.js          Web、Mac 与后端共用的家庭状态字段契约
src/useFamilySync.js        浏览器 API 轮询与 WebKit 原生桥双向同步
scripts/local-family-state-api.mjs 本机状态 API
src/rules.js                可测试的业务规则
test/rules.test.js          业务规则测试
contracts/                  跨端策略与设备事件契约
ios/TimeBoxerParent/        独立 SwiftUI 家长 iPhone 客户端
supabase/                   多家庭云端数据库与安全迁移
PROGRESS.md                 历史进展与路线图
```

## 后续方向

- 将当前本地联动适配到云端家庭账户和实时事件 API。
- Mac 孩子客户端、应用/网站识别、设备心跳和家长推送通知。
- 周度行为洞察与家庭共同制定计划。
- 多租户、订阅计费和公开发布所需的隐私与合规能力。
