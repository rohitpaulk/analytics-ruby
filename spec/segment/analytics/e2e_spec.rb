require 'spec_helper'

module Segment
  # End-to-end tests that send events to a segment source and verifies that a
  # webhook connected to the source (configured manually via the app) is able
  # to receive the data sent by this library.
  describe 'End-to-end tests', e2e: true do
    WRITE_KEY = 'qhdMksLsQTi9MES3CHyzsWRRt4ub5VM6'
    RUNSCOPE_BUCKET_KEY = 'pwb8mcmfks0f'

    let(:client) { Segment::Analytics.new(write_key: WRITE_KEY) }
    let(:runscope_client) { RunscopeClient.new(ENV.fetch('RUNSCOPE_TOKEN')) }

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
