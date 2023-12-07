#!/usr/bin/env python3

from bs4 import BeautifulSoup
from urllib.parse import urlparse
from pathlib import Path
import requests, sys, subprocess, shutil, os

knock = Path("./result/bin/knock")

if not knock.exists():
    print("error: " + str(knock) + " does not exist", file=sys.stderr)
    sys.exit()

if len(sys.argv) != 2:
    print(
        "error: missing required argument: directory in which to perform the tests",
        file=sys.stderr,
    )
    sys.exit()
workspace = Path(sys.argv[1])

print("Testing " + str(knock))

result = subprocess.run(knock)
if result.returncode != 0:
    print("Test failed: knock failed to describe itself")
    sys.exit()
print("---")

html = requests.get(
    "https://www.adobe.com/solutions/ebook/digital-editions/sample-ebook-library.html"
).text
soup = BeautifulSoup(html, "html.parser")

links = []
for a_tag in soup.find_all("a"):
    if a_tag.string != "Download eBook":
        continue
    if not urlparse(a_tag.get("href")).path.endswith(".acsm"):
        continue

    links.append(a_tag.get("href"))

    if len(links) >= 10:
        break

for time in ["first", "second"]:

    if workspace.exists():
        shutil.rmtree(workspace)
    workspace.mkdir()

    for i, link in enumerate(links):
        i = str(i)

        print("Testing URL #" + i + " for the " + time + " time:\n" + link)
        file = workspace.joinpath(i + ".acsm")

        r = requests.get(link)
        open(file, "wb").write(r.content)

        result = subprocess.run([knock, file])

        if result.returncode != 0:
            print("Test failed: knock failed to convert a file")
            sys.exit()

        print("Success\n---")

print("All tests passed")
