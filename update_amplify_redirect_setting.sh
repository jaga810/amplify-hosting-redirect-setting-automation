#!/bin/bash

##### パラメータ ######

# 拡張子
EXTENSION='.tsx'
# リダイレクト設定を行うルートディレクトリ
ROOT_DIR='./pages'
# リダイレクト設定から除外するファイル
EXCLUDED_FILES=("$ROOT_DIR/_app.tsx" "$ROOT_DIR/_document.tsx" "$ROOT_DIR/index.tsx")
# 出力先のファイル名
OUTPUT_FILE='redirections.json'
# Trailing Slashの設定(Next.jsのデフォルトはfalse)
TRAILING_SLASH=false


##### 関数 #####

### ソースパスとターゲットパスを受け取ってOUTPUT_FILEに書き出す関数 ###
# Args
# $1: source path
# $2: target path
# $3: status code
# $4: with comma? - default is true
function writeRedirectSetting (){
  local with_comma=${4:-true};

  echo "    {" >> $OUTPUT_FILE
  echo "        \"source\": \"$1\"," >> $OUTPUT_FILE
  echo "        \"target\": \"$2\"," >> $OUTPUT_FILE
  echo "        \"status\": \"$3\"" >> $OUTPUT_FILE

  if "$with_comma"; then
    echo "    }," >> $OUTPUT_FILE
  else
    echo "    }" >> $OUTPUT_FILE
  fi
}

### writeRedirectSettingをラップして、Trailing Slashの処理をする関数  ###
# Args
# $1: source path
# $2: target path
# $3: status code
# $4: with comma?
function writeRedirectSettingBasedOnTrailingSlashParam (){
    if "$TRAILING_SLASH"; then
      writeRedirectSetting "$1/" "$2/" $3 $4
      writeRedirectSetting $1 "$2/" $3 $4
    else
      writeRedirectSetting "$1/" "$2" $3 $4
      writeRedirectSetting $1 "$2" $3 $4
    fi
}

##### Amplify Hostingのリダイレクト設定ファイル redirects.json の生成 #####

# pages 配下のファイル名の配列の作成
pages=$(find $ROOT_DIR -type f | sort -r) # 逆順ソートをすることで、/posts/ が /posts/<id> でなく /posts/ にマッチするようにする

echo "[" > $OUTPUT_FILE

# pages 配下のファイル群に応じたリダイレクト設定の生成
for page in $pages
do
  # 除外ファイル群に含まれる場合はスキップ
  if printf '%s\n' "${EXCLUDED_FILES[@]}" | grep -qx $page; then
    continue
  fi

  # リダイレクトパスを整形 e.g. ./pages/posts/index.tsx → /posts
  page=${page#$ROOT_DIR}
  page=${page%$EXTENSION}
  page=${page%"/index"}

  # source と targetの文字列を加工
  source=$(echo $page | sed -e "s/\\[/\</" -e "s/\\]/\>/") # []を<>に書き換える e.g. /posts/[id] → /posts/<id>
  target=$page

  # リダイレクト設定の書き出し
  writeRedirectSettingBasedOnTrailingSlashParam $source $target 200
done

# アドホックなリダイレクト設定

## /settings to /settings/company
writeRedirectSettingBasedOnTrailingSlashParam "/settings" "/settings/private" 301

# 想定外のパスへのリクエストには404を返す
writeRedirectSetting "/<*>" "/404.html" 404 false

echo "]" >> $OUTPUT_FILE

# リダイレクト設定をAmplifyのビルドログに出力する
cat $OUTPUT_FILE

##### 書き出したリダイレクト設定を Amplify Hosting に反映する #####
/usr/local/bin/aws amplify update-app --app-id $AWS_APP_ID --custom-rules file://redirections.json