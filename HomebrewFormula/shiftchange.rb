cask "shiftchange" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

  url "https://github.com/adamdexter/shiftchange/releases/download/v#{version}/ShiftChange-#{version}.dmg"
  name "ShiftChange"
  desc "Menu bar app that auto-disables Night Shift for color-sensitive apps"
  homepage "https://github.com/adamdexter/shiftchange"

  depends_on macos: ">= :ventura"

  app "ShiftChange.app"

  zap trash: [
    "~/Library/Preferences/net.adamdexter.ShiftChange.plist",
  ]
end
