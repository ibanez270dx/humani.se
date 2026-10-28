source "https://rubygems.org"
ruby "4.0.7"

gem "rails", "~> 8.1"                 # Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "sprockets-rails"                 # The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "dartsass-rails"                  # Integrate Dart Sass with the asset pipeline in Rails
gem "puma", ">= 5.0"                  # Use the Puma web server [https://github.com/puma/puma]
gem "bootsnap", require: false        # Reduces boot times through caching; required in config/boot.rb

group :development, :test do
  gem "debug",                        # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
    platforms: %i[ mri windows ],
    require: "debug/prelude"
  gem "brakeman", require: false      # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "bundler-audit", require: false # Check locked gems against Ruby security advisories
  gem "rubocop-rails-omakase",        # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
    require: false
end

group :development do
  gem "web-console"                   # Use console on exceptions pages [https://github.com/rails/web-console]
end

gem "pg", "~> 1.7"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 2.0"
gem "pdf-reader", "~> 2.16"
