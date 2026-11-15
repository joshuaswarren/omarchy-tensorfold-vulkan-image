# tensorfold-vulkan

This image runs [TensorFold](https://github.com/ashhart/TensorFold)'s native server on the Vulkan driver of Apple Silicon Macs that run Linux.

A GitHub workflow builds it on an arm64 runner. It publishes it to `ghcr.io/joshuaswarren/tensorfold-vulkan`.
[omarchy-local-ai](https://github.com/omacom/omarchy-local-ai) pins it by digest.

## What is inside

- `tensorfold-native`, built with `zig build native-vulkan -Dvulkan=true` from the TensorFold commit in the workflow, with no patches. The commit is the head of the Vulkan pull request stack that ends at ashhart/TensorFold#3401.
- The Vulkan loader and the Arch Linux ARM `vulkan-asahi` driver. That is the driver build Omarchy ships on Apple Silicon.
- curl for the health probe, and TensorFold's license and notices in `/usr/share/licenses/tensorfold`.
- Nothing else. No compiler, no package database.

## Limits

The Vulkan engine serves one model family today: Qwen3.5-2B in MLX 4-bit (group size 64). It runs one stream at a time, decodes greedily, and sees at most 7168 tokens of context.

## Run it

The container needs the host's render node. The driver in the image must match the kernel's GPU interface.

```sh
podman run --rm --device /dev/dri/renderD128 --group-add keep-groups -p 127.0.0.1:8888:8888 \
  -v "$HOME/models/qwen3.5-2b:/models:ro" ghcr.io/joshuaswarren/tensorfold-vulkan@sha256:<digest> \
  tensorfold-native serve /models --backend vulkan --host 0.0.0.0 --port 8888 --context 7168
```

## Update

Change `TENSORFOLD_COMMIT` in `.github/workflows/image.yml` and push to `main`. The run prints the new digest.
