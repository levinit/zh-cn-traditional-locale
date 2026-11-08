# Task Routing & Agent Guidelines

本目錄爲 Agent 任務路由入口，根據任務類型按需加載對應資產。

## 任務路由表

| 任務類型 | 執行入口 / 工具 | 規則與參考 | 驗證門禁 |
| :--- | :--- | :--- | :--- |
| **反編譯與繁體化轉換** | `./bin/zh-cn-traditional-sync <domain>` | [locale-principles.md](rules/locale-principles.md)<br>Skill: [convert-locale](skills/convert-locale/SKILL.md) | `./scripts/verify.sh` |
| **全量同步系統現有組件** | `./bin/zh-cn-traditional-sync --all` (`make sync`) | [locale-principles.md](rules/locale-principles.md)<br>Skill: [convert-locale](skills/convert-locale/SKILL.md) | `./scripts/verify.sh` |
| **過期增量同步（無文件列表）** | `./bin/zh-cn-traditional-sync --outdated` | [locale-principles.md](rules/locale-principles.md)<br>`packaging/debian/postinst` | `./scripts/verify.sh` |
| **桌面快捷方式與面板同步** | `./bin/zh-cn-traditional-sync --desktop` (`make desktop`) | [locale-principles.md](rules/locale-principles.md) | `./scripts/verify.sh` |
| **清空桌面快捷方式副本** | `./bin/zh-cn-traditional-sync --clean-desktop` (`make clean-desktop`) | - | `./scripts/verify.sh` |
| **包管理器鉤子調試** | `echo "<path>" \| ./bin/zh-cn-traditional-sync --hook` | [packaging/README.md](../packaging/README.md) | `./scripts/verify.sh` |
| **調整字詞/一對多繁體修正** | 編輯 `config/overrides.tsv` | [locale-principles.md](rules/locale-principles.md) | `./scripts/verify.sh` |
| **自動適配當前系統打包** | `make pkg` (`./packaging/package.sh auto`) | [packaging/README.md](../packaging/README.md) | `packaging/package.sh` |
| **指定格式打包 (arch/deb/rpm)** | `make arch` / `make deb` / `make rpm` | [packaging/README.md](../packaging/README.md) | `packaging/package.sh` |
| **部署到系統** | `sudo make install PREFIX=/usr` | [Makefile](../Makefile) | `make verify` |
| **AUR 發佈維護** | 維護 `packaging/arch/PKGBUILD` 與 `.SRCINFO` | [packaging/arch/PKGBUILD](../packaging/arch/PKGBUILD) | `cd packaging/arch && makepkg --printsrcinfo > .SRCINFO` |
| **門禁驗證與健全性檢查** | `./scripts/verify.sh` (`make verify`) | - | `./scripts/verify.sh` |

## 目錄與事實源索引

- `bin/zh-cn-traditional-sync`：動態內存轉換核心引擎（兼支持手動同步與包管理器 hook 增量處理）。
- `i18n/locales/zh_CN@traditional`：系統 glibc locale 定義文件（元數據）。
- `config/overrides.tsv`：OpenCC 轉換後額外應用的詞彙微調規則（安裝至 `/etc/zh-cn-traditional/overrides.tsv`）。
- `packaging/arch/zh-cn-traditional.hook`：Arch Linux pacman 增量事務鉤子。
