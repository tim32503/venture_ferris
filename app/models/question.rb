require "digest"

# A Question is one of the 11 puzzle stations. The correct answer is never
# stored/rendered in plain text — only a normalized digest is kept so the
# server can verify submissions (REFACTOR_PLAN.md §0: answer checking must
# move server-side).
class Question < ApplicationRecord
  FIRST_NUMBER = 1
  LAST_NUMBER = 11
  DEFAULT_BASE_SCORE = 1000
  DEFAULT_BOSS_HP = 120
  DEFAULT_BOSS_TIME_LIMIT = 30

  # Two questions can share one Boss: Q10/Q11 are phase 1 and phase 2 of the
  # same 摩天輪魔王 (docs/SCHEMA_REDESIGN.md §2-3). `boss_phase` is NULL for
  # every single-phase boss.
  belongs_to :boss

  has_many :question_attempts, dependent: :destroy
  has_many :boss_battles, dependent: :destroy
  # `hints` (not `question_hints`) is the name every caller uses — the hint
  # cap and the hint panel both read `question.hints.size`, so the number of
  # rows here *is* the per-question limit (docs/SCHEMA_REDESIGN.md §2-4).
  has_many :hints, -> { order(:position) },
            class_name: "QuestionHint", inverse_of: :question, dependent: :destroy

  # Backs the admin hint editor's simple add/edit/delete/reorder form
  # (docs/ADMIN_CONSOLE_PLAN.md A4 — "提示子表的新增/修改/刪除/排序，取簡單
  # 實作"). A blank *new* row (no `id`, no `content`) is silently dropped so
  # the form's always-present empty "add a hint" row never creates a
  # spurious blank hint.
  accepts_nested_attributes_for :hints, allow_destroy: true,
    reject_if: ->(attrs) { attrs["id"].blank? && attrs["content"].blank? }

  enum :kind, { puzzle: 0, quiz: 1, bear: 2 }, validate: true

  validates :number, presence: true,
                      uniqueness: true,
                      inclusion: { in: FIRST_NUMBER..LAST_NUMBER }
  validates :title, presence: true
  # Only `quiz` questions store a real answer. Puzzle/bear are "interactive"
  # kinds (see `interactive?` below) whose completion is judged client-side,
  # so they have nothing to hash — `answer_digest` is nullable at the schema
  # level for exactly these two kinds (db/migrate/*_allow_null_answer_digest_
  # on_questions.rb).
  validates :answer_digest, presence: true, if: :quiz?
  validates :base_score, numericality: { greater_than: 0 }
  validates :boss_hp, numericality: { greater_than: 0 }
  validates :boss_time_limit, numericality: { greater_than: 0 }

  # Puzzle and bear questions are "interactive": the interaction itself (a
  # solved jigsaw, or all 5 hotspots in the bear minigame found) IS the
  # answer, judged entirely client-side — exactly like the legacy
  # wheel_puzzle.php/wheel_bear.php pages, which POSTed straight to
  # `timer/Question/:no/End` from their completion callback with no answer
  # text ever compared server-side (wheel_puzzle.php:201-208,
  # wheel_bear.php:206-213). That is also why questions 1, 2 and 9 had an
  # EMPTY `QUESTION_PASSWORD` in the recovered 2018 dump — there was never an
  # authoritative answer text for these two kinds to begin with.
  # `Game::QuestionsController#answer` uses this to skip `answer?` entirely
  # for these two kinds and complete unconditionally once the front-end
  # (puzzle_controller.js / bear_controller.js) says the player is done.
  def interactive?
    puzzle? || bear?
  end

  # Attack count threshold that defeats this question's boss. Kept as a named
  # concept (rather than reading `boss_hp` directly everywhere) because the
  # legacy game conflated "hit points" with "attacks required to win".
  def boss_defeated_threshold
    boss_hp
  end

  # Normalizes a raw answer the same way before hashing and before comparing,
  # so trivial formatting differences (spacing/case/full-width) don't cause
  # false negatives.
  def self.normalize_answer(raw)
    raw.to_s.strip.downcase.gsub(/\s+/, "")
  end

  def self.digest_for(raw)
    Digest::SHA256.hexdigest(normalize_answer(raw))
  end

  def answer?(raw)
    answer_digest == self.class.digest_for(raw)
  end
end
