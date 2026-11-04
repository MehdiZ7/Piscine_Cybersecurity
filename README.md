# Piscine Cybersécurité — Day 0 : Arachnida

Projet d'introduction au **web scraping** et aux **métadonnées**.

Ce dépôt contient le premier exercice de la piscine cybersécurité : **Spider**, un
programme capable de parcourir un site, d'en extraire les images et de les
télécharger, avec récursion optionnelle et gestion de la profondeur. Le second
exercice, **Scorpion** (analyse EXIF), est prévu dans `days_0/scorpion/` et n'est
pas encore implémenté.

L'objectif de ce README est double : expliquer **ce que fait le programme** et
détailler **comment il est construit**, fonction par fonction, pour rendre le
travail lisible et vérifiable.

---

## Sommaire

- [Contexte et état du projet](#contexte-et-état-du-projet)
- [Fonctionnalités](#fonctionnalités)
- [Structure du dépôt](#structure-du-dépôt)
- [Prérequis](#prérequis)
- [Utilisation](#utilisation)
- [Architecture et flux de données](#architecture-et-flux-de-données)
- [Détail du code](#détail-du-code)
- [Choix techniques et sécurité](#choix-techniques-et-sécurité)
- [Gestion des erreurs](#gestion-des-erreurs)
- [Tests](#tests)
- [Limites connues et améliorations possibles](#limites-connues-et-améliorations-possibles)
- [Scorpion — prochaine étape](#scorpion--prochaine-étape)

---

## Contexte et état du projet

Le sujet impose deux programmes :

1. **Spider** : extraire et télécharger récursivement les images d'un site ;
2. **Scorpion** : lire et afficher les métadonnées EXIF des images.

Contraintes importantes du sujet :

- les requêtes HTTP et la manipulation de fichiers sont autorisées ;
- **la logique doit être écrite soi-même** ;
- `wget` et `scrapy` sont **interdits** (note 0).

État actuel :

| Élément | État |
| --- | --- |
| Spider | Terminé et testé |
| Scorpion | À venir |

Spider utilise uniquement la **bibliothèque standard** de Python
(`urllib`, `html.parser`, `argparse`, `pathlib`, `hashlib`, etc.), sans aucune
dépendance externe.

---

## Fonctionnalités

- Extraction des images depuis le HTML (`<img src="...">`).
- Téléchargement des images au format binaire.
- Résolution des URLs relatives (`urljoin`).
- Récursion optionnelle via les liens `<a href="...">`.
- Limite de profondeur configurable (`-l`, défaut 5).
- Dossier de sortie configurable (`-p`, défaut `./data/`).
- Restriction au même site pour les pages (évite de crawler tout le Web).
- Détection et évitement des boucles de navigation.
- Déduplication des pages visitées et des images téléchargées.
- Gestion des URLs non-ASCII (percent-encoding).
- Noms de fichiers sans collision grâce à un hash court.
- Gestion d'erreur **par page** et **par image** : un 404 n'arrête pas le crawl.
- Extensions prises en charge : `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`.

---

## Structure du dépôt

```text
Piscine_Cybersecurity/
└── days_0/
    ├── spider/
    │   └── spider.py      # programme principal
    └── scorpion/          # exercice 2 (à venir)
```

Le sujet PDF (`days_0/en.subject.pdf`) n'est volontairement pas versionné.

---

## Prérequis

- **Python 3.10 ou supérieur** (le code utilise `str | None` et les types
  génériques modernes comme `list[str]`).
- Aucun paquet à installer.
- Pour les tests : un serveur HTTP local, fourni par Python.

Testé avec Python 3.14 sous Linux.

---

## Utilisation

Depuis `days_0/spider/` :

```bash
python3 spider.py URL
```

Avec récursion et profondeur :

```bash
python3 spider.py -r -l 3 URL
```

Avec un dossier de sortie personnalisé :

```bash
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

### Exemples

```bash
# Une seule page
python3 spider.py https://example.com

# Récursion sur 2 niveaux
python3 spider.py -r -l 2 https://example.com

# Sortie dans /tmp/images
python3 spider.py -r -p /tmp/images https://example.com
```

Exemple de sortie :

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

## Architecture et flux de données

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

Le parcours est un **BFS** (breadth-first search) : les pages sont visitées
niveau par niveau grâce à une file `deque`.

---

## Détail du code

Le fichier `days_0/spider/spider.py` est organisé en petites fonctions
indépendantes et testables.

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

- `HTMLParser` fournit le moteur d'analyse ; `feed(html)` déclenche les callbacks.
- `handle_starttag` est appelé pour chaque balise ouvrante.
- `dict(attrs)` transforme la liste de tuples `(nom, valeur)` en dictionnaire.
- `.get("src")` évite un `KeyError` si l'attribut est absent.
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

Cette fonction percent-encode les caractères non-ASCII afin que la requête HTTP
reste valide.

Pourquoi c'est nécessaire : la ligne de requête HTTP doit être ASCII. Une URL
contenant `é` brut provoque :

```text
UnicodeEncodeError: 'ascii' codec can't encode character '\xe9'
```

`é` devient `%C3%A9`. Les caractères réservés (`:`, `/`, `?`, `&`, `=`, `#`) et
les `%` déjà présents sont laissés intacts, donc la fonction est **idempotente**.

### `is_image_url(url)`

```python
path = urlsplit(url).path.lower()
return path.endswith(VALID_EXTENSIONS)
```

- on isole le **chemin** : la query string et le fragment sont ignorés ;
- on compare en minuscules pour accepter `PHOTO.JPG` ;
- `endswith` reçoit le tuple `VALID_EXTENSIONS`.

Sans `urlsplit`, `"a.png?x=1".endswith(".png")` renverrait `False` à tort.

### `extract_images(html)` et `extract_links(html)`

Deux fonctions qui instancient le parseur, appellent `feed` puis `close`, et
renvoient le résultat. `extract_images` applique en plus le filtre
`is_image_url`.

### `same_site(base_url, url)`

```python
base = urlsplit(base_url)
target = urlsplit(url)
return (
    target.scheme in ("http", "https")
    and target.netloc.lower() == base.netloc.lower()
)
```

- seuls `http` et `https` sont acceptés (`mailto:`, `javascript:`, `ftp:` sont
  rejetés) ;
- l'hôte et le port doivent être identiques à ceux de la page de départ ;
- la comparaison est insensible à la casse.

Cette restriction évite qu'un lien externe fasse partir le spider sur tout le
Web. Les **images** peuvent en revanche être hébergées sur un autre domaine
(CDN), ce qui est courant.

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

- **file FIFO** : `deque` + `popleft()` pour un BFS efficace ;
- **profondeur** : chaque entrée est un couple `(url, depth)` ; on ajoute les
  liens avec `depth + 1` ;
- **anti-boucle** : `visited` empêche de revisiter une page ;
- **anti-doublon image** : `seen_images` mémorise les URLs absolues déjà
  téléchargées ;
- **fragment** : `urldefrag` retire `#ancre`, inutile côté serveur ;
- **erreurs** : `HTTPError` et `URLError` sont attrapés page par page ;
- **profondeur** : au-delà de `max_depth`, les liens de la page ne sont pas
  suivis, mais ses images sont quand même téléchargées.

### `parse_arg()`

Construit l'interface en ligne de commande avec `argparse` :

- `url` positionnel obligatoire ;
- `-r` booléen (`store_true`) ;
- `-l` entier avec `type=int` et défaut 5 ;
- `-p` chemin avec défaut `./data/` ;
- validation : `depth >= 0`, sinon `parser.error(...)` et code de sortie 2.

`argparse` gère aussi l'aide (`-h`) et les erreurs d'usage.

### `fetch(url)`

```python
req = Request(url, headers={"User-Agent": "Spider42/1.0"})
with urlopen(req, timeout=10) as resp:
    html = resp.read().decode("utf-8", errors="replace")
```

- `User-Agent` explicite, car certains serveurs refusent le client Python par
  défaut ;
- `timeout=10` pour éviter un blocage réseau ;
- `.read()` renvoie des `bytes`, décodés en UTF-8 pour obtenir du texte ;
- les erreurs réseau/HTTP remontent à l'appelant, qui décide quoi faire.

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
- `posixpath.basename` retire les dossiers et les `../` (protection contre la
  traversée de répertoire) ;
- un hash court de l'URL complète est ajouté pour éviter les collisions
  (`a/logo.png` et `b/logo.png` ne s'écrasent plus) ;
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

- lit les **octets** sans décodage (indispensable pour une image) ;
- écrit en binaire avec `write_bytes` (`wb` en C) ;
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
- le dossier est créé avant le crawl ;
- un résumé du nombre de pages visitées est affiché à la fin.

---

## Choix techniques et sécurité

### Bibliothèque standard uniquement

`urllib` et `html.parser` suffisent à faire des requêtes et à analyser du HTML.
Cela respecte l'esprit du sujet et évite les dépendances. `wget` et `scrapy`
sont volontairement absents.

### BFS plutôt que DFS

Le BFS visite les pages par niveau de profondeur, ce qui rend la limite `-l`
naturelle et prévisible. `deque.popleft()` est en O(1), contrairement à
`list.pop(0)`.

### Périmètre limité au même site

`same_site` empêche le spider de suivre des liens externes. C'est une mesure de
sécurité et de bon sens : sans elle, un site contenant un lien vers un moteur de
recherche pourrait entraîner un crawl incontrôlé.

### Noms de fichiers sûrs

- `basename` empêche d'écrire hors du dossier de destination via `../` ;
- le hash évite les collisions entre URLs différentes ;
- aucune donnée venue du serveur n'est utilisée comme chemin complet.

### Images en binaire

Une image ne doit jamais être décodée en texte. Le code lit et écrit des
`bytes`, ce qui préserve son intégrité.

### URLs normalisées

`normalize_url` garantit que les URLs envoyées à `urllib` sont ASCII. C'est ce
qui permet de traiter des pages contenant des liens accentués sans planter.

### Déduplication

- pages : `visited` (ensemble des URLs absolues) ;
- images : `seen_images` (ensemble des URLs absolues).

La déduplication se fait sur l'URL **résolue**, pas sur le `src` brut.

---

## Gestion des erreurs

| Situation | Comportement |
| --- | --- |
| Page 404 / 403 / 500 | `[SKIP] ... HTTP <code>`, page ignorée, crawl poursuivi |
| Connexion refusée / DNS / timeout | `[SKIP] ... <raison>`, page ignorée |
| Image 404 | `[FAIL] ... HTTP <code>`, les autres images continuent |
| Image réseau indisponible | `[FAIL] ... <raison>` |
| Profondeur négative | message d'argparse, code de sortie 2 |
| URL manquante | message d'argparse, code de sortie 2 |
| Image sans nom dérivable | ignorée (`filename_from_url` renvoie `None`) |

Un `try/except` est placé **dans** la boucle, au niveau de chaque page et de
chaque image, pour qu'une erreur isolée ne fasse pas tomber tout le programme.

---

## Tests

### Test de bout en bout avec un serveur local

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
- deux images téléchargées depuis `index` (`a.png`, `b.JPG`) ;
- `d.bmp` téléchargée depuis `gallery` ;
- `notes.txt` ignorée (extension non valide) ;
- `absent.png` en échec 404, sans arrêter le programme.

### Test des URLs accentuées

Créer une page `café.html` référencée par un lien `café.html` et une image
`img/été.png`. Le spider doit :

- encoder le lien en `caf%C3%A9.html` ;
- visiter la page ;
- télécharger l'image sans `UnicodeEncodeError`.

### Vérifications statiques

```bash
python3 -m py_compile days_0/spider/spider.py
```

---

## Limites connues et améliorations possibles

- **Pas de `robots.txt`** : à ajouter pour un usage responsable sur de vrais
  sites.
- **Pas de limitation de débit** : aucun délai entre les requêtes.
- **Pas de gestion de `<base href>`**, de `srcset`, ni des attributs `data-src`
  utilisés par le lazy loading.
- **Liens non-HTML** : un lien vers un `.css` ou un `.pdf` serait visité comme
  une page. Un contrôle du `Content-Type` serait plus robuste.
- **Noms de fichiers percent-encodés** pour les URLs non-ASCII
  (`%C3%A9t%C3%A9_...png`). Fonctionnel, mais moins lisible.
- **Code de sortie** : une page de départ inaccessible n'entraîne pas un code
  de sortie non nul.
- **Pas de parallélisme** : le crawl est séquentiel.
- **Aucune validation du `Content-Type`** avant d'écrire une image.

Ces points ne bloquent pas l'exercice mais constituent des pistes
d'amélioration naturelles.

---

## Scorpion — prochaine étape

Le dossier `days_0/scorpion/` est réservé au second programme :

```text
./scorpion FILE1 [FILE2 ...]
```

Objectif : lire les métadonnées EXIF et les afficher, pour les mêmes extensions
que Spider. Il devra au minimum afficher la date de création et les données
EXIF, avec un format de sortie libre. Le bonus du sujet prévoit la modification
ou la suppression des métadonnées, ainsi qu'une interface graphique.

---

## Compétences mises en œuvre

- Requêtes HTTP avec la bibliothèque standard (`urllib`).
- Analyse de HTML avec `html.parser`.
- Parcours de graphe en largeur (BFS) avec file `deque`.
- Gestion de la profondeur et des cycles.
- Résolution d'URLs relatives (`urljoin`, `urldefrag`).
- Encodage percent-encoding et gestion de l'Unicode.
- Téléchargement et écriture de données binaires.
- Sécurité des chemins de fichiers (`basename`, hash anti-collision).
- Interface CLI avec `argparse`.
- Gestion d'erreurs isolée par page et par image.
- Tests manuels avec un serveur HTTP local.
