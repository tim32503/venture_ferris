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
  before_action :block_viewer_writes

  private

  def current_admin
    @current_admin ||= Admin.find_by(id: session[:admin_id])
  end
  helper_method :current_admin

  def require_admin
    return if current_admin

    redirect_to admin_login_path, alert: "請先登入後台"
  end

  # The viewer role exists so a portfolio visitor can log in with a public,
  # intentionally-published account and actually click around the real back
  # office — but never change anything. Enforcement lives here, at the base
  # controller, rather than as a per-action check in each controller: it
  # blocks by HTTP verb (any non-GET/HEAD request) instead of by listing
  # every write action, so a future controller/action that writes data is
  # covered automatically the moment it inherits from Admin::BaseController,
  # with no extra step to remember. Admin::SessionsController skips this
  # (see its own `skip_before_action`) because a viewer must still be able
  # to log in (POST) and log out (DELETE).
  #
  # This is the actual security boundary for the read-only demo account: the
  # UI hides write forms/buttons for viewers (app/views/admin/**) purely as
  # a UX nicety, but that alone would not stop a direct POST/PATCH/DELETE
  # crafted outside the browser — this before_action does.
  def block_viewer_writes
    return unless current_admin&.viewer?
    return if request.get? || request.head?

    redirect_back fallback_location: admin_root_path, alert: "展示帳號為唯讀模式"
  end
end
