namespace :ridgepole do
  desc 'ridgepole apply'
  task apply: :environment do
    puts `bundle exec ridgepole --apply -E #{ ENV['RAILS_ENV'] } -c config/database.yml -f db/Schemafile`
  end
end
