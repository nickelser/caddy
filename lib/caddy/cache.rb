# frozen_string_literal: true
module Caddy
  class Cache
    # Default refresh interval, in seconds
    DEFAULT_REFRESH_INTERVAL = 60

    # Percentage to randomly smooth the refresh interval to avoid stampeding herd on expiration
    REFRESH_INTERVAL_JITTER_PCT = 0.15

    # @!attribute refresher
    #   @return [Proc] called on interval {#refresh_interval} with the returned object used as the cache
    attr_accessor :refresher

    # @!attribute refresh_interval
    #   @return [Numeric] number of seconds between calls to {#refresher}; timeout is set to <tt>{#refresher} - 0.1</tt>
    attr_accessor :refresh_interval

    # @!attribute error_handler
    #   @return [Proc] if unset, defaults to the global error handler (see #{Caddy.error_handler}); called when exceptions or timeouts
    #   happen within the refresher
    attr_accessor :error_handler

    # Create a new periodically updated cache.
    # @param key [Symbol] the name of this cache
    def initialize(key)
      @task = nil
      @refresh_interval = DEFAULT_REFRESH_INTERVAL
      @cache = nil
      @key = key
    end

    # Convenience method for getting the value of the refresher-returned object at path +k+,
    # assuming the refresher-returned value responds to <tt>[]</tt>.
    #
    # If not, {#cache} can be used instead to access the refresher-returned object.
    # @param k key to access from the refresher-returned cache.
    def [](k)
      cache[k]
    end

    # Returns the refresher-produced value that is used as the cache.
    def cache
      raise "Please run `Caddy.start` before attempting to access the cache" unless @task && @task.running?

      unless @cache
        logger.warn "Caddy cache access of :#{@key} before initial load; doing synchronous load. Please allow some more time for your app to start up."
        refresh_cache
      end

      @cache
    end

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
        refresh_cache
        nil # no need for the {#Concurrent::TimerTask} to keep a reference to the value
      end

      @task.add_observer(Caddy::TaskObserver.new(error_handler, @key))

      logger.debug "Starting Caddy refresher for :#{@key}, updating every #{interval.round(1)}s."

      @task.execute

      @task.running?
    end

    # Stops the current executing refresher.
    #
    # The current cache value is persisted even if the task is stopped.
    def stop
      @task.shutdown if @task && @task.running?
    end

    def task
      @task
    end

    private

    # Delegates logging to the module logger
    def logger
      Caddy.logger
    end

    # Updates the internal cache object. We freeze the result to avoid mutation errors.
    def refresh_cache
      @cache = refresher.call.freeze
    end
  end
end
