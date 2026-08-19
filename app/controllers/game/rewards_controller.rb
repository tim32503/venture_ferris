module Game
  # Contact info + prize redemption (legacy `wheel/reward`, `setInfo`/
  # `getInfo`/`setQRCode`/`getQRCode` — REFACTOR_PLAN.md §2/P4). Redemption
  # codes are allocated in pairs, keyed by email (see
  # `RewardCode.allocate_pair!`), so revisiting this page or re-submitting
  # the allocation always hands back the same two codes instead of drawing
  # more from the pool.
  class RewardsController < BaseController
    def show
      @codes = RewardCode.where(player_email: current_player.email).order(:id)
    end

    # PATCH /game/reward/contact — legacy `setInfo`. Player has no format
    # validation on these fields beyond what's already declared on the
    # model; "填齊" for allocation purposes only requires name + mobile
    # (see `contact_complete?` — gender defaults to "unspecified" and is
    # never itself a blocker).
    def update_contact
      if current_player.update(name: params[:name], mobile: params[:mobile], gender: normalize_gender(params[:gender]))
        redirect_to game_reward_path, notice: "聯絡資訊已更新"
      else
        redirect_to game_reward_path, alert: current_player.errors.full_messages.to_sentence
      end
    end

    # POST /game/reward/codes — legacy `setQRCode`. Refuses until contact
    # info is filled in; the actual atomic/idempotent pairing is delegated
    # to `RewardCode.allocate_pair!`.
    def allocate_codes
      unless contact_complete?
        return redirect_to game_reward_path, alert: "請先填寫聯絡資訊才能兌換獎品"
      end

      RewardCode.allocate_pair!(current_player.email, test_mode: current_team.test_mode)
      redirect_to game_reward_path, notice: "獎品序號已發放"
    rescue ActiveRecord::RecordNotFound
      redirect_to game_reward_path, alert: "獎品序號已發放完畢，請聯繫工作人員"
    end

    private

    def contact_complete?
      current_player.name.present? && current_player.mobile.present?
    end

    # Falls back to the player's existing gender rather than resetting it
    # to "unspecified" when the form is resubmitted without that field set.
    def normalize_gender(raw)
      %w[ male female ].include?(raw.to_s) ? raw.to_s : current_player.gender
    end
  end
end
