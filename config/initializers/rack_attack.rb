# frozen_string_literal: true

# Abuse-prevention throttles for the public deployment (see README「部署待辦」).
#
# This app deploys to a single fixed-cost VPS with no plan to scale across
# multiple app servers (see README), so `Rails.cache` (the file store by
# default in production — config/environments/production.rb) is an
# acceptable backing store for throttle counters: one process, one cache.
# If this app is ever scaled horizontally, these counters MUST move to a
# cache shared by every instance (Redis/Memcached) — with `Rails.cache`
# alone, each instance would enforce its own independent limit, quietly
# multiplying every threshold below by the instance count.
Rack::Attack.cache.store = Rails.cache

# ---------------------------------------------------------------------------
# Boundary: do NOT throttle in-game action or polling endpoints here.
#
# - `POST /game/bosses/:number/attacks` is meant to be mashed — a real boss
#   fight is a burst of legitimate rapid clicks from the whole team.
# - Every `*/status` action (`game/team/status`, `game/job/status`,
#   `game/bosses/:number/status`, `game/questions/:number/status`) is polled
#   by the front end roughly every 500ms while its page is open.
#
# A throttle rule whose matcher can match any of the above WILL break the
# game for legitimate players. The rules below match only the specific
# session-creation/login paths named in each comment — keep it that way.
# ---------------------------------------------------------------------------

# Homepage "Demo" button (Game::SessionsController#create_demo!, routed
# through the shared POST /game/session action via the `demo` param): every
# click creates a brand-new Team + Player row, so this is the single easiest
# way for a visitor (malicious or just trigger-happy) to fill up the
# database. Throttled per IP, not globally, so one abusive visitor cannot
# lock everyone else out of the demo.
Rack::Attack.throttle(
  "demo-team-creation/ip",
  limit: Integer(ENV.fetch("RACK_ATTACK_DEMO_LIMIT", 5)),
  period: Integer(ENV.fetch("RACK_ATTACK_DEMO_PERIOD_SECONDS", 1.hour.to_i))
) do |req|
  req.ip if req.post? && req.path == "/game/session" && req.params["demo"].present?
end

# Back-office login (Admin::SessionsController#create): brute-force
# protection. Tighter window than the player login throttle below — there is
# only ever one admin account (see db/seeds.rb), so a burst of attempts is
# unlikely to be anything but an attack.
Rack::Attack.throttle(
  "admin-login/ip",
  limit: Integer(ENV.fetch("RACK_ATTACK_ADMIN_LOGIN_LIMIT", 10)),
  period: Integer(ENV.fetch("RACK_ATTACK_ADMIN_LOGIN_PERIOD_SECONDS", 1.minute.to_i))
) do |req|
  req.ip if req.post? && req.path == "/admin/session"
end

# Player check-in login (Game::SessionsController#create, the non-demo
# path): a light throttle to blunt serial-number brute-forcing/scraping
# without getting in the way of normal onsite check-in, where a few retries
# (typo'd serial, wrong role, full roster) are expected and legitimate.
Rack::Attack.throttle(
  "player-login/ip",
  limit: Integer(ENV.fetch("RACK_ATTACK_PLAYER_LOGIN_LIMIT", 20)),
  period: Integer(ENV.fetch("RACK_ATTACK_PLAYER_LOGIN_PERIOD_SECONDS", 1.minute.to_i))
) do |req|
  req.ip if req.post? && req.path == "/game/session" && req.params["demo"].blank?
end

Rack::Attack.throttled_responder = lambda do |_request|
  [ 429, { "Content-Type" => "text/plain; charset=utf-8" }, [ "請求過於頻繁，請稍後再試。" ] ]
end
