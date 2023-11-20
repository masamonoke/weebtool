require "tk"
require "sqlite3"
require "YAML"

require "./db.rb"

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
  def initialize(id, value, occurence, last_update, repeated, islearnt, grade, reading, translation)
    @id = id
    @value = value
    @occurence = occurence
    @last_update = last_update
    @repeated = repeated
    @islearnt = islearnt
    @grade = grade
    @reading = reading
    @translation = translation
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

  def repeated
    @repeated
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
    m -= @repeated
    # then time since last update
    m += @last_update / 10000
    # then if is learnt
    if @islearnt
      m -= 1000
    end
  end

  def to_s
    ks = "\n"
    @kanjis.each { |k| ks += "\t\t#{k.to_s}\n" }
    return "Entry:\n" \
      "\tid=#{self.id},\n" \
      "\tvalue=#{self.value},\n" \
      "\toccurence=#{self.occurence},\n" \
      "\tlast_update=#{self.last_update},\n" \
      "\trepeated=#{self.repeated},\n" \
      "\tislearnt=#{self.islearnt},\n" \
      "\treading=#{self.reading},\n" \
      "\ttranslation=#{self.translation},\n" \
      "\tkanjis=#{ks}\n"
  end
end

def load_entries(conn)
  entries_raw = conn.execute \
    "SELECT * FROM user_vocabulary u " \
    "INNER JOIN word w ON w.word = u.value"
  entries = []
  kanji_cache = {}
  entries_raw.each {
    |e|
    entry = Entry.new(e[0], e[1], e[2], e[3].to_i, e[4], e[5], e[10], e[8], e[9])
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
          puts "unexpected kanji and is not found in dictionary: #{symbol}"
        end
      end
      kanjis_list.append(kanji)
    }
    entry.kanjis = kanjis_list
    entries.append(entry)
  }

  return entries
end

class Learner
  def initialize(entries)
    @entries = entries
    @current_entry = entries[0]
  end

  def learn
    root = TkRoot.new {
      title "weeblang"
      resizable 0, 0
    }
    defaultFont = TkFont.new("size" => 100)
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
  }
end

if __FILE__ == $0
  db = YAML.load_file("config.yml")["db"]
  conn = connect(db)
  entries = load_entries(conn).sort_by {|e| -e.metric } [0..10]
  ler = Learner.new(entries)
  ler.learn()
end
