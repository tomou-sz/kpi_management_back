class ReportsController < ApplicationController
  include JiraInitializer

  def save_sprint_time_tracking
    sprint_id = params[:sprint_id]
    return response_bad_request if sprint_id.blank?

    users = User.all
    sprint_time_trackings = { sprint_id: sprint_id, time_trackings: [] }
    created_at = Time.zone.now
    ActiveRecord::Base.transaction do
      users.each do |user|
        time_spent = 0
        remaining_time = 0
        jira_id = user.jira_id
        if jira_id.blank?
          logger.warn "This user doesn't have jira_id. user_id: #{user_id}"
          next
        end
        logger.info "---User: #{jira_id} Sprint Time Tracking---"
        issues = @client.Issue.jql(
          "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
          fields: [:key, :status, :timetracking],
          max_results: 5000,
          start_index:0
        )
        issues.each do |issue|
          issue_fields = issue.attrs['fields']
          issue_time_spent = issue_fields['timetracking']['timeSpentSeconds'].to_i
          logger.info "Issue: #{issue.attrs['key']}, Time Spent: #{issue_time_spent}"
          time_spent += issue_time_spent
          if issue_fields['status']['statusCategory']['key'] != 'done'
            issue_remaining_time = issue_fields['timetracking']['remainingEstimateSeconds'].to_i
            logger.info "Issue: #{issue.attrs['key']}, Remaining Time: #{issue_remaining_time}"
            remaining_time += issue_remaining_time
          end
        end
        user_id = user.id
        SprintTimeTracking.create!(user_id: user_id, jira_id: jira_id, sprint_id: sprint_id, time_spent: time_spent, remaining_time: remaining_time, created_at: created_at)
        sprint_time_trackings[:time_trackings] << { user_id: user_id, jira_id: jira_id, time_spent: time_spent, remaining_time: remaining_time }
      end
    end
    response_success(self.class.name, self.action_name, sprint_time_trackings)
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  def save_sprint_remaining_story_point
    sprint_id = params[:sprint_id]
    return response_bad_request if sprint_id.blank?

    users = User.all
    sprint_remaining_story_points = { sprint_id: sprint_id, remaining_story_points: [] }
    created_at = Time.zone.now
    ActiveRecord::Base.transaction do
      users.each do |user|
        remaining_story_point = 0
        jira_id = user.jira_id
        if jira_id.blank?
          logger.warn "This user doesn't have jira_id. user_id: #{user_id}"
          next
        end
        logger.info "---User: #{jira_id} Sprint Remaining Story Point---"
        issues = @client.Issue.jql(
          "Sprint = #{sprint_id} AND assignee in (#{jira_id})",
          fields: [:key, :status, :customfield_10106],
          max_results: 5000,
          start_index:0
        )
        issues.each do |issue|
          issue_fields = issue.attrs['fields']
          if issue_fields['status']['statusCategory']['key'] != 'done'
            issue_remaining_story_point = issue_fields['customfield_10106'].to_i
            logger.info "Issue: #{issue.attrs['key']}, Remaining Story Point: #{issue_remaining_story_point}"
            remaining_story_point += issue_remaining_story_point
          end
        end
        user_id = user.id
        SprintRemainingStoryPoint.create!(user_id: user_id, jira_id: jira_id, sprint_id: sprint_id, story_point: remaining_story_point, created_at: created_at)
        sprint_remaining_story_points[:remaining_story_points] << { user_id: user_id, jira_id: jira_id, story_point: remaining_story_point }
      end
    end
    response_success(self.class.name, self.action_name, sprint_remaining_story_points)
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  def total_sprint_time_tracking
    user_ids = params[:user_ids].split(',').map(&:to_i)
    sprint_id = params[:sprint_id]
    @total_sprint_time_tracking =
      Rails.cache.fetch("total_sprint_time_tracking_user_ids_#{user_ids.join('-')}_sprint_id_#{sprint_id}") do
        return response_bad_request if sprint_id.blank?

        users = User.where(id: user_ids)
        not_found_user_ids = user_ids - users.ids
        logger.warn "These user cannot be found. user_ids: #{not_found_user_ids}" if not_found_user_ids.present?

        total_sprint_time_tracking = { sprint_id: sprint_id, total_time_trackings: [] }
        sprint_time_trackings = SprintTimeTracking.where(sprint_id: sprint_id, user_id: users.ids).group_by(&:created_at)
        sprint_time_trackings.keys.each do |created_at|
          hash = { date: created_at, time_trackings: [] }
          sprint_time_trackings[created_at].each do |sprint_time_tracking|
            hash[:time_trackings] << {
              jira_id: sprint_time_tracking.jira_id,
              time_spent: sprint_time_tracking.time_spent,
              remaining_time: sprint_time_tracking.remaining_time
            }
          end
          total_sprint_time_tracking[:total_time_trackings] << hash
        end
        total_sprint_time_tracking
      end
    response_success(self.class.name, self.action_name, @total_sprint_time_tracking)
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end

  def total_sprint_remaining_story_point
    user_ids = params[:user_ids].split(',').map(&:to_i)
    sprint_id = params[:sprint_id]
    @total_sprint_remaining_story_point =
      Rails.cache.fetch("total_sprint_remaining_story_point_user_ids_#{user_ids.join('-')}_sprint_id_#{sprint_id}") do
        return response_bad_request if sprint_id.blank?

        users = User.where(id: user_ids)
        not_found_user_ids = user_ids - users.ids
        logger.warn "These user cannot be found. user_ids: #{not_found_user_ids}" if not_found_user_ids.present?

        total_sprint_remaining_story_point = { sprint_id: sprint_id, total_remaining_story_points: [] }
        sprint_remaining_story_points = SprintRemainingStoryPoint.where(sprint_id: sprint_id, user_id: users.ids).group_by(&:created_at)
        sprint_remaining_story_points.keys.each do |created_at|
          hash = { date: created_at, remaining_story_points: [] }
          sprint_remaining_story_points[created_at].each do |sprint_remaining_story_point|
            hash[:remaining_story_points] << {
              jira_id: sprint_remaining_story_point.jira_id,
              story_point: sprint_remaining_story_point.story_point
            }
          end
          total_sprint_remaining_story_point[:total_remaining_story_points] << hash
        end
        total_sprint_remaining_story_point
      end
    response_success(self.class.name, self.action_name, @total_sprint_remaining_story_point)
  rescue => e
    logger.error "#{Rails.backtrace_cleaner.clean(e.backtrace).first}\n#{e.inspect}"
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
