# Audio Workflow Boundaries

`ofxGgmlAudio` owns audio and speech workflows for the ofxGgml ecosystem. This
document is for Codex, GitHub Copilot, Hermes Agent, and human contributors
planning audio-lane work before changing runtime behavior.

## Owned workflow surface

This addon may define:

- Whisper transcription setup, smoke tests, and example handoff paths
- audio preprocessing and postprocessing helpers
- timestamped transcript, SRT, and WebVTT export behavior
- stream chunking, rolling transcript, and overlap-handling workflows
- lightweight VAD, RMS, peak, zero-crossing, and event-detection helpers
- denoising, enhancement, voice conversion, speaker, emotion, and turn-taking
  planning docs
- audio-specific model/tool handoff notes for `ofxGgmlAgents`

## Not owned here

Keep these responsibilities out of `ofxGgmlAudio`:

- ggml setup, backend selection, and runtime discovery owned by `ofxGgmlCore`
- text, vision, video, diffusion, segmentation, music, or RAG model UX
- local model files, sample audio dumps, generated subtitles, build output, or
  downloaded runtime caches
- reusable GitHub Actions policy owned by `ofxGgmlWorkflows`
- generic agent planning loops owned by `ofxGgmlAgents`

## Planning handoff

Before changing audio behavior, write down:

```text
Workflow:
Input media:
Backend or model:
Generated local artifacts:
User-visible output:
Out of scope:
Validation:
```

Prefer documentation, validation, or example scaffolding first. Runtime changes
should name the backend involved, the local artifacts they need, and the
headless smoke test that proves the workflow still works.

## Validation ladder

Use the smallest command that proves the changed layer:

| Change type | Suggested validation |
| --- | --- |
| Docs or planning only | `scripts\validate-local.bat` |
| Whisper setup scripts | `scripts\test-whisper-setup-dry-run.bat` |
| Asset download scripts | `scripts\test-whisper-assets-dry-run.bat` |
| Example launch path | `scripts\test-launch-dry-run.bat` |
| Quickstart path | `scripts\test-transcribe-quickstart-dry-run.bat` |
| Native transcription | `scripts\test-whisper-transcribe.bat` |
| Streaming transcript path | `scripts\test-whisper-chunked-transcribe.bat` |

## Safe first tasks

Good early audio-lane tasks are:

- documenting backend-specific setup decisions
- adding dry-run validation around generated artifacts
- improving quickstart or troubleshooting coverage
- describing how audio tools could be exposed to `ofxGgmlAgents`
- adding deterministic tests for preprocessing and transcript formatting

Avoid broadening runtime behavior until the expected media inputs, generated
artifacts, and validation command are explicit.
