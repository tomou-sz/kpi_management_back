class ApplicationController < ActionController::API
  # 200 Success
  def response_success(class_name, action_name, data)
    render status: 200, json: { status: 200, message: "Success #{class_name}##{action_name}", data: data}
  end

  # 400 Bad Request
  def response_bad_request
    render status: 400, json: { status: 400, message: 'Bad Request' }
  end

  # 404 Not Found
  def response_not_found(class_name = 'page')
    render status: 404, json: { status: 404, message: "#{class_name.capitalize} Not Found" }
  end

  # 500 Internal Server Error
  def response_internal_server_error
    render status: 500, json: { status: 500, message: 'Internal Server Error' }
  end
end
