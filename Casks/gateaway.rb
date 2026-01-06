cask "gateaway" do
  version "0.0.1"
  sha256 "09c5366fd1c801c69af5a14ba44acde342f23303a6744bf28f1405b90c0fc93a"

  url "https://github.com/realdavian/GateAway/releases/download/v#{version}/GateAway.dmg"
  name "GateAway"
  desc "Native macOS menu bar VPN client for VPNGate servers"
  homepage "https://github.com/realdavian/GateAway"

  depends_on macos: ">= :big_sur"

  app "GateAway.app"

  zap trash: [
    "~/Library/Application Support/GateAway",
    "~/Library/Preferences/com.realdavian.GateAway.plist",
    "~/Library/Caches/com.realdavian.GateAway"
  ]
end
