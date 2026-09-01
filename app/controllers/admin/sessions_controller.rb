class Admin::SessionsController < Admin::BaseController
  skip_before_action :require_admin, only: [ :new, :create ]
  # Viewer accounts must be able to log in and out like any other admin —
  # the read-only guard only makes sense once a session already exists, and
  # login/logout are themselves POST/DELETE requests that would otherwise be
  # blocked by Admin::BaseController#block_viewer_writes.
  skip_before_action :block_viewer_writes

  def new
  end

  # Deliberately vague on failure: the flash message never reveals whether
  # the email exists, only whether the pair as a whole was valid.
  def create
    admin = Admin.authenticate_by(email: params[:email].to_s, password: params[:password].to_s)

    if admin
      reset_session
      session[:admin_id] = admin.id
      redirect_to admin_root_path, notice: "登入成功"
    else
      flash.now[:alert] = "帳號或密碼錯誤"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to admin_login_path, notice: "已登出"
  end
end
