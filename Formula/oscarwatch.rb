class Oscarwatch < Formula
  desc "Desktop satellite tracking for amateur radio operators"
  homepage "https://github.com/rmariano/OscarWatch-Tracker"
  version "1.1.5"

  on_macos do
    on_arm do
      url "https://github.com/magicbug/OscarWatch-Tracker/releases/download/v1.1.5/OscarWatch-1.1.5-osx-arm64.tar.gz"
      sha256 "5c6a0ee78106ea26dc7d793a7adc25cd2473c8bd6d8b04b23f4d88c31baee4a9"
    end
  end

  def install
    # OscarWatch is a multi-file self-contained .NET app. All assemblies and runtimes stay in libexec.
    libexec.install Dir["*"]

    # Do not call write_exec_script on bin/"oscarwatch" — that path is treated as a
    # directory and ends up empty. Write the wrapper file explicitly instead.
    (bin/"oscarwatch").write <<~SH
      #!/bin/bash
      exec "#{libexec}/OscarWatch" "$@"
    SH

    # post_install runs under a sandbox with a fake $HOME, so Desktop / ~/.local/bin
    # writes never reach the real user directories. Ship a helper the user (or
    # post_install best-effort) can run to create those shortcuts against the
    # Cellar binary brew actually installed.
    (bin/"oscarwatch-link").write <<~SH
      #!/bin/bash
      set -euo pipefail

      target="$(brew --prefix oscarwatch)/libexec/OscarWatch"
      if [[ ! -x "$target" ]]; then
        echo "oscarwatch-link: executable not found at $target" >&2
        exit 1
      fi

      # Real home (not a sandbox temp HOME), via the installing user.
      home="$(dscl . -read "/Users/$(id -un)" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
      home="${home:-$HOME}"

      local_bin="$home/.local/bin"
      mkdir -p "$local_bin"
      ln -sfn "$target" "$local_bin/oscarwatch"
      # Case-insensitive volumes treat these as the same path; ignore if so.
      ln -sfn "$target" "$local_bin/OscarWatch" 2>/dev/null || true

      desktop="$home/Desktop"
      if [[ -d "$desktop" ]]; then
        rm -f "$desktop/OscarWatch"
        osascript -e "
          tell application \\"Finder\\"
            set targetFile to POSIX file \\"$target\\"
            set destFolder to path to desktop folder
            make new alias file at destFolder to targetFile with properties {name:\\"OscarWatch\\"}
          end tell
        " >/dev/null || ln -sfn "$target" "$desktop/OscarWatch"
      fi

      echo "Linked OscarWatch -> $target"
      echo "  $local_bin/oscarwatch"
      echo "  $desktop/OscarWatch"
    SH
  end

  def post_install
    # Clear quarantine so Gatekeeper does not block native .dylib libraries.
    # Shortcut creation cannot run here: Homebrew sandboxes post_install with a
    # fake $HOME and blocks writes to the real Desktop / ~/.local/bin.
    # Run `oscarwatch-link` after install (see caveats).
    system "xattr", "-dr", "com.apple.quarantine", libexec.to_s
  end

  def caveats
    <<~EOS
      OscarWatch has been installed!

      Launch with:
        oscarwatch

      Create Desktop + ~/.local/bin shortcuts to the Cellar binary:
        oscarwatch-link
    EOS
  end

  test do
    assert_predicate bin/"oscarwatch", :exist?
    assert_predicate bin/"oscarwatch", :executable?
    assert_predicate bin/"oscarwatch-link", :executable?
    assert_predicate libexec/"OscarWatch", :exist?
    assert_predicate libexec/"OscarWatch", :executable?
  end
end
