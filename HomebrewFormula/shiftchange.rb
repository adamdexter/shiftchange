cask "shiftchange" do
  version "1.1.1"
  sha256 "b4344b08986de4f087ba6d4a274b1344b6203eb9bd9de4a1a28dab71795c78dc"

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
