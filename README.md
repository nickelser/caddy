# Caddy (WORK IN PROGRESS)

Holds your stuff, and keeps it up to date.

```ruby
# in your initializers (caddy.rb would be a wonderful name)
Caddy.refresher = -> { Hash[SomeKeyValueModel.all.map { |skvm| [skvm.key.to_sym, skvm.value } }
Caddy.refresh_interval = 5.minutes # default is 60 seconds

# ... in your unicorn.rb/puma.rb after fork/start
Caddy.start

# ... in a controller
def index
  # the Caddy requests are instant, and are up-to-date (as of 5 minutes ago, as specified above)
  # you could use this for high-level feature flags, cache dumping
  if Caddy[:use_the_fast_index]
    Rails.cache.fetch("#{Caddy[:global_cache_version}/#{Caddy[:foo_index_cache_version}/foo/bar") do
      # wonderful things happen here
    end
  end
end
```

## Using Caddy with Spring (in development)

For testing Caddy in development with Spring, you need to have Caddy start after fork:

```ruby
# in your caddy.rb initializer, perhaps

if Rails.env.development?
  Spring.after_fork do
    Caddy.start
  end
end
```

## Give it to me!

Add this line to your application's Gemfile:

```ruby
gem "caddy"
```

## Semantic Versioning

This project conforms to [semver](http://semver.org/). As a result of this
policy, you can (and should) specify a dependency on this gem using the
[Pessimistic Version Constraint](http://guides.rubygems.org/patterns/) with
two digits of precision. For example:

```ruby
spec.add_dependency "caddy", "~> 1.0"
```

This means your project is compatible with caddy 1.0 up until 2.0.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

Don't forget to run the tests with `rake`.
