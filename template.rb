require "psych"

# internal constants for the template
RAILS_GEM_VERSION = Gem::Version.new(Rails::VERSION::STRING).freeze
RAILS_8_VERSION = Gem::Version.new("8.0.0").freeze
AT_LEAST_RAILS_8 = RAILS_GEM_VERSION.release >= RAILS_8_VERSION

# user-configurable constants for the template
SKIP_SOLID_QUEUE = ENV.fetch("SKIP_SOLID_QUEUE", false).freeze
QUEUE_DB = ENV.fetch("QUEUE_DB", "queue").freeze
JOBS_ROUTE = ENV.fetch("JOBS_ROUTE", "/jobs").freeze
JOBS_CONTROLLER = ENV.fetch("JOBS_CONTROLLER", "AdminController").freeze

SKIP_SOLID_CACHE = ENV.fetch("SKIP_SOLID_CACHE", false).freeze
CACHE_DB = ENV.fetch("CACHE_DB", "cache").freeze
SKIP_DEV_CACHE = ENV.fetch("SKIP_DEV_CACHE", false).freeze

SKIP_LITESTREAM = ENV.fetch("SKIP_LITESTREAM", false).freeze
SKIP_LITESTREAM_CREDS = ENV.fetch("SKIP_LITESTREAM_CREDS", false).freeze

# ------------------------------------------------------------------------------

class DatabaseYAML
  COMMENTED_PROD_DATABASE = "# database: path/to/persistent/storage/production.sqlite3"
  UNCOMMENTED_PROD_DATABASE = "database: path/to/persistent/storage/production.sqlite3"
  attr_reader :content

  def initialize(path: nil, content: nil)
    @content = content ? content : File.read(path)
    # if the production environment has the default commented database value,
    # uncomment it so that the value can be parsed. We will comment it out
    # again at the end of the transformations.
    @content.gsub!(COMMENTED_PROD_DATABASE, UNCOMMENTED_PROD_DATABASE)
    @stream = Psych.parse_stream(@content)
    @emission_stream = Psych::Nodes::Stream.new
    @emission_document = Psych::Nodes::Document.new
    @emission_mapping = Psych::Nodes::Mapping.new
  end

  def add_database(name)
    root = @stream.children.first.root
    root.children.each_slice(2).map do |scalar, mapping|
      next unless scalar.is_a?(Psych::Nodes::Scalar)
      next unless mapping.is_a?(Psych::Nodes::Mapping)
      next unless mapping.anchor.nil? || mapping.anchor.empty?
      next if mapping.children.each_slice(2).any? do |key, value|
        key.is_a?(Psych::Nodes::Scalar) && key.value == name && value.is_a?(Psych::Nodes::Alias) && value.anchor == name
      end

      new_mapping = Psych::Nodes::Mapping.new
      if mapping.children.first.value == "<<" # 2-tiered environment
        new_mapping.children.concat [
          Psych::Nodes::Scalar.new("primary"),
          mapping,
          Psych::Nodes::Scalar.new(name),
          Psych::Nodes::Alias.new(name),
        ]
      else # 3-tiered environment
        new_mapping.children.concat mapping.children
        new_mapping.children.concat [
          Psych::Nodes::Scalar.new(name),
          Psych::Nodes::Alias.new(name),
        ]
      end

      old_environment_entry = emit_pair(scalar, mapping)
      new_environment_entry = emit_pair(scalar, new_mapping)

      [scalar.value, old_environment_entry, new_environment_entry]
    end.compact!
  end

  def new_database(name)
    db = Psych::Nodes::Mapping.new(name)
    db.children.concat [
      Psych::Nodes::Scalar.new("<<"),
      Psych::Nodes::Alias.new("default"),
      Psych::Nodes::Scalar.new("migrations_paths"),
      Psych::Nodes::Scalar.new("db/#{name}_migrate"),
      Psych::Nodes::Scalar.new("database"),
      Psych::Nodes::Scalar.new("storage/<%= Rails.env %>-#{name}.sqlite3"),
    ]
    "\n" + emit_pair(Psych::Nodes::Scalar.new(name), db)
  end

  def database_def_regex(name)
    /#{name}: &#{name}\n(?:[ \t]+.*\n)+/
  end

  def emit_pair(scalar, mapping)
    @emission_mapping.children.clear.concat [scalar, mapping]
    @emission_document.children.clear.concat [@emission_mapping]
    @emission_stream.children.clear.concat [@emission_document]
    output = @emission_stream.yaml.gsub!(/^---/, '').strip!
    # if the production environment had the default commented database value,
    # make sure to comment it out now when emitting the
    output.gsub!(UNCOMMENTED_PROD_DATABASE, COMMENTED_PROD_DATABASE)
    output
  end
end

def file_includes?(path, check)
  destination = File.expand_path(path, destination_root)
  content = File.read(destination)
  content.include?(check)
end

def run_or_error(command, config = {})
  result = in_root { run command, config }

  if result
    return true
  else
    say_status :error, "Failed to run `#{command}`. Resolve and try again", :red
    exit 1
  end
end

def add_gem(*args)
  name, *versions = args
  return if file_includes?("Gemfile.lock", "    #{name}")

  gem(*args)
end

def bundle_install
  Bundler.with_unbundled_env do
    run_or_error 'bundle install'
  end
end

# ------------------------------------------------------------------------------

# Ensure the sqlite3 gem is installed
add_gem "sqlite3", "~> 2.0", comment: "Use SQLite as the database engine"

# Ensure all SQLite connections are properly configured
if AT_LEAST_RAILS_8
else
  add_gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0", comment: "Ensure all SQLite connections are properly configured"
end

# Add Solid Queue
unless SKIP_SOLID_QUEUE
  # 1. add the appropriate solid_queue gem version
  if AT_LEAST_RAILS_8
    add_gem "solid_queue", "~> 0.4", comment: "Add Solid Queue for background jobs"
  else
    add_gem "solid_queue", github: "rails/solid_queue", branch: "main", comment: "Add Solid Queue for background jobs"
  end

  # 2. install the gem
  bundle_install

  # 3. define the new database configuration
  database_yaml = DatabaseYAML.new path: File.expand_path("config/database.yml", destination_root)
  # NOTE: this `insert_into_file` call is idempotent because we are only inserting a plain string.
  insert_into_file "config/database.yml",
                   database_yaml.new_database(QUEUE_DB) + "\n",
                   after: database_yaml.database_def_regex("default"),
                   verbose: false
  say_status :def_db, "#{QUEUE_DB} (database.yml)"

  # 4. add the new database configuration to all environments
  database_yaml.add_database(QUEUE_DB).each do |environment, old_environment_entry, new_environment_entry|
    # NOTE: this `gsub_file` call is idempotent because we are only finding and replacing plain strings.
    gsub_file "config/database.yml",
              old_environment_entry,
              new_environment_entry,
              verbose: false
    say_status :add_db, "#{QUEUE_DB} -> #{environment} (database.yml)"
  end

  # 5. run the Solid Queue installation generator
  # NOTE: we run the command directly instead of via the `generate` helper
  # because that doesn't allow passing arbitrary environment variables.
  run_or_error "bin/rails generate solid_queue:install", env: { "DATABASE" => QUEUE_DB }

  # 6. run the migrations for the new database
  # NOTE: we run the command directly instead of via the `rails_command` helper
  # because that runs `bin/rails` through Ruby, which we can't test properly.
  run_or_error "bin/rails db:migrate:#{QUEUE_DB}"

  # 7. configure the application to use Solid Queue in all environments with the new database
  # NOTE: `insert_into_file` with replacement text that contains regex backreferences will not be idempotent,
  # so we need to check if the line is already present before adding it.
  configure_queue_adapter = "config.active_job.queue_adapter = :solid_queue"
  configure_solid_queue = "config.solid_queue.connects_to = { database: { writing: :#{QUEUE_DB} } }"
  if not file_includes?("config/application.rb", configure_queue_adapter)
    insert_into_file "config/application.rb", after: /^([ \t]*)config.load_defaults.*$/ do
      [
        "",
        "",
        "\\1# Use Solid Queue for background jobs",
        "\\1#{configure_queue_adapter}"
      ].join("\n")
    end
  end
  if not file_includes?("config/application.rb", configure_solid_queue)
    insert_into_file "config/application.rb", after: /^([ \t]*)config.active_job.queue_adapter = :solid_queue.*$/ do
      [
        "",
        "\\1#{configure_solid_queue}",
      ].join("\n")
    end
  end

  # 8. add the Solid Queue plugin to Puma
  # NOTE: this `insert_into_file` call is idempotent because we are only inserting a plain string.
  insert_into_file "config/puma.rb", after: "plugin :tmp_restart" do
    [
      "",
      "# Allow puma to manage Solid Queue's supervisor process",
      "plugin :solid_queue"
    ].join("\n")
  end

  # 9. add the Solid Queue engine to the application
  add_gem "mission_control-jobs", "~> 0.3", comment: "Add a web UI for Solid Queue"

  # 10. mount the Solid Queue engine
  # NOTE: `insert_into_file` with replacement text that contains regex backreferences will not be idempotent,
  # so we need to check if the line is already present before adding it.
  mount_mission_control_jobs = %Q{mount MissionControl::Jobs::Engine, at: "#{JOBS_ROUTE}"}
  if not file_includes?("config/routes.rb", mount_mission_control_jobs)
    insert_into_file "config/routes.rb",  after: /^([ \t]*).*rails_health_check$/ do
      [
        "",
        "",
        "\\1#{mount_mission_control_jobs}"
      ].join("\n")
    end
  end

  jobs_controller = if JOBS_CONTROLLER.safe_constantize.nil?
    say_status :warning, "The JOBS_CONTROLLER class `#{JOBS_CONTROLLER}` does not exist. Generating a basic secure controller instead.", :blue
    create_file "app/controllers/mission_control/base_controller.rb", <<~RUBY
      module MissionControl
        mattr_writer :username
        mattr_writer :password

        class << self
          # use method instead of attr_accessor to ensure
          # this works if variable set after SolidErrors is loaded
          def username
            @username ||= @@username || ENV.fetch("MISSION_CONTROL_USERNAME", "admin")
          end

          def password
            @password ||= @@password || ENV.fetch("MISSION_CONTROL_PASSWORD", SecureRandom.hex(16))
          end
        end

        class BaseController < ActionController::Base
          protect_from_forgery with: :exception

          http_basic_authenticate_with name: MissionControl.username, password: MissionControl.password
        end
      end
    RUBY
    "MissionControl::BaseController"
  else
    JOBS_CONTROLLER
  end
  # NOTE: `insert_into_file` with replacement text that contains regex backreferences will not be idempotent,
  # so we need to check if the line is already present before adding it.
  configure_mission_control_jobs = %Q{config.mission_control.jobs.base_controller_class = "#{jobs_controller}"}
  if not file_includes?("config/application.rb", configure_mission_control_jobs)
    insert_into_file "config/application.rb", after: /^([ \t]*)config.solid_queue.*$/ do
      [
        "",
        "\\1# Ensure authorization is enabled for the Solid Queue web UI",
        "\\1#{configure_mission_control_jobs}",
      ].join("\n")
    end
  end
end

# Add Solid Cache
unless SKIP_SOLID_CACHE
  # 1. add the appropriate solid_cache gem version
  if AT_LEAST_RAILS_8
    add_gem "solid_cache", "~> 0.7", comment: "Add Solid Cache as an Active Support cache store"
  else
    add_gem "solid_cache", github: "rails/solid_cache", branch: "main", comment: "Add Solid Cache as an Active Support cache store"
  end

  # 2. install the gem
  bundle_install

  # 3. define the new database configuration
  database_yaml = DatabaseYAML.new path: File.expand_path("config/database.yml", destination_root)
  # NOTE: this `insert_into_file` call is idempotent because we are only inserting a plain string.
  insert_into_file "config/database.yml",
                   database_yaml.new_database(CACHE_DB) + "\n",
                   after: database_yaml.database_def_regex(QUEUE_DB),
                   verbose: false
  say_status :def_db, "#{CACHE_DB} (database.yml)"

  # 4. add the new database configuration to all environments
  database_yaml.add_database(CACHE_DB).each do |environment, old_environment_entry, new_environment_entry|
    # NOTE: this `gsub_file` call is idempotent because we are only finding and replacing plain strings.
    gsub_file "config/database.yml",
              old_environment_entry,
              new_environment_entry,
              verbose: false
    say_status :add_db, "#{CACHE_DB} -> #{environment} (database.yml)"
  end

  # 5. run the Solid Cache installation generator
  # NOTE: we run the command directly instead of via the `generate` helper
  # because that doesn't allow passing arbitrary environment variables.
  run_or_error "bin/rails generate solid_cache:install", env: { "DATABASE" => CACHE_DB }

  # 6. run the migrations for the new database
  # NOTE: we run the command directly instead of via the `rails_command` helper
  # because that runs `bin/rails` through Ruby, which we can't test properly.
  run_or_error "bin/rails db:migrate:#{CACHE_DB}"

  # 7. configure Solid Cache to use the new database
  # NOTE: this `gsub_file` call is idempotent because we are only finding and replacing plain strings.
  gsub_file "config/solid_cache.yml",
            "database: <%= Rails.env %>",
            "database: #{CACHE_DB}"

  # 8. optionally enable the cache in development
  # NOTE: we run the command directly instead of via the `rails_command` helper
  # because that runs `bin/rails` through Ruby, which we can't test properly.
  if not SKIP_DEV_CACHE
    run_or_error "bin/rails dev:cache"
  end
end

# Add Litestream
unless SKIP_LITESTREAM
  # 1. add the litestream gem
  add_gem "litestream", "~> 0.10.0", comment: "Ensure all SQLite databases are backed up"

  # 2. install the gem
  bundle_install

  # 3. run the Litestream installation generator
  # NOTE: we run the command directly instead of via the `rails_command` helper
  # because that runs `bin/rails` through Ruby, which we can't test properly.
  run_or_error "bin/rails generate litestream:install"

  # 4. add the Litestream plugin to Puma
  # NOTE: this `insert_into_file` call is idempotent because we are only inserting a plain string.
  insert_into_file "config/puma.rb", after: "plugin :tmp_restart" do
    [
      "",
      "# Allow puma to manage Litestream replication process",
      "plugin :litestream"
    ].join("\n")
  end

  # 5. add the Litestream engine to the application
  say_status :NOTE, "Litestream requires an S3-compatible storage provider, like AWS S3, DigitalOcean Spaces, Google Cloud Storage, etc.", :blue
  if not SKIP_LITESTREAM_CREDS
    uncomment_lines "config/initializers/litestream.rb", /litestream_credentials/

    say_status :NOTE, <<~MESSAGE, :blue
      Edit your application's credentials to store your bucket details with:
          bin/rails credentials:edit
      Supply the necessary credentials for your S3-compatible storage provider in the following format:
          litestream:
            replica_bucket: <your-bucket-name>
            replica_key_id: <public-key>
            replica_access_key: <private-key>
      You can confirm that everything is configured correctly by validating the output of the following command:
          bin/rails litestream:env
    MESSAGE
  else
    say_status :NOTE, <<~MESSAGE, :blue
      You will need to configure Litestream by editing the configuration file at config/initializers/litestream.rb
    MESSAGE
  end
end
