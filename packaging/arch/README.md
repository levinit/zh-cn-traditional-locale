# Arch Linux AUR 維護與發佈指南

本目錄包含發佈到 Arch User Repository (AUR) 所需的全部資產。包名爲 **`zh-cn-traditional-locale`**。

---

## 1. 目錄文件說明

* [`PKGBUILD`](PKGBUILD)：AUR 與本地統一構建腳本（由 `make arch` 或 `package.sh arch` 在本地調用時自動使用當前工作區，上傳至 AUR 時則從遠程 Git 克隆）。
* [`.SRCINFO`](.SRCINFO)：AUR 元數據文件（由 `makepkg --printsrcinfo` 生成，上傳 AUR 必須包含）。
* [`zh-cn-traditional.hook`](zh-cn-traditional.hook)：pacman 增量自動繁體化鉤子。
* [`zh-cn-traditional-locale.install`](zh-cn-traditional-locale.install)：pacman 安裝/升級後提示腳本，指導用戶配置環境變量。

---

## 2. PKGBUILD 核心寫法解析

```bash
pkgname=zh-cn-traditional-locale
pkgver=1.0.0
pkgrel=1
arch=('any')
url="https://github.com/levinit/zh-cn-traditional-locale"
license=('GPL-3.0-or-later')

# 運行依賴：OpenCC、Python 與 gettext
depends=('gettext' 'opencc' 'python')
makedepends=('git')
conflicts=("${pkgname}-git")
replaces=("${pkgname}-git")
backup=('etc/zh-cn-traditional/overrides.tsv')
install="${pkgname}.install"

# 自動判定：當處於本地源碼倉庫（且非生成 AUR .SRCINFO 元數據階段）時，直接使用當前工作區構建；否則從遠程 Git 克隆
if [ "${PRINTSRCINFO:-0}" != "1" ] && { [ "${LOCAL_BUILD:-0}" = "1" ] || [ -f "${startdir}/../../bin/zh-cn-traditional-sync" ]; }; then
    _is_local=1
    source=()
    sha256sums=()
else
    _is_local=0
    source=("${pkgname}::git+https://github.com/levinit/zh-cn-traditional-locale.git")
    sha256sums=('SKIP')
fi

# 動態版本號函數（優先從 Git tag 提取，如 1.0.0.r0.g...；無 tag 則以 ${pkgver} 為前綴回退）
pkgver() {
    if [ "${_is_local}" = "1" ]; then
        cd "${startdir}/../.."
    else
        cd "${pkgname}"
    fi
    ( set -o pipefail
      git describe --long --tags --abbrev=7 2>/dev/null | sed 's/^v//;s/\([^-]*-g\)/r\1/;s/-/./g' ||
      printf "%s.r%s.%s" "${pkgver%%.r*}" "$(git rev-list --count HEAD)" "$(git rev-parse --short=7 HEAD)"
    )
}

build() {
    if [ "${_is_local}" = "1" ]; then
        make -C "${startdir}/../.." build
    else
        make -C "${pkgname}" build
    fi
}

package() {
    if [ "${_is_local}" = "1" ]; then
        make -C "${startdir}/../.." install DESTDIR="${pkgdir}" PREFIX=/usr HOOK_ALPM=yes
    else
        make -C "${pkgname}" install DESTDIR="${pkgdir}" PREFIX=/usr HOOK_ALPM=yes
    fi
}
```

---

## 3. AUR 發佈與更新流程

### 首次發佈
1. 在 [AUR](https://aur.archlinux.org/) 註冊賬號並上傳 SSH 公鑰。
2. 克隆空的 AUR 遠程倉庫：
   ```bash
   git clone ssh://aur@aur.archlinux.org/zh-cn-traditional-locale.git /tmp/aur-pkg
   ```
3. 將本目錄的 `PKGBUILD`、`.SRCINFO`、`*.install` 複製過去：
   ```bash
   cp PKGBUILD .SRCINFO *.install /tmp/aur-pkg/
   cd /tmp/aur-pkg
   git add PKGBUILD .SRCINFO *.install
   git commit -m "Initial import for zh-cn-traditional-locale"
   git push origin master
   ```

### 日常版本更新
當主倉庫有重要調整或修改了 PKGBUILD 時：
```bash
# 重新生成 .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# 提交到 AUR
git add PKGBUILD .SRCINFO *.install
git commit -m "Update PKGBUILD"
git push origin master
```
