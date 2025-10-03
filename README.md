# FFmpeg Windows Builds

This repository publishes ready-to-use FFmpeg builds for 64-bit Windows.

## Getting the Binaries

- Browse the [Releases](../../releases) page and pick the tag that matches the FFmpeg version you need.
- Download `ffmpeg-<version>.7z` for executable binaries and `ffmpeg-source-<version>.tar.gz` for the exact upstream source tree used in that build.
- Extract the 7z archive with `7z x ffmpeg-<version>.7z` to retrieve `bin/ffmpeg.exe`, `bin/ffprobe.exe`, and supporting libraries. Run `ffmpeg.exe -version` on Windows (or via Wine) to confirm enabled codecs.
