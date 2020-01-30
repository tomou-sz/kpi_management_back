class ReportsController < ApplicationController
  include JiraInitializer

  def save_sprint_remaining_time
    sprint_id = params[:sprint_id]
    return response_bad_request if sprint_id.blank?

    users = User.all
    sprint_remaining_times = { sprint_id: sprint_id, remaining_times: [] }
    created_at = Time.zone.now
    ActiveRecord::Base.transaction do
      users.each do |user|
        remaining_time = 0
        jira_id = user.jira_id
        if jira_id.blank?
          logger.warn "This user doesn't have jira_id. user_id: #{user_id}"
          next
        end
        logger.info "---User: #{jira_id} Sprint Remaining Time---"
        issues = @client.Issue.jql(
          "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
          fields: [:key, :status, :timetracking],
          max_results: 5000,
          start_index:0
        )
        issues.each do |issue|
          issue_fields = issue.attrs['fields']
          if issue_fields['status']['statusCategory']['key'] != 'done'
            issue_remaining_time = issue_fields['timetracking']['remainingEstimateSeconds']
            logger.info "Issue: #{issue.attrs['key']}, Remaining Time: #{issue_remaining_time}"
            remaining_time += issue_remaining_time
          end
        end
        user_id = user.id
        SprintRemainingTime.create!(user_id: user_id, jira_id: jira_id, sprint_id: sprint_id, remaining_time: remaining_time, created_at: created_at)
        sprint_remaining_times[:remaining_times] << { user_id: user_id, jira_id: jira_id, remaining_time: remaining_time }
      end
    end
    response_success(self.class.name, self.action_name, sprint_remaining_times)
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  def total_sprint_remaining_time
    user_ids = params[:user_ids].split(',').map(&:to_i)
    sprint_id = params[:sprint_id]
    @total_sprint_remaining_time =
      Rails.cache.fetch("total_sprint_remaining_time_user_ids_#{user_ids.join('-')}_sprint_id_#{sprint_id}") do
        return response_bad_request if sprint_id.blank?

        users = User.where(id: user_ids)
        not_found_user_ids = user_ids - users.ids
        logger.warn "These user cannot be found. user_ids: #{not_found_user_ids}" if not_found_user_ids.present?

        total_sprint_remaining_time = { sprint_id: sprint_id, total_remaining_times: [] }
        sprint_remaining_times = SprintRemainingTime.where(user_id: users.ids).group_by(&:created_at)
        sprint_remaining_times.keys.each do |created_at|
          hash = { date: created_at, remaining_times: [] }
          sprint_remaining_times[created_at].each do |sprint_remaining_time|
            hash[:remaining_times] << {
              jira_id: sprint_remaining_time.jira_id,
              remaining_time: sprint_remaining_time.remaining_time
            }
          end
          total_sprint_remaining_time[:total_remaining_times] << hash
        end
        total_sprint_remaining_time
      end
    response_success(self.class.name, self.action_name, @total_sprint_remaining_time)
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
