require "yaml"
require "sqlite3"
require "date"
require "optparse"
require "./db.rb"

def update(conn, value)
  res = conn.execute "SELECT * FROM user_vocabulary WHERE value = '#{value}'"
  kanjis_resultset = conn.execute "SELECT symbol FROM kanji"
  id = res[0][0]
  toupdate_kanji = res[0][1].to_s
  occurence = res[0][2].to_i
  kanjis_resultset.each {
    |s|
    k = s[0][1].to_s
    if toupdate_kanji.include?(k)
      occurence += 1
      conn.execute "UPDATE user_vocabulary SET occurence = %s, last_update = %s WHERE id = %d" % [occurence, Time.now.to_i, id]
      break
    end
  }
end

def add(conn, value)
  begin
    conn.execute "INSERT INTO user_vocabulary (value, occurence, last_update, repeated, islearnt)" \
      "VALUES ('%s', '%s', '%s', '%s', '%s');" % [value, 1, Time.now.to_i, 0, false]
    puts "added new entry #{value}"
  rescue SQLite3::ConstraintException => e
    puts "Entry #{value} is not new, updating occurences"
    update(conn, value)
  rescue SQLite3::Exception => e
    puts "execption: #{e}"
  end
end

def from_file(file, conn)
  File.open(file, "r") do |f|
    f.each_line do |line|
      value = line[0..-2]
      add(conn, value)
    end
  end
end


if __FILE__ == $0
  if ARGV.length < 1
    puts "usage: ruby add.rb <value>"
    return
  end
  db = YAML.load_file("config.yml")["db"]
  conn = connect(db)
  options = {}
  OptionParser.new do |opts|
    opts.on("-f", "--file", "Read entries from file") do |f|
      options[:file] = ARGV[0]
    end
  end.parse!
  if options[:file]
    from_file(options[:file], conn)
  else
    add(conn, ARGV[0])
  end
  conn.close()
end
