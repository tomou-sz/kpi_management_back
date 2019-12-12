require 'rails_helper'

RSpec.describe DailyWorkLogsController, :type => :controller do
  include JiraHelper
  include WebMockHelper

  before do
    WebMock.enable!
  end
  describe '#get_work_log' do
    before do
      jira_api_search_issue_stub_request(
        jql: "worklogAuthor = #{jira_id}",
        fields: "key,worklog",
        max_results: 5000,
        file_path: "#{API_TEST_DATA_PATH}/search_worklog_author_response.json"
      )
    end
    let(:params) {{ jira_id: jira_id, date: date }}
    let(:jira_id) { "test" }
    let(:date) { "2019-12-09" }
    context 'when JIRA API can return issues JSON' do
      it do
        get :get_work_log, params: params

        expect(response.status).to eq 200
        json_data = JSON.parse(response.body)["data"]
        expect(json_data["jira_id"]).to eq "test"
        # Take a look test data whose startAt is 2019-12-09
        # spec/fixtures/jira/rest/api/2.0/search_worklog_author_response.json
        expect(json_data["total_time_spent"]).to eq (28800 + 10800 + 14400 + 21600 + 7200)/3600
      end
    end
    context 'when JIRA API cannot return issues JSON' do
      before do
        allow_any_instance_of(JIRA::Resource::IssueFactory).to receive(:jql).and_raise(JIRA::HTTPError, "Failed to get response from JIRA")
      end
      it 'return error code 400' do
        get :get_work_log, params: params

        expect(response.status).to eq 400
        expect(JSON.parse(response.body)["message"]).to eq "Bad Request"
      end
    end
    context 'when unexpected error happen' do
      before do
        allow(controller).to receive(:response_success).and_raise("Unexpected error happen")
      end
      it 'return error code 500' do
        get :get_work_log, params: params

        expect(response.status).to eq 500
        expect(JSON.parse(response.body)["message"]).to eq "Internal Server Error"
      end
    end
  end

end
