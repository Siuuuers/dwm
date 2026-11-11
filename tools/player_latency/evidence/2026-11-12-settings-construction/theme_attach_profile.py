from pathlib import Path
import subprocess
p=Path('scripts/ui/SettingsContent.gd');saved=p.read_text()
try:
 s=saved.replace('\t\tvar candidate := PRESENTATION._build_context','\t\tvar measured := Time.get_ticks_usec()\n\t\tvar candidate := PRESENTATION._build_context',1)
 s=s.replace('\t\tif candidate == null:','\t\tprint("SPAN theme_build " + str(Time.get_ticks_usec() - measured))\n\t\tif candidate == null:',1)
 s=s.replace('\t\ttheme = candidate','\t\tmeasured = Time.get_ticks_usec()\n\t\ttheme = candidate\n\t\tprint("SPAN theme_attach " + str(Time.get_ticks_usec() - measured))\n\t\tmeasured = Time.get_ticks_usec()',1)
 s=s.replace('\t$Heading/CategoryHeading.add_theme_font_size_override','\t\tprint("SPAN initial_styles " + str(Time.get_ticks_usec() - measured))\n\t$Heading/CategoryHeading.add_theme_font_size_override',1)
 p.write_text(s)
 subprocess.run(['python','.godot/ci/settings-open/run.py','theme-attach-profile'],check=True)
finally:p.write_text(saved)
