# Task 2.1 transition verification contract

Status: implemented under ADR 0002's model decision, accepted by Matt on
2026-11-16. The cases below define required behaviour; the canonical runner
checks pure transitions and the real QML service. Host close routes also require
loaded-window verification. Engineering evidence and Matt's acceptance remain
separate.

## State boundaries

The model holds input/output EQ intent and per-side provenance separately from
device, volume and mute fixtures. An edit session captures EQ before preview,
then holds inclusion, initial values, current draft and a generation. Save intent
returns the latest validated draft and requested EQ changes; it performs no I/O.

The fixture coordinator owns a separate in-memory profile library, committed EQ,
preview EQ and fake-engine observation. A valid saved profile is not proof that
the requested EQ was applied. A saved-in-memory message is not disk persistence.

## Required regression cases

| Case | Trigger | Required observation |
| --- | --- | --- |
| Included-side merge | Apply a combined profile, then output-only | Input values and provenance unchanged; output replaced |
| Reverse merge | Apply input-only after independently chosen output | Output unchanged |
| Independent copies | Apply/edit from shared source objects | Caller data and factory fixtures remain unchanged |
| Invalid Save | Blank/invalid name, neither side included, malformed EQ | No library or committed-state mutation; draft remains editable |
| Strict profile boundary | Device/volume/mute or unsupported fields supplied | Validation rejects the profile |
| Numerical boundaries | Nonfinite/out-of-range/wrong-count gains | Validation rejects; accepted schema limits come from ADR 0002 |
| Inclusion off | Edit both, then uncheck input | Input preview returns to baseline; output draft retained; input omitted on Save |
| Cancel after manual audio change | Preview EQ, select another fixture device and change volume/mute, Cancel | EQ restored on current device; manual choices preserved |
| Bypass and Flat | Edit a curve; bypass; then Flat | Bypass retains curve; Flat zeroes only gains; Cancel restores baseline |
| Latest draft Save | Move a band immediately before Save | Saved intent includes the last movement, not an older queued preview |
| Stale completion | Delay a preview acknowledgment, Cancel, deliver old acknowledgment | Newer restored state cannot be overwritten |
| Partial application failure | One side succeeds and one fails | Prior applied EQ restored where confirmed; failed restoration remains visibly uncertain |
| Missing fixture device | Save/apply valid profile while one side unavailable | Profile intent retained; that side says waiting, never applied |
| Dirty profile switch | Request another profile with edited draft | Save/Discard/Keep editing resolves before navigation |
| Failed Save with pending navigation | Inject a Save failure | Draft and pending action remain; no navigation or success claim |
| Dirty close routes | In-window Close, host hide, compositor close | Each respects Save/Discard/Keep editing; Keep editing leaves window usable |
| Clean editor departure | Open an existing profile without changing fields, then leave | Any preview baseline is restored before leaving |
| Names as passive data | Markup-shaped display name | Rendered as literal text, never interpreted as markup or a path |

The JS tests must exercise pure transitions against independent expected values,
including frozen inputs. Service/UI verification must establish that the tested
transitions are actually used, especially on all close paths. Existing foundation
checks remain prerequisites.

## Command boundary

Task 2.1 implements `./tools/check --scope model --part transitions`. Full
`--scope model` remains unavailable until Task 2.2's storage checks exist.

Task 2.1's demo lets Matt create/apply/edit input-only, output-only and combined
profiles, test independent labels and Save/Cancel, and change ordinary fixture
controls during an EQ preview. It must continue to state that audio and Save are
simulated. No persistence, production preset tuning, real device access or final
layout selection is part of this task.
