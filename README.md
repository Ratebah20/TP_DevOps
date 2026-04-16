# Projet DevOps — Pipeline CI/CD GitLab pour Ecommerce

**Groupe RJRST** — Rateb, Jonathan, Romain, Soulymane, Tomy
**Date** : 15-04-2026
**Module** : 4DEVOPS — Projet final

---

## Sommaire

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Solutions choisies](#2-solutions-choisies)
3. [Architecture du projet](#3-architecture-du-projet)
4. [Frameworks et technologies utilisés](#4-frameworks-et-technologies-utilisés)
5. [Démarche détaillée étape par étape](#5-démarche-détaillée-étape-par-étape)
6. [Annexes — logs et commandes](#6-annexes--logs-et-commandes)

---

## 1. Contexte et objectifs

### 1.1 Situation client

Nous intervenons pour un nouveau client qui possède un ecommerce générant **15 M€ de CA annuel**. Frustré par la lenteur et les erreurs de ses mises à jour passées (effectuées par d'autres ESN), il souhaite un POC (Proof of Concept) démontrant la robustesse et l'automatisation de notre solution CI/CD avant de nous confier sa plateforme complète.

### 1.2 Exigences exprimées lors de l'échange

Le client a formulé cinq questions clés pendant la réunion de cadrage. Nous avons traduit chacune en exigence technique :

| Demande du client | Traduction technique |
|---|---|
| « Comment mettrez-vous à jour mon ecommerce ? » | Pipeline CI/CD automatisé |
| « Si vous faites une erreur, avez-vous un process de CTRL+Z ? » | Mécanisme de rollback vers version précédente |
| « Sauvegardes des données clients avec restauration ? » | Stratégie de backup + restore de la base de données |
| « Analyses pour détecter les cyberattaques ? » | Security scanning des images Docker |
| « Déployer pour test avant prod réelle ? » | Environnements staging et production séparés |

Le Product Owner a ajouté deux contraintes fortes :
- **Aucune tolérance aux coupures de service** (pas de perte de CA)
- **Aller à l'essentiel** — pas de sur-ingénierie

### 1.3 Objectif du POC

Livrer une chaîne CI/CD complète et fonctionnelle démontrant :
- Build automatisé de deux images Docker (dev et prod optimisée)
- Tests unitaires automatiques
- Analyse de sécurité avec détection de CVE
- Déploiement automatique en staging
- Déploiement manuel (après validation) en production sur un serveur distant
- Backup et rollback à la demande
- Application accessible depuis l'extérieur du serveur

### 1.4 Répartition des tâches

Le projet a été réalisé en groupe de cinq. Les responsabilités ont été réparties selon les composants de l'architecture et les compétences de chacun, avec des points de synchronisation réguliers pour garantir la cohérence globale.

| Membre | Responsabilités principales |
|---|---|
| **Rateb** | Architecture globale, mise en place de l'infrastructure GitLab CE et des trois runners, configuration des deux VMs Colima (default et remote-server), rédaction du `.gitlab-ci.yml` et orchestration du pipeline complet, rédaction du rapport |
| **Jonathan** | Sécurité — configuration du compte utilisateur non-admin, gestion des clés SSH, intégration de Trivy dans le pipeline, analyse des CVE détectées et mise à jour des dépendances pour les corriger |
| **Romain** | Containerisation — rédaction et optimisation des deux Dockerfiles (`Dockerfile.dev` et `Dockerfile.prod`), comparaison des tailles d'images, mise en place du multi-stage build Alpine, configuration du Container Registry GitLab |
| **Soulymane** | Application Django — adaptation de `django-volt-dashboard`, configuration du `settings.py` pour PostgreSQL via variables d'environnement, intégration de `django-dbbackup`, écriture de l'`entrypoint.sh` pour l'initialisation automatique |
| **Tomy** | Stratégie de déploiement et fiabilité — mise en place des environnements staging et production, logique de rollback via tag `:previous`, stage de backup, tests de bout en bout du cycle deploy → backup → rollback |

Chaque membre a également contribué à la rédaction de la documentation de sa partie et à la relecture croisée du rapport final. Les points bloquants (YAML invalide, erreurs de `config.toml`, dépendances manquantes) ont été résolus collectivement, ce qui a renforcé la maîtrise de la chaîne CI/CD par l'ensemble du groupe.

---

## 2. Solutions choisies

Pour répondre aux cinq exigences client, voici les solutions techniques retenues :

### 2.1 Pipeline CI/CD automatisé

Nous utilisons **GitLab CE Community Edition** auto-hébergé comme serveur central. À chaque `git push` sur la branche `main`, un pipeline s'exécute automatiquement avec huit étapes (stages) : `build_dev`, `build_prod`, `test`, `security_scan`, `deploy_staging`, `deploy_production`, `backup`, `rollback`.

Les trois derniers stages (`deploy_production`, `backup`, `rollback`) sont déclenchés manuellement via un bouton dans l'interface GitLab, ce qui laisse la main à l'équipe sur les actions critiques en production.

### 2.2 Mécanisme de rollback (CTRL+Z)

Avant chaque déploiement en production, le pipeline tague automatiquement l'image actuellement en prod avec le tag `:previous` et la pousse dans le registry GitLab. Le stage `rollback` (manuel) peut à tout moment pull ce tag et redéployer immédiatement la version précédente. Cette logique garantit un retour arrière en moins d'une minute en cas d'incident.

### 2.3 Backup et restauration de la base de données

Nous avons intégré **django-dbbackup** dans l'application Django. Ce package génère des dumps PostgreSQL à la demande, stockés dans un volume Docker persistant (`app-prod-backups`). Le stage `backup_db` (manuel) exécute `python manage.py dbbackup` dans le conteneur de production. Le dump peut ensuite être restauré via `python manage.py dbrestore`.

### 2.4 Security scanning

Le stage `security_scan` utilise **Trivy** (aquasecurity) pour analyser l'image Docker de production. Trivy détecte les vulnérabilités CVE connues dans les packages système Alpine ainsi que dans les dépendances Python (Django, etc.). Lors de notre premier scan, Trivy a détecté **15 CVE dans Django 4.2.9** (2 CRITICAL et 13 HIGH). Nous avons mis à jour vers Django 4.2.30, le scan suivant est revenu avec 0 vulnérabilité — preuve que le process fonctionne.

### 2.5 Environnements staging et production séparés

Nous avons créé deux VMs distinctes via **Colima** (runtime Docker léger pour macOS) :
- **VM default** : héberge GitLab CE, le registry Docker et un runner local qui gère les stages `build_dev`, `build_prod`, `test`, `security_scan`
- **VM remote-server** (IP `192.168.64.2`) : héberge deux runners dédiés (`staging` et `production`) ainsi que les conteneurs de l'application

Le staging est accessible sur `http://192.168.64.2:8001` et la production sur `http://192.168.64.2:8000`. Deux bases PostgreSQL distinctes isolent complètement les données.

---

## 3. Architecture du projet

### 3.1 Vue d'ensemble

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MAC STUDIO (Hôte)                                   │
│                                                                             │
│  ┌────────────────────────────────┐    ┌────────────────────────────────┐ │
│  │  VM DEFAULT (4 CPU, 8 Go RAM)  │    │ VM REMOTE-SERVER               │ │
│  │                                 │    │ (2 CPU, 4 Go RAM)              │ │
│  │                                 │    │ IP: 192.168.64.2               │ │
│  │  ┌──────────────────────────┐  │    │                                │ │
│  │  │ GitLab CE                │  │    │  ┌──────────────────────────┐ │ │
│  │  │ - Interface web :8080    │  │    │  │ Runner STAGING           │ │ │
│  │  │ - SSH :2222              │  │    │  │ - Tag: staging           │ │ │
│  │  │ - Registry Docker :5050  │  │    │  │ - Pull image + deploy    │ │ │
│  │  └──────────────────────────┘  │    │  └──────────────────────────┘ │ │
│  │                                 │    │                                │ │
│  │  ┌──────────────────────────┐  │    │  ┌──────────────────────────┐ │ │
│  │  │ Runner LOCAL             │  │◄───┤  │ Runner PRODUCTION        │ │ │
│  │  │ - Tag: local             │  │    │  │ - Tag: production        │ │ │
│  │  │ - Build images           │  │    │  │ - Deploy manuel          │ │ │
│  │  │ - Tests / Scan Trivy     │  │    │  │ - Backup / Rollback      │ │ │
│  │  │ - Push vers registry     │  │    │  └──────────────────────────┘ │ │
│  │  └──────────────────────────┘  │    │                                │ │
│  │                                 │    │  ┌──────────────────────────┐ │ │
│  └────────────────────────────────┘    │  │ app-staging-rjrst :8001  │ │ │
│                  │                      │  │ db-staging-rjrst         │ │ │
│                  │  Registry Docker     │  │ (PostgreSQL)             │ │ │
│                  │  gitlab.local:5050   │  └──────────────────────────┘ │ │
│                  │                      │                                │ │
│                  │                      │  ┌──────────────────────────┐ │ │
│                  └──────────────────────┤  │ app-prod-rjrst :8000     │ │ │
│                                          │  │ db-prod-rjrst            │ │ │
│                                          │  │ (PostgreSQL)             │ │ │
│                                          │  │ Volume backups persistant│ │ │
│                                          │  └──────────────────────────┘ │ │
│                                          └────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Composants et naming

Conformément aux consignes, chaque composant porte les initiales du groupe suivies de la date de création :

| Composant | Nom |
|---|---|
| Conteneur GitLab CE | `gitlab-ce-rjrst-15-04-2026` |
| Runner local | `gitlab-runner-local-rjrst-15-04-2026` |
| Runner staging | `gitlab-runner-staging-rjrst-15-04-2026` |
| Runner production | `gitlab-runner-prod-rjrst-15-04-2026` |
| Projet GitLab | `ecommerce-rjrst-15-04-2026` |
| Image Docker | `gitlab.local:5050/root/ecommerce-rjrst-15-04-2026` |
| Conteneur app staging | `app-staging-rjrst` |
| Conteneur app production | `app-prod-rjrst` |
| Base staging | `db-staging-rjrst` |
| Base production | `db-prod-rjrst` |
| Réseau Docker | `network-rjrst-15-04-2026` |

### 3.3 Flux CI/CD

```
Développeur
   │
   │  git push (GitHub + GitLab)
   ▼
GitLab CE détecte le push et lit .gitlab-ci.yml
   │
   ▼
[Runner LOCAL] → Stage 1: build_dev      → push image :dev au registry
[Runner LOCAL] → Stage 2: build_prod     → push image :prod + :SHA au registry
[Runner LOCAL] → Stage 3: test           → pull image et vérifie la config Django
[Runner LOCAL] → Stage 4: security_scan  → Trivy scan sur image :prod
   │
   ▼
[Runner STAGING] → Stage 5: deploy_staging (automatique)
                 → pull image :prod → lance db-staging + app-staging
   │
   ▼ [DÉCISION MANUELLE DE L'ÉQUIPE]
   │
[Runner PROD] → Stage 6: deploy_production (manuel)
              → sauvegarde version actuelle en :previous
              → pull image :SHA → lance db-prod + app-prod
   │
   ▼ [À LA DEMANDE]
   │
[Runner PROD] → backup_db (manuel)   → dbbackup → dump dans volume persistant
[Runner PROD] → rollback (manuel)    → pull :previous → redéploie version N-1
```

---

## 4. Frameworks et technologies utilisés

### 4.1 Colima

**Rôle** : Runtime Docker léger pour macOS, alternative à Docker Desktop.

**Avantages** : Open-source, léger, gratuit, permet de créer plusieurs VMs Docker indépendantes avec `colima start --profile`. Idéal pour simuler un environnement multi-serveurs sur une seule machine.

**Inconvénients** : Spécifique à macOS, moins d'intégration GUI que Docker Desktop.

**Justification du choix** : Colima nous permet de créer deux VMs Linux distinctes (default pour GitLab, remote-server pour le déploiement) qui simulent un environnement de production réaliste sans avoir besoin de vrais serveurs distants.

### 4.2 GitLab Community Edition

**Rôle** : Plateforme centrale Git + CI/CD + Container Registry.

**Avantages** : Open-source et auto-hébergeable, intègre nativement un Container Registry, gestion fine des environnements (staging, production) via les variables `environment:`, interface moderne pour visualiser les pipelines et leurs stages.

**Inconvénients** : Gourmand en ressources au premier lancement, configuration initiale complexe (nginx interne, Redis, PostgreSQL, Sidekiq embarqués).

**Justification du choix** : C'est la demande explicite du cahier des charges. GitLab CE couvre Git + CI/CD + Registry dans un seul produit, ce qui simplifie l'architecture.

### 4.3 Docker + Docker Registry GitLab

**Rôle** : Containeurisation de l'application Django et stockage des images.

**Avantages** : Portabilité maximale, isolation entre environnements, versioning via tags, rollback instantané par retag.

**Inconvénients** : Les images non optimisées deviennent vite lourdes ; nécessite de maîtriser les multi-stage builds pour la production.

**Justification du choix** : Standard de l'industrie pour le déploiement d'applications, parfaitement intégré avec GitLab.

### 4.4 GitLab Runner

**Rôle** : Agents qui exécutent les jobs du pipeline.

**Avantages** : Supporte plusieurs executors (Docker, shell, Kubernetes), possibilité de dédier des runners par tag à des environnements spécifiques, léger.

**Inconvénients** : La configuration TOML est sensible aux erreurs de formatage, les runners peuvent refuser silencieusement de prendre un job si les tags ne correspondent pas exactement.

**Justification du choix** : Les trois runners dédiés (local, staging, production) nous permettent d'avoir une vraie séparation des responsabilités — le runner de prod est le seul qui a les droits de déployer sur la VM de prod.

### 4.5 Django 4.2 + django-volt-dashboard

**Rôle** : Application ecommerce de démonstration.

**Avantages** : Framework mature, ORM puissant, système de migrations automatique, intégration native avec PostgreSQL, dashboard administrateur prêt à l'emploi (django-admin-volt).

**Inconvénients** : Version LTS 4.2 nécessite vigilance sur les CVE (cf. section security scan).

**Justification du choix** : L'app django-volt-dashboard est un projet open-source réaliste avec dashboard, authentification, modèles — elle représente bien un ecommerce.

### 4.6 PostgreSQL 16 Alpine

**Rôle** : Base de données relationnelle pour l'application.

**Avantages** : Open-source, robuste, supporte les transactions complexes, image Alpine très légère, volumes Docker pour la persistance.

**Inconvénients** : Configuration initiale plus lourde que SQLite.

**Justification du choix** : Choix standard pour une app Django en production, essentiel pour justifier les backups demandés par le client.

### 4.7 Trivy (security scanner)

**Rôle** : Analyse de vulnérabilités dans les images Docker.

**Avantages** : Open-source, scan rapide, base CVE régulièrement mise à jour, détecte les failles dans les packages OS (Alpine) et dans les dépendances applicatives (Python), rapport clair.

**Inconvénients** : Peut générer beaucoup de bruit sur les images de dev non optimisées, nécessite d'avoir internet pour télécharger la base CVE.

**Justification du choix** : Standard de l'industrie pour le container scanning, ligne de défense directe contre la demande du client sur la cybersécurité.

### 4.8 django-dbbackup

**Rôle** : Package Django pour les dumps et restaurations de base de données.

**Avantages** : Intégré au management Django (`python manage.py dbbackup`), supporte PostgreSQL / MySQL / SQLite, stockage configurable (local, S3, etc.).

**Inconvénients** : Package tiers, moins connu que `pg_dump` direct.

**Justification du choix** : S'intègre parfaitement dans l'écosystème Django, facilement appelable depuis un job CI/CD.

### 4.9 Gunicorn + Whitenoise

**Rôle** : Serveur WSGI (Gunicorn) et gestionnaire de fichiers statiques (Whitenoise) pour la production.

**Avantages** : Gunicorn est un serveur WSGI production-ready, Whitenoise évite d'avoir à configurer Nginx pour les fichiers statiques.

**Inconvénients** : Moins performant qu'un vrai Nginx en reverse proxy pour les très gros trafics.

**Justification du choix** : Pour un POC, éviter la complexité d'un Nginx supplémentaire tout en restant production-ready.

### 4.10 Multi-stage build Alpine

**Rôle** : Optimisation de la taille de l'image Docker production.

**Résultats mesurés** :
- Image `Dockerfile.dev` (Python 3.12 complet) : **1.81 GB**
- Image `Dockerfile.prod` (Alpine multi-stage) : **261 MB**
- **Gain : ~7× plus léger**

**Avantages** : Pull et deploy beaucoup plus rapides en production, surface d'attaque réduite, moins de vulnérabilités héritées.

**Inconvénients** : Alpine utilise musl au lieu de glibc, certaines dépendances Python avec extensions C nécessitent `apk add gcc musl-dev libpq-dev` dans le stage builder.

---

## 5. Démarche détaillée étape par étape

### Phase 1 — Mise en place de l'infrastructure

#### 1.1 Lancement de Colima

Deux VMs Docker ont été créées pour simuler une architecture multi-serveurs réaliste :

```bash
colima start --cpu 4 --memory 8 --disk 60
colima start --profile remote-server --cpu 2 --memory 4 --disk 20 --network-address
```

#### 1.2 Déploiement de GitLab CE

Le fichier `gitlab-infra/docker-compose.yml` orchestre GitLab CE et son runner local. Configuration clé : Nginx écoute sur le port 80 en interne, mappé sur le 8080 externe, avec le Container Registry actif sur le port 5050.

Commande de lancement :
```bash
cd gitlab-infra
docker compose up -d
docker logs -f gitlab-ce-rjrst-15-04-2026
```

<img width="975" height="465" alt="image" src="https://github.com/user-attachments/assets/c3931490-76b2-4715-b9b1-e20bb4323877" />

#### 1.3 Récupération du mot de passe root initial

```bash
docker exec gitlab-ce-rjrst-15-04-2026 cat /etc/gitlab/initial_root_password
```

<img width="975" height="242" alt="image" src="https://github.com/user-attachments/assets/e741c9ea-80bf-4ad8-8bc4-0212947b4995" />

#### 1.4 Configuration des registries Docker insecure

Pour que les deux VMs puissent communiquer avec le registry GitLab sans certificat HTTPS, on configure le daemon Docker de chaque VM :

```bash
# VM default
colima ssh -- sudo sh -c 'echo "{\"insecure-registries\": [\"gitlab.local:5050\"]}" > /etc/docker/daemon.json'
colima ssh -- sudo systemctl restart docker

# VM remote-server
colima ssh --profile remote-server -- sudo sh -c 'echo "192.168.1.74 gitlab.local" >> /etc/hosts'
colima ssh --profile remote-server -- sudo sh -c 'echo "{\"insecure-registries\": [\"gitlab.local:5050\"]}" > /etc/docker/daemon.json'
colima ssh --profile remote-server -- sudo systemctl restart docker
```

#### 1.5 Création du projet GitLab

Depuis l'interface GitLab, nouveau projet blank nommé `ecommerce-rjrst-15-04-2026`.

<img width="975" height="417" alt="image" src="https://github.com/user-attachments/assets/72cba2ba-889a-4246-8a46-4c12fca89f85" />

#### 1.6 Installation et enregistrement des trois runners

Un runner local est déjà dans le docker-compose, deux runners distants sont lancés sur la VM remote-server. Chaque runner est enregistré avec un token unique généré dans l'interface GitLab, puis configuré avec :
- `clone_url` pour forcer le clonage via le nom interne Docker
- `extra_hosts` pour que les jobs résolvent `gitlab.local`
- Socket Docker monté pour permettre les commandes `docker` dans les jobs
- Tags appropriés (`local`, `staging`, `production`)

<img width="975" height="402" alt="image" src="https://github.com/user-attachments/assets/059b6c22-5d8f-4eeb-96ce-235600c2b5dc" />

#### 1.7 Création du repo GitHub miroir

Un repo GitHub est créé en parallèle pour que l'enseignant puisse consulter le code. Les deux remotes (GitHub en origin, GitLab) sont configurés sur le dépôt local.

<img width="975" height="446" alt="image" src="https://github.com/user-attachments/assets/9359fddc-ba96-4e6f-a8dc-6c4f0e404000" />

### Phase 2 — Sécurité : compte utilisateur non-admin

Le projet ne doit pas être manipulé avec le compte root. Un utilisateur `rateb` a été créé avec le rôle Maintainer sur le projet.

#### 2.1 Création du compte utilisateur

Via Admin → Users → New : username `rateb`, email `rateb@rjrst.local`.

<img width="975" height="496" alt="image" src="https://github.com/user-attachments/assets/6da482ef-00a0-41d0-9c60-b0139228fe79" />

#### 2.2 Configuration du mot de passe

<img width="975" height="204" alt="image" src="https://github.com/user-attachments/assets/c57f8853-2a38-495a-a6ed-2fa37d15f7cb" />

#### 2.3 Ajout au projet avec le rôle Maintainer

Project → Members → Invite members.

<img width="975" height="417" alt="image" src="https://github.com/user-attachments/assets/3b4e8b2f-eac5-4107-83e8-0a55f1410386" />

<img width="975" height="427" alt="image" src="https://github.com/user-attachments/assets/b880a051-5020-484d-8b38-a8751bab3b4e" />

#### 2.4 Configuration SSH pour l'utilisateur

Génération d'une clé ed25519 dédiée à rateb :

```bash
ssh-keygen -t ed25519 -C "rateb-rjrst@gitlab.local" -f ~/.ssh/id_ed25519_rateb -N ""
cat ~/.ssh/id_ed25519_rateb.pub
```

<img width="975" height="123" alt="image" src="https://github.com/user-attachments/assets/14d923f8-1272-4f54-afd3-8795d52c11de" />

<img width="975" height="446" alt="image" src="https://github.com/user-attachments/assets/56b5a773-d8cb-4653-bff2-5a4fb535f1d4" />

Configuration SSH côté Mac (`~/.ssh/config`) pour simplifier les commandes :

```
Host gitlab-rjrst
  HostName localhost
  Port 2222
  User git
  IdentityFile ~/.ssh/id_ed25519_rateb
```

#### 2.5 Test de la connexion SSH

```bash
ssh -T gitlab-rjrst
```

<img width="975" height="325" alt="image" src="https://github.com/user-attachments/assets/a419f27a-5b84-4c3b-8328-396e45f9ca3f" />

#### 2.6 Premier push sur les deux remotes

```bash
git remote add gitlab gitlab-rjrst:root/ecommerce-rjrst-15-04-2026.git
git push gitlab main
git push origin main
```

<img width="975" height="400" alt="image" src="https://github.com/user-attachments/assets/02e0748d-1272-48c2-b095-36b94dbf9579" />

<img width="973" height="592" alt="image" src="https://github.com/user-attachments/assets/f88f10cf-51fb-4e10-91f0-a9beb865fdec" />

<img width="923" height="255" alt="image" src="https://github.com/user-attachments/assets/772abfca-29d7-4d94-bcd4-11ba52982e03" />

### Phase 3 — Structure du projet et application Django

#### 3.1 Structure du repo

L'organisation finale sépare clairement l'infrastructure et le code applicatif :

```
projet-devops-rjrst/
├── app/                      # Application Django
│   ├── apps/                 # Modules Django (pages, charts, dyn_dt, dyn_api)
│   ├── cli/                  # Utilitaires requis par dyn_dt
│   ├── config/               # Settings, URLs, WSGI
│   ├── templates/            # Templates HTML
│   ├── static/               # CSS, JS, images
│   ├── Dockerfile.dev        # Image basique (non optimisée)
│   ├── Dockerfile.prod       # Image optimisée multi-stage Alpine
│   ├── entrypoint.sh         # Script d'initialisation (migrations, superuser)
│   ├── requirements.txt      # Dépendances Python
│   ├── gunicorn-cfg.py       # Config Gunicorn
│   └── manage.py
├── gitlab-infra/             # Infrastructure GitLab
│   └── docker-compose.yml
├── .gitlab-ci.yml            # Pipeline CI/CD
└── README.md
```

<img width="477" height="181" alt="image" src="https://github.com/user-attachments/assets/a82a1795-0640-4aee-804e-3ce0362105eb" />

#### 3.2 Application Django retenue

Nous avons choisi `django-volt-dashboard` (open-source, app-generator.dev) qui fournit un dashboard admin complet avec authentification, modèles d'exemple et templates Bootstrap. Le `config/settings.py` natif supporte déjà PostgreSQL via variables d'environnement, ce qui nous évite une grosse modification.

#### 3.3 Entrypoint avec migrations automatiques

Le script `entrypoint.sh` est lancé au démarrage de chaque conteneur. Il :
- Attend que la base PostgreSQL soit joignable
- Applique les migrations Django (`python manage.py migrate`)
- Collecte les fichiers statiques (Whitenoise)
- Crée le superuser admin si les variables `DJANGO_SUPERUSER_*` sont définies
- Lance l'app (runserver pour dev, Gunicorn pour prod)

Cette automatisation garantit qu'on n'a **jamais** à se connecter manuellement sur un conteneur pour initialiser la base, même après un rollback.

#### 3.4 Dockerfile.dev (version non optimisée)

Image basique pour développement et comparaison pédagogique. Taille finale : **1.81 GB**.

#### 3.5 Dockerfile.prod (multi-stage optimisé)

Le stage builder compile les dépendances Python sur Alpine avec gcc/musl-dev/libpq-dev. Le stage final (production) ne garde que le binaire Python et les libs compilées, sans les outils de build, en utilisateur non-root. Taille finale : **261 MB** (~7× plus léger).

### Phase 4 — Pipeline CI/CD

Le fichier `.gitlab-ci.yml` définit huit stages exécutés en séquence. Les stages sont répartis entre les trois runners selon leur tag pour une vraie séparation des responsabilités.

#### 4.1 Premier déclenchement du pipeline

Dès le premier push sur `main`, le pipeline démarre automatiquement.

<img width="975" height="356" alt="image" src="https://github.com/user-attachments/assets/d9d6ba80-1c9c-40fd-bc6c-b329085c14c5" />

<img width="975" height="471" alt="image" src="https://github.com/user-attachments/assets/523f3bf8-0e40-40ff-8477-c31712fd4372" />

#### 4.2 Stage 1 et 2 — build_dev et build_prod

Le runner local exécute `docker login` vers le registry GitLab, puis `docker build` avec les deux Dockerfiles. Les images sont taguées et pushées : `:dev`, `:prod`, `:latest`, `:SHA_COMMIT`. Le tag de commit court permet un rollback granulaire vers n'importe quelle version historique.

<img width="975" height="425" alt="image" src="https://github.com/user-attachments/assets/ab628467-03ce-4def-a382-a60b37f98953" />

<img width="975" height="423" alt="image" src="https://github.com/user-attachments/assets/d1bdc956-9cb3-4f9a-8f15-0f3e7d58f2e0" />

#### 4.3 Stage 3 — test

Ce stage pull l'image `:prod` depuis le registry et lance `python manage.py check` pour valider la configuration Django et les imports de tous les modules.

<img width="975" height="417" alt="image" src="https://github.com/user-attachments/assets/b9a09c9e-351d-4701-9b1f-60c46a672dc0" />

#### 4.4 Stage 4 — security_scan (Trivy)

Trivy analyse l'image `:prod` et cherche les CVE dans les packages Alpine et les dépendances Python. Le stage est configuré avec `allow_failure: true` pour ne pas bloquer le pipeline en cas de CVE (ce qui nous permet de voir le rapport et décider de corriger).

**Premier scan** : 15 vulnérabilités Django 4.2.9 (2 CRITICAL, 13 HIGH) : SQL injection, déni de service, path traversal...

<img width="975" height="329" alt="image" src="https://github.com/user-attachments/assets/6e80c076-3f05-4a7d-9d6b-02c03eadf26b" />

Correction : mise à jour vers Django 4.2.30 (version LTS patchée).

<img width="975" height="469" alt="image" src="https://github.com/user-attachments/assets/f7843301-27c1-4c35-b22e-0ce29976f621" />

**Deuxième scan** : 0 vulnérabilité détectée.

<img width="975" height="394" alt="image" src="https://github.com/user-attachments/assets/2511a9e2-e234-457b-bc59-75d6b3cdbe03" />

Cette capacité à **détecter puis corriger** est exactement ce que le client demandait.

#### 4.5 Stage 5 — deploy_staging (automatique)

Le runner staging (sur la VM remote) pull l'image `:prod` depuis le registry, crée un réseau Docker dédié, lance PostgreSQL (si inexistant) puis déploie l'application avec les variables d'environnement adaptées. L'app est accessible sur `http://192.168.64.2:8001`.

<img width="975" height="425" alt="image" src="https://github.com/user-attachments/assets/3fd2ac74-793f-4958-83fc-6ab805753414" />

Test avec curl :
```bash
curl -s -o /dev/null -w "%{http_code}" http://192.168.64.2:8001/
# Retourne 200 → déploiement validé
```

<img width="975" height="69" alt="image" src="https://github.com/user-attachments/assets/e8e8005b-3172-4ea0-ab5e-a9da8e1ee569" />

<img width="975" height="473" alt="image" src="https://github.com/user-attachments/assets/79741ac7-8b7b-4a76-a6e2-d921379b8073" />

<img width="975" height="423" alt="image" src="https://github.com/user-attachments/assets/7ffe012b-ab8e-4db7-8c5e-90a084f2f427" />

#### 4.6 Stage 6 — deploy_production (manuel)

Ce stage est volontairement manuel pour que l'équipe valide le staging avant de toucher à la prod. Avant chaque déploiement, le pipeline tague l'image actuellement en prod avec `:previous` et la pousse au registry — c'est la clé du mécanisme de rollback.

<img width="975" height="127" alt="image" src="https://github.com/user-attachments/assets/68da4b55-4e07-4a8b-acd6-04690534c8fa" />

<img width="975" height="181" alt="image" src="https://github.com/user-attachments/assets/667ace06-255b-4980-a288-e525ddc838b8" />

Test avec curl sur le port 8000 :
```bash
curl -s -o /dev/null -w "%{http_code}" http://192.168.64.2:8000/
# Retourne 200 → production en ligne
```

<img width="975" height="65" alt="image" src="https://github.com/user-attachments/assets/b222c319-f533-4f01-80cf-9d540d49b03c" />

<img width="975" height="483" alt="image" src="https://github.com/user-attachments/assets/4a429ea1-1c5a-48f4-a342-218c81467118" />

#### 4.7 Stage 7 — backup_db (manuel)

Ce stage exécute `python manage.py dbbackup` dans le conteneur de production. Le dump PostgreSQL compressé est stocké dans le volume persistant `app-prod-backups`, survivant à toute destruction du conteneur.

<img width="975" height="123" alt="image" src="https://github.com/user-attachments/assets/da18c261-3991-404c-ae83-69967e8a5be1" />

<img width="975" height="421" alt="image" src="https://github.com/user-attachments/assets/6aa7cd8c-bda3-446b-ba03-ce24f14d7e67" />

#### 4.8 Stage 8 — rollback (manuel)

Ce stage pull l'image `:previous` depuis le registry et redéploie l'application en moins d'une minute. Nous avons testé deux rollbacks consécutifs avec succès, prouvant que le mécanisme est fiable.

<img width="975" height="135" alt="image" src="https://github.com/user-attachments/assets/d2558538-1320-494f-9be6-c52f59646870" />

<img width="975" height="425" alt="image" src="https://github.com/user-attachments/assets/9415e0fe-dc97-4e28-b5b2-903ff95d0545" />

#### 4.9 Vue d'ensemble du pipeline complet

<img width="975" height="125" alt="image" src="https://github.com/user-attachments/assets/899c72b8-79b8-46a6-9f76-97d9dcef6d82" />

### Phase 5 — Environnements GitLab

GitLab propose nativement le concept d'**environnements** pour tracer quelle version est déployée où. Nos deux environnements `staging` et `production` sont visibles dans Deploy → Environments avec l'historique des déploiements, les liens d'accès direct et le commit associé.

<img width="975" height="238" alt="image" src="https://github.com/user-attachments/assets/2c7283b0-cf4d-4c6d-8cf7-5af63e963a5c" />

Cette vue est précieuse pour l'équipe ops : d'un coup d'œil on sait quelle version est en production, depuis combien de temps, et qui l'a déployée.

---

## 6. Annexes — logs et commandes

### 6.1 Génération de l'historique des commandes

Conformément aux consignes, l'historique complet des commandes bash est exporté :

```bash
history > history-projet-rjrst-15-04-2026.log
```

Ce fichier est versionné dans le repo à la racine.

### 6.2 Logs des conteneurs principaux

```bash
# GitLab CE
docker logs gitlab-ce-rjrst-15-04-2026 > logs-gitlab-ce.log

# Runner local
docker logs gitlab-runner-local-rjrst-15-04-2026 > logs-runner-local.log

# Runners distants
docker context use colima-remote-server
docker logs gitlab-runner-staging-rjrst-15-04-2026 > logs-runner-staging.log
docker logs gitlab-runner-prod-rjrst-15-04-2026 > logs-runner-prod.log
docker logs app-prod-rjrst > logs-app-prod.log
docker logs db-prod-rjrst > logs-db-prod.log
docker context use colima
```

### 6.3 Commandes utiles pour la démo orale

| Action | Commande |
|---|---|
| Voir les VMs Colima | `colima list` |
| Changer de contexte | `docker context use colima` / `colima-remote-server` |
| État des conteneurs | `docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'` |
| Images dans le registry | http://localhost:8080/root/ecommerce-rjrst-15-04-2026/container_registry |
| Voir les pipelines | http://localhost:8080/root/ecommerce-rjrst-15-04-2026/-/pipelines |
| Voir les environnements | http://localhost:8080/root/ecommerce-rjrst-15-04-2026/-/environments |
| App staging | http://192.168.64.2:8001 |
| App production | http://192.168.64.2:8000 |
| Admin Django | http://192.168.64.2:8000/admin (admin / admin123) |

### 6.4 Problèmes rencontrés et solutions

| Problème | Cause | Solution |
|---|---|---|
| YAML invalide au premier push (backslashes multi-lignes) | GitLab CI parse mal les `\` de continuation dans les scripts | Tout réécrire en commandes single-line |
| `ModuleNotFoundError: No module named 'cli'` dans le stage test | Le dossier `cli/` supprimé par erreur était référencé par `dyn_dt/views.py` | Restauration du dossier `cli/` depuis le repo original |
| `ModuleNotFoundError: anthropic`, `astor` | Le module `cli/` importe ces dépendances | Restauration complète du requirements.txt d'origine |
| `requirements.txt` créé à la racine au lieu de `app/` | Le `cd app` était manquant lors du `cat >` | Placement du fichier au bon endroit |
| `config.toml` avec clés dupliquées | Les `sed -i` successifs empilaient `clone_url` et `tags` | Réécriture propre de chaque config.toml via un heredoc dans un conteneur alpine |
| Runners « offline » malgré l'enregistrement | Mauvais tag assigné au runner | Modification du tag via l'UI GitLab (Project → Runners → Edit) |
| `Trivy: docker.io/aquasec/trivy:latest: not found` | Le repo Docker Hub a été déplacé | Utilisation de `ghcr.io/aquasecurity/trivy:latest` (repo officiel) |
| Rollback : `gitlab.local:5050/...:previous: not found` | L'image `:previous` n'était taguée qu'en local, jamais pushée | Modification du stage `deploy_production` pour faire `docker tag` + `docker push :previous` avant le nouveau déploiement |
| 15 CVE détectées sur Django 4.2.9 | Version LTS non patchée | Mise à jour vers Django 4.2.30 |

### 6.5 Récapitulatif des fichiers livrés

- **`gitlab-infra/docker-compose.yml`** — Orchestration GitLab CE + runner local
- **`app/Dockerfile.dev`** — Image dev 1.81 GB
- **`app/Dockerfile.prod`** — Image prod 261 MB
- **`app/entrypoint.sh`** — Initialisation automatique (DB, migrations, superuser)
- **`app/requirements.txt`** — Dépendances Python
- **`.gitlab-ci.yml`** — Pipeline complet en 8 stages
- **`README.md`** — Ce document
- **`history-projet-rjrst-15-04-2026.log`** — Historique bash
- **Logs Docker** — Un fichier par conteneur principal

---

## Conclusion

Le POC répond à l'ensemble des demandes du client avec une architecture claire et automatisée. Chaque promesse est démontrable :

- **Mises à jour sans coupure** : le pipeline automatique permet de déployer en staging puis en prod en quelques minutes, sans intervention manuelle répétitive
- **CTRL+Z** : le rollback rétablit la version N-1 en moins d'une minute
- **Sauvegardes** : `backup_db` à la demande, dumps persistants hors du cycle de vie des conteneurs
- **Cybersécurité** : le scan Trivy a effectivement détecté 15 CVE lors du premier run, prouvant l'utilité immédiate de la démarche
- **Test avant prod** : staging automatique séparé de la prod manuelle, sur deux runners distincts et deux bases isolées

Le client peut donc constater que son ecommerce bénéficiera d'une chaîne de déploiement robuste, auditable et réversible.
