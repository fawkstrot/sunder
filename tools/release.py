"""Prepare release notes/metadata; upload only with an explicit publish command."""
from pathlib import Path
import argparse, hashlib, importlib.util, json, os, re, subprocess, urllib.request, uuid
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('sunder_tools',ROOT/'tools/sunder.py');tools=importlib.util.module_from_spec(spec);spec.loader.exec_module(tools)
def notes(version):
    text=(tools.ADDON/'CHANGELOG.md').read_text(encoding='utf-8')
    match=re.search(r'^# '+re.escape(version)+r'(?: \([^\n]*\))?\s*\n(.*?)(?=^# |\Z)',text,re.M|re.S)
    if not match or not match[1].strip():raise ValueError('Add a nonempty versioned changelog section before releasing.')
    return match[1].strip()+'\n'
def prepare(tag):
    version=tools.version()
    if tag!='v'+version:raise ValueError('Tag must match the TOC version: v'+version)
    compat=(tools.COMPAT/'ROTBOTForever.toc').read_text(encoding='utf-8')
    if '## Version: '+version not in compat:raise ValueError('Migration loader version must match.')
    config=json.loads((ROOT/'release.json').read_text(encoding='utf-8'))
    toc=(tools.ADDON/'Sunder.toc').read_text(encoding='utf-8')
    if f"## X-Curse-Project-ID: {config['curseforgeProjectId']}" not in toc:raise ValueError('CurseForge project ID mismatch.')
    release_notes=notes(version);tools.package()
    dist=ROOT/'dist';(dist/'release-notes.md').write_text(release_notes,encoding='utf-8')
    metadata={'displayName':'Sunder '+version,'changelog':release_notes,'changelogType':'markdown','releaseType':'alpha' if '-alpha' in version else 'beta' if '-beta' in version or '-rc' in version else 'release','gameVersions':config['gameVersionIds']}
    (dist/'curseforge-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    archive=dist/f'Sunder-{version}.zip'
    (dist/'release-manifest.json').write_text(json.dumps({'tag':tag,'version':version,'curseforgeProjectId':config['curseforgeProjectId'],'artifact':archive.name,'sha256':hashlib.sha256(archive.read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
    print('Prepared '+tag+': identical curated notes for GitHub and CurseForge. Nothing published.')
    return metadata,archive,config
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):return None

def resolve_versions(names, token):
    if not names:
        raise ValueError('Choose supported game-version names before uploading.')
    request=urllib.request.Request('https://wow.curseforge.com/api/game/versions',headers={'X-Api-Token':token})
    try:
        with urllib.request.build_opener(NoRedirect).open(request,timeout=30) as response:
            available=json.load(response)
    except Exception:
        raise RuntimeError('Could not retrieve CurseForge game versions. Nothing uploaded; check API access.') from None
    ids=[]
    for name in names:
        matches=[v for v in available if v.get('name')==name]
        if len(matches)!=1 or type(matches[0].get('id'))!=int or matches[0]['id']<=0:
            raise ValueError('CurseForge version is unavailable or ambiguous: '+name)
        ids.append(matches[0]['id'])
    print('Resolved CurseForge versions: '+', '.join(names))
    return ids

def publish(tag,versions,names=None):
    # Publishing always uses a committed tag. Ordinary branches/dirty working trees cannot upload.
    if subprocess.check_output(['git','status','--porcelain'],cwd=ROOT,text=True).strip():raise ValueError('Commit the working tree before publishing.')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
    target=subprocess.check_output(['git','rev-parse',tag+'^{commit}'],cwd=ROOT,text=True).strip()
    if head!=target:raise ValueError('Checkout the release tag before publishing.')
    token=os.environ.get('CURSEFORGE_API_TOKEN')
    if not token:raise ValueError('Set the CURSEFORGE_API_TOKEN environment secret; never put tokens in source or command arguments.')
    metadata,archive,config=prepare(tag)
    ids=versions or config['gameVersionIds'] or resolve_versions(names or config.get('gameVersionNames',[]),token)
    if not ids or any(type(v)!=int or v<=0 for v in ids):raise ValueError('Provide verified CurseForge game-version IDs before uploading.')
    metadata['gameVersions']=ids
    (ROOT/'dist/curseforge-metadata.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
    boundary='sunder-'+uuid.uuid4().hex
    body=(f'--{boundary}\r\nContent-Disposition: form-data; name="metadata"\r\n\r\n'.encode()+json.dumps(metadata).encode()+f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{archive.name}"\r\nContent-Type: application/zip\r\n\r\n'.encode()+archive.read_bytes()+f'\r\n--{boundary}--\r\n'.encode())
    url=f"https://wow.curseforge.com/api/projects/{config['curseforgeProjectId']}/upload-file"
    request=urllib.request.Request(url,data=body,headers={'X-Api-Token':token,'Content-Type':'multipart/form-data; boundary='+boundary},method='POST')
    try:
        with urllib.request.build_opener(NoRedirect).open(request,timeout=120) as response:result=json.load(response)
    except Exception as exc:raise RuntimeError('CurseForge upload failed; no token or server response has been logged. Check the project, token and current upload API endpoint.')from None
    print('CurseForge upload accepted; file ID: '+str(result.get('id','unknown')))
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('command',choices=['prepare','publish']);parser.add_argument('--tag',required=True);parser.add_argument('--game-versions',default='');parser.add_argument('--game-version-names',default='');parser.add_argument('--root',type=Path)
    args=parser.parse_args()
    if args.root:
        ROOT=args.root.resolve();tools.ROOT=ROOT;tools.ADDON=ROOT/'addon/Sunder';tools.COMPAT=ROOT/'compat/ROTBOTForever'
    if args.command=='prepare':prepare(args.tag)
    else:publish(args.tag,[int(v.strip())for v in args.game_versions.split(',')if v.strip()],[v.strip()for v in args.game_version_names.split(',')if v.strip()])
