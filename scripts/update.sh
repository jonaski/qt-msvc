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

ci_file=".github/workflows/build.yml"
curl_options="-s -f -L"

function timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
function status() { echo "[$(timestamp)] $*"; }
function error() { echo "[$(timestamp)] ERROR: $*" >&2; }

function update_repo() {

  git fetch >/dev/null 2>&1 || exit 1
  if [ $? -ne 0 ]; then
    error "Could not fetch"
    exit 1
  fi

  git checkout . >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    error "Could not checkout ."
    exit 1
  fi

  if ! [ "$(git branch | head -1 | cut -d ' ' -f2)" = "master" ]; then
    git checkout master >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      error "Could not checkout master branch."
      exit 1
    fi
  fi

  git pull origin master --rebase >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    error "Could not pull with rebase."
    exit 1
  fi

}

function merge_prs() {

  local prs
  local pr
  local review_decision
  local status_check_rollup
  local status_check_ok
  local status_check_total

  prs=$(gh pr list --json number | jq '.[].number')
  if [ "${prs}" = "" ]; then
    return
  fi

  for pr in ${prs}; do
    pr_author=$(gh pr view "${pr}" --json 'author' | jq -r '.author.login')
    if ! [ "${pr_author}" = "${gh_username}" ] && ! [ "${pr_author}" = "dependabot" ] && ! [ "${pr_author}" = "jonaski" ] ; then
      continue
    fi
    if ! [ "$(gh pr view "${pr}" --json 'isDraft' | jq '.isDraft')" = "false" ]; then
      continue
    fi
    if ! [ "$(gh pr view "${pr}" --json 'mergeable' | jq -r '.mergeable')" = "MERGEABLE" ]; then
      continue
    fi
    if ! [ "$(gh pr view "${pr}" --json 'mergeStateStatus' | jq -r '.mergeStateStatus')" = "CLEAN" ]; then
      continue
    fi
    review_decision=$(gh pr view "${pr}" --json 'reviewDecision' | jq -r '.reviewDecision')
    if [ ! "${review_decision}" = "" ] && [ ! "${review_decision}" = "APPROVED" ] ; then
      continue
    fi
    status_check_rollup=$(gh pr view "${pr}" --json 'statusCheckRollup')
    status_check_ok="1"
    status_check_total=$(echo "${status_check_rollup}" | jq '.statusCheckRollup | length')
    for ((i = 0; i < status_check_total; i++)); do
      status_check=$(echo "${status_check_rollup}" | jq -r ".statusCheckRollup[${i}].status")
      if ! [ "${status_check}" = "COMPLETED" ]; then
        status_check_ok=0
        break
      fi
    done
    if ! [ "${status_check_ok}" = "1" ]; then
      continue
    fi
    status "Merging pull request ${pr}."
    gh pr merge -dr "${pr}"
  done

}

function update_packages() {

  packages=$(cat "${ci_file}" | sed -n "s,^  \(.*\)_version: .*$,\1,p" | tr '\n' ' ')
  for package in ${packages}; do
    update_package "${package}"
    update_repo
  done

}

function update_package() {

  local package_name
  local package_version_current
  local package_version_latest

  package_name="${1}"
  package_version_current=$(cat "${ci_file}" | sed -n "s,^  ${package_name}_version: \(.*\)\$,\1,p" | tr -d "\'")

  if [ "${package_version_current}" = "" ]; then
    error "Could not get current version for ${package}."
    return
  fi

  case ${package_name} in
    "nasm")
      package_version_latest=$(curl ${curl_options} 'https://www.nasm.us/pub/nasm/releasebuilds/?C=M;O=D' | sed -n 's,.*href="\([0-9\.]*[^a-z]\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "yasm")
      package_version_latest=$(curl ${curl_options} 'https://github.com/yasm/yasm/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    "boost")
      package_version_latest=$(curl ${curl_options} 'https://www.boost.org/users/download/' | sed -n 's,.*/release/\([0-9][^"/]*\)/.*,\1,p' | grep -v beta | sort -V | tail -1)
      ;;
    "pkgconf")
      package_version_latest=$(curl ${curl_options} 'https://github.com/pkgconf/pkgconf/tags' | sed -n 's#.*releases/tag/\([^"]*\).*#\1#p' | sed 's/^pkgconf\-//g' | sort -V | tail -1)
      ;;
    "zlib")
      package_version_latest=$(curl ${curl_options} 'https://zlib.net/' | sed -n 's,.*zlib-\([0-9][^>]*\)\.tar.*,\1,ip' | sort -V | tail -1)
      ;;
    "openssl")
      package_version_latest=$(curl ${curl_options} 'https://www.openssl.org/source/' | sed -n 's,.*openssl-\([0-9][0-9a-z.]*\)\.tar.*,\1,p' | sort -V | tail -1)
      ;;
    "libpng")
      package_version_latest=$(curl ${curl_options} 'https://sourceforge.net/p/libpng/code/ref/master/tags/' | sed -n 's,.*<a[^>]*>v\([0-9][^<]*\)<.*,\1,p' | grep -v alpha | grep -v beta | grep -v rc | sort -V | tail -1)
      ;;
    "libjpeg_turbo")
      package_version_latest=$(curl ${curl_options} 'https://sourceforge.net/projects/libjpeg-turbo/files/' | sed -n 's,.*/projects/.*/\([0-9][^"%]*\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "pcre2")
      package_version_latest=$(curl ${curl_options} 'https://github.com/PhilipHazel/pcre2/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^pcre2\-//g' | grep -iv rc | sort -V | tail -1)
      ;;
    "bzip2")
      package_version_latest=$(curl ${curl_options} 'https://sourceware.org/pub/bzip2/' | grep 'bzip2-' | sed -n 's,.*bzip2-\([0-9][^>]*\)\.tar.*,\1,p' | sort -V | tail -1)
      ;;
    "xz")
      package_version_latest=$(curl ${curl_options} 'https://github.com/tukaani-project/xz/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/v//g' | sort -V | tail -1)
      ;;
    "brotli")
      package_version_latest=$(curl ${curl_options} 'https://github.com/google/brotli/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    "sqlite3")
      package_version_latest=$(curl ${curl_options} 'https://www.sqlite.org/download.html' | sed -n 's,.*sqlite-autoconf-\([0-9][^>]*\)\.tar.*,\1,p' | sort -V | tail -1)
      ;;
    "glib")
      package_version_latest=$(curl ${curl_options} 'https://gitlab.gnome.org/GNOME/glib/tags' | sed -n "s,.*<a [^>]\+>v\?\([0-9]\+\.[0-9.]\+\)<.*,\1,p" | sort -V | tail -1)
      ;;
    "icu4c")
      package_version_latest=$(curl ${curl_options} 'https://github.com/unicode-org/icu/releases/latest' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/release\-//g' | tr '\-' '\.' | grep -v '^\*name$' | sort -V | tail -1)
      ;;
    "expat")
      package_version_latest=$(curl ${curl_options} 'https://github.com/libexpat/libexpat/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | grep -v '^\*name$' | sed 's/R_//g' | tr '_' '.' | sort -V | tail -1)
      ;;
    "freetype")
      package_version_latest=$(curl ${curl_options} 'https://sourceforge.net/projects/freetype/files/freetype2/' | sed -n 's,.*/projects/.*/\([0-9][^"]*\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "harfbuzz")
      package_version_latest=$(curl ${curl_options} 'https://github.com/harfbuzz/harfbuzz/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    "qt")
      qt_major_version=$(curl ${curl_options} "https://download.qt.io/official_releases/qt/" | sed -n 's,.*<a href=\"\([0-9]*\.[0-9]*\).*,\1,p' | sort -V | tail -1)
      package_version_latest=$(curl ${curl_options} "https://download.qt.io/official_releases/qt/${qt_major_version}/" | sed -n 's,.*href="\([0-9]*\.[0-9]*\.[^/]*\)/".*,\1,p' | sort -V | tail -1)
      ;;
    "quazip")
      package_version_latest=$(curl ${curl_options} 'https://github.com/stachenov/quazip/releases' | sed -n 's,.*releases/tag/\([^"&;]*\)".*,\1,p' | sed 's/^v//g' | sort -V | tail -1)
      ;;
    "win_flex_bison")
      package_version_latest=$(curl ${curl_options} 'https://sourceforge.net/projects/winflexbison/files/' | sed -n 's,.*<a href=".*files\/win_flex_bison-\(.*\)\.zip\/.*,\1,p' | grep -v 'latest' | sort -V | tail -1)
      ;;
    "mariadbclient")
      package_version_latest=$(curl ${curl_options} 'https://archive.mariadb.org/' | sed -n 's,.*connector-c-\([0-9\.]\+\).*,\1,p' | sort -V | tail -1)
      ;;
    "file")
      package_version_latest=$(curl ${curl_options} 'https://astron.com/pub/file/' | grep 'file-' | sed -n 's,.*file-\([0-9][^>]*\)\.tar.*,\1,p' | tail -1)
      ;;
    *)
      package_version_latest=
      error "No update rule for package: ${package}"
      return
      ;;
  esac

  if [ "${package_version_latest}" = "" ]; then
    error "Could not get latest version for ${package}."
    return
  fi

  package_version_highest=$(echo "${package_version_current} ${package_version_latest}" | tr ' ' '\n' | sort -V | tail -1)

  if [ "${package_version_highest}" = "" ]; then
    error "Could not get highest version for ${package}."
    return
  fi

  if [ "${package_version_highest}" = "${package_version_current}" ]; then
    status "${package_name}: ${package_version_current} is the latest"
  else
    branch="${package_name}_$(echo ${package_version_latest} | sed 's/\./_/g')"
    git branch | tr -d '[:blank:]' | grep "^${branch}\$" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
      status "${package_name}: updating from ${package_version_current} to ${package_version_latest}..."
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

cmds="dirname cat head tail cut sort tr grep sed curl jq git gh"
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

dir="$(dirname "$0")"

if [ "${dir}" = "" ]; then
  error "Could not get current directory."
  exit 1
fi

if ! [ -d "${dir}" ]; then
  error "Missing ${dir}"
  exit 1
fi

if ! [ -d "${dir}/../.git" ]; then
  error "Missing ${dir}/../.git"
  exit 1
fi

repodir="$(dirname "${dir}")"

if ! [ -d "${repodir}" ]; then
  error "Missing ${repodir}."
  exit 1
fi

cd "${repodir}"
if [ $? -ne 0 ]; then
  error "Could not change directory to ${repodir}."
  exit 1
fi

repo=$(git config --get remote.origin.url | cut -d ':' -f 2 | sed 's/\.git$//g')
if [ "${repo}" = "" ]; then
  error "Could not get repo name."
  exit 1
fi

gh auth status >/dev/null || exit 1
if [ $? -ne 0 ]; then
  error "Missing GitHub login."
  exit 1
fi

gh_username=$(sed -n 's,^[ ]*user: \(.*\)$,\1,p' ~/.config/gh/hosts.yml)
if [ "${gh_username}" = "" ]; then
  error "Missing GitHub username."
  exit 1
fi

update_repo
merge_prs

update_repo
update_packages
