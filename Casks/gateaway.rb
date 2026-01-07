cask "gateaway" do
  version "1.0.3"
  sha256 "7c4371a98e42a0db2af36bf7be7c956c70fa98231cded315c91135263537e4f4"

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
