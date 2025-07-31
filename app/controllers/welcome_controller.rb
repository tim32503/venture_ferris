class WelcomeController < ApplicationController
  def index; end

  def privacy; end

  # Error handling page with error code and message
  def error
    @error_code = params[:error_code] || params[:errCode]
    @error_message = error_message_for(@error_code)
  end

  private

  def error_message_for(code)
    case code
    when "404"
      "頁面不存在"
    when "500"
      "系統錯誤"
    when "403"
      "權限不足"
    else
      "未知錯誤"
    end
  end
end
