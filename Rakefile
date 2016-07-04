require 'rubygems'
require 'bundler'
begin
  Bundler.require :default, :development
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

Juwelier::Tasks.new do |gem|
  gem.name = "slugalicious"
  gem.summary = %Q{Easy-to-use and powerful slugging for Rails 3}
  gem.description = %Q{Slugalicious adds simple and powerful slugging to your ActiveRecord models.}
  gem.email = "git@timothymorgan.info"
  gem.homepage = "http://github.com/riscfuture/slugalicious"
  gem.authors = [ "Tim Morgan" ]
  gem.required_ruby_version = '>= 1.9'
  gem.files = %w( lib/**/* LICENSE README.md templates/* slugalicious.gemspec )
end
Juwelier::RubygemsDotOrgTasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

# bring sexy back (sexy == tables)
module YARD::Templates::Helpers::HtmlHelper
  def html_markup_markdown(text)
    markup_class(:markdown).new(text, :gh_blockcode, :fenced_code, :autolink, :tables, :no_intra_emphasis).to_html
  end
end

YARD::Rake::YardocTask.new('doc') do |doc|
  doc.options << '-m' << 'markdown' << '-M' << 'redcarpet'
  doc.options << '--protected' << '--no-private'
  doc.options << '-r' << 'README.md'
  doc.options << '-o' << 'doc'
  doc.options << '--title' << 'Slugalicious Documentation'

  doc.files = %w( lib/**/* templates/**/* README.md )
end                                                              

task(default: :spec)
