# Recon Orchestrator Task

## Variables

### prompt

{{prompt}}

### previous_envelope

{{previous_envelope}}

### context_handoff_dir

{{context_handoff_dir}}

## Task

Merge the recon's interval checkpoints (in `context_handoff_dir`) into the
finished map that `prompt` asks for. Write the final report where `prompt`
says, then emit your `Report` JSON.

## Report

Respond with ONLY valid JSON matching the shape `prompt` specifies — no prose
before or after.