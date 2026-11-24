#!/usr/bin/env python3
# OAMap add-on 0006: bake our ID server / public key into the build as the
# default (libs/hbb_common/src/config.rs RENDEZVOUS_SERVERS / RS_PUB_KEY).
# Values come only from GitHub secrets via env (OAMAP_ID_SERVER,
# OAMAP_PUB_KEY); nothing is stored in the repository and nothing is printed.
# Empty secret = upstream default kept (feature off).
import os
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'libs/hbb_common/src/config.rs'
server = os.environ.get('OAMAP_ID_SERVER', '').strip()
key = os.environ.get('OAMAP_PUB_KEY', '').strip()
if not server:
    print('OAMap 0006: OAMAP_ID_SERVER empty - upstream server default kept')
    sys.exit(0)
for v in (server, key):
    if '"' in v or '\\' in v or '\n' in v:
        print('OAMap 0006: secret contains a character not allowed here')
        sys.exit(1)

src = open(path, encoding='utf-8').read()
src, n1 = re.subn(r'^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
                  lambda m: 'pub const RENDEZVOUS_SERVERS: &[&str] = &["%s"];' % server,
                  src, flags=re.M)
n2 = 1
if key:
    src, n2 = re.subn(r'^pub const RS_PUB_KEY: &str = "[^"]*";',
                      lambda m: 'pub const RS_PUB_KEY: &str = "%s";' % key,
                      src, flags=re.M)
if n1 != 1 or n2 != 1:
    print('OAMap 0006: config.rs lines not found (upstream changed?) n1=%d n2=%d' % (n1, n2))
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(src)
print('OAMap 0006: server default set (values hidden)')
