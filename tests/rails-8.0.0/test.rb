# frozen_string_literal: true

require_relative "../test_helper"

class TestRails800 < TestCase
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

    assert_output /8.0.0/ do
      apply_rails_template template_path
    end
  end

  def test_the_template_handles_defaults
    call_count = 0
    stdout = ""

    Thor::LineEditor.stub :readline, "yes" do
      Bundler.stub :with_unbundled_env, ->(*) { call_count += 1 } do
        stdout, _stderr = capture_io do
          apply_rails_template
        end
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
    assert_includes app.read("config/application.rb"), 'config.mission_control.jobs.base_controller_class = "AdminController"'

    assert_includes app.read("config/routes.rb"), 'mount MissionControl::Jobs::Engine, at: "/jobs"'

    assert_includes app.read("config/solid_cache.yml"), 'database: cache'

    assert_match /^  litestream_credentials = Rails.application.credentials.litestream$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_bucket = litestream_credentials.replica_bucket$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_key_id = litestream_credentials.replica_key_id$/, app.read("config/initializers/litestream.rb")
    assert_match /^  config.replica_access_key = litestream_credentials.replica_access_key$/, app.read("config/initializers/litestream.rb")
  end
end
