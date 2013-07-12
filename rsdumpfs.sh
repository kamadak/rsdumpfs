#!/bin/sh
#
# Copyright (c) 2013 KAMADA Ken'ichi.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#

set -e
export PATH=/usr/bin:/bin
export LC_ALL=C

RSYNC=/usr/pkg/bin/rsync
RSYNCFLAGS="-aHS --no-D"

progname=$(basename "$0")

error() {
        printf "%s: %s\n" "$progname" "$*" 1>&2
        exit 1
}

if [ $# -ne 2 ]; then
	echo "usage: $progname SRC DEST"
	exit 1
fi
# Strip trailing slashes from SRCDIR for rsync (but keep the root directory).
SRCDIR=$(printf "%s" "$1" | sed -E 's:(^/|.*[^/])/*$:\1:')
DESTDIR="$2"

# Convert the output from "rsync -ii" to pdumpfs-like one.
emul_pdumpfs_output() {
	sed -e 's/^cd......... /directory    /' \
	    -e 's/^>f+++++++++ /new_file     /' \
	    -e 's/^>f......... /updated      /' \
	    -e 's/^hf......... /unchanged    /' \
	    -e 's/^cL......... /symlink      /' \
	    -e 's/^cS......... /special      /' \
	    -e 's/^cD......... /device       /'
}

old=$(readlink "$DESTDIR/latest" || echo "")
new=$(date +'%Y/%m%d')
if [ x"$new" = x"$old" ]; then
	error "Today ($new) = latest ($old); cannot backup twice a day"
elif [ -e "$DESTDIR/$new" ]; then
	error "$DESTDIR/$new: Already exists"
elif [ -z "$old" ]; then
	(umask 077 && mkdir -p "$DESTDIR/$new")
	$RSYNC $RSYNCFLAGS -ii "$SRCDIR" "$DESTDIR/$new" | emul_pdumpfs_output
	ln -s "$new" "$DESTDIR/latest"
else
	(umask 077 && mkdir -p "$DESTDIR/$new")
	$RSYNC $RSYNCFLAGS -ii --delete-during --link-dest=../../"$old" \
	    "$SRCDIR" "$DESTDIR/$new" | emul_pdumpfs_output
	rm "$DESTDIR/latest"
	ln -s "$new" "$DESTDIR/latest"
fi
