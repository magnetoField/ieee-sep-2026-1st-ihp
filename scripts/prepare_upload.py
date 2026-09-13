#!/usr/bin/env python3
"""Check the public source snapshot; optionally create a transport ZIP.

Uses git's tracked/nonignored file selection without staging, committing or
publishing anything. A clean extracted tree is checked separately before handoff.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

import yaml

ROOT = Path(__file__).resolve().parents[1]


def check_viewer_artifact(viewer):
    """Require one attempt-specific Pages artifact from upload through deploy."""
    errors = []
    pages_name = 'github-pages-${{ github.run_id }}-${{ github.run_attempt }}'
    if viewer.get('env', {}).get('PAGES_ARTIFACT') != pages_name:
        errors.append('Viewer Pages artifact is not unique per workflow attempt')
    upload_steps = [s for s in viewer.get('steps', [])
                    if str(s.get('uses', '')).startswith('actions/upload-pages-artifact@')]
    deploy_steps = [s for s in viewer.get('steps', [])
                    if str(s.get('uses', '')).startswith('actions/deploy-pages@')]
    artifact_ref = '${{ env.PAGES_ARTIFACT }}'
    if len(upload_steps) != 1 or upload_steps[0].get('with', {}).get('name') != artifact_ref:
        errors.append('Viewer must upload exactly the attempt-specific Pages artifact')
    if len(deploy_steps) != 1 or deploy_steps[0].get('with', {}).get('artifact_name') != artifact_ref:
        errors.append('Viewer must deploy exactly the attempt-specific Pages artifact')
    return errors


def candidates():
    data = subprocess.check_output(
        ['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT
    )
    return sorted(set(name.decode() for name in data.split(b'\0') if name))


def tracked_modes():
    data = subprocess.check_output(['git', 'ls-files', '--stage', '-z'], cwd=ROOT)
    modes = {}
    for record in data.split(b'\0'):
        if not record:
            continue
        metadata, name = record.split(b'\t', 1)
        modes[name.decode()] = metadata.split()[0].decode()
    return modes


def check(names):
    errors = []
    info = yaml.safe_load((ROOT / 'info.yaml').read_text())
    project = info['project']
    for key in ('title', 'author', 'description'):
        if not str(project.get(key, '')).strip():
            errors.append(f'info.yaml: missing {key}')
    if info.get('yaml_version') != 6 or project.get('tiles') != '1x1':
        errors.append('Expected YAML v6 and 1x1 tile')
    if project.get('clock_hz') != 1000000:
        errors.append('Expected 1 MHz clock')
    sources = project.get('source_files', [])
    if not sources or len(sources) != len(set(sources)):
        errors.append('Empty or duplicate source list')
    source_paths = []
    for name in sources:
        path = ROOT / 'src' / name
        if not path.resolve().is_relative_to(ROOT / 'src') or not path.is_file():
            errors.append(f'Invalid source: {name}')
        elif str(path.relative_to(ROOT)) not in names:
            errors.append(f'Source excluded from upload: {name}')
        else:
            source_paths.append(path)
    top = project.get('top_module', '')
    if not top.startswith('tt_um_') or not any(
        re.search(r'\bmodule\s+' + re.escape(top) + r'\b', p.read_text()) for p in source_paths
    ):
        errors.append('Top module not found')
    for group in ('ui', 'uo', 'uio'):
        for bit in range(8):
            if f'{group}[{bit}]' not in info.get('pinout', {}):
                errors.append(f'Missing pin {group}[{bit}]')
    required = ('LICENSE', 'README.md', 'docs/info.md', 'test/Makefile',
                '.github/workflows/gds.yaml', '.github/workflows/docs.yaml',
                '.github/workflows/test.yaml', '.github/workflows/wiki.yaml',
                'MANIFEST.sha256')
    errors += [f'Missing required publication file: {n}' for n in required if n not in names]
    modes = tracked_modes()
    for name in (n for n in names if n.startswith('scripts/') and n.endswith('.sh')):
        if modes.get(name) != '100755':
            errors.append(f'Linux runner requires executable Git mode 100755: {name}')
    workflow = yaml.safe_load((ROOT / '.github/workflows/gds.yaml').read_text())
    jobs = workflow['jobs']
    if not {'gds', 'precheck', 'gl_test', 'viewer'} <= jobs.keys():
        errors.append('Missing Tiny Tapeout jobs')
    if not any(s.get('with', {}).get('pdk') == 'ihp-sg13g2' for s in jobs['gds']['steps']):
        errors.append('GDS workflow does not select IHP')
    errors += check_viewer_artifact(jobs['viewer'])
    # Report filenames only, never credential contents. Public demo cipher
    # vectors are intentionally allowed; they are not account credentials.
    patterns = [rb'gh[pousr]_[A-Za-z0-9]{30,}', rb'github_pat_[A-Za-z0-9_]{40,}',
                rb'AKIA[0-9A-Z]{16}', rb'-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----']
    total = 0
    for name in names:
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            errors.append(f'Non-regular publication file: {name}')
            continue
        if name.split('/')[0] in ('.tools', '.build', '.upload', '.git', 'runs', 'node_modules'):
            errors.append(f'Local-only directory selected: {name}')
        size = path.stat().st_size
        total += size
        if size >= 25 * 1024 * 1024:
            errors.append(f'Large publication file >=25 MiB: {name}')
        if any(re.search(pattern, path.read_bytes()) for pattern in patterns):
            errors.append(f'Possible credential in: {name}')
    if errors:
        raise SystemExit('BLOCKED:\n' + '\n'.join(errors))
    print(f'PASS upload structure: {len(names)} files, {total / 1024 / 1024:.2f} MiB')
    print('PASS metadata, 24 pins, source list, executable scripts, IHP jobs, size and basic credential-pattern checks')
    print(f'Project: {project["title"]}; author: {project["author"]}')
    return total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--archive', action='store_true')
    args = parser.parse_args()
    names = candidates()
    check(names)
    if args.archive:
        directory = ROOT / '.upload'
        directory.mkdir(exist_ok=True)
        output = directory / 'D00RSH-github.zip'
        inventory = {}
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            for name in names:
                data = (ROOT / name).read_bytes()
                entry = zipfile.ZipInfo('D00RSH/' + name, (2026, 9, 13, 0, 0, 0))
                entry.create_system = 3
                mode = 0o755 if name.endswith('.sh') else 0o644
                entry.external_attr = (0o100000 | mode) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                archive.writestr(entry, data)
                inventory[name] = hashlib.sha256(data).hexdigest()
        (directory / 'D00RSH-files.json').write_text(json.dumps(inventory, indent=2) + '\n')
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        (directory / 'D00RSH-github.zip.sha256').write_text(digest + '  D00RSH-github.zip\n')
        print(f'Archive: {output} ({output.stat().st_size} bytes)')
        print('SHA256: ' + digest)
        print('No Git commit, remote creation, push or Tiny Tapeout submission performed.')


if __name__ == '__main__':
    main()
