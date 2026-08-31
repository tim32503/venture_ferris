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

  test "unique index rejects duplicate [team, email]" do
    team = build_team
    build_player(team, role: :member, email: "dup@example.com").save!

    dup = Player.new(team: team, role: :member, email: "dup@example.com")
    assert_raises(ActiveRecord::RecordInvalid) { dup.save! }
  end

  # docs/SCHEMA_REDESIGN.md §2-7d: the old `[team_id, role, email]` index let
  # one address hold the leader seat *and* a member seat on the same team,
  # burning two of the four slots. Zero rows in the 2018 dump ever did this.
  test "one email cannot hold both roles on the same team" do
    team = build_team
    build_player(team, role: :leader, email: "both@example.com").save!

    also_member = build_player(team, role: :member, email: "both@example.com")
    assert_not also_member.valid?
    assert_includes also_member.errors[:email], "has already been taken"
  end

  test "two teammates cannot hold the same job" do
    team = build_team
    build_player(team, role: :leader, email: "leader@example.com", job: :senior).save!

    twin = build_player(team, role: :member, email: "member@example.com", job: :senior)
    assert_raises(ActiveRecord::RecordNotUnique) { twin.save! }
  end

  test "the same job may be held on two different teams" do
    build_player(build_team, role: :leader, email: "a@example.com", job: :senior).save!

    other = build_player(build_team, role: :leader, email: "b@example.com", job: :senior)
    assert other.save
  end

  test "same email can join as leader on a different team" do
    team_a = build_team
    team_b = build_team
    build_player(team_a, role: :leader, email: "shared@example.com").save!

    other = build_player(team_b, role: :leader, email: "shared@example.com")
    assert other.valid?
  end
end
