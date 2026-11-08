# Locale Rules & Translation Principles

## 1. 架構與機制邊界

- **完整雙層支持**：
  1. **glibc Locale 元數據層**：通過 `i18n/locales/zh_CN@traditional` 安裝至 `/usr/share/i18n/locales/zh_CN@traditional`，並在 `/etc/locale.gen` 中註冊 `zh_CN@traditional UTF-8` 後執行 `locale-gen`（或 `localedef`），使系統原生支持 `LANG=zh_CN@traditional`。
  2. **gettext 翻譯層**：將編譯後的 `.mo` 部署至 `/usr/share/locale/zh_CN@traditional/LC_MESSAGES/*.mo`，供應用程序在運行時加載繁體字形翻譯。
- **打包與安裝隔離**：當 `DESTDIR` 非空（即正在構建 Arch/DEB/RPM 軟件包）時，`make install` 僅複製文件至目標根目錄，絕不修改宿主機的 `/etc/locale.gen`；僅在真實系統安裝/卸載（`DESTDIR` 爲空或包管理器鉤子 `post_install`/`post_remove`、`postinst`/`postrm`、`%post`/`%postun`）時自動增刪 `/etc/locale.gen` 條目並調用 `locale-gen` / `localedef`。
- **回退邏輯**：未覆蓋的 domain gettext 會按前綴剝離回退至 `zh_CN`（簡體），不會自動跳轉到 `zh_TW`。如需手動補齊，使用 `zh-cn-traditional-sync <domain>` 提取並轉換對應組件。
- **桌面環境修飾符顯示限制**：在 GNOME 等桌面環境的語言選擇器中，`@traditional` 可能顯示爲英文 `traditional`。這是由於 `libgnome-desktop` 的 `gnome_get_translated_modifier()` 內部採用固定 C 白名單硬編碼，未經由 gettext `.mo` 翻譯；此現象屬於桌面環境上游代碼行為，不影響應用程序的實際本地化渲染。

## 2. 術語規範（大陸習慣 + 繁體字形）

本項目的核心目標是“字形繁體，用詞大陸”。使用 `opencc -c s2t`（純簡繁轉換），嚴禁使用 `s2tw` 或 `s2twp`（臺灣詞彙化轉換）。

關鍵術語對照舉例：

| 概念 | 目標用法（大陸繁體） | 嚴禁使用的臺灣用法 |
| :--- | :--- | :--- |
| File | 文件 | 檔案 |
| Default | 默認 | 預設 |
| Hard Drive | 硬盤 | 硬碟 |
| Memory | 內存 | 記憶體 |
| Interface | 界面 | 介面 |
| Network | 網絡 | 網路 |
| Software | 軟件 | 軟體 |
| Program | 程序 | 程式 |
| Server | 服務器 | 伺服器 |
| Settings | 設置 / 設定 | 設定（偏好保留原有 zh_CN 詞） |

## 3. PO 文件編輯準則

- **`msgid` 絕對禁止變更**：`msgid` 是程序的源字符串查找鍵，修改任何字符都會導致原應用無法匹配翻譯。
- **格式化佔位符完整性**：`%s`、`%d`、`%1$s`、`{0}`、`\n` 等符號必須原樣保留。
- **單複數處理**：保留原本 `Plural-Forms: nplurals=1; plural=0;` 結構及 `msgstr[0]` 格式。
