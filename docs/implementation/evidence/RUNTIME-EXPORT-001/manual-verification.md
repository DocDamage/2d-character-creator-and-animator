# Manual Verification

1. Open Batch Export, add character and weapon IDs, choose an output directory,
   export the queue, and inspect status/progress plus artifact validity.
2. Build a package containing clips, a rigged mesh, sprite, marker, collision
   shape, weapon grip, appearance, and runtime tracks. Export it through
   `GodotResourceExporter`, then instance its generated scene in a clean
   consumer project containing only the runtime addon.
3. At runtime, set parameters/facing/equipment, save and restore appearance,
   inspect a grip target, and enable the debug snapshot.
4. Import a `.chrproj` with `ChrprojImporter`; inspect its report before use.
