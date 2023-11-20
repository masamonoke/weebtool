from getlexis import Executor, gen_n5
import subprocess
import yaml
from threading import Thread

def _task(n):
    e = Executor(n)
    e.gen(skip_types=True)

if __name__ == "__main__":
    with open("config.yml", "r") as f:
        config = yaml.safe_load(f)
        db = config["db"]
    ns = ["n4", "n3", "n2", "n1", "n5"]
    cmd = ""
    tasks = []
    for n in ns:
        t = Thread(target=_task, args=(n,))
        t.start()
        tasks.append(t)
        cmd += f"sqlite3 {db} < sql/init_{n}.sql;"
    for t in tasks:
        t.join()
    p = subprocess.Popen([cmd], shell=True)
    p.wait()
