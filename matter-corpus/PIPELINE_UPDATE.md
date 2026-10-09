# Pipeline update: automatic TLC checking and decomposition

## In short

The pipeline now goes all the way from the Matter spec to TLC results. When a model is too big for TLC, the pipeline splits it into smaller pieces automatically, the same way we split the PAFTP model by hand, and checks each piece.

## What changed

### 1. Model checking is part of the pipeline
Every TLA+ model now goes through:
1. **SANY**, the syntax check.
2. **TLC**, with a size limit (maximum number of states and time).

Before this, we ran SANY and TLC by hand.

### 2. Automatic decomposition when the model is too big
If TLC goes over the limit, the pipeline:
1. **Finds how to split the model.** It looks for the variables every part depends on (for PAFTP: `phase` and `pendingEvent`) and the independent groups of the remaining variables.
2. **Writes one smaller model per group** and checks each one with TLC.
3. **Replays every problem found on the original full model**, to make sure it's real.
4. **Writes one combined report.**

It produces the same split we made by hand for PAFTP (Handshake / AckWindow / SDU). It works on any TLA+ model, including the ones the LLM generates, not only our hand-written style.

Small models are still checked whole. Splitting only happens when needed.

### 3. The Colab notebook is now in the repo
The OpenRouter steps from the notebook now run as part of the pipeline: spec context → behaviour JSON → TLA+. The prompts are unchanged; only the hard-coded ArmFailSafe target became a parameter. One addition: a separate LLM call writes the TLC `.cfg` file, because TLC needs one.

## Does the splitting lose anything?
No. We checked it by running both the whole model and the split version, then comparing the findings:

| Model | States (whole model) | States (largest piece) | Findings (whole vs. split) |
|---|---|---|---|
| PAFTP session | 3,598 | 462 | 20 vs. 20 |
| PAFTP, bigger constants | 105,854 | 3,794 (28× smaller) | 20 vs. 20 |
| LLM-style test model | 3,210 | 642 | 3 vs. 3 |

Findings B and C from the earlier session are both found.

## Something new we found
`PacketAcknowledgements.tla` has **4** possible gaps, not 1. Before, TLC stopped at the first problem it hit, so it only ever showed the stale `AckTimeout` case. The pipeline now explores the whole model and also shows:
- `ReceivePacket` arriving when the receive window is full
- `SendPacket` arriving when the send window is full
- a stale `SendAckTimeout`

These still need human review; some may come from how the model was written.

## How to run it
From `matter-corpus/`:

```bash
pip install -r requirements.txt
export OPENROUTER_API_KEY=...        # only needed for the LLM steps

# Full pipeline for one section
python -m src.run_pipeline --sections core_11.10.7.2

# Full pipeline for the top 5 ranked sections
python -m src.run_pipeline --top 5

# Re-check all existing models (no LLM needed)
python -m src.run_pipeline --verify-only

# Check one model
python -m src.verify tla_models/core_4.20.3_session/PAFTPSessionNaive.tla
```

Each check writes a readable `report.md` (and `report.json`) into a `verification/` folder next to the model.

## Limits
- The LLM-generated models don't have the Undefined/Contradictory checks yet, as planned in the notebook. For them, TLC checks `TypeInvariant` and any other invariants listed in their `.cfg`.
- Deadlock is only checked on the whole model, not on the split pieces.
- Only safety invariants are supported; temporal properties are not.
- Needs Java to run SANY/TLC.

## Where the code is
- `src/verify.py`: runs SANY, then TLC, then decomposition if needed, and writes the report.
- `src/decomposition/`: the automatic splitting.
- `src/tla/`: runs SANY/TLC and reads their output.
- `src/generation/`: the notebook steps (OpenRouter).
- `src/run_pipeline.py`: runs everything end to end.
- `tests/test_decomposition.py`: checks that the split never loses or invents a finding.
