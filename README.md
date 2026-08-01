# Data Center Simulator
![Stars](https://img.shields.io/github/stars/BlackAngelTVdev/DataCenter-Simulator?style=for-the-badge&color=yellow)
![Commits](https://img.shields.io/github/commit-activity/m/BlackAngelTVdev/DataCenter-Simulator?style=for-the-badge&color=blue)
![Issues](https://img.shields.io/github/issues/BlackAngelTVdev/DataCenter-Simulator?style=for-the-badge&color=orange)
![Forks](https://img.shields.io/github/forks/BlackAngelTVdev/DataCenter-Simulator?style=for-the-badge&color=808080)
![Last Commit](https://img.shields.io/github/last-commit/BlackAngelTVdev/DataCenter-Simulator?style=for-the-badge&color=blue)

> **Un simulateur de gestion de data center dans ton garage : achète des serveurs d'occasion, installe des OS, refroidis la salle et fais tourner ton business.**
> *Sous le nom de code « Mes Data Centers ». Développé avec Godot 4.7 (renderer Compatibility).*

---

## Aperçu
![Menu principal](assets/images/menu_image.svg)

## Fonctionnalités

### Le garage & l'infrastructure
- **Vue de dessus isométrique** : tu contrôles un personnage (WASD / ZQSD), la caméra suit, et tu poses tes équipements à la souris (cases vertes quand c'est possible, pose à 2 cases du joueur).
- **Deux locaux, deux ambiances** :
  - **GARAGE DC-1** : ton local de départ — PC, établi, étagère, gamelle, cour de livraison. On y pose les serveurs au sol (max 4, ensuite il faut une armoire).
  - **LOCAL 2 « DATA HALL »** (à débloquer 3000 $) : PC Pro, établi 2 baies, table d'assemblage, armoires 4 slots, gestion réseau complexe (switch à ports limités, batteries). Au Data Hall, **pas de serveurs par terre** : tout passe par des armoires.
- **Se déplacer en voiture** : la voiture (dans la rue au garage, dans la salle au Data Hall) ouvre le menu des lieux — chaque local garde **son** infrastructure en mémoire, et les serveurs continuent de rapporter pendant ton absence.
- **Déco et vie du local** : climatiseurs à poser où tu veux, affiches, plantes (certaines réduisent la chaleur), néon OPEN 24/7.

### Le faux OS « BianOS » (PC des deux locaux)
- **Renard** (le navigateur) avec **deux sites** :
  - **Tech'Occase** : serveurs d'occasion, armoires, batteries, switches, clims, pare-feu, déco, locaux. Prix du **marché fluctuant** (achète bas, stocke sur l'étagère, revends haut).
  - **ServeurLab Neuf** : abonnements internet, nourriture et accessoires pour chat, et (au Data Hall uniquement) le **configurateur de serveurs neufs** — choisis RAM, processeur et disques, assemble le kit sur la table d'assemblage, puis installe l'OS.
- **Mail** : des clients t'écrivent (plaintes, demandes de dédié, félicitations), des pubs et offres arrivent aléatoirement. Certains e-mails débloquent des **contrats d'entreprise** (revenus garantis + exigences à respecter).
- **Monitor** : l'état de ta connexion en temps réel — clients en ligne, saturation de la bande passante et des serveurs, température, incidents.
- **Terminal** : quelques commandes et easter eggs.
- **Succès** : un panneau d'achievements consultable (Premier serveur, Millionnaire, Vainqueur d'un DDoS, Vu 5 chats…).
- **Fenêtres déplaçables** comme sur un vrai PC, notifications cliquables en haut à gauche.

### Économie & réalisme
- **Clients** qui se connectent à tes serveurs (selon l'OS installé et l'abonnement internet), revenus par seconde, **factures d'électricité et de connexion** déduites (consultables au bureau des factures, à côté du PC).
- **3 OS installables à l'établi** (fakes) :
  - **Deblon 12 « Bookpoule »** : serveur dédié premium (+20 % de revenus par client).
  - **Ouboutou 24.04 LTS** : dédié économe (−25 % de chaleur).
  - **Proxmousse VE 9 (PVE)** : nœud VPS — 2,5× plus de clients, mais chacun paie moins.
- **Reverse proxies** (au Data Hall) : N'Ginx (+100), H'Proxy (+300), Trafik Gate 9000 (+700 clients) — le moyen de **dépasser la limite de l'abonnement** (400 clients max).
- **Réseau réaliste au Data Hall** : chaque armoire a besoin d'un **switch** (cher !), les ports sont limités, les serveurs non branchés ne rapportent rien.
- **Température** : les serveurs chauffent, la salle monte — au-delà de **50 °C, les serveurs s'arrêtent**. Pose des clims avant qu'il ne soit trop tard.
- **Incidents** : attaques **DDoS** (bloquées par le pare-feu Forteresse) et **coupures de courant** (survécues par les armoires avec batterie UPS).
- **Usure** : les serveurs vieillissent et tombent en panne. Répare-les à l'établi (prix du marché, ~2 min, le slot est occupé — les deux baies du Data Hall te laissent continuer à travailler).
- **Partenariats** : un onglet dédié — les entreprises paient moins cher si leurs clients tournent sur tes machines partenaires.
- **Autosave** : la progression est sauvegardée automatiquement toutes les 60 s + aux moments clés.

### Vie du garage
- **Radio** sur l'établi : 3 ambiances musicales (lofi, synthwave, electro) — ajoute un fichier dans `assets/radio-garage/` et la radio le joue.
- **Chat du quartier** : verse de la nourriture dans la gamelle (5 $) pour l'adopter. Il se balade, mange, se fait caresser (un succès demande 50 000 caresses… cooldown oblige), et **utilise les accessoires que tu poses** : arbre à chat, litière, griffoir, panier.

### Confort
- **Écran de chargement** entre les scènes : barre de progression réelle + blagues serveur/OS qui défilent.
- Menu principal façon Minecraft, options (plein écran…), **Mes Sauvegardes** (plusieurs emplacements), pause (sauvegarder, quitter, ouvrir en ligne).

## Tech Stack
| Technologie | Usage |
| :--- | :--- |
| ![GDScript](https://img.shields.io/badge/GDScript-478CBF?style=flat-square) | Logique principale du jeu |
| ![Godot](https://img.shields.io/badge/Godot-4.7-478CBF?style=flat-square) | Moteur / Interface / Scènes |
| ![JSON](https://img.shields.io/badge/Sauvegarde-JSON-6BA81E?style=flat-square) | Emplacements de sauvegarde |

## Installation & Lancement

1. **Cloner le projet**
   ```bash
   git clone https://github.com/BlackAngelTVdev/DataCenter-Simulator.git
   cd DataCenter-Simulator
   ```
2. **Installer Godot 4.7**
   Téléchargez l'éditeur Godot **4.7 stable** depuis [godotengine.org](https://godotengine.org/download) et installez-le.
3. **Ouvrir le projet**
   Lancez Godot, cliquez sur **Import** puis sélectionnez le fichier `project.godot` du dossier cloné.
4. **Lancer le jeu**
   ```
   Appuyez sur F5 (ou cliquez sur Play)
   ```
   Les textures sont pré-cuites dans `assets/images/baked/` — aucun outil de régénération nécessaire.

## Utilisation

Au lancement, tu arrives sur le menu principal (**Reprendre** reprend la dernière partie, **Mes Sauvegardes**, **Options**, **Quitter**).

### Contrôles
| Action | Touche |
| :--- | :--- |
| Se déplacer | WASD / ZQSD |
| Interagir (PC, établi, livraison, voiture…) | E |
| Poser / monter l'objet porté | Clic gauche (ou E) |
| Pause (sauvegarder, quitter…) | Échap |

### Démarrage rapide
1. Au PC du garage, ouvre **Renard** → **Tech'Occase**, achète ton premier serveur d'occasion.
2. Récupère le colis à la **livraison** (E).
3. Va à l'**établi** (E) et installe un OS (Deblon = dédié premium, Ouboutou = économe, Proxmousse = VPS).
4. Pose le serveur au sol (ou dans une armoire dès que tu en as une) et regarde les clients arriver.
5. Surveille la **température** (au-delà de 50 °C tout s'arrête) et la **connexion** (saturée ? achète un meilleur abonnement).

```text
// Exemple de boucle de jeu
Acheter un serveur -> Installer un OS -> Le poser -> Clients arrivent -> Revenus $/s
                          ^                                v
              Refroidir le local (clims) <- La chaleur monte
```

## Structure du projet
```text
data/                  Catalogues de contenu (serveurs, OS, proxies, lieux, succès, shop)
scripts/core/          Sauvegarde, réglages, entrées
scripts/game/          Scène principale (garage + data hall), unités, chat, câbles
scripts/ui/            Tous les menus, panneaux et le faux OS (navigateur, mail, monitor…)
scenes/                Scènes Godot (menu, garage, data hall)
assets/images/baked/   Textures pré-cuites (plus besoin de régénérer)
assets/radio-garage/   Sons de la radio (ajoutes-en un, la radio le joue)
tests/                 Scènes de test headless (market, ddos, succès, autosave…)
```

## Contribution
1. Forkez le projet
2. Créez votre branche (git checkout -b feature/AmazingFeature)
3. Commit (git commit -m 'Add some AmazingFeature')
4. Push (git push origin feature/AmazingFeature)
5. Ouvrez une Pull Request

## Auteur

**BlackAngelTVdev**
![Follow](https://img.shields.io/github/followers/BlackAngelTVdev?label=Follow%20Me&style=social)

---
## Licence

Ce projet est sous licence :
![GitHub License](https://img.shields.io/github/license/BlackAngelTVdev/DataCenter-Simulator?style=flat-square&color=blue)

> Aucun fichier LICENSE n'est encore fourni. Contactez l'auteur avant toute utilisation commerciale.

### Contributors

Merci à toutes les personnes qui contribuent au projet.

[![Contributors](https://contrib.rocks/image?repo=BlackAngelTVdev/DataCenter-Simulator)](https://github.com/BlackAngelTVdev/DataCenter-Simulator/graphs/contributors)
