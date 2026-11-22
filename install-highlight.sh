#!/bin/bash
# paper-companion · 「选中高亮」安装脚本(仅 macOS)
#
# 装两样东西:
#   1. 捕捉脚本  → <项目目录>/scripts/highlight-capture.sh
#   2. 系统服务  → ~/Library/Services/高亮到论文摘录.workflow(里面的路径按项目目录的实际位置生成)
#
# 用法:
#   install-highlight.sh --check                          只检查环境,不安装
#   install-highlight.sh --project <项目目录>              安装
#   install-highlight.sh --project <项目目录> --replace    已有同名服务指向别处时,备份旧的再装
#   install-highlight.sh --uninstall --project <项目目录>  卸载(摘录.md 和备忘录里已有的内容不动)
#
# 退出码:0 成功 / 2 参数不对 / 10 不是 macOS / 11 备忘录没有 iCloud 账户
#         12 已有同名服务且指向别处 / 13 没拿到控制「备忘录」的许可

set -u

SERVICE_NAME="高亮到论文摘录"
SERVICES_DIR="$HOME/Library/Services"
PROJECT=""
MODE="install"
REPLACE=0

usage() { sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --check) MODE="check" ;;
    --uninstall) MODE="uninstall" ;;
    --replace) REPLACE=1 ;;
    --project) shift; PROJECT="${1:-}" ;;
    --services-dir) shift; SERVICES_DIR="${1:-}" ;;   # 只给测试用
    -h|--help) usage; exit 0 ;;
    *) echo "不认识的参数:$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

xml_escape() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
shell_quote() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

check_env() {
  if [ "$(uname -s)" != "Darwin" ]; then
    echo "环境检查:不通过。这台电脑不是 macOS,系统服务和备忘录都只有 macOS 才有。"
    exit 10
  fi
  local accounts rc
  accounts=$(osascript -e 'tell application "Notes" to return name of every account' 2>&1)
  rc=$?
  if [ $rc -ne 0 ]; then
    echo "环境检查:不通过。没拿到控制「备忘录」的许可,或备忘录打不开。"
    echo "系统返回:$accounts"
    echo "处理:系统弹出「想要控制备忘录」时点允许;或到 系统设置 → 隐私与安全性 → 自动化 里打开,然后重试。"
    exit 13
  fi
  case "$accounts" in
    *iCloud*) echo "环境检查:通过。macOS,备忘录有 iCloud 账户。" ;;
    *)
      echo "环境检查:不通过。备忘录里没有 iCloud 账户,摘录没法同步到手机。"
      echo "处理:到 系统设置 → Apple 账户 → iCloud 里打开「备忘录」,然后重试。"
      exit 11 ;;
  esac
}

need_project() {
  if [ -z "$PROJECT" ] || [ ! -d "$PROJECT" ]; then
    echo "需要用 --project 指定一个已存在的项目目录。" >&2
    exit 2
  fi
  PROJECT="$(cd "$PROJECT" && pwd)"
  CAPTURE="$PROJECT/scripts/highlight-capture.sh"
  WF="$SERVICES_DIR/$SERVICE_NAME.workflow"
  CMD="exec /bin/zsh $(shell_quote "$CAPTURE")"
  CMD_XML="$(xml_escape "$CMD")"
}

# 已装的服务是不是指向这个项目
# 比的是服务里实际写入的整条命令(路径已按 shell 规则加引号、再按 XML 规则转义),
# 不能拿原始路径去比:路径里有单引号时,写进去的样子和原始路径不一样。
wf_points_here() {
  [ -f "$WF/Contents/document.wflow" ] || return 1
  plutil -convert xml1 -o - "$WF/Contents/document.wflow" 2>/dev/null | grep -qF -- "<string>${CMD_XML}</string>"
}

wf_current_target() {
  plutil -convert xml1 -o - "$WF/Contents/document.wflow" 2>/dev/null \
    | grep -A1 '<key>COMMAND_STRING</key>' | grep '<string>' | head -1 \
    | sed -e 's/^[[:space:]]*<string>//' -e 's/<\/string>.*$//' -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g'
}

write_capture_script() {
  mkdir -p "$PROJECT/scripts"
  cat > "$CAPTURE" <<'CAPTURE_EOF'
#!/bin/zsh
# paper-companion · 选中高亮捕捉脚本
# 由 install-highlight.sh 生成,重装会覆盖,不要手改。
#
# 用法一(系统服务调用):选中的文字从 stdin 进来
#        → 在 papers/ 里按字面反查出处 → 追加到 摘录.md 的「收件箱」→ 写一条备忘录
# 用法二(对话入口同步备忘录):
#        printf '%s' "原句" | highlight-capture.sh --note-only "标题" "出处" "批注"
#        只写备忘录,不动 摘录.md;失败时退出码非 0,原因记进日志
set -u

PROJ="${0:A:h:h}"                      # 本脚本在 <项目目录>/scripts/ 下
EXCERPTS="$PROJ/摘录.md"
LOG="$PROJ/scripts/highlight-capture.log"
DATE=$(date +%F)
NOTES_ERR=""

html_escape() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' }

notify() {
  osascript -e 'on run a' -e 'display notification (item 1 of a) with title "论文摘录"' -e 'end run' "$1" >/dev/null 2>&1 || true
}

# write_note 标题 原句 出处 批注
write_note() {
  NOTES_ERR=$(osascript - "$(html_escape "$1")" "$(html_escape "$2")" "$(html_escape "$3")" "$DATE" "$(html_escape "$4")" 2>&1 >/dev/null <<'APPLESCRIPT'
on run argv
	set noteTitle to item 1 of argv
	set noteBody to "<div><b>" & noteTitle & "</b></div><div><br></div><div><b>原句:</b>\"" & (item 2 of argv) & "\"</div><div><br></div><div><b>出处:</b>" & (item 3 of argv) & "</div><div><b>日期:</b>" & (item 4 of argv) & "</div><div><b>批注:</b>" & (item 5 of argv) & "</div>"
	tell application "Notes"
		tell account "iCloud"
			if not (exists folder "论文摘录") then make new folder with properties {name:"论文摘录"}
			tell folder "论文摘录" to make new note with properties {name:noteTitle, body:noteBody}
		end tell
	end tell
end run
APPLESCRIPT
)
}

log_notes_failure() {
  printf '%s 备忘录写入失败 rc=%s 调用方=%s :: %s\n' "$(date '+%F %T')" "$1" "$(ps -o comm= -p $PPID 2>/dev/null)" "$NOTES_ERR" >> "$LOG"
}

# ---------- 用法二:只写备忘录 ----------
if [ "${1:-}" = "--note-only" ]; then
  N_TITLE="${2:-未命名摘录 · $DATE}"
  N_SRC="${3:-(未注明)}"
  N_ANNOT="${4:-(无)}"
  N_TEXT="$(cat | tr -d '\r')"
  [ -z "$N_TEXT" ] && exit 0
  write_note "$N_TITLE" "$N_TEXT" "$N_SRC" "$N_ANNOT"
  RC=$?
  [ "$RC" -ne 0 ] && log_notes_failure "$RC"
  exit "$RC"
fi

# ---------- 用法一:选中捕捉 ----------
RAW="$(cat | tr -d '\r')"
# 存的时候把多行并成一行;反查出处用第一行非空内容
TEXT="$(printf '%s' "$RAW" | tr '\n' ' ' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -z "$TEXT" ] && exit 0
NEEDLE="$(printf '%s\n' "$RAW" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -m1 .)"
NLINES=$(printf '%s\n' "$RAW" | grep -c '[^[:space:]]')

# 摘录.md 不存在就先建骨架
if [ ! -f "$EXCERPTS" ]; then
  {
    printf '# 摘录\n\n'
    printf '> 用法:对 AI 说「高亮:某句话」,可附批注;装了「选中高亮」的,也可以选中文字直接加入。按主题包分组,只追加。\n'
  } > "$EXCERPTS"
fi

# 去重:这句话已经存过就不再存
if grep -qF -- "**原句**:\"$TEXT\"" "$EXCERPTS" 2>/dev/null; then
  notify "这句已经存过了,没有重复保存"
  exit 0
fi

# 出处反查(papers/ 里按字面找)
FILES=""
[ -d "$PROJ/papers" ] && FILES=$(grep -rlF --include='*.md' -- "$NEEDLE" "$PROJ/papers" 2>/dev/null || true)
NFILES=0; [ -n "$FILES" ] && NFILES=$(printf '%s\n' "$FILES" | grep -c .)

SRC="(未在 papers/ 中逐字找到,待 AI 核对)"
TITLE="未归档摘录 · $DATE"
if [ "$NFILES" -eq 1 ]; then
  FILE="$FILES"
  SECTION=$(NEEDLE="$NEEDLE" awk 'BEGIN{n=ENVIRON["NEEDLE"]} /^#/{h=$0} index($0, n){gsub(/^#+[[:space:]]*/,"",h); print h; exit}' "$FILE")
  [ -z "$SECTION" ] && SECTION="(节未定位)"
  BASE=$(basename "$FILE" .md)
  SHORT=${BASE#*-}; SHORT=${SHORT#*-}; SHORT=${SHORT#*-}   # 去掉日期前缀
  SRC="${BASE}.md · ${SECTION}"
  TITLE="${SHORT} · $DATE"
elif [ "$NFILES" -gt 1 ]; then
  SRC="(多处命中,待 AI 确认:$(printf '%s' "$FILES" | sed "s#^$PROJ/##" | tr '\n' ' '))"
fi
[ "$NLINES" -gt 1 ] && SRC="$SRC(选中了多行,出处按第一行反查)"

# 摘录.md 收件箱(只追加;收件箱固定是文件最后一节)
grep -qF '## 收件箱' "$EXCERPTS" 2>/dev/null || printf '\n## 收件箱(选中捕捉,待归包)\n' >> "$EXCERPTS"
{
  printf '\n- **原句**:"%s"\n' "$TEXT"
  printf '  **出处**:%s\n' "$SRC"
  printf '  **日期**:%s\n' "$DATE"
  printf '  **批注**:(选中捕捉,无)\n'
} >> "$EXCERPTS"

# 备忘录(iCloud 账户 / 「论文摘录」文件夹)
write_note "$TITLE" "$TEXT" "$SRC" "(选中捕捉,无)"
RC=$?
if [ "$RC" -eq 0 ]; then
  notify "已存进摘录和备忘录:${TITLE}"
else
  log_notes_failure "$RC"
  notify "已存进摘录文件,但备忘录没写进去:${TITLE}"
fi
exit 0
CAPTURE_EOF
  chmod +x "$CAPTURE"
}

write_workflow() {
  mkdir -p "$WF/Contents"
  cat > "$WF/Contents/Info.plist" <<INFO_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>${SERVICE_NAME}</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendTypes</key>
			<array>
				<string>NSStringPboardType</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
INFO_EOF
  cat > "$WF/Contents/document.wflow" <<WFLOW_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>528</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>Run Shell Script</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>${CMD_XML}</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>0</integer>
					<key>shell</key>
					<string>/bin/zsh</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>5D8E2F1A-0001-4A2B-9C3D-111111111111</string>
				<key>Keywords</key>
				<array>
					<string>Shell</string>
				</array>
				<key>OutputUUID</key>
				<string>5D8E2F1A-0002-4A2B-9C3D-222222222222</string>
				<key>UUID</key>
				<string>5D8E2F1A-0003-4A2B-9C3D-333333333333</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<integer>0</integer>
						<key>uuid</key>
						<string>0</string>
					</dict>
				</dict>
				<key>isViewVisible</key>
				<integer>1</integer>
			</dict>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.text</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.text</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>systemImageName</key>
		<string>NSActionTemplate</string>
		<key>useAsQuickAction</key>
		<true/>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW_EOF
}

refresh_services() {
  [ "$SERVICES_DIR" = "$HOME/Library/Services" ] || return 0
  /System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true
}

case "$MODE" in
  check)
    check_env
    ;;

  install)
    check_env
    need_project
    if [ -e "$WF" ] && ! wf_points_here; then
      if [ "$REPLACE" -ne 1 ]; then
        echo "没有安装:这台电脑上已经有一个「$SERVICE_NAME」服务,指向别的位置。"
        echo "它现在执行的是:$(wf_current_target)"
        echo "一台电脑上这个服务只能指向一个项目目录。要改成指向本项目,加 --replace 重跑(旧的会先备份)。"
        exit 12
      fi
      BAK="$WF.bak-$(date +%Y%m%d-%H%M%S)"
      mv "$WF" "$BAK"
      echo "旧服务已备份到:$BAK"
    fi
    write_capture_script
    rm -rf "$WF"
    write_workflow
    refresh_services
    echo "安装完成。"
    echo "捕捉脚本:$CAPTURE"
    echo "系统服务:$WF"
    echo "摘录会写进:$PROJECT/摘录.md(收件箱)和备忘录的「论文摘录」文件夹"
    ;;

  uninstall)
    need_project
    if [ -e "$WF" ]; then
      if wf_points_here; then
        rm -rf "$WF"; echo "已移除系统服务:$WF"
      else
        echo "系统服务没动:它指向的不是本项目($(wf_current_target))。"
      fi
    else
      echo "没有找到系统服务,跳过。"
    fi
    if [ -f "$CAPTURE" ]; then rm -f "$CAPTURE"; echo "已移除捕捉脚本:$CAPTURE"; fi
    refresh_services
    echo "卸载完成。摘录.md 和备忘录里已有的内容没有动。"
    ;;
esac
exit 0
