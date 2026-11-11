from pathlib import Path
import subprocess
p=Path('scripts/ui/SettingsTheme.gd');saved=p.read_text()
try:
 s=saved.replace('\tvar roles: Dictionary = PALETTES.resolve(palette_id, high_contrast, colour_preset)','\tvar measured := Time.get_ticks_usec()\n\tvar roles: Dictionary = PALETTES.resolve(palette_id, high_contrast, colour_preset)',1)
 s=s.replace('\tif primary == null: return null','\tprint("SPAN primary " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()\n\tif primary == null: return null',1)
 s=s.replace('\t\tvar companion := TYPOGRAPHY.font(companion_locale, percent, font_style)','\t\tvar started := Time.get_ticks_usec()\n\t\tvar companion := TYPOGRAPHY.font(companion_locale, percent, font_style)\n\t\tprint("SPAN companion " + companion_locale + " " + str(Time.get_ticks_usec() - started))',1)
 for needle,label in [('\tfor role: String in roles:', 'fallbacks'),('\tresult.set_constant("h_separation", "CheckBox", 12)','styles'),('\tresult.set_stylebox("panel", "PopupMenu",', 'icons'),('\treturn result\n\n\nstatic func roles_from_theme','remaining')]:
  s=s.replace(needle,'\tprint("SPAN '+label+' " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()\n'+needle,1)
 p.write_text(s)
 subprocess.run(['python','.godot/ci/settings-open/run.py','theme-profile'],check=True)
finally:p.write_text(saved)
