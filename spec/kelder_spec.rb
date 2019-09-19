require 'spec_helper'

RSpec.describe Kelder do
  before :all do
    Apartment.database_schema_file = File.expand_path(__dir__ + '/schema.rb')

    db_filename = ('testdb_%s.sqlite3' % SecureRandom.hex(4))
    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', pool: 10, database: db_filename)

    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :things do |t|
          t.string :description, :null => true
          t.timestamps :null => false
        end
      end
    end

    Apartment::Tenant.create("test_tenant_kelder_tenant123")
  end

  after :all do
    Apartment::Tenant.drop("test_tenant_kelder_tenant123")
  end

  describe 'ActiveStorage::Blob overrides' do
    it 'prefixes the "key" attribute with the last component of the current tenant database name' do
      Apartment::Tenant.switch("test_tenant_kelder_tenant123") do
        blob = ActiveStorage::Blob.new
        expect(blob.key).to start_with("tenant123")
      end
    end

    it 'returns an altered payload from #signed_id and can use it to find itself later via .find_signed' do
      Apartment::Tenant.switch("test_tenant_kelder_tenant123") do
        blob = ActiveStorage::Blob.new(id: 10)
        expect(blob.id).to eq(10)
        signed_id_with_tenant = blob.signed_id

        tenant_name, id = ActiveStorage.verifier.verify(signed_id_with_tenant, purpose: :blob_id_with_tenant)
        expect(tenant_name).to eq("test_tenant_kelder_tenant123")

        expect(ActiveStorage::Blob).to receive(:find).with(10)
        ActiveStorage::Blob.find_signed(signed_id_with_tenant)
      end
    end
  end

  describe 'ActiveStorage::DirectUploadsController overrides', type: :request do
    it 'performs the original action if there is no "signed_tenant_name"' do
      blob_params = {blob: {filename: 'file.txt', byte_size: 123, checksum: "abefg"}}

      expect(Apartment::Tenant).not_to receive(:switch)
      post "/rails/active_storage/direct_uploads", params: blob_params

      expect(response).to be_ok
      parsed_response = JSON.load(response.body)
      expect(parsed_response["key"]).not_to start_with("tenant123")
    end

    it 'switches into the tenant before returning the direct upload URL' do
      st = ActiveStorage.verifier.generate("test_tenant_kelder_tenant123", purpose: :active_storage_controllers)
      blob_params = {blob: {filename: 'file.txt', byte_size: 123, checksum: "abefg"}}

      expect(Apartment::Tenant).to receive(:switch).with("test_tenant_kelder_tenant123").and_call_original
      post "/rails/active_storage/direct_uploads?signed_tenant_name=#{st}", params: blob_params

      expect(response).to be_ok
      parsed_response = JSON.load(response.body)
      expect(parsed_response["key"]).to start_with("tenant123")
    end
  end

  describe 'ActiveStorage::BlobsController overrides', type: :request do
    it 'with the main tenant, does not suffix the blob key' do
      data = StringIO.new(Random.new.bytes(1024*5))
      signed_id = ActiveStorage::Blob.create_after_upload!(io: data, filename: 'test.bin').signed_id

      get "/rails/active_storage/blobs/#{signed_id}/test.bin"

      expect(response).to be_redirect
      location_on_storage_service = response.location

      get location_on_storage_service
      expect(response).to be_ok
      expect(response.body.bytesize).to eq(1024*5)
    end

    it 'returns the correct blob even though the blob URL does not contain the query string parameter' do
      data = StringIO.new(Random.new.bytes(1024*5))
      signed_id = Apartment::Tenant.switch("test_tenant_kelder_tenant123") do
        ActiveStorage::Blob.create_after_upload!(io: data, filename: 'test.bin').signed_id
      end

      expect(Apartment::Tenant).to receive(:switch).with("test_tenant_kelder_tenant123").and_call_original
      get "/rails/active_storage/blobs/#{signed_id}/test.bin"

      expect(response).to be_redirect
      location_on_storage_service = response.location

      get location_on_storage_service
      expect(response).to be_ok
      expect(response.body.bytesize).to eq(1024*5)
    end
  end

  describe 'ActiveStorage::Service::DiskService override' do
    it 'stores the files in a prefixed subdirectory' do
      Dir.mktmpdir do |tempdir_path|
        subject = ActiveStorage::Service::DiskService.new(root: tempdir_path)
        data = StringIO.new(Random.new.bytes(98721))

        subject.upload("tenant-abcdefg123", data)
        expect(File).to be_exist(tempdir_path + '/tenant/ab/cd/tenant-abcdefg123')
      end
    end

    it 'does not tenant-prefix a key which does not contain a "-"' do
      Dir.mktmpdir do |tempdir_path|
        subject = ActiveStorage::Service::DiskService.new(root: tempdir_path)
        data = StringIO.new(Random.new.bytes(98721))

        subject.upload("notenant", data)
        expect(File).to be_exist(tempdir_path + '/no/te/notenant')
      end
    end
  end
end
