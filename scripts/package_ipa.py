"""Create a device-only, unsigned IPA for personal signing. Does not sign or publish."""
import argparse
import plistlib
from pathlib import Path
import zipfile

def package(app, out):
    app, out = Path(app), Path(out)
    with (app/'Info.plist').open('rb') as stream:
        info=plistlib.load(stream)
    if info.get('CFBundleSupportedPlatforms') != ['iPhoneOS']:
        raise ValueError('Only a physical iPhone build can be packaged; simulator rejected.')
    executable=app/info['CFBundleExecutable']
    if not executable.is_file():
        raise ValueError('App executable missing')
    out.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(out,'w',compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(app.rglob('*')):
            if path.is_file():
                archive.write(path,Path('Payload')/app.name/path.relative_to(app))
    return out

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('app',type=Path);parser.add_argument('out',type=Path)
    args=parser.parse_args();package(args.app,args.out)
