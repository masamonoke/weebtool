require "YAML"
require "optparse"
require "logger"

require "./update.rb"
require "./learn.rb"

def update(conf, options)
  db = conf["db"]
  database = Weebtool::Database.new(db)
  uv = Weebtool::UserVocabulary.new(database.conn)
  if options[:update] == "file"
    uv.fromFile(options[:entries])
  else
    uv.add(options[:entries])
  end
end

def learn(conf, logger = nil)
  db = conf["db"]
  outdate_time = conf["outdate_time"]
  words_learn_count = conf["words_learn_count"]
  kanji_learn_count = conf["kanji_learn_count"]
  repeat_to_learn = conf["repeat_to_learn"]
  database = Weebtool::Database.new db
  dto = Weebtool::EntryDTO.new(database.conn, words_learn_count, kanji_learn_count, outdate_time, logger)
  ler = Weebtool::Learner.new(dto.entries, 150, repeat_to_learn)
  trap "SIGINT" do
    puts "\nExiting..."
    exit 130
  end
  begin
    ler.learn()
  rescue SystemExit => e
    puts "You have ended learning session\n\n"
    dto.entries.each {
      |e|
      dto.update_load(e)
    }
  ensure
    database.close
  end
end

def create_options
  options = {}
  OptionParser.new do |opts|
    opts.on("-l", "--learn", "Starts learning procedure") {
      |_|
      options[:learn] = true
    }
    opts.on("-u", "--update VARIANT", "Updates user vocabulary that will being thaught in learn procedure") {
      |var|
      if var == "word" or var == "file"
        options[:update] = var
      else
        options[:update] = nil
      end

    }
    opts.on("-e", "--entries ENT", "Reads words from file") {
      |e|
      options[:entries] = e
    }
    opts.on("-d", "--debug", "Enables debug mode") {
      |e|
      options[:debug] = true
    }
  end.parse!
  return options
end

if __FILE__ == $0
  conf = YAML.load_file("config.yml")
  options = create_options()
  if options.key?(:debug)
    logger = Logger.new($stdout)
    logger.level = Logger::DEBUG
  end
  if options.key?(:learn)
    learn(conf, logger)
  end
  if options.key?(:update) and not options[:update].nil?
    puts "Updating vocabulary with your input..."
    update(conf, options)
  end
end
