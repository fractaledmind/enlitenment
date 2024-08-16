require_relative "boot"
require "rails/all"
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Fallback to English if translation key is missing
    config.i18n.fallbacks = true

    # Use SQL schema format to include search-related objects
    config.active_record.schema_format = :sql
  end
end
