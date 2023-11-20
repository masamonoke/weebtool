require "tk"
require "sqlite3"
require "YAML"

require "./db.rb"
require "./update.rb"

HIRAGANA = [
    "あ", "か", "さ", "た", "な", "ま", "や", "ら", "わ",
    "い", "き", "し", "ち", "に", "ひ", "み", "り",
    "う", "く", "す", "つ", "ぬ", "ふ", "む", "ゆ", "る",
    "え", "け", "せ", "て", "ね", "へ", "め", "れ",
    "お", "こ", "そ", "と", "も", "よ", "ろ", "を",
    "ん", "ょ", "ゅ", "っ", "ゃ", "ぅ", "が", "ば", "ぼ", "び", "ぶ", "じ", "づ", "ぢ", "だ"
]

KATAKANA = [
    "イ", "キ", "シ", "チ", "ニ", "ヒ", "ミ", "リ",
    "ウ", "ク", "ス", "ツ", "ヌ", "フ", "ム", "ユ", "ル",
    "エ", "ケ", "セ", "テ", "ヌ", "ヘ", "メ", "レ",
    "オ", "コ", "ソ", "ト", "モ", "ヨ", "ロ",
    "ン", "ュ", "ャ", "ョ", "ッ", "ガ", "バ", "ボ", "ビ", "ブ", "ジ", "ヅ", "ヂ", "ダ"
]

class Kanji
  def initialize(symbol, onyomi, kunyomi, translation, difficulty)
    @symbol = symbol
    @onyomi = onyomi
    @kunyomi = kunyomi
    @translation = translation
    @difficulty = difficulty
  end

  def symbol
    @symbol
  end

  def onyomi
    @onyomi
  end

  def kunyomi
    @kunyomi
  end

  def translation
    @translation
  end

  def difficulty
    @difficulty
  end

  def to_s
    return "sym: #{@symbol}, on: #{@onyomi}, kun: #{@kunyomi}, tran: #{@translation}"
  end
end

class Entry
  def initialize(id, value, occurence, last_update, repeated, islearnt, grade, reading, translation, type)
    @id = id
    @value = value
    @occurence = occurence
    @last_update = last_update
    @repeated = repeated
    @islearnt = islearnt
    @grade = grade
    @reading = reading
    @translation = translation
    @type= type
  end

  def id
    @id
  end

  def value
    @value
  end

  def occurence
    @occurence
  end

  def last_update
    @last_update
  end

  def last_update=(unix_time)
    @last_update = unix_time
  end

  def repeated
    @repeated
  end

  def repeated=(value)
    @repeated = value
  end

  def islearnt
    @islearnt
  end

  def grade
    @grade
  end

  def reading
    @reading
  end

  def translation
    @translation
  end

  def kanjis
    @kanjis
  end

  def kanjis=(kanjis)
    @kanjis = kanjis
  end

  def metric
    m = 0
    # for kanji with lower grade (n5 is the lowest) metric is the highest
    if @grade == "n5"
      m += 5
    elsif @grade == "n4"
      m += 4
    elsif @grade == "n3"
      m += 3
    elsif @grade == "n2"
      m += 2
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
      "\ttype=#{@type}\n"
      "\tkanjis=#{ks}\n"
  end
end

class Learner
  def initialize(entries, font_size)
    @entries = entries
    @current_entry = entries[0]
    @font_size = font_size
  end

  def learn
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
  end

  def _console(lbl)
    consol_thread = Thread.new {
      console(@entries) { |e|
        @current_entry = e
        lbl.text(@current_entry.value)
        print lbl.text
      }
    }
  end

  private :_gui, :_console
end

def gui()
  Tk.mainloop()
end

def console(entries)
  entries.each {
    |e|
    yield(e)
    gets
    puts e
    e.repeated = e.repeated + 1
    e.last_update = Time.now.to_i
  }
end

class EntryDTO
  def initialize(conn)
    @conn = conn
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
      "SET repeated = #{entry.repeated}, islearnt = #{entry.islearnt}, last_update = #{entry.last_update} " \
      "WHERE id = #{entry.id}"
  end

  def load_entries
    word_entries = _load_words(@conn).sort_by {|e| -e.metric } [0..10]
    kanji_entries = _load_kanjis(@conn).sort_by {|e| -e.metric } [0..5]
    @entry = word_entries + kanji_entries
  end

  def _load_words(conn)
    entries_raw = conn.execute \
      "SELECT * FROM user_vocabulary u " \
      "INNER JOIN word w ON w.word = u.value"
    entries = []
    kanji_cache = {}
    entries_raw.each {
      |e|
      entry = Entry.new(e[0], e[1], e[2], e[3].to_i, e[4], e[5], e[10], e[8], e[9], "word")
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
            puts "Unexpected kanji and is not found in dictionary: #{symbol}. Probably you need update your dictionary\n"
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
      entry = Entry.new(e[0], e[1], e[2], e[3].to_i, e[4], e[5], e[11], "on: #{e[8]}; kun: #{e[9]}", e[10], "kanji")
      entries.append(entry)
    }
    return entries
  end

  private :_load_words

end

if __FILE__ == $0
  db = YAML.load_file("config.yml")["db"]
  conn = connect(db)
  dto = EntryDTO.new(conn)
  ler = Learner.new(dto.entries, 150)
  ler.learn()
  dto.entries.each {
    |e|
    dto.update_load(e)
  }
end
