# DOC-003 Manual Verification Report

## Verification Goal
Verify that `SerializationService.serialize_deterministic()`, `canonicalize()`, `compute_hash()`, and project persistence produce byte-identical output across different dictionary key insertion orders, float precision noise, and line endings.

## Test Scenarios & Results

1. **Key Insertion Order Independence**
   - Created `dict_a` and `dict_b` with keys inserted in different orders.
   - Verified `serialize_deterministic(dict_a) == serialize_deterministic(dict_b)`.
   - Result: PASS.

2. **Nested Structure Canonicalization**
   - Created deeply nested dictionaries and arrays with unordered keys.
   - Verified canonicalization produces sorted keys at every nesting level.
   - Result: PASS.

3. **Float Formatting & Epsilon Normalization**
   - Evaluated float values with epsilon jitter (`1.5000000000000002` vs `1.5`).
   - Verified float values match deterministically.
   - Result: PASS.

4. **Line Ending Normalization**
   - Generated serialized project JSON on Windows OS.
   - Confirmed output contains strictly `\n` line endings without `\r\n`.
   - Result: PASS.

5. **SHA-256 Checksum Calculation**
   - Computed hash via `compute_hash(dict_a)` and `compute_hash(dict_b)`.
   - Confirmed identical 64-character SHA-256 hex output (`hash_a == hash_b`).
   - Result: PASS.

6. **Save-Load Roundtrip Determinism**
   - Computed `hash_orig` for manifest, saved to `.chrproj`, loaded back, and re-computed `hash_reloaded`.
   - Confirmed `hash_orig == hash_reloaded`.
   - Result: PASS.
