Name:           zh-cn-traditional-locale
Version:        1.0.0
Release:        1%{?dist}
Summary:        Linux locale variant zh_CN@traditional

License:        GPL-3.0-or-later
URL:            https://github.com/levinit/zh-cn-traditional-locale
Packager:       levinit <levinit@outlook.com>
BuildArch:      noarch

BuildRequires:  make
Requires:       gettext, opencc, python3
Recommends:     python3-opencc

%description
A Linux Chinese locale variant (zh_CN@traditional) providing
Traditional Chinese glyphs while maintaining Mainland China terminology
and conventions, with file triggers and dynamic conversion engine.

%prep
cp -f %{?_sourcedir}%{!?_sourcedir:../..}/LICENSE . 2>/dev/null || true

%build
make -C %{?_sourcedir}%{!?_sourcedir:../..} build

%install
rm -rf %{buildroot}
make -C %{?_sourcedir}%{!?_sourcedir:../..} install DESTDIR=%{buildroot} PREFIX=/usr HOOK_ALPM=no

%files
%license LICENSE
/usr/share/i18n/locales/zh_CN@traditional
/usr/bin/zh-cn-traditional-sync
%dir /etc/zh-cn-traditional
%config(noreplace) /etc/zh-cn-traditional/overrides.tsv

%post
needs_gen=0
if [ -f /etc/locale.gen ]; then
    if grep -qE '^[[:space:]]*#[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then
        sed -i 's/^[[:space:]]*#[[:space:]]*\(zh_CN@traditional[[:space:]]\+UTF-8\)/\1/' /etc/locale.gen
        needs_gen=1
    elif ! grep -qE '^[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then
        echo "zh_CN@traditional UTF-8" >> /etc/locale.gen
        needs_gen=1
    fi
fi

if ! locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$'; then
    needs_gen=1
fi

if [ "$needs_gen" -eq 1 ]; then
    if command -v locale-gen >/dev/null 2>&1; then
        locale-gen
    elif command -v localedef >/dev/null 2>&1; then
        localedef -i zh_CN@traditional -c -f UTF-8 zh_CN@traditional || true
    fi
fi

if command -v zh-cn-traditional-sync >/dev/null 2>&1; then
    echo "=== 正在全量同步系統現有 zh_CN 翻譯至 zh_CN@traditional ==="
    # 安裝只同步 MO，不同步桌面快捷方式：桌面是用戶級操作，
    # 應由用戶本人運行 --desktop，避免 root 家目錄問題。
    zh-cn-traditional-sync --all --quiet --no-desktop || true
fi

if [ $1 -eq 1 ]; then
    cat << 'EOF'
========================================================================
[zh_CN@traditional] 已成功安裝並完成 locale 生成！

1. 啓用繁體字形 + 大陸術語（在 ~/.profile 或 ~/.bashrc 中配置）：
     export LANG=zh_CN@traditional
     export LANGUAGE=zh_CN@traditional

2. 平常維護與手動同步：
   - 系統已內置 RPM 文件觸發器，安裝/更新軟件時會自動增量轉換；
   - 如需手動觸發全量重新同步或單獨轉換指定軟件，可隨時運行：
     zh-cn-traditional-sync --all          # 全量同步系統所有組件
     zh-cn-traditional-sync <組件名>...     # 例如: zh-cn-traditional-sync git baobab

注：未覆蓋的軟件翻譯將自動安全回退到簡體 zh_CN。
注：安裝不自動同步桌面快捷方式，如需請以普通用戶身份運行 zh-cn-traditional-sync --desktop -y。
========================================================================
EOF
fi

%filetriggerin -- /usr/share/locale/zh_CN/LC_MESSAGES
/usr/bin/zh-cn-traditional-sync --hook --quiet || true

%filetriggerpostun -- /usr/share/locale/zh_CN/LC_MESSAGES
/usr/bin/zh-cn-traditional-sync --hook --quiet || true

%postun
if [ $1 -eq 0 ]; then
    needs_gen=0
    if [ -f /etc/locale.gen ]; then
        if grep -qE '^[[:space:]]*zh_CN@traditional[[:space:]]+UTF-8' /etc/locale.gen; then
            sed -i '/^[[:space:]]*zh_CN@traditional[[:space:]]\+UTF-8/d' /etc/locale.gen
            needs_gen=1
        fi
    fi

    if locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$'; then
        if command -v localedef >/dev/null 2>&1; then
            localedef --delete-from-archive zh_CN@traditional zh_CN.utf8@traditional 2>/dev/null || true
        fi
        if locale -a 2>/dev/null | grep -qE '^zh_CN(\.utf8)?@traditional$'; then
            needs_gen=1
        else
            needs_gen=0
        fi
    fi

    if [ "$needs_gen" -eq 1 ] && command -v locale-gen >/dev/null 2>&1; then
        locale-gen
    fi
    rm -rf /usr/share/locale/zh_CN@traditional
fi

%changelog
* Mon Oct 26 2026 levinit <levinit@outlook.com> - 1.0.0-1
- Initial release of zh_CN@traditional locale variant
