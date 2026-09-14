cask "macpulse" do
  version "1.0.0"
  sha256 "2b7501ebd369ec50b47e65a021c990bd1d4d2b56656e4b389af03067e7d8d1c5"

  url "https://github.com/princepal9120/MacPulse/releases/download/v#{version}/MacPulse-#{version}.dmg"
  name "MacPulse"
  desc "Native macOS system cleaner and deep uninstaller"
  homepage "https://trymacpulse.pages.dev"

  depends_on macos: ">= :tahoe"

  app "MacPulse.app"

  zap trash: [
    "~/Library/Application Support/MacPulse",
    "~/Library/Caches/input.MacPulse",
    "~/Library/Preferences/input.MacPulse.plist",
  ]
end

