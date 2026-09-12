<p align="center"><img src="media/logo.png" width="88" alt="AIZU"></p>
<h1 align="center">AIZU</h1>
<p align="center">将你在 iPhone 和 iPad 上选择的活动分享到 Discord。</p>
<p align="center"><strong>0.1.0 Beta</strong> · SwiftUI · iOS / iPadOS 17+ · MIT</p>
<p align="center"><a href="../README.md">한국어</a> · <a href="README.en.md">English</a> · <a href="README.ja.md">日本語</a> · <strong>简体中文</strong></p>

AIZU 是一款通过 Discord Rich Presence 分享应用和任务的 iPhone、iPad 应用。除了游戏，你还可以添加图片编辑、视频观看，或自行命名的任务。分享什么，以及何时开始、结束，都由你决定。

当前版本为**从源码构建并安装到个人设备上的测试版**。分享期间，应用使用无声音频维持后台连接，因此不作为 App Store 版本提供。强制退出 AIZU 后，连接无法继续保持。

![iPad 上的 AIZU 活动页面](media/activity.png)

## 主要功能

- **添加应用和任务**：通过 App Store 搜索应用，或手动创建活动。
- **自定义活动信息**：设置名称、描述、活动类型、已用时间和图片。设备图片保存在本地；若要在 Discord 中显示图片，需要另外填写公开的 HTTPS 图片 URL。
- **分享后打开应用**：活动发送成功后，打开应用 URL 或运行指定名称的快捷指令。
- **快捷指令自动化**：可将打开、关闭目标应用的事件与开始、停止分享关联起来。
- **统一的活动卡片**：查看预览和发送状态，重试发送或停止分享。
- **四种界面语言**：支持韩语、英语、日语和简体中文。默认遵循设备首选语言，也可在设置中切换。

## 使用方法

1. 在设置中连接 Discord 账号。
2. 点击 **+**，添加应用或任务。
3. 开启**活动分享**，再点击目标活动的**分享**。
4. 完成后，点击卡片上的**停止分享**。关闭活动分享开关也会结束当前活动。

![开始和停止分享](media/sharing.gif)

*以上媒体来自 iPad 模拟器中的实际界面，界面语言为韩语。GIF 依次展示待机、分享和结束状态。拍摄使用预览模式，不读取账号，也不向 Discord 发送数据；它并非其他 Discord 客户端的显示录像。*

如需在分享后打开应用，请在活动设置中指定应用 URL 或快捷指令名称。AIZU 不会自动检测已安装的应用或它们的启动 URL。打开、关闭应用时的自动化配置详见[开发指南](DEVELOPMENT.md)。

| 手动添加活动 | 语言与连接设置 |
| --- | --- |
| ![手动添加活动](media/custom-activity.png) | ![语言与连接设置](media/settings.png) |

## 构建

需要 macOS、包含 iOS 模拟器运行时的 Xcode 27 测试版，以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。安装到实体设备还需要配置 Apple 开发签名。最低部署目标为 iOS/iPadOS 17.0，但尚未验证 iOS 17 实体设备上的运行情况。

```sh
git clone https://github.com/aizuproject/AIZU.git
cd AIZU
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open iPadPresence.xcodeproj
```

选择 `iPadPresence` scheme 和一个模拟器。Xcode 项目文件由脚本生成，不提交到仓库。只查看界面时，可在 Debug scheme 的启动参数中添加 `--uitesting --ui-language zh-Hans`。该模式使用内存中的示例数据，不读取已保存的账号，也不向 Discord 发送活动。

实际连接 Discord 需要你自己的 Discord Application ID 和官方 Social SDK。请先完成[连接配置](DEVELOPMENT.md)，再重新生成项目。仓库不包含 SDK 二进制文件或登录凭据。

## 后台行为与限制

无声音频随分享自动开始，并在分享结束时停止。其他音乐应用、通话、音频输出切换及网络状态都可能导致中断。后台运行会消耗额外电量，目前尚未进行电池使用量的定量测量。

| 场景 | 当前行为 |
| --- | --- |
| 返回主屏幕、切换应用或锁屏 | 在系统允许音频运行期间尝试维持连接。 |
| 引导式访问 | 已在部分实体设备上确认可运行，但不保证所有设备和应用都能持续保持连接。 |
| 强制退出 AIZU | 无法继续维持连接。 |
| 未收到关闭应用的自动化事件 | 活动可能继续显示，需要在 AIZU 中手动停止。 |

“已发送到 Discord”表示 SDK 返回成功，不代表已确认其他用户客户端上的显示情况。活动通过 AIZU 的 Discord 应用发送，并不等同于所选应用的官方集成。AIZU 不是 Discord 或 Apple 的官方产品。

当前通过无声音频获取后台运行时间的设计不适合作为 App Store 分发方案。相关要求见 [Apple 审核指南 2.5.4](https://developer.apple.com/app-store/review/guidelines/#software-requirements)。

## 隐私与安全

AIZU 将所选活动的名称、描述、图片 URL 和开始时间发送到 Discord。App Store 搜索词会发送给 Apple；显示远程图片时会连接图片所在的服务器。登录凭据保存在设备的 Keychain 中。AIZU 没有自建的数据收集服务器或分析服务。

应用不会读取其他应用的屏幕、文档或视频标题，也不使用 VPN、位置或麦克风权限。活动由你手动选择，或通过自行设置的快捷指令启动。安全漏洞请通过[私密渠道](https://github.com/aizuproject/AIZU/security/advisories/new)报告，不要提交公开 issue。详情见[安全政策](../SECURITY.md)。

## 参与开发

报告问题时，请在 [issue](https://github.com/aizuproject/AIZU/issues/new/choose) 中提供复现步骤，以及设备、系统和 AIZU 版本。代码修改应从工作分支通过 PR 提交。请参阅[贡献指南](../CONTRIBUTING.md)、[测试范围](TESTING.md)和[更新日志](../CHANGELOG.md)。

CI 配置为在不使用 Discord SDK 或凭据的情况下执行仓库检查和模拟器测试。CodeQL 检查 Python 工具和 GitHub Actions；这些检查不能替代 Swift 代码的安全审查或实体设备测试。

## 许可证

AIZU 源码采用 [MIT 许可证](../LICENSE)。Discord Social SDK 需要单独下载，并遵守 Discord 的条款和许可证。详见[第三方组件说明](../THIRD_PARTY_NOTICES.md)。
