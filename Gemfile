source "https://rubygems.org"
ruby "3.3.5"

gem "rails", "~> 7.2.1"               # Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "sprockets-rails"                 # The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "dartsass-rails"                  # Integrate Dart Sass with the asset pipeline in Rails
gem "sqlite3", ">= 1.4"               # Use sqlite3 as the database for Active Record
gem "puma", ">= 5.0"                  # Use the Puma web server [https://github.com/puma/puma]
gem "importmap-rails"                 # Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "turbo-rails"                     # Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "stimulus-rails"                  # Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "bootsnap", require: false        # Reduces boot times through caching; required in config/boot.rb

group :development, :test do
  gem "debug",                        # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
    platforms: %i[ mri windows ],
    require: "debug/prelude"
  gem "brakeman", require: false      # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "rubocop-rails-omakase",        # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
    require: false
end

group :development do
  gem "web-console"                   # Use console on exceptions pages [https://github.com/rails/web-console]
end
