cask "shiftchange" do
  version "1.0.0"
  sha256 "077bbff59075742f56ec75cb6a67ab5e3b9039a68e353278b2fdfda959466b55"

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
