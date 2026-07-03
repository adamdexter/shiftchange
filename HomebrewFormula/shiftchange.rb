cask "shiftchange" do
  version "1.2.1"
  sha256 "36fda5ef6dd795579e5eb9687a67aed6340a401c2f2883e7571dab5da895aa58"

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
