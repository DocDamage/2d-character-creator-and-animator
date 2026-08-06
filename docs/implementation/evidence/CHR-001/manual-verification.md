# Manual Verification

1. Open the Character Creator workspace; the Character Creator dock is visible.
2. Bind a part registry, slot registry, body types, and optional weapons through
   `MainWindow.bind_character_creator_context`.
3. Search for a compatible part, activate it, randomize from a chosen seed, then
   use Undo and Redo. The status label reports the outcome or a repair message.
4. Confirm an incompatible or conflicting part is rejected before it changes the
   assembly, with its repair action returned by the model.
