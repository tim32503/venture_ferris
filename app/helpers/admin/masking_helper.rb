# Personal-data masking for the admin back office (A3 —
# docs/ADMIN_CONSOLE_PLAN.md: "個資遮罩：後台顯示的玩家手機/email 遮罩處理").
# Nothing here ever needs to be reversed — the back office only ever
# *displays* contact info, it never re-sends it — so this is display-only
# masking, not encryption.
module Admin::MaskingHelper
  # "09**-***-***" — keep the leading 2 digits (enough to tell a real
  # Taiwanese mobile number apart from garbage input) and mask the rest.
  # A number that doesn't look like a 10-digit mobile (blank, landline,
  # already-masked, freeform test data) is masked in place instead of
  # forced into that shape, so this never fabricates digits that were
  # never entered.
  def mask_mobile(mobile)
    return nil if mobile.blank?

    digits = mobile.to_s
    return "09**-***-***" if digits.length == 10 && digits.start_with?("0")

    mask_generic(digits)
  end

  # "t***@example.com" — first character of the local part is kept (useful
  # for eyeballing "is this the same player as row above"), the rest of the
  # local part is masked, the domain is left intact since it carries no
  # personal information on its own.
  def mask_email(email)
    return nil if email.blank?

    local, at, domain = email.to_s.partition("@")
    return mask_generic(email) if at.blank?

    masked_local = local.length <= 1 ? "*" : "#{local[0]}#{"*" * (local.length - 1)}"
    "#{masked_local}@#{domain}"
  end

  private

  def mask_generic(value)
    return "*" if value.length <= 1

    "#{value[0]}#{"*" * (value.length - 1)}"
  end
end
