class Smolvm < Formula
  desc "OCI-native microVM runtime with sub-200ms boot"
  homepage "https://github.com/smol-machines/smolvm"
  version "1.5.0"
  license "Apache-2.0"

  # smolvm formats ext4 storage disks with mkfs.ext4, which isn't native on macOS.
  depends_on "e2fsprogs"

  # Prebuilt, self-contained release tarballs (wrapper + binary + libs +
  # agent-rootfs). One per platform; unsupported platforms simply have no url so
  # `brew install` fails cleanly there (and `brew tap` never parse-errors).
  on_macos do
    on_arm do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-darwin-arm64.tar.gz"
      sha256 "a79a9864397ccc3f987fec5c2a584d759b5f115e6e88815b5392b4007f8bb671"
    end
    # No macOS x86_64 build — smolvm targets Apple Silicon (Hypervisor.framework).
  end

  on_linux do
    on_arm do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-linux-arm64.tar.gz"
      sha256 "f3e339635359b29cb60407e5d7deac3d4199870d8af2034c37c74f0f1c5530e8"
    end
    on_intel do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-linux-x86_64.tar.gz"
      sha256 "986bc230befea542af18d85a849fca056a18d728c9c7b75cfca382adb0fe1a64"
    end

    # The Linux libkrun.so.1 ships without a RUNPATH, so smolvm-bin can't find
    # its bundled libs or Homebrew's libbz2 at startup (reported as
    # "libbz2.so.1.0 => not found" on Fedora). Patch the rpath at install time.
    depends_on "patchelf" => :build
    depends_on "bzip2"
  end

  def install
    libexec.install Dir["*"]

    # The wrapper resolves its own symlink to locate libexec (binary, libs, and
    # the agent-rootfs it exports as SMOLVM_AGENT_ROOTFS), so a plain bin symlink
    # is enough — no manual rootfs copy needed.
    bin.install_symlink libexec/"smolvm"

    return unless OS.linux?

    system "patchelf", "--set-rpath", "#{libexec}/lib:#{HOMEBREW_PREFIX}/lib",
                       libexec/"lib/libkrun.so.1"
  end

  def caveats
    <<~EOS
      smolvm runs real microVMs, so it needs hardware virtualization:
        - macOS: Hypervisor.framework (macOS 11+ on Apple Silicon) — no extra setup.
        - Linux: access to /dev/kvm. Add yourself to the kvm group if needed:
            sudo usermod -aG kvm "$USER"   # then log out and back in

      Get started:
        smolvm run alpine echo hello
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/smolvm --version")
  end
end
