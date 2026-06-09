#!/usr/bin/env python3
# Pantheon web fetch: download a URL and print readable text (HTML stripped).
# Usage: webfetch.py <url>   -> prints up to ~6000 chars of page text
import sys, re, html, urllib.request

def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print("usage: webfetch.py <url>")
        return 1
    url = sys.argv[1].strip()
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                      "(KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
    }
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=20) as r:
            raw = r.read().decode("utf-8", "ignore")
    except Exception as e:
        print(f"FETCH ERROR: {e} (try a different source from the search results)")
        return 1
    raw = re.sub(r"(?is)<(script|style|head|nav|footer|noscript)[^>]*>.*?</\1>", " ", raw)
    text = re.sub(r"(?is)<[^>]+>", " ", raw)
    text = html.unescape(re.sub(r"\s+", " ", text)).strip()
    print(text[:6000])
    return 0

if __name__ == "__main__":
    sys.exit(main())
