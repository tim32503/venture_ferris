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
    # 01004 is the legacy code/message (leader slot taken). 01005 is a
    # refactor-added refinement: the legacy site reused 01004 for a full
    # member roster, showing the leader-specific message to members.
    ERROR_LEADER_FULL = "01004"
    ERROR_MEMBER_FULL = "01005"
    # 01006 is new with docs/SCHEMA_REDESIGN.md §2-7d: the `[team_id, email]`
    # unique index means one email is one seat on a team, so re-registering
    # the same address under the other role is now refused instead of quietly
    # consuming a second slot. It is its own code because "this address is
    # already on this team" is not "this team is full" — and the error page's
    # 帳號轉移 button is the actual fix for it.
    ERROR_EMAIL_TAKEN = "01006"

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

      # Checked *before* capacity (docs/SCHEMA_REDESIGN.md §7): an address
      # that is already on this team under the other role is a duplicate
      # identity, not a full roster, and reporting it as 01004/01005 would
      # send the player looking for a seat that is not the problem.
      return redirect_error(ERROR_EMAIL_TAKEN) if team.players.exists?(email: email)

      return redirect_error(capacity_error_for(role)) if team.players.where(role: role).count >= capacity_for(role)

      player = team.players.new(role: role, email: email, gender: gender)

      begin
        saved = player.save
      rescue ActiveRecord::RecordNotUnique
        # Lost a race for the same team+email against a concurrent request:
        # the `[team_id, email]` index is the only one a brand-new player can
        # violate here (its job is still nil), so this is the same situation
        # as the guard above, just decided by PostgreSQL instead.
        return redirect_error(ERROR_EMAIL_TAKEN)
      end

      if saved
        session[:player_id] = player.id
        redirect_to game_team_path, notice: "登入成功"
      else
        # The only realistic reason `save` fails here (given the checks
        # above already passed) is a capacity race against a concurrent
        # request for the same team+role.
        redirect_error(capacity_error_for(role))
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

      # 7d: transferring onto a team that already knows this address would
      # need a second row for one person on one team, which the
      # `[team_id, email]` index forbids.
      if new_team.id != current_player.team_id && new_team.players.exists?(email: current_player.email)
        return redirect_error(ERROR_EMAIL_TAKEN)
      end

      current_player.team = new_team
      current_player.role = new_role

      begin
        saved = current_player.save
      rescue ActiveRecord::RecordNotUnique
        # Two indexes can reject a transfer that got past the checks above:
        # `[team_id, email]` on a race, and 7b's `[team_id, job]` when this
        # player's job is already held on the destination team. Both fall
        # through to the same "transfer refused" page the pre-existing
        # validation-failure branch used.
        saved = false
      end

      if saved
        redirect_to game_team_path, notice: "帳號已轉移"
      else
        redirect_error(capacity_error_for(new_role))
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
      # Name is intentionally left blank so the demo leader goes through the
      # normal naming step (the team page only renders the naming form — and
      # its redirect onward to job selection — while the name is blank).
      team = Team.create!(
        test_mode: true,
        serial_no: unique_demo_serial_no,
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

    def capacity_error_for(role)
      role == "leader" ? ERROR_LEADER_FULL : ERROR_MEMBER_FULL
    end

    def normalize_gender(raw)
      %w[ male female ].include?(raw.to_s) ? raw.to_s : "unspecified"
    end

    def redirect_error(code)
      redirect_to error_page_path(error_code: code)
    end
  end
end
