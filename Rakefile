require 'rake'
begin
  require 'bundler'
rescue LoadError
  puts "Bundler is not installed; install with `gem install bundler`."
  exit 1
end

Bundler.require :default, :development

Jeweler::Tasks.new do |gem|
  gem.name = "slugalicious"
  gem.summary = %Q{Easy-to-use and powerful slugging for Rails 3}
  gem.description = %Q{Slugalicious adds simple and powerful slugging to your ActiveRecord models.}
  gem.email = "git@timothymorgan.info"
  gem.homepage = "http://github.com/riscfuture/slugalicious"
  gem.authors = [ "Tim Morgan" ]
  gem.required_ruby_version = '>= 1.9'
  gem.files = [ 'lib/**/*', 'LICENSE', 'README.textile', 'templates/*', 'slugalicious.gemspec' ]
end
Jeweler::GemcutterTasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

YARD::Rake::YardocTask.new('doc') do |doc|
  doc.options << "-m" << "textile"
  doc.options << "--protected"
  doc.options << "-r" << "README.textile"
  doc.options << "-o" << "doc"
  doc.options << "--title" << "Slugalicious Documentation"
  
  doc.files = [ 'lib/**/*', 'README.textile', 'templates/slug.rb' ]
end

task(default: :spec)
