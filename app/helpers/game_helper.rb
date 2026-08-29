module GameHelper
  # Chinese display names ↔ enum mapping (REFACTOR_PLAN.md §1.2).
  JOB_LABELS = {
    "uncle" => "阿北",
    "senior" => "鞋姊",
    "netizen" => "鄉民",
    "celebrity" => "罔美"
  }.freeze

  ROLE_LABELS = {
    "leader" => "隊長",
    "member" => "隊員"
  }.freeze

  # Passive effect (always on) + active Boss-fight skill (docs/JOB_SKILLS_DESIGN.md,
  # once per battle via Game::BossesController#skill) for each job. Shared by
  # the job-selection carousel (so picking a job is an informed choice) and
  # the Boss page's skill card (so the card's copy and the server's actual
  # behavior never drift apart from being maintained in two places).
  JOB_SKILLS = {
    "uncle" => { passive: "被動：王戰時限 +10 秒", skill_name: "倚老賣老", skill_description: "本場王戰時限再 +10 秒" },
    "senior" => { passive: "被動：提示不扣分", skill_name: "醍醐灌頂", skill_description: "下一次攻擊必定爆擊，且不受節流限制" },
    "netizen" => { passive: "被動：每次攻擊 +2", skill_name: "肉搜公審", skill_description: "立即造成 5 點傷害" },
    "celebrity" => { passive: "被動：結算加 100 職業分", skill_name: "聚光燈", skill_description: "立即召喚弱點，5 秒內爆擊不受節流限制" }
  }.freeze

  def job_label(job)
    JOB_LABELS.fetch(job.to_s, job.to_s)
  end

  def job_passive_description(job)
    JOB_SKILLS.dig(job.to_s, :passive) || ""
  end

  def job_skill_name(job)
    JOB_SKILLS.dig(job.to_s, :skill_name) || ""
  end

  def job_skill_description(job)
    JOB_SKILLS.dig(job.to_s, :skill_description) || ""
  end

  def role_label(role)
    ROLE_LABELS.fetch(role.to_s, role.to_s)
  end

  # The legacy question views show a clue photo named `P<2-digit number>`
  # (`wheel_question.php:190-195`: zero-padded, `.png`). Puzzle-kind
  # questions (1 and 2) reuse the same numbering but the asset is the
  # original `.jpg` jigsaw source image instead of a `.png` clue photo —
  # see app/assets/images/P01.jpg vs P03.png..P11.png.
  def question_image_filename(question)
    extension = question.puzzle? ? "jpg" : "png"
    format("P%02d.%s", question.number, extension)
  end

  # Base path active_question_poll_controller.js appends a question number
  # onto when it redirects (see `data-active-question-poll-question-base-
  # path-value` in the home/map views). Derived from the real
  # `game_question_path` route rather than hardcoded, so it stays correct
  # if the app is ever mounted under a path prefix.
  def question_redirect_base_path
    game_question_path(Question::FIRST_NUMBER).delete_suffix(Question::FIRST_NUMBER.to_s)
  end
end
