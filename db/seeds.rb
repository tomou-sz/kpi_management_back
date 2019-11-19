# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)
users_list = [
  {name: "Tran Thanh An", jira_id: "tran_thanh_an", position: "leader"},
  {name: "tai pham", jira_id: "pham_ba_tai", position: "leader"},
  {name: "Luohao", jira_id: "jakeluong", position: "junior"},
  {name: "Nguyen Thi Anh Tram", jira_id: "nguyen_thi_anh_tram", position: "senior"},
  {name: "Bui Tien Thuan", jira_id: "thuanbui", position: "junior"},
  {name: "Nguyen Ngoc Linh", jira_id: "nguyen_ngoc_linh", position: "leader"},
  {name: "Hoang Thi Tuyet", jira_id: "hoang_thi_tuyet", position: "junior"},
  {name: "Nguyen Tang Hoang Phi", jira_id: "nguyen_tang_hoang_phi", position: "senior"},
]
Rails.logger.info 'Start to init users'
begin
  users_list.each do |user|
    next if User.find_by(jira_id: user["jira_id"])
    user = User.create!(user)
    Rails.logger.info "User is created. #{user.inspect}"
  end
  Rails.logger.info "All users are created."
rescue StandardError => e
  Rails.logger.error "Unexpected error happen. #{e.inspect}"
end
