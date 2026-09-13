cask "macpulse" do
  version "1.0.0"
  sha256 "19d8403a71451aa5ba34aec2510478cb6e14640119f78073f2f73d2aff85fe86"

  url "https://github.com/princepal9120/MacPulse/releases/download/v#{version}/MacPulse-#{version}.dmg"
  name "MacPulse"
  desc "Native macOS system cleaner and deep uninstaller"
  homepage "https://trymacpulse.pages.dev"

  depends_on macos: ">= :sonoma"

  app "MacPulse.app"

  zap trash: [
    "~/Library/Application Support/MacPulse",
    "~/Library/Caches/com.princepal.MacPulse",
    "~/Library/Preferences/com.princepal.MacPulse.plist",
  ]
end

