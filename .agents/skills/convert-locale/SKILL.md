---
name: convert-locale
description: 提取並轉換系統 zh_CN 翻譯（通過 OpenCC s2t 繁體化），動態生成 zh_CN@traditional 的 MO 文件。
---

# Convert Locale Skill

自動化將簡體中文（`zh_CN`）的 `.mo` 文件反編譯、轉換爲保留大陸用語的繁體中文（`zh_CN@traditional`）並編譯爲 `.mo` 二進制文件。

## 執行步驟

### 1. 單個或指定組件（反編譯 -> 轉換 -> 編譯）

從系統 `/usr/share/locale/zh_CN/LC_MESSAGES/<domain>.mo` 反編譯提取、轉換並輸出到 `zh_CN@traditional/LC_MESSAGES/<domain>.mo`：

```bash
./bin/zh-cn-traditional-sync <domain_name>
# 例如：
./bin/zh-cn-traditional-sync baobab gnome-shell coreutils
```

### 2. 全量同步系統組件

掃描系統 `/usr/share/locale/zh_CN/LC_MESSAGES/` 下所有可用組件並全量轉換：

```bash
./bin/zh-cn-traditional-sync --all
# 或：
make sync
```

### 3. 包管理器鉤子模式（增量處理）

模擬或調用包管理器 hook 傳入的目標文件路徑：

```bash
printf "usr/share/locale/zh_CN/LC_MESSAGES/git.mo\n" | ./bin/zh-cn-traditional-sync --hook
```

### 4. 字詞微調與一對多簡繁歧義修正

若某些詞彙經過 OpenCC `s2t` 轉換後不符合預期（例如特定語境下的字詞選擇），在 `config/overrides.tsv`（或系統 `/etc/zh-cn-traditional/overrides.tsv`）中添加規則：

```text
原繁體詞<TAB>修正後繁體詞
```

重新運行 `./bin/zh-cn-traditional-sync <domain>` 即可自動應用規則。

### 5. 驗證與安裝

運行門禁驗證：

```bash
./scripts/verify.sh
```

如需直接安裝到系統目錄：

```bash
sudo make install PREFIX=/usr
```
