class SprintsController < ApplicationController
  include JiraInitializer

  def board_sprints
    # TODO: Board id will be replaced with params[:board_id]
    begin
      board_id = ENV['JIRA_MAIN_PROJECT_BOARD_ID']
      board = @client.Board.find(board_id)
      @board_sprints = board.sprints.map do |sprint|
        sprint_attrs = sprint.attrs
        {
          id: sprint_attrs['id'],
          state: sprint_attrs['state'],
          start_date: sprint_attrs['startDate'],
          end_date: sprint_attrs['endDate']
        }
      end
      response_success(self.class.name, self.action_name, @board_sprints)
    end
  rescue => e
    if e.class.name == "JIRA::HTTPError"
      response_bad_request
    else
      response_internal_server_error
    end
  end
end
