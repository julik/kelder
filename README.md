# Kelder

"Kelder" in Dutch is a private storage space assigned to an apartment in an apartment building, which is usually situated in the basement or on the ground floor. It is where a tenant stores their belongings.

This gem integrates ActiveStorage into [Apartment.](https://github.com/influitive/apartment) It applies a number of patches to how ActiveStorage works under the hood:

* It prefixes the `key` attribute of all ActiveStorage blobs with the short version of the tenant schema name. This prevents attachments from one tenant overwriting other tenant's attachments
* It changes the directory partitioning scheme of the ActiveStorage disk service so that the directories start with the short version of the tenant name, and partition underneat that directory
* It installs a small version of an `Elevator` inside the stock Rails ActiveStorage controllers, so that uploads go to the correct tenant automatically (or semi-automatically)
* It embeds the tenant name in the ActiveStorage signed IDs which ensures that the Blob always gets retrieved from the correct tenant

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kelder'
```

You do not have to do anything else. Note that if you cache the signed IDs of your ActiveStorage blobs (used in thumbnail display, for example, or as part of your partials) you might want to flush
that cache. Existing blobs already uploaded on your application do not need to be changed.

## Usage

If you are using Apartment with subdomain tenanting it means that all of your ActiveStorage controllers will use the Elevator middleware you have configured for your application, by default. This
means that you do not have to do anything at all - everything will happen automatically.

If you do not have an Elevator middleware around your entire Rails application or your application switches tenants using paths, see below.

## Explicitly switching tenants during upload

You can hint the ActiveStorage controllers which tenant you want to upload to. These controllers are mounted under the `/rails` scope in the Rails routes, so if you switch tenants using
a path (for example `"/shops/:tenant_name/products"` etc.) these controllers are not going to be switching into the right tenant by themselves. Most of these controllers will know which
tenant to switch to due to the changes Kelder does to the signed ID of the attachment Blobs **except the direct upload endpoint**. For the direct upload endpoint you need to add a
query string parameter to your direct upload URL which is called `signed_tenant_name`. It has to be generated like this:

```ruby
Kelder.signed_tenant_name
```

You need to inject it into your direct upload URL, and tell the ActiveStorage JS module that you want to use that URL instead of the built-in one. So in your Rails view you can inject
a `meta` element:

```
  <meta name="direct-upload-path" content="<%= rails_direct_uploads_path(signed_tenant_name: Kelder.signed_tenant_name) %>" />
```

and then tell ActiveStorage to use this as the direct upload URL:

```javascript

function getScopedDirectUploadURL() {
  return document.querySelector("meta[name=direct-upload-path]").getAttribute("content");
}
// ...
const upload = new ActiveStorage.DirectUpload(browserFile, getScopedDirectUploadURL(), uploadDelegate);
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/julik/kelder.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
