require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module VentureFerris
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # sassc-rails defaults `config.assets.css_compressor` to `:sass` outside
    # development (see sassc/rails/railtie.rb#setup_compression), which
    # routes every compiled CSS asset — including the pre-built, already
    # minified `tailwind.css` from tailwindcss-rails — back through the
    # libsass compressor. Tailwind v4's output uses modern CSS syntax
    # (e.g. `@media (width >= 40rem)` range syntax) that libsass cannot
    # parse, raising "unclosed parenthesis in media query expression" in
    # test/production. Disable the compressor so built assets are served
    # as-is; sassc-rails' own .scss compilation (site.scss/boss.scss) is
    # unaffected since that happens at the engine/transformer step, not here.
    config.assets.css_compressor = nil
  end
end
