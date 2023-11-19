import requests
import pandas as pd
import numpy as np
from bs4 import BeautifulSoup
import re
from tqdm import tqdm
from threading import Thread
import sqlite3
from model import Word

def _get_n5(count=None):
    x = requests.get("https://nihongoichiban.com/2011/04/30/complete-list-of-vocabulary-for-the-jlpt-n5")
    tables = pd.read_html(x.text)
    tables[0].replace(to_replace=pd.NA, value="NONE", inplace=True)
    kanjis = []
    i = 0
    for table in tables:
        for kanji in zip(table[0], table[1], table[3]):
            if kanji[0] == "Kanji":
                continue
            if kanji[0] == "NONE":
                word = kanji[1]
            else:
                word = kanji[0]
            k = Word(word, "n5", kanji[1], kanji[2], None, None)
            kanjis.append(k)
            i += 1
            if count != None and i == count:
                return kanjis
    return kanjis

def _kanji_extend(kanji):
    x = requests.get("https://jisho.org/search/" + kanji.word)
    soup = BeautifulSoup(x.text, features="html.parser")
    divs = soup.find_all("div", {"class": "exact_block"})
    if len(divs) == 0:
        return ""
    divs = str(divs[0])
    reg_str = f'<span class="meaning-meaning">(.*?)</span>'
    data = re.findall(reg_str, divs)
    reg_str = f'<div class="meaning-tags">(.*?)</div>'
    tags = re.findall(reg_str, divs)
    typ = None
    if len(tags) != 0:
        word_types = ["verb", "adjective", "noun", "particle"]
        for t in word_types:
            for tag in tags:
                if t in tag.lower():
                    typ = t
                    break
    else:
        typ = "undefined"
    translation = []
    for d in data:
        if d.startswith('<span class="break-unit">'):
            continue
        else:
            translation.append(d)
    extend = ""
    for item in translation:
        extend += item
    defs = 0
    i = 0
    for ch in extend:
        if ch == ';':
            defs += 1
        if defs == 5:
            break
        i += 1
    kanji.extend = extend[:i]
    kanji.typ = typ

def _kanji_list_extend(kanji_list, start_idx, end_idx):
    for i in tqdm(range(start_idx, end_idx)):
        kanji = kanji_list[i]
        try:
            _kanji_extend(kanji)
        except TypeError:
            kanji.word = kanji.reading

def _run(threads_count, kanji_list):
    l = int((len(kanji_list)) / threads_count)
    tasks = []
    start = 0
    end = l
    for i in range(threads_count):
        tasks.append(Thread(target=_kanji_list_extend, args=(kanji_list, start, end)))
        start += l
        end += l
        if i == threads_count - 2 and end != len(kanji_list) - 1:
            end = len(kanji_list)

    for t in tasks:
        t.start()
    for t in tasks:
        t.join()

def _insert_into_db(db, kanji_list):
    tmp = None
    try:
        conn = sqlite3.connect(db)
        query = """
            INSERT INTO kanji (word, reading, translation, difficulty, type, extend)
            VALUES (?, ?, ?, ?, ?);
        """
        cur = conn.cursor()
        for item in kanji_list:
            tmp = item
            cur.execute(query, (item.word, item.reading, item.translation, item.difficulty, item.typ, item.extend))
            conn.commit()
        conn.close()
    except sqlite3.IntegrityError as e:
        print(e)
        print(tmp)

def _generate_insert_sql(file, kanji_list):
    query = \
        "CREATE TABLE IF NOT EXISTS word (\n"\
        "\tid INTEGER PRIMARY KEY AUTOINCREMENT,\n"\
        "\tword TEXT,\n" \
        "\treading TEXT,\n" \
        "\ttranslation TEXT,\n" \
        "\ttype TEXT,\n" \
        "\textend TEXT\n" \
        ");\n"
    queries = [query]
    for item in kanji_list:
        if item.extend != None:
            for i in range(len(item.extend) - 2):
                if item.extend[i] == '\'':
                    item.extend = item.extend[:i - 1] + "\'\'" + item.extend[i + 1:]
        query = f"INSERT INTO word (word, reading, translation, type, extend)\n" \
            f"VALUES ('{item.word}', '{item.reading}', '{item.translation}', '{item.typ}', '{item.extend}');"
        queries.append(query)
    with open(file, "w") as f:
        for line in queries:
            f.write(f"{line}\n")

def _gen_words():
    word_list = _get_n5()
    _run(20, word_list)
    # insert_into_db("n5.sqlite3", kanji_list)
    # TODO: get file path and name from config
    _generate_insert_sql("./sql/init_n5.sql", word_list)

def _gen_kanji():
    print(f" {_gen_kanji} NOT IMPLEMENTED")

def gen_n5():
    _gen_words()
    _gen_kanji()
