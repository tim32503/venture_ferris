module Game
  # Serial-number check-in (legacy `/wheel/login` + `/wheel/register` +
  # `/wheel/updateSNo` — see docs/REFACTOR_PLAN.md §2 and
  # `Wheel_model#checkUserData`/`#registerPlayer`/`#updateSNo`).
  #
  # `new`/`create` run before a player session exists, so they skip the
  # BaseController guard. `update` (account transfer) requires one, since it
  # rebinds the *already signed-in* player to a different team/role.
  class SessionsController < BaseController
    skip_before_action :require_player_session, only: [ :new, :create ]

    ERROR_INVALID_SERIAL = "01002"
    ERROR_INVALID_EMAIL = "01003"
    ERROR_TEAM_FULL = "01004"

    # GET /game/login?sno=&role= — legacy just pre-filled these two params
    # into the page; the actual sign-in form (email/gender) never had a
    # server-rendered counterpart in the legacy app (it was filled in by
    # hand at the check-in desk), so this view is the new, real login form.
    def new
      @serial_no = params[:sno]
      @role = params[:role]
    end

    # POST /game/session — validates against the same rules as
    # `checkUserData`/`registerPlayer` (serial exists & is 16 chars, role is
    # leader/member, email is well-formed, team+role has room) and either
    # finds the already-registered player (idempotent re-login) or creates
    # a new one, then stores the authoritative `player_id` in the session.
    #
    # `demo: "1"` short-circuits all of that: the homepage "Demo" button
    # posts here with that flag to spin up a brand-new, single-player demo
    # team on every click (see `create_demo!`) instead of joining the fixed
    # `Team::DEMO_SERIAL_NO` team from db/seeds.rb. This is what lets any
    # number of public-site visitors demo the game concurrently without
    # fighting over the same 1-leader/3-member roster — a lone player's
    # team always has exactly 1 member, so the Boss "ready" gate
    # (`ready_count >= current_team.players.count`, see
    # Game::BossesController#start_if_all_ready!) is satisfied immediately.
    def create
      return create_demo! if params[:demo].present?

      serial_no = params[:serial_no].to_s
      role = params[:role].to_s.downcase
      email = params[:email].to_s.strip
      gender = normalize_gender(params[:gender])

      team = find_team(serial_no)
      return redirect_error(ERROR_INVALID_SERIAL) if team.nil?
      return redirect_error(ERROR_INVALID_SERIAL) unless Player.roles.key?(role)
      return redirect_error(ERROR_INVALID_EMAIL) unless email.match?(URI::MailTo::EMAIL_REGEXP)

      player = team.players.find_by(role: role, email: email)

      if player
        session[:player_id] = player.id
        return redirect_to game_team_path, notice: "登入成功"
      end

      return redirect_error(ERROR_TEAM_FULL) if team.players.where(role: role).count >= capacity_for(role)

      player = team.players.new(role: role, email: email, gender: gender)

      if player.save
        session[:player_id] = player.id
        redirect_to game_team_path, notice: "登入成功"
      else
        # The only realistic reason `save` fails here (given the checks
        # above already passed) is a capacity/uniqueness race against a
        # concurrent request for the same team+role.
        redirect_error(ERROR_TEAM_FULL)
      end
    end

    # PATCH /game/session — legacy `updateSNo`: re-bind the *currently
    # signed-in* player (identified by email, via `current_player`) onto a
    # different serial number / role, e.g. after the check-in desk issued
    # the wrong wristband. Unlike the legacy version this re-validates team
    # capacity instead of silently bypassing it.
    def update
      new_role = params[:role].to_s.downcase
      new_team = find_team(params[:serial_no].to_s)

      return redirect_error(ERROR_INVALID_SERIAL) if new_team.nil?
      return redirect_error(ERROR_INVALID_SERIAL) unless Player.roles.key?(new_role)

      current_player.team = new_team
      current_player.role = new_role

      if current_player.save
        redirect_to game_team_path, notice: "帳號已轉移"
      else
        redirect_error(ERROR_TEAM_FULL)
      end
    end

    # DELETE /game/session — no direct legacy analog (the legacy site never
    # tore down its session explicitly); mirrors `Admin::SessionsController
    # #destroy`. Requires an active player session same as every other
    # action here (not skipped above), so logging out twice just redirects
    # like any other unauthenticated hit.
    def destroy
      reset_session
      redirect_to root_path, notice: "已登出"
    end

    private

    # A fresh, single-player, `test_mode: true` team + leader for every
    # "Demo" button click (see the `#create` comment above for why). The
    # serial number is random and never shown to the visitor — it exists
    # only to satisfy `Team#serial_no`'s presence/length/uniqueness
    # validations, since a demo player never types one in.
    def create_demo!
      team = Team.create!(
        test_mode: true,
        serial_no: unique_demo_serial_no,
        name: "Demo 體驗隊",
      )
      player = team.players.create!(role: :leader, email: demo_email)

      session[:player_id] = player.id
      redirect_to game_team_path, notice: "已建立全新的單人 Demo 隊伍"
    end

    def unique_demo_serial_no
      loop do
        candidate = SecureRandom.alphanumeric(Team::SERIAL_NO_LENGTH)
        return candidate unless Team.exists?(serial_no: candidate)
      end
    end

    def demo_email
      "demo-#{SecureRandom.hex(8)}@demo.local"
    end

    def find_team(serial_no)
      return nil if serial_no.blank? || serial_no.length != Team::SERIAL_NO_LENGTH

      Team.find_by(serial_no: serial_no)
    end

    def capacity_for(role)
      role == "leader" ? Player::MAX_LEADERS : Player::MAX_MEMBERS
    end

    def normalize_gender(raw)
      %w[ male female ].include?(raw.to_s) ? raw.to_s : "unspecified"
    end

    def redirect_error(code)
      redirect_to error_page_path(error_code: code)
    end
  end
end
