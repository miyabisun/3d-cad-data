# 多色プリントの共通規約

SCADの作者と、scad-live・orca-serverの実装者が共有する材料の受け渡し規約です。
自作モデルの材料を`primary`・`secondary`で識別し、公開ファイルは3MFにします。
対応版は[scad-live v0.2.8以降](https://github.com/miyabi-sunny-side/scad-live/releases)と
[OrcaServer v0.1.50以降](https://github.com/miyabi-sunny-side/orca-server/releases)です。
既存環境ではOrcaServerを先に更新し、その後scad-liveを更新してください。
OpenSCAD 2021.01で利用でき、nightlyへの変更は不要です。

## 材料の役割と所有先

| 所有先                | 設定するもの                                            |
| --------------------- | ------------------------------------------------------- |
| SCAD                  | 形状のどこを`primary`・`secondary`にするか              |
| scad-live             | 役割名・形状・相対位置を保持した3MFとプレビュー         |
| orca-serverのプレート | 各役割に使う、SQLiteの既存フィラメントID                |
| 印刷時のorca-server   | フィラメントに対応するAMSスロットとスライサーの材料番号 |

例えば本体を`primary`、文字を`secondary`にし、プレートで白PLAと黒PLAを割り当てます。
役割名は大小文字を区別する固定キーです。表示色、部品の並び順、3MFの数値ID、AMSスロット番号から推測しません。
同じ表示色でも役割を区別し、両役割へ同じフィラメントを割り当てることもできます。
対応する役割を増やす場合は、この規約と入出力の両実装を合わせて更新します。

## SCADでの指定

多色モデルは、トップレベルで使用する役割を1回だけ宣言し、
`scad_live_material`で役割ごとの形状を選択できるようにします。
既存の部品選択用`part`とは別の変数です。

```scad
scad_live_material = "all";
echo(scad_live_materials = ["primary", "secondary"]);

if (scad_live_material == "all" || scad_live_material == "primary")
  color("white") cube([10, 10, 2]);

if (scad_live_material == "all" || scad_live_material == "secondary")
  color("black") translate([10, 0, 0]) cube([10, 10, 2]);
```

通常のOpenSCAD表示では`all`で全体を表示します。
scad-liveは実行結果の`ECHO: scad_live_materials = ["primary", "secondary"]`を読み取ります。
各役割は`-D 'scad_live_material="primary"'`などで選択して生成します。
宣言は重複のない文字列配列で、選択する役割によって変えてはいけません。
通常の`echo()`はログとして扱い、この名前の宣言だけを読み取ります。
宣言が不正・複数・未対応の役割を含む場合は、理由を示して生成を失敗させます。

すべての役割は同じ原点・単位・印刷方向を使い、個別の原点移動や自動配置をしません。
異なる役割の形状は体積が重ならないように作り、境界で接することは許します。
`color()`は見分けるための表示です。フィラメントの銘柄・色・温度・AMS番号はSCADへ書きません。

宣言のない既存SCADは、全形状を`primary`として扱います。
単色のために既存ファイルを一括修正する必要はありません。

## 3MFでの受け渡し

`assets/<path>.scad`の公開出力は`dist/<path>.3mf`とします。
1ファイルを一組のモデルとして扱い、独立した部品の位置関係を保持します。
役割の情報を別ファイルに分けず、3MF内に含めます。

- 3MF Coreの`basematerials`に、役割名を`base.name`として記録します。
- 各役割のメッシュは、`object.pid`と`object.pindex`で該当の材料を参照します。
  役割別にメッシュを分け、三角形のプロパティで別の役割へ上書きしません。
- 全メッシュを一つの組立オブジェクトの`components`へまとめ、`build`から一度だけ参照します。
  組立オブジェクトには`pid`・`pindex`を付けません。
- 単位はmmです。変換を使う場合も、適用後の寸法・相対位置をSCADと一致させます。
- `displaycolor`は不透明なプレビュー色です。同色でも別役割として保持します。
  配列の順序や数値IDを変えても、参照先の`base.name`で同じ役割を取り出せるようにします。
- G-code、プリンター設定、温度設定、実フィラメントIDは含めません。

材料リソースの例です。数値IDと色は例示で、役割名が契約です。

```xml
<basematerials id="1">
  <base name="primary" displaycolor="#FFFFFFFF" />
  <base name="secondary" displaycolor="#202020FF" />
</basematerials>
```

この例では、primaryのメッシュは`pid="1" pindex="0"`、secondaryは`pid="1" pindex="1"`を持ちます。
scad-liveがOpenSCADの役割別出力をこの構造にまとめます。
OpenSCAD単体の色付き3MF出力や、表示色からの自動材料判定には依存しません。
宣言した役割の生成に失敗した場合は、不完全な3MFで正常な公開ファイルを置き換えません。

構造の定義は[3MF Core Specification](https://github.com/3MFConsortium/spec_core/blob/master/3MF%20Core%20Specification.md)を参照してください。

## orca-serverの設定と印刷

プレートには、例えば`primary → 白PLAのID`、`secondary → 黒PLAのID`をSQLiteへ保存します。
複数モデルを載せたプレートでは、同じ役割名に同じ割当を使います。
フィラメント製品の共通設定や色の台帳を複製せず、既存IDを参照します。
プレートの複製・再編集・サーバー再起動でも割当を保持します。

画面ではモデルが使う役割の材料選択を表示し、既存のファジー検索付き選択画面を使います。
単色モデルでは`primary`だけを表示します。
キュー追加時に選び直す画面は設けず、プレート詳細の操作から追加します。
未設定のまま保存でき、使用する役割の割当不足や材料の未装填は追加可否で示します。

キュー追加時と開始前に、使用する各フィラメントのAMSスロットを既存の優先順で解決します。
モデル更新で新しい役割が増えた場合も、別の材料へ黙って置き換えません。
スライサーには役割と材料番号の対応を明示し、一組のモデルを色ごとに分離配置しません。
数量指定は一組全体に適用します。試算・印刷には全材料と切替処理を反映します。
サポート接触面の材料設定は独立して保持し、`secondary`をサポート専用にはしません。

既存の単色プレートは、使用中のフィラメントを`primary`へ引き継ぎます。
旧プレートの`<path>.stl`参照は、同じ相対パスの`<path>.3mf`がある場合にそちらへ解決します。
モデル名・数量・他の印刷条件は保持します。3MFがなければ従来のSTLを利用します。
scad-liveは以前のSTLファイルを削除しませんが、一覧・配信の対象は3MFだけです。
ブラウザの旧`/<path>.stl`は`/<path>.3mf`へ置き換わります。
外部クライアントの直接ダウンロードURLは`/models/<path>.3mf`へ変更してください。
旧版のOrcaServerはこの役割規約に対応しないため、scad-liveだけを先に更新しないでください。

モデルの役割構成を変更した場合は、OrcaServerでプレートを開いて保存し直します。
追加した役割へ材料を割り当ててからキューへ追加してください。
SCAD参照の形状は試算・印刷準備時に再取得します。
準備を終えた試行の再試行には、その時点で固定した形状・材料条件を使います。

この規約は自作SCADからの出力を対象にします。外部配布3MFの材料番号やペイント情報を、
この規約の役割名へ推測で変換しません。外部ファイルの原本・多色情報は保持します。

## モデル例と確認方法

[隣接立方体のSCAD](https://github.com/miyabi-sunny-side/scad-live/blob/main/tests/fixtures/material-roles.scad)と
[生成済み3MF](https://github.com/miyabi-sunny-side/scad-live/blob/main/tests/fixtures/material-roles.3mf)を公開しています。
primaryはX=0〜10、secondaryはX=10〜20、両方ともY=0〜10・Z=0〜2 mmです。
全体は20×10×2 mmで、色ごとに原点を揃え直してはいけません。

SCADをベースキャンプの`assets/`へ置き、scad-liveを起動すると、
同じ相対パスの`dist/*.3mf`を生成します。生成に失敗した場合は端末に理由を表示し、
直前の正常な3MFを保持します。失敗した生成を成功としてブラウザへ通知しません。
具体的な起動・生成手順は[scad-liveの案内](https://github.com/miyabi-sunny-side/scad-live#材料を分ける)、
プレートの保存・材料設定は[OrcaServerの案内](https://github.com/miyabi-sunny-side/orca-server/blob/main/docs/plates.md)を参照してください。
