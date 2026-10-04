# verilatorenv

[English](README.md) | [日本語](README_jp.md)

pyenv のように使える Verilator のバージョン管理ツールです。リポジトリを clone し、
`bin` を PATH に追加するだけで、通常の `verilator` コマンドから利用できます。
verilatorenv 自体の利用に、パッケージマネージャー、Python 環境、管理者権限は不要です。
Verilator は公式 GitHub リポジトリのリリースタグからソースを取得してビルドします。

## セットアップ

```bash
git clone https://github.com/ryuz/verilatorenv.git "$HOME/.verilatorenv"
export PATH="$HOME/.verilatorenv/bin:$PATH"
```

PATH の設定をシェルの起動ファイルに追加してください。`bin` ディレクトリは、
既存の Verilator のインストール先よりも PATH の前方に置く必要があります。
CLI の実行には Bash 4.4 以上が必要です。シェル連携は Bash と Zsh に対応しています。

デフォルトでは、設定、インストールしたバージョン、ビルドログ、shim は clone した
リポジトリ内に保存されます。保存先を分ける場合は、verilatorenv を実行する前に
`VERILATORENV_ROOT` を設定してください。

```bash
export VERILATORENV_ROOT="$HOME/.local/share/verilatorenv"
```

`bin` には `verilator`、`verilator_bin`、`verilator_coverage`、`verilator_gantt`、
`verilator_profcfunc`、`verilator_includer` のラッパーが含まれているため、
通常の利用にシェルの初期化は不要です。任意の初期化を行うと、インストールされた
すべての実行ファイルに対応する shim が PATH に追加され、`shell` コマンドが使えます。

```bash
eval "$(verilatorenv init - bash)"
# Zsh の場合はこちらを使用します。
eval "$(verilatorenv init - zsh)"
```

シェル関数を定義せず、PATH だけを設定する場合は `verilatorenv init --path` を使います。

## ビルドに必要なツール

Git、GNU Make、Autoconf、Perl、Flex、Bison、および使用する Verilator のリリースに
対応した C++ コンパイラーが必要です。`sed`、`sort`、`tee`、`mktemp` などの
標準的な Unix コマンドも使用します。Ubuntu/Debian では、通常は次のように準備できます。

```bash
sudo apt-get install git build-essential autoconf flex bison perl
```

Verilator のリリースによっては、追加の依存関係が必要です。SystemC は任意ですが、
利用する場合は別途インストールしてください。ビルドは各リリースの通常の手順である
`autoconf`、`configure`、`make`、`make install` に従います。
ソースを最初に clone する際には GitHub へのアクセスが必要です。

## 使い方

```bash
verilatorenv install --list
verilatorenv install 5.042
verilatorenv install v5.040       # 先頭の v は省略できます。

verilatorenv global 5.042
verilator --version

cd my-project
verilatorenv local 5.040
verilator --version
cd src                          # my-project/.verilator-version を継承します。
verilator --version

verilatorenv local --unset       # 現在のディレクトリの設定ファイルを削除します。
verilatorenv global system      # PATH 上にある既存の Verilator を使用します。
verilatorenv uninstall 5.040     # 確認を求めます。
verilatorenv uninstall -f 5.040  # 確認なし。未インストールでも成功します。
```

上記の例では、両方のバージョンを先にインストールする必要があります。
`local --unset` は現在のディレクトリの設定ファイルだけを削除し、親ディレクトリの
設定は引き続き適用されます。親の設定を上書きして system 版を使う場合は、
`verilatorenv local system` を実行してください。

バージョンは、次の優先順位で選択されます。

1. 環境変数 `VERILATORENV_VERSION`。`verilatorenv shell` による指定も含みます。
2. 最も近い `.verilator-version`。現在のディレクトリから親ディレクトリをたどり、
   `/` まで探索します。
3. `$VERILATORENV_ROOT/version` に保存された global 設定。
4. `system`。このツールのラッパー、shim、管理対象バージョンの `bin` ディレクトリを
   除いた PATH から検索します。

`VERILATORENV_DIR` を設定すると、local 設定の探索を開始するディレクトリを変更できます。
設定ファイルにはバージョンを1つ記述し、空行や `#` によるコメントも使用できます。
`global`、`local`、`shell` で設定する前に、そのバージョンをインストールしてください。
存在しないバージョンや無効な設定はエラーになり、別のバージョンには自動で切り替わりません。
アンインストールしても、プロジェクトの設定ファイルや global 設定は書き換えません。
選択中のバージョンを削除した場合は、別のバージョンを設定してください。

シェル連携を有効にしている場合は、次のように使えます。

```bash
verilatorenv shell 5.040
verilatorenv shell               # 現在のシェルで指定しているバージョンを表示します。
verilatorenv shell --unset
```

シェル連携を使わない場合は、環境変数で指定できます。

```bash
VERILATORENV_VERSION=5.040 verilator --version
```

`verilator` という名前のシェルエイリアスや関数は PATH より優先されるため、
ラッパーを使う場合は解除してください。ラッパーは実行前に `VERILATOR_ROOT` を解除し、
以前の設定が別のインストール先を指定しないようにします。
`VERILATORENV_ROOT` はこの管理ツールのデータ保存先であり、Verilator 本体の
`VERILATOR_ROOT` とは異なる環境変数です。

## その他のコマンド

```bash
verilatorenv versions            # インストール済みの一覧。選択中のものに * を表示します。
verilatorenv versions --bare
verilatorenv version             # 選択中のバージョンと設定元を表示します。
verilatorenv version-name
verilatorenv version-origin
verilatorenv which verilator
verilatorenv whence verilator_coverage
verilatorenv prefix [VERSION]
verilatorenv root
verilatorenv exec verilator --lint-only design.sv
verilatorenv rehash
verilatorenv commands
verilatorenv help
```

`exec` は選択中のバージョンに含まれる実行ファイルを実行し、引数と終了ステータスを
保持します。`rehash` は実行ファイル用の shim を再生成し、インストールと
アンインストールの後に自動実行されます。`shims` ディレクトリは verilatorenv が
管理するため、独自のスクリプトを置かないでください。

## インストールのオプション

```bash
verilatorenv install --skip-existing 5.042
verilatorenv install --force 5.042
VERILATORENV_JOBS=2 verilatorenv install 5.042
VERILATORENV_CONFIGURE_OPTS="--enable-ccache" verilatorenv install 5.042
VERILATORENV_MAKE_OPTS="CXX=clang++" verilatorenv install 5.042
```

`VERILATORENV_JOBS` のデフォルトは利用可能な CPU 数です。取得できない場合は2です。
メモリに余裕がない環境では、小さい値を指定してください。configure と Make の
オプションは空白区切りの引数リストとして扱い、シェルコードとしては実行しません。
リスト内の引用符による引数のグループ化や、空白を含む引数はサポートしていません。
prefix と DESTDIR の上書きは管理ツール専用です。`CC`、`CXX`、`CXXFLAGS` などの
コンパイラー用の変数は、通常どおり export して使うこともできます。

ビルドには、`cache` 内の一時的なソースディレクトリとステージングディレクトリを
使用します。出力はターミナルに表示し、失敗した場合も含めて
`cache/<version>.<id>.log` に保存します。ビルドが失敗しても、既存のインストールは
保持されます。新しいインストールは、`make install` とステージング先の
`verilator --version` による検証が成功してから配置します。
一時的なソースは処理後に削除します。同じバージョンのインストールとアンインストールは、
ロックディレクトリによって同時実行を防ぎます。`SIGKILL` などの捕捉できない終了で
ロックが残った場合は、実行中の処理がないことを確認してから、`locks` 内の該当する
ディレクトリ、または `.rehash-lock` を手動で削除してください。

デフォルトの取得元は `https://github.com/verilator/verilator.git` です。
`VERILATORENV_REPOSITORY` で、同じ `vVERSION` タグ形式を使用する信頼できるミラーを
指定できます。この変数はテストでも使用します。ビルドでは取得したリポジトリの
コードを実行するため、信頼できない取得元は指定しないでください。
対応するのはタグ付きのバージョンだけで、任意のブランチやコミットには対応していません。
このツールではタグの暗号学的な検証は行いません。各設定で選択できるのは1つの
バージョンで、pyenv の複数バージョンの同時指定やプラグイン API は実装していません。

インストール後にデータ保存先を移動しないでください。Verilator にはインストール先の
prefix が埋め込まれ、生成した shim は clone した CLI を参照します。
データ保存先を移動した場合は各バージョンを再ビルドし、clone した CLI を移動した場合は
`rehash` を実行してください。

## テスト

```bash
bash -n bin/* tests/run.sh
bash tests/run.sh
shellcheck bin/* tests/run.sh
```

統合テストは一時ディレクトリ内で、ネットワークに接続せず実行します。
タグ付きの小さな Git テスト用リポジトリを Autoconf と Make でビルドし、
バージョン選択、ラッパー、system 版の検索、シェル連携、空白を含むパス、無効な設定、
ビルド失敗、強制再ビルド、ロック、アンインストール、shim の削除を確認します。
実行には前述のビルド用ツールが必要です。ShellCheck は任意の静的解析ツールです。