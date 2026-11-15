# TensorFold's native server on the Vulkan driver of Apple Silicon Macs running Linux.
# The runtime layer holds only what the server needs: the Vulkan loader and the Arch Linux ARM
# `vulkan-asahi` driver (the build Omarchy ships), curl for the health probe, and tensorfold-native.
# The host supplies /dev/dri/renderD*; the kernel's GPU interface and the driver version must match.
FROM scratch AS alarm
ADD ArchLinuxARM-aarch64-latest.tar.gz /
RUN sed -i 's/^CheckSpace/#CheckSpace/; s/^\[options\]/[options]\nDisableSandbox/' /etc/pacman.conf \
 && pacman-key --init && pacman-key --populate archlinuxarm

FROM alarm AS build
ARG TENSORFOLD_REPO
ARG TENSORFOLD_COMMIT
ARG ZIG_VERSION
ARG ZIG_SHA256
RUN pacman -Syu --noconfirm --needed git curl xz glslang vulkan-headers \
 && curl -fsSL -o /zig.tar.xz "https://ziglang.org/download/$ZIG_VERSION/zig-aarch64-linux-$ZIG_VERSION.tar.xz" \
 && echo "$ZIG_SHA256  /zig.tar.xz" | sha256sum -c - \
 && mkdir /zig && tar -C /zig --strip-components=1 -xf /zig.tar.xz \
 && mkdir /src && cd /src && git init -q && git remote add origin "$TENSORFOLD_REPO" \
 && git fetch -q --depth 1 origin "$TENSORFOLD_COMMIT" && git checkout -q FETCH_HEAD \
 && /zig/zig build native-vulkan -Dvulkan=true -Dtarget=aarch64-linux-gnu -Dcpu=apple_m1
RUN mkdir -p /rootfs/var/lib/pacman /rootfs/etc/pacman.d \
 && pacman -r /rootfs --gpgdir /etc/pacman.d/gnupg --config /etc/pacman.conf -Sy --noconfirm --needed \
      filesystem glibc gcc-libs bash coreutils curl ca-certificates vulkan-asahi vulkan-icd-loader \
 && rm -rf /rootfs/var/cache /rootfs/var/lib/pacman/sync /rootfs/usr/share/man /rootfs/usr/share/doc /rootfs/usr/share/info \
 && install -m 0755 /src/zig-out/native/bin/tensorfold-native-vulkan /rootfs/usr/local/bin/tensorfold-native \
 && install -d /rootfs/usr/share/licenses/tensorfold \
 && cp /src/LICENSE /src/NOTICE /src/THIRD_PARTY_NOTICES.md /rootfs/usr/share/licenses/tensorfold/

FROM scratch
COPY --from=build /rootfs /
ENV VK_DRIVER_FILES=/usr/share/vulkan/icd.d/asahi_icd.json
EXPOSE 8888
CMD ["tensorfold-native", "--version"]
