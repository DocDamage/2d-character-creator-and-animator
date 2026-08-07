# Asset Authoring Guide

Use Character Creator as an imported-artwork assembler: choose a canvas and
slot template, then import individual PNG/WebP/JPEG layers or a folder whose
filenames identify their slots. The project owns a copy of each imported file,
so moving the original outside the project does not break the assembled
character. This workflow deliberately contains no generated characters or
randomized artwork.

Use the layer list for thumbnails, missing-file warnings, ordering, transforms,
locking, visibility, soloing, duplication, replacement, and deletion. Drop a
single file on a selected layer to replace it; drop several files on the preview
to map them by filename. The Asset Browser reports duplicate and missing artwork;
use Repair Missing Artwork to rebase missing files from a selected folder.

Use the Facing Grid dock for directional assets and the Media Authoring dock for
references that must stay excluded from exports. For deformable assets, validate
bone weights before export. The Deformable Mesh sample demonstrates the intended
weighted runtime mapping.

For deformable assets, validate bone weights before export. The Deformable Mesh
sample demonstrates the intended weighted runtime mapping.
