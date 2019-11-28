class DailyWorkLogsController < ApplicationController
  include JiraInitializer

  def index
  end

  def get_work_log
    jira_id = params[:jira_id]
    total_time_spent = 0
    issues = @client.Issue.jql(
      "worklogAuthor = #{jira_id}",
      fields:[:key,:worklog],
      max_results: 5000,
      start_index:0
    )
    issues.each do |issue|
      worklogs = issue.fields['worklog']['worklogs']
      worklogs.each do |worklog|
        author_name = worklog['author']['name']
        time_spent = worklog['timeSpentSeconds']
        date = worklog['started'][0,10]
        total_time_spent += time_spent if jira_id == author_name && params[:date] == date
      end
    end
    @daily_work_log = {jira_id: jira_id, total_time_spent: (total_time_spent/3600)}
    render json: @daily_work_log
  end
end
