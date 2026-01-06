cask "gateaway" do
  version "0.2.5"
  sha256 "455398a9225766d90314deba199f9f2e1caa481c3ee1e0d2098df4283625ca3c"

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
