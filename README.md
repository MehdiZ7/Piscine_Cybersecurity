# Piscine Cybersécurité — Day 0 : Arachnida

Projet d'introduction au **web scraping** et aux **métadonnées**.

Ce dépôt contient les deux exercices du Day 0 :

1. **Spider** : parcourir un site, extraire les images et les télécharger,
   avec récursion optionnelle et limite de profondeur ;
2. **Scorpion** : lire et afficher les métadonnées EXIF et les informations
   techniques d'un ou plusieurs fichiers images.

L'objectif de ce README est double : expliquer **ce que font les programmes**
et détailler **comment ils sont construits**, fonction par fonction, pour rendre
le travail lisible et vérifiable.

---

## Sommaire

- [Contexte et état du projet](#contexte-et-état-du-projet)
- [Fonctionnalités](#fonctionnalités)
- [Structure du dépôt](#structure-du-dépôt)
- [Prérequis](#prérequis)
- [Spider — utilisation](#spider--utilisation)
- [Scorpion — utilisation](#scorpion--utilisation)
- [Architecture et flux de données](#architecture-et-flux-de-données)
- [Spider — détail du code](#spider--détail-du-code)
- [Scorpion — détail du code](#scorpion--détail-du-code)
- [Choix techniques et sécurité](#choix-techniques-et-sécurité)
- [Gestion des erreurs](#gestion-des-erreurs)
- [Tests](#tests)
- [Limites connues et améliorations possibles](#limites-connues-et-améliorations-possibles)
- [Bonus du sujet](#bonus-du-sujet)
- [Compétences mises en œuvre](#compétences-mises-en-œuvre)

---

## Contexte et état du projet

Le sujet impose deux programmes, avec une contrainte importante :

- les requêtes HTTP et la manipulation de fichiers sont autorisées ;
- **la logique doit être écrite soi-même** ;
- `wget` et `scrapy` sont **interdits** (note 0).

État actuel :

| Élément | État |
| --- | --- |
| Spider | Terminé et testé |
| Scorpion | Terminé et testé |
| Bonus (modification de métadonnées, interface graphique) | Non implémentés |

Spider utilise uniquement la **bibliothèque standard** de Python.
Scorpion utilise **Pillow** pour ouvrir les images et lire les données EXIF,
mais toute la logique de sélection, de conversion et d'affichage est écrite
dans le projet.

---

## Fonctionnalités

### Spider

- Extraction des images depuis le HTML (`<img src="...">`).
- Téléchargement binaire des images.
- Résolution des URLs relatives (`urljoin`).
- Récursion optionnelle via les liens `<a href="...">`.
- Limite de profondeur configurable (`-l`, défaut 5).
- Dossier de sortie configurable (`-p`, défaut `./data/`).
- Restriction au même site pour les pages.
- Détection et évitement des boucles de navigation.
- Déduplication des pages visitées et des images téléchargées.
- Gestion des URLs non-ASCII (percent-encoding).
- Noms de fichiers sans collision grâce à un hash court.
- Gestion d'erreur par page et par image.
- Extensions : `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`.

### Scorpion

- Accepte un ou plusieurs fichiers en argument.
- Détecte le format réel via Pillow, indépendamment de l'extension.
- Affiche les informations techniques : format, dimensions, mode couleur,
  taille sur disque.
- Affiche les dates du système de fichiers : `Changed`, `Modified`, et
  `Created` quand la plateforme expose `st_birthtime`.
- Lit et affiche les tags EXIF principaux.
- Traduit les identifiants de tags en noms lisibles (`Make`, `Model`,
  `DateTimeOriginal`, etc.).
- Formate les dates EXIF, les nombres rationnels, les bytes, les tuples.
- Traduit l'orientation EXIF en texte (`6 (Rotate 90 CW)`).
- Lit le sous-IFD GPS et affiche :
  - latitude et longitude en degrés décimaux et en DMS ;
  - altitude ;
  - date et heure GPS en UTC.
- Gère les images sans EXIF, sans GPS, les GPS partiels, les fichiers
  corrompus, les fichiers absents et les métadonnées malformées.
- Extensions : `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`.

---

## Structure du dépôt

```text
Piscine_Cybersecurity/
└── days_0/
    ├── spider/
    │   └── spider.py
    └── scorpion/
        ├── scorpion.py
        ├── sample.png
        ├── sample_exif.jpg
        ├── sample_rich.jpg
        ├── sample_gps.jpg
        ├── sample_gps_partial.jpg
        ├── sample.gif
        └── sample.bmp
```

Le sujet PDF (`days_0/en.subject.pdf`) n'est volontairement pas versionné.

Les fichiers `sample*` sont des images de test générées pour vérifier Scorpion :
PNG sans EXIF, JPEG avec EXIF simples, JPEG avec EXIF riches, JPEG avec GPS
complet, JPEG avec GPS partiel, GIF et BMP.

---

## Prérequis

- **Python 3.10 ou supérieur** (types `str | None`, `list[str]`, etc.).
- **Pillow** pour Scorpion :

```bash
python3 -m pip install pillow
```

Spider n'a besoin d'aucune dépendance externe.

Testé avec Python 3.14 et Pillow 12.3.0 sous Linux.

---

## Spider — utilisation

Depuis `days_0/spider/` :

```bash
python3 spider.py URL
python3 spider.py -r -l 3 URL
python3 spider.py -p ./mes_images URL
```

### Options

```text
python3 spider.py [-r] [-l N] [-p PATH] URL
```

| Option | Description | Défaut |
| --- | --- | --- |
| `URL` | page de départ (positionnel, obligatoire) | — |
| `-r` | active le téléchargement récursif | désactivé |
| `-l N` | profondeur maximale de récursion | `5` |
| `-p PATH` | dossier de destination | `./data/` |
| `-h` | affiche l'aide | — |

Notes :

- sans `-r`, seule la page de départ est analysée ; `-l` est alors ignoré ;
- `-l 0` avec `-r` analyse uniquement la page de départ ;
- une profondeur négative est refusée avec un code de sortie `2`.

### Exemple de sortie

```text
200 text/html
[PAGE] http://127.0.0.1:8000/index.html (depth=0)
[OK] http://127.0.0.1:8000/img/a.png -> data/a_97d0efaf.png
[OK] http://127.0.0.1:8000/img/b.JPG?size=big -> data/b_203eccee.JPG
[FAIL] http://127.0.0.1:8000/img/absent.png -> HTTP 404
[PAGE] http://127.0.0.1:8000/gallery.html (depth=1)
[OK] http://127.0.0.1:8000/img/d.bmp -> data/d_958f0ae8.bmp
2 page(s) visited
```

---

## Scorpion — utilisation

Depuis `days_0/scorpion/` :

```bash
python3 scorpion.py FILE1 [FILE2 ...]
```

Exemples :

```bash
python3 scorpion.py sample.png
python3 scorpion.py sample_rich.jpg sample_gps.jpg
python3 scorpion.py sample.png sample_rich.jpg sample_gps_partial.jpg
```

### Exemple de sortie

```text
File      : sample_gps.jpg
Format    : JPEG
Dimensions: 320 x 240
Mode      : RGB
Size      : 2111 bytes
Changed   : 2026-11-10 17:15:46
Modified  : 2026-11-10 17:15:46
tags: 3
Model               : Model X
Make                : GPSCam
GPS data:
Latitude  : 48.856667 (48°51'24.0" N)
Longitude : 2.294444 (2°17'40.0" E)
Altitude  : 35 m
Timestamp : 2024-01-02 14:30:00 UTC
```

---

## Architecture et flux de données

### Spider

```text
main()
 │
 ├─ parse_arg()                 lit URL, -r, -l, -p
 ├─ crée le dossier de sortie
 └─ crawl_page(start, depth, out)
      │
      ├─ fetch(url)              GET HTTP, décodage du HTML
      ├─ extract_images(html)    ImageParser + filtre d'extensions
      │    └─ normalize_url(urljoin(...))
      │    └─ download_image(...)
      │         └─ filename_from_url(...)
      ├─ extract_links(html)     LinkParser
      │    └─ urljoin + normalize_url + urldefrag
      │    └─ same_site + filtre image + visited
      └─ queue.append((link, depth + 1))
```

Le parcours est un **BFS** : les pages sont visitées niveau par niveau grâce à
une file `deque`.

### Scorpion

```text
main()
 │
 └─ pour chaque fichier :
      show_basic_info(path)
        ├─ Image.open(path)
        ├─ Path(path).stat()
        ├─ format, dimensions, mode, taille
        ├─ dates système (Changed, Modified, Created si dispo)
        └─ show_exif(img.getexif())
             ├─ tags EXIF principaux via format_value()
             └─ show_gps(exif)
                  ├─ exif.get_ifd(0x8825)
                  ├─ to_decimal() / format_dms()
                  ├─ altitude
                  └─ timestamp GPS
```

---

## Spider — détail du code

Le fichier est organisé en petites fonctions indépendantes.

### `ImageParser(HTMLParser)`

Classe qui hérite de `HTMLParser` et collecte les URLs d'images.

```python
class ImageParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.images: list[str] = []

    def handle_starttag(self, tag, attrs) -> None:
        if tag != "img":
            return
        attributes = dict(attrs)
        src = attributes.get("src")
        if src:
            self.images.append(src)
```

- `HTMLParser` fournit le moteur d'analyse ; `feed(html)` déclenche les
  callbacks ;
- `handle_starttag` est appelé pour chaque balise ouvrante ;
- `dict(attrs)` transforme la liste de tuples en dictionnaire ;
- `.get("src")` évite un `KeyError` ;
- `if src:` écarte `None` et la chaîne vide.

### `LinkParser(HTMLParser)`

Même principe, mais pour les liens de navigation :

```python
if tag != "a":
    return
href = dict(attrs).get("href")
if href:
    self.links.append(href)
```

On ne suit pas `<link>` (stylesheets, icônes) : ce ne sont pas des pages HTML.

### `normalize_url(url)`

```python
def normalize_url(url: str) -> str:
    return quote(url, safe=":/?#[]@!$&'()*+,;=%")
```

Percent-encode les caractères non-ASCII afin que la requête HTTP reste valide.
Une URL contenant `é` brut provoquerait :

```text
UnicodeEncodeError: 'ascii' codec can't encode character '\xe9'
```

`é` devient `%C3%A9`. Les caractères réservés et les `%` déjà présents sont
préservés, donc la fonction est **idempotente**.

### `is_image_url(url)`

```python
path = urlsplit(url).path.lower()
return path.endswith(VALID_EXTENSIONS)
```

- on isole le chemin : la query string et le fragment sont ignorés ;
- comparaison insensible à la casse ;
- `endswith` reçoit le tuple `VALID_EXTENSIONS`.

### `extract_images(html)` et `extract_links(html)`

Instancient le parseur, appellent `feed` puis `close`, et renvoient le résultat.
`extract_images` applique en plus le filtre `is_image_url`.

### `same_site(base_url, url)`

```python
base = urlsplit(base_url)
target = urlsplit(url)
return (
    target.scheme in ("http", "https")
    and target.netloc.lower() == base.netloc.lower()
)
```

- seuls `http` et `https` sont acceptés ;
- l'hôte et le port doivent être identiques à ceux de la page de départ ;
- comparaison insensible à la casse.

Cette restriction évite de crawler tout le Web. Les **images** peuvent en
revanche être hébergées sur un autre domaine (CDN).

### `crawl_page(start_url, max_depth, out)`

Cœur du programme : parcours BFS avec profondeur maximale.

```python
start_url = normalize_url(urldefrag(start_url)[0])
queue = deque([(start_url, 0)])
visited: set[str] = set()
seen_images: set[str] = set()

while queue:
    url, depth = queue.popleft()
    ...
```

Points clés :

- file FIFO avec `deque` + `popleft()` ;
- profondeur transportée dans chaque entrée `(url, depth)` ;
- `visited` empêche de revisiter une page ;
- `seen_images` mémorise les URLs absolues déjà téléchargées ;
- `urldefrag` retire `#ancre`, inutile côté serveur ;
- erreurs `HTTPError` / `URLError` attrapées page par page ;
- au-delà de `max_depth`, les liens ne sont pas suivis, mais les images de la
  page sont quand même téléchargées.

### `parse_arg()`

Interface `argparse` :

- `url` positionnel obligatoire ;
- `-r` booléen (`store_true`) ;
- `-l` entier avec `type=int`, défaut 5 ;
- `-p` chemin avec défaut `./data/` ;
- validation : `depth >= 0`, sinon `parser.error(...)` et code 2.

### `fetch(url)`

```python
req = Request(url, headers={"User-Agent": "Spider42/1.0"})
with urlopen(req, timeout=10) as resp:
    html = resp.read().decode("utf-8", errors="replace")
```

- `User-Agent` explicite ;
- `timeout=10` pour éviter un blocage ;
- `.read()` renvoie des `bytes`, décodés en UTF-8 ;
- les erreurs réseau/HTTP remontent à l'appelant.

### `filename_from_url(url)`

```python
path = urlsplit(url).path
name = posixpath.basename(path)
if not name:
    return None

digest = hashlib.sha1(url.encode("utf-8")).hexdigest()[:8]
stem, suffix = posixpath.splitext(name)
return f"{stem}_{digest}{suffix}"
```

- `urlsplit(url).path` isole le chemin ;
- `posixpath.basename` retire les dossiers et les `../` ;
- un hash court de l'URL complète évite les collisions ;
- le hash est déterministe : même URL, même nom.

Exemple : `logo.png` peut devenir `logo_8c8dc35b.png`.

### `download_image(url, directory)`

```python
with urlopen(req, timeout=10) as resp:
    img = resp.read()
    target = directory / name
    target.write_bytes(img)
return target
```

- lecture des **octets** sans décodage ;
- écriture binaire avec `write_bytes` ;
- retourne le chemin écrit, ou `None` si aucun nom n'est dérivable.

### `main()`

```python
args = parse_arg()
out = Path(args.path)
out.mkdir(parents=True, exist_ok=True)
max_depth = args.depth if args.recursive else 0
pages = crawl_page(args.url, max_depth, out)
print(f"{len(pages)} page(s) visited")
```

- sans `-r`, `max_depth = 0` : une seule page ;
- avec `-r`, la profondeur vient de `-l` ;
- le dossier est créé avant le crawl.

---

## Scorpion — détail du code

### Constantes

```python
DATE_TAGS = {306, 36867, 36868}
ORIENTATION_LABELS = {1: "Horizontal", ..., 8: "Rotate 270 CW"}
GPS_IFD = 0x8825
```

- `DATE_TAGS` : identifiants des tags de date EXIF ;
- `ORIENTATION_LABELS` : traduction des valeurs d'orientation ;
- `GPS_IFD` : pointeur vers le sous-IFD GPS (`34853`).

### `parse_args()`

`argparse` avec un argument positionnel `files` et `nargs="+"` :

- `scorpion a.jpg` → `["a.jpg"]` ;
- `scorpion a.jpg b.png` → `["a.jpg", "b.png"]` ;
- sans fichier → erreur argparse, code 2.

### `show_basic_info(path)`

Ouvre l'image avec Pillow et affiche :

- le chemin ;
- le format détecté par le contenu ;
- les dimensions ;
- le mode couleur ;
- la taille en octets ;
- `Created` si `st_birthtime` existe ;
- `Changed` (`st_ctime`) ;
- `Modified` (`st_mtime`) ;
- puis appelle `show_exif(img.getexif())`.

Sous Linux, `st_ctime` est un changement d'inode, pas une création : le label
`Changed` est donc plus honnête que `Created`.

### `show_exif(exif)`

- si `exif` est vide → `No EXIF data` ;
- sinon affiche le nombre de tags ;
- parcourt `exif.items()` ;
- ignore le tag `GPSInfo` (`0x8825`), qui n'est qu'un offset ;
- traduit les identifiants avec `TAGS.get(tag_id, tag_id)` ;
- formate les valeurs avec `format_value` ;
- appelle `show_gps(exif)` à la fin.

### `format_value(tag_id, value)`

Gère les types rencontrés dans les EXIF :

| Cas | Traitement |
| --- | --- |
| tag de date + `str` | `2024:01:02 03:04:05` → `2024-01-02 03:04:05` |
| orientation `274` + `int` | `6` → `6 (Rotate 90 CW)` |
| `IFDRational` | entier, fraction `1/120`, ou décimal `2.8` |
| `bytes` | décodage UTF-8 avec remplacement, puis suppression des `\x00` |
| `tuple` / `list` | jointure avec `, ` |
| autre | `str(value)` |

L'ordre des tests est important : les cas spécifiques d'abord, le fallback
`str(value)` en dernier.

### `to_decimal(coord, ref)`

Convertit `(degrés, minutes, secondes)` en degrés décimaux :

```text
d + m/60 + s/3600
```

La valeur est négative si `ref` vaut `S` ou `W`. La fonction vérifie que
`coord` contient bien trois valeurs, sinon elle lève `ValueError`.

### `valid_coord(coord)`

Retourne `True` si `coord` est une séquence de trois valeurs. Utilisé pour
éviter les plantages sur des GPS malformés.

### `format_dms(coord, ref)`

Construit la représentation lisible :

```text
48°51'24.0" N
```

### `show_gps(exif)`

- récupère le sous-IFD avec `exif.get_ifd(GPS_IFD)` ;
- si vide → `No GPS data` ;
- vérifie la présence et la forme des coordonnées ;
- affiche latitude et longitude en décimal et en DMS ;
- affiche l'altitude si elle existe ;
- affiche le timestamp GPS en UTC si la date et l'heure sont valides ;
- ignore proprement les champs absents ou invalides.

### `main()`

Pour chaque fichier :

```python
try:
    show_basic_info(path)
except FileNotFoundError:
    ...
except PermissionError:
    ...
except UnidentifiedImageError:
    ...
except OSError as e:
    ...
except (ValueError, TypeError, OverflowError) as e:
    ...
finally:
    print()
```

Le `finally` garantit une ligne vide entre les fichiers, même en cas d'erreur.

---

## Choix techniques et sécurité

### Bibliothèque standard pour Spider

`urllib` et `html.parser` suffisent à faire des requêtes et à analyser du HTML.
Aucune dépendance externe, `wget` et `scrapy` sont volontairement absents.

### Pillow pour Scorpion

Pillow ouvre les formats de façon fiable et expose les EXIF et le sous-IFD GPS.
La logique de sélection, de conversion et d'affichage reste dans le projet.

### BFS plutôt que DFS

Le BFS visite les pages par niveau de profondeur, ce qui rend `-l` naturel et
prévisible. `deque.popleft()` est en O(1).

### Périmètre limité au même site

`same_site` empêche le spider de suivre des liens externes. C'est une mesure de
sécurité et de bon sens.

### Noms de fichiers sûrs

- `basename` empêche d'écrire hors du dossier de destination via `../` ;
- le hash évite les collisions entre URLs différentes ;
- aucune donnée venue du serveur n'est utilisée comme chemin complet.

### Images et métadonnées non fiables

- les images sont lues en binaire, jamais décodées en texte ;
- les métadonnées EXIF sont traitées comme des données non fiables :
  vérification des coordonnées, des types de dates, des longueurs d'heure ;
- les erreurs de métadonnées sont isolées par fichier.

### URLs normalisées

`normalize_url` garantit que les URLs envoyées à `urllib` sont ASCII. C'est ce
qui permet de traiter des pages contenant des liens accentués sans planter.

### Déduplication

- pages : `visited` ;
- images : `seen_images`.

La déduplication se fait sur l'URL **résolue**, pas sur le `src` brut.

---

## Gestion des erreurs

### Spider

| Situation | Comportement |
| --- | --- |
| Page 404 / 403 / 500 | `[SKIP] ... HTTP <code>`, page ignorée |
| Connexion refusée / DNS / timeout | `[SKIP] ... <raison>`, page ignorée |
| Image 404 | `[FAIL] ... HTTP <code>`, les autres continuent |
| Image réseau indisponible | `[FAIL] ... <raison>` |
| Profondeur négative | message d'argparse, code 2 |
| URL manquante | message d'argparse, code 2 |
| Image sans nom dérivable | ignorée |

### Scorpion

| Situation | Comportement |
| --- | --- |
| Fichier absent | `file not found` |
| Permission refusée | `permission denied` |
| Fichier non-image | `not a valid image` |
| Fichier tronqué / corrompu | message OSError, fichier ignoré |
| Dossier passé en argument | `Is a directory` |
| Aucun EXIF | `No EXIF data` |
| Aucun GPS | `No GPS data` |
| GPS incomplet | `Incomplete GPS data` |
| Coordonnée GPS invalide | `Invalid GPS coordinate` |
| Métadonnée malformée | `invalid metadata (...)`, fichier ignoré |
| Un fichier échoue | les suivants sont quand même traités |

---

## Tests

### Spider — serveur local

Créer un petit site :

```bash
mkdir -p /tmp/spider-lab/img
cd /tmp/spider-lab
```

`index.html` :

```html
<!DOCTYPE html>
<html>
<body>
  <img src="img/a.png">
  <img src="img/b.JPG?size=big">
  <img src="notes.txt">
  <img src="img/absent.png">
  <a href="gallery.html">Galerie</a>
</body>
</html>
```

`gallery.html` :

```html
<!DOCTYPE html>
<html>
<body>
  <img src="img/d.bmp">
  <a href="index.html">Retour</a>
</body>
</html>
```

Créer une image PNG minimale :

```bash
python3 - <<'PY'
import base64, pathlib

png = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
for name in ("a.png", "b.JPG", "d.bmp"):
    pathlib.Path("img", name).write_bytes(png)
PY
```

Lancer le serveur :

```bash
python3 -m http.server 8000 --bind 127.0.0.1
```

Dans un autre terminal :

```bash
cd days_0/spider
python3 spider.py -r -l 1 -p /tmp/spider-out http://127.0.0.1:8000/index.html
```

Résultat attendu :

- `index.html` et `gallery.html` visités ;
- `a.png` et `b.JPG` téléchargées ;
- `notes.txt` ignorée ;
- `absent.png` en échec 404, sans arrêter le programme ;
- `d.bmp` téléchargée depuis `gallery`.

### Spider — URLs accentuées

Une page `café.html` référencée par un lien accentué doit être encodée en
`caf%C3%A9.html` et visitée sans `UnicodeEncodeError`.

### Scorpion — images de test

Les fichiers `sample*` permettent de vérifier les cas principaux :

```bash
cd days_0/scorpion
python3 scorpion.py sample.png sample_exif.jpg
python3 scorpion.py sample_rich.jpg
python3 scorpion.py sample_gps.jpg
python3 scorpion.py sample_gps_partial.jpg
python3 scorpion.py sample.gif sample.bmp
```

Résultats attendus :

- `sample.png`, `sample.gif`, `sample.bmp` : `No EXIF data` ;
- `sample_exif.jpg` : tags `Make`, `Model`, `DateTime`, `DateTimeOriginal` ;
- `sample_rich.jpg` : dates formatées, rationnels (`1/120`, `2.8`, `50`),
  orientation lisible, `No GPS data` ;
- `sample_gps.jpg` : latitude, longitude, altitude, timestamp UTC ;
- `sample_gps_partial.jpg` : latitude/longitude seulement, sans crash.

### Scorpion — erreurs

```bash
python3 scorpion.py missing.jpg
python3 scorpion.py /tmp
python3 scorpion.py notes.txt
```

Chaque cas doit afficher un message lisible, sans traceback, et le programme
continue avec les fichiers suivants.

### Vérifications statiques

```bash
python3 -m py_compile days_0/spider/spider.py
python3 -m py_compile days_0/scorpion/scorpion.py
python3 -m flake8 days_0/spider/spider.py
python3 -m flake8 days_0/scorpion/scorpion.py
```

---

## Limites connues et améliorations possibles

### Spider

- Pas de `robots.txt` ni de limitation de débit.
- Pas de gestion de `<base href>`, `srcset`, `data-src` (lazy loading).
- Les liens vers des ressources non-HTML (`.css`, `.pdf`) seraient visités
  comme des pages.
- Noms de fichiers percent-encodés pour les URLs non-ASCII.
- Code de sortie `0` même si la page de départ échoue.
- Crawl séquentiel, sans parallélisme.

### Scorpion

- Les variantes EXIF exotiques (tags imbriqués, commentaires avec préfixe
  d'encodage) ne sont pas toutes interprétées.
- Le GPS est affiché, mais pas converti en lien de carte.
- Pas de modification ni de suppression de métadonnées (bonus).
- Pas d'interface graphique (bonus).
- `st_ctime` dépend de la plateforme : sous Linux, ce n'est pas la création.
- Les dates sont affichées en heure locale pour le système de fichiers, en UTC
  pour le GPS.

---

## Bonus du sujet

Le bonus n'est pas implémenté. Il pourrait inclure :

- une option Scorpion pour modifier ou supprimer les métadonnées d'un fichier
  (par exemple avec `piexif`) ;
- une interface graphique de visualisation et de gestion des métadonnées.

Le bonus ne doit être évalué que si la partie obligatoire est parfaite.

---

## Compétences mises en œuvre

- Requêtes HTTP avec la bibliothèque standard (`urllib`).
- Analyse de HTML avec `html.parser`.
- Parcours de graphe en largeur (BFS) avec `deque`.
- Gestion de la profondeur et des cycles.
- Résolution d'URLs relatives (`urljoin`, `urldefrag`).
- Percent-encoding et gestion de l'Unicode.
- Téléchargement et écriture de données binaires.
- Sécurité des chemins de fichiers (`basename`, hash anti-collision).
- Lecture d'images et de métadonnées avec Pillow.
- Lecture EXIF, sous-IFD GPS, rationnels, dates.
- Conversion DMS → degrés décimaux.
- Interface CLI avec `argparse`.
- Gestion d'erreurs isolée par page, par image et par fichier.
- Traitement de métadonnées non fiables.
- Tests manuels avec un serveur HTTP local et des images générées.
