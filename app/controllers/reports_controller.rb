class ReportsController < ApplicationController
  include JiraInitializer

  def total_remaing_time_in_sprint
    user_ids = params[:user_ids].split(',').map(&:to_i)
    sprint_id = params[:sprint_id]
    @total_remaing_time_in_sprint =
      Rails.cache.fetch("total_remaing_time_in_sprint_user_ids_#{user_ids.join('-')}_sprint_id_#{sprint_id}") do
        return response_bad_request if sprint_id.blank?

        users = User.where(id: user_ids)
        not_found_user_ids = user_ids - users.ids
        logger.warn "These user cannot be found. user_ids: #{not_found_user_ids}" if not_found_user_ids.present?

        total_remaing_time_in_sprint = { sprint_id: sprint_id, total_remaing_times: [] }
        users.each do |user|
          total_remaing_time_hash = { user_id:  user.id, jira_id: '', total_remaing_time: 0 }
          jira_id = user.jira_id
          if jira_id.blank?
            logger.warn "This user doesn't have jira_id. user_id: #{user_id}"
            total_remaing_time_in_sprint[:total_remaing_times] << total_remaing_time_hash
            next
          end
          total_remaing_time_hash[:jira_id] = jira_id
          begin
            issues = @client.Issue.jql(
              "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
              fields: [:key, :status, :timetracking],
              max_results: 5000,
              start_index:0
            )
            issues.each do |issue|
              issue_fields = issue.attrs['fields']
              if issue_fields['status']['statusCategory']['key'] != 'done'
                total_remaing_time_hash[:total_remaing_time] += issue_fields['timetracking']['remainingEstimateSeconds']
              end
            end
            total_remaing_time_in_sprint[:total_remaing_times] << total_remaing_time_hash
          end
        end
        total_remaing_time_in_sprint
      end
    response_success(self.class.name, self.action_name, @total_remaing_time_in_sprint)
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
