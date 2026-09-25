cask "macpulse" do
  version "1.0.1"
  sha256 "39c7a28abaaff091997ace83fe2425516ceca592bafd67772ec6fd85d5c76301"

  url "https://github.com/princepal9120/MacPulse/releases/download/v#{version}/MacPulse-#{version}.dmg"
  name "MacPulse"
  desc "Native system cleaner and deep uninstaller"
  homepage "https://trymacpulse.pages.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :tahoe

  app "MacPulse.app"

  # Homebrew sets the download quarantine xattr (0181), which makes macOS 26
  # refuse to launch this ad-hoc-signed app ("Not Opened", no override).
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-cr", "{{appdir}}/MacPulse.app"]
  end

  zap trash: [
    "~/Library/Application Support/MacPulse",
    "~/Library/Caches/input.MacPulse",
    "~/Library/Preferences/input.MacPulse.plist",
  ]
end
