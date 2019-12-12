FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:jira_id) { |n| "user_#{n}" }
    trait :junior do
      position { 'junior' }
    end
    trait :senior do
      position { 'senior' }
    end
    trait :leader do
      position { 'leader' }
    end
  end
end
