PREFIX ?= /usr
DESTDIR ?=
SYSCONFDIR ?= /etc
BIN_DIR ?= $(PREFIX)/bin
I18N_DIR ?= $(PREFIX)/share/i18n/locales
LOCALE_DIR ?= $(PREFIX)/share/locale/zh_CN@traditional
ALPM_HOOKS_DIR ?= $(PREFIX)/share/libalpm/hooks
CONFIG_DIR ?= $(SYSCONFDIR)/zh-cn-traditional

.PHONY: all build sync desktop clean-desktop verify install uninstall clean pkg arch deb rpm packages

all: build

build:
	@echo "zh-cn-traditional-locale: 核心引擎就緒 (動態生成模式)。"

sync:
	@./bin/zh-cn-traditional-sync --all

desktop:
	@./bin/zh-cn-traditional-sync --desktop

clean-desktop:
	@./bin/zh-cn-traditional-sync --clean-desktop

verify:
	@./scripts/verify.sh

install:
	install -d -m 755 "$(DESTDIR)$(I18N_DIR)"
	install -m 644 i18n/locales/zh_CN@traditional "$(DESTDIR)$(I18N_DIR)/zh_CN@traditional"
	install -d -m 755 "$(DESTDIR)$(BIN_DIR)"
	install -m 755 bin/zh-cn-traditional-sync "$(DESTDIR)$(BIN_DIR)/zh-cn-traditional-sync"
	install -d -m 755 "$(DESTDIR)$(CONFIG_DIR)"
	install -m 644 config/overrides.tsv "$(DESTDIR)$(CONFIG_DIR)/overrides.tsv"
	@if [ "$(HOOK_ALPM)" = "yes" ] || { [ -z "$(HOOK_ALPM)" ] && [ -d /usr/share/libalpm/hooks ] && [ ! -d "$(DESTDIR)/usr/src" ]; }; then \
		install -d -m 755 "$(DESTDIR)$(ALPM_HOOKS_DIR)"; \
		install -m 644 packaging/arch/zh-cn-traditional.hook "$(DESTDIR)$(ALPM_HOOKS_DIR)/zh-cn-traditional.hook"; \
	fi
	@if [ -z "$(DESTDIR)" ]; then \
		needs_gen=0; \
		if [ -f /etc/locale.gen ]; then \
			if grep -qE '^[[:space:]]*#[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then \
				sed -i 's/^[[:space:]]*#[[:space:]]*\(zh_CN@traditional[[:space:]]\+UTF-8\)/\1/' /etc/locale.gen; \
				needs_gen=1; \
			elif ! grep -qE '^[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then \
				echo "zh_CN@traditional UTF-8" >> /etc/locale.gen; \
				needs_gen=1; \
			fi; \
		fi; \
		if ! locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$$'; then \
			needs_gen=1; \
		fi; \
		if [ "$$needs_gen" -eq 1 ]; then \
			echo "=== 正在註冊並生成 zh_CN@traditional locale ==="; \
			if command -v locale-gen >/dev/null 2>&1; then \
				locale-gen; \
			elif command -v localedef >/dev/null 2>&1; then \
				localedef -i zh_CN@traditional -c -f UTF-8 zh_CN@traditional || true; \
			fi; \
		fi; \
		echo "=== 正在全量同步系統現有 zh_CN 翻譯至 zh_CN@traditional ==="; \
		"$(DESTDIR)$(BIN_DIR)/zh-cn-traditional-sync" --all --no-desktop || true; \
		printf '\n========================================================================\n[zh_CN@traditional] 已成功安裝並完成 locale 生成！\n\n1. 啓用繁體字形 + 大陸術語（在 ~/.profile 或 ~/.bashrc 中配置）：\n     export LANG=zh_CN@traditional\n     export LANGUAGE=zh_CN@traditional\n\n2. 平常維護與手動同步：\n   - 系統已內置自動鉤子，安裝/更新軟件時會自動同步；\n   - 如需手動觸發全量重新同步或單獨轉換指定軟件，可隨時運行：\n     zh-cn-traditional-sync --all          # 全量同步系統所有組件\n     zh-cn-traditional-sync <組件名>...     # 例如: zh-cn-traditional-sync git baobab\n\n桌面快捷方式：安裝不自動同步，如需請以普通用戶身份運行 zh-cn-traditional-sync --desktop -y。\n注：未覆蓋的軟件翻譯將自動安全回退到簡體 zh_CN。\n========================================================================\n'; \
	fi

uninstall:
	rm -f "$(DESTDIR)$(I18N_DIR)/zh_CN@traditional"
	rm -f "$(DESTDIR)$(BIN_DIR)/zh-cn-traditional-sync"
	@if [ -f "$(DESTDIR)$(CONFIG_DIR)/overrides.tsv" ] && grep -qE '^[[:space:]]*[^[:space:]#]' "$(DESTDIR)$(CONFIG_DIR)/overrides.tsv"; then \
		echo "保留用戶自定義詞表：$(DESTDIR)$(CONFIG_DIR)/overrides.tsv（未刪除）"; \
		find "$(DESTDIR)$(CONFIG_DIR)" -mindepth 1 ! -name overrides.tsv -delete 2>/dev/null || true; \
	else \
		rm -rf "$(DESTDIR)$(CONFIG_DIR)"; \
	fi
	rm -f "$(DESTDIR)$(ALPM_HOOKS_DIR)/zh-cn-traditional.hook"
	rm -rf "$(DESTDIR)$(LOCALE_DIR)"
	@if [ -z "$(DESTDIR)" ]; then \
		echo "=== 正在從系統移除 zh_CN@traditional locale ==="; \
		needs_gen=0; \
		if [ -f /etc/locale.gen ]; then \
			if grep -qE '^[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then \
				sed -i '/^[[:space:]]*zh_CN@traditional[[:space:]]\+UTF-8/d' /etc/locale.gen; \
				needs_gen=1; \
			fi; \
		fi; \
		if locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$$'; then \
			if command -v localedef >/dev/null 2>&1; then \
				localedef --delete-from-archive zh_CN@traditional zh_CN.utf8@traditional 2>/dev/null || true; \
			fi; \
			if locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$$'; then \
				needs_gen=1; \
			else \
				needs_gen=0; \
			fi; \
		fi; \
		if [ "$$needs_gen" -eq 1 ] && command -v locale-gen >/dev/null 2>&1; then \
			locale-gen; \
		fi; \
	fi

clean:
	rm -rf pkg/ src/ *.pkg.tar.* dist/ *.deb *.rpm \
	       packaging/arch/pkg/ packaging/arch/src/ packaging/arch/*.pkg.tar.* \
	       packaging/pacman/pkg/ packaging/pacman/src/ packaging/pacman/*.pkg.tar.*

# 自動檢測當前系統發行版/包管理器並打包
pkg:
	@./packaging/package.sh auto

# 手動指定目標格式打包
arch:
	@./packaging/package.sh arch

deb:
	@./packaging/package.sh deb

rpm:
	@./packaging/package.sh rpm

packages:
	@./packaging/package.sh all
