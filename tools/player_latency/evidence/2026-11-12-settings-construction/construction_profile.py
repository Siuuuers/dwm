from pathlib import Path
import subprocess
p=Path('scripts/ui/SettingsContent.gd');saved=p.read_text()
try:
 s=saved.replace('\t_build_content()\n\trefresh_labels()', '\tvar measured := Time.get_ticks_usec()\n\t_build_content()\n\tprint("SPAN build " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()\n\trefresh_labels()\n\tprint("SPAN labels " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()',1)
 s=s.replace('\t_controller.bind(self, _services)','\t_controller.bind(self, _services)\n\tprint("SPAN bind " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()',1)
 s=s.replace('\tselect_category("language")','\tselect_category("language")\n\tprint("SPAN select " + str(Time.get_ticks_usec() - measured))',1)
 p.write_text(s)
 subprocess.run(['python','.godot/ci/settings-open/run.py','construction-profile'],check=True)
finally:p.write_text(saved)
