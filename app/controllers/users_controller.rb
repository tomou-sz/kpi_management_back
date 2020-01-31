class UsersController < ApplicationController
  include JiraInitializer

  def index
    @users =
      Rails.cache.fetch('all_users') do
        User.all.to_a
      end
    response_success(self.class.name, self.action_name, @users)
  end

  def sprint_tickets
    user_id = params[:user_id]
    sprint_id = params[:sprint_id]
    @sprint_tickets_list =
      Rails.cache.fetch("sprint_tickets_user_id_#{user_id}_sprint_id_#{sprint_id}") do
        @user = User.find_by(id: params[:user_id])
        return response_not_found(@user.class.name) if @user.blank?

        jira_id = @user.jira_id
        return response_bad_request if jira_id.blank? || sprint_id.blank?

        sprint_tickets_list_hash = {user_id: @user.id, jira_id: jira_id, target_sprint_id: sprint_id, sprint_tickets: []}
        begin
          issues = @client.Issue.jql(
            "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
            fields:[:key, :summary, :issuetype, :status, :timetracking, :customfield_10101],
            max_results: 5000,
            start_index:0
          )
          issues.each { |issue| sprint_tickets_list_hash[:sprint_tickets] << ticket_attributes(issue) }
        end
        sprint_tickets_list_hash
      end
    response_success(self.class.name, self.action_name, @sprint_tickets_list)
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  private

  def ticket_attributes(issue)
    issue_attr = issue.attrs
    issue_fields = issue_attr["fields"]
    ticket_fields = {}
    ticket_fields[:key] = issue_attr["key"]
    ticket_fields[:summary] = issue_fields["summary"]
    ticket_fields[:issuetype] = issue_fields["issuetype"]["name"]
    # customfield_10101 return com.atlassian.greenhopper.service.sprint.Sprint@6e71ace3 \
    # [id=,rapidViewId=,state=,name=,startDate=,endDate=,completeDate=,sequence=,goal=]
    ticket_fields[:sprint_ids] = issue_fields["customfield_10101"].map{ |str| str[/id=/]; $'[/,rapidViewId/]; $` }
    ticket_fields[:original_estimate_seconds] = issue_fields["timetracking"]["originalEstimateSeconds"]
    ticket_fields[:remaining_estimate_seconds] = issue_fields["timetracking"]["remainingEstimateSeconds"]
    ticket_fields[:time_spent_seconds] = issue_fields["timetracking"]["timeSpentSeconds"]
    ticket_fields[:status] = {
      key: issue_fields["status"]["statusCategory"]["key"],
      name: issue_fields["status"]["name"]
    }
    ticket_fields
  end
end
