require "sqlite3"
require "date"
require "optparse"

require_relative "db.rb"
require_relative "config.rb"

module Weebtool

  class UserVocabulary
    def initialize(conn)
      @conn = conn
    end

    def _update(value)
      res = @conn.execute "SELECT * FROM user_vocabulary WHERE value = '#{value}'"
      id = res[0][0]
      occurence = res[0][2].to_i
      occurence += 1
      @conn.execute "UPDATE user_vocabulary SET occurence = %s, last_update = %s WHERE id = %d" % [occurence, Time.now.to_i, id]
    end

    def add(value)
      begin
        @conn.execute "INSERT INTO user_vocabulary (value, occurence, last_update, repeated, islearnt, repeat_cycle)" \
          "VALUES ('%s', '%s', '%s', '%s', '%s', '%s');" % [value, 1, Time.now.to_i, 0, false, 0]
        puts "added new entry #{value}"
      rescue SQLite3::ConstraintException => e
        puts "Entry #{value} is not new, updating occurences"
        _update(value)
      rescue SQLite3::Exception => e
        puts "execption: #{e}"
      end
    end

    def fromFile(file)
      File.open(file, "r") do |f|
        f.each_line do |line|
          value = line[0..-2]
          add(value)
        end
      end
    end

    private_methods :_update
  end

end
