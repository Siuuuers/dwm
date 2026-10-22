# Ending accessibility publication: next discriminator

This is a read-only source-boundary note after the negative root-order experiment. It does not qualify a runtime change or a new cloud run.

## Observed and unobserved

The corrected experiment's original trace shows the intended scene-root order, a live unwithdrawn Canvas, and normal caption callbacks with the correct name/role on an existing valid element. The original native ending wait still returns zero matching actions and fails. Valid local setters do not establish that the caption is reachable through the accessibility tree submitted for the active window.

The next distinction is therefore specific: **does the emitted or retained accessibility parent-child chain connect the active window root to the current ending caption after the previous SceneHost is retired?**

- An incomplete chain would locate the missing link before native traversal.
- A complete chain, bound to the actual submitted update and its retained ancestor state, would move investigation to adapter/provider delivery.
- A child name/role update alone, a Godot node-order snapshot, or another equivalent Raw/FindAll omission cannot answer this question.

No existing retained record observes these emitted parent-child edges. The current evidence establishes neither branch of this discriminator.

## Inspected primary-source boundary

The coordinator and a separate internal reviewer read the following source at release revision `35e80b3a8822a9df9be390814b62f44c0a9c69e8`:

| Source owner | Observed role | Git blob |
| --- | --- | --- |
| [Node accessibility notification](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/scene/main/node.cpp#L69-L89) | Ordinary parent notification adds child accessibility elements unless its hierarchy is overridden. | `d723df77185ac685c97fb42f63b90b01f874063f` |
| [SceneTree active-window processing and flush](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/scene/main/scene_tree.cpp#L235-L309) | Selects queued valid nodes for the relevant native window, notifies them, then flushes through the active accessibility driver. | `78e2181da18e6792ba51b318365fd4ee5f08a27d` |
| [AccessKit tree construction and adapter handoff](https://github.com/godotengine/godot/blob/35e80b3a8822a9df9be390814b62f44c0a9c69e8/drivers/accesskit/accessibility_driver_accesskit.cpp#L643-L699) | Adds stored child edges to updated nodes, submits those nodes in a tree update, and passes the update through the Windows adapter. | `f0dfc5e056c4cf6341cda93763e294b7e5fe3df6` |

This identifies a code boundary, not the tested binary's defect. The previously retained [engine source identity note](../ending_publication_trace_20261018/engine-source-identity-note.md) still applies: the executable banner reports `4.6.3.stable.official.7d41c59c4`, while the public release revision above is `35e80b3a...`. Relevant file lookups reported matching blobs, but the full build-to-source identity is not independently established. Do not silently replace the engine or describe this source reading as a reproduced engine cause.

## Conditions on any subsequent observation

First state the exact parent edge and state generation being observed, how the active native window and retained ancestor state will be bound, and which possible outcomes discriminate the two branches above. A useful observation must preserve natural update timing and use values already available at the publication boundary. It must not allocate an observation-only accessibility RID, request a refresh, alter acceptance deadlines, or infer UIA RuntimeIds from Godot RIDs.

The project's Godot4.6.3 standard GDScript and cloud-only execution constraints remain in force. No instrumentation or engine modification is included in this note. Do not launch another equivalent ordering, timing, or native hierarchy campaign merely to recover the already retained result. A new measurement needs to resolve this new uncertainty within the established constraints.

External Coordinator C has not reviewed these new runs or this note. The internal review described here is separate.

