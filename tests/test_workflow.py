from pathlib import Path
import importlib.util,json,tempfile,zipfile,shutil
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sunder_tools',ROOT/'tools/sunder.py');tool=importlib.util.module_from_spec(spec);spec.loader.exec_module(tool)
local=ROOT/'.local';local.mkdir(exist_ok=True)
last=local/'last-deploy.json';previous=last.read_bytes() if last.exists() else None
backup=None
try:
    with tempfile.TemporaryDirectory(prefix='workflow-test-',dir=local) as temp:
        root=Path(temp)/'Interface/AddOns';root.mkdir(parents=True)
        for name in ('Sunder','ROTBOTForever'):
            (root/name).mkdir();(root/name/'original.txt').write_text(name)
        saved=Path(temp)/'WTF/account.lua';saved.parent.mkdir();saved.write_bytes(b'private fixture unchanged')
        tool.deploy(root,run_tests=False)
        backup=Path(json.loads(last.read_text())['backup'])
        assert (root/'Sunder/Sunder.toc').exists() and not (root/'ROTBOTForever/original.txt').exists()
        assert not list((root/'ROTBOTForever').glob('*.lua'))
        assert saved.read_bytes()==b'private fixture unchanged'
        tool.restore(backup)
        assert (root/'Sunder/original.txt').read_text()=='Sunder'
        assert (root/'ROTBOTForever/original.txt').read_text()=='ROTBOTForever'
        assert saved.read_bytes()==b'private fixture unchanged'
    tool.package();first={p.name:tool.digest(p) for p in (ROOT/'dist').glob('*.zip')};tool.package()
    assert first=={p.name:tool.digest(p) for p in (ROOT/'dist').glob('*.zip')}
    for path in (ROOT/'dist').glob('*.zip'):
        with zipfile.ZipFile(path) as z:
            names=z.namelist();roots={name.split('/')[0] for name in names}
            assert roots==({'Sunder','ROTBOTForever'} if '-upgrade' in path.name else {'Sunder'})
            assert 'Sunder/Sunder.toc' in names and not any('/tests/' in n or '/.local/' in n for n in names)
            if '-upgrade' in path.name:assert [n for n in names if n.startswith('ROTBOTForever/')]==['ROTBOTForever/ROTBOTForever.toc']
finally:
    if previous is not None:last.write_bytes(previous)
    elif last.exists():last.unlink()
    if backup and backup.parent.resolve()==(ROOT/'.local/backups').resolve():shutil.rmtree(backup)
print('Workflow passed: temporary-target deploy/hash verification, metadata-only legacy replacement, rollback, untouched saved-data fixture and deterministic clean/upgrade packages.')
