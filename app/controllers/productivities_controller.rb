class ProductivitiesController < ApplicationController
  include JiraInitializer

  def sprint_productivity
    user_id = params[:user_id]
    sprint_id = params[:sprint_id]
    @sprint_productivity =
      Rails.cache.fetch("sprint_productivity_user_id_#{user_id}_sprint_id_#{sprint_id}") do
        user = User.find_by(id: user_id)
        return response_not_found(user.class.name) if user.blank?

        @jira_id = user.jira_id
        return response_bad_request if @jira_id.blank? || sprint_id.blank?

        sprint_productivity_hash = { user_id: user.id, jira_id: @jira_id, target_sprint_id: sprint_id, kpi: { main: {}, others: {} }}
        begin
          sprint = @client.Sprint.find(sprint_id)
          @sprint_start_date = sprint.attrs['startDate'].to_date
          @sprint_end_date = sprint.attrs['endDate'].to_date
          logger.info("sprint_start_date: #{@sprint_start_date}, sprint_end_date: #{@sprint_end_date}")
          # Development
          development_issues = @client.Issue.jql(
            "Sprint = #{sprint_id} AND assignee in (#{@jira_id}) AND labels not in (#{ENV['JIRA_REVIEW_LABEL']})",
            fields:[:key, :summary, :issuetype, :status, :timetracking, :customfield_10101, :worklog],
            max_results: 5000,
            start_index:0
          )
          sprint_productivity_hash[:kpi][:main].merge!(main_development_kpi_attributes(development_issues))
          # Review
          review_issues = @client.Issue.jql(
            'Sprint = 21 AND assignee in (t.shida) AND labels in (Review)',
            fields:[:key, :summary, :issuetype, :status, :timetracking, :customfield_10101, :worklog],
            max_results: 5000,
            start_index:0
          )
          sprint_productivity_hash[:kpi][:main].merge!(main_revierw_kpi_attribtues(review_issues))
          # Others projects
          other_projects_issues = @client.Issue.jql(
            "Project != '#{ENV['JIRA_MAIN_PROJECT_KEY']}' AND assignee = #{@jira_id} AND
            worklogDate >= '#{@sprint_start_date.to_s.gsub('-', '/')}' AND
            worklogDate <= '#{@sprint_end_date.to_s.gsub('-', '/')}' AND
            worklogAuthor = #{@jira_id}",
            fields:[:key, :timetracking, :worklog],
            max_results: 5000,
            start_index:0
          )
          sprint_productivity_hash[:kpi][:others].merge!(others_kpi_attribtues(other_projects_issues))
          sprint_productivity_hash
        end
      end
    response_success(self.class.name, self.action_name, @sprint_productivity)
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  private

  def main_development_kpi_attributes(issues)
    estimate_total, done_tickets_estimate_total= 0, 0
    all_work_logs = []
    issues.each do |issue|
      issue_fields = issue.attrs['fields']
      original_estimate_seconds = issue_fields['timetracking']['originalEstimateSeconds'] || 0
      estimate_total += original_estimate_seconds
      done_tickets_estimate_total += original_estimate_seconds if issue_fields['status']['statusCategory']['key'] == 'done'

      all_work_logs += issue_fields['worklog']['worklogs']
    end
    main_development_kpi_attributes = {
      estimate_total: estimate_total,
      done_tickets_estimate_total: done_tickets_estimate_total
    }
    main_development_kpi_attributes.merge(categorize_work_log_totals(all_work_logs))
  end

  def categorize_work_log_totals(work_logs)
    sprint_work_logs_total, carried_over_logs_total, do_over_logs_total = 0, 0, 0
    work_logs.each do |work_log|
      log_at = work_log['started'].to_date
      time_spent_seconds = work_log['timeSpentSeconds'] || 0
      if work_log['author']['key'] == @jira_id && log_at < @sprint_start_date
        carried_over_logs_total += time_spent_seconds
      elsif work_log['author']['key'] == @jira_id && log_at > @sprint_end_date
        do_over_logs_total += time_spent_seconds
      else
        sprint_work_logs_total += time_spent_seconds
      end
    end
    {
      sprint_work_logs_total: sprint_work_logs_total,
      carried_over_logs_total: carried_over_logs_total,
      do_over_logs_total: do_over_logs_total
    }
  end

  def main_revierw_kpi_attribtues(issues)
    review_time_spend_total = 0
    issues.each { |issue| review_time_spend_total += issue.attrs['fields']['timetracking']['timeSpentSeconds'] }
    { review_time_spend_total: review_time_spend_total }
  end

  def others_kpi_attribtues(issues)
    work_logs_total = 0
    issues.each do |issue|
      issue.attrs['fields']['worklog']['worklogs'].each do |work_log|
        if work_log['author']['key'] == @jira_id && (@sprint_start_date..@sprint_end_date).include?(work_log['started'].to_date)
          work_logs_total += work_log['timeSpentSeconds']
        end
      end
    end
    { work_logs_total: work_logs_total }
  end
end
