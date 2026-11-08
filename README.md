# zh-cn-traditional-locale

Linux 中文 locale 變體（`zh_CN@traditional`）：**繁體字形 + 大陸術語**。

本項目是一套專為習慣大陸簡體中文計算機術語、但偏好繁體漢字字形的使用者設計的現代化 Linux 本地化解決方案。

在 Linux 系統中，傳統的 `zh_CN`（簡體中文）術語符合大陸習慣但字形為簡體；而 `zh_TW` 或 `zh_HK` 字形雖為繁體，但帶有大量港臺地域詞彙（如「檔案」、「預設」、「硬碟」、「記憶體」、「程式」、「伺服器」）。`zh_CN@traditional` 旨在消除這種割裂：

- **字形繁體化**：漢字全面使用規範的傳統繁體（正體）字形；
- **術語大陸化**：100% 嚴格保留大陸標準計算機術語（「文件」、「默認」、「硬盤」、「內存」、「程序」、「服務器」、「軟件」、「網絡」），絕不混入港臺方言詞；
- **原生與回退安全**：底層具備標準的 glibc locale 定義；未覆蓋的軟件自動前綴剝離並安全回退至簡體 `zh_CN`，絕不跳轉至 `zh_TW`。

---

## 運作原理：包管理器自動鉤子 (Hook) + 命令行引擎 (CLI)

與傳統「預先在倉庫中塞入幾百個龐大 PO 翻譯文件」的靜態方案不同，本項目採用現代化的**「動態本地化」**架構：

```text
                                  ┌─────────────────────────────┐
                                  │   使用者安裝/更新任意軟件包    │
                                  │ (例如 pacman -S gimp / git) │
                                  └──────────────┬──────────────┘
                                                 │
                                     釋放了 zh_CN/*.mo
                                                 │
                                                 ▼
┌───────────────────────────┐      ┌─────────────────────────────┐
│  手動運行 (CLI 隨時調用)    │      │  包管理器鉤子 (alpm Hook)     │
│  zh-cn-traditional-sync   │      │  自動觸發，僅針對變更的 mo    │
└─────────────┬─────────────┘      └─────────────┬───────────────┘
              │                                  │
              └──────────────────┬───────────────┘
                                 ▼
                 ┌───────────────────────────────┐
                 │    zh-cn-traditional-sync     │
                 │ 內存 OpenCC 毫秒級繁體化轉換   │
                 └───────────────┬───────────────┘
                                 ▼
                 ┌───────────────────────────────┐
                 │ 即時生成 zh_CN@traditional/*.mo│
                 │     （100% 匹配當前軟件版本）   │
                 └───────────────────────────────┘
```

### 1. 自動鉤子（Hook）的工作機制
- **自動部署**：安裝本軟件包後，會自動將鉤子註冊至系統對應路徑：
  - **Arch Linux / pacman**：`/usr/share/libalpm/hooks/zh-cn-traditional.hook`
  - **Debian / Ubuntu / dpkg**：`DEBIAN/triggers` 文件觸發器（`interest-noawait`）
  - **Fedora / openSUSE / rpm**：RPM Spec `%filetriggerin` 事務觸發器

- **零性能損耗（增量處理）**：
  - 鉤子**僅在**安裝或升級的軟件包含 `/usr/share/locale/zh_CN/LC_MESSAGES/*.mo` 時才會被激活；
  - 借助 `NeedsTargets` 機制，鉤子只針對本次變動的 1~2 個 `.mo` 文件執行增量轉換；
  - 採用內存管道直通技術（`msgunfmt -> OpenCC(s2t) -> msgfmt`），**轉換單個軟件僅耗時約 20 毫秒**，日常系統更新完全無感。

- **無版本漂移**：翻譯源頭永遠來自用戶本機正在安裝的軟件版本。
  

### 2. 手動同步工具（CLI）

隨包提供 `/usr/bin/zh-cn-traditional-sync`，供初次全量轉換、調試或自定義詞表微調後手動觸發。

---

## 快速開始

### 1. 安裝軟件包

* **Arch Linux / Manjaro（推薦使用 AUR）**：
  ```bash
  paru -S zh-cn-traditional-locale
  # 或：yay -S zh-cn-traditional-locale
  ```

* **手動打包安裝（適配當前系統發行版）**：
  ```bash
  make pkg        # 自動檢測發行版並輸出安裝包至 dist/
  # 或直接指定目標：make arch / make deb / make rpm
  ```

* **源碼直接安裝**：
  ```bash
  sudo make install PREFIX=/usr
  ```
  > 安裝完成時會自動在 `/etc/locale.gen` 註冊 `zh_CN@traditional UTF-8`、生成 locale 歸檔，並自動全量初次同步系統現有已安裝軟件的翻譯（僅 MO，不含桌面快捷方式）。

### 2. 啓用環境變量

在您的用戶環境變量配置文件（如 `~/.profile`、`~/.bashrc`、`~/.pam_environment` 或桌面環境“區域與語言”設置）中添加：

```bash
export LANG=zh_CN@traditional
export LANGUAGE=zh_CN@traditional
```
重新登錄或重啟終端後即可生效。

---

## 依賴環境（Prerequisites）

由於採用動態翻譯引擎與包管理器鉤子，系統運行依賴 OpenCC 與 Python 環境（桌面發行版通常已默認具備）：

| 依賴項 | 類型 | 說明 |
| :--- | :--- | :--- |
| **`glibc`** | 運行依賴 | 提供基礎 `locale-gen` / `localedef` 支持 |
| **`gettext`** | 運行依賴 | 提供 `msgfmt`、`msgunfmt` 用於 MO 二進制轉換 |
| **`opencc`** | 運行依賴 | 提供高效的漢字簡繁轉換底層引擎 |
| **`python >= 3.8`** 及 `python-opencc` | 運行依賴 | 運行 `zh-cn-traditional-sync` 核心腳本 |
| **`make`** | 構建依賴 | 源碼構建與調度打包所需 |

各發行版依賴安裝命令：
```bash
# Arch Linux / Manjaro
sudo pacman -S make gettext opencc python

# Debian / Ubuntu / Mint
sudo apt install make gettext opencc python3 python3-opencc

# Fedora / RHEL / CentOS
sudo dnf install make gettext opencc python3 python3-opencc
```

---

## 命令行工具使用 (`zh-cn-traditional-sync`)

除了包管理器的自動觸發外，您亦可隨時在終端手動調用：

```bash
# 1. 全量同步系統當前所有已安裝的 zh_CN 組件的 MO（或 make sync；不含桌面快捷方式，如需同時同步桌面，用 --all --desktop）
sudo zh-cn-traditional-sync --all

# 2. 針對單個或多個指定組件進行同步
sudo zh-cn-traditional-sync git gnome-shell baobab

# 3. 測試包管理器鉤子（從標準輸入讀取變動路徑）
printf "usr/share/locale/zh_CN/LC_MESSAGES/git.mo\n" | zh-cn-traditional-sync --hook

# 4. 可選：將轉換後的 PO 文本導出至指定目錄（調試/審查用）
zh-cn-traditional-sync --save-po ./po-debug git

# 5. 桌面快捷方式與設置面板繁體化（覆蓋至 ~/.local/share/applications/，自動清理已卸載應用的孤兒快捷方式；需單獨運行，--all 默認不再自動帶桌面）
zh-cn-traditional-sync --desktop            # 交互式提示確認（Y/n）
zh-cn-traditional-sync --desktop -y         # 免交互直接執行

# 6. 安全撤銷與清空由本工具生成的所有桌面快捷方式副本
zh-cn-traditional-sync --clean-desktop
```

### 詞彙自定義微調

若 OpenCC `s2t` 的某些字詞在特定語境下需要微調，可直接編輯 `/etc/zh-cn-traditional/overrides.tsv`（源代碼中對應 `config/overrides.tsv`）：

```text
原繁體詞<TAB>修正後繁體詞
```
保存後運行 `sudo zh-cn-traditional-sync --all`，即可立即重新生成生效。

---

## Makefile 常用目標速查

| 目標 | 命令 | 說明 |
| :--- | :--- | :--- |
| **sync** | `make sync` | 調用 `zh-cn-traditional-sync --all` 全量同步系統現有組件的 MO（不含桌面） |
| **desktop** | `make desktop` | 調用 `zh-cn-traditional-sync --desktop` 繁體化用戶級快捷方式與面板 |
| **clean-desktop** | `make clean-desktop` | 清空撤銷由本工具生成的所有桌面快捷方式副本 |
| **verify** | `make verify` | 運行完整性門禁檢查（校驗核心腳本、locale 定義、hook 規範等） |
| **install** | `sudo make install [PREFIX=/usr]` | 安裝 locale 定義、CLI 引擎、配置與 hook，並初次全量同步 MO（不含桌面） |
| **uninstall** | `sudo make uninstall [PREFIX=/usr]` | 移除安裝的文件與 hook，註銷 locale.gen 並清理生成的 MO |
| **pkg** | `make pkg` | 自動識別當前發行版體系並調用對應打包器 |
| **arch** | `make arch` | 調用 `makepkg` 構建 Arch Linux 安裝包 (`.pkg.tar.zst`) |
| **deb** | `make deb` | 調用 `dpkg-deb`（或原生回退）構建 Debian 安裝包 (`.deb`) |
| **rpm** | `make rpm` | 調用 `rpmbuild` 沙箱構建 RPM 安裝包 (`.rpm`) |
| **packages** | `make packages` | 一鍵構建全部主流發行版安裝包輸出至 `dist/` |
| **clean** | `make clean` | 清理構建產物、臨時目錄與各發行版安裝包 |

---

## 常見問題（FAQ）

### 1. 為什麼桌面設置面板的語言列表顯示為 `漢語 — traditional`？
- **原因**：GNOME 桌面（`gnome-control-center` / `libgnome-desktop`）在 C 源碼中為 locale 修飾符硬編碼了一個只有 7 個項的內部白名單（僅包含 `latin`、`cyrillic` 等少數預置項）。對於不在白名單內的修飾符（如 `@traditional`），上游代碼直接返回英文原詞，未進入 gettext 翻譯鏈路。
- **影響**：此現象僅限於桌面設置面板的語言名稱展示，**完全不影響**系統終端、應用程序及桌面界面的實際繁體字形與大陸術語渲染。

### 2. 未覆蓋的軟件會顯示什麼？
- 系統採用前綴安全回退機制，未命中繁體翻譯的軟件會自動回退至系統原生的簡體 `zh_CN` 界面，絕不會跳轉至臺灣用語的 `zh_TW`。
- 如果發現某個軟件仍顯示為簡體，只要系統已裝有簡體包，運行 `sudo zh-cn-traditional-sync <domain>` 即可秒級補齊繁體。

---

## 許可證（License）

本項目自身腳本、Makefile、打包規範與配置工具採用 [GNU GPL-3.0-or-later 許可證](LICENSE) 開源。
glibc locale 定義文件遵從 glibc 開源協議（LGPL-2.1+ / GPL-2.0+）；各軟件 domain 的 PO 翻譯文本遵從相應上游開源軟件項目的原始協議。
