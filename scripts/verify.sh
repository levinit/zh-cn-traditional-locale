#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=== 正在運行驗證門禁 ==="

# 1. 檢查 opencc 命令與 python opencc 模塊
# 注意：sync 本身只用 Python opencc 模塊，不調用 opencc 命令行；
# 命令行缺失只警告、不阻塞，避免在只有 Python 模塊的系統上假陰性。
if ! command -v opencc &>/dev/null; then
    echo "[WARN] opencc 命令未找到（sync 只需 Python opencc 模塊，此項不阻塞）。"
else
    echo "[PASS] opencc 命令可用"
fi

if ! python3 -c "import opencc" &>/dev/null; then
    echo "[FAIL] python opencc 模塊未找到。"
    exit 1
fi
echo "[PASS] python opencc 模塊可用"

# 2. 檢查 zh-cn-traditional-sync 執行文件與基本運行
SYNC_BIN="${REPO_ROOT}/bin/zh-cn-traditional-sync"
if [[ ! -x "${SYNC_BIN}" ]]; then
    echo "[FAIL] ${SYNC_BIN} 未找到或不可執行！"
    exit 1
fi
"${SYNC_BIN}" --help >/dev/null
echo "[PASS] zh-cn-traditional-sync 核心引擎健全性校驗通過。"

# 3. 測試動態轉換引擎（內容斷言始終跑 mock；有系統 MO 時再加一輪真實樣本）
TMP_TEST_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_TEST_DIR}"' EXIT

mkdir -p "${TMP_TEST_DIR}/src"
cat << 'EOF' > "${TMP_TEST_DIR}/test.po"
msgid ""
msgstr "Content-Type: text/plain; charset=UTF-8\n"

msgid "test file"
msgstr "测试文件，默认内存与硬盘"
EOF
msgfmt "${TMP_TEST_DIR}/test.po" -o "${TMP_TEST_DIR}/src/test.mo"
"${SYNC_BIN}" --src-dir "${TMP_TEST_DIR}/src" \
              --dest-dir "${TMP_TEST_DIR}/LC_MESSAGES" \
              --quiet test
if [[ ! -s "${TMP_TEST_DIR}/LC_MESSAGES/test.mo" ]]; then
    echo "[FAIL] 動態轉換測試失敗：未能生成 test.mo！"
    exit 1
fi
# 內容斷言：mock 原文必須轉為繁體且保留大陸術語（不可變成檔案/預設/記憶體/硬碟）。
MOCK_PO="$(msgunfmt "${TMP_TEST_DIR}/LC_MESSAGES/test.mo" 2>/dev/null || true)"
for expect in "測試文件" "默認" "內存" "硬盤"; do
    if ! printf '%s' "${MOCK_PO}" | grep -q "${expect}"; then
        echo "[FAIL] 動態轉換內容校驗失敗：回讀結果中缺少 ${expect}！"
        exit 1
    fi
done
for forbid in "檔案" "預設" "記憶體" "硬碟"; do
    if printf '%s' "${MOCK_PO}" | grep -q "${forbid}"; then
        echo "[FAIL] 動態轉換內容校驗失敗：回讀結果出現臺灣用語 ${forbid}！"
        exit 1
    fi
done
echo "[PASS] 動態轉換內容校驗通過 (mock test.mo 為繁體且保留大陸術語)。"

SAMPLE_MO="$(find /usr/share/locale/zh_CN/LC_MESSAGES -maxdepth 1 -name "*.mo" 2>/dev/null | sort | head -n 1 || true)"
if [[ -n "${SAMPLE_MO}" && -f "${SAMPLE_MO}" ]]; then
    SAMPLE_DOMAIN="$(basename "${SAMPLE_MO}" .mo)"
    "${SYNC_BIN}" --src-dir "/usr/share/locale/zh_CN/LC_MESSAGES" \
                  --dest-dir "${TMP_TEST_DIR}/sys_LC_MESSAGES" \
                  --quiet "${SAMPLE_DOMAIN}"
    if [[ ! -s "${TMP_TEST_DIR}/sys_LC_MESSAGES/${SAMPLE_DOMAIN}.mo" ]]; then
        echo "[FAIL] 系統樣本轉換失敗：未能生成 ${SAMPLE_DOMAIN}.mo！"
        exit 1
    fi
    if ! msgunfmt "${TMP_TEST_DIR}/sys_LC_MESSAGES/${SAMPLE_DOMAIN}.mo" 2>/dev/null | grep -q "msgstr"; then
        echo "[FAIL] 系統樣本轉換失敗：${SAMPLE_DOMAIN}.mo 無法用 msgunfmt 回讀出 msgstr！"
        exit 1
    fi
    echo "[PASS] 系統樣本轉換管線通過 (${SAMPLE_DOMAIN}.mo)。"
fi

# 4. 校驗 i18n/locales/zh_CN@traditional 基本格式與元數據
LOCALE_DEF="${REPO_ROOT}/i18n/locales/zh_CN@traditional"
if [[ -f "${LOCALE_DEF}" ]]; then
    if grep -q "libc-alpha@sourceware.org" "${LOCALE_DEF}"; then
        echo "[FAIL] i18n/locales/zh_CN@traditional 仍包含 glibc 默認郵箱！"
        exit 1
    fi
    if grep -q "%H时%M分%S秒" "${LOCALE_DEF}"; then
        echo "[FAIL] i18n/locales/zh_CN@traditional 時間格式仍使用簡體'时'！"
        exit 1
    fi
    echo "[PASS] i18n/locales/zh_CN@traditional 元數據檢查通過。"
else
    echo "[FAIL] 未找到 locale 定義文件：${LOCALE_DEF}"
    exit 1
fi

# 5. 校驗 pacman hook 語法
HOOK_FILE="${REPO_ROOT}/packaging/arch/zh-cn-traditional.hook"
if [[ ! -f "${HOOK_FILE}" ]]; then
    echo "[FAIL] 未找到 pacman hook: ${HOOK_FILE}"
    exit 1
fi
if ! grep -q "zh-cn-traditional-sync" "${HOOK_FILE}"; then
    echo "[FAIL] pacman hook 未調用 zh-cn-traditional-sync！"
    exit 1
fi
echo "[PASS] pacman hook 規範檢查通過。"

# 6. 測試 .desktop 同步與孤兒清理功能
DESK_SRC="${TMP_TEST_DIR}/desk_src"
DESK_DEST="${TMP_TEST_DIR}/desk_dest"
mkdir -p "${DESK_SRC}" "${DESK_DEST}"
cat << 'EOF' > "${DESK_SRC}/test.desktop"
[Desktop Entry]
Name[zh_CN]=外观
EOF
"${SYNC_BIN}" --desktop -y --desktop-src-dir "${DESK_SRC}" --desktop-dest-dir "${DESK_DEST}" --quiet
if ! grep -q "Name\[zh_CN@traditional\]=外觀" "${DESK_DEST}/test.desktop" 2>/dev/null; then
    echo "[FAIL] .desktop 繁體化同步校驗失敗！"
    exit 1
fi
rm -f "${DESK_SRC}/test.desktop"
"${SYNC_BIN}" --desktop -y --desktop-src-dir "${DESK_SRC}" --desktop-dest-dir "${DESK_DEST}" --quiet
if [[ -f "${DESK_DEST}/test.desktop" ]]; then
    echo "[FAIL] .desktop 孤兒清理校驗失敗！"
    exit 1
fi
echo "[PASS] .desktop 繁體化與孤兒清理機制校驗通過。"

# 7. 測試 --all 的桌面語義：--all 默認只同步 MO，--all --desktop 才同步桌面
ALL_SRC="${TMP_TEST_DIR}/all_src"
ALL_DESK_SRC="${TMP_TEST_DIR}/all_desk_src"
mkdir -p "${ALL_SRC}" "${ALL_DESK_SRC}"
cat << 'EOF' > "${TMP_TEST_DIR}/alltest.po"
msgid ""
msgstr "Content-Type: text/plain; charset=UTF-8\n"

msgid "test file"
msgstr "测试文件"
EOF
msgfmt "${TMP_TEST_DIR}/alltest.po" -o "${ALL_SRC}/alltest.mo"
cat << 'EOF' > "${ALL_DESK_SRC}/alltest.desktop"
[Desktop Entry]
Name[zh_CN]=外观
EOF

# 7a. --all 單獨：只應生成 MO，不應生成桌面文件、不應等待交互確認
"${SYNC_BIN}" --all --quiet \
    --src-dir "${ALL_SRC}" --dest-dir "${TMP_TEST_DIR}/all_dest" \
    --desktop-src-dir "${ALL_DESK_SRC}" --desktop-dest-dir "${TMP_TEST_DIR}/all_desk_dest"
if [[ ! -f "${TMP_TEST_DIR}/all_dest/alltest.mo" ]]; then
    echo "[FAIL] --all 語義校驗失敗：未生成 alltest.mo！"
    exit 1
fi
if [[ -d "${TMP_TEST_DIR}/all_desk_dest" ]] && find "${TMP_TEST_DIR}/all_desk_dest" -name "*.desktop" 2>/dev/null | grep -q .; then
    echo "[FAIL] --all 語義校驗失敗：--all 不應自動生成桌面文件！"
    exit 1
fi

# 7b. --all --desktop -y：應同時生成 MO 與桌面文件
"${SYNC_BIN}" --all --desktop -y --quiet \
    --src-dir "${ALL_SRC}" --dest-dir "${TMP_TEST_DIR}/all_dest2" \
    --desktop-src-dir "${ALL_DESK_SRC}" --desktop-dest-dir "${TMP_TEST_DIR}/all_desk_dest2"
if [[ ! -f "${TMP_TEST_DIR}/all_dest2/alltest.mo" ]]; then
    echo "[FAIL] --all --desktop 語義校驗失敗：未生成 alltest.mo！"
    exit 1
fi
if ! grep -q "Name\[zh_CN@traditional\]=外觀" "${TMP_TEST_DIR}/all_desk_dest2/alltest.desktop" 2>/dev/null; then
    echo "[FAIL] --all --desktop 語義校驗失敗：未生成繁體桌面文件！"
    exit 1
fi

# 7c. --all --desktop -y 且源目錄無 MO：仍應執行桌面同步（零 MO 提前返回的舊問題）
EMPTY_SRC="${TMP_TEST_DIR}/empty_src"
mkdir -p "${EMPTY_SRC}"
"${SYNC_BIN}" --all --desktop -y --quiet \
    --src-dir "${EMPTY_SRC}" --dest-dir "${TMP_TEST_DIR}/empty_dest" \
    --desktop-src-dir "${ALL_DESK_SRC}" --desktop-dest-dir "${TMP_TEST_DIR}/empty_desk_dest"
if ! grep -q "Name\[zh_CN@traditional\]=外觀" "${TMP_TEST_DIR}/empty_desk_dest/alltest.desktop" 2>/dev/null; then
    echo "[FAIL] 零 MO 時 --all --desktop 語義校驗失敗：桌面文件未生成！"
    exit 1
fi
echo "[PASS] --all 桌面語義校驗通過。"

# 8. PO 邊界：複數 msgstr[N]、msgctxt、轉義引號；以及 --outdated 增量語義
REPO_ROOT="${REPO_ROOT}" python3 - <<'PY'
import importlib.machinery
import importlib.util
import os
import sys
from pathlib import Path

repo = Path(os.environ["REPO_ROOT"])
path = repo / "bin" / "zh-cn-traditional-sync"
loader = importlib.machinery.SourceFileLoader("zh_sync", str(path))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)

class FakeCC:
    def convert(self, text: str) -> str:
        return (
            text.replace("说", "說")
            .replace("默认", "默認")
            .replace("测试", "測試")
            .replace("外观", "外觀")
            .replace("个", "個")
        )

po = r'''msgid ""
msgstr "Content-Type: text/plain; charset=UTF-8\n"

msgctxt "menu"
msgid "test"
msgstr "测试文件"

msgid "file"
msgid_plural "files"
msgstr[0] "一个文件"
msgstr[1] "多个文件"

msgid "quote"
msgstr "他说\"你好\""
'''
out = mod.convert_po_text(po, FakeCC(), [])
checks = [
    ('msgctxt "menu"', "msgctxt 必須原樣保留"),
    ('msgid "test"', "msgid 必須原樣保留"),
    ('msgstr "測試文件"', "msgctxt 條目的 msgstr 應繁體化"),
    ("msgid_plural", "msgid_plural 必須原樣保留"),
    ('msgstr[0] "一個文件"', "msgstr[0] 應繁體化"),
    ('msgstr[1] "多個文件"', "msgstr[1] 應繁體化"),
    ('msgstr "他說\\"你好\\""', "轉義引號 msgstr 應繁體化且保留轉義"),
]
for needle, err in checks:
    if needle not in out:
        print(f"[FAIL] PO 邊界校驗失敗：{err}")
        print(out)
        sys.exit(1)
print("[PASS] PO 複數/msgctxt/轉義引號轉換校驗通過。")
PY

OUTDATED_SRC="${TMP_TEST_DIR}/outdated_src"
OUTDATED_DEST="${TMP_TEST_DIR}/outdated_dest"
mkdir -p "${OUTDATED_SRC}" "${OUTDATED_DEST}"
cat << 'EOF' > "${TMP_TEST_DIR}/fresh.po"
msgid ""
msgstr "Content-Type: text/plain; charset=UTF-8\n"

msgid "a"
msgstr "测试"
EOF
msgfmt "${TMP_TEST_DIR}/fresh.po" -o "${OUTDATED_SRC}/fresh.mo"
# 先全量生成目標
"${SYNC_BIN}" --all --quiet --src-dir "${OUTDATED_SRC}" --dest-dir "${OUTDATED_DEST}"
# 再放一個僅存在於目標的孤兒，以及一個更新過的源
echo 'orphan' > "${OUTDATED_DEST}/orphan.mo"
sleep 1
cat << 'EOF' > "${TMP_TEST_DIR}/fresh2.po"
msgid ""
msgstr "Content-Type: text/plain; charset=UTF-8\n"

msgid "a"
msgstr "测试文件"
EOF
msgfmt "${TMP_TEST_DIR}/fresh2.po" -o "${OUTDATED_SRC}/fresh.mo"
"${SYNC_BIN}" --outdated --quiet --src-dir "${OUTDATED_SRC}" --dest-dir "${OUTDATED_DEST}"
if [[ -f "${OUTDATED_DEST}/orphan.mo" ]]; then
    echo "[FAIL] --outdated 未清理孤兒 MO！"
    exit 1
fi
if ! msgunfmt "${OUTDATED_DEST}/fresh.mo" 2>/dev/null | grep -q "測試文件"; then
    echo "[FAIL] --outdated 未更新過期 MO！"
    exit 1
fi
echo "[PASS] --outdated 增量語義校驗通過。"

# 9. Debian 觸發器應走增量而非全量
if ! grep -q -- '--outdated' "${REPO_ROOT}/packaging/debian/postinst"; then
    echo "[FAIL] packaging/debian/postinst 觸發路徑未使用 --outdated！"
    exit 1
fi
if ! grep -q 'triggered' "${REPO_ROOT}/packaging/debian/postinst"; then
    echo "[FAIL] packaging/debian/postinst 缺少 triggered 分支！"
    exit 1
fi
echo "[PASS] Debian 觸發器增量配置檢查通過。"

echo "=== 所有門禁檢查通過 ==="
