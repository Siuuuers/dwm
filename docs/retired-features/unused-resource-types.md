# Unused Resource types

Revision `86c50e5` included six editor-visible Resource classes with exported data fields: `AudioCueData`, `BgmTrackData`, `ChatMessageData`, `EffectData`, `InvitationData`, and `StatValue`. No game scene, saved resource, runtime loader, or authoring tool instantiated them. The Windows “all resources” preset included their scripts in the game pack.

The music catalog resolves tracks through `AudioManifest`. Game saves and Global history persist JSON. `DataCatalog` still constructs the two Resource types the game uses, `ShopItemData` and `MinesweeperTaskData`.
