"""Sunder local checks, tests, reproducible packaging and backed-up deployment."""
from __future__ import annotations
import argparse, datetime, hashlib, json, os, re, shutil, subprocess, sys, tempfile, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ADDON=ROOT/'addon/Sunder'
COMPAT=ROOT/'compat/ROTBOTForever'
DEFAULT_ADDONS=Path(r'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns')
def version():
    return re.search(r'^## Version: (.+)$',(ADDON/'Sunder.toc').read_text(encoding='utf-8'),re.M)[1].strip()
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def files(root):return sorted(p for p in root.rglob('*') if p.is_file() and '__pycache__' not in p.parts and 'tests' not in p.relative_to(root).parts)
def check():
    import xml.etree.ElementTree as ET
    from lupa.lua51 import LuaRuntime
    lua=LuaRuntime();compile_lua=lua.eval('function(s,n) local f,e=loadstring(s,n);assert(f,e) end')
    for p in ADDON.rglob('*.lua'):compile_lua(p.read_text(encoding='utf-8-sig'),str(p))
    visited=set()
    def resource(path):
        assert path.is_file(),f'Missing manifest resource: {path}'
        if path in visited:return
        visited.add(path)
        if path.suffix.lower()=='.xml':
            for node in ET.parse(path).iter():
                if node.get('file'):resource(path.parent/node.get('file').replace(chr(92),'/'))
    toc=(ADDON/'Sunder.toc').read_text(encoding='utf-8')
    for line in toc.splitlines():
        if line.strip() and not line.startswith('#'):resource(ADDON/line.strip().replace(chr(92),'/'))
    assert '## SavedVariables: SunderDB' in toc
    assert (ADDON/'Sunder/Migration.lua') in visited
    assert not any(line.strip() and not line.startswith('#') for line in (COMPAT/'ROTBOTForever.toc').read_text().splitlines()),'Legacy loader must contain metadata only'
    from PIL import Image
    for name,size in [('SunderIcon',256),('SunderMinimap',64),('SunderSettings',512)]:
        p=ADDON/'Media/Brand'/f'{name}.tga';im=Image.open(p)
        assert im.size==(size,size) and im.mode=='RGBA'
        assert p.read_bytes()[2]==2,'WoW textures must be uncompressed true-color TGA'
    allowed={'Migration.lua','Config.lua','ItemProtection.lua','ProfileTransfer.lua','Bindings.xml','Sunder.toc'}
    for p in (ADDON/'Sunder').rglob('*.lua'):
        if p.name not in allowed:assert not re.search(r'rotbot|runestone',p.read_text(encoding='utf-8'),re.I),f'Unexpected legacy branding: {p}'
    print(f'Check passed: Lua 5.1 syntax, {len(visited)} manifest resources, loader and branded textures.')
def tests():
    check()
    env=dict(os.environ,SUNDER_ADDON_ROOT=str(ADDON),PYTHONDONTWRITEBYTECODE='1',PYTHONIOENCODING='utf-8')
    cases=['work/test_chat_spacing097.py','work/test_bank_sort098.py','work/test_edit_registration0910.py','work/test_settings094.py','work/test_item_clicks093.py','work/sunder-tests/test_editors_bounds.py']
    for case in cases:
        result=subprocess.run([sys.executable,'-c',"import os,runpy,sys;runpy.run_path(sys.argv[1],init_globals={'os':os},run_name='__main__')",case],cwd=ROOT/'tests/regression',env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,encoding='utf-8')
        if result.returncode:
            print(result.stdout);raise RuntimeError(f'Regression failed: {case}')
        print(f'PASS {case}')
    for case in ('test_migration.py','test_workflow.py'):
        subprocess.run([sys.executable,str(ROOT/'tests'/case)],cwd=ROOT,env=env,check=True)
def package():
    check();out=ROOT/'dist';out.mkdir(exist_ok=True)
    for suffix,roots in [('',[(ADDON,'Sunder')]),('-upgrade',[(ADDON,'Sunder'),(COMPAT,'ROTBOTForever')])]:
        dest=out/f'Sunder-{version()}{suffix}.zip'
        with zipfile.ZipFile(dest,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
            for root,name in roots:
                for p in files(root):
                    info=zipfile.ZipInfo(f'{name}/{p.relative_to(root).as_posix()}',date_time=(2026,1,1,0,0,0))
                    info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16
                    z.writestr(info,p.read_bytes())
        print(f'Packaged {dest.name}  SHA256 {digest(dest)}')
    manifest={str(p.relative_to(ADDON)).replace(chr(92),'/'):digest(p) for p in files(ADDON)}
    (out/'Sunder-files.sha256.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
def addon_path(value):
    root=Path(value).expanduser().resolve()
    if not root.is_dir() or root.name.lower()!='addons':raise ValueError('Select the existing Interface/AddOns directory.')
    return root
_NAMES=('Sunder','ROTBOTForever')
def safe_child(root,name):
    if name not in _NAMES:raise ValueError('Unexpected addon directory')
    p=root/name
    if p.is_symlink() or p.resolve().parent!=root.resolve():raise ValueError('Addon target escaped the selected directory')
    return p
def deploy(root,dry=False,run_tests=True):
    if run_tests:tests()
    root=addon_path(root)
    for name in _NAMES:safe_child(root,name)
    if dry:
        print(f'Would deploy {ADDON} to {root}/Sunder and replace ROTBOTForever with its data-only loader. SavedVariables stay untouched.');return
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup=ROOT/'.local/backups'/stamp;backup.mkdir(parents=True)
    state={'addons':str(root),'version':version(),'folders':{}}
    for name in _NAMES:
        target=safe_child(root,name);state['folders'][name]=target.exists()
        if target.exists():shutil.copytree(target,backup/name)
    (backup/'deployment.json').write_text(json.dumps(state,indent=2)+'\n',encoding='utf-8')
    try:
        with tempfile.TemporaryDirectory(prefix='sunder-deploy-',dir=ROOT/'.local') as temp:
            stage=Path(temp)
            for source,name in [(ADDON,'Sunder'),(COMPAT,'ROTBOTForever')]:shutil.copytree(source,stage/name)
            for name in _NAMES:
                target=safe_child(root,name)
                if target.exists():shutil.rmtree(target)
                shutil.copytree(stage/name,target)
        for source,name in [(ADDON,'Sunder'),(COMPAT,'ROTBOTForever')]:
            target=safe_child(root,name)
            assert len(files(source))==len(files(target))
            for p in files(source):assert digest(p)==digest(target/p.relative_to(source))
    except Exception:
        restore(backup,root);raise
    (ROOT/'.local/last-deploy.json').write_text(json.dumps({'backup':str(backup),'addons':str(root)},indent=2),encoding='utf-8')
    print(f'Deployed Sunder {version()}; all installed files verified. Backup: {backup.name}. SavedVariables untouched.')
def restore(backup,root=None):
    backup=Path(backup).resolve();base=(ROOT/'.local/backups').resolve()
    if backup.parent!=base:raise ValueError('Rollback must name a backup created by this repository.')
    state=json.loads((backup/'deployment.json').read_text(encoding='utf-8'));root=addon_path(root or state['addons'])
    for name in _NAMES:
        target=safe_child(root,name)
        if target.exists():shutil.rmtree(target)
        if state['folders'][name]:shutil.copytree(backup/name,target)
    print('Restored addon folders from deployment backup; SavedVariables untouched.')
def main():
    parser=argparse.ArgumentParser(description=__doc__);sub=parser.add_subparsers(dest='command',required=True)
    for command in ('check','test','package'):sub.add_parser(command)
    d=sub.add_parser('deploy');d.add_argument('--addons',default=str(DEFAULT_ADDONS));d.add_argument('--dry-run',action='store_true')
    r=sub.add_parser('rollback');r.add_argument('--backup');r.add_argument('--addons')
    args=parser.parse_args()
    if args.command=='check':check()
    elif args.command=='test':tests()
    elif args.command=='package':package()
    elif args.command=='deploy':deploy(args.addons,args.dry_run)
    else:
        backup=args.backup or json.loads((ROOT/'.local/last-deploy.json').read_text())['backup'];restore(backup,args.addons)
if __name__=='__main__':main()
