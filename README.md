# Caddy [![Build Status](https://travis-ci.org/nickelser/caddy.svg?branch=master)](https://travis-ci.org/nickelser/caddy) [![Code Climate](https://codeclimate.com/github/nickelser/caddy/badges/gpa.svg)](https://codeclimate.com/github/nickelser/caddy) [![Test Coverage](https://codeclimate.com/github/nickelser/caddy/badges/coverage.svg)](https://codeclimate.com/github/nickelser/caddy) [![Gem Version](https://badge.fury.io/rb/caddy.svg)](http://badge.fury.io/rb/caddy)

Caddy is an asynchronously updated store that is updated on an interval to store objects that you can access quickly during requests.

Caddy is great for storing information like feature flags -- accessed extremely frequently during many requests, updated relatively rarely and usually safe to be stale by some small duration.

It's powered by [concurrent-ruby](https://github.com/ruby-concurrency/concurrent-ruby), a battle-tested and comprehensive thread-based (& thread-safe) concurrency library.

![Architecture Diagram](https://rawgit.com/nickelser/caddy/master/docs/architecture.svg)

```ruby
# in your initializers (caddy.rb would be a wonderful name)
Caddy[:flags].refresher = lambda do
  SomeFlagService.fetch_flags # this can take a few seconds; it won't block requests when you use it later
end

# you can have multiple cache stores, refreshed at different intervals
Caddy[:cache_keys].refresher = lambda do
  SomeCacheKeyService.cache_keys
end

Caddy[:flags].refresh_interval = 30.seconds # default is 60 seconds; the actual amount is smoothed slightly
                                            # to avoid a stampeding herd of refreshes
Caddy[:cache_keys].refresh_interval = 5.minutes

# ... after your application forks (see the guide below for Unicorn, Puma & Spring)
Caddy.start

# ... in a controller
def index
  # Caddy provides a convenience method to access the cache by key; you can also access
  # what your refresher returns directly with Caddy[:flags].cache
  if Caddy[:flags][:fuzz_bizz]
    Rails.cache.fetch("#{Caddy[:cache_keys][:global_key]}/#{Caddy[:cache_keys][:index_key]}/foo/bar") do
      # wonderful things happen here
    end
  end
end
```

## Error handling

As Caddy refreshers are run in threads, exceptions are not normally reported (except by default in the logs). If your refresher errors out (or times out, which can happen if your refresher takes as long as your refresh interval to run) your error handler will be called and the cache value will remain what it was before it errored. This means your application may use stale values until your refresher stops erroring.

To add a programmatic error handler:

```ruby
Caddy[:flags].refresher = -> { SomeFlagService.fetch_flags }
Caddy.error_handler = -> (exception) { ExceptionReporter.bad_thing_happened(exception) } # global (all caches) error handler
Caddy[:flags].error_handler = -> (exception) { SpecificExceptionReporter.worse_thing_happened(exception) } # cache-specific error reporters also supported
```

## Using Caddy with Unicorn

Start Caddy after fork:

```ruby
# in your unicorn.rb initializer
after_fork do |server, worker|
  Caddy.start

  # ... your magic here
end
```

## Using Caddy with Puma

Start Caddy after the worker boots:

```ruby
# in your puma.rb initializer
on_worker_boot do |server, worker|
  Caddy.start

  # ... your magic here
end
```

## Using Caddy with Spring

Start Caddy after fork:

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
