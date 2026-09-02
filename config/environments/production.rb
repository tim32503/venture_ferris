require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Do not fall back to the asset pipeline if a precompiled asset is missed.
  # (Sprockets defaults this to true; the Rails 8 template omits the line
  # because it assumes Propshaft, which has no runtime compilation at all.)
  config.assets.compile = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # Fly.io's edge proxy terminates TLS and forwards plain HTTP to the app over
  # its private network, setting X-Forwarded-Proto: https — without this,
  # force_ssl below would see a plain-HTTP request and 301-redirect it to
  # itself, an infinite redirect loop. See docs/DEPLOYMENT.md.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = true

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  # This app ships no mailers (only the generated ApplicationMailer skeleton),
  # so the Rails 8 template's `host: "example.com"` placeholder is left off
  # rather than committing a hostname the deployment does not actually use.
  # config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  # Deployed on Fly.io (see docs/DEPLOYMENT.md). This only takes effect when
  # the ALLOWED_HOSTS env var is actually set — a comma-separated list of
  # hostnames, e.g. "venture-ferris.fly.dev,example.com". Leaving it unset
  # keeps the default (commented-out, i.e. no allowlist) behavior above.
  # `fly secrets set ALLOWED_HOSTS=...` should always include the app's
  # *.fly.dev hostname, plus any custom domain later attached.
  if ENV["ALLOWED_HOSTS"].present?
    config.hosts = ENV["ALLOWED_HOSTS"].split(",").map(&:strip)
    # Fly.io health checks hit the machine by its private IP (e.g.
    # "172.19.11.162:3000"), which the allowlist would block, leaving the
    # machine permanently unhealthy. Exempt the health-check path only —
    # same as the Rails 8 generator default.
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end

  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
