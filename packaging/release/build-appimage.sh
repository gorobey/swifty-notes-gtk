#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: build-appimage.sh --install-root ROOT --output OUTPUT_DIR [--version VERSION]
EOF
}

version=""
install_root=""
output_dir=""
package_name="swifty-notes-gtk"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --version)
            version="$2"
            shift 2
            ;;
        --install-root)
            install_root="$2"
            shift 2
            ;;
        --output)
            output_dir="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [ -z "$install_root" ] || [ -z "$output_dir" ]; then
    usage >&2
    exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
source "${script_dir}/version.sh"
version="$(resolve_release_version "$version")"

if [ ! -d "$install_root/usr" ]; then
    echo "Expected /usr install tree under ${install_root}" >&2
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "AppImage build is currently supported only on x86_64." >&2
    exit 1
fi

mkdir -p "$output_dir"
work_dir="$(mktemp -d)"
tools_dir="${work_dir}/tools"
appdir="${work_dir}/AppDir"
cleanup() {
    rm -rf "$work_dir"
}
trap cleanup EXIT

mkdir -p "$tools_dir" "$appdir/usr"
cp -a "${install_root}/usr/." "${appdir}/usr/"

desktop_file="${appdir}/usr/share/applications/me.spaceinbox.swiftynotes.desktop"
icon_file="${appdir}/usr/share/icons/hicolor/scalable/apps/me.spaceinbox.swiftynotes.svg"
main_binary="${appdir}/usr/libexec/swifty-notes/swiftynotes"
wrapper_binary="${appdir}/usr/bin/swiftynotes"

if [ ! -f "$desktop_file" ] || [ ! -f "$icon_file" ] || [ ! -x "$main_binary" ] || [ ! -x "$wrapper_binary" ]; then
    echo "Install root is missing required desktop/icon/binary files." >&2
    exit 1
fi

linuxdeploy_appimage="${tools_dir}/linuxdeploy-x86_64.AppImage"
appimagetool_appimage="${tools_dir}/appimagetool-x86_64.AppImage"

curl -fsSL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage" -o "$linuxdeploy_appimage"
curl -fsSL "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage" -o "$appimagetool_appimage"
chmod 755 "$linuxdeploy_appimage" "$appimagetool_appimage"

APPIMAGE_EXTRACT_AND_RUN=1 \
ARCH=x86_64 \
"$linuxdeploy_appimage" \
    --appdir "$appdir" \
    --desktop-file "$desktop_file" \
    --icon-file "$icon_file" \
    --executable "$main_binary" \
    --executable "$wrapper_binary"

output_path="${output_dir}/${package_name}-${version}-x86_64.AppImage"
APPIMAGE_EXTRACT_AND_RUN=1 \
ARCH=x86_64 \
"$appimagetool_appimage" \
    "$appdir" \
    "$output_path"
