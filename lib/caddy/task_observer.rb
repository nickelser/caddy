# frozen_string_literal: true
module Caddy
  # {TaskObserver} is used internally to monitor the status of the running refreshers
  # @private
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
            log_exception("Caddy error handler itself errored handling refresh for :#{@cache_name}", incepted_boom)
          end
        else
          # rubocop:disable Style/StringLiterals
          logger.error 'Caddy error handler not callable. Please set the error handler like:'\
                       ' `Caddy.error_handler = -> (e) { puts "#{e}" }`'
          # rubocop:enable Style/StringLiterals

          log_exception("Caddy refresher for :#{@cache_name} failed with error", boom)
        end
      elsif boom.is_a?(Concurrent::TimeoutError)
        logger.error "Caddy refresher for :#{@cache_name} timed out"
      else
        log_exception("Caddy refresher for :#{@cache_name} failed with error", boom)
      end
    end

    private

    def log_exception(msg, boom)
      logger.error "\n#{msg}: #{boom}"
      logger.error "\t#{boom.backtrace.join("\n\t")}"
    end

    def logger
      Caddy.logger
    end
  end
end
