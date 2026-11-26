# TaskPilot — 跑在 iPhone 上的自动化 Agent

自己写、自己签、自己装的 iOS 自动化 Agent。整个 App 只有 10 个 Swift 文件，没有第三方依赖，用 XcodeGen 生成工程，10 分钟能从源码跑到真机上。

## 它能干什么

一个任务 = 一串**顺序执行的步骤**，任何一步失败整条链停下并记录原因：

| 步骤类型 | 作用 |
| --- | --- |
| `HTTP 请求` | 任意 GET/POST/PUT/DELETE，自定义 Header 和 JSON Body |
| `调用模型` | 走 OpenAI 兼容接口（OpenAI / DeepSeek / Moonshot / 通义 / 自建 one-api 都行） |
| `发通知` | 本地通知推送结果，锁屏就能看到 |
| `等待` | 延迟若干秒，用于轮询类任务 |

后面步骤可以用 `{{prev}}` 拿上一步的输出，用 `{{task}}` 拿任务名。所以典型的链是这样的：

```
取天气 API → {{prev}} 丢给模型"告诉我今天穿什么" → 把回答推成通知
```

**语音输入**：提示词、Body、通知内容、任务名、步骤名这些长文本框，右侧都有一个麦克风按钮。点一下开始说，识别结果实时写进输入框，说完再点一次停止。用的是系统 Speech 框架，识别过程需要联网（走苹果的识别服务）。

触发方式三选一：手动点、每天定时（后台兜底）、**快捷指令**（强烈推荐，见下文）。

## 一、真机跑起来（最省事，不用 IPA）

1. Mac 上装工具：`brew install xcodegen`
2. 进目录生成工程：
   ```bash
   cd TaskPilot
   xcodegen generate
   open TaskPilot.xcodeproj
   ```
3. Xcode 里选中 TaskPilot target → **Signing & Capabilities** → Team 选你的开发者账号，Bundle Identifier 改成你自己的（比如 `com.你的名字.taskpilot`）
4. iPhone 用数据线连上，选中设备，`Cmd+R`

第一次装完，手机上要去 **设置 → 通用 → VPN与设备管理** 里信任你的开发者证书。

进 App 后在「设置」里填 Base URL / 模型名 / API Key，点「保存并测试连接」，看到 ✅ 就能用了。

## 二、打 IPA

只有要**分发给别人**或者放进 TestFlight 才需要。自己装真机完全不必。

```bash
chmod +x build_ipa.sh
./build_ipa.sh ABCDE12345 com.yourname.taskpilot
```

产物在 `build/ipa/TaskPilot.ipa`，`ABCDE12345` 换成你的 Team ID（developer.apple.com → Membership details）。

- 装到设备：用 Apple Configurator、Xcode 的 Devices 窗口、或者 iMazing 拖进去
- 走 TestFlight：把脚本里 `method` 改成 `app-store-connect`，然后 `xcrun altool` / Transporter 上传

`development` 方式签出来的包**只能装在你自己账号里登记过的设备**上，装别人手机要对方 UDID 先加进设备列表，或者走 Ad Hoc / TestFlight。

## 三、让它在后台自己跑（重点）

iOS 的后台执行权限很抠，这里有两个档次：

**档次一：BGAppRefreshTask（App 自带定时）**
不用配置，在任务里选「每天定时」就行。但系统只是「建议」15 分钟后唤醒，不保证时间，低电量模式可能整天不跑。适合「每天大概早上给我推一次」这种宽松需求。

**档次二：快捷指令自动化（准点、可条件触发）**
这才是 iOS 上真正的自动化入口，App 已经把动作暴露好了：

1. 打开「快捷指令」→ 底部「自动化」→ 新建
2. 触发条件随便选：**特定时间**、到达某地点、连上某 Wi-Fi、开始充电、收到某人的消息、NFC 标签
3. 动作里搜 **TaskPilot** → 「运行 TaskPilot 任务」→ 填任务名（要和 App 里完全一致）
4. 关掉「运行前询问」

这样就实现了每天 7:00 准点跑、到家自动跑、插上充电就跑的任意组合。执行结果会作为文本返回给快捷指令，你可以接着在里面推微信、写备忘录、发邮件。

Siri 也能直接喊：*"用 TaskPilot 跑任务"*。

## 四、文件结构

```
TaskPilot/
├── project.yml            # XcodeGen 工程描述（改 bundle id、团队在这里）
├── build_ipa.sh           # archive + 导出 IPA
├── README.md
└── TaskPilot/
    ├── TaskPilotApp.swift        # 入口，注册后台任务
    ├── Models.swift              # 任务 / 步骤 / 日志的数据结构
    ├── AgentStore.swift          # 状态管理 + JSON 持久化
    ├── Executor.swift            # 步骤链执行引擎
    ├── LLMClient.swift           # OpenAI 兼容接口封装
    ├── NotificationManager.swift # 本地通知
    ├── BackgroundScheduler.swift # BGTaskScheduler 定时兜底
    ├── RunTaskIntent.swift       # App Intents，暴露给快捷指令 / Siri
    ├── TaskListView.swift        # 主界面
    ├── TaskEditorView.swift      # 任务编辑
    ├── StepEditorView.swift      # 单步编辑
    ├── SettingsView.swift        # 模型接口配置
    └── LogView.swift             # 执行记录
```

## 五、几个坑，先说在前面

- **API Key 存在 UserDefaults 里**，不加密。个人自用够了；要是想更稳，把 `LLMClient.swift` 里的读写换成 Keychain（`SecItemAdd` / `SecItemCopyMatching`），签名和加密都不用动别的代码。
- **ATS 限制**：走 https 没问题。要连局域网里的自建服务（`http://192.168.x.x`），得在 `project.yml` 的 info properties 里加 `NSAppTransportSecurity → NSAllowsLocalNetworking: true`。
- **不是越狱机，也别想越狱机**。做不了读别的 App 数据、自动点屏幕、模拟点击这些事。想做这类，只能上 Android 或者去做无障碍/屏幕录制方案。
- **上架 App Store 会被卡**：这类工具型 App 上架审核通常要看「是否提供实质性功能」，纯 DIY 的话建议只自己用，或者走 TestFlight。
- **改了 bundle id 记得同步**：`BGTaskSchedulerPermittedIdentifiers` 里用的是 `$(PRODUCT_BUNDLE_IDENTIFIER).refresh`，工程会自动展开，不用手改，但你用脚本传 bundle id 时要和 Xcode 里签的一致。

## 六、想更省事的话

如果不想维护这份代码，还有两条更轻的路：

- **快捷指令 + 自建后端**：快捷指令里「获取 URL 内容」直接打你服务器上的 `/run`，服务端用 Python 写 Agent，手机端零代码。适合任务逻辑经常变的场景。
- **现成客户端 + 自建后端**：Chatbox、Pal Chat 这类支持自定义 OpenAI 兼容地址的 App，配一个自建的 Agent 服务端，几分钟就能用。

自己写 App 的唯一好处是：数据全在本地、不用连第三方、想加什么能力就加什么。
