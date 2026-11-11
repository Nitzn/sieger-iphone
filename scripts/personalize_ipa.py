"""Embed a local public-research snapshot AFTER cloud building, BEFORE personal signing."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import zipfile

MAX_SNAPSHOT=20_000_000

def personalize(source, snapshot, out):
    source, snapshot, out=Path(source),Path(snapshot),Path(out)
    if source.resolve()==out.resolve():
        raise ValueError('Output must differ from input IPA')
    if snapshot.stat().st_size>MAX_SNAPSHOT:
        raise ValueError('Snapshot larger than 20 MB')
    with snapshot.open('rb') as stream:
        data=stream.read(MAX_SNAPSHOT+1)
    if len(data)>MAX_SNAPSHOT:
        raise ValueError('Snapshot larger than 20 MB')
    value=json.loads(data)
    if value.get('schema_version')!=1 or not isinstance(value.get('instruments'),list):
        raise ValueError('Unsupported research snapshot')
    with zipfile.ZipFile(source) as archive:
        entries=archive.infolist()
        manifests=[e for e in entries if e.filename.startswith('Payload/') and e.filename.count('/')==2 and e.filename.endswith('.app/Info.plist')]
        if len(manifests)!=1:
            raise ValueError('Expected one iPhone app')
        info=plistlib.loads(archive.read(manifests[0]))
        if info.get('CFBundleSupportedPlatforms')!=['iPhoneOS'] or info.get('CFBundleIdentifier')!='de.sieger.research':
            raise ValueError('Not a SIEGER physical-device build')
        app=manifests[0].filename.rsplit('/',1)[0]
        if any(e.filename.startswith('/') or '..' in e.filename.split('/') or '\\' in e.filename for e in entries):
            raise ValueError('Invalid archive paths')
        if len({e.filename for e in entries})!=len(entries):
            raise ValueError('Duplicate archive paths')
        if sum(e.file_size for e in entries)>500_000_000:
            raise ValueError('App archive too large')
        out.parent.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED) as destination:
            for entry in entries:
                if entry.filename==app+'/Bootstrap.json' or '/_CodeSignature/' in entry.filename or entry.filename.endswith('/embedded.mobileprovision'):
                    continue
                with archive.open(entry) as incoming,destination.open(entry,'w') as outgoing:
                    shutil.copyfileobj(incoming,outgoing)
            destination.writestr(app+'/Bootstrap.json',data)
    return out

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa',type=Path,required=True)
    parser.add_argument('--snapshot',type=Path,required=True)
    parser.add_argument('--out',type=Path,required=True)
    args=parser.parse_args();print(personalize(args.ipa,args.snapshot,args.out))
