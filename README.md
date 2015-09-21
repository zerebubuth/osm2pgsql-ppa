# Osm2pgsql packaging scripts

These are scripts used to build nightly releases of osm2pgsql, and upload to launchpad.



## Requirements

```
sudo apt-get install debhelper devscripts dput git-core python
```

## Setting up

1) Clone the packaging repo and enter debian dir:

    git clone https://github.com/pnorman/osm2pgsql-ppa.git
    cd osm2pgsql-ppa

2) Clone the osm2pgsql git repo from https://github.com/openstreetmap/osm2pgsql into a git/ dir:

    git clone https://github.com/openstreetmap/osm2pgsql.git git

3) Update the nightly-build.sh script with your name/GPG key/etc, and 
what branches/dists/ppas you want. Set the latest releases correctly too.


## Notes

Modeled after

* https://github.com/mapnik/debian
* https://github.com/apmon/OSM-rendering-stack-deplou

Script license: GPL-2+
