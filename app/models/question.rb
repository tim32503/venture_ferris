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

  enum :kind, { puzzle: 0, quiz: 1, bear: 2 }, validate: true

  validates :number, presence: true,
                      uniqueness: true,
                      inclusion: { in: FIRST_NUMBER..LAST_NUMBER }
  validates :title, presence: true
  validates :answer_digest, presence: true
  validates :base_score, numericality: { greater_than: 0 }
  validates :boss_hp, numericality: { greater_than: 0 }
  validates :boss_time_limit, numericality: { greater_than: 0 }

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
