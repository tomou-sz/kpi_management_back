require 'rails_helper'

RSpec.describe UsersController, :type => :controller do
  include JiraHelper
  include WebMockHelper

  describe '#index' do
    before do
      create(:user, :junior)
      create(:user, :senior)
      create(:user, :leader)
    end
    it do
      get :index
      json_data = JSON.parse(response.body)["data"]
      expect(response.status).to eq 200
      expect(json_data.size).to eq 3
    end
  end

  describe '#sprint_tickets' do
    before do
      @user = create(:user, :junior)
      jira_api_search_issue_stub_request(
        jql: jql,
        fields: fields,
        max_results: max_results,
        file_path: "#{API_TEST_DATA_PATH}/search_sprint_assignee_response.json"
      )
      WebMock.enable!
    end
    let(:params) {{ user_id: user_id, sprint_id: sprint_id }}
    let(:jql) { "Sprint = #{sprint_id} AND assignee in (#{jira_id})" }
    let(:fields) { "key,summary,issuetype,status,timetracking,customfield_10101" }
    let(:max_results) { 5000 }
    context 'when user can be found' do
      let(:user_id) { @user.id }
      let(:jira_id) { @user.jira_id }
      context 'when jira_id and sprint_id is presence' do
        let(:sprint_id) { 1 }
        it 'can get sprint tickets' do
          get :sprint_tickets, params: params

          expect(response.status).to eq 200
          json_data = JSON.parse(response.body)["data"]
          test_data = JSON.parse(File.read("#{Rails.root}/spec/fixtures/jira/rest/api/2.0/search_sprint_assignee_response.json"))["issues"]
          expect(json_data["user_id"]).to eq @user.id
          expect(json_data["jira_id"]).to eq jira_id
          expect(json_data["target_sprint_id"]).to eq sprint_id.to_s
          expect(json_data["sprint_tickets"].count).to eq test_data.count
        end
      end
    end
  end

  describe '#ticket_attributes' do
    before do
      test_data_issues = JSON.parse(File.read("#{API_TEST_DATA_PATH}/search_sprint_assignee_response.json"))["issues"]
      jira_resouce_issues =  build_issue(jira_client, test_data_issues)
      @response = controller.send(:ticket_attributes, jira_resouce_issues.first)
    end
    let(:jql) { "Sprint = 1 AND assignee in (test)" }
    let(:fields) { "key,summary,issuetype,status,timetracking,customfield_10101" }
    let(:max_results) { 5000 }
    # Take a look test data of first issue
    # spec/fixtures/jira/rest/api/2.0/search_sprint_assignee_response.json
    it {
      expect(@response[:key]).to eq "TEST-1823"
      expect(@response[:summary]).to eq "[ContentsManagement][MyContents][BE] Weird file appears on S3"
      expect(@response[:issuetype]).to eq "Bug"
      expect(@response[:sprint_ids]).to eq ["1"]
      expect(@response[:original_estimate_seconds]).to eq 3600
      expect(@response[:remaining_estimate_seconds]).to eq 0
      expect(@response[:time_spent_seconds]).to eq 3600
      expect(@response[:status][:key]).to eq "indeterminate"
      expect(@response[:status][:name]).to eq "Review"
    }
  end

end
