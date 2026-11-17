# ft_onion — service caché Tor

Mise en place d'une page web statique accessible uniquement via le réseau Tor,
sous la forme d'une adresse `xxxxxxxxx.onion`.

## Objectif

Le projet doit fournir :

- une page statique `index.html` ;
- Nginx comme seul serveur web ;
- un service caché Tor exposant HTTP sur le port 80 ;
- SSH sur le port 4242 ;
- aucun port publié sur l'hôte et aucune règle de firewall.

## Architecture

```text
Utilisateur Tor
      │
      ▼
Réseau Tor
      │
      ▼
Service caché Tor dans la VM
      ├── port 80   ──►  Nginx  127.0.0.1:80
      └── port 4242 ──►  sshd   127.0.0.1:4242
```

Nginx et sshd écoutent uniquement sur `127.0.0.1`. Tor fait le lien avec le
réseau Tor. Aucun port n'est exposé sur l'interface réseau de la VM.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `index.html` | page statique, CSS inline, aucune ressource externe |
| `nginx.conf` | configuration du site servi par Nginx |
| `sshd_config` | configuration SSH sur le port 4242 |
| `torrc` | configuration du service caché Tor |
| `setup.sh` | installation et configuration automatique dans une VM Debian |

## Prérequis

- une VM Debian 12 ou 13 avec `sudo` ;
- accès Internet pour installer les paquets ;
- le dossier `days_2/` copié dans la VM.

Aucun paquet n'est installé sur l'hôte 42. Tout se fait dans la VM.

## Déploiement

Dans la VM :

```bash
cd days_2
chmod +x setup.sh
sudo ./setup.sh
```

Le script :

1. installe Nginx, Tor, OpenSSH et curl ;
2. copie `index.html` dans `/var/www/ft_onion/` ;
3. installe `nginx.conf` dans `sites-available` et active le site ;
4. ajoute les directives Tor manquantes dans `/etc/tor/torrc` ;
5. active et redémarre `tor@default` ;
6. installe `sshd_config` et redémarre SSH ;
7. vérifie que la page locale répond ;
8. affiche l'adresse `.onion`.

Le script est pensé pour être relancé : il compare `sshd_config`, ajoute
uniquement les lignes Tor manquantes et ne duplique pas les directives.

## Récupérer l'adresse

```bash
sudo cat /var/lib/tor/ft_onion/hostname
```

L'adresse change si les clés Tor sont supprimées ou si Tor est réinstallé sans
conserver `/var/lib/tor/ft_onion/`.

Après un redémarrage de Tor, le service peut mettre quelques dizaines de secondes
à publier son descripteur. Si `curl --socks5-hostname` échoue juste après le
script, attends que Tor affiche `Bootstrapped 100%` et réessaie.

## Tests

### Services et ports

```bash
systemctl is-active nginx tor@default ssh
sudo ss -tlnp | grep -E ':80|:4242|:9050'
```

Attendu :

```text
127.0.0.1:80
127.0.0.1:4242
127.0.0.1:9050
```

### Nginx en local

```bash
curl -I http://127.0.0.1/
curl -s http://127.0.0.1/ | grep "Welcome to ft_onion"
```

### HTTP via Tor

```bash
ONION="$(sudo cat /var/lib/tor/ft_onion/hostname)"
curl -I --socks5-hostname 127.0.0.1:9050 "http://$ONION/"
curl -s --socks5-hostname 127.0.0.1:9050 "http://$ONION/" | grep "Welcome to ft_onion"
```

### SSH via Tor

```bash
ONION="$(sudo cat /var/lib/tor/ft_onion/hostname)"
torsocks ssh -p 4242 mzouhir@$ONION
```

Le mot de passe est demandé : l'authentification par mot de passe est conservée.
Le bonus « SSH fortifié » n'a pas été implémenté.

### Vérifier Tor

```bash
systemctl status tor@default --no-pager
sudo journalctl -u tor@default -n 40 --no-pager
```

Chercher `Bootstrapped 100%`.

## Choix techniques

### Nginx statique uniquement

- `listen 127.0.0.1:80` ;
- `root /var/www/ft_onion` ;
- `index index.html` ;
- `autoindex off` ;
- `try_files $uri $uri/ =404` ;
- `access_log off` pour limiter les traces ;
- `server_tokens off` pour masquer la version ;
- en-têtes de sécurité (`nosniff`, `DENY`, `Referrer-Policy`, CSP).

Aucun PHP, Python, Node ou autre framework n'est utilisé.

### Tor

```text
HiddenServiceDir /var/lib/tor/ft_onion/
HiddenServicePort 80 127.0.0.1:80
HiddenServicePort 4242 127.0.0.1:4242
```

- `HiddenServiceDir` contient les clés et le hostname ;
- les clés privées Tor ne sont pas versionnées ;
- le premier port est celui vu par Tor, le second est la cible locale.

### SSH

```text
Port 4242
ListenAddress 127.0.0.1
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
KbdInteractiveAuthentication no
```

SSH n'est joignable que depuis la VM, donc depuis Tor, et non depuis le réseau
extérieur.

### Anonymat

- aucune ressource externe dans la page (CSS inline, favicon data URI) ;
- pas de CDN, police externe, analytics ou iframe ;
- logs Nginx désactivés ;
- pas de port publié sur l'hôte ;
- pas de règle de firewall ;
- clés Tor et SSH hors du dépôt.

## Limites

- Pas de bonus : pas de clé SSH obligatoire, pas de QR code, pas d'interface
  graphique.
- L'authentification SSH par mot de passe reste active.
- L'adresse `.onion` dépend des clés Tor locales ; elle change après suppression
  ou réinstallation des clés.
- La VM n'est pas versionnée : seuls les fichiers de configuration et le script
  le sont.

## Sécurité et évaluation

Avant l'évaluation :

```bash
sudo ss -tlnp
```

Aucun service ne doit écouter sur `0.0.0.0` pour les ports du projet. Les
redirections NAT d'administration doivent être supprimées côté hôte :

```bash
VBoxManage controlvm general_VM natpf1 delete "ssh"
VBoxManage controlvm general_VM natpf1 delete "ssh4242"
```

L'accès se fait alors par la console VirtualBox ou par Tor.

## Fichiers non versionnés

- `en.subject.pdf` ;
- les clés Tor générées dans `/var/lib/tor/ft_onion/` ;
- les clés SSH privées ;
- les sauvegardes de VM (`.vdi`, `.vbox`, snapshots, archives).
