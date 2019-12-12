require 'rails_helper'

RSpec.describe ProductivitiesController, :type => :controller do
  include JiraHelper
  include WebMockHelper

  describe '#sprint_productivity' do
    before do
      @user = create(:user, :junior)

      jira_agile_sprint_stub_request(
        sprint_id: sprint_id,
        file_path: "#{AGILE_TEST_DATA_PATH}/sprint_key_response.json"
      )
      jira_api_search_issue_stub_request(
        jql: "Sprint = #{sprint_id} AND assignee in (#{jira_id}) AND labels not in (#{ENV['JIRA_REVIEW_LABEL']})",
        fields: fields_main_project,
        max_results: max_results,
        file_path: "#{API_TEST_DATA_PATH}/search_sprint_assignee_label_not_review_response.json"
      )
      jira_api_search_issue_stub_request(
        jql: "Sprint = #{sprint_id} AND assignee in (#{jira_id}) AND labels in (#{ENV['JIRA_REVIEW_LABEL']})",
        fields: fields_main_project,
        max_results: max_results,
        file_path: "#{API_TEST_DATA_PATH}/search_sprint_assignee_label_review_response.json"
      )
      jira_api_search_issue_stub_request(
        jql: ("Project != '#{ENV['JIRA_MAIN_PROJECT_KEY']}' AND assignee = #{jira_id} AND \
        worklogDate >= '2019/12/02' AND worklogDate <= '2019/12/15' AND \
        worklogAuthor = #{jira_id}").squeeze(" "),
        fields: "key,timetracking,worklog",
        max_results: max_results,
        file_path: "#{API_TEST_DATA_PATH}/search_other_project_sprint_term_response.json"
      )
      WebMock.enable!
    end
    let(:params) {{ user_id: user_id, sprint_id: sprint_id }}
    let(:fields_main_project) { "key,summary,issuetype,status,timetracking,customfield_10101,worklog" }
    let(:max_results) { 5000 }
    context 'when user is presence' do
      let(:user_id) { @user.id }
      context 'when jira_id and sprint_id are presence' do
        let(:jira_id) { @user.jira_id }
        let(:sprint_id) { 1 }
        context 'when JIRA API can return JSON' do
          it 'can get sprint sprint productivity' do
            get :sprint_productivity, params: params

            expect(response.status).to eq 200
            json_data = JSON.parse(response.body)["data"]
            expect(json_data["user_id"]).to eq user_id
            expect(json_data["jira_id"]).to eq jira_id
            expect(json_data["target_sprint_id"]).to eq sprint_id.to_s
            expect(json_data["kpi"]["main"].present?).to eq true
            expect(json_data["kpi"]["others"].present?).to eq true
          end
        end
        context 'when JIRA API cannot return JSON' do
          before do
            allow_any_instance_of(JIRA::Resource::SprintFactory).to receive(:find).and_raise(JIRA::HTTPError, "Failed to get response from JIRA")
          end
          it 'return error code 400' do
            get :sprint_productivity, params: params

            expect(response.status).to eq 400
            expect(JSON.parse(response.body)["message"]).to eq "Bad Request"
          end
        end
        context 'when unexpected error happen' do
          before do
            allow(controller).to receive(:response_success).and_raise("Unexpected error happen")
          end
          it 'return error code 500' do
            get :sprint_productivity, params: params

            expect(response.status).to eq 500
            expect(JSON.parse(response.body)["message"]).to eq "Internal Server Error"
          end
        end
      end
      context 'when jira_id and sprint_id are blank' do
        let(:jira_id) { nil }
        let(:sprint_id) { nil }
        it 'return error code 400' do
          get :sprint_productivity, params: params

          expect(response.status).to eq 400
          expect(JSON.parse(response.body)["message"]).to eq "Bad Request"
        end
      end
    end
    context 'when user is not presence' do
      let(:user_id) { 999 }
      context 'when jira_id and sprint_id are presence' do
        let(:jira_id) { 1 }
        let(:sprint_id) { 1 }
        it 'return error code 404' do
          get :sprint_productivity, params: params

          expect(response.status).to eq 404
          expect(JSON.parse(response.body)["message"]).to eq "User Not Found"
        end
      end
    end
  end

  describe '#main_development_kpi_attributes' do
    before do
      test_data_issues = JSON.parse(File.read("#{API_TEST_DATA_PATH}/search_sprint_assignee_label_not_review_response.json"))["issues"]
      @jira_resouce_issues =  build_issue(jira_client, test_data_issues)
    end
    it do
      response = controller.send(:main_development_kpi_attributes, @jira_resouce_issues)
      # Take a look test data
      # spec/fixtures/jira/rest/api/2.0/search_sprint_assignee_label_not_review_response.json
      expect(response[:estimate_total]).to eq (3600 + 7200)
      expect(response[:done_tickets_estimate_total]).to eq 3600
    end
  end

  describe '#categorize_work_log_totals' do
    before do
      test_data_issues = JSON.parse(File.read("#{API_TEST_DATA_PATH}/search_sprint_assignee_label_not_review_response.json"))["issues"]
      jira_resouce_issues =  build_issue(jira_client, test_data_issues)
      @all_work_logs = []
      @jira_id = 'test'
      jira_resouce_issues.each { |issue| @all_work_logs += issue.attrs['fields']['worklog']['worklogs'] }

      controller.instance_variable_set('@jira_id', 'test')
      controller.instance_variable_set('@sprint_start_date', '2019-12-02'.to_date)
      controller.instance_variable_set('@sprint_end_date', '2019-12-15'.to_date)
    end
    it do
      response = controller.send(:categorize_work_log_totals, @all_work_logs)
      # Take a look test data
      # spec/fixtures/jira/rest/api/2.0/search_sprint_assignee_label_not_review_response.json
      expect(response[:sprint_work_logs_total]).to eq (3600 + 7200)
      expect(response[:carried_over_logs_total]).to eq 0
      expect(response[:do_over_logs_total]).to eq 0
    end
  end

  describe '#main_revierw_kpi_attribtues' do
    before do
      test_data_issues = JSON.parse(File.read("#{API_TEST_DATA_PATH}/search_sprint_assignee_label_review_response.json"))["issues"]
      @jira_resouce_issues =  build_issue(jira_client, test_data_issues)
    end
    it do
      response = controller.send(:main_revierw_kpi_attribtues, @jira_resouce_issues)
      # Take a look test data
      # spec/fixtures/jira/rest/api/2.0/search_sprint_assignee_label_review_response.json
      expect(response[:review_time_spend_total]).to eq (900 + 900 + 1800 + 1200)
    end
  end

  describe '#others_kpi_attribtues' do
    before do
      test_data_issues = JSON.parse(File.read("#{API_TEST_DATA_PATH}/search_other_project_sprint_term_response.json"))["issues"]
      @jira_resouce_issues =  build_issue(jira_client, test_data_issues)
      controller.instance_variable_set('@jira_id', 'test')
      controller.instance_variable_set('@sprint_start_date', '2019-12-02'.to_date)
      controller.instance_variable_set('@sprint_end_date', '2019-12-15'.to_date)
    end
    it do
      response = controller.send(:others_kpi_attribtues, @jira_resouce_issues)
      # Take a look test data
      # spec/fixtures/jira/rest/api/2.0/search_other_project_sprint_term_response.json
      expect(response[:work_logs_total]).to eq 18000
    end
  end

end
