module JiraInitializer
  extend ActiveSupport::Concern

  included do
    before_action :jira_authenticate
  end

  private

  def jira_authenticate
    options = {
      :username     => ENV['JIRA_USERNAME'],
      :password     => ENV['JIRA_PASSWORD'],
      :site         => ENV['JIRA_SITE'],
      :context_path => '',
      :auth_type    => :basic
    }
    @client = JIRA::Client.new(options)
  end
end
