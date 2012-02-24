require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  gem.name = "slugalicious"
  gem.summary = %Q{Easy-to-use and powerful slugging for Rails 3}
  gem.description = %Q{Slugalicious adds simple and powerful slugging to your ActiveRecord models.}
  gem.email = "git@timothymorgan.info"
  gem.homepage = "http://github.com/riscfuture/slugalicious"
  gem.authors = [ "Tim Morgan" ]
  gem.required_ruby_version = '>= 1.9'
  gem.files = %w( lib/**/* LICENSE README.textile templates/* slugalicious.gemspec )
end
Jeweler::RubygemsDotOrgTasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'yard'
YARD::Rake::YardocTask.new('doc') do |doc|
  doc.options << "-m" << "textile"
  doc.options << "--protected"
  doc.options << "-r" << "README.textile"
  doc.options << "-o" << "doc"
  doc.options << "--title" << "Slugalicious Documentation"
  
  doc.files = [ 'lib/**/*', 'README.textile', 'templates/slug.rb' ]
end

task(:default => :spec)
