class Entry:
    def __init__(self):
        self.last_query_date = None
        self.count = 0
        self.difficulty = None
        self.translation = None

class Word(Entry):
    def __init__(self, word, difficulty, reading, translation, typ, extend):
        super(Word, self).__init__()
        self.word = word
        self.reading = reading
        self.extend = extend
        self.kanjis = []
        self.translation = translation
        self.typ = None
        self.difficulty = difficulty

    def __str__(self):
        return f"""
            Word {{
                word: {self.word},
                "count": {self.count},
                "last_query_date": {self.last_query_date},
                "difficulty": {self.difficulty},
                "reading": {self.reading},
                "translation": {self.translation},
                "type": {self.typ},
                "extend": {self.extend}
            }}
        """

class Kanji(Entry):
    def __init__(self, symbol, onyomi, kunyomi, translation, examples, difficulty):
        super(Kanji, self).__init__()
        self.symbol = symbol
        self.onyomi = onyomi
        self.kunyomi = kunyomi
        self.examples = examples
        self.translation = translation
        self.difficulty = difficulty

    def __str__(self):
        return f"""
            Word {{
                symbol: {self.symbol},
                "count": {self.count},
                "last_query_date": {self.last_query_date},
                "difficulty": {self.difficulty},
                "onyomi": {self.onyomi},
                "kunyomi": {self.kunyomi},
                "translation": {self.translation},
                "examples": {self.examples},
                "type": {self.typ}
            }}
        """

HIRAGANA = [
    "あ", "か", "さ", "た", "な", "ま", "や", "ら", "わ",
    "い", "き", "し", "ち", "に", "ひ", "み", "り",
    "う", "く", "す", "つ", "ぬ", "ふ", "む", "ゆ", "る",
    "え", "け", "せ", "て", "ね", "へ", "め", "れ",
    "お", "こ", "そ", "と", "も", "よ", "ろ", "を",
    "ん"
]

KATAKANA = [
    "イ", "キ", "シ", "チ", "ニ", "ヒ", "ミ", "リ",
    "ウ", "ク", "ス", "ツ", "ヌ", "フ", "ム", "ユ", "ル",
    "エ", "ケ", "セ", "テ", "ヌ", "ヘ", "メ", "レ",
    "オ", "コ", "ソ", "ト", "モ", "ヨ", "ロ",
    "ン", "ュ", "ャ", "ョ", "ッ"
]
