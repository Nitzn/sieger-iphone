"""Fail closed if personal data or generated artifacts enter the cloud source tree."""
from pathlib import Path
import subprocess

def validate(root):
    root=Path(root)
    tracked=subprocess.run(['git','ls-files','-z'],cwd=root,check=True,capture_output=True).stdout.decode('utf-8').split('\0')
    allowed={'README.md','.gitignore','BUILD-STATUS.md'}
    prefixes=('SIEGER/','SIEGER.xcodeproj/','Checks/','scripts/','.github/workflows/')
    forbidden=[]
    for relative in filter(None,tracked):
        lower=relative.casefold()
        if not (relative in allowed or relative.startswith(prefixes)) or any(token in lower for token in (
            'bootstrap.json','research.json','private/','.dpapi','.ipa','.p12','.mobileprovision','hosts.yml','desktop.json')):
            forbidden.append(relative)
    if forbidden:
        raise ValueError('Unexpected or personal files in build source: '+', '.join(forbidden))
    print(f'OK: {sum(bool(p) for p in tracked)} cloud source files; no watchlist/bootstrap/private files.')

if __name__=='__main__':validate(Path(__file__).resolve().parents[1])
