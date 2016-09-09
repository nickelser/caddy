# frozen_string_literal: true
module Caddy
  class Cache
    DEFAULT_REFRESH_INTERVAL = 60
    REFRESH_INTERVAL_JITTER_PCT = 0.15

    attr_accessor :refresher, :refresh_interval, :error_handler

    def initialize(key)
      @task = nil
      @refresh_interval = DEFAULT_REFRESH_INTERVAL
      @cache = nil
      @key = key
    end

    def [](k)
      cache[k]
    end

    def cache
      raise "Please run `Caddy.start` before attempting to access the cache" unless @task && @task.running?

      @cache
    end

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
        begin
          @cache = refresher.call.freeze
        rescue
          raise
        end
      end

      @task.add_observer(Caddy::TaskObserver.new(error_handler, @key))
      @task.execute

      @task.running?
    end

    def stop
      @task.shutdown if @task && @task.running?
    end
  end
end
