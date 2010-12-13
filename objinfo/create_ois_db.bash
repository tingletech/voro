#!/bin/env bash
set -e
set -u 
mkdir -p $HOME/indexes/sqlite3
if [ ! -e $HOME/indexes/sqlite3/ois.sqlite3 ]; then
  sqlite3 $HOME/indexes/sqlite3/ois.sqlite3 <<EOF
CREATE TABLE "item" ("ark" varchar(256) PRIMARY KEY,
    "ark_parent" varchar(256) NOT NULL,
    "ark_grandparent" varchar(256)
);
CREATE TABLE "digitalobject" ("ark" varchar(256) NOT NULL,
    "ark_findingaid" varchar(256) NOT NULL REFERENCES "item" ("ark"),
    "num_order" varchar(9) NOT NULL,
    PRIMARY KEY (ark, ark_findingaid)
);
EOF
fi
