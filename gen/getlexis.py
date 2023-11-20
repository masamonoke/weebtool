import sys
import csv
from threading import Thread
from tqdm import tqdm
import os

from model import Kanji, KATAKANA, HIRAGANA, Word
from utils import get_word_type, sql_escape
from n5 import gen_n5

class Executor:
    def __init__(self, difficulty):
        self.difficulty = difficulty
        self.sql_file = f"./sql/init_{self.difficulty}.sql"
        self.kanji_dataset = f"./data/{self.difficulty}_kanji.csv"
        self.word_dataset = f"./data/{self.difficulty}_word.csv"
        self.kanjis = []
        self.words = []

    def _get_kanjis(self):
        with open(self.kanji_dataset, newline="") as f:
            reader = csv.reader(f, delimiter=",")
            for row in reader:
                i = 0
                onyomi = None
                kunyomi = None
                for ch in row[1]:
                    if ch in HIRAGANA:
                        onyomi = row[1][:i]
                        kunyomi = row[1][i:]
                        break
                    i += 1
                if onyomi == None:
                    self.kanjis.append(Kanji(row[0], row[1], "", row[2], None, self.difficulty))
                else:
                    self.kanjis.append(Kanji(row[0], onyomi, kunyomi, row[2], None, self.difficulty))


    def _gen_sql(self):
        queries = []
        query = \
            "CREATE TABLE IF NOT EXISTS kanji (\n"\
            "\tid INTEGER PRIMARY KEY AUTOINCREMENT,\n"\
            "\tsymbol TEXT UNIQUE,\n" \
            "\tonyomi TEXT,\n" \
            "\tkunyomi TEXT,\n" \
            "\ttranslation TEXT,\n" \
            "\tdifficulty TEXT\n" \
            ");\n"
        queries.append(query)
        query = \
            "CREATE TABLE IF NOT EXISTS word (\n"\
            "\tid INTEGER PRIMARY KEY AUTOINCREMENT,\n"\
            "\tword TEXT UNIQUE,\n" \
            "\treading TEXT,\n" \
            "\ttranslation TEXT,\n" \
            "\tdifficulty TEXT,\n" \
            "\ttype TEXT,\n" \
            "\textend TEXT\n" \
            ");\n"
        queries.append(query)
        query = \
            "CREATE TABLE IF NOT EXISTS user_vocabulary (\n"\
            "\tid INTEGER PRIMARY KEY AUTOINCREMENT,\n"\
            "\tvalue TEXT NOT NULL UNIQUE,\n" \
            "\toccurence INTEGER NOT NULL,\n" \
            "\tlast_update TEXT NOT NULL,\n" \
            "\trepeated INTEGER NOT NULL,\n" \
            "\tislearnt BOOLEAN NOT NULL\n" \
            ");\n"
        queries.append(query)
        for k in self.kanjis:
            k.translation = sql_escape(k.translation)
            query = f"INSERT INTO kanji (symbol, onyomi, kunyomi, translation, difficulty)\n" \
                f"VALUES ('{k.symbol}', '{k.onyomi}', '{k.kunyomi}', '{k.translation}', '{k.difficulty}');"
            queries.append(query)

        for w in self.words:
            for i in range(len(w.translation) - 2):
                if w.translation[i] == '\'':
                    w.translation = w.translation[:i - 1] + "\'\'" + w.translation[i + 1:]
            query = f"INSERT INTO word (word, reading, translation, difficulty, type, extend)\n" \
                f"VALUES ('{w.word}', '{w.reading}', '{w.translation}', '{w.difficulty}', '{w.typ}', '{w.extend}');"
            queries.append(query)
        os.makedirs(os.path.dirname(self.sql_file), exist_ok=True)
        with open(self.sql_file, "w") as f:
            for line in queries:
                f.write(f"{line}\n")

    def _get_words(self):
        with open(self.word_dataset, newline="") as f:
            reader = csv.reader(f, delimiter=",")
            for row in reader:
                self.words.append(Word(row[0], self.difficulty, row[1], row[2], None, None))

    def _get_word_types(self, start, end):
        for i in tqdm(range(start, end)):
            self.words[i].typ = get_word_type(self.words[i].word)

    def _populate_types(self, threads=20):
        l = int((len(self.words)) / threads)
        tasks = []
        start = 0
        end = l
        for i in range(threads):
            tasks.append(Thread(target=self._get_word_types, args=(start, end)))
            start += l
            end += l
            if i == threads - 2 and end != len(self.words) - 1:
                end = len(self.words)

        for t in tasks:
            t.start()
        for t in tasks:
            t.join()

    def gen(self, skip_types=True):
        self._get_kanjis()
        self._get_words()
        if not skip_types:
            print(f"populating words types for {self.difficulty}")
            self._populate_types()
        self._gen_sql()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python getlexis.py <[n5, n4]>")
    n = sys.argv[1]
    if n == "n5":
        gen_n5()
    else:
        e = Executor(n)
        e.gen(skip_types=False)
