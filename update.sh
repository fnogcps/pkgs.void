#!/bin/sh

# pkgs.void - web catalog of Void Linux packages.
# Copyright (C) 2019 Piotr Wójcik <chocimier@tlen.pl>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# This script updates packages database and published source tarball.

mirror=https://alpha.de.repo.voidlinux.org
rsyncmirror=rsync://alpha.de.repo.voidlinux.org/voidmirror/current/
download=yes
templates=
updates=
popularity=yes

cd "$(dirname "$0")" || exit 1
[ -r ./profile ] && . ./profile
. venv/bin/activate

while true
do
    case "$1" in
        -D) download= ;;
        -m)
            shift
            mirror="$1"
            ;;
        -P) popularity= ;;
        -t) templates=yes ;;
        -u) updates=yes ;;
        *) break
    esac
    shift
done

mkdir -p static/source
cd .. || exit 1
tar cjf pkgs.void/static/source/tmp.tar.bz2 --exclude-ignore tar-exclude pkgs.void || exit 1
cd pkgs.void || exit 1
mv static/source/tmp.tar.bz2  static/source/pkgs.void.tar.bz2 || exit 1

if [ "$templates" ]
then
    : "${XBPS_DISTDIR:=$(xdistdir)}"
    ( cd "$XBPS_DISTDIR" || exit $?
    git checkout -q xbps-src-p || exit $?
    if [ "$download" ]
    then
        git fetch xbps-src-p -q &&
        git checkout --detach -q &&
        git branch -f xbps-src-p xbps-src-p/xbps-src-p -q &&
        git checkout -q xbps-src-p &&
        git fetch -q origin &&
        git rebase -q origin/master || exit $?
    fi
    ) || exit $?
fi

mkdir -p data
cd data || exit 1

repos=$(cat ../repos.list)

for path in $repos; do
	arch="$(echo "$path" | tr / _)"
	filename="$arch-repodata.tar.xz"
	extract_dir=$(../repopaths.py directory_name "$path")
	[ "$download" ] && wget -q -O "$filename" "$mirror/current/$path-repodata"
	rm -r "$extract_dir"
	mkdir "$extract_dir"
	tar xf "$filename" -C "$extract_dir"
done

for path in $repos; do
	echo "$(../repopaths.py rsync_path "$path")"
done | sort -u | while read dir; do
	filename="$(../repopaths.py rsync_filename "$dir")"
	[ "$download" ] && rsync --list-only "${rsyncmirror}${dir}" --include '*.xbps' --exclude='*' > "${filename}"
done

[ "$download" ] && [ "$updates" ] && wget -q -O void-updates.txt "$mirror/void-updates/void-updates.txt"
[ "$download" ] && [ "$popularity" ] &&
  wget -q -O popcorn.today.json "http://popcorn.voidlinux.org/popcorn_$(date +%Y-%m-%d).json" &&
  mv popcorn.today.json popcorn.json

cd .. || exit 1

rm -f newindex.sqlite3
./builddb.py $repos
[ "$templates" ] && ./dbfromrepo.py $repos
[ "$updates" ] && ./updates.py $repos
[ "$popularity" ] && ./popularity.py
./rsyncdata.py $repos

mv newindex.sqlite3 index.sqlite3

mkdir -p static/generated
python -c 'import voidhtml; print(voidhtml.list_all())' > static/generated/all.html
