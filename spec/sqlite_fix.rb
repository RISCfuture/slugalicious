# Fix bug with Rails SQLite boolean handling

class ActiveRecord::ConnectionAdapters::SQLite3Adapter
  QUOTED_TRUE, QUOTED_FALSE = '1'.freeze, '0'.freeze

  def quoted_true() QUOTED_TRUE end
  def quoted_false() QUOTED_FALSE end
end
