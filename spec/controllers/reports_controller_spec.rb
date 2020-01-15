require 'rails_helper'

describe ReportsController, type: :controller do
  include JiraHelper
  include WebMockHelper

  describe '#total_remaing_time_in_sprint' do
    before do
      @user = create(:user, :junior)
      jira_api_search_issue_stub_request(
        jql: jql,
        fields: fields,
        max_results: 5000,
        file_path: "#{API_TEST_DATA_PATH}/search_sprint_assignee_response.json"
      )
      WebMock.enable!
    end
    let(:params) {{ user_ids: user_id, sprint_id: sprint_id }}
    let(:jql) { "Sprint = #{sprint_id} AND assignee in (#{jira_id})" }
    let(:fields) { "key,status,timetracking" }
    let(:user_id) { @user.id }
    let(:jira_id) { @user.jira_id }
    context 'when sprint_id is presence' do
      let(:sprint_id) { 1 }
      it 'can get total remain estimate in the sprint' do
        get :total_remaing_time_in_sprint, params: params

        expect(response.status).to eq 200
        json_data = JSON.parse(response.body)["data"]
        expect(json_data['total_remaing_times'].count).to eq 1
        expect(json_data['total_remaing_times'].first["user_id"]).to eq user_id
        expect(json_data['total_remaing_times'].first["jira_id"]).to eq jira_id
        expect(json_data['total_remaing_times'].first["total_remaing_time"]).to eq (18000 + 14400)
      end
    end
    context 'when sprint_id is nil' do
      let(:sprint_id) { nil }
      it 'can get total remain estimate in the sprint' do
        get :total_remaing_time_in_sprint, params: params

        expect(response.status).to eq 400
        expect(JSON.parse(response.body)["message"]).to eq "Bad Request"
      end
    end
  end
end
