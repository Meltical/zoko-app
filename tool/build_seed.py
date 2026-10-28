"""Valide le catalogue de recettes, récupère les photos Wikimedia et génère supabase/seed.sql.

Usage : python3 -I tool/build_seed.py [--offline]
"""

import html
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "supabase" / "data"
IMAGES_CACHE = DATA / "images.json"
SEED = ROOT / "supabase" / "seed.sql"
USER_AGENT = "zoko-seed/1.0 (https://github.com/Meltical/zoko-app)"
THUMB_WIDTH = 960
TAGS = {"entrée", "plat", "dessert", "soupe", "salade", "végétarien", "rapide", "four", "poêle", "mijoté"}


def fetch_json(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def strip_html(value):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", value or ""))).strip()


def lookup_image(wiki_title):
    slug = urllib.parse.quote(wiki_title.replace(" ", "_"), safe="")
    summary = fetch_json(f"https://fr.wikipedia.org/api/rest_v1/page/summary/{slug}")
    original = (summary.get("originalimage") or {}).get("source")
    thumbnail = (summary.get("thumbnail") or {}).get("source")
    if not original or "/wikipedia/commons/" not in original:
        return None

    width = (summary.get("originalimage") or {}).get("width") or 0
    base = (thumbnail or original).split("?")[0]
    if width > THUMB_WIDTH and "/thumb/" in base:
        url = re.sub(r"/\d+px-([^/]+)$", rf"/{THUMB_WIDTH}px-\1", base)
    else:
        url = original.split("?")[0]

    file_name = urllib.parse.unquote(base.split("/thumb/")[-1].split("/")[2] if "/thumb/" in base else base.rsplit("/", 1)[-1])
    meta = fetch_json(
        "https://commons.wikimedia.org/w/api.php?action=query&format=json&prop=imageinfo"
        f"&iiprop=extmetadata&titles={urllib.parse.quote('File:' + file_name)}"
    )
    page = next(iter(meta["query"]["pages"].values()))
    ext = (page.get("imageinfo") or [{}])[0].get("extmetadata", {})
    artist = strip_html(ext.get("Artist", {}).get("value")) or "Auteur inconnu"
    license_name = strip_html(ext.get("LicenseShortName", {}).get("value")) or "licence libre"
    return {
        "url": url,
        "credit": f"Photo : {artist} — {license_name}, via Wikimedia Commons",
        "source": f"https://commons.wikimedia.org/wiki/File:{urllib.parse.quote(file_name.replace(' ', '_'))}",
    }


def validate(ingredients, recipes):
    keys = {item["key"] for item in ingredients}
    errors = []
    slugs = set()
    for recipe in recipes:
        slug = recipe.get("slug", "?")
        if slug in slugs:
            errors.append(f"{slug}: slug en double")
        slugs.add(slug)
        for field in ("title", "ingredients", "steps", "servings"):
            if not recipe.get(field):
                errors.append(f"{slug}: champ {field} manquant")
        for tag in recipe.get("tags", []):
            if tag not in TAGS:
                errors.append(f"{slug}: tag inconnu {tag!r}")
        for item in recipe.get("ingredients", []):
            for key in [item.get("key"), *item.get("alt", [])]:
                if key not in keys:
                    errors.append(f"{slug}: clé d'ingrédient inconnue {key!r}")
    return errors


def sql_literal(value):
    return "'" + value.replace("'", "''") + "'"


def main():
    offline = "--offline" in sys.argv
    ingredients = json.loads((DATA / "ingredients.json").read_text())
    recipes = []
    for path in sorted((DATA / "recipes").glob("*.json")):
        recipes.extend(json.loads(path.read_text()))

    errors = validate(ingredients, recipes)
    if errors:
        print("\n".join(errors))
        sys.exit(1)

    cache = json.loads(IMAGES_CACHE.read_text()) if IMAGES_CACHE.exists() else {}
    for recipe in recipes:
        wiki = recipe.get("wiki")
        if not wiki or wiki in cache or offline:
            continue
        try:
            cache[wiki] = lookup_image(wiki)
        except Exception as error:
            print(f"photo introuvable pour {wiki!r} : {error}")
            cache[wiki] = None
        time.sleep(0.2)
    IMAGES_CACHE.write_text(json.dumps(cache, ensure_ascii=False, indent=2, sort_keys=True) + "\n")

    rows = []
    for recipe in recipes:
        image = cache.get(recipe.get("wiki") or "") or {}
        rows.append({
            "slug": recipe["slug"],
            "title": recipe["title"],
            "image_url": image.get("url"),
            "image_credit": image.get("credit"),
            "image_source": image.get("source"),
            "prep_minutes": recipe.get("prep_minutes"),
            "cook_minutes": recipe.get("cook_minutes"),
            "servings": recipe["servings"],
            "difficulty": recipe.get("difficulty"),
            "tags": recipe.get("tags", []),
            "ingredients": recipe["ingredients"],
            "steps": recipe["steps"],
        })

    ingredients_json = json.dumps(ingredients, ensure_ascii=False)
    recipes_json = json.dumps(rows, ensure_ascii=False)
    SEED.write_text(f"""-- Généré par tool/build_seed.py — ne pas éditer à la main.

insert into public.ingredients (key, name, aliases, staple)
select key, name, coalesce(aliases, '{{}}'), coalesce(staple, false)
from jsonb_to_recordset({sql_literal(ingredients_json)}::jsonb)
  as t(key text, name text, aliases text[], staple boolean)
on conflict (key) do update
  set name = excluded.name, aliases = excluded.aliases, staple = excluded.staple;

insert into public.recipes (slug, title, image_url, image_credit, image_source, prep_minutes,
  cook_minutes, servings, difficulty, tags, ingredients, steps)
select slug, title, image_url, image_credit, image_source, prep_minutes, cook_minutes, servings,
  difficulty, coalesce(tags, '{{}}'), ingredients, steps
from jsonb_to_recordset({sql_literal(recipes_json)}::jsonb)
  as t(slug text, title text, image_url text, image_credit text, image_source text,
       prep_minutes smallint, cook_minutes smallint, servings smallint, difficulty text,
       tags text[], ingredients jsonb, steps text[])
on conflict (slug) do update
  set title = excluded.title, image_url = excluded.image_url, image_credit = excluded.image_credit,
      image_source = excluded.image_source, prep_minutes = excluded.prep_minutes,
      cook_minutes = excluded.cook_minutes, servings = excluded.servings,
      difficulty = excluded.difficulty, tags = excluded.tags,
      ingredients = excluded.ingredients, steps = excluded.steps;

delete from public.recipes
where slug not in (select slug from jsonb_to_recordset({sql_literal(json.dumps([{"slug": r["slug"]} for r in rows]))}::jsonb) as t(slug text));
""")
    missing = [r["slug"] for r in rows if not r["image_url"]]
    print(f"{len(rows)} recettes, {len(ingredients)} ingrédients, {len(missing)} sans photo : {', '.join(missing)}")


if __name__ == "__main__":
    main()
