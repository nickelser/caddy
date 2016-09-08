# Caddy [![Build Status](https://travis-ci.org/nickelser/caddy.svg?branch=master)](https://travis-ci.org/nickelser/caddy) [![Code Climate](https://codeclimate.com/github/nickelser/caddy/badges/gpa.svg)](https://codeclimate.com/github/nickelser/caddy) [![Test Coverage](https://codeclimate.com/github/nickelser/caddy/badges/coverage.svg)](https://codeclimate.com/github/nickelser/caddy) [![Gem Version](https://badge.fury.io/rb/caddy.svg)](http://badge.fury.io/rb/caddy)

Caddy is an asynchronously updated store that is updated on an interval to store objects that you can access quickly during requests. The cache refresher function can be as slow as you would like and it will not affect your request-time performance.

It's powered by [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby), a battle-tested and comprehensive thread-based (& thread-safe) concurrency library.

```ruby
# in your initializers (caddy.rb would be a wonderful name)
Caddy.refresher = lambda do
  {
    flags: SomeFlagService.fetch_flags, # this can take a few seconds; it won't block requests when you use it later
    cache_keys: SomeCacheKeyService.cache_keys
  }
end

Caddy.refresh_interval = 5.minutes # default is 60 seconds

# ... after your application forks
Caddy.start

# ... in a controller
def index
  # the Caddy requests are instant, and are up-to-date (as of 5 minutes ago, as specified above)
  # you could use this for high-level feature flags, cache dumping
  if Caddy[:flags][:fuzz_bizz] # Caddy provides a convenience method to access the cache by key; you can also access
                               # it directly with Caddy.cache[:flags][...]
    Rails.cache.fetch("#{Caddy[:cache_keys][:global_key]}/#{Caddy[:cache_keys][:index_key]}/foo/bar") do
      # wonderful things happen here
    end
  end
end
```

## Using Caddy with Unicorn

You need to start Caddy after fork:

```ruby
# in your unicorn.rb initializer
after_fork do |server, worker|
  Caddy.start

  # ... your magic here
end
```

## Using Caddy with Puma

Similarly, after work boot:

```ruby
# in your puma.rb initializer
on_worker_boot do |server, worker|
  Caddy.start

  # ... your magic here
end
```

## Using Caddy with Spring

In the same vein, with developing with Spring, you need to have Caddy start after fork:

```ruby
# in your caddy.rb initializer, perhaps

if Rails.env.development? && defined?(Spring)
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
