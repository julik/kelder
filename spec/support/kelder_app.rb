class KelderApp < Rails::Application
  active_storage_config = {
    service: :local,
    service_configurations: {
      local: {
        service: "Disk",
        root: File.expand_path(__dir__ + '../../tmp/storage')
      }
    }
  }

  config.storage = active_storage_config
  config.active_storage = active_storage_config

  # secrets.secret_token    = "secret_token"
  # secrets.secret_key_base = "secret_key_base"

  # # Use cookie sessions - do not set expire_after: so that
  # # the cookie is a "browser session cookie"
  # config.session_store :cookie_store,
  #   digest: "SHA512",
  #   serializer: JSON

  # config.logger = Logger.new($stderr)
  # Rails.logger = config.logger

  # routes.draw do
  #   mount SESSION_MANIPULATING_APP => '/'
  # end
end
