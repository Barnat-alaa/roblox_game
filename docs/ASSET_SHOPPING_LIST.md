# Creator Store shopping list (graphics pass)

_Created 2026-07-15. Owner decision: the café should LOOK like a café now —
we adopt **curated Roblox Creator Store models** for props/furniture/NPCs,
integrated through an asset pipeline with procedural fallback. This amends
docs/ART_DIRECTION.md (see its 2026-07-15 addendum); every adopted asset gets
a row in docs/ASSET_LICENSES.md before it ships._

## How this works (division of labour)

**You (owner)** shop with the list below. **Claude** integrates: strips all
scripts from bought models (security), rescales them to our grid footprints,
wires them into the Furniture catalog / customer spawner, logs licences, and
keeps a procedural fallback if an asset ever fails to load.

### Where to shop (French Studio UI)

- **In Studio:** ruban **AFFICHAGE → Boîte à outils** → onglet déroulant
  **« Boutique des créateurs »** → catégorie **Modèles** → tape le terme de
  recherche **en anglais** (résultats bien meilleurs qu'en français).
- **Ou sur le web (plus confortable):** <https://create.roblox.com/store/models>
  — même recherche; chaque page de modèle a un bouton **Obtenir** et l'ID
  est dans l'URL: `create.roblox.com/store/asset/123456789/Nom`.

### What to do for each item you like — 2 options

- **Option A (recommandé, zéro manipulation):** clique **Obtenir** (Get) puis
  **colle-moi simplement le lien (ou l'ID) dans le chat**, avec le nom cible
  de la liste (ex. `coffee_machine → https://create.roblox.com/store/asset/…`).
  Je fais tout le reste via MCP (insertion, nettoyage, intégration, licence).
- **Option B (si tu préfères tout faire dans Studio):** insère le modèle
  depuis la Boîte à outils, puis glisse-le dans un dossier **`AssetDropbox`**
  dans Workspace (crée-le: clic droit sur Workspace → Insérer un objet →
  Folder, renomme `AssetDropbox`), renomme le modèle avec le nom cible
  (ex. `coffee_machine`), **enregistre le fichier**, et dis-le-moi.

Tu peux me donner 2–3 candidats pour le même objet — j'insère les deux,
je fais une capture côte à côte et tu choisis.

### Choosing well (10-second checklist per asset)

1. **Style "low poly" / cartoon chunky** — flat colours, formes rondes.
   C'est ce qui s'accorde avec nos clients chibi et la palette chaude.
   Évite le photoréaliste et les gros packs PBR (lourds sur mobile).
2. **Créateur fiable**: beaucoup de 👍 et de favoris; badge vérifié = bonus.
3. **Un seul objet propre** vaut mieux qu'une map entière. Les packs
   (ex. "food pack") sont OK — je découpe.
4. Ignore les scripts qu'ils contiennent — **je supprime TOUS les scripts**
   des modèles achetés, systématiquement (règle de sécurité absolue).
5. Gratuit d'abord. Si un asset payant est vraiment mieux, demande-moi avant.

**Cohérence visuelle:** essaie de prendre un maximum d'objets **du même
créateur / même pack** — c'est le secret d'un rendu propre.

---

## PRIORITÉ 1 — le kit "ça ressemble à un vrai café" (Étape S1)

Remplace nos modèles procéduraux actuels (les IDs `→` sont nos IDs internes).

| # | Cible interne | Objet | Qté | Termes de recherche (EN) | Exigences |
|---|---|---|---|---|---|
| 1 | `coffee_machine` | Machine à espresso | 1 | `espresso machine low poly` · `coffee machine cafe` | ~2×2 tuiles, lisible de loin |
| 2 | `oven` | Four en pierre | 1 | `stone oven low poly` · `brick pizza oven` | Bouche de four visible (le feu, c'est moi) |
| 3 | `prep_station` | Plan de travail cuisine | 1 | `kitchen counter low poly` · `prep table cutting board` | Plateau libre (j'y pose les aliments) |
| 4 | `counter` | Comptoir vitrine | 1 | `bakery display case` · `cafe display counter` | Vitrine où empiler les plats |
| 5 | `table_round` | Table de café | 1–2 | `cafe table low poly` · `round table restaurant` | 1×1 ou 2×2 tuiles |
| 6 | `chair_wood` | Chaise | 1–2 | `cafe chair low poly` · `wooden chair` | Assise dégagée (les clients s'assoient dessus) |
| 7 | *(nouveau)* `register` | Caisse enregistreuse | 1 | `cash register low poly` · `vintage cash register` | Se pose sur le comptoir |
| 8 | props nourriture | Pack de plats (croissant, muffin, gâteau, sandwich, rôti…) | 1 pack | `food pack low poly` · `bakery set low poly` · `pastry pack` | Le plus important pour les comptoirs pleins! ≥8 plats différents |
| 9 | props boissons | Tasses, mugs, théière, verres | 1 pack | `coffee cup low poly` · `mug teapot set` · `drink glass low poly` | Tailles ~réalistes vs tables |
| 10 | clients (rigs) | Pack de personnages PNJ | 8–12 persos | `npc pack low poly` · `rigged character pack` · `blocky npc citizens` | **OBLIGATOIRE: rigged R6 ou R15** (sinon ils ne marchent/s'assoient pas). Variété (âges, styles) |
| 11 | staff | Barista / serveur / nettoyeur | 3 | `barista character` · `waiter npc low poly` · `chef character` | Rigged aussi; tabliers = identité staff (Mia, Noah, Pia) |

## PRIORITÉ 2 — la couche cosy (Étapes S1–S2)

| # | Cible | Objet | Qté | Termes de recherche (EN) |
|---|---|---|---|---|
| 12 | `plant_small` +variantes | Plantes en pot | 3 | `potted plant low poly` · `indoor plant set` |
| 13 | `lamp_floor` +plafond | Lampadaire, suspensions, guirlandes | 3 | `floor lamp low poly` · `pendant lamp` · `string lights` |
| 14 | `rug_round` variantes | Tapis | 2 | `round rug` · `carpet low poly` |
| 15 | *(nouveau)* déco murale | Cadres, ardoise menu murale | 3 | `wall art frames` · `menu chalkboard` |
| 16 | *(nouveau)* `menu_board` | Panneau menu sur pied (pour S3!) | 1 | `chalkboard stand sign` · `cafe menu board` |
| 17 | *(nouveau)* bibliothèque | Étagère à livres | 1 | `bookshelf low poly` |
| 18 | *(nouveau)* cheminée | Cheminée cosy | 1 | `fireplace low poly cartoon` |
| 19 | extérieur | Table + parasol terrasse | 1 set | `outdoor table umbrella` · `bistro set low poly` |
| 20 | extérieur | Jardinière fleurie | 2 | `flower planter box low poly` |

## PRIORITÉ 3 — débloqueurs de nouvelles features (Étapes S3–S4)

| # | Cible | Objet | Qté | Termes de recherche (EN) | Pour |
|---|---|---|---|---|---|
| 21 | *(nouveau)* `drink_bar` | Bar à jus / blender | 1 | `juice bar counter` · `smoothie blender low poly` | Famille de recettes Boissons (S3) |
| 22 | *(nouveau)* `pastry_display` | Présentoir à gâteaux (cloche) | 1 | `cake stand glass dome` · `pastry display` | Famille Pâtisserie (S3) |
| 23 | portes/fenêtres | Styles de portes + fenêtres | 2–3 chacun | `wooden shop door` · `window frame low poly` | Customisation (S4) |
| 24 | *(plus tard)* | Chariot à glaces | 1 | `ice cream cart low poly` | Famille Glaces (post-S5) |

## Ce qu'on n'achète PAS (et pourquoi)

- **Textures sols/murs (images)**: provenance douteuse sur le Store; je les
  **génère** (palettes bois/carrelage/damier originales) — c'est l'étape S4.
- **Icônes UI (images 2D)**: on reste sur notre UI originale (règle
  ART_DIRECTION §UI) — pas de risque de copyright dans l'interface.
- **Sons/musiques hors catalogues partenaires** — règle existante inchangée.
- **Tout asset qui imite Café World/Zynga** (personnages, logos, plats
  reconnaissables) — interdit, même trouvé sur le Store.

## Pipeline technique (ce que Claude construit — étape S1)

```
Config/AssetManifest.luau      -- ex.: coffee_machine = 123456789 (asset ID)
AssetLibraryService (serveur)  -- au boot: InsertService:LoadAsset(id)
                               -- → strip Scripts/LocalScripts/ModuleScripts,
                               --   Sounds non listés, remotes suspects
                               -- → auto-scale au footprint grille de l'objet
                               -- → PrimaryPart + ancrage + cache ServerStorage
BuildService / CustomerService -- consomment le template s'il existe,
                               -- sinon FALLBACK sur le modèle procédural actuel
```

Chaque asset adopté = 1 ligne dans `docs/ASSET_LICENSES.md` (ID, créateur,
licence Creator Store, date) **avant** d'être publié.
