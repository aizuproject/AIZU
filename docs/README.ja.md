<p align="center"><img src="media/logo.png" width="88" alt="AIZU"></p>
<h1 align="center">AIZU</h1>
<p align="center">iPhoneやiPadで選んだアクティビティを、Discordに。</p>
<p align="center"><strong>0.1.0 Beta</strong> · SwiftUI · iOS / iPadOS 17+ · MIT</p>
<p align="center"><a href="../README.md">한국어</a> · <a href="README.en.md">English</a> · <strong>日本語</strong> · <a href="README.zh-CN.md">简体中文</a></p>

AIZUは、ゲーム、アプリ、任意の作業をDiscord Rich Presenceで共有する個人インストール用のベータ版です。

![iPadのAIZUアクティビティ画面](media/activity.png)

## 主な機能

- **アプリと作業の登録**：App Storeで検索するか、手動でアクティビティを追加できます。
- **表示内容の設定**：名前、説明、種類、経過時間、画像を指定できます。端末から選んだ画像はローカルに保存されます。Discordにも表示するには、別途公開HTTPS画像URLが必要です。
- **共有後にアプリを起動**：アクティビティの送信成功後に、アプリURLや指定したショートカットを開きます。
- **ショートカット連携**：対象アプリを開いたとき・閉じたときに、共有を開始・終了するオートメーションを設定できます。
- **共有状況の確認**：カード上でプレビューと送信状態を確認し、再試行や共有終了を操作できます。
- **4言語に対応**：韓国語、英語、日本語、簡体字中国語をサポートします。端末の優先言語に従って選択され、設定画面でも変更できます。

## 使い方

1. 設定でDiscordアカウントを連携します。
2. **+** ボタンからアプリや作業を登録します。
3. **アクティビティ共有**をオンにして、対象の**共有**を押します。
4. 作業が終わったらカードの**共有を停止**を押します。共有をオフにした場合も、現在のアクティビティは終了します。

![共有の開始と終了](media/sharing.gif)

共有後にアプリを開くには、アクティビティ設定でアプリURLまたはショートカット名を指定します。インストール済みアプリや起動URLは自動検出しません。アプリの開閉に連動するオートメーションについては、[開発ガイド](DEVELOPMENT.md)を参照してください。

| 手動で登録 | 言語と接続の設定 |
| --- | --- |
| ![手動で登録](media/custom-activity.png) | ![言語と接続の設定](media/settings.png) |

## ビルド

macOS、iOSシミュレータのランタイムを含むXcode 27ベータ、[XcodeGen](https://github.com/yonaskolb/XcodeGen)が必要です。実機へのインストールにはAppleの開発用署名も必要です。

```sh
git clone https://github.com/aizuproject/AIZU.git
cd AIZU
brew install xcodegen
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
AIZU_WITHOUT_SDK=1 zsh scripts/generate.sh
open iPadPresence.xcodeproj
```

`iPadPresence`スキームとシミュレータを選択します。実際のDiscord接続には、自分のDiscord Application IDと公式Social SDKが必要です。[接続設定](DEVELOPMENT.md)を完了してから、プロジェクトを再生成してください。

## バックグラウンド動作と制限

無音オーディオは共有と同時に開始し、共有の終了と同時に停止します。他の音声アプリ、通話、ネットワークの変化で中断する場合があり、AIZUを強制終了すると接続も終了します。

## プライバシーとセキュリティ

選択したアクティビティの名前、説明、画像URL、開始時刻をDiscordに送信します。App Storeの検索語はAppleに送られ、リモート画像の表示時には画像のホストに接続します。認証情報は端末のKeychainに保存します。AIZU独自の情報収集サーバーや解析サービスはありません。

他のアプリの画面、文書、動画タイトルは読み取りません。VPN、位置情報、マイクの権限も使用しません。アクティビティは手動操作または自分で設定したショートカットから開始します。脆弱性は公開イシューではなく、[非公開の報告窓口](https://github.com/aizuproject/AIZU/security/advisories/new)をご利用ください。GHSAを利用できない場合や、その他のセキュリティに関するお問い合わせは、[me@st4rain.com](mailto:me@st4rain.com)までお送りください。[セキュリティポリシー](../SECURITY.md)もご確認ください。

## 開発への参加

不具合は再現手順と端末・OS・AIZUのバージョンを添えて、[イシュー](https://github.com/aizuproject/AIZU/issues/new/choose)で報告してください。変更は作業ブランチからプルリクエストで提出します。[貢献ガイド](../CONTRIBUTING.md)、[検証範囲](TESTING.md)、[変更履歴](../CHANGELOG.md)を参照してください。

## ライセンス

AIZUのソースは[MITライセンス](../LICENSE)で公開します。Discord Social SDKは別途ダウンロードが必要で、Discordの利用規約とライセンスに従います。[外部コンポーネントについて](../THIRD_PARTY_NOTICES.md)をご確認ください。
