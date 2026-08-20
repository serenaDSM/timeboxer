# TimeBoxer

TimeBoxer 是一款面向家庭的轻量儿童屏幕时间管理应用。孩子通过阅读、运动等任务赚取时间，家长通过独立的 Parent Dashboard 设置上学日、周末和假期规则，并实时查看孩子的使用状态和额外时间申请。

当前版本：`v4.0.0 prototype`

- 线上地址：https://timeboxer-app.netlify.app/
- 项目进展：[PROGRESS.md](./PROGRESS.md)

## v4 原型已实现

- 双端界面：独立的 Child View 与 PIN 保护的 Parent Dashboard。
- 本地实时联动：同一浏览器的不同标签页通过持久化状态同步，模拟家长端与孩子端的实时效果。
- 轻量模板：`Strict Reset`（20/40/60 分钟）与 `Balanced`（30/60/90 分钟）。
- 日期规则：自动识别上学日/周末，家长可以把当天切换为 School Day、Weekend 或 Holiday。
- 今日可用时间：自动取“时间币余额”和“今日剩余额度”中的较小值。
- 家长审批：孩子可申请额外 10 分钟，家长批准或拒绝后孩子端实时更新。
- 活动流：记录开始任务、开始娱乐、被规则阻止、申请和审批事件。
- 家庭护栏：单次娱乐上限、睡前 60 分钟禁用、实际连续使用达到 20 分钟后进入休息期、公共健康上限 120 分钟。
- 自定义：家长仍可编辑 Earn/Spend 活动、每日额度、孩子姓名、年龄和睡眠时间。
- 家长测试工具：可直接调整时间币，并把真实分钟临时压缩为 1–300 秒的快速倒计时；关闭后恢复正式计时与防切屏规则。

## 保留的核心能力

- Earn：目标倒计时、完成后 Overtime 奖励、提前退出零收益。
- Spend：余额校验、每日限额、按实际连续使用时长触发护眼冷却、提前退出按比例扣费。
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
```

生产构建输出到 `dist/`。

## 本地联动演示

1. 打开孩子端：`http://localhost:5173/?view=child`
2. 点击 `Parent` 并输入 PIN，或另开家长端：`http://localhost:5173/?view=parent`
3. 在家长端点击 `Open linked tab` 可打开一个独立孩子标签页。
4. 孩子申请额外时间或家长修改计划时，另一个标签页会实时更新。

## 快速计时测试

1. 进入 `Parent Dashboard`，使用家长 PIN 解锁。
2. 在 `Parent-only testing tools` 中直接设置 `Available time coins`。
3. 点击 `10 sec`、`30 sec`、`60 sec`，或在 `Countdown length` 输入 1–300 秒。
4. 返回 Child View 后启动任意 Earn/Play 活动；界面会标明测试秒数对应的真实任务分钟。
5. 测试结束后点击 `Real time`，恢复正式倒计时、全屏和防切屏要求。

测试模式只缩短等待时间。任务奖励、娱乐扣费、每日额度与护眼休息仍按原任务分钟结算。

## macOS 原生原型

`macos/TimeBoxerMac` 已包含第一版原生控制骨架：

- AppKit + WKWebView 外壳，可加载当前 React 生产资源。
- JavaScript → Swift 事件桥和家庭规则快照同步。
- `NSWorkspace` 应用启动、切换和前台应用定时检测。
- 默认 `observe` 安全模式，不会关闭任何程序。
- `enforce` 原型仅对明确配置的 Bundle ID 请求正常退出，不会强制杀进程。
- 全屏 Shield 保留 Earn、Ask Parent 和 Return to Homework。
- 家长主动开启的 `SMAppService` Start at Login 入口。
- 本地 `.app` 组装、相对 Web 资源和 ad-hoc 签名脚本。

详细说明：[macos/TimeBoxerMac/README.md](./macos/TimeBoxerMac/README.md)

```bash
npm run mac:test
npm run mac:build
```

当前开发机已安装、选择并完成 Xcode 16.4 首次初始化。原生应用已完成 Release 编译、ad-hoc 签名、安装和首次启动验证；安装位置为 `/Applications/TimeBoxer.app`。标准 `npm run mac:test` 已执行，Swift 规则测试共 4 项通过；`npm run mac:build` 也可直接完成打包。

## 当前数据与安全边界

所有任务、余额、统计和家长 PIN 目前都保存在当前浏览器的 LocalStorage 中。清理浏览器数据、切换浏览器或更换设备不会自动同步数据。

当前双端联动只在同一浏览器的标签页间工作，用于验证产品交互。真正跨设备的家长端/孩子端联动仍需要后端账户、家庭绑定、设备身份、服务端规则、心跳和推送通知。

当前 PIN 和 Web 防切屏机制用于家庭行为引导，不是不可绕过的系统级家长控制。macOS 原型已开始实现应用检测和温和退出，但独立后台 Agent、防卸载、设备心跳和远程提醒仍是后续工作。

## 默认设置

- 家长 PIN：`1234`（首次使用后应立即修改）
- 默认方案：Balanced
- 上学日/周末/假期：30 / 60 / 90 分钟
- 单次娱乐上限：30 分钟
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
src/rules.js                可测试的业务规则
test/rules.test.js          业务规则测试
PROGRESS.md                 历史进展与路线图
```

## 后续方向

- 将当前本地联动适配到云端家庭账户和实时事件 API。
- Mac 孩子客户端、应用/网站识别、设备心跳和家长推送通知。
- 周度行为洞察与家庭共同制定计划。
- 多租户、订阅计费和公开发布所需的隐私与合规能力。
