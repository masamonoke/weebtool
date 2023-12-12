require "eiwa"

require_relative "config.rb"
require_relative "db.rb"

module Weebtool

  class Word
    attr_reader :word, :reading, :translation
    def initialize(word = nil, reading = nil, translation = nil)
      @word = word unless word.nil?
      @reading = reading unless reading.nil?
      @translation = translation unless translation.nil?
    end

    def empty?
      return (word.nil? or reading.nil? or translation.nil?)
    end
  end

  class JapDict
    def initialize(conn, path)
      @conn = conn
      createTable()
      if _empty?
        puts "Dictionary is empty. Loading from #{path} file. It may take some time"
        saveDict(path)
        puts "Done"
      end
    end

    def createTable
      @conn.execute "
          CREATE TABLE IF NOT EXISTS jap_dict (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            word TEXT,
            reading TEXT,
            translations TEXT
          );
        "
    end

    def _empty?
      vals = @conn.execute "
        SELECT * FROM jap_dict LIMIT 10
      "
      return vals.length == 0
    end

    def saveDict(path)
        Eiwa.parse_file("#{path}", type: :jmdict_e) {
        |entry|
        readings = []
        entry.readings.each {
          |r|
          readings.append r.text
        }
        translations = []
        entry.meanings.each { |m| m.definitions.each { |d| translations.append d.text } }
        word = Word.new(entry.text, readings.join("; "), translations.join("; "))
        tmp = ""
        word.translation.each_char {
          |char|
          tmp += char
          if char == '\''
            tmp += '\''
          end
        }
        query = "INSERT INTO jap_dict (word, reading, translations) VALUES ('#{word.word}', '#{word.reading}', '#{tmp}');"
        begin
          @conn.execute query
        rescue
          p "exeption with query: #{query}"
          break
        end
      }
    end

    def update(path)
      raise NotImplementedError
    end

    def word(value)
      w = @conn.execute "
        SELECT word, reading, translations FROM jap_dict jd
        WHERE jd.word = '#{value}'
      "
      if w.length > 1
        w = w[0]
      end
      return Word.new(w[0], w[1], w[2])
    end

  end

end
