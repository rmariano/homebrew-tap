class Oscarwatch < Formula
  desc "Desktop satellite tracking for amateur radio operators"
  homepage "https://github.com/rmariano/OscarWatch-Tracker"
  version "1.1.3"

  on_macos do
    on_arm do
      url "https://github.com/magicbug/OscarWatch-Tracker/releases/download/v1.1.3/OscarWatch-1.1.3-osx-arm64.tar.gz"
      sha256 "e3c0a339e29e6af986db7870f486a5fcdcbfb7e3f981986136f73884abacbce3"
    end
  end

  def install
    # OscarWatch is a multi-file self-contained .NET app. All assemblies and runtimes stay in libexec.
    libexec.install Dir["*"]
    (bin/"oscarwatch").write_exec_script libexec/"OscarWatch"
    bin.install_symlink bin/"oscarwatch" => "OscarWatch"
  end

  def post_install
    # 1. Clear quarantine attributes so macOS Gatekeeper does not block native .dylib libraries
    system "xattr", "-dr", "com.apple.quarantine", "#{libexec}" rescue nil

    # 2. Replace / link content at ~/.local/bin
    local_bin = Pathname.new(Dir.home)/".local/bin"
    local_bin.mkpath rescue nil
    if local_bin.exist?
      target = bin/"oscarwatch"
      ["oscarwatch", "OscarWatch"].each do |name|
        link = local_bin/name
        link.unlink if link.exist? || link.symlink?
        link.make_symlink(target) rescue nil
      end
    end

    # 3. Create an alias on the Desktop
    desktop = Pathname.new(Dir.home)/"Desktop"
    if desktop.exist?
      desktop_alias = desktop/"OscarWatch"
      desktop_alias.unlink if desktop_alias.exist? || desktop_alias.symlink?
      target_posix = (bin/"oscarwatch").to_s
      applescript = <<~AS
        tell application "Finder"
          set targetFile to POSIX file "#{target_posix}"
          set destFolder to path to desktop folder
          make new alias file at destFolder to targetFile with properties {name:"OscarWatch"}
        end tell
      AS
      unless system("osascript", "-e", applescript, out: File::NULL, err: File::NULL)
        desktop_alias.make_symlink(bin/"oscarwatch") rescue nil
      end
    end
  end

  def caveats
    <<~EOS
      OscarWatch has been installed!

      Available commands:
        oscarwatch
        ~/.local/bin/oscarwatch

      A shortcut has also been placed on your Desktop:
        ~/Desktop/OscarWatch
    EOS
  end

  test do
    assert_predicate bin/"oscarwatch", :exist?
    assert_predicate bin/"oscarwatch", :executable?
  end
end

