#!/bin/sh
# In sync once the repo exists, whoever wrote it — this spec on a fresh machine,
# or Vivaldi's own %post from then on. Deliberately says nothing about the
# content: asserting that would re-open the fight the bootstrap script avoids.
set -eu
test -f /etc/yum.repos.d/vivaldi.repo
