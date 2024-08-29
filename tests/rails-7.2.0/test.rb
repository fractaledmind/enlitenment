# frozen_string_literal: true

require_relative "../test_helper"

class TestRails720 < TestCase
  def setup
    @app_path = File.join(__dir__, "dummy")
    build_app
  end

  def teardown
    remove_app_dir
  end

  def test_a_template_can_be_applied_and_rails_version_is_correct
    template_path = File.join(@app_path, "template.rb")
    File.write(template_path, <<~RUBY)
      puts Rails::VERSION::STRING
    RUBY

    assert_output /7.2.0/ do
      apply_rails_template template_path
    end
  end

  def test_the_template_handles_defaults
    call_count = 0
    stdout = ""

    Bundler.stub :with_unbundled_env, ->(*) { fake_lockfile!; call_count += 1 } do
      stdout, _stderr = capture_io do
        apply_rails_template
      end
    end

    assert_equal 3, call_count, "Bundler.with_unbundled_env should be called thrice"

    assert_match /gemfile * activerecord-enhancedsqlite3-adapter \(~> 0\.8\.0\)/, stdout
    assert_match /gemfile * solid_queue/, stdout
    assert_match /def_db * queue \(database.yml\)/, stdout
    assert_match /add_db * queue -> development \(database.yml\)/, stdout
    assert_match /add_db * queue -> test \(database.yml\)/, stdout
    assert_match /add_db * queue -> production \(database.yml\)/, stdout
    assert_match /run * bin\/rails generate solid_queue:install from "\."/, stdout
    assert_match /run * bin\/rails db:migrate:queue from "\."/, stdout
    assert_match /insert * config\/application\.rb/, stdout
    assert_match /insert * config\/puma\.rb/, stdout
    assert_match /gemfile * mission_control-jobs \(~> 0\.3\)/, stdout
    assert_match /insert * config\/routes\.rb/, stdout
    assert_match /insert * config\/application\.rb/, stdout
    assert_match /gemfile * solid_cache/, stdout
    assert_match /def_db * cache \(database.yml\)/, stdout
    assert_match /add_db * cache -> development \(database.yml\)/, stdout
    assert_match /add_db * cache -> test \(database.yml\)/, stdout
    assert_match /add_db * cache -> production \(database.yml\)/, stdout
    assert_match /run * bin\/rails generate solid_cache:install from "\."/, stdout
    assert_match /run * bin\/rails db:migrate:cache from "\."/, stdout
    assert_match /gsub * config\/solid_cache\.yml/, stdout
    assert_match /run * bin\/rails dev:cache from "\."/, stdout
    assert_match /gemfile * litestream \(~> 0\.10\.0\)/, stdout
    assert_match /run * bin\/rails generate litestream:install from "\."/, stdout
    assert_match /insert * config\/puma\.rb/, stdout
    assert_match /gsub * config\/initializers\/litestream\.rb/, stdout

    assert_includes app.read("Gemfile"), 'gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0"'
    assert_includes app.read("Gemfile"), 'gem "solid_queue", github: "rails/solid_queue", branch: "main"'
    assert_includes app.read("Gemfile"), 'gem "mission_control-jobs", "~> 0.3"'
    assert_includes app.read("Gemfile"), 'gem "litestream", "~> 0.10.0"'

    assert_includes app.read("generate"), "solid_queue:install"
    assert_includes app.read("generate"), "solid_cache:install"
    assert_includes app.read("generate"), "litestream:install"

    assert_path_exists app.expand("db:migrate:queue")
    assert_path_exists app.expand("db:migrate:cache")
    assert_path_exists app.expand("dev:cache")

    assert_includes app.read("config/database.yml"), <<~YAML
      queue: &queue
        <<: *default
        migrations_paths: db/queue_migrate
        database: storage/<%= Rails.env %>-queue.sqlite3
    YAML
    assert_includes app.read("config/database.yml"), <<~YAML
      development:
        primary:
          <<: *default
          database: storage/development.sqlite3
        queue: *queue
    YAML
    assert_includes app.read("config/database.yml"), <<~YAML
      # Warning: The database defined as "test" will be erased and
      # re-generated from your development database when you run "rake".
      # Do not set this db to the same as development or production.
      test:
        primary:
          <<: *default
          database: storage/test.sqlite3
        queue: *queue
    YAML
    assert_includes app.read("config/database.yml"), <<~YAML.strip
      # SQLite3 write its data on the local filesystem, as such it requires
      # persistent disks. If you are deploying to a managed service, you should
      # make sure it provides disk persistence, as many don't.
      #
      # Similarly, if you deploy your application as a Docker container, you must
      # ensure the database is located in a persisted volume.
      production:
        primary:
          <<: *default
          # database: path/to/persistent/storage/production.sqlite3
        queue: *queue
    YAML
    assert_includes app.read("config/puma.rb"), 'plugin :solid_queue'
    assert_includes app.read("config/puma.rb"), 'plugin :litestream'

    assert_includes app.read("config/application.rb"), 'config.active_job.queue_adapter = :solid_queue'
    assert_includes app.read("config/application.rb"), 'config.solid_queue.connects_to = { database: { writing: :queue } }'
    assert_includes app.read("config/application.rb"), 'config.mission_control.jobs.base_controller_class = "MissionControl::BaseController"'

    assert_includes app.read("config/routes.rb"), 'mount MissionControl::Jobs::Engine, at: "/jobs"'

    assert_includes app.read("config/solid_cache.yml"), 'database: cache'

    assert_match /^  litestream_credentials = Rails.application.credentials.litestream$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_bucket = litestream_credentials.replica_bucket$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_key_id = litestream_credentials.replica_key_id$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_access_key = litestream_credentials.replica_access_key$/, app.read("config/initializers/litestream.rb")
  end

  def test_the_template_is_idempotent
    call_count = 0
    stdout = ""

    Bundler.stub :with_unbundled_env, ->(*) { fake_lockfile!; call_count += 1 } do
      stdout, _stderr = capture_io do
        apply_rails_template
        apply_rails_template
      end
    end

    expected_gemfile = <<~RUBY
      source "https://rubygems.org"
      # Use SQLite as the database engine
      gem "sqlite3", "~> 2.0"
      # Ensure all SQLite connections are properly configured
      gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0"
      # Add Solid Queue for background jobs
      gem "solid_queue", github: "rails/solid_queue", branch: "main"
      # Add a web UI for Solid Queue
      gem "mission_control-jobs", "~> 0.3"
      # Add Solid Cache as an Active Support cache store
      gem "solid_cache", github: "rails/solid_cache", branch: "main"
      # Ensure all SQLite databases are backed up
      gem "litestream", "~> 0.10.0"
    RUBY
    assert_equal expected_gemfile, app.read("Gemfile")

    expected_database_yml = <<~YAML
      # SQLite. Versions 3.8.0 and up are supported.
      #   gem install sqlite3
      #
      #   Ensure the SQLite 3 gem is defined in your Gemfile
      #   gem "sqlite3"
      #
      default: &default
        adapter: sqlite3
        pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
        timeout: 5000

      queue: &queue
        <<: *default
        migrations_paths: db/queue_migrate
        database: storage/<%= Rails.env %>-queue.sqlite3

      cache: &cache
        <<: *default
        migrations_paths: db/cache_migrate
        database: storage/<%= Rails.env %>-cache.sqlite3

      development:
        primary:
          <<: *default
          database: storage/development.sqlite3
        queue: *queue
        cache: *cache

      # Warning: The database defined as "test" will be erased and
      # re-generated from your development database when you run "rake".
      # Do not set this db to the same as development or production.
      test:
        primary:
          <<: *default
          database: storage/test.sqlite3
        queue: *queue
        cache: *cache

      # SQLite3 write its data on the local filesystem, as such it requires
      # persistent disks. If you are deploying to a managed service, you should
      # make sure it provides disk persistence, as many don't.
      #
      # Similarly, if you deploy your application as a Docker container, you must
      # ensure the database is located in a persisted volume.
      production:
        primary:
          <<: *default
          # database: path/to/persistent/storage/production.sqlite3
        queue: *queue
        cache: *cache
    YAML
    assert_equal expected_database_yml, app.read("config/database.yml")

    expected_application_rb = <<~RUBY
      require_relative "boot"
      require "rails/all"
      Bundler.require(*Rails.groups)

      module Dummy
        class Application < Rails::Application
          # Initialize configuration defaults for originally generated Rails version.
          config.load_defaults 7.0

          # Use Solid Queue for background jobs
          config.active_job.queue_adapter = :solid_queue
          config.solid_queue.connects_to = { database: { writing: :queue } }
          # Ensure authorization is enabled for the Solid Queue web UI
          config.mission_control.jobs.base_controller_class = "MissionControl::BaseController"

          # Fallback to English if translation key is missing
          config.i18n.fallbacks = true

          # Use SQL schema format to include search-related objects
          config.active_record.schema_format = :sql
        end
      end
    RUBY
    assert_equal expected_application_rb, app.read("config/application.rb")

    expected_puma_rb = <<~RUBY
      threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
      threads threads_count, threads_count

      # Specifies the `port` that Puma will listen on to receive requests; default is 3000.
      port ENV.fetch("PORT", 3000)

      # Allow puma to be restarted by `bin/rails restart` command.
      plugin :tmp_restart
      # Allow puma to manage Litestream replication process
      plugin :litestream
      # Allow puma to manage Solid Queue's supervisor process
      plugin :solid_queue

      # Only use a pidfile when requested
      pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
    RUBY
    assert_equal expected_puma_rb, app.read("config/puma.rb")

    expected_routes_rb = <<~RUBY
      Rails.application.routes.draw do
        get "webmanifest"    => "pwa#manifest"
        get "service-worker" => "pwa#service_worker"

        get "up" => "rails/health#show", as: :rails_health_check

        mount Litestream::Engine, at: "/litestream"

        mount MissionControl::Jobs::Engine, at: "/jobs"

        root "welcome#show"
      end
    RUBY
    assert_equal expected_routes_rb, app.read("config/routes.rb")

    expected_solid_cache_yml = <<~YAML
      default: &default
        database: cache
        store_options:
          max_age: <%= 1.week.to_i %>
          max_size: <%= 256.megabytes %>
          namespace: <%= Rails.env %>

      development:
        <<: *default

      test:
        <<: *default

      production:
        <<: *default
    YAML
    assert_equal expected_solid_cache_yml, app.read("config/solid_cache.yml")

    expected_litestream_rb = <<~RUBY
      # Use this hook to configure the litestream-ruby gem.
      # All configuration options will be available as environment variables, e.g.
      # config.replica_bucket becomes LITESTREAM_REPLICA_BUCKET
      # This allows you to configure Litestream using Rails encrypted credentials,
      # or some other mechanism where the values are only avaialble at runtime.

      # Ensure authorization is enabled for the Solid Queue web UI
      Litestream.username = "admin"
      Litestream.password = "lite$tr3am" # TODO: CHANGE THIS

      Litestream.configure do |config|
        # An example of using Rails encrypted credentials to configure Litestream.
        litestream_credentials = Rails.application.credentials.litestream

        # Replica-specific bucket location.
        # This will be your bucket's URL without the `https://` prefix.
        # For example, if you used DigitalOcean Spaces, your bucket URL could look like:
        #   https://myapp.fra1.digitaloceanspaces.com
        # And so you should set your `replica_bucket` to:
        #   myapp.fra1.digitaloceanspaces.com
        # Litestream supports Azure Blog Storage, Backblaze B2, DigitalOcean Spaces,
        # Scaleway Object Storage, Google Cloud Storage, Linode Object Storage, and
        # any SFTP server.
        # In this example, we are using Rails encrypted credentials to store the URL to
        # our storage provider bucket.
        config.replica_bucket = litestream_credentials.replica_bucket

        # Replica-specific authentication key.
        # Litestream needs authentication credentials to access your storage provider bucket.
        # In this example, we are using Rails encrypted credentials to store the access key ID.
        config.replica_key_id = litestream_credentials.replica_key_id

        # Replica-specific secret key.
        # Litestream needs authentication credentials to access your storage provider bucket.
        # In this example, we are using Rails encrypted credentials to store the secret access key.
        config.replica_access_key = litestream_credentials.replica_access_key
      end
    RUBY
    assert_equal expected_litestream_rb, app.read("config/initializers/litestream.rb")

    assert_equal 6, call_count, "Bundler.with_unbundled_env should be called six times"
  end
end
