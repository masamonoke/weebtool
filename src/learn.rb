require "tk"
require "YAML"

require_relative "db.rb"
require_relative "update.rb"
require_relative "kana.rb"
require_relative "jp_dict.rb"
require_relative "log.rb"

module Weebtool

  class Kanji
    attr_reader :symbol, :onyomi, :kunyomi, :translation, :difficulty

    def initialize(symbol, onyomi, kunyomi, translation, difficulty)
      @symbol = symbol
      @onyomi = onyomi
      @kunyomi = kunyomi
      @translation = translation
      @difficulty = difficulty
    end

    def to_s
      return "sym: #{@symbol}, on: #{@onyomi}, kun: #{@kunyomi}, tran: #{@translation}"
    end
  end

  class Entry
    attr_reader :id, :value, :occurence, :repeat_cycle, :grade, :reading, :translation
    attr_accessor :last_update, :repeated, :islearnt, :kanjis

    def initialize(id, value, occurence, last_update, repeated, islearnt, grade, reading, translation, type, outdate_time, repeat_cycle)
      @id = id
      @value = value
      @occurence = occurence
      @last_update = last_update
      @repeated = repeated
      @repeat_cycle = repeat_cycle
      if Time.now.to_i - last_update > outdate_time
        @islearnt = false
        @repeated = 0
        @repeat_cycle += 1
      else
        @islearnt = islearnt
      end
      @grade = grade
      @reading = reading
      @translation = translation
      @type= type
    end

    def self.from_dict_word(word, outdate_time)
      return Entry.new(0, word.word, 0, Time.now.to_i, 0, false, "n1", word.reading, word.translation, "word", outdate_time, 0)
    end

    def metric
      m = 0
      # for kanji with lower grade (n5 is the lowest) metric is the highest
      if @grade == "n5"
        m += 5 * 30
      elsif @grade == "n4"
        m += 4 * 10
      elsif @grade == "n3"
        m += 3 * 3
      elsif @grade == "n2"
        m += 2 * 2
      else
        m += 1
      end
      # then occurence
      m += @occurence
      # then repeat time (0 repeat is greater metric than other values)
      m -= @repeated * 100
      # then time since last update
      m -= @last_update / 1000000
      # then if is learnt
      if @islearnt
        m -= 1000
      end
      return m
    end

    def to_s
      ks = "\n"
      if !@kanjis.nil?
        @kanjis.each { |k| ks += "\t\t#{k.to_s}\n" }
      end
      return "Entry:\n" \
        "\tid=#{self.id},\n" \
        "\tvalue=#{self.value},\n" \
        "\toccurence=#{self.occurence},\n" \
        "\tlast_update=#{self.last_update},\n" \
        "\trepeated=#{self.repeated},\n" \
        "\tislearnt=#{self.islearnt},\n" \
        "\treading=#{self.reading},\n" \
        "\ttranslation=#{self.translation},\n" \
        "\ttype=#{@type},\n" \
        "\tgrade=#{@grade},\n" \
        "\tkanjis=#{ks}\n"
    end
  end

  class Learner
    def initialize(entries, font_size, repeat_to_learn)
      @entries = entries
      @current_entry = entries[0]
      @font_size = font_size
      @repeats = repeat_to_learn
    end

    # blocking
    def learn
      if @entries.empty?
        raise Exception.new "Vocabulary is empty"
      end
      root = TkRoot.new {
        title "weeblang"
        resizable 0, 0
      }
      defaultFont = TkFont.new("size" => @font_size)
      lbl = TkLabel.new(root) do
          text ""
          font defaultFont
          grid("column" => 3, "row" => 0)
      end
      _console(lbl)
      _gui()
    end

    def _gui()
      Tk.mainloop()
      raise SystemExit
    end

    def _console(lbl)
      consol_thread = Thread.new {
        console_routine(@entries) { |e|
          @current_entry = e
          lbl.text(@current_entry.value)
          print lbl.text
        }
      }
    end

    def console_routine(entries)
      entries.each {
        |e|
        yield(e)
        print "\nMark this (#{e.value}) entry as learnt? y/n:\n --> "
        decision = gets
        if decision.start_with?('y')
          puts "You chose yes. Entry will be shown some other time."
          e.islearnt = true
        else
          puts "You chose no. Entry still will be showing"
        end
        puts e
        e.repeated = e.repeated + 1
        e.last_update = Time.now.to_i
        if e.repeated > @repeats
          e.islearnt = true
          puts "Congrats! You learnt entry: #{e.value}"
        end
      }
      p "Good work! Press again in console or close window to exit"
      gets
      raise SystemExit
    end

    private :_gui, :_console
  end


  class EntryDTO
    def initialize(conn, words_learn_count, kanji_learn_count, outdate_time)
      @conn = conn
      @word_count = words_learn_count
      @kanji_count = kanji_learn_count
      @outdate_time = outdate_time
      self.load_entries()
    end

    def entries
      @entry
    end

    def entries=(entries)
      @entry = entries
    end

    def update_load(entry)
      @conn.execute \
        "UPDATE user_vocabulary "\
        "SET repeated = #{entry.repeated}, islearnt = #{entry.islearnt}, last_update = #{entry.last_update}, repeat_cycle = #{entry.repeat_cycle} " \
        "WHERE id = #{entry.id}"
    end

    def load_entries
      word_entries = _load_words(@conn).sort_by { |e| -e.metric } [0..@word_count]
      kanji_entries = _load_kanjis(@conn).sort_by { |e| -e.metric } [0..@kanji_count]
      @entry = word_entries + kanji_entries
    end

    def _load_words(conn)
      entries_raw = conn.execute "
        SELECT * FROM user_vocabulary u
        LEFT JOIN word w ON w.word = u.value"
      entries = []
      kanji_cache = {}
      jd = JapDict.new(conn, $config["jmdict"])
      entries_raw.each {
        |e|
        if e[7].nil?
          # TODO: find entry from dictionary
          word = jd.word(e[1])
          if word.empty?
            next
          end
          entry = Entry.from_dict_word(word, @outdate_time)
        else
          entry = Entry.new(e[0], e[1], e[2], e[3].to_i, e[4], e[5], e[11], e[9], e[10], "word", @outdate_time, e[6])
        end
        kanjis_list = []
        entry.value.each_char {
          |symbol|
          kanji = nil
          if KATAKANA.include?(symbol) or HIRAGANA.include?(symbol)
              next
          end
          if kanji_cache.include?(symbol)
            kanji = kanji_cache[symbol]
          else
            kanji_raw = conn.execute \
              "SELECT symbol, onyomi, kunyomi, translation, difficulty FROM kanji " \
              "WHERE symbol = '#{symbol}'"
            if !kanji_raw.empty?
              kanji = Kanji.new(kanji_raw[0][0], kanji_raw[0][1], kanji_raw[0][2], kanji_raw[0][3], kanji_raw[0][4])
              kanji_cache[symbol] = kanji
            else
              log("Unexpected kanji and is not found in dictionary: #{symbol}. Probably you need update your dictionary\n")
            end
          end
          kanjis_list.append(kanji)
        }
        entry.kanjis = kanjis_list
        entries.append(entry)
      }

      return entries
    end

    def _load_kanjis(conn)
      entries_raw = conn.execute \
        "SELECT * FROM user_vocabulary u " \
        "INNER JOIN kanji k ON k.symbol = u.value"
      entries = []
      entries_raw.each {
        |e|
        entry = Entry.new(e[0], e[1], e[2], e[3].to_i, e[4], e[5], e[12], "on: #{e[9]}; kun: #{e[10]}", e[11], "kanji", @outdate_time, e[6])
        entries.append(entry)
      }
      return entries
    end

    private :_load_words, :_load_kanjis

  end
end
