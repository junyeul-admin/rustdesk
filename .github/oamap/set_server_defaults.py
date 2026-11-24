#!/usr/bin/env python3
# OAMap add-on 0006: bake our ID server / public key into the build as the
# default (libs/hbb_common/src/config.rs RENDEZVOUS_SERVERS / RS_PUB_KEY).
# Values come only from GitHub secrets via env (OAMAP_ID_SERVER,
# OAMAP_PUB_KEY); nothing is stored in the repository and nothing is printed.
# Empty secret = upstream default kept (feature off).
# Server set without key = stop: the app would check our server against
# upstream's public key (src/common.rs get_key falls back to RS_PUB_KEY).
import os
import re
import sys

path = sys.argv[1] if len(sys.argv) > 1 else 'libs/hbb_common/src/config.rs'
server = os.environ.get('OAMAP_ID_SERVER', '').strip()
key = os.environ.get('OAMAP_PUB_KEY', '').strip()

# GitHub masks the whole secret; also mask the host part alone (a log line may
# show "host" without ":port").
if os.environ.get('GITHUB_ACTIONS') == 'true':
    host = server
    if host.startswith('['):
        host = host[1:].split(']', 1)[0]
    elif host.count(':') == 1:
        host = host.split(':', 1)[0]
    for v in {server, host, key}:
        if v:
            print('::add-mask::' + v)

if not server:
    print('OAMap 0006: OAMAP_ID_SERVER empty - upstream server default kept')
    sys.exit(0)
if not key:
    print('OAMap 0006: OAMAP_ID_SERVER is set but OAMAP_PUB_KEY is empty - set both secrets')
    sys.exit(1)
# host[:port] (IPv6 in brackets) and a base64 key only: nothing that could end
# the Rust string literal or add code.
if not re.fullmatch(r'[A-Za-z0-9.\-]+(:[0-9]{1,5})?|\[[0-9A-Fa-f:.]+\](:[0-9]{1,5})?', server):
    print('OAMap 0006: OAMAP_ID_SERVER must be host or host:port')
    sys.exit(1)
if not re.fullmatch(r'[A-Za-z0-9+/]{40,64}={0,2}', key):
    print('OAMap 0006: OAMAP_PUB_KEY must be the base64 public key (id_ed25519.pub)')
    sys.exit(1)

src = open(path, encoding='utf-8').read()
src, n1 = re.subn(r'^pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
                  lambda m: 'pub const RENDEZVOUS_SERVERS: &[&str] = &["%s"];' % server,
                  src, flags=re.M)
src, n2 = re.subn(r'^pub const RS_PUB_KEY: &str = "[^"]*";',
                  lambda m: 'pub const RS_PUB_KEY: &str = "%s";' % key,
                  src, flags=re.M)
if n1 != 1 or n2 != 1:
    print('OAMap 0006: config.rs lines not found (upstream changed?) n1=%d n2=%d' % (n1, n2))
    sys.exit(1)
open(path, 'w', encoding='utf-8').write(src)
print('OAMap 0006: server default set (values hidden)')
