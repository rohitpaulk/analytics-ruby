require 'segment/analytics/defaults'
require 'segment/analytics/utils'
require 'segment/analytics/response'
require 'segment/analytics/logging'
require 'net/http'
require 'net/https'
require 'json'

module Segment
  class Analytics
    class Request
      include Segment::Analytics::Defaults::Request
      include Segment::Analytics::Utils
      include Segment::Analytics::Logging

      # public: Creates a new request object to send analytics batch
      #
      def initialize(options = {})
        options[:host] ||= HOST
        options[:port] ||= PORT
        options[:ssl] ||= SSL
        options[:headers] ||= HEADERS
        @path = options[:path] || PATH
        @retries = options[:retries] || RETRIES
        @backoff = options[:backoff] || BACKOFF

        http = Net::HTTP.new(options[:host], options[:port])
        http.use_ssl = options[:ssl]
        http.read_timeout = 8
        http.open_timeout = 4

        @http = http
      end

      # public: Posts the write key and batch of messages to the API.
      #
      # returns - Response of the status and error if it exists
      def post(write_key, batch)
        last_result, exception = retry_with_backoff(@retries, @backoff) do
          result = send_request(write_key, batch)
          should_retry = false # TODO: Use status code

          [result, should_retry]
        end

        if exception
          logger.error(exception.message)
          exception.backtrace.each { |line| logger.error(line) }
          Response.new(-1, "Connection error: #{exception}")
        else
          last_result
        end
      end

      private

      # Takes a block that returns [result, should_retry].
      #
      # Retries upto `retries_remaining` times, if `should_retry` is false or
      # an exception is raised.
      #
      # Returns [last_result, raised_exception]
      def retry_with_backoff(retries_remaining, backoff, &block)
        result, caught_exception = nil
        should_retry = false

        begin
          result, should_retry = yield
          return [result, nil] unless should_retry
        rescue Exception => e
          should_retry = true
          caught_exception = e
        end

        if should_retry && (retries_remaining > 1)
          sleep(backoff)
          retry_with_backoff(retries_remaining - 1, backoff, &block)
        else
          [result, caught_exception]
        end
      end

      # Sends a request for the batch, returns a `Response` object.
      def send_request(write_key, batch)
        headers = {
          'Content-Type' => 'application/json',
          'accept' => 'application/json'
        }
        payload = JSON.generate(
          :sentAt => datetime_in_iso8601(Time.now),
          :batch => batch
        )
        request = Net::HTTP::Post.new(@path, headers)
        request.basic_auth(write_key, nil)

        if self.class.stub
          status = 200
          error = nil
          logger.debug "stubbed request to #{@path}: " \
                       "write key = #{write_key}, payload = #{payload}"
        else
          res = @http.request(request, payload)
          status = res.code.to_i
          body = JSON.parse(res.body)
          error = body['error']
        end

        Response.new(status, error)
      end

      class << self
        attr_writer :stub

        def stub
          @stub || ENV['STUB']
        end
      end
    end
  end
end
