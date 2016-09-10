# frozen_string_literal: true
require "concurrent/timer_task"

require "caddy/version"
require "caddy/task_observer"
require "caddy/cache"

module Caddy
  class << self
    attr_accessor :error_handler
  end

  @started_pid = nil
  @caches = Hash.new { |h, k| h[k] = Caddy::Cache.new(k) }

  ##
  # Returns the cache object for key +k+.
  #
  # If the cache at +k+ does not exist yet, Caddy will initialize an empty one.
  def self.[](k)
    @caches[k]
  end

  ##
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
      raise "Please run `Caddy.start` *after* forking, as the refresh thread will get killed after fork"
    end

    @caches.freeze

    @caches.values.each(&:start).all?
  end

  ##
  # Cleanly shut down all currently running refreshers.
  def self.stop
    @caches.values.each(&:stop).all?
  end

  ##
  # Start and then stop again all refreshers. Useful for triggering an immediate refresh of all caches.
  def self.restart
    stop
    start
  end
end
