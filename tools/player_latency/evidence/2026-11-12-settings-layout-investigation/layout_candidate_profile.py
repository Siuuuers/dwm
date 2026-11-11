from pathlib import Path
import subprocess
p=Path('scripts/ui/SettingsContent.gd');saved=p.read_text()
try:
 s=saved.replace('func apply_text_size(percent: int, large_targets: bool) -> void:\n','func apply_text_size(percent: int, large_targets: bool) -> void:\n\tvar measured := Time.get_ticks_usec()\n')
 for needle,label in [('\t$Heading/CategoryHeading.add_theme_font_size_override','theme'),('\tvar sample_copy: Array','controls_sheet'),('\tfor path: StringName in controls:\n\t\tvar control: Control = controls[path]\n\t\tif control is OptionButton:','font_overrides'),('\tfor button: Button in _rails.values():\n\t\tvar label := button.get_child(0) as Label','values'),('\tfor dialog: ConfirmationDialog in confirmations.values():\n\t\tdialog.set_presentation','rails'),('\tqueue_redraw()\n\t_selected_extension.queue_redraw()','dialogs')]:
  s=s.replace(needle,'\tprint("SPAN '+label+' " + str(Time.get_ticks_usec() - measured))\n\tmeasured = Time.get_ticks_usec()\n'+needle,1)
 p.write_text(s)
 subprocess.run(['python','.godot/ci/settings-open/run.py','layout-cand-profile'],check=True)
finally:p.write_text(saved)
