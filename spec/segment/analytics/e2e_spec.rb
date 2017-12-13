require 'spec_helper'

module Segment
  # End-to-end tests that send events to a segment source and verifies that a
  # webhook connected to the source (configured manually via the app) is able
  # to receive the data sent by this library.
  describe 'End-to-end tests', e2e: true do
    WRITE_KEY = 'kzt5bZFLzc0sl8qBoJ7j7zcv512Z5MpM'
    RUNSCOPE_BUCKET_KEY = 'gefzlpt8ao5r'

    let(:client) { Segment::Analytics.new(write_key: WRITE_KEY) }
    let(:runscope_client) {
      RunscopeClient.new('46adda7b-a85e-4842-b6af-1785e0a8049a')
    }

    it 'tracks events' do
      id = SecureRandom.uuid
      client.track(
        user_id: 'dummy_user_id',
        event: 'E2E Test',
        properties: { id: id }
      )
      client.flush

      # Allow events to propagate to runscope
      eventually(timeout: 30) {
        expect(has_matching_request?(id)).to eq(true)
      }
    end

    def has_matching_request?(id)
      captured_requests = runscope_client.requests(RUNSCOPE_BUCKET_KEY)
      captured_requests.any? do |request|
        begin
          body = JSON.parse(request['body'])
          body['properties'] && body['properties']['id'] == id
        rescue JSON::ParserError
          false
        end
      end
    end
  end
end
