# dartsass-rails compiles each entry point in app/assets/stylesheets/ into
# app/assets/builds/, which sprockets then fingerprints and serves (see
# app/assets/config/manifest.js's `link_tree ../builds`). `dartsass:build` is
# attached to `assets:precompile`, so production builds pick this up
# automatically; `bin/dev` runs `dartsass:watch` alongside the server.
#
# These two entry points are linked directly from views rather than being
# bundled together: "site" from the shared layout, "boss" only from the boss
# battle page (app/views/game/bosses/show.html.erb).
Rails.application.config.dartsass.builds = {
  "site.scss" => "site.css",
  "boss.scss" => "boss.css"
}
