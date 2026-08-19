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

  def job_label(job)
    JOB_LABELS.fetch(job.to_s, job.to_s)
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
