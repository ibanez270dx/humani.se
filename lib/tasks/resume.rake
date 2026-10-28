namespace :resume do
  desc "Import the initial PDF only if no resume has been published"
  task bootstrap: :environment do
    Resume.bootstrap!
    puts "Resume ready."
  end
end
