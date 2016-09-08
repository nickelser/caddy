# frozen_string_literal: true
require "caddy/version"
require "caddy/task_observer"
require "concurrent/timer_task"

module Caddy
  class << self
    attr_accessor :refresher, :error_handler, :refresh_interval
  end

  DEFAULT_REFRESH_INTERVAL = 60
  REFRESH_INTERVAL_JITTER_PCT = 0.15

  @task = nil
  @refresh_interval = DEFAULT_REFRESH_INTERVAL
  @_started_pid = nil

  def self.[](k)
    cache[k]
  end

  def self.cache
    raise "Please run `Caddy.start` before attempting to access the cache" unless @task
    raise "Caddy cache access before initial load; allow some more time for your app to start up" unless @task.value

    @task.value
  end

  def self.start
    unless refresher && refresher.respond_to?(:call)
      raise "Please set your cache refresher via `Caddy.refresher = -> { <code that returns a value> }`"
    end

    raise "`Caddy.refresh_interval` must be > 0" unless refresh_interval > 0

    if @_started_pid && $$ != @_started_pid
      raise "Please run `Caddy.start` *after* forking, as the refresh thread will get killed after fork"
    end

    jitter_amount = [1, refresh_interval * REFRESH_INTERVAL_JITTER_PCT].max
    interval = refresh_interval + rand(-jitter_amount...jitter_amount)
    timeout_interval = [interval - 1, 0.1].max

    stop # stop any existing task from running

    @task = Concurrent::TimerTask.new(
      run_now: true,
      execution_interval: interval,
      timeout_interval: timeout_interval
    ) { refresher.call }

    @task.add_observer(Caddy::TaskObserver.new)
    @task.execute

    @_started_pid = $$

    @task.running?
  end

  def self.stop
    @task.shutdown if @task && @task.running?
  end
end
