class WelcomeController < ApplicationController
  def index; end

  def privacy; end

  # Error handling page with error code and message
  def error
    @error_code = params[:error_code] || params[:errCode]
    @error_message = error_message_for(@error_code)
  end

  private

  # Game session error codes (01002/01003/01004, see
  # docs/REFACTOR_PLAN.md §1.1 and Game::SessionsController) and HTTP-style
  # codes (404/500/403) are all looked up from config/locales/zh-TW.yml;
  # anything not found there falls back to the generic "unknown error" key.
  def error_message_for(code)
    I18n.t("errors.game.#{code}", locale: :"zh-TW", default: nil) ||
      I18n.t("errors.http.#{code}", locale: :"zh-TW", default: nil) ||
      I18n.t("errors.unknown", locale: :"zh-TW")
  end
end
