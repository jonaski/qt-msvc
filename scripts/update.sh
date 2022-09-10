#!/bin/bash
#
#  STRAWBERRY MSVC GITHUB ACTION UPDATE SCRIPT
#  Copyright (C) 2022 Jonas Kvinge
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

repo="jonaski/qt-msvc"
repodir="${HOME}/Projects/qt-msvc"
ci_file=".github/workflows/build.yml"

function timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
function error() { echo "[$(timestamp)] ERROR: $*" >&2; }

function update_package() {

  local package_name
  local package_version_current
  local package_version_latest

  package_name="${1}"
  package_version_current=$(cat "${ci_file}" | sed -n "s,^  ${package_name}_version: \(.*\)\$,\1,p" | tr -d "\'")

  if [ "${package_version_current}" = "" ]; then
    echo "Could not get current version for ${package}."
    return
  fi

  case ${package_name} in
    "nasm")
      package_version_latest=$(wget -q -O- 'https://www.nasm.us/pub/nasm/releasebuilds/?C=M;O=D' | sed -n 's,.*href="\([0-9\.]*[^a-z]\)/".*,\1,p' | head -1)
      ;;
    "yasm")
      package_version_latest=$(wget -q -O- 'https://github.com/yasm/yasm/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | sed 's/^v//g' | sort -V | head -1)
      ;;
    "boost")
      package_version_latest=$(wget -q -O- 'https://www.boost.org/users/download/' | sed -n 's,.*/release/\([0-9][^"/]*\)/.*,\1,p' | grep -v beta | head -1)
      ;;
    "pkgconf")
      package_version_latest=$(wget -q -O- 'https://github.com/pkgconf/pkgconf/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | sed 's/^pkgconf\-//g' | sort -V | head -1)
      ;;
    "zlib")
      package_version_latest=$(wget -q -O- 'https://zlib.net/' | sed -n 's,.*zlib-\([0-9][^>]*\)\.tar.*,\1,ip' | head -1)
      ;;
    "openssl")
      package_version_latest=$(wget -q -O- 'https://www.openssl.org/source/' | sed -n 's,.*openssl-\([0-9][0-9a-z.]*\)\.tar.*,\1,p' | sort -V | tail -1)
      ;;
    "libpng")
      package_version_latest=$(wget -q -O- 'https://sourceforge.net/p/libpng/code/ref/master/tags/' | sed -n 's,.*<a[^>]*>v\([0-9][^<]*\)<.*,\1,p' | grep -v alpha | grep -v beta | grep -v rc | sort -V | tail -1)
      ;;
    "pcre2")
      package_version_latest=$(wget -q -O- 'https://github.com/PhilipHazel/pcre2/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^pcre2\-//g' | sort -V | head -1)
      ;;
    "bzip2")
      package_version_latest=$(wget -q -O- 'https://sourceware.org/pub/bzip2/' | grep 'bzip2-' | sed -n 's,.*bzip2-\([0-9][^>]*\)\.tar.*,\1,p' | sort -V | tail -1)
      ;;
    "xz")
      package_version_latest=$(wget -q -O- 'https://tukaani.org/xz/' | sed -n 's,.*xz-\([0-9][^>]*\)\.tar.*,\1,p' | head -1)
      ;;
    "brotli")
      package_version_latest=$(wget -q -O- 'https://github.com/google/brotli/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    "sqlite3")
      package_version_latest=$(wget -q -O- 'https://www.sqlite.org/download.html' | sed -n 's,.*sqlite-autoconf-\([0-9][^>]*\)\.tar.*,\1,p' | head -1)
      ;;
    "glib")
      package_version_latest=$(wget -q -O- 'https://github.com/gnome/glib/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | grep -v '\([0-9]\+\.\)\{2\}9[0-9]' | sort -Vr | head -1)
      ;;
    "icu4c")
      package_version_latest=$(wget -q -O- 'https://github.com/unicode-org/icu/releases/latest' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/release\-//g' | tr '\-' '\.' | sort -Vr | head -1)
      ;;
    "expat")
      package_version_latest=$(wget -q -O- 'https://sourceforge.net/projects/expat/files/expat/' | sed -n 's,.*/projects/.*/\([0-9][^"]*\)/".*,\1,p' | head -1)
      ;;
    "freetype")
      package_version_latest=$(wget -q -O- 'https://sourceforge.net/projects/freetype/files/freetype2/' | sed -n 's,.*/projects/.*/\([0-9][^"]*\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "harfbuzz")
      package_version_latest=$(wget -q -O- 'https://github.com/harfbuzz/harfbuzz/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^v//g' | sort -V | head -1)
      ;;
    "qt")
      qt_major_version=$(wget -q -O- "https://download.qt.io/official_releases/qt/" | sed -n 's,.*<a href=\"\([0-9]*\.[0-9]*\).*,\1,p' | sort -V | tail -1)
      package_version_latest=$(wget -q -O- "https://download.qt.io/official_releases/qt/${qt_major_version}/" | sed -n 's,.*href="\([0-9]*\.[0-9]*\.[^/]*\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "quazip")
      package_version_latest=$(wget -q -O- 'https://github.com/stachenov/quazip/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    *)
      package_version_latest=
      echo "No update rule for package: ${package}"
      return
      ;;
  esac

  if [ "${package_version_latest}" = "" ]; then
    echo "Could not get latest version for ${package}."
    return
  fi

  package_version_highest=$(echo "${package_version_current} ${package_version_latest}" | tr ' ' '\n' | sort -V | tail -1)

  if [ "${package_version_highest}" = "" ]; then
    echo "Could not get highest version for ${package}."
    return
  fi

  if [ "${package_version_highest}" = "${package_version_current}" ]; then
    echo "${package_name}: ${package_version_current} is the latest"
  else
    branch="${package_name}_$(echo ${package_version_latest} | sed 's/\./_/g')"
    git branch | grep "${branch}" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      echo "${package_name}: updating from ${package_version_current} to ${package_version_latest}..."
      git checkout -b "${branch}" || exit 1
      sed -i "s,^  ${package_name}_version: .*,  ${package_name}_version: '${package_version_latest}',g" .github/workflows/build.yml || exit 1
      git commit -m "Update ${package_name}" .github/workflows/build.yml || exit 1
      git add .github/workflows/build.yml || exit 1
      git push origin "${branch}" || exit 1
      gh pr create --repo "${repo}" --head "${branch}" --base "master" --title "Update ${package_name} to ${package_version_latest}" --body "Update ${package_name} from ${package_version_current} to ${package_version_latest}" || exit 1
      git checkout . >/dev/null 2>&1 || exit 1
      if ! [ "$(git branch | head -1 | cut -d ' ' -f2)" = "master" ]; then
        git checkout master >/dev/null 2>&1 || exit 1
      fi
    fi
  fi

}

cmds="cat cut sort tr grep sed wget curl git gh"
cmds_missing=
for cmd in ${cmds}; do
  which "${cmd}" >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    continue
  fi
  if [ "${cmds_missing}" = "" ]; then
    cmds_missing="${cmd}"
  else
    cmds_missing="${cmds_missing}, ${cmd}"
  fi
done

if ! [ "${cmds_missing}" = "" ]; then
  error "Missing ${cmds_missing} commands."
  exit 1
fi

if ! [ -d "${repodir}" ]; then
  echo "Missing ${repodir}"
  exit 1
fi

cd "${repodir}" || exit 1

gh auth status >/dev/null || exit 1
if [ $? -ne 0 ]; then
  error "Missing GitHub login."
  exit 1
fi

git fetch >/dev/null 2>&1 || exit 1
git checkout . >/dev/null 2>&1 || exit 1

if ! [ "$(git branch | head -1 | cut -d ' ' -f2)" = "master" ]; then
  git checkout master >/dev/null 2>&1 || exit 1
fi

git pull origin master --rebase >/dev/null || exit 1

packages=$(cat "${ci_file}" | sed -n "s,^  \(.*\)_version: .*$,\1,p" | tr '\n' ' ')

for package in ${packages}; do
  update_package "${package}"
  git checkout . >/dev/null 2>&1 || exit 1
  if ! [ "$(git branch | head -1 | cut -d ' ' -f2)" = "master" ]; then
    git checkout master >/dev/null 2>&1 || exit 1
  fi
  git pull origin master --rebase >/dev/null 2>&1 || exit 1
done
