module Game
  # View/controller helpers for the per-question boss fight (legacy
  # `wheel_boss.php` — REFACTOR_PLAN.md §2/P4). Kept out of the shared
  # `GameHelper` (a P3 file) so this batch doesn't have to touch it.
  module BossesHelper
    # Boss time limit + uncle bonus (REFACTOR_PLAN.md §1.2 — the legacy
    # uncle effect was broken by a "false" JSON string always being truthy,
    # so it *always* added the bonus; this ports the intended 30->40s
    # design instead, computed server-side and handed to the view/JS).
    UNCLE_BONUS_SECONDS = 10

    def boss_time_limit_seconds(question, team)
      question.boss_time_limit + (team.players.uncle.any? ? UNCLE_BONUS_SECONDS : 0)
    end

    # Legacy boss sprites are named `mon{01..11}.gif`, zero-padded
    # (REFACTOR_PLAN.md P4 acceptance). Boss #10 has no shipped sprite in
    # this repo's asset set (the P0 batch only copied mon01-09 and mon11 —
    # a gap in the recovered source material, not something fixable here
    # without new artwork), so callers must check `boss_asset_available?`
    # before rendering an `image_tag` for it.
    def boss_image_filename(number)
      format("mon%02d.gif", number)
    end

    def boss_asset_available?(logical_path)
      manifest = Rails.application.assets_manifest
      return true if manifest && manifest.assets[logical_path]

      environment = Rails.application.assets
      environment.present? && environment.find_asset(logical_path).present?
    rescue StandardError
      false
    end

    # Base path `active_question_poll_controller.js` appends a boss number
    # onto when it redirects a teammate whose boss fight has started
    # elsewhere — mirrors `GameHelper#question_redirect_base_path`.
    def boss_redirect_base_path
      game_boss_path(Question::FIRST_NUMBER).delete_suffix(Question::FIRST_NUMBER.to_s)
    end
  end
end
