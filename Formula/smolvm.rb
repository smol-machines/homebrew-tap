class Smolvm < Formula
  desc "Branchable microVMs for AI agents"
  homepage "https://github.com/smol-machines/smolvm"
  version "1.27.4"
  license "Apache-2.0"

  # smolvm formats ext4 storage disks with mkfs.ext4, which isn't native on macOS.
  depends_on "e2fsprogs"

  # Prebuilt, self-contained release tarballs (wrapper + binary + libs +
  # agent-rootfs). One per platform; unsupported platforms simply have no url so
  # `brew install` fails cleanly there (and `brew tap` never parse-errors).
  on_macos do
    on_arm do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-darwin-arm64.tar.gz"
      sha256 "4c4940f5c4631ef3aff82b6da6f7f99befd3e216fdf4131dce53a5eb58786421"
    end
    # No macOS x86_64 build — smolvm targets Apple Silicon (Hypervisor.framework).
  end

  on_linux do
    on_arm do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-linux-arm64.tar.gz"
      sha256 "a1e299e02e4ec2e61edc79fb8d48e2a37d68578d17ef311b88ce3fd416be008c"
    end
    on_intel do
      url "https://github.com/smol-machines/smolvm/releases/download/v#{version}/smolvm-#{version}-linux-x86_64.tar.gz"
      sha256 "15e9fa132569709ee4b25f02f7d5f859f2f826f03fe118f8cce6b001f0f1d934"
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

  # The release tarball's dylibs are already self-contained (@rpath / @loader_path
  # sibling references). Homebrew's automatic dylib relocation, however, rewrites
  # some of those sibling refs (libepoxy, virglrenderer) to absolute
  # /opt/homebrew/opt/<formula>/lib paths — which point at formulae/taps the user
  # doesn't have (hence the "requires the tap slp/krun" warning) and only resolve
  # on a machine that happens to have those libs installed. Re-point every
  # dependency that has a bundled sibling back to @loader_path so the bundle is
  # self-contained again, then re-sign (relocation invalidated the ad-hoc
  # signature). Runs after Homebrew's relocation, so it's the last word.
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
      # ruby-macho invalidates the ad-hoc signature; re-sign so dyld will load it.
      MachO.codesign!(dylib) if changed
    end
  end

  def caveats
    <<~EOS
      smolvm runs real microVMs, so it needs hardware virtualization:
        - macOS: Hypervisor.framework (macOS 11+ on Apple Silicon) — no extra setup.
        - Linux: access to /dev/kvm. Add yourself to the kvm group if needed:
            sudo usermod -aG kvm "$USER"   # then log out and back in

      Get started:
        smolvm machine run --net --image alpine -- echo hello
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/smolvm --version")
  end
end
