class UsersController < ApplicationController
  include JiraInitializer

  def index
    @users = User.all
    render json: @users
  end

  def sprint_tickets
    @user = User.find(params[:user_id])
    jira_id = @user.jira_id
    sprint_id = params[:sprint_id]
    @sprint_tickets_list = {user_id: @user.id, jira_id: jira_id, sprint_id: sprint_id, sprint_tickets: []}
    issues = @client.Issue.jql(
      "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
      fields:[:key, :summary, :issuetype, :status, :timetracking],
      max_results: 5000,
      start_index:0
    )
    issues.each { |issue| @sprint_tickets_list[:sprint_tickets] << ticket_attributes(issue) }
    render json: @sprint_tickets_list
  end

  private

  def ticket_attributes(issue)
    issue_attr = issue.attrs
    issue_fields = issue_attr["fields"]
    ticket_fields = {}
    ticket_fields[:key] = issue_attr["key"]
    ticket_fields[:summary] = issue_fields["summary"]
    ticket_fields[:issuetype] = issue_fields["issuetype"]["name"]
    ticket_fields[:original_estimate_seconds] = issue_fields["timetracking"]["originalEstimateSeconds"]
    ticket_fields[:remaining_estimate_seconds] = issue_fields["timetracking"]["remainingEstimateSeconds"]
    ticket_fields[:time_spent_seconds] = issue_fields["timetracking"]["timeSpentSeconds"]
    ticket_fields[:status_key] = issue_fields["status"]["statusCategory"]["key"]
    ticket_fields
  end
end
