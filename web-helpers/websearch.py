#!/usr/bin/env python3
# Pantheon web search via the local SearXNG (free, unlimited, no API key).
# Usage: websearch.py <query words...>   -> prints ranked results (title, URL, snippet)
import sys, json, urllib.request, urllib.parse

SEARX = "http://kea-prod-searxng-1:8080/search"

def main():
    q = " ".join(sys.argv[1:]).strip()
    if not q:
        print("usage: websearch.py <query>")
        return 1
    url = SEARX + "?" + urllib.parse.urlencode({"q": q, "format": "json"})
    try:
        with urllib.request.urlopen(url, timeout=15) as r:
            data = json.load(r)
    except Exception as e:
        print(f"SEARCH ERROR: {e}")
        return 1
    results = data.get("results", [])[:8]
    if not results:
        print("No results.")
        return 0
    for i, x in enumerate(results, 1):
        title = (x.get("title") or "").strip()
        link = x.get("url") or ""
        snippet = (x.get("content") or "").strip().replace("\n", " ")
        print(f"{i}. {title}\n   URL: {link}\n   {snippet[:300]}\n")
    return 0

if __name__ == "__main__":
    sys.exit(main())
