class DailyWorkLogsController < ApplicationController
  include JiraInitializer
  def get_work_log
    begin
      jira_id = params[:jira_id]
      target_date = params[:date]
      @daily_work_log =
        Rails.cache.fetch("daily_work_log_jira_id_#{jira_id}_date_#{target_date}") do
          issues = @client.Issue.jql(
            "worklogAuthor = #{jira_id}",
            fields:[:key,:worklog],
            max_results: 5000,
            start_index:0
          )
          total_time_spent = 0
          issues.each do |issue|
            worklogs = issue.fields['worklog']['worklogs']
            worklogs.each do |worklog|
              author_name = worklog['author']['name']
              time_spent = worklog['timeSpentSeconds']
              date = worklog['started'][0,10]
              total_time_spent += time_spent if jira_id == author_name && target_date == date
            end
          end
          {jira_id: jira_id, total_time_spent: (total_time_spent/3600)}
        end
      response_success(self.class.name, self.action_name, @daily_work_log)
    end
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
