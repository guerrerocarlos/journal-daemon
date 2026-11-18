class JournalDaemon < Formula
  desc "Build and bootstrap the Journal Daemon macOS command-line agent"
  homepage "https://guerrerocarlos.github.io/journal-daemon/"
  head "https://github.com/guerrerocarlos/journal-daemon.git", branch: "main"

  depends_on :macos
  uses_from_macos "swift" => :build

  def install
    system "swift", "build", "--configuration", "release", "--disable-sandbox"
    bin.install ".build/release/journal-daemon"
    pkgshare.install "config/config.example.json"
  end

  service do
    run [opt_bin/"journal-daemon", "run", "--config", "#{Dir.home}/.config/journal-daemon/config.json"]
    keep_alive true
    process_type :background
    log_path "#{Dir.home}/Library/Logs/com.guerrerocarlos.journal-daemon/service.log"
    error_log_path "#{Dir.home}/Library/Logs/com.guerrerocarlos.journal-daemon/service-error.log"
  end

  test do
    assert_match "journal-daemon", shell_output("#{bin}/journal-daemon version")
    assert_match "Glass", shell_output("#{bin}/journal-daemon bell sounds")
    system bin/"journal-daemon", "config", "validate", "--config",
           pkgshare/"config.example.json"
  end
end
