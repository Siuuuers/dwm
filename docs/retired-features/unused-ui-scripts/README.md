# Retired UI scripts

At revision `5481ec1`, no shipped scene, script, or resource referenced these classes by name, path, or Godot resource UID.

| Script | Former purpose |
|---|---|
| `AccessibleButton.gd` | Declared a button label key and an empty accessibility refresh method. |
| `FocusGrid.gd` | Assigned directional focus neighbors to children in a rectangular grid. |
| `SafeImage.gd` | Declared image and placeholder methods with empty bodies and returned an empty missing-art report. |

Their UID sidecars were retired with the scripts. Historical design notes and verification logs still describe the old implementations.

The story host also retired its hidden `ComputerHome` button. It built a desktop theme whenever the host refreshed its presentation. The desktop and Challenge each own their visible Home control and navigation. The removed node held no saved state.
