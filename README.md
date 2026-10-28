<div align="center">
  <img src="images/logo.png" alt="Zoko" width="80" height="80">
  <h1>Zoko</h1>
  <p>Ce qu'il y a dans le frigo, quand ça périme, et quoi cuisiner avec.</p>
</div>

## Fonctionnalités

- **Frigo** : liste triée par urgence (à consommer vite, cette semaine, plus tard), frigo / congélo / placard.
- **Ajout en rafale** : le panneau reste ouvert, les produits déjà achetés reprennent leur durée de conservation
  habituelle, et `yaourts 12/11` ou `poulet +3` règle la date au clavier.
- **Mangé / jeté** d'un glissement, annulable ; historique du mois.
- **Recettes** : depuis un produit (bouton couverts) ou pour tout le frigo (« Que cuisiner ? »), réalisables ou
  presque, triées pour utiliser d'abord ce qui périme. « J'ai cuisiné ça » retire les produits utilisés.
- **Courses** : les ingrédients manquants d'une recette s'ajoutent en un geste ; « Ranger dans le frigo » enchaîne
  les articles achetés dans l'ajout rapide.
- **Foyer** partagé entre plusieurs téléphones avec un code, synchronisé en direct.
- **Rappel** la veille de la péremption (optionnel).
- **Mise à jour automatique** sur Android depuis les releases GitHub.

## Stack

Flutter 3.47 · Dart 3.13 · Riverpod 3 · go_router · Material 3 · Supabase (Postgres, RLS, temps réel, connexion
anonyme).

```
lib/
  core/          configuration, thème, routes, outils texte et dates
  features/
    pantry/      produits : données, domaine (dates, saisie rapide), écrans
    recipes/     catalogue, matching produits ↔ ingrédients, écrans
    shopping/    liste de courses
    household/   foyer (création, code, adhésion)
    reminders/   notifications locales
    updater/     mise à jour Android via GitHub Releases
    settings/
supabase/
  migrations/    schéma versionné
  data/          ingrédients et recettes (source du catalogue)
  seed.sql       généré par tool/build_seed.py
```

## Sécurité

L'app ne contient que l'URL du projet et sa clé *publishable*, publiques par conception. Chaque téléphone ouvre une
session anonyme Supabase ; les données d'un foyer ne sont lisibles que par ses membres (Row Level Security). On
rejoint un foyer avec son code (12 caractères, ~60 bits, 10 essais ratés maximum par heure), qu'un membre peut
régénérer à tout moment.

## Développer

```sh
cp env.example.json env.json   # URL + clé publishable du projet Supabase
flutter pub get
flutter run --dart-define-from-file=env.json
flutter test
```

Base de données : appliquer `supabase/migrations/*.sql` dans l'ordre, puis `supabase/seed.sql`. Après une
modification de `supabase/data/`, régénérer le catalogue avec `python3 tool/build_seed.py`.

## Publier une version

1. Monter `version:` dans `pubspec.yaml`.
2. `git tag v2.0.1 && git push --tags`.

Le workflow `Release` construit l'APK signé et le publie avec son empreinte SHA-256 ; les téléphones proposent la
mise à jour au lancement suivant. Secrets requis dans le repo : `SUPABASE_URL`, `SUPABASE_KEY`,
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`.

La clé de signature ne doit jamais changer : sans elle, Android refuse d'installer la mise à jour.

## Crédits

Photos des recettes : Wikimedia Commons, auteur et licence affichés sous chaque recette.

## Licence

MIT
