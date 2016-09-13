# frozen_string_literal: true
require "concurrent/timer_task"

require "caddy/version"
require "caddy/task_observer"
require "caddy/cache"

# Caddy gives you a auto-updating global cache to speed up requests
module Caddy
  class << self
    # @!attribute error_handler
    #   @return [Proc] called when any cache refresher throws an exception (or times out)
    attr_accessor :error_handler

    # see {#logger}
    attr_writer :logger
  end

  @started_pid = nil
  @caches = Hash.new { |h, k| h[k] = Caddy::Cache.new(k) }

  # Returns the cache object at a key.
  #
  # If the cache at +k+ does not exist yet, Caddy will initialize an empty one.
  #
  # @param k [Symbol] the cache key.
  # @return [Caddy::Cache] the cache object at key +k+.
  def self.[](k)
    @caches[k]
  end

  # Starts the Caddy refresh processes for all caches.
  #
  # If the refresh process was started pre-fork, Caddy will error out, as this means
  # the refresh process would have been killed by the fork.
  #
  # Caddy freezes the hash of caches at this point, so no more further caches can be
  # added after start.
  def self.start
    if !@started_pid
      @started_pid = $$
    elsif @started_pid && $$ != @started_pid
      # raise "Please run `Caddy.start` *after* forking, as the refresh thread will get killed after fork"
    end

    logger.info "Starting Caddy with refreshers: #{@caches.keys.join(', ')}"

    @caches.values.each(&:start).all?
  end

  # Cleanly shut down all currently running refreshers.
  def self.stop
    logger.info "Stopping Caddy refreshers"

    @caches.values.each(&:stop).all?
  end

  # Start and then stop all refreshers. Useful for triggering an immediate refresh of all caches.
  def self.restart
    stop
    start
  end

  # @!attribute logger
  #   @return [Logger] logger used for all non-fatals; defaults to the Rails logger if it exists
  def self.logger
    @logger ||= begin
      if defined?(Rails.logger)
        Rails.logger
      else
        @logger ||= Logger.new(STDOUT).tap do |logger|
          logger.formatter = -> (_, datetime, _, msg) { "#{datetime}: #{msg}\n" }
        end
      end
    end
  end
end
