# frozen_string_literal: true
module Caddy
  class TaskObserver
    def update(_, _, boom)
      return unless boom

      if Caddy.error_handler
        if Caddy.error_handler.respond_to?(:call)
          begin
            Caddy.error_handler.call(boom)
          rescue => incepted_boom
            puts_exception("Caddy error handler itself errored", incepted_boom)
          end
        else
          # rubocop:disable Style/StringLiterals
          STDERR.puts 'Caddy error handler not callable. Please set the error handler like:'\
                      ' `Caddy.error_handler = -> (e) { puts "#{e}" }`'
          # rubocop:enable Style/StringLiterals

          puts_exception("Caddy refresher failed with error", boom)
        end
      elsif boom.is_a?(Concurrent::TimeoutError)
        STDERR.puts "Caddy refresher timed out"
      else
        puts_exception("Caddy refresher failed with error", boom)
      end
    end

    private

    def puts_exception(msg, boom)
      STDERR.puts "\n#{msg}: #{boom}"
      STDERR.puts "\t#{boom.backtrace.join("\n\t")}"
    end
  end
end
