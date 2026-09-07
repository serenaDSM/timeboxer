# PROGRESS: TimeBoxer (时间管理者 - 儿童专注打卡 APP)

## 📌 第一阶段：项目信息 (Project Info)
* **部署地址 (Netlify)**：[https://timeboxer-app.netlify.app/](https://timeboxer-app.netlify.app/)
* **源码仓库 (GitHub)**：[https://github.com/serenaDSM/timeboxer](https://github.com/serenaDSM/timeboxer)
* **核心定位**：一款专为 11 岁男孩设计的硬核防作弊、游戏化时间管理 Web 应用。
* **核心功能模块**：
  * **Earn Time (赚取区)**：完成指定任务（如阅读、运动）获取时间币。
  * **Spend Time (消费区)**：消耗时间币兑换娱乐时间（如游戏、视频）。
  * **Anti-Cheat (防作弊系统)**：全屏锁定与焦点监控，杜绝挂机与切屏。
* **技术栈**：React + Vite + TailwindCSS + Zustand (本地持久化存储)。
* **UI/UX 风格**：赛博朋克/暗黑游戏风 (黑底 + 霓虹绿/红，大字号倒计时)。

## 📌 v3.0 核心机制设计文档 (Design Document)

### 1. 赚取区 (EARN TIME)：保底门槛 + 超额无限秒表
* **阶段一 (保底倒计时)**：必须完成设定的目标时间（如 30 分钟）。若提前退出，收益为 0。
* **阶段二 (超额正向秒表)**：倒计时归零后，不强制结束，而是无缝转为“金色正向秒表”。孩子之后每多坚持一分钟，都能获取额外的超额时间币。退出时可一次性领取所有奖励。

### 2. 消费区 (SPEND TIME)：防沉迷强管控系统
* **每日动态限额 (Daily Cap)**：引入 `Today's Limit` 概念。家长可通过密码随时修改当日上限（如上学日 20 分钟，周末 120 分钟）。哪怕余额有几百分钟，当天消费达到上限后，所有消费任务立刻锁定。
* **用眼冷却期 (Cooldown)**：每次完整完成消费任务后，SPEND 区域自动进入可由家长配置的强制冷却期（默认 20 分钟），倒计时结束前无法再次开始娱乐；提前结束不触发冷却。
* **自由汇率调控 (Inflation)**：通过自定义任务功能，家长可自由设定“实际游玩时间”与“消耗时间币”的比例（例如：玩 15 分钟游戏，扣除 30 个时间币），实现汇率贬值。
* *(注：支持提前结束消费并退还剩余时间币，取消“一票买断制”)*。

---

## 📈 历史版本与进度追踪 (Progress Tracking)

### [2026-05-04] v1.0 基础版本上线
- [x] 完成项目框架搭建，配置 TailwindCSS 暗黑主题。
- [x] 开发核心组件：全屏倒计时器 (`Timer.jsx`)、赚取/消费任务卡片、时间币余额自动更新。
- [x] 集成 Zustand 状态管理与 `LocalStorage` 数据持久化。
- [x] 初步防作弊 1.0：倒计时期间离开标签页（触发 `blur`）会自动暂停。

### [2026-05-13] v2.0 深度防作弊与自定义更新
- [x] **数据统计功能**：新增 `All Time Stats`，展示应用累计总赚取和总消费时间。
- [x] **动态任务表单**：支持在页面前端随时添加自定义名称、时长和奖励的赚取任务。
- [x] **家长防退出密码锁**：倒计时中途点击退出(❌)，强制要求输入家长 PIN 码 (`1234`)，防止强行中断。
- [x] **霸屏机制 (Anti-Cheat 2.0)**：
  - 点击开始倒计时时，强制检测窗口大小，若不是全屏状态，则通过 `requestFullscreen()` 强制拉起浏览器全屏。
  - 倒计时过程中，监控 `resize`，若窗口高度/宽度被缩小（比如企图露出桌面看视频），倒计时立刻暂停并显示警告。

### [2026-05-18] 基础测试与预览准备
- [x] 修复 `App.jsx` 中 render 阶段调用 `Date.now()` 导致的 React purity lint 错误。
- [x] 修复两个 Timer 文件中未使用 `err` 变量导致的 lint 错误。
- [x] 重新运行 `npm run lint` 和 `npm run build`，均通过。

### [2026-05-18] Bug 修复：启动全屏与本地运行稳定性
- [x] 修复 Earn 任务开始时没有在用户点击手势内请求全屏的问题；现在窗口未最大化/全屏时会先尝试进入全屏，失败则不启动计时。
- [x] 修复每日消费统计使用 UTC 日期的问题；改为本地日期 key，避免北京时间下跨日统计错位。
- [x] 限制 Tailwind 4 扫描范围到 `src`，并关闭 Vite/Tailwind CSS 压缩优化，避免 dev server 在当前环境中启动卡住。
- [x] 本地 dev server 已启动并打开：`http://127.0.0.1:5173/`，首页 HTTP 返回 200。
- [x] `npm run build` 与 eslint 长时间不退出的问题已在后续工具链稳定性修复中解决。

### [2026-05-18] 工具链稳定性修复
- [x] 将构建工具链收敛到稳定组合：Vite `7.3.3`、`@vitejs/plugin-react` `5.2.0`、TailwindCSS `4.1.18`、ESLint `9.39.4`。
- [x] 将 `lucide-react` 从 `1.x` 降到 `0.511.0`，避免 esbuild/Vite 打包图标库时卡在依赖转换阶段。
- [x] 将 `eslint-plugin-react-hooks` 降到 `5.2.0`，并把旧式推荐规则转换成 flat config 写法；补充 `eslint-plugin-react` 的 JSX 使用检测规则。
- [x] 修复 `node_modules/@vitejs/plugin-react 2` 异常目录名导致的模块解析失败。
- [x] `npm run lint` 已稳定通过。
- [x] `npm run build` 已稳定通过，产物生成到 `dist/`。
- [x] 使用 `npm run preview -- --host 127.0.0.1` 启动生产预览，并在浏览器验证 `http://127.0.0.1:4173/` 页面正常渲染、无新控制台错误。
- [x] 清理旧 Vite/esbuild 进程并强制重建依赖缓存后，`npm run dev -- --host 127.0.0.1 --force` 已可正常加载；浏览器验证 Vite HMR 连接成功。

### [2026-05-19] Bug 修复：提前退出警报音
- [x] 修复点击计时器退出按钮时只弹 PIN、不响警报的问题；现在 Earn/Spend 提前退出都会先播放警报音，再弹出家长 PIN。
- [x] 补充 `fullscreenchange` 监听，退出浏览器全屏时会重新执行防作弊窗口检查。
- [x] 警报音在防作弊暂停时强制播放，不再被短时间节流误吞。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] 行为调整：Spend 提前退出
- [x] 按用户反馈移除 Spend 提前退出时的警报音。
- [x] Spend 点击退出时会先暂停计时并冻结当前剩余时间，再弹出家长 PIN；PIN 错误或取消时保持暂停，可手动继续。
- [x] Earn 提前退出仍保留警报音。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：弹窗期间计时暂停
- [x] 修复 Earn 提前退出弹出 PIN 对话框时，墙钟计时仍继续推进的问题。
- [x] Earn 点击退出时现在会先响警报、冻结当前剩余时间并暂停，再弹出家长 PIN；PIN 错误或取消时保持暂停，可手动继续。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：警报音不可听
- [x] 修复 WebAudio 总输出增益过低导致警报音几乎静音的问题。
- [x] Earn 提前退出时先启动警报音并等待 250ms，再弹出 PIN，避免浏览器对话框阻塞声音启动。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] 行为调整：持续报警 PIN 弹窗
- [x] 将计时器提前退出的原生 `window.prompt` 改为应用内 PIN 弹窗，避免浏览器原生弹窗阻塞报警循环。
- [x] Earn 提前退出时持续循环报警，直到输入正确 PIN 或取消弹窗。
- [x] Spend 提前退出仍不报警，只暂停并显示家长 PIN 弹窗。
- [x] 浏览器实测：Earn 退出弹窗打开后创建 `1200ms` 报警循环，取消弹窗后报警循环清除，计时保持暂停。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：窗口遮挡仍继续计时
- [x] 恢复并加强浏览器窗口失焦检测：监听 `window.blur`、`focusout`，并每秒检查 `document.hasFocus()`。
- [x] 当计时窗口被其他应用窗口遮挡或失去焦点时，Earn 计时会立即暂停并显示防作弊警告。
- [x] 浏览器实测：触发 `blur` 后显示暂停警告，等待 1.5 秒计时数字保持不变。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] 行为调整：自动黑屏不暂停
- [x] 调整隐藏页面逻辑：`document.hidden`（自动黑屏/系统隐藏）不再触发暂停或警报。
- [x] 保留可见窗口失焦检测：浏览器仍可见时，被其他应用遮挡仍会暂停 Earn 计时。
- [x] 浏览器实测：可见窗口触发 `blur` 会暂停；模拟 hidden 状态后触发 `visibilitychange`/`blur`，计时继续推进且无暂停警告。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：切屏暂停报警改为连续播放
- [x] 将 Earn 计时因失焦/遮挡而暂停时的警报，从单次播放改为持续循环播放。
- [x] 报警循环支持模式切换：切屏暂停使用 warning 循环，提前退出继续使用 exit 循环，二者不会相互叠加。
- [x] 恢复计时时立即停止 warning 报警，避免已回到计时界面后继续响铃。
- [x] 本地浏览器实测：触发 `blur` 后 2.6 秒内累计触发 3 轮报警；点击继续后 1.8 秒内未再新增报警。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：自动黑屏误判为切屏
- [x] 为 Earn 失焦检测增加 `180ms` 延迟确认，避免 `blur` 先于 `document.hidden` 到达时误判成作弊暂停。
- [x] 页面进入 `hidden` 时会清理待执行的失焦暂停检查，自动黑屏期间不触发警报，也不暂停计时。
- [x] 本地浏览器实测：模拟 `blur` 后 `50ms` 进入 hidden，计时从 `29:40` 继续到 `29:37`，且无暂停警告。
- [x] 本地浏览器实测：纯 `blur` 失焦场景下，报警循环持续增长；恢复 `hasFocus()` 后点击继续，报警立即停止且计时恢复推进。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] 行为调整：移动端切 App 立即暂停
- [x] 移动端 Earn 计时期间优先申请 `Screen Wake Lock`，尽量阻止系统自动黑屏，把“自动灭屏”和“切去其他 App”分开处理。
- [x] 移动端页面进入 `hidden` 时，按切走其他应用处理：立即暂停 Earn 计时并启动 warning 报警。
- [x] 桌面端维持原行为：`hidden` 仍不触发暂停，自动黑屏或标签页隐藏不会误报。
- [x] 本地浏览器移动端 UA 实测：模拟 `hidden` 后剩余时间停在 `29:48`，警告出现且报警循环启动。
- [x] 本地浏览器桌面端 UA 实测：模拟 `hidden` 后时间从 `29:47` 继续到 `29:45`，无警告、无报警。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：手机端切 App 暂停但无报警
- [x] 将移动端 warning 报警改为“前台预热、后台开闸”模式，避免切到其他 App 后再临时启动音频被系统拦截。
- [x] 移动端 Earn 计时开始时会预先创建静音循环报警源；进入 `hidden` 暂停时只提升 gain，不再重新创建音频源。
- [x] 桌面端保持现状，不引入预热报警逻辑。
- [x] 本地浏览器移动端 UA 实测：开始计时后先记录两次 `0.0001` 静音预热；模拟 `hidden` 后追加 `0.9` 音量开启，且页面进入暂停警告状态。
- [x] 本地浏览器桌面端 UA 实测：模拟 `hidden` 后时间从 `29:46` 继续到 `29:44`，无暂停警告。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] Bug 修复：手机端切回前台才响
- [x] 将移动端 warning 报警从 `Web Audio` 预热切换为 `HTMLAudio` 循环轨道，提升切 App 时后台立即出声的兼容性。
- [x] 移动端 Earn 开始时会先创建低音量 `audio` 轨道；进入 `hidden` 时只把音量提升到 `1` 并再次调用 `play()`，不等待回到前台。
- [x] 桌面端维持原行为，`hidden` 仍不会暂停，也不会触发报警。
- [x] 本地浏览器移动端 UA 实测：模拟 `hidden` 后新增一次 `play()`，音量从 `0.001` 提升到 `1`，同时页面进入暂停警告状态。
- [x] 本地浏览器桌面端 UA 实测：模拟 `hidden` 后时间从 `29:50` 继续到 `29:48`，无暂停警告。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-19] 行为回退：手机端只暂停不报警
- [x] 按用户要求撤回手机端 warning 报警，保留手机端离开计时页面即暂停 Earn 计时的行为。
- [x] 手机端切到其他 App 或进入 `hidden` 时仍会暂停并显示警告，但不再触发任何报警音。
- [x] 桌面端保持现有逻辑不变。
- [x] 本地浏览器移动端 UA 实测：模拟 `hidden` 后停在暂停警告状态，且没有音频播放计数。
- [x] 本地浏览器桌面端 UA 实测：模拟 `hidden` 后时间从 `29:30` 继续到 `29:28`，无暂停警告。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-20] 行为调整：iPad Earn 按电脑端处理
- [x] 将 `iPad` 从手机静音分支中拆出，改为像电脑端一样：离开计时器会暂停 Earn 并触发 warning 报警。
- [x] `iPhone/手机` 仍保持静音暂停规则；`iPad` 与桌面端继续保留 warning 报警。
- [x] `iPad` 黑屏场景不依赖 `hidden` 触发暂停；只有切 App 造成的失焦链路才会触发暂停与报警。
- [x] 本地浏览器 iPad UA 实测：模拟 `blur` 后 `50ms` 进入 `hidden`，剩余时间冻结且出现暂停警告，并触发一次 warning 报警启动。
- [x] 本地浏览器 iPad UA 实测：纯 `hidden` 场景下时间从 `29:39` 继续到 `29:36`，无暂停警告、无报警。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-20] Bug 修复：iPad warning 报警偶发不响
- [x] 定位到根因：iPad 的 warning 报警在离开 App 时已切到高音量，但随后被预热清理分支误关停，导致听感上出现“有时候响、有时候不响”。
- [x] 将 iPad warning 报警改为前台预热循环音源，触发时只提升音量，不再在后台临时新建音频上下文。
- [x] 修正预热清理条件：只有离开 warning 状态、进入 PIN 弹窗、切出 Earn 或进入 overtime 时才停止 warning 音源。
- [x] 本地浏览器 iPad UA 实测：进入 Earn 后只创建 `0.0001` 音量预热音源，没有立即触发可听警报。
- [x] 本地浏览器 iPad UA 实测：模拟 `blur` 后 `50ms` 进入 `hidden`，剩余时间停在 `29:32`，warning 音量从 `0.0001` 提升到 `0.9`，且不再被后续逻辑关停。
- [x] 本地浏览器 iPad UA 实测：纯 `hidden` 场景下时间从 `29:50` 继续到 `29:48`，无暂停警告，warning 音源保持静音预热。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-20] 规则补齐：Overtime Bonus 继承 Earn 防切屏限制
- [x] 将 `overtime bonus` 纳入和普通 `earn` 相同的焦点/全屏限制，不再允许超时阶段离开计时器后继续累计奖励时间。
- [x] 手机端 `earn` 的静音暂停规则、桌面端/iPad 的 warning 报警规则，现已同时覆盖到 `overtime bonus`。
- [x] 恢复 `overtime` 暂停后重新开始时，同样要求保持计时器页面的最大化/全屏约束。
- [x] 本地浏览器 iPad UA 实测：以 `TARGET 0M` 直接进入 `OVERTIME BONUS`，模拟 `blur` 后 `50ms` 进入 `hidden`，计时停在 `+00:14`，显示暂停警告，warning 音量从 `0.0001` 提升到 `0.9`。
- [x] 本地浏览器 iPad UA 实测：`OVERTIME BONUS` 纯 `hidden` 场景下时间从 `+00:12` 继续到 `+00:14`，无暂停警告，维持黑屏例外规则。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-05-20] UI 回归修复：iPad 任务编辑/删除按钮消失
- [x] 定位到根因：任务卡片和设置行的编辑按钮在 `md` 断点下默认透明，只在 `hover` 时显示；`iPad` 命中桌面断点但没有稳定 hover，导致按钮看起来像被取消。
- [x] 调整为：触屏设备（`navigator.maxTouchPoints > 0`）始终显示这些管理按钮，鼠标设备继续保留 hover 显示。
- [x] 同步覆盖 `Earn` / `Spend` 任务卡片，以及 `Daily Screen Limit` / `Eye Rest Cooldown` 两处铅笔按钮。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。
- [x] 本地浏览器 iPad UA 视口复测：首页任务编辑/删除按钮与设置铅笔按钮重新可见。

### [2026-05-20] UI 修正：iPad 常显按钮遮挡 Earn 奖励文本
- [x] 定位到根因：`iPad` 触屏设备下编辑/删除按钮改为常显后，`Earn` 任务卡片右侧原有留白不足，导致奖励文本与按钮区重叠。
- [x] 为触屏设备的 `Earn` 任务卡片增加固定右侧留白，让奖励文本稳定停在按钮区左侧。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。
- [x] 本地浏览器 iPad UA 视口截图复测：任务标题、奖励文本、编辑/删除按钮已分离，不再遮挡。

### [2026-05-20] 行为调整：Spend Time 提前退出取消家长密码
- [x] 将 `Spend Time` 的提前退出从 PIN 弹窗改为直接退出，不再要求输入家长密码。
- [x] 保留原有按已使用时长按比例结算 `Spend` 消耗分钟数的逻辑。
- [x] `Earn Time` 与 `Overtime Bonus` 的退出 PIN 规则保持不变。
- [x] 已重新运行 `npm run lint` 与 `npm run build`，均通过。

### [2026-08-12] Codex 接手：工程基线与规则安全修复
- [x] 移除 Git 远程地址中的明文访问令牌，恢复为普通 GitHub HTTPS 地址。
- [x] 隔离并清理异常的重复依赖/缓存目录，使用 `package-lock.json` 完成干净安装。
- [x] 将 `.vite` 加入忽略规则并移除已提交的构建缓存，避免工具链状态污染仓库。
- [x] 删除未被引用的重复 `src/Timer.jsx`，保留 `src/components/Timer.jsx` 为唯一计时器实现。
- [x] 移除对外部 Mixkit 完成提示音的依赖，保留计时器内建 Web Audio 提示音。
- [x] 集中任务输入与 Spend 按比例扣费规则，禁止负数奖励/成本和非整数分钟。
- [x] 新增 Node 原生业务规则测试；`npm test` 共 5 项通过。
- [x] 更新 README、冷却期说明和 Spend 提前退出引导文案，使文档与实际行为一致。
- [x] `npm run lint` 与 `npm run build` 均通过；本地浏览器首页/引导交互正常且无控制台错误。

### [2026-08-14] v4.0 轻量家庭规则与双端联动原型
- [x] 将单一 `dailyCap` 升级为 School Day、Weekend、Holiday 日期规则引擎。
- [x] 内置 Strict Reset（20/40/60）和 Balanced（30/60/90）两套轻量模板，保留自定义额度。
- [x] 增加独立 Child View 与 PIN 保护的 Parent Dashboard，整体界面改为简洁浅色家庭产品风格。
- [x] 孩子端统一显示 `Today available`，自动受时间币余额、今日剩余额度和单次上限约束。
- [x] 增加睡前 60 分钟禁用、120 分钟健康硬上限，以及按实际连续使用时长触发的休息规则。
- [x] 增加孩子额外 10 分钟申请、家长批准/拒绝、孩子状态和家庭活动流。
- [x] 增加跨标签页 LocalStorage 实时重载，完成孩子申请 → 家长审批 → 孩子额度更新的双端联动演示。
- [x] 增加日期类型、模板上限、今日可用时间、缩短娱乐时长、睡前限制和冷却规则测试；共 10 项通过。
- [x] `npm run lint`、`npm test`、`npm run build` 全部通过；双端浏览器验证无新控制台错误。
- [ ] 下一步：将本地联动抽象接入云端家庭账户、设备绑定和推送服务。

### [2026-08-15] macOS 原生控制原型 0.1
- [x] 创建 `macos/TimeBoxerMac` Swift Package 和可组装 `.app` 的目录结构。
- [x] 使用 AppKit + WKWebView 加载现有 React 界面，Vite 生产资源改为相对路径以支持应用内加载。
- [x] 增加 JavaScript → Swift 事件桥，传递任务开始、规则拦截和额外时间申请。
- [x] 增加 Swift → React 回传：原生应用拦截进入家庭活动流，Shield 的 Ask Parent 会创建额外时间申请。
- [x] 将孩子姓名、睡觉时间、三类日期额度、今日使用量和临时加时同步到原生策略文件。
- [x] 使用 `NSWorkspace` 监听应用启动/激活，并每 5 秒检查当前前台应用，覆盖娱乐时长在游戏运行期间到期的情况。
- [x] 实现全屏 Shield，保留 Earn、Ask Parent 与 Return to Homework 三个安全出口。
- [x] 加入 `SMAppService` Start at Login 开关，但不静默注册。
- [x] 默认使用 `observe` 模式；只有策略明确设为 `enforce` 时才请求已列入黑名单的应用正常退出，且不执行 force terminate。
- [x] 增加 Swift 规则测试源码、示例策略、`.app` 组装和 ad-hoc 签名脚本。
- [x] 所有 Swift 源码通过编译器语法解析；Web 端 lint、10 项测试和生产构建通过。
- [x] 安装并选择 Xcode 16.4，完成原生 Release 链接、`.app` 组装和严格签名校验。
- [x] 将 Swift Testing 测试迁移到 XCTest，并通过 Xcode 的 `xctest` 实际执行 4 项规则测试，全部通过。
- [x] 修复 `main.swift` 双重启动入口、打包扩展属性导致的签名失败，以及 ESLint 误扫描原生构建产物的问题。
- [x] 将 TimeBoxer 安装到 `/Applications/TimeBoxer.app` 并成功启动；默认仍为 `observe` 模式。
- [x] 完成 Apple/Xcode 许可确认和首次组件初始化；标准 `npm run mac:test` 与 `npm run mac:build` 均已通过。
- [ ] 下一步进行 Shield 手动演示、测试应用观察/拦截和孩子端—家长端联动验收。

### [2026-08-16] macOS 原生运行链路稳定化
- [x] 修复 WKWebView 给本地文件 URL 添加查询/片段参数导致的 `NSInvalidArgumentException`。
- [x] 将孩子端/家长端切换改为 Swift → React 原生事件，不再反复重载 WKWebView。
- [x] 增加 React `web-ready` 握手和 Swift 事件队列，页面未就绪时不丢失 Shield 申请或应用观察事件。
- [x] 在 macOS 打包阶段内联 Vite JS/CSS，绕过 WebKit 对 `file://` 模块子资源的限制；Web 部署产物保持分离资源。
- [x] 修复 Shield 应用名插值和无边框窗口无法成为 Key/Main Window 的交互问题。
- [x] 为前台应用观察事件增加同应用、同原因一分钟去重，避免家长活动流每 5 秒重复刷屏。
- [x] 真实运行确认 React → Swift `web-ready` 与 `policy-snapshot` 到达，原生策略文件成功刷新。
- [x] 原生 4 项 XCTest、Web 10 项规则测试、lint、Web 构建与 macOS Release 打包全部通过。

### [2026-08-16] 双端与 Shield 验收
- [x] 浏览器实际点击完成孩子申请 10 分钟 → 错误 PIN 拒绝 → 正确 PIN 解锁 → 家长批准 → 孩子余额同步增加的完整流程。
- [x] 安装版以 Demo Shield 模式实际启动并完成截图核对，确认原生全屏窗口与三个安全出口正常显示。
- [x] 修复 Shield 长英文标题被截断的问题，改为最多两行完整显示；重新通过 4 项 XCTest、Release 构建、安装和签名校验。
- [x] 验收结束后恢复 `/Applications/TimeBoxer.app` 的正常 `observe` 模式运行。
- [x] 品牌方向确认：使用原版绿色线框立方体 + 银灰 `TIME` + 绿色 `BOXER` 的单一页眉 Logo；白色底板、绿色主色、清晰简洁，保留新版内容结构。
- [x] 品牌首轮落地：孩子端、家长端、PIN 页面和首次设置页统一接入单一绿色立方体 + `TIMEBOXER` 字标，采用白色底板、绿色主色和紫色 Play 辅助色；不使用 `public/logo.png` 的罗盘图。
- [x] 孩子端按确认稿重组为计划/可用时间/今日使用三块摘要卡、Earn/Play 双栏和底部加时申请，同时保留全部新版内容与规则逻辑。
- [x] 本地浏览器与 `/Applications/TimeBoxer.app` 安装版均完成截图核对，确认不再显示旧深蓝摘要卡，页面只有一个品牌 Logo。
- [x] 品牌第二轮第一步：完成绿色立方体 macOS Retina 应用图标与 Xcode Asset Catalog 打包。
- [ ] 品牌第二轮后续：制作菜单栏模板图标和 Shield 原生品牌组件。

### [2026-08-21] 家长端手机信息架构优化（macOS Build 17）
- [x] 将孩子状态、待审批请求、今日日期类型与额度、最近活动放在手机端前部常显，确保高频信息优先。
- [x] 将时间计划、App/网站保护、活动奖励、孩子资料和测试工具改为独立折叠类别；一次设置后不常修改的内容默认收起。
- [x] App/网站保护增加第二层分类，网站列表和孩子 Mac 检测到的应用列表可分别展开，避免 41 个已安装 App 拉长整个页面。
- [x] 使用 390×844 手机视口验证信息顺序、展开/收起状态和网站选择入口；页面折叠交互正常。
- [x] `npm run lint`、16 项 Web 规则测试、16 项 macOS 原生测试、Web 构建及原生 Release 打包全部通过。
- [x] Build 17 已严格签名、安装至 `/Applications/TimeBoxer.app` 并成功启动；Build 16 保留为可恢复备份。

### [2026-08-21] 家长提醒中心（macOS Build 18）
- [x] 家长端页眉增加铃铛入口和未读角标，通知中心按严重程度区分违规拦截、待处理申请、任务完成和娱乐使用。
- [x] 新违规事件在家长端首屏显示红色警告卡片；确认或标记全部已读后，同时清除首屏警告和未读角标。
- [x] 额外时间申请可继续在首页处理，并在通知中心内提供快捷批准与拒绝操作。
- [x] 增加浏览器通知授权入口；页面运行时可发送系统通知，明确提示完全关闭后的远程推送仍需 iPhone App 和云端服务。
- [x] Mac 监管掉线时显示红色连接警告，并在从在线切换到离线时触发高优先级提醒。
- [x] 家长测试工具增加 `Send test blocked alert`，无需等待孩子真实违规即可验证提醒链路。
- [x] 新增 5 项提醒分类与未读逻辑测试，Web 测试总数增至 21 项；390×844 手机视口完成触发、置顶、已读清除和视觉验收。
- [x] 16 项 macOS 原生测试、Web/原生 Release 构建与严格签名全部通过；Build 18 已安装启动，Build 17 保留为可恢复备份。

### [2026-08-16] 家长快速测试工具
- [x] 在 PIN 保护的 Parent Dashboard 增加 `Parent-only testing tools`，支持直接设置 0–600 分钟测试时间币。
- [x] 支持 Real time、10 秒、30 秒、60 秒快捷档和 1–300 秒自定义倒计时。
- [x] 快速倒计时只压缩等待时间，完整结束仍按原任务分钟结算奖励、扣费、每日额度与护眼休息。
- [x] 快速测试只压缩计时时间，Earn 仍保持全屏、防缩小和防切屏要求，与真实模式一致。
- [x] 为计时器暂停、退出和领取奖励按钮增加无障碍名称，提升孩子操作可读性和自动化测试稳定性。
- [x] 浏览器实际完成 10 秒 Play：30 时间币 → 0、今日使用 0 → 30、护眼冷却触发。
- [x] 浏览器实际完成 10 秒 Earn：进入 Overtime、领取后增加 30 时间币。
- [x] Web lint、11 项规则测试、生产构建、4 项 macOS XCTest、Release 打包、安装与签名校验全部通过。

### [2026-08-21] v4.1 基础额度与轻奖励模型
- [x] 将旧的“先赚币才能使用”改为“基础额度 + 当日可赚奖励 + 家长临时加时”，降低孩子为了娱乐而过量刷任务的风险。
- [x] 奖励只在当天有效，并按日类型设置上限；家长加时独立记录，不占孩子任务奖励上限。
- [x] 内置 Strict Reset、Balanced、Collaborative 三套轻量模板，默认 Balanced 为基础 20/30/40 分钟、可赚 10/20/20 分钟。
- [x] 默认 Earn 项目更新为 Read、Move & Play、Create，奖励分别为 +5、+10、+5 分钟；旧内置阅读/运动任务自动迁移，同时保留家长创建的自定义任务。
- [x] Play 不再设置兑换成本，直接按实际使用量消耗当天额度；单次上限、睡前保护、冷却和 120 分钟健康上限保留。
- [x] 家长端新增基础额度、可赚上限、家长加时和快速测试的清晰拆分；孩子端显示基础额度与今日奖励进度。
- [x] 浏览器实际完成 10 秒 Read → +5 分钟 → 家长端同步的联动验收；Web 13 项规则测试、lint 和生产构建通过。
- [ ] 下一步：把相同家庭状态接入云端账户、Mac 设备身份和手机端推送，替换当前仅同浏览器的本地联动。

### [2026-08-21] v4.4 手机家长端与个性化保护
- [x] 家长端收束为 430px 手机优先单列界面，并在 390px 手机视口完成首屏视觉检查。
- [x] Mac 孩子端扫描 `/Applications`、系统应用和用户应用目录，每分钟刷新实际安装 App 清单。
- [x] 明确游戏类别和已知流媒体客户端默认建议保护；Zoom、Photo Booth、Image Playground、教育和生产力应用不会因宽泛类别被误选。
- [x] 检测结果进入统一家庭状态，手机家长端可逐个开启或关闭保护，选择同步回 Mac 原生监管规则。
- [x] 网站保护保留内置建议，并增加家长自定义域名入口；支持粘贴完整网址并自动规范为域名。
- [x] Web lint、16 项规则测试、生产构建和 16 项 macOS XCTest 全部通过。
- [ ] 下一步：将本机家庭状态迁移到带账户、设备绑定和 RLS 的云端同步，接入 iPhone 推送通知。

### [2026-08-21] v4.2 浏览器家长端与 Mac 孩子端统一状态
- [x] 修正此前只验收同浏览器标签页、却未覆盖安装版 Mac 客户端的范围错误。
- [x] 定义唯一家庭状态字段契约，统一基础额度、当日奖励、家长加时、使用量、日期、任务、申请、活动和计划数据。
- [x] 增加本机 `/api/family-state` 状态服务，浏览器家长端与 Mac 原生客户端共同读写 `family-state.json`。
- [x] 增加 WebKit 双向桥：完整状态可从 Mac 回传 Web，也可从孩子端发布给家长端；原生监管策略继续由同一状态派生。
- [x] 增加版本号、稳定状态指纹和 Mac 在线心跳；修复 JSON 字段顺序不同造成的同步回写循环。
- [x] 将设备心跳拆分为独立文件，消除心跳与家长/孩子业务状态同时写入时互相覆盖的竞态。
- [x] 清理跨日残留的 `todaySpent`、`lastSpentDate`、冷却时间和当日奖励，避免后端原始值与界面计算值不一致。
- [x] 家长端明确显示 Mac 已连接、正在连接或未连接，不再把普通浏览器标签页同步描述成设备联动。
- [x] 真实验收家长端 5 → 6 → 5：共享状态每次只增加一个版本，Mac 原生策略同步为相同值，最终两端均为 25 分钟可用。
- [x] Web 14 项规则/状态测试、macOS 5 项 XCTest、lint、生产构建、签名、安装和运行验证全部通过。
- [ ] 下一步：将同一状态契约迁移到云端，支持手机家长端、家庭绑定、远程提醒和离线冲突处理。

### [2026-08-21] macOS 0.2.2 阅读全屏与强警报
- [x] Reading 等 Earn 活动开始时由 Mac 原生窗口进入系统全屏，不再依赖 WKWebView 的网页全屏权限。
- [x] 快速测试模式也必须进入全屏，避免测试结果与真实计时行为不同。
- [x] 原生全屏动画增加 1.8 秒检测缓冲，避免进入全屏过程中被误判为缩小窗口。
- [x] 警报改为 660–1047Hz 的高频交替方波，输出峰值由约 0.16 提升至约 0.82，并加入动态压缩。
- [x] 离开焦点、缩小窗口或尝试提前退出 Earn 时持续循环警报，直到恢复全屏并继续，或家长 PIN 处理退出。
- [x] 警告状态升级为全屏红色高对比提示；Web 14 项测试、macOS 5 项 XCTest、lint、Release 构建、签名和安装通过。

### [2026-08-21] v4.3 默认关闭娱乐与 Play 限时通行证
- [x] 将 Earn 状态与原生监管彻底拆开；Earn 全部完成或孩子不打开界面时，Mac 后台监管仍持续运行。
- [x] 原生规则改为默认拒绝：只有孩子端正式开始 Play 后才签发最长 60 分钟、带绝对截止时间的临时通行证。
- [x] Play 正常结束、提前结束或页面关闭会立即撤销通行证；即使网页计时被节流，原生截止时间仍独立生效。
- [x] Steam、Roblox、Minecraft 等已配置 App，以及系统分类为 Games 的 Mac App，在无通行证时每秒检查、隐藏并请求正常退出；重复打开不会被通知去重逻辑漏放。
- [x] 拦截事件继续写入统一家庭活动流，本机家长端可看到发生的 App、原因和时间。
- [x] 默认切换到 Enforce；TimeBoxer 自动注册随登录启动，关闭启动项或退出需要共享家长 PIN。
- [x] 明确当前边界：浏览器内的网页游戏/视频尚不能按网址识别，需要浏览器扩展、Network Extension 或 Apple Family Controls。
- [x] Web 14 项测试、macOS 8 项原生规则/状态测试、lint 和 Release 构建通过。

### [2026-08-22] v4.5 独立客户端与云端基础
- [x] 增加 `child`、`parent`、`combined` 三种构建模式；Mac 发布包固定使用 Child 构建，手动 URL 参数也不能进入家长端。
- [x] 删除 Mac 原生状态栏的 `Open Parent Preview` 和原生 `.parent` 视图模式，家长控制不再随孩子安装包发布。
- [x] 创建独立 `TimeBoxer Parent` SwiftUI iPhone 工程，完成移动首屏、Mac 在线状态、违规卡片、加时审批、今日额度、折叠设置和六位配对码界面。
- [x] iPhone 工程以 `nz.co.timeboxer.parent` 为 Bundle ID，通过 iOS 17 模拟器 SDK 无签名编译。
- [x] 使用固定版本 Supabase CLI 初始化独立本地云端工程；没有连接或修改账户中已有的非 TimeBoxer 项目。
- [x] 建立 family、member、child、device、policy、event、request、entitlement 数据结构；所有公开表启用 RLS 并显式授权。
- [x] 配对码摘要、设备凭证和 APNs token 放入不可从 Data API 访问的 `private` schema，孩子 Mac 不使用家长 JWT 或 service-role key。
- [x] 增加家庭策略与设备事件 JSON Schema，明确不收集截图、键盘输入和网页正文。
- [x] 按 Supabase PostgreSQL 最佳实践补齐所有高频查询、RLS 和外键列索引，并收紧 service-role 表权限。
- [x] 在唯一组织内创建 Sydney 区域的独立 `timeboxer` 云项目；项目与 `s-nz-ledger` 使用不同数据库、API、Auth 用户和扩容额度。
- [x] 在线部署四批数据库迁移；真实 authenticated 事务通过 RLS 创建 profile、family、owner membership 和 child 后完整清理验证数据。
- [x] 修复 family 与 family_members 的 RLS 循环引用；内部成员判断函数位于不可暴露的 private schema，并仅授予策略执行所需的最小权限。
- [x] Supabase Security Advisor 无 warning/error；12 张 TimeBoxer 表全部启用 RLS，私密凭证表保持默认拒绝。
- [x] iPhone 家长端加入固定版本 Supabase Swift SDK、TimeBoxer 独立项目配置和真实邮箱注册/登录界面；官方依赖已解析并锁定。
- [x] 安装 iOS 18.6 Simulator runtime，创建 `TimeBoxer Test iPhone`（iPhone 16 Pro）并完成家长端首次模拟器安装。
- [x] 修复登录/注册闭包的 Swift 编译错误，以及自动生成 `Info.plist` 丢失 Supabase 配置导致的启动退出；Debug 包现可稳定进入真实登录页。
- [x] iPhone 主屏幕图标复用已确认的黑底绿色方盒品牌资产，移除 Xcode 系统占位图，并在模拟器主屏幕完成视觉核对。
- [x] 使用不创建账号的无效登录请求验证 TimeBoxer Auth 地址和 publishable key；云项目状态为健康，四批迁移存在，9 张公开表全部启用 RLS，且未访问 `s-nz-ledger`。
- [x] 使用真实测试邮箱完成注册确认与登录验收；Dashboard 和六位码配对已从 Preview 服务切换为真实 TimeBoxer 云服务。
- [x] 实现家庭首次初始化和 Mac 六位码配对；设备密钥仅保存在 macOS 钥匙串，云端只保存摘要。
- [ ] 下一步：实现 Mac 定时心跳、策略/事件双向同步和 APNs Edge Functions。

### [2026-08-23] iPhone 家长端与 Mac 孩子端真实云绑定
- [x] 在 TimeBoxer 独立 Supabase 项目部署 `timeboxer-pairing` Edge Function，支持家长首次家庭初始化、单次六位码创建和 Mac 消费绑定码。
- [x] 使用 `19813880@qq.com` 完成邮箱确认、真实 Auth 登录，并创建独立 family、owner membership、child、policy 和 entitlement。
- [x] Mac 安装版加入 `Pair with Parent…`，以安装身份、公钥和一次性码换取设备凭据；设备 ID、孩子 ID与策略版本写入本机身份文件，设备密钥写入 macOS 钥匙串。
- [x] 修复 PostgreSQL `bigint` 作为字符串返回导致 Mac 原生解码失败，并重新部署函数；真实设备 `Serena’s MacBook Air` 绑定成功。
- [x] iPhone 家长端改用真实 Supabase 服务，显式携带家长 JWT 通过 RLS 读取设备、请求和违规事件；不再显示 Alex 预览数据。
- [x] iPhone 18.6 模拟器验证真实孩子档案、Mac 名称与 20 分钟 School day 模板；30 项 Web/安全测试、ESLint、iOS Debug 构建、macOS Release 构建和签名均通过。
- [x] Mac 安装版每 30 秒使用设备 ID、安装 ID 和钥匙串密钥向云端安全上报心跳；家长端以 90 秒阈值显示 Online/Offline，已用真实绑定设备连续验证。
- [x] 修复 SwiftUI 刷新任务被系统取消时误报“云服务无法连接”；应用回到前台会自动刷新，页面仍支持下拉刷新，真实错误卡增加 `Try again`。
- [x] 将此前仅有外观的 Common controls、Family profile、Subscription 和提醒铃铛接入可打开的原生详情页；未完成云端写入的控制明确标注为下一阶段，不再假装已经生效。

### [2026-08-23] 原生品牌修正与 Play 放行体验
- [x] iPhone 家长端移除小号黑底系统立方体字标，改为与原版一致的绿色线框方盒、银灰斜体 `TIME` 和绿色斜体 `BOXER`。
- [x] 在 iPhone 16 Pro 模拟器重新编译、覆盖安装并截图核对，确认登录页使用放大后的单一品牌 Logo。
- [x] Play 倒计时移除孩子可暂停的入口，避免界面暂停时间与 Mac 原生绝对通行证到期时间不一致。
- [x] Play 页面明确显示 `Play access active`：家长批准的娱乐 App 与所选网站可在倒计时内打开，倒计时结束、提前退出或页面关闭后恢复拦截。
- [x] 30 项 Web 业务/安全规则测试通过，iOS 原生 Debug 构建通过。
- [x] SwiftPM 卡顿定位为嵌套沙箱、模块缓存和索引冲突；构建脚本固定临时模块缓存并关闭无用索引，macOS Release 打包与严格签名校验重新通过。

### [2026-08-23] 真实设备在线状态闭环
- [x] `timeboxer-pairing` Edge Function 增加设备心跳动作，以摘要比对验证设备密钥，不放宽 RLS，也不在公开表保存原始密钥。
- [x] 孩子 Mac 启动后立即心跳、之后每 30 秒续报，同时回收当前云端策略版本，为下一步策略下发提供版本依据。
- [x] 将新版孩子端重新打包、严格验签并安装至 `/Applications/TimeBoxer.app`；旧版保留在 `/private/tmp/TimeBoxer-before-heartbeat-20260823-2121.app`。
- [x] 因开发期 ad-hoc 签名变化导致旧钥匙串 ACL 不再匹配，为当前测试 Mac 安全重新签发设备凭据；未降级为明文凭据存储。
- [x] 真实日志连续确认启动心跳和 30 秒续报均成功，iPhone 18.6 模拟器家长端随后显示 `Serena’s MacBook Air · Online`。
- [x] 家长端日期、可用时间和网站保护已写入云端并由 Mac 拉取、执行和回执；实际 App 清单上传与远程选择单列为下一项。

### [2026-08-23] 家长策略写入与 Mac 执行闭环
- [x] 家长端 Common controls 接入真实云端策略：可选择今天为 School day / Weekend / Holiday、设置 0–120 分钟当天家长加时、添加或删除自定义保护域名。
- [x] 家长策略采用乐观版本控制；只有家庭成员可更新，旧版本保存会返回冲突而不会静默覆盖另一台家长设备的新规则。
- [x] Edge Function 对计划额度、会话/冷却时间、Earn 任务、App 标识、域名和当天覆盖字段执行范围与格式校验；家庭策略 JSON Schema 同步加入当天计划和家长加时字段。
- [x] Mac 心跳携带已执行策略版本；云端仅在有更新时返回完整策略，Mac 成功保存到原生规则和孩子界面家庭状态后，下一次心跳才回执已执行版本。
- [x] 真实云端执行临时 +5 分钟测试：策略 revision 1 → 2，iPhone 重启后读回周末 35 分钟；随后恢复为 0，revision 3，iPhone 显示 Weekend plan / 30 min，Mac 下载并执行 revision 3。
- [x] 修复家长端日期文案硬编码为 School day 的数据错位；当前周末会同时显示 Weekend plan、30 min left 和 0 of 30 used。
- [x] ad-hoc 开发包使用固定 `nz.co.timeboxer.mac` designated requirement；更换了实际二进制后仍可读取原钥匙串凭据并直接心跳，无需再次配对。正式内测仍需 Apple Development/Developer ID 签名。
- [x] 30 项 Web/契约/安全测试、iOS Debug 构建、macOS Release 构建、严格签名、真实双端安装和运行验收通过。
- [ ] 下一步：Mac 将 41 个已安装 App 清单上传云端，家长端按实际设备清单选择保护项；之后接通违规事件和加时申请的云端往返。

### [2026-08-23] 真实 App 清单与家长选择闭环
- [x] Mac 将实际安装 App 的精简清单上传到 TimeBoxer 独立云端；只包含 Bundle ID、显示名、类别和建议保护标记，不收集路径、使用记录、截图、键盘输入或网页正文。
- [x] `child_devices` 增加最多 500 项的 JSON 清单和服务端接收时间；继续复用家庭成员 RLS，孩子端只能通过设备密钥认证的 Edge Function 写入。
- [x] 家长端 `Apps and websites` 改为手机友好的双折叠区：应用默认展开、网站默认收起；应用开关直接来自孩子 Mac 的真实扫描结果。
- [x] 家长选择会更新 `protectedApplications` 策略版本，Mac 下一次心跳下载后以云端列表为准执行；不再与本机硬编码列表做无法关闭的并集。
- [x] 现有家庭策略补入 8 个应用和 15 个网站的安全默认值，新家庭也使用相同默认策略。
- [x] 真实安装版完成端到端验收：Mac 上传 41 项，云端记录扫描时间，设备维持 revision 4 回执；更新安装包后无需再次绑定即可继续心跳。
- [x] 修复 ad-hoc 内测包更新时传统钥匙串 ACL 卡住启动的问题；正式签名优先使用 Data Protection Keychain，未配置 Apple 签名证书的本机内测包使用当前账户专属的 `700/600` 权限凭据后备。
- [x] 拆分“孩子页面需要刷新清单”和“清单确实变化才上传”，并增加稳定排序，避免相同 41 项每分钟重复写云端。
- [x] 新增应用清单隐私/上限/设备认证契约测试和稳定排序 XCTest；33 项 Web/契约测试、17 项 macOS XCTest、iOS Debug 构建、macOS Release 构建和真实安装运行均通过。
- [x] Mac 的 App/网站拦截事件和孩子额外时间申请已接入云端，家长端处理结果可随心跳回传 Mac。
- [ ] 下一步：完成双端新版安装和真实违规/申请/审批往返验收；随后接入 APNs 远程通知，准备首批多家庭内测。

### [2026-08-23] 违规提醒与加时审批云端闭环（本地实现完成）
- [x] Mac 在真正拦截受保护 App 或网站时生成带幂等 UUID 的精简违规事件；只上报应用/域名、拦截原因和时间，不上传截图、键盘输入、网页正文、剪贴板或完整浏览历史。
- [x] 孩子从 Shield 或孩子首页申请额外时间时复用同一个 UUID，Mac 使用设备身份上传；服务端限制每台设备仅有一个待处理申请并安全处理重复提交。
- [x] 家长端批准或拒绝改走认证 Edge Function；批准操作、申请状态、家长加时和策略 revision 在同一数据库事务中完成，重复点击不会重复加时。
- [x] Mac 心跳接收申请处理结果和新策略；批准后孩子端申请状态与可用时间自动更新，拒绝后清除等待状态。
- [x] 数据库迁移会先收束历史重复待处理申请，再建立唯一索引；撤销家长端对申请表的直接更新权限，避免绕过原子审批逻辑。
- [x] 修复 File Provider 管理目录导致 Swift 输入在编译中被误判变化的问题；Mac 打包和测试统一改为从本地临时快照执行。
- [x] 修复图标库总入口一次打开上千文件造成的构建卡死风险，改为按图标文件精准导入；35 项 Web/契约测试、17 项 macOS XCTest、Mac Release 编译与 Web esbuild 冒烟检查通过。
- [x] 数据库迁移和 `timeboxer-pairing` Edge Function version 9 已部署到独立 TimeBoxer Supabase 项目；迁移结构、唯一约束、写权限收口、JWT 校验及新版 Mac 心跳 `POST 200` 均已在线核验。
- [ ] 执行 iOS Debug 编译、安装双端新版测试包，并完成真实违规/申请/审批往返验收。
- [ ] 下一步：接入 APNs 远程推送，使家长端未打开时也能收到孩子违规和加时申请通知。

### [2026-08-29] macOS 0.6.1 Earn 原生防切屏修复（Build 19）
- [x] 定位到 WKWebView 进入后台后 `document.hidden` 分支取消失焦检查，导致 Earn 倒计时可在切屏后继续的真实漏洞；该问题与设备是否已绑定无关。
- [x] 将 Earn 全屏保护提升到 macOS 原生层：监听应用失活并每 250ms 校验前台、Key Window 和系统全屏状态。
- [x] 孩子切换应用或退出全屏后，原生层立即记录违规、暂停 Earn、持续拉回 TimeBoxer；恢复全屏并点击继续后才清除违规状态。
- [x] 将切屏警报从后台不可靠的 WKWebView Web Audio 改为 AVAudioPlayer 原生循环音轨；警报保持到孩子回到 TimeBoxer 并主动继续。
- [x] 未绑定状态同样启用本地 Earn 防切屏；绑定只影响家长自选保护名单、云端同步和家长提醒。
- [x] 新增 5 项 Focus Protection/原生警报 XCTest；22 项 macOS 测试、35 项 Web/契约测试、Timer ESLint、Release 编译、严格签名和 ZIP 完整性检查通过。
- [x] 生成 Apple Silicon 测试包 `releases/TimeBoxer-Mac-Test-0.6.1-arm64.zip`；真实跨应用声音强度与系统音量边界等待孩子 Mac 手动验收。

### [2026-08-30] macOS 0.6.2 未绑定单机保护自检（Build 20）
- [x] 未绑定 Mac 启动时扫描实际安装 App，把已知娱乐客户端和 macOS Games 分类 App 自动加入本地强制保护；之后每分钟复扫，新启动的系统分类游戏也会即时保护。
- [x] 单机默认网站名单继续生效；浏览器自动化权限缺失时不再只隐藏 Chrome/Safari，而是关闭无法监管的浏览器，避免 YouTube 后台有声音却没有可关闭窗口。
- [x] 修复 Earn 的系统状态边界：退出原生全屏会自动恢复，Mac/屏幕休眠会暂停 Earn 且不误响，唤醒后恢复保护。
- [x] 启动和正常退出时撤销残留 Play 通行证，防止应用重启后继承旧的娱乐许可。
- [x] 禁用公开默认 PIN `1234`；首次创建 PIN 必须先通过 macOS 管理员授权，避免孩子抢先设置已知 PIN；移除孩子可接触的 Demo 和本地策略重载菜单项。
- [x] 新增浏览器安全回退、休眠警报、Play 权限持久化撤销、单机 App 推荐保护和 PIN 策略回归测试；37 项 Web/契约测试、31 项 macOS XCTest 和全量 ESLint 通过。
- [x] 生成并验收唯一的新 Apple Silicon 测试包 `releases/TimeBoxer-Mac-Test-0.6.2-arm64.zip`；严格验签、版本检查和 ZIP 完整性检查通过，SHA-256 为 `67e140fd1e8bfb34373fea9be217a8d19aaef8da7b4a4e92fedcce532088d1ca`。
- [ ] 孩子 Mac 手测 Command-Tab、系统音量、休眠、Chrome/Safari 自动化授权和单机游戏拦截；随后再测试真实 iPhone 绑定。
- [ ] 正式抗强制退出、跨 macOS 用户和本地策略篡改仍需要特权辅助服务或 MDM；内测阶段要求孩子使用标准非管理员账户，完整边界见 `docs/STANDALONE_SECURITY_AUDIT.md`。

### [2026-08-31] macOS 0.6.3 提醒优先模式（Build 21）
- [x] 按产品决策将默认行为从“强制关闭”调整为“提醒优先”：非 Play 时间仍识别已选娱乐 App 和网站，但不隐藏、不终止 App，也不替换或关闭浏览器标签页。
- [x] 检测到非批准娱乐时显示可确认的品牌全屏提醒，并使用原生循环警报音持续播放到孩子点击 `I understand`、开始 Earn 或向家长申请时间。
- [x] 每次提醒继续写入现有云端设备事件链路；绑定且联网后，家长端显示“opened outside Play time”，不再误写为“was blocked”。
- [x] 旧安装包遗留的 enforce 本地状态会在新版本启动时自动迁移为 Alerts Only；状态栏明确显示 `Mode: Alerts Only`。
- [x] Play 原生时间窗继续作为免警报许可；Play 内不提醒，倒计时结束、页面关闭或 App 重启后恢复提醒。
- [x] 孩子端、Web 家长端和 iOS 家长端说明同步改为提醒逻辑；37 项 Web/契约测试、32 项 macOS XCTest、全量 ESLint、Child Release 构建和 iOS Simulator Debug 构建通过。
- [x] 构建并验收 Apple Silicon 测试包 `releases/TimeBoxer-Mac-Test-0.6.3-arm64.zip`；版本 0.6.3（Build 21）、严格签名和 ZIP 完整性检查通过，SHA-256 为 `b97d16dbd47e925c9ea6751a0cb484f1b10640bbcc9f39b97abcc3b2a0c49f50`。
- [ ] 在孩子 Mac 进行真实警报音、游戏不被关闭和家长端事件手测。
- [ ] 家长 App 关闭时的 iOS 系统推送仍需下一阶段接入 APNs；当前提醒在家长端打开、回到前台或刷新后可见。

### [2026-08-31] macOS 0.6.4 强制霸屏提醒模式（Build 22）
- [x] 按最终产品决策将非 Play 行为调整为 Focus Shield：检测到受保护游戏或网站时立即全屏霸屏并持续循环警报，但保留游戏/浏览器进程，不执行退出或强制终止。
- [x] 移除可直接忽略的 `I understand`；霸屏只允许 Earn、申请家长加时或返回 TimeBoxer，再次切回娱乐内容会立即恢复霸屏。
- [x] 本地霸屏不受家长提醒冷却限制，确保每次重新切回都立即生效；云端事件单独去重，避免每秒向家长端重复上传。
- [x] 提醒事件继续使用现有认证云端链路，家长端文案改为 `activated the focus shield`，并说明 Mac 已霸屏、响铃但没有关闭应用。
- [x] 37 项 Web/契约测试、33 项 macOS XCTest、全量 ESLint、Child Release 构建和 iOS Simulator Debug 编译通过；新增回归测试确认重复切回始终霸屏但家长事件保持去重。
- [x] macOS Release 构建、严格签名和 ZIP 完整性检查通过；生成 Apple Silicon 测试包 `releases/TimeBoxer-Mac-Test-0.6.4-arm64.zip`，版本 0.6.4（Build 22），SHA-256 为 `a701d807c91e4171fc31a4e8bf3741c7f5a70101493d4bc31580dae5eed957c8`。
- [ ] 家长 App 完全关闭时的 iOS 系统推送仍需接入 APNs；当前绑定提醒在家长端打开、回到前台或刷新后可见。

---

## 🚀 第三阶段：未来规划 (Next Steps)
- [x] 接入专用 Supabase 云端项目实现跨设备多端同步。
- [ ] 开发可视化的孩子“周常努力数据折线图”。
- [ ] 丰富 Spend Time 消费区的虚拟商城体系（兑换零食、特权等）。
