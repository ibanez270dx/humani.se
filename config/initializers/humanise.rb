# See Heroku Dyno Metadata | https://devcenter.heroku.com/articles/dyno-metadata

module Humanise

  %i[app_id app_name release_version released_created_at build_commit build_description].each do |metadata|
    define_singleton_method(metadata) do
      return "test" if Rails.env.test?
      ENV["HEROKU_#{metadata.upcase}"]
    end
  end

end
