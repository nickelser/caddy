require "caddy/version"
require "concurrent/timer_task"

module Caddy
  class << self
    attr_accessor :refresher
    attr_writer :refresh_interval
  end

  DEFAULT_REFRESH_INTERVAL = 60
  REFRESH_INTERVAL_JITTER_PCT = 0.1
  DEFAULT_INITIAL_VALUE_WAIT = 0.1

  def self.[](k)
    raise "Please run `Caddy.start` before attempting to access values" unless @task
    raise "Caddy variable access before initial load; allow some more time for your system to warm up" unless @task.value
    @task.value[k]
  end

  def self.start
    unless refresher
      raise "Please set your cache refresher via `Caddy.refresher = -> { <code that returns a value> }`"
    end

    if @task
      puts "Caddy already running; shutting it down and starting over. Please ensure you run `Caddy.start`"\
           " only after fork/worker start in your web processes."
      @task.shutdown
    end

    jitter_amount = refresh_interval * REFRESH_INTERVAL_JITTER_PCT
    interval = refresh_interval + rand(-jitter_amount...jitter_amount)

    @task = Concurrent::TimerTask.new(
      run_now: true,
      freeze_on_deref: true,
      execution_interval: interval,
      timeout_interval: interval - 1) { refresher.call }

    @task.add_observer(CaddyTaskObserver.new)
    @task.execute
  end

  def self.stop
    raise "Please run `Caddy.start` before running `Caddy.stop`" unless @task

    @task.shutdown
    @task = nil
  end

  def self.refresh_interval
    @refresh_interval || DEFAULT_REFRESH_INTERVAL
  end

  class CaddyTaskObserver
    def update(time, _, boom)
      return unless boom

      if boom.is_a?(Concurrent::TimeoutError)
        puts "(#{time}) Caddy refresher timed out"
      else
        puts "(#{time}) Caddy refresher failed with error #{boom}"
      end
    end
  end
end
