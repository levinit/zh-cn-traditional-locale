# Agent Harness - zh-cn-traditional-locale

本項目用於維護 Linux 中文 locale 變體 `zh_CN@traditional`（**繁體字形 + 大陸用語**）。

## 核心邊界與不可違背原則 (P0)

1. **嚴格保持大陸術語**：僅轉換字符字形爲繁體，絕對不轉爲臺灣用語（例如保持“文件”、“默認”、“硬盤”、“內存”，絕不替換爲“檔案”、“預設”、“硬碟”、“記憶體”）。
2. **msgid 絕對只讀**：在任何 `.po` 文件中，`msgid` 是程序查找鍵，絕對不能修改或翻譯；僅轉換 `msgstr`。
3. **轉換基底與工具**：優先使用 `bin/zh-cn-traditional-sync` 從系統 `zh_CN` 通過 OpenCC `s2t` 模式轉換，避免從 `zh_TW` 逆向消除方言詞。
4. **Locale 註冊與打包邊界**：必須先確保 `/usr/share/i18n/locales/zh_CN@traditional` 就位，再寫入 `/etc/locale.gen`（`zh_CN@traditional UTF-8`）並執行 `locale-gen` / `localedef`；打包構建階段（`DESTDIR` 非空時）嚴禁修改宿主機 `/etc/locale.gen`。

## 任務路由入口

具體任務執行請查閱路由入口：[.agents/README.md](.agents/README.md)。
