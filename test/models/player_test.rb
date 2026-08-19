require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  def build_team
    Team.create!(serial_no: SecureRandom.alphanumeric(16), test_mode: false)
  end

  def build_player(team, **attrs)
    Player.new({
      team: team,
      role: :member,
      email: "player-#{SecureRandom.hex(4)}@example.com",
      gender: :unspecified
    }.merge(attrs))
  end

  test "valid with a well-formed email" do
    player = build_player(build_team)
    assert player.valid?
  end

  test "invalid with a malformed email" do
    player = build_player(build_team, email: "not-an-email")
    assert_not player.valid?
    assert_includes player.errors[:email], "is invalid"
  end

  test "gender defaults to unspecified" do
    player = Player.new(team: build_team, role: :member, email: "x@example.com")
    assert player.unspecified?
  end

  test "job is nullable (not yet chosen)" do
    player = build_player(build_team, job: nil)
    assert player.valid?
    assert_nil player.job
  end

  test "rejects a second leader on the same team" do
    team = build_team
    build_player(team, role: :leader, email: "leader1@example.com").save!

    second_leader = build_player(team, role: :leader, email: "leader2@example.com")
    assert_not second_leader.valid?
    assert_includes second_leader.errors[:role], "隊伍已有隊長"
  end

  test "allows up to 3 members but rejects the 4th" do
    team = build_team
    3.times do |i|
      build_player(team, role: :member, email: "member#{i}@example.com").save!
    end

    fourth = build_player(team, role: :member, email: "member4@example.com")
    assert_not fourth.valid?
    assert_includes fourth.errors[:role], "隊伍隊員已滿"
  end

  test "unique index rejects duplicate [team, role, email]" do
    team = build_team
    build_player(team, role: :member, email: "dup@example.com").save!

    dup = Player.new(team: team, role: :member, email: "dup@example.com")
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  test "same email can join as leader on a different team" do
    team_a = build_team
    team_b = build_team
    build_player(team_a, role: :leader, email: "shared@example.com").save!

    other = build_player(team_b, role: :leader, email: "shared@example.com")
    assert other.valid?
  end
end
