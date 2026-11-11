"""Release safety checks; no network requests or real uploads."""
from pathlib import Path
import importlib.util, json, hashlib, unittest
from unittest.mock import patch, MagicMock
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('release_tools',ROOT/'tools/release.py')
release=importlib.util.module_from_spec(spec);spec.loader.exec_module(release)
class ReleaseTests(unittest.TestCase):
    def test_notes_and_preparation(self):
        with patch.object(release.urllib.request,'build_opener',side_effect=AssertionError('No network during preparation')):
            metadata,archive,config=release.prepare('v'+release.tools.version())
        self.assertEqual(config['curseforgeProjectId'],1798860)
        self.assertEqual(archive.name,'Sunder-'+release.tools.version()+'.zip')
        self.assertIn('Rebrand',metadata['changelog'])
        self.assertNotIn('Record player-facing',metadata['changelog'])
        self.assertNotIn('# 0.9.10',metadata['changelog'])
        manifest=json.loads((ROOT/'dist/release-manifest.json').read_text())
        self.assertEqual(manifest['sha256'],hashlib.sha256(archive.read_bytes()).hexdigest())
    def test_version_guards(self):
        with self.assertRaises(ValueError):release.prepare('v0.0.0')
        with self.assertRaises(ValueError):release.notes('0.0.0')
    def test_dirty_publish_blocked(self):
        with patch.object(release.subprocess,'check_output',return_value=' M file'),self.assertRaises(ValueError):
            release.publish('v0.9.11',[1])
    def test_missing_token_blocked(self):
        with patch.object(release.subprocess,'check_output',side_effect=['','abc','abc']),patch.dict(release.os.environ,{},clear=True),self.assertRaises(ValueError):
            release.publish('v0.9.11',[1])
    def test_missing_versions_blocked(self):
        with patch.object(release.subprocess,'check_output',side_effect=['','abc','abc']),patch.dict(release.os.environ,{'CURSEFORGE_API_TOKEN':'fixture-not-a-secret'}),patch.object(release,'prepare',return_value=({},None,{'gameVersionIds':[]})),patch.object(release.urllib.request,'build_opener',side_effect=AssertionError('Must not upload')),self.assertRaises(ValueError):
            release.publish('v0.9.11',[])
    def test_live_version_lookup(self):
        response=MagicMock()
        response.__enter__.return_value.read.return_value=b'[{"id":9876,"name":"1.60.1"},{"id":9999,"name":"12.0.0"}]'
        opener=MagicMock();opener.open.return_value=response
        with patch.object(release.urllib.request,'build_opener',return_value=opener):
            self.assertEqual(release.resolve_versions(['1.60.1'],'fixture'),[9876])
            with self.assertRaises(ValueError):release.resolve_versions(['1.60.2'],'fixture')
        request=opener.open.call_args.args[0]
        self.assertNotIn('fixture',request.full_url)
    def test_ambiguous_version_rejected(self):
        response=MagicMock()
        response.__enter__.return_value.read.return_value=b'[{"id":1,"name":"1.60.1"},{"id":2,"name":"1.60.1"}]'
        opener=MagicMock();opener.open.return_value=response
        with patch.object(release.urllib.request,'build_opener',return_value=opener),self.assertRaises(ValueError):
            release.resolve_versions(['1.60.1'],'fixture')
if __name__=='__main__':unittest.main()
