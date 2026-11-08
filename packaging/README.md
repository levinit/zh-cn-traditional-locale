# Linux 主流發行版打包指南

本項目採用「**自動包管理器鉤子 (Hook) + 命令行引擎 (CLI)**」的動態架構，安裝時由系統包管理器直接管理：
- 當安裝或升級任意軟件包時，鉤子自動觸發 OpenCC 將該軟件的 `zh_CN` 翻譯轉換為 `zh_CN@traditional`；
- 倉庫無需攜帶數百個臃腫的靜態 PO 文件，永遠 100% 精確匹配用戶本機軟件版本。

---

## 目錄結構

```text
packaging/
├── package.sh                      # 統一打包調度腳本（支持自動識別系統發行版）
├── arch/                           # Arch Linux / pacman / AUR 打包規範
│   ├── PKGBUILD                    # AUR 與本地統一構建腳本
│   ├── .SRCINFO                    # AUR 元數據文件
│   ├── zh-cn-traditional.hook      # libalpm 增量自動繁體化鉤子
│   ├── zh-cn-traditional-locale.install # 安裝全量同步與 locale-gen 提示
│   └── README.md                   # AUR 發佈與維護手冊
├── pacman                          # 指向 arch/ 的軟鏈接
├── debian/                         # Debian / Ubuntu / Mint 打包規範
│   ├── control                     # 包信息與依賴定義 (opencc, python3)
│   ├── triggers                    # dpkg 文件觸發器 (interest-noawait)
│   ├── rules                       # debhelper 構建流程
│   ├── changelog                   # 發行日志
│   ├── copyright                   # DEP-5 格式許可證聲明
│   ├── postinst                    # 安裝後全量同步與 locale-gen
│   ├── postrm                      # 卸載後清理 locale 歸檔與目錄
│   └── source/format               # 源碼格式 3.0 (native)
├── rpm/                            # Fedora / RHEL / CentOS / openSUSE
│   └── zh-cn-traditional-locale.spec # RPM spec（含 %filetriggerin 自動鉤子）
└── README.md                       # 本指南
```

---

## 統一打包入口 (`make pkg` / `package.sh`)

項目提供統一打包腳本 [`packaging/package.sh`](package.sh)：
* **自動檢測當前系統發行版並打包**：
  ```bash
  make pkg
  # 或直接運行：
  ./packaging/package.sh
  ```
  腳本會自動讀取 `/etc/os-release` 及可用包管理器，自動選擇合適的打包邏輯。

* **手動指定目標格式打包**：
  ```bash
  make arch      # 或 ./packaging/package.sh arch
  make deb       # 或 ./packaging/package.sh deb
  make rpm       # 或 ./packaging/package.sh rpm
  make packages  # 構建全部主流格式 (./packaging/package.sh all)
  ```

---

## 主流發行版打包與安裝一覽

| 目標發行版 | 格式 | 構建命令 | 生成產物 / 安裝命令 |
| :--- | :--- | :--- | :--- |
| **自動適配當前系統** | 自動判斷 | `make pkg` | 輸出至 `dist/`，根據提示安裝 |
| **Arch Linux / Manjaro** | `.pkg.tar.zst` | `make arch` | `sudo pacman -U dist/zh-cn-traditional-locale-*.pkg.tar.zst` |
| **Debian / Ubuntu / Mint** | `.deb` | `make deb` | `sudo dpkg -i dist/*.deb` |
| **Fedora / RHEL / openSUSE**| `.rpm` | `make rpm` | `sudo dnf install dist/noarch/*.rpm` |
| **源碼通用安裝（任意 Linux）**| - | `sudo make install PREFIX=/usr` | 安裝至 `/usr` 並自動初次同步 |

---

## 各發行版構建細節

### 1. Arch Linux (pacman & AUR)
* **自動增量鉤子**：安裝包會將 [`zh-cn-traditional.hook`](arch/zh-cn-traditional.hook) 部署至 `/usr/share/libalpm/hooks/`。此後用戶使用 `pacman` 安裝或升級任何軟件時，鉤子自動調用 `zh-cn-traditional-sync --hook` 進行毫秒級增量繁體化。
* **本地打包**：運行 `make arch`（產物輸出至 `dist/`）。
* **AUR 發佈**：詳見 [`packaging/arch/README.md`](arch/README.md)。

### 2. Debian / Ubuntu (`.deb`)
* 運行 `make deb` 即可在 `dist/` 目錄下生成合規的 `.deb` 安裝包。
* 包含 `triggers` 觸發器與 `postinst`：本包 `configure` 時全量同步；其他軟件變更 `zh_CN` MO 觸發時走 `zh-cn-traditional-sync --outdated` 增量刷新（dpkg 路徑觸發器無文件列表，按源/目標 mtime 與孤兒清理）。

### 3. Fedora / RHEL / openSUSE (`.rpm`)
* 運行 `make rpm` 調用 `rpmbuild` 在沙箱中生成 RPM 包。
* Spec 文件內置 `%filetriggerin -- /usr/share/locale/zh_CN/LC_MESSAGES`，無縫對接 RPM 的系統級文件觸發器機制。

### 4. 通用與源碼卸載
* 構建生成的文件均可通過 `make clean` 一鍵清除。
* 源碼安裝後如需完全卸載，運行：
  ```bash
  sudo make uninstall PREFIX=/usr
  ```
