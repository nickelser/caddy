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

  def self.[](k)
    @caches[k]
  end

  def self.caches
    @caches
  end

  def self.start
    if !@started_pid
      @started_pid = $$
    elsif @started_pid && $$ != @started_pid
      raise "Please run `Caddy.start` *after* forking, as the refresh thread will get killed after fork"
    end

    @caches.values.each(&:start).all?
  end

  def self.stop
    @caches.values.each(&:stop).all?
  end

  def self.restart
    stop
    start
  end
end
