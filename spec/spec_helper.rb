Bundler.require :default, :test
require 'active_support'
require 'active_record'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'slugalicious'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'test.sqlite'
)
require "#{File.dirname __FILE__}/../templates/slug"

class User < ActiveRecord::Base
  include Slugalicious
  slugged :last_name, ->(user) { "#{user.first_name} #{user.last_name}" }
end
class Abuser < ActiveRecord::Base
  include Slugalicious
  slugged :last_name, ->(user) { "#{user.first_name} #{user.last_name}" }
end

require "#{File.dirname __FILE__}/factories"

RSpec.configure do |config|
  config.before(:each) do
    Slug.connection.execute "DROP TABLE IF EXISTS slugs"
    Slug.connection.execute <<-SQL
      CREATE TABLE slugs (
        id INTEGER PRIMARY KEY ASC,
        sluggable_type VARCHAR(126) NOT NULL,
        sluggable_id INTEGER NOT NULL,
        active BOOLEAN NOT NULL DEFAULT 1,
        slug VARCHAR(126) NOT NULL,
        scope VARCHAR(126)
      )
    SQL
    User.connection.execute "DROP TABLE IF EXISTS users"
    User.connection.execute "CREATE TABLE users (id INTEGER PRIMARY KEY ASC, first_name TEXT, last_name TEXT, callsign TEXT, gender VARCHAR(7))"
    Abuser.connection.execute "DROP TABLE IF EXISTS abusers"
    Abuser.connection.execute "CREATE TABLE abusers (id INTEGER PRIMARY KEY ASC, first_name TEXT, last_name TEXT, callsign TEXT, gender VARCHAR(7))"
  end
end
