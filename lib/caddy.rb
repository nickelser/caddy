# frozen_string_literal: true
require "caddy/version"
require "concurrent/timer_task"

module Caddy
  class << self
    attr_accessor :refresher, :refresher_error_handler
    attr_writer :refresh_interval
  end

  DEFAULT_REFRESH_INTERVAL = 60
  REFRESH_INTERVAL_JITTER_PCT = 0.15

  def self.[](k)
    raise "Please run `Caddy.start` before attempting to access values" unless @task
    raise "Caddy variable access before initial load; allow some more time for your app to start up" unless @task.value
    @task.value[k]
  end

  def self.start
    unless refresher
      raise "Please set your cache refresher via `Caddy.refresher = -> { <code that returns a value> }`"
    end

    jitter_amount = [1, refresh_interval * REFRESH_INTERVAL_JITTER_PCT].max
    interval = refresh_interval + rand(-jitter_amount...jitter_amount)

    task = Concurrent::TimerTask.new(
      run_now: true,
      execution_interval: interval,
      timeout_interval: interval - 1) { refresher.call }

    task.add_observer(InternalCaddyTaskObserver.new)
    task.execute

    _stop_internal # stop any existing task from running

    @task = task # and transfer over the new task
  end

  def self.stop
    raise "Please run `Caddy.start` before running `Caddy.stop`" unless @task

    _stop_internal
  end

  def self.refresh_interval
    @refresh_interval || DEFAULT_REFRESH_INTERVAL
  end

  private_class_method def self._stop_internal
    @task.shutdown if @task && @task.running?
  end

  class InternalCaddyTaskObserver
    def update(time, _, boom)
      return unless boom

      if Caddy.refresher_error_handler
        if Caddy.refresher_error_handler.respond_to?(:call)
          begin
            Caddy.refresher_error_handler.call(boom)
          rescue => incepted_boom
            STDERR.puts "(#{time}) Caddy error handler itself errored: #{incepted_boom}"
          end
        else
          # rubocop:disable Style/StringLiterals
          STDERR.puts 'Caddy error handler not callable. Please set the error handler like:'\
                      ' `Caddy.refresher_error_handler = -> (e) { puts "#{e}" }`'
          # rubocop:enable Style/StringLiterals

          STDERR.puts "(#{time}) Caddy refresher failed with error #{boom}"
        end
      elsif boom.is_a?(Concurrent::TimeoutError)
        STDERR.puts "(#{time}) Caddy refresher timed out"
      else
        STDERR.puts "(#{time}) Caddy refresher failed with error #{boom}"
      end
    end
  end
end
