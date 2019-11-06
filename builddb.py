#!/usr/bin/env python3

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

import sys

import datasource
from repopaths import index_path, load_repo


def build_db(source, repos):
    for repo in repos:
        path = index_path(repo)
        repodata = load_repo(path)
        if repodata is None:
            continue
        arch = repo.rpartition('/')[-1]
        for pkgname in repodata:
            dictionary = {}
            for k, v in repodata[pkgname].items():
                if isinstance(v, bytes):
                    v = v.decode('utf-8')
                dictionary[k] = v
            source.create(datasource.PackageRow(
                arch=arch,
                pkgname=pkgname,
                pkgver=dictionary['pkgver'],
                restricted=False,
                builddate=dictionary['build-date'],
                repodata=datasource.to_json(dictionary),
                templatedata=datasource.to_json({}),
                upstreamver='',
                repo=repo
            ))


if __name__ == '__main__':
    datasource.update(lambda x: build_db(x, sys.argv[1:]))
