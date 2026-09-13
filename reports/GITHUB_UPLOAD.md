# D00RSH — public GitHub preparation, 2026-09-13

Project: D00RSH. Author: Koło Naukowe BAZA — ZT, PN, MK, JT, KK.
Publication target selected by the user:
https://github.com/magnetoField/ieee-sep-2026-1st-ihp. The target is public,
the authenticated account has WRITE permission, and its existing `main`
history through dde98d17fe0eef79c5d05db6fbf471b7aeebed0e is merged without a
force-push. The D00RSH project tree remains authoritative over the placeholder
template. Commit 591f96d58bc990ff2b4ac7c46b12b4208281c7a2 was pushed to
`main`. No other repository is configured as a project remote. No payment or
production submission has been performed.

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
REMOTE_CI=FAIL_ON_591F96D
SUBMISSION=NOT_PERFORMED
LOCAL_COMMIT=PASS
FIRST_PUSH=PASS

Remote result for 591f96d: docs/wiki/gds/precheck/gl_test PASS; RTL FAIL because
Git mode 0644 made `scripts/local_tool.sh` non-executable on Linux. Viewer alone
FAIL because GitHub Pages is not enabled. Commit bc292cd fixes executable modes,
but its RTL run exposed Icarus 13 rejecting a forward declaration use in kb.v.
Declarations were reordered without logic changes and the complete local CI
command set PASS. Commit ff4b316 confirms Icarus 13 acceptance, then Verilator
5.053 FAILs only on SYNCASYNCNET for the intentional reset-release synchronizer.
The lint command now waives only that named warning while retaining `-Wall`.
A fresh push and remote run remain required. The Pages API
returned 404 for the authenticated WRITE collaborator; a repository admin must
enable Pages with GitHub Actions as source. Then verify shuttle availability and
import in Tiny Tapeout.
Preserve SDF unsupported, 15 fanout warnings, narrow hold margin, public demo
key, volatile lockout and absence of silicon testing. The standard RTL CI uses
Ubuntu packages and has not yet been executed on a GitHub runner.

User instructions: docs/GITHUB_UPLOAD.md. No account credentials are requested
or embedded. The basic credential-pattern scan is not an exhaustive secret audit.

## Current CI status and Pages rerun repair — 2026-09-13

Commit `857c0e4c9b81f69020444db35f6e80c294e28417` passes the remote RTL,
documentation, wiki, GDS, precheck and gate-level jobs. GitHub Pages is now
enabled, and fresh workflow-dispatch run 34764740699 also passes `viewer`.
The branch nevertheless reports 6/7 because push run 34762738865 was rerun as
attempt 2: the upstream viewer uploaded another fixed-name `github-pages`
artifact, and `deploy-pages@v5` rejected the two retained artifacts.

The local repair expands the upstream viewer sequence and uses
`github-pages-${{ github.run_id }}-${{ github.run_attempt }}` consistently for
upload and deployment. `make upload-check` now rejects loss or mismatch of that
pair. This CI-only change has local structural verification but no remote result
until an explicitly authorized push; the existing 6/7 is not relabeled PASS.
