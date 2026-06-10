cask "shiftchange" do
  version "1.1.2"
  sha256 "c023d6c0217a9841c9ccc0495ead0e7fb2bc21072da2799f31ee9957019ebd2e"

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
