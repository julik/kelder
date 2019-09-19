require "kelder/version"

module Kelder
  module PrefixKeyWithToken
    # Prefix all generated blob keys with the tenant. Do not
    # use slash as a delimiter because it needs different escaping
    # depending on the storage service adapter - in some cases it
    # might be significant, in other cases it might get escaped as a path
    # component etc.
    def generate_unique_secure_token
      tenant_slug = Apartment::Tenant.current.split('_').last
      "#{tenant_slug}-#{super}"
    end
  end

  module FindSignedWithTenant
    # Finds in the correct database
    def find_signed(signed_id_with_tenant_prefix)
      tenant, id = ActiveStorage.verifier.verify(signed_id_with_tenant_prefix, purpose: :blob_id_with_tenant)
      Apartment::Tenant.switch(tenant) { find(id) }
    end
  end

  module PrefixedSignedId
    def signed_id
      ActiveStorage.verifier.generate([Apartment::Tenant.current, id], purpose: :blob_id_with_tenant)
    end
  end

  module FolderForPrefix
    # The disk storage service creates folders which avoid having too many files
    # within the same directory. If we leave it unchanged, it will generate very
    # few folders for our project slugs but will not reduce the number of files
    # in a single directory - which will create severe performance problems once
    # we have tens of thousands or hundreds of thousands of files per directory.
    # To avoid it, we need to make sure the directories are "spread" underneath
    # the project slug subdirectory. So if a standard ActiveStorage method
    # would generate this:
    #
    #   "abcdefg" => "ab/cd/abcdefg"
    #
    # without our patch, having a prefix and a dash:
    #
    #   "prj1-abcdefg" => "pr/j1/prj1-abcdefg"
    #
    # This would kill performance - especially when globbing.
    # Instead we want to do this:
    #
    #   "prj1-abcdefg" => "prj1/ab/cd/prj1-abcdefg"
    #
    # which is a combination of both. It will also make our project deletes faster.
    def folder_for(key_with_prefix)
      return super unless key_with_prefix.include?('-')

      # This is a tenant key, so we need to prefix the key with
      # the tenant slug which should create a single directory.
      # Underneath that - use the original method only for the pseudorandom
      # component of the key.
      tenant_slug, random_component = key_with_prefix.split('-')
      path_for_random_component = super(random_component)
      [tenant_slug, path_for_random_component].join('/')
    end
  end

  # The ActiveStorage controllers get mounted under the Rails routes root, or - at best -
  # under a static scope. Inside of those controllers we need to know which tenant is
  # being used for this particular operation. To do that we are going to "sidechannel"
  # the tenant name, signed, into one of the query string parameters. This query string
  # parameter needs to be given to the Rails URL helpers when generating the blob
  # URL or the direct upload URL, otherwise the main tenant is going to be used.
  #
  # These controllers need a "service elevator".
  module ControllerElevator
    # We cannot use around_action because it is going to be applied _after_
    # the before_action of the builtin ActiveStorage controllers. That before_action
    # actually calls set_blob, and set_blob already does the first ActiveRecord query.
    #
    # We need to intercept prior to set_blob, so around_action won't really work all that well.
    def process_action(*args)
      if signed_tenant_name = request.query_parameters['signed_tenant_name']
        # The tenant name is signed because otherwise we would be allowing uploads
        # from any project or even by not signed-in users, we want to control these URLs real tight.
        tenant_database_name = ActiveStorage.verifier.verify(signed_tenant_name, purpose: :active_storage_controllers)
        Apartment::Tenant.switch(tenant_database_name) do
          super
        end
      else
        super
      end
    end
  end

  # Install our patches via railtie
  class KelderRailtie < Rails::Railtie
    config.after_initialize do
      # Install the prefixed key patch and the prefixed signed ID patches.
      #
      # We need to prepend in class context, to make sure our method really takes over.
      ::ActiveStorage::Blob.singleton_class.send(:prepend, PrefixKeyWithToken)
      ::ActiveStorage::Blob.singleton_class.send(:prepend, FindSignedWithTenant)
      ::ActiveStorage::Blob.prepend(PrefixedSignedId)

      # Install DiskService patch to have prefixed folder trees
      require 'active_storage/service/disk_service' unless defined?(ActiveStorage::Service::DiskService)
      ActiveStorage::Service::DiskService.prepend(FolderForPrefix)

      # Install the elevator into controllers
      ActiveStorage::BaseController.prepend(ControllerElevator)
    end
  end
end
