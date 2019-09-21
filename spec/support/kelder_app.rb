require 'rails'
require 'apartment'
require 'action_controller'
require 'active_job'
require 'active_storage/engine'

db_filename = ('nyet_testdb_%s.sqlite3' % SecureRandom.hex(4))
ActiveRecord::Base.establish_connection(adapter: 'sqlite3', pool: 10, database: db_filename)

class KelderApp < Rails::Application
  secrets.secret_token    = "secret_token"
  secrets.secret_key_base = "secret_key_base"

  config.eager_load = true
  config.cache_classes = false
  # # Use cookie sessions - do not set expire_after: so that
  # # the cookie is a "browser session cookie"
  # config.session_store :cookie_store,
  #   digest: "SHA512",
  #   serializer: JSON

  # config.logger = Logger.new($stderr)
  # Rails.logger = config.logger

  
  routes.draw do
    mount ActiveStorage::Engine => '/rails/activestorage'
  end
end

ActiveStorage::Engine.configure do |engine|
  storage_configs = {
    local: {
      service: "Disk",
      root: File.expand_path(__dir__ + '../../tmp/storage')
    }
  }
  engine.config.storage_configurations = storage_configs
  engine.config.service = :local
end

# Initialize the Rails application, which also mounts ActiveStorage as an engine.
Rails.application.initialize!

