# frozen_string_literal: true
module Caddy
  class TaskObserver
    def initialize(error_handler, cache_name)
      @error_handler = error_handler || Caddy.error_handler
      @cache_name = cache_name
    end

    def update(_, _, boom)
      return unless boom

      if @error_handler
        if @error_handler.respond_to?(:call)
          begin
            @error_handler.call(boom)
          rescue => incepted_boom
            puts_exception("Caddy error handler itself errored handling refresh for :#{@cache_name}", incepted_boom)
          end
        else
          # rubocop:disable Style/StringLiterals
          STDERR.puts 'Caddy error handler not callable. Please set the error handler like:'\
                      ' `Caddy.error_handler = -> (e) { puts "#{e}" }`'
          # rubocop:enable Style/StringLiterals

          puts_exception("Caddy refresher for :#{@cache_name} failed with error", boom)
        end
      elsif boom.is_a?(Concurrent::TimeoutError)
        STDERR.puts "Caddy refresher for :#{@cache_name} timed out"
      else
        puts_exception("Caddy refresher for :#{@cache_name} failed with error", boom)
      end
    end

    private

    def puts_exception(msg, boom)
      STDERR.puts "\n#{msg}: #{boom}"
      STDERR.puts "\t#{boom.backtrace.join("\n\t")}"
    end
  end
end
