module Game
  # Same inline-SVG QR rendering approach as
  # `Admin::SerialCodesHelper#serial_code_qr_svg` (REFACTOR_PLAN.md P4:
  # "比照 admin helper 範式做一個 game 用 helper"), replacing the legacy
  # `wheel_reward.php`'s now-deprecated Google Image Charts QR endpoint.
  module RewardsHelper
    # Encodes the bare redemption code (not a URL) — this QR is scanned at
    # a prize-redemption booth to read the code itself, unlike the admin
    # helper's login-URL QR.
    def reward_code_qr_svg(reward_code)
      qr = RQRCode::QRCode.new(reward_code.code)

      svg = qr.as_svg(
        module_size: 4,
        standalone: true,
        use_path: true,
        viewbox: true,
        svg_attributes: { class: "qr-code" }
      )
      svg.sub(/\A<\?xml[^>]*\?>\s*/, "").html_safe
    end
  end
end
