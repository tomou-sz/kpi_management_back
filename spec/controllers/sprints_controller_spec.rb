require 'rails_helper'

RSpec.describe SprintsController, :type => :controller do
  include JiraHelper
  include WebMockHelper

  before do
    WebMock.enable!
  end

  describe '#board_sprints' do
    before do
      jira_agile_board_stub_request(board_id: board_id, file_path: "#{Rails.root}/spec/fixtures/jira/rest/agile/1.0/board_key_response.json")
      jira_agile_board_sprint_stub_request(board_id: board_id, file_path: "#{AGILE_TEST_DATA_PATH}/board_key_sprint_response.json")
    end
    let(:board_id) { ENV['JIRA_MAIN_PROJECT_BOARD_ID'] }
    context 'when JIRA API can return board and sprints JSON' do
      it 'can get board sprints' do
        get :board_sprints

        expect(response.status).to eq 200
        json_data = JSON.parse(response.body)["data"]
        test_data = JSON.parse(File.read("#{Rails.root}/spec/fixtures/jira/rest/agile/1.0/board_key_sprint_response.json"))["values"]
        expect(json_data.count).to eq test_data.count

        json_data.each_with_index do |data, i|
          expect(data["state"]).to eq test_data[i]["state"]
          if data["state"] == "closed" || data["state"] == "active"
            expect(data["start_date"]).to eq test_data[i]["startDate"]
            expect(data["end_date"]).to eq test_data[i]["endDate"]
          end
        end
      end
    end
    context 'when JIRA API can return board and sprints JSON' do
      before do
        allow(JIRA::Resource::Board).to receive(:find).and_raise(JIRA::HTTPError, "Failed to get response from JIRA")
      end
      let(:key) { ENV['JIRA_MAIN_PROJECT_BOARD_ID'] }
      it 'return error code 400' do
        get :board_sprints

        expect(response.status).to eq 400
        expect(JSON.parse(response.body)["message"]).to eq "Bad Request"
      end
    end
    context 'when unexpected error happen' do
      before do
        allow(controller).to receive(:response_success).and_raise("Unexpected error happen")
      end
      let(:key) { ENV['JIRA_MAIN_PROJECT_BOARD_ID'] }
      it 'return error code 500' do
        get :board_sprints

        expect(response.status).to eq 500
        expect(JSON.parse(response.body)["message"]).to eq "Internal Server Error"
      end
    end
  end
end
