# Compact form because `Admin` is already a class (app/models/admin.rb) —
# see the comment in app/controllers/admin/base_controller.rb for why
# `module Admin; module SerialCodesHelper; end; end` would raise.
module Admin::SerialCodesHelper
  # Renders a QR code as inline SVG for the given team, encoding the same
  # game login URL a printed ticket would carry. Replaces the legacy
  # admin_home.php's use of Google's now-deprecated "Image Charts" QR
  # endpoint with a locally-rendered SVG.
  def serial_code_qr_svg(team)
    url = game_login_url(sno: team.serial_no, role: "leader")
    qr = RQRCode::QRCode.new(url)

    # `standalone: true` is what makes rqrcode emit the wrapping <svg>...
    # </svg> tag (with `false` it only emits the bare <path>); it also
    # prepends an `<?xml ...?>` prologue we don't want inline in HTML, so
    # that prefix is stripped back off.
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
