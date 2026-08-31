require "test_helper"

class Admin::MaskingHelperTest < ActionView::TestCase
  include Admin::MaskingHelper

  test "mask_mobile keeps the leading 2 digits of a 10-digit mobile" do
    assert_equal "09**-***-***", mask_mobile("0912345678")
  end

  test "mask_mobile falls back to generic masking for non-standard input" do
    assert_equal "0*****", mask_mobile("012345")
  end

  test "mask_mobile returns nil for blank input" do
    assert_nil mask_mobile(nil)
    assert_nil mask_mobile("")
  end

  test "mask_email keeps the first local-part character and the full domain" do
    assert_equal "l*****@example.com", mask_email("leader@example.com")
  end

  test "mask_email handles a single-character local part" do
    assert_equal "*@example.com", mask_email("a@example.com")
  end

  test "mask_email returns nil for blank input" do
    assert_nil mask_email(nil)
    assert_nil mask_email("")
  end
end
