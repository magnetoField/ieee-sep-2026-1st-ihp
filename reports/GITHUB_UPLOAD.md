# D00RSH — public GitHub preparation, 2026-09-13

Project: D00RSH. Author: Koło Naukowe BAZA — ZT, PN, MK, JT, KK.
Public repository created at https://github.com/opelkus/D00RSH. The local
pre-publication source commit is 60e40e9e213899b3100321591388d3e2c844380e.
At this report snapshot the first push and remote CI are still pending. No
payment or production submission has been performed.

## Prepared

- info.yaml product title/authorship and public README/datasheet/wiki updated.
- Verified physical top/source names retained to preserve netlist/GDS identity.
- IHP26b official workflow structure retained; GDS support tools pinned to
  01d5d2814fa9dd61e9d211e0b235a4a592a9316a and LibreLane 3.0.5.
- RTL regression uses OSS CAD Suite release 2026-09-12 through setup action
  commit 853bb54f52246aa8fb4fab963f104cfb6676197a.
- RTL logs uploaded by CI; wiki builds as an artifact, without competing
  with the official Tiny Tapeout Pages viewer.
- gitignore excludes local PDK/tool installations, runs, generated wiki,
  old wiki archive, credentials and upload bundles. No existing files deleted.
- Transport archive: .upload/D00RSH-github.zip; inventory and ZIP SHA-256
  alongside it. This is a GitHub source snapshot, not a Tiny Tapeout submission.
- Original verification manifest preserved in
  reports/MANIFEST_BEFORE_GITHUB_UPLOAD.sha256. Current MANIFEST.sha256 updated
  only for named packaging/docs/workflow records. RTL, source configuration,
  GDS/LEF/netlist and original verification evidence digests are unchanged.

## Executed checks

| Command / scope | Result | Evidence |
|---|---|---|
| make upload-check PYTHON=.tools/wiki-env/bin/python | PASS | logs/upload-check.log |
| Official ProjectInfo validation from pinned support tools | PASS | logs/upload-official-metadata.log |
| make lint test-model | PASS; 15 model tests | logs/upload-lint-model.log |
| make release-check | PASS local evidence | logs/upload-release-check.log |
| make wiki-build | PASS strict build | logs/upload-wiki-build.log |
| .tools/wiki-env/bin/python scripts/check_wiki.py | PASS 398 links, 56 indexed entries | logs/upload-wiki-check.log |
| make upload-package PYTHON=.tools/wiki-env/bin/python | PASS source ZIP | logs/upload-package.log (initial candidate) |
| Extract ZIP; verify full inventory; release-check; strict MkDocs build; RTL wrapper compile/simulate | PASS | logs/upload-extracted-check.log |

Extracted-source test used a fresh /tmp directory, no local .tools or PDK in
the package. Compiler executables were supplied from the host. RTL wrapper
covered authorized response, rejected PIN and pin mapping. Full historical
regression/P&R were not repeated for this documentation/packaging change.
The final archive is rebuilt after adding this report; its separate SHA-256
and inventory are authoritative rather than the initial archive hash in logs.

Tools: Python 3.12.14 (wiki/metadata), Python 3.14.4 (system checks),
MkDocs 1.6.1, Icarus Verilog 12.0, Yosys 0.52, Verilator 5.032, Git 2.53.0.

## Status and remaining work

RTL_DEMO=PASS (local evidence plus extracted wrapper smoke)
VERIFICATION=PASS (required local evidence; not a new full regression)
FIT_1_TILE=PASS (existing verified IHP run)
PHYSICAL_CHECKS=PASS (existing local STA/DRC/LVS/antenna evidence)
PRODUCTION_PERSISTENCE=NOT_IMPLEMENTED
REMOTE_CI=NOT_RUN
SUBMISSION=NOT_PERFORMED
LOCAL_COMMIT=PASS
FIRST_PUSH=PENDING

Remaining: first push, enable/verify Actions and Pages, require green CI for
the published commit, verify shuttle availability and import in Tiny Tapeout.
Preserve SDF unsupported, 15 fanout warnings, narrow hold margin, public demo
key, volatile lockout and absence of silicon testing. The standard RTL CI uses
Ubuntu packages and has not yet been executed on a GitHub runner.

User instructions: docs/GITHUB_UPLOAD.md. No account credentials are requested
or embedded. The basic credential-pattern scan is not an exhaustive secret audit.
