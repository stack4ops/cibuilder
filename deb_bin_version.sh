#!/usr/bin/env bash
deb_bin_version() {
    local os="$1"
    local pkg="$2"
    local arch="${3:-amd64}"
    case "$os" in
        13) os="trixie" ;;
        12) os="bookworm" ;;
        11) os="bullseye" ;;
    esac

    local found_version=""
    for base in \
        "https://deb.debian.org/debian/dists/${os}/main/binary-${arch}/Packages" \
        "https://deb.debian.org/debian/dists/${os}/contrib/binary-${arch}/Packages" \
        "https://deb.debian.org/debian-security/dists/${os}-security/main/binary-${arch}/Packages"; do
        
        found_version=$(
            (
                curl -fsSL "${base}.xz" 2>/dev/null | xz -dc 2>/dev/null ||
                curl -fsSL "${base}.gz" 2>/dev/null | gzip -dc 2>/dev/null ||
                curl -fsSL "${base}" 2>/dev/null
            ) | awk -v pkg="$pkg" '
                $1 == "Package:" && $2 == pkg { found=1 }
                found && $1 == "Version:" { print $2; exit }
                /^$/ { found=0 }
            '
        )
        [ -n "$found_version" ] && break
    done

    echo "$found_version"
}
deb_bin_version "$@"