#!/usr/bin/env node

/**
 * KSIS HTML Fixture Anonymizer
 *
 * Usage:
 *   node scripts/anonymize-ksis-fixture.js <input.html> <output.html> [--keep-couple=ID]
 *
 * Replaces every person name with a synthetic label while keeping the HTML exactly as KSIS writes it
 * (tables, places, points, "89/5F", round headers, start numbers, ids):
 *   - couples linked to par.php (relative or https://szts.ksis.eu/…) → "Tanečník N - Tanečnica N"
 *   - judges linked to rozhodca.php ("A - Name (City)")              → "A - Rozhodca N (Mesto)"
 *   - the couple page title (par.php)                                  → "Tanečný Adam - Tanečná Eva"
 * --keep-couple=ID names that couple "Tanečný Adam - Tanečná Eva" too, the couple the tests look for.
 * Clubs are organisations and stay as they are.
 */

import fs from "node:fs";
import path from "node:path";

const OWN = "Tanečný Adam - Tanečná Eva";
const args = process.argv.slice(2);
const files = args.filter((arg) => !arg.startsWith("--"));
const keep = args.find((arg) => arg.startsWith("--keep-couple="))?.split("=")[1]?.trim() ?? null;
if (files.length !== 2) {
  console.log("Usage: node scripts/anonymize-ksis-fixture.js <input.html> <output.html> [--keep-couple=ID]");
  process.exit(1);
}
const [inputFile, outputFile] = files;
let html = fs.readFileSync(inputFile, "utf8");

const couples = new Map();
html = html.replace(
  /(<a\s[^>]*href=['"](?:https?:\/\/szts\.ksis\.eu\/)?par\.php\?id=(\d+)['"][^>]*>)(.*?)(<\/a>)/gis,
  (_match, open, id, _name, close) => {
    if (id === keep) return `${open}${OWN}${close}`;
    if (!couples.has(id)) couples.set(id, `Tanečník ${couples.size + 1} - Tanečnica ${couples.size + 1}`);
    return `${open}${couples.get(id)}${close}`;
  },
);

// Judges carry their name and city in the link too: rozhodca.php?meno=…&mesto=….
const judges = new Map();
html = html.replace(
  /<a\s[^>]*href=['"]((?:https?:\/\/szts\.ksis\.eu\/)?rozhodca\.php)\?meno=([^'"&]*)[^'"]*['"][^>]*>\s*([A-Z])\s*-\s*[^<(]*?(\([^)]*\))?\s*<\/a>/gis,
  (_match, page, name, letter, city) => {
    if (!judges.has(name)) judges.set(name, `Rozhodca ${judges.size + 1}`);
    const label = judges.get(name);
    return `<a href="${page}?meno=${encodeURIComponent(label)}&amp;mesto=Mesto">${letter} - ${label}${city ? " (Mesto)" : ""}</a>`;
  },
);

// The couple page names the couple only in its title.
if (/Výkonnostná trieda/.test(html)) {
  html = html.replace(/(<div class="jumbotron">\s*<div class="container">\s*<h3>)[^<]*(<\/h3>)/i, `$1${OWN}$2`);
}

fs.mkdirSync(path.dirname(outputFile), { recursive: true });
fs.writeFileSync(outputFile, html, "utf8");
console.log(`${path.basename(outputFile)}: ${couples.size} couples, ${judges.size} judges anonymized${keep ? `, couple ${keep} kept as "${OWN}"` : ""}`);
