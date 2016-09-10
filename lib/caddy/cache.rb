# frozen_string_literal: true
module Caddy
  class Cache
    DEFAULT_REFRESH_INTERVAL = 60
    REFRESH_INTERVAL_JITTER_PCT = 0.15

    attr_accessor :refresher, :refresh_interval, :error_handler

    ##
    # Create a new cache with key +key+.
    def initialize(key)
      @task = nil
      @refresh_interval = DEFAULT_REFRESH_INTERVAL
      @cache = nil
      @key = key
    end

    ##
    # Convenience method for getting the value of the refresher-returned object at path +k+,
    # assuming the refresher-returned value responds to <tt>[]</tt>.
    #
    # If not, #cache can be used instead to access the refresher-returned object.
    def [](k)
      cache[k]
    end

    ##
    # Returns the refresher-produced value that is used as the cache.
    def cache
      raise "Please run `Caddy.start` before attempting to access the cache" unless @task && @task.running?
      raise "Caddy cache access of :#{@key} before initial load; allow some more time for your app to start up" unless @cache

      @cache
    end

    ##
    # Starts the period refresh cycle.
    #
    # Every +refresh_interval+ seconds -- smoothed by a jitter amount (a random amount +/- +REFRESH_INTERVAL_JITTER_PCT+) --
    # the refresher lambda is called and the results stored in +cache+.
    #
    # Note that the result of the refresh is frozen to avoid multithreading mutations.
    def start
      unless refresher && refresher.respond_to?(:call)
        raise "Please set your cache refresher via `Caddy[:#{@key}].refresher = -> { <code that returns a value> }`"
      end

      raise "`Caddy[:#{@key}].refresh_interval` must be > 0" unless refresh_interval > 0

      jitter_amount = [0.1, refresh_interval * REFRESH_INTERVAL_JITTER_PCT].max
      interval = refresh_interval + rand(-jitter_amount...jitter_amount)
      timeout_interval = [interval - 1, 0.1].max

      stop # stop any existing task from running

      @task = Concurrent::TimerTask.new(
        run_now: true,
        execution_interval: interval,
        timeout_interval: timeout_interval
      ) do
        @cache = refresher.call.freeze
        nil # no need to save the value internally to TimerTask
      end

      @task.add_observer(Caddy::TaskObserver.new(error_handler, @key))
      @task.execute

      @task.running?
    end

    ##
    # Stops the current executing refresher.
    #
    # The current cache value is persisted even if the task is stopped.
    def stop
      @task.shutdown if @task && @task.running?
    end
  end
end
