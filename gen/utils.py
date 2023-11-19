import requests
from bs4 import BeautifulSoup
import re

def get_word_type(word):
    x = requests.get("https://jisho.org/search/" + word)
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
    return typ

def sql_escape(string):
    for i in range(len(string) - 2):
        if string[i] == '\'':
            string = string[:i - 1] + "\'\'" + string[i + 1:]
    return string
