class Smol < Formula
  desc "The agent's computer: branchable microVMs on your machine and in the cloud"
  homepage "https://smolmachines.com"
  version "1.29.1"
  license "Apache-2.0"

  # smol formats ext4 storage disks with mkfs.ext4, which isn't native on macOS.
  depends_on "e2fsprogs"

  # Prebuilt, self-contained release tarballs: wrapper + binary (with the engine
  # embedded) + libkrun/libkrunfw + the agent rootfs. One per platform.
  on_macos do
    on_arm do
      url "https://github.com/smol-machines/smol/releases/download/v#{version}/smol-#{version}-darwin-arm64.tar.gz"
      sha256 "fce580293d373b57808047d455e3200be172e12b40e369b6eb655412e6e1144a"
    end
    # No macOS x86_64 build: smol targets Apple Silicon (Hypervisor.framework).
  end

  on_linux do
    on_arm do
      url "https://github.com/smol-machines/smol/releases/download/v#{version}/smol-#{version}-linux-arm64.tar.gz"
      sha256 "57559dad1cb3a9cb6a8430f9a91329f6f1ddb22b4ad77bd916d5009b7bf8a446"
    end
    on_intel do
      url "https://github.com/smol-machines/smol/releases/download/v#{version}/smol-#{version}-linux-x86_64.tar.gz"
      sha256 "7cdf7dfd29241d3511c23f3c9e0b7c6b6abc44ef16119ca6c580f47623a910df"
    end

    # The Linux libkrun.so ships without a RUNPATH, so the binary can't find the
    # bundled libs or Homebrew's libbz2 at startup. Patch the rpath at install time.
    depends_on "patchelf" => :build
    depends_on "bzip2"
  end

  def install
    libexec.install Dir["*"]

    # The wrapper resolves its own symlink to locate libexec (binary, libs and
    # the agent rootfs it exports as SMOLVM_AGENT_ROOTFS), so a bin symlink is enough.
    bin.install_symlink libexec/"smol"

    return unless OS.linux?

    system "patchelf", "--set-rpath", "#{libexec}/lib:#{HOMEBREW_PREFIX}/lib",
                       libexec/"lib/libkrun.so.2"
  end

  # Homebrew's dylib relocation rewrites some bundled sibling references to
  # absolute /opt/homebrew paths that do not exist on the user's machine. Point
  # every dependency that has a bundled sibling back to @loader_path and re-sign.
  def post_install
    return unless OS.mac?

    lib = libexec/"lib"
    bundled = Dir[lib/"*.dylib"].map { |f| File.basename(f) }
    Dir[lib/"*.dylib"].each do |dylib|
      changed = false
      MachO.open(dylib).linked_dylibs.each do |dep|
        next if dep.start_with?("@")

        base = File.basename(dep)
        next unless bundled.include?(base)

        MachO::Tools.change_install_name(dylib, dep, "@loader_path/#{base}")
        changed = true
      end
      MachO.codesign!(dylib) if changed
    end
  end

  def caveats
    <<~EOS
      smol runs real microVMs, so it needs hardware virtualization:
        - macOS: Hypervisor.framework (macOS 11+ on Apple Silicon), no extra setup.
        - Linux: access to /dev/kvm. Add yourself to the kvm group if needed:
            sudo usermod -aG kvm "$USER"   # then log out and back in

      Get started:
        smol run python:3.12 -- python -c 'print("hello from a microVM")'
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/smol --version")
  end
end
