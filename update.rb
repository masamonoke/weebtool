require "yaml"
require "sqlite3"

def connect(db)
  return SQLite3::Database.open db
end

def update(conn, value)
  res = conn.execute "SELECT * FROM user_vocabulary"
  kanjis_resultset = conn.execute "SELECT symbol FROM kanji"
  id = res[0][0]
  toupdate_kanji = res[0][1].to_s
  occurence = res[0][2].to_i
  kanjis_resultset.each {
    |s|
    k = s[0][1].to_s
    if toupdate_kanji.include?(k)
      occurence += 1
      conn.execute "UPDATE user_vocabulary SET occurence = %s WHERE id = %d" % [occurence, id]
      break
    end
  }
end

def add(conn, value)
  begin
    conn.execute "INSERT INTO user_vocabulary (value, occurence) VALUES ('%s', '%s');" % [value, 0]
    puts "added new entry #{value}"
  rescue SQLite3::ConstraintException => e
    puts "Entry is not new, updating occurences"
    update(conn, value)
  rescue SQLite3::Exception => e
    puts e
  ensure
    conn.close if conn
  end
end

if __FILE__ == $0
  if ARGV.length < 1
    puts "usage: ruby add.rb <value>"
    return
  end
  db = YAML.load_file("config.yml")["db"]
  conn = connect(db)
  add(conn, ARGV[0])
end
