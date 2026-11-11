# Unused caption glossary and text-entry widgets

Removed layers 14 (Glossary popup) and 16 (TextInput prompt) from the Witnessed
Caption style on 12 November 2026. No configured glossary resources, authored
text-input events, or application calls to these features were found. Current
Scene compilation rejects native TextInput events. Neither widget owns save data.

This removes hidden UI construction, glossary hover listeners and its per-frame
callback, plus the unused text-entry node and its signals. Keep addon modules,
subsystem registration, example styles, Choices, and all remaining layer IDs.

The trimmed witnessed style does not support glossary hover popups or native
text-entry prompts. If those features are authored later, supply their UI first:
a native TextInput event without an input widget would wait for confirmation.
This does not alter addon behavior or remove an approved current player feature.
