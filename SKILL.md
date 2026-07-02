---
name: Ghost Pepper Dictation
description: |
  Guide setup and usage of Ghost Pepper — a 100% private on-device macOS
  dictation and meeting transcription app powered by WhisperKit and local
  LLMs on Apple Silicon.
---

# Ghost Pepper Dictation

Help the user set up, configure, and get the most out of
[Ghost Pepper](https://github.com/matthartman/ghost-pepper), a free
open-source macOS menu-bar app that provides hold-to-talk dictation and
meeting transcription entirely on-device. No cloud APIs, no data leaves
the machine.

Provenance: this skill was shaped from the public repository
`https://github.com/matthartman/ghost-pepper` (2.8 k stars, MIT license,
Swift/macOS 14+/Apple Silicon).

## When to use this skill

- The user wants to dictate text hands-free on macOS without sending audio
  to any cloud service.
- The user needs to record and transcribe a meeting with AI-generated
  summaries, all processed locally.
- The user is choosing between Ghost Pepper's speech models (Whisper
  tiny/small, Parakeet v3, Qwen3-ASR) or cleanup models (Qwen 3.5 0.8B /
  2B / 4B) and wants guidance.
- The user wants to customize the cleanup prompt, microphone selection,
  hotkey behavior, or launch-at-login settings.
- The user is troubleshooting Gatekeeper warnings, microphone permissions,
  or Accessibility permissions on macOS.

## Required inputs

- **Platform confirmation**: macOS 14.0+ on Apple Silicon (M1 or later).
- **Use-case**: dictation, meeting transcription, or both.
- **Language needs**: English-only, multilingual (≤25 languages via
  Parakeet), or 50+ languages (Qwen3-ASR, requires macOS 15+).

## Workflow

### 1. Installation

1. Download `GhostPepper.dmg` from the latest GitHub release at
   <https://github.com/matthartman/ghost-pepper/releases>.
2. Open the DMG → drag Ghost Pepper to `/Applications`.
3. On first launch, grant **Microphone** and **Accessibility** permissions
   when prompted.
4. If Gatekeeper blocks the app: System Settings → Privacy & Security →
   Open Anyway.

### 2. Speech model selection

Help the user pick the right model for their needs:

| Model | Size | Languages | Notes |
|---|---|---|---|
| Whisper tiny.en | ~75 MB | English only | Fastest, lowest accuracy |
| Whisper small.en | ~466 MB | English only | Default, best English accuracy |
| Whisper small multilingual | ~466 MB | Multiple | Multilingual Whisper |
| Parakeet v3 | ~1.4 GB | 25 languages | High quality multilingual |
| Qwen3-ASR 0.6B int8 | ~900 MB | 50+ languages | Requires macOS 15+ |

### 3. Cleanup model selection

Local LLM removes filler words and handles self-corrections:

| Model | Size | Speed | Quality |
|---|---|---|---|
| Qwen 3.5 0.8B | ~535 MB | Very fast | Good for dictation |
| Qwen 3.5 2B | ~1.3 GB | Fast | Better quality |
| Qwen 3.5 4B | ~2.8 GB | Moderate | Full quality |

### 4. Daily usage — dictation

- Hold **Control** → speak → release to transcribe and auto-paste into the
  active text field.
- The cleanup model removes filler words ("um", "uh") and fixes
  self-corrections automatically.
- The app lives in the menu bar with no dock icon; configure launch at
  login for always-on dictation.

### 5. Meeting transcription

- Start a meeting recording from the menu bar.
- Ghost Pepper captures audio, generates a full transcript, and produces
  an AI summary — all saved as Markdown files.
- Review and export meeting notes directly from the app.

### 6. Customization

- Edit the cleanup prompt to adjust how the LLM processes transcribed text.
- Select your preferred microphone from the settings.
- Toggle individual features on/off as needed.

## Output

Provide the user with:
- A clear installation and setup checklist tailored to their macOS version
  and hardware.
- Model recommendations based on their language needs, disk space, and
  speed preferences.
- Troubleshooting steps for common permission and Gatekeeper issues.
- Tips for optimizing dictation accuracy and meeting transcription quality.

## Key references

- Repository: <https://github.com/matthartman/ghost-pepper>
- README: <https://github.com/matthartman/ghost-pepper/blob/main/README.md>
- Privacy Audit: <https://github.com/matthartman/ghost-pepper/blob/main/PRIVACY_AUDIT.md>
- Releases: <https://github.com/matthartman/ghost-pepper/releases>
