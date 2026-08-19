# All back-office controllers inherit from this and are gated by a real
# server-side session check (REFACTOR_PLAN.md §0: the legacy Admin
# controller had zero server-side auth — any browser could hit
# /admin/home directly). Admin::SessionsController opts out of the
# before_action for :new/:create since you cannot be logged in yet.
#
# NOTE: uses the compact `class Admin::BaseController` form (not
# `module Admin; class BaseController; end; end`) on purpose: the `Admin`
# constant is already a class (app/models/admin.rb), and Ruby's `module`
# keyword refuses to reopen a constant that isn't already a Module. The
# compact form only asserts the *last* segment's type, so it nests fine
# under an existing class. Zeitwerk is fine with either form since Class
# is itself a kind of Module.
class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id])
  end
  helper_method :current_admin

  def require_admin
    return if current_admin

    redirect_to admin_login_path, alert: "請先登入後台"
  end
end
