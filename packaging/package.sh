#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"

mkdir -p "${DIST_DIR}"

# 1. 檢測當前操作系統與包管理器
detect_target() {
    # 優先檢查 /etc/os-release 的 ID 與 ID_LIKE
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        case "${ID:-}" in
            arch|manjaro|endeavouros|artix)
                echo "arch"
                return
                ;;
            debian|ubuntu|linuxmint|pop|kali|deepin)
                echo "deb"
                return
                ;;
            fedora|rhel|centos|rocky|alma|ol|opensuse*|suse)
                echo "rpm"
                return
                ;;
        esac

        for like in ${ID_LIKE:-}; do
            case "$like" in
                arch)
                    echo "arch"
                    return
                    ;;
                debian|ubuntu)
                    echo "deb"
                    return
                    ;;
                fedora|rhel|suse)
                    echo "rpm"
                    return
                    ;;
            esac
        done
    fi

    # 兜底檢測常用包管理器命令
    if command -v pacman &>/dev/null && command -v makepkg &>/dev/null; then
        echo "arch"
    elif command -v dpkg-deb &>/dev/null || command -v apt-get &>/dev/null; then
        echo "deb"
    elif command -v rpmbuild &>/dev/null || command -v dnf &>/dev/null; then
        echo "rpm"
    else
        echo "unknown"
    fi
}

build_arch() {
    echo "=== 正在構建 Arch Linux 軟件包 (pacman) ==="
    if ! command -v makepkg &>/dev/null; then
        echo "錯誤: 未找到 makepkg 命令。" >&2
        exit 1
    fi
    (
        cd "${SCRIPT_DIR}/arch"
        LOCAL_BUILD=1 PKGDEST="${DIST_DIR}" makepkg -f
    )
    echo "=== Arch Linux (pacman) 構建完成！產物位於: ==="
    ls -lh "${DIST_DIR}"/*.pkg.tar.* 2>/dev/null || true
}

build_deb() {
    echo "=== 正在構建 DEB 軟件包 (Debian / Ubuntu / Mint) ==="
    PKG_DIR="${DIST_DIR}/debbuild/pkg"
    DEB_NAME="zh-cn-traditional-locale_1.0.0-1_all.deb"
    OUTPUT_DEB="${DIST_DIR}/${DEB_NAME}"

    rm -rf "${PKG_DIR}"
    mkdir -p "${PKG_DIR}" "${DIST_DIR}"

    make -C "${REPO_ROOT}" install DESTDIR="${PKG_DIR}" PREFIX=/usr HOOK_ALPM=no

    mkdir -p "${PKG_DIR}/DEBIAN"
    echo "/etc/zh-cn-traditional/overrides.tsv" > "${PKG_DIR}/DEBIAN/conffiles"
    chmod 644 "${PKG_DIR}/DEBIAN/conffiles"

    cat > "${PKG_DIR}/DEBIAN/control" << 'EOF'
Package: zh-cn-traditional-locale
Version: 1.0.0-1
Section: localization
Priority: optional
Architecture: all
Depends: gettext, opencc, python3, python3-opencc
Maintainer: levinit <levinit@outlook.com>
Homepage: https://github.com/levinit/zh-cn-traditional-locale
Description: Linux locale variant zh_CN@traditional
 A Linux Chinese locale variant (zh_CN@traditional) providing
 Traditional Chinese glyphs while maintaining Mainland China terminology
 and conventions, with dynamic sync engine and triggers.
EOF

    if [[ -f "${SCRIPT_DIR}/debian/triggers" ]]; then
        install -m 644 "${SCRIPT_DIR}/debian/triggers" "${PKG_DIR}/DEBIAN/triggers"
    fi
    if [[ -f "${SCRIPT_DIR}/debian/postinst" ]]; then
        install -m 755 "${SCRIPT_DIR}/debian/postinst" "${PKG_DIR}/DEBIAN/postinst"
    fi
    if [[ -f "${SCRIPT_DIR}/debian/postrm" ]]; then
        install -m 755 "${SCRIPT_DIR}/debian/postrm" "${PKG_DIR}/DEBIAN/postrm"
    fi

    if command -v dpkg-deb &>/dev/null; then
        echo "使用系統 dpkg-deb 打包..."
        dpkg-deb --build --root-owner-group "${PKG_DIR}" "${OUTPUT_DEB}"
    else
        echo "未檢測到 dpkg-deb，使用 ar + tar 構建標準 Debian 格式包..."
        TMP_DIR="$(mktemp -d)"
        trap 'rm -rf "${TMP_DIR}"' EXIT

        echo "2.0" > "${TMP_DIR}/debian-binary"
        (cd "${PKG_DIR}/DEBIAN" && tar --numeric-owner --owner=0 --group=0 -czf "${TMP_DIR}/control.tar.gz" ./*)
        (cd "${PKG_DIR}" && tar --numeric-owner --owner=0 --group=0 --exclude="./DEBIAN" -czf "${TMP_DIR}/data.tar.gz" ./*)
        (cd "${TMP_DIR}" && ar -rc "${OUTPUT_DEB}" debian-binary control.tar.gz data.tar.gz)
        rm -rf "${TMP_DIR}"
        trap - EXIT
    fi

    echo "=== DEB 構建完成！產物位於: ==="
    ls -lh "${OUTPUT_DEB}"
}

build_rpm() {
    echo "=== 正在構建 RPM 軟件包 (Fedora / RHEL / openSUSE) ==="
    if ! command -v rpmbuild &>/dev/null; then
        echo "錯誤: 未找到 rpmbuild 命令。" >&2
        exit 1
    fi
    RPM_TOPDIR="${DIST_DIR}/rpmbuild"
    mkdir -p "${RPM_TOPDIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS} "${DIST_DIR}"

    rpmbuild -bb \
        --define "_topdir ${RPM_TOPDIR}" \
        --define "_sourcedir ${REPO_ROOT}" \
        --define "_builddir ${RPM_TOPDIR}/BUILD" \
        --define "_rpmdir ${DIST_DIR}" \
        "${SCRIPT_DIR}/rpm/zh-cn-traditional-locale.spec"

    echo "=== RPM 構建完成！產物位於: ==="
    ls -lh "${DIST_DIR}"/*/*.rpm 2>/dev/null || ls -lh "${DIST_DIR}"/*.rpm 2>/dev/null || true
}

TARGET="${1:-auto}"

case "$TARGET" in
    auto)
        DETECTED="$(detect_target)"
        if [[ "$DETECTED" == "unknown" ]]; then
            echo "未能識別當前系統的包管理器，請手動指定目標: $0 [arch|deb|rpm|all]" >&2
            exit 1
        fi
        echo "檢測到當前系統發行版體系: ${DETECTED}"
        case "$DETECTED" in
            arch) build_arch ;;
            deb) build_deb ;;
            rpm) build_rpm ;;
        esac
        ;;
    arch|pacman)
        build_arch
        ;;
    deb|debian|ubuntu)
        build_deb
        ;;
    rpm|fedora|rhel|suse|opensuse)
        build_rpm
        ;;
    all)
        echo "=== 正在構建所有可用發行版軟件包 ==="
        build_arch
        build_deb
        build_rpm
        ;;
    -h|--help|help)
        echo "用法: $0 [目標類型]"
        echo "可選目標:"
        echo "  auto (默認)  自動檢測當前系統發行版並構建對應軟件包"
        echo "  arch / pacman 構建 Arch Linux (.pkg.tar.zst)"
        echo "  deb          構建 Debian / Ubuntu (.deb)"
        echo "  rpm          構建 Fedora / RHEL / openSUSE (.rpm)"
        echo "  all          構建所有主流格式"
        ;;
    *)
        echo "未知目標類型: ${TARGET}" >&2
        echo "運行 '$0 --help' 查看可用選項。" >&2
        exit 1
        ;;
esac
