class JournalDaemon < Formula
  desc "Build and bootstrap the Journal Daemon macOS command-line agent"
  homepage "https://guerrerocarlos.github.io/journal-daemon/"
  head "git@github.com:guerrerocarlos/journal-daemon.git", branch: "main"

  depends_on :macos
  uses_from_macos "swift" => :build

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/journal-daemon"
    pkgshare.install "config/config.example.json"
  end

  test do
    assert_match "journal-daemon", shell_output("#{bin}/journal-daemon version")
    system bin/"journal-daemon", "config", "validate", "--config",
           pkgshare/"config.example.json"
  end
end
