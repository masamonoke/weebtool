require "sqlite3"
require "YAML"

module Weebtool

  class Database
    attr_reader :conn

    def initialize(db)
      @db = db
      connect()
    end

    def connect
      @conn = SQLite3::Database.open @db
    end

    def close
      @conn.close
    end
  end
end
