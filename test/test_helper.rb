ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # `questions.boss_id` is NOT NULL (docs/SCHEMA_REDESIGN.md §2-3), so every
    # test that builds a Question needs a Boss for it. The test database is
    # built with `schema:load`, which never runs db/seeds.rb, so the seeded
    # boss rows are not there and each test creates the one it needs.
    #
    # The mapping mirrors db/seeds.rb's BOSS_ASSIGNMENTS, including the part
    # that motivated this table in the first place: question 10 has no sprite
    # of its own and shares question 11's 摩天輪魔王.
    def seed_boss_for(question_number)
      Boss.find_or_create_by!(sprite: format("mon%02d", question_number == 10 ? 11 : question_number))
    end
  end
end
