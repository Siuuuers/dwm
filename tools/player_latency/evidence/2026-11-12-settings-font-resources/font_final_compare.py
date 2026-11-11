from pathlib import Path
import subprocess
p=Path('scripts/ui/UiTypography.gd');candidate=p.read_bytes();base=subprocess.check_output(['git','show','HEAD:'+str(p)])
runner=Path('.godot/ci/settings-open/run.py');saved=runner.read_text()
try:
 runner.write_text(saved.replace('range(2)','range(1)'))
 for i,version in enumerate(['base','candidate','candidate','base']):
  p.write_bytes(base if version=='base' else candidate)
  subprocess.run(['python',str(runner),'font-final-abba-'+str(i)+'-'+version],check=True)
finally:
 p.write_bytes(candidate);runner.write_text(saved)
