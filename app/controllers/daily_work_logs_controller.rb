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
          daily_work_log_hash = { jira_id: jira_id }
          sprint_issues = []
          issues.each do |issue|
            worklogs = issue.fields['worklog']['worklogs']
            worklogs.each do |worklog|
              author_name = worklog['author']['name']
              time_spent = worklog['timeSpentSeconds'].to_i
              date = worklog['started'][0,10]
              if jira_id == author_name && target_date == date
                total_time_spent += time_spent
                sprint_issues << { key: issue.attrs['key'], time_spent: time_spent }
              end
            end
          end
          daily_work_log_hash[:total_time_spent] = total_time_spent / 3600.0
          daily_work_log_hash[:issues] = sprint_issues
          daily_work_log_hash
        end
      response_success(self.class.name, self.action_name, @daily_work_log)
    end
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
