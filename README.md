# smol machines Homebrew tap

Homebrew formula for [smolvm](https://github.com/smol-machines/smolvm) — the
OCI-native microVM runtime with sub-200ms boot.

## Install

```sh
brew install smol-machines/tap/smolvm
```

Or tap first, then install (and upgrade later with `brew upgrade smolvm`):

```sh
brew tap smol-machines/tap
brew install smolvm
```

## Supported platforms

| Platform | Notes |
|----------|-------|
| macOS, Apple Silicon | Uses Hypervisor.framework; no extra setup. |
| Linux, x86_64 | Needs access to `/dev/kvm`. |
| Linux, arm64 | Needs access to `/dev/kvm`. |

There is no macOS x86_64 build — smolvm targets Apple Silicon.

## What you get

The formula installs the self-contained release tarball (the `smolvm` wrapper,
its binary, the libkrun libraries, and the guest agent rootfs) into Homebrew's
Cellar and links `smolvm` onto your `PATH`:

```sh
smolvm run alpine echo hello
```
