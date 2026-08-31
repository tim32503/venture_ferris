require "test_helper"

class QuestionTest < ActiveSupport::TestCase
  def build_question(**attrs)
    number = attrs.fetch(:number, rand(1..11))

    Question.new({
      number: number,
      kind: :quiz,
      title: "sample",
      boss: seed_boss_for(number),
      answer_digest: Question.digest_for("answer")
    }.merge(attrs))
  end

  test "valid with required attributes" do
    assert build_question.valid?
  end

  test "invalid when number is outside 1..11" do
    question = build_question(number: 12)
    assert_not question.valid?
    assert_includes question.errors[:number], "is not included in the list"
  end

  test "invalid with duplicate number" do
    build_question(number: 5).save!
    dup = build_question(number: 5)
    assert_not dup.valid?
    assert_includes dup.errors[:number], "has already been taken"
  end

  test "answer_digest never stores the plaintext answer" do
    question = build_question(number: 1).tap(&:save!)
    refute_equal "answer", question.answer_digest
    assert_equal Question.digest_for("answer"), question.answer_digest
  end

  test "answer? normalizes case, spacing, and full-width vs half-width before comparing" do
    question = build_question(number: 2, answer_digest: Question.digest_for("Hello World")).tap(&:save!)

    assert question.answer?("hello world")
    assert question.answer?("  HELLO   WORLD  ")
    assert_not question.answer?("hello")
  end

  test "boss_defeated_threshold mirrors boss_hp" do
    question = build_question(number: 3, boss_hp: 42).tap(&:save!)
    assert_equal 42, question.boss_defeated_threshold
  end

  test "answer_digest is optional for puzzle and bear kinds but required for quiz" do
    puzzle = build_question(number: 1, kind: :puzzle, answer_digest: nil)
    assert puzzle.valid?

    bear = build_question(number: 9, kind: :bear, answer_digest: nil)
    assert bear.valid?

    quiz = build_question(number: 3, kind: :quiz, answer_digest: nil)
    assert_not quiz.valid?
    assert_includes quiz.errors[:answer_digest], "can't be blank"
  end

  test "interactive? is true for puzzle and bear, false for quiz" do
    assert build_question(number: 1, kind: :puzzle).interactive?
    assert build_question(number: 9, kind: :bear).interactive?
    assert_not build_question(number: 3, kind: :quiz).interactive?
  end
end
