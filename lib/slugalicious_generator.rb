require 'rails/generators'
require 'rails/generators'
require 'rails/generators/migration'

# @private
class SlugaliciousGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  
  source_root "#{File.dirname __FILE__}/../templates"
  
  def self.next_migration_number(dirname)
    if ActiveRecord::Base.timestamped_migrations then
      Time.now.utc.strftime "%Y%m%d%H%M%S"
    else
      "%.3d" % (current_migration_number(dirname) + 1)
    end
  end
  
  def copy_files
    copy_file 'slug.rb', 'app/models/slug.rb'
    migration_template "create_slugs.rb", "db/migrate/create_slugs.rb"
  end
end
