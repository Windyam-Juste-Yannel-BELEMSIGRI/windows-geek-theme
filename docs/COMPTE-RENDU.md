# Compte rendu d'intervention

Date : 2026-11-09 · Machine : Windows 11 Pro, build 26200, écran 2560x1600 · Session administrateur

## 1. Inspection initiale (lecture seule)

| Élément | Constat |
|---|---|
| Édition | Pro (stratégie de verrouillage supportée) |
| Thème | Déjà en mode sombre, transparence active |
| Polices | Cascadia Code/Mono ; aucune Nerd Font |
| WSL | WSL2 présent, seule la distro `docker-desktop` |
| PowerShell | 5.1 seulement, PSReadLine 2.0.0, pas de Terminal-Icons, aucun profil |
| Outils | git, python, VS Code, winget présents ; le reste absent |
| Restauration | Un point préexistant (« Before WinHardening ») : le durcissement antérieur n'a pas été touché |

## 2. Choix retenus

Accent vert `#00ff9c` · icônes à gauche · Debian · fond généré · projet dans `%USERPROFILE%\windows-geek-theme\`. Demandes ajoutées en cours de route : barre en haut, padding réduit, tiling avec marges, barre sobre avec icônes « nerd ».

## 3. Ce qui a été exécuté

| Étape | Statut | Détail |
|---|---|---|
| 00 Sécurité | Fait | Point de restauration `windows-geek-theme (before changes)` ; 9 clés exportées dans `backup/reg/` |
| 01 Thème | Fait | Sombre, transparence, accent `#00ff9c`, Démarrer/barre restés sombres |
| 02 Barre des tâches | Fait, 1 limite | Task View/Chat masqués, recherche en icône. Widgets : écriture protégée par Windows (voir §5) |
| 03 Paquets | Fait | 12 paquets winget (PowerShell 7 7.x, Oh My Posh, JetBrainsMono Nerd Font, zoxide, fzf, bat, eza, ripgrep, btop4win, jq, DuckDB, Wireshark + Npcap) + Sysinternals (Store) + Terminal-Icons. PSReadLine 2.4.5 déjà fourni avec PS 7 |
| 04 Profil PowerShell | Fait | Bloc géré dans les profils PS 7 et 5.1 ; prompt Oh My Posh validé (rendu OK) |
| 05 Terminal | Fait | Fragment (schéma + 3 profils acryliques 80 %) ; **défaut = SOC // PowerShell 7** |
| 06 VS Code | Fait | Thème Default Dark Modern + couleurs + police |
| 07 WSL Debian | Fait | Debian (trixie) installée, utilisateur créé ; apt : curl, git, fzf, bat, ripgrep, jq, zoxide, eza ; oh-my-posh (release GitHub) + bloc `~/.bashrc` |
| 08 Fond d'écran | Fait | PNG 3840x2160 généré et appliqué |
| 09 Verrouillage | Refait | Première version (stratégie HKLM) **inefficace sur Pro** et Windows Spotlight actif → remplacée par l'API par utilisateur `SetImageFileAsync` ; Spotlight désactivé pour l'écran de verrouillage ; stratégie HKLM retirée |
| 11 Lanceur | Fait | `win+d` (et `alt+d`) : lanceur fzf façon wofi (apps, `>cmd`, `?web`), fenêtre flottante centrée |
| 10 Tiling + barre | Fait | GlazeWM + Zebar installés et configurés, barre native masquée, démarrage automatique à l'ouverture de session |

Journal : 20 valeurs de registre, 12 fichiers, 2 blocs de profil, 14 paquets.

## 4. Barre des tâches en haut : ce qui est possible

- **Déplacer la barre native en haut / réduire son padding** : impossible proprement sur Windows 11 (option supprimée). Seuls Windhawk ou ExplorerPatcher le permettent, en s'injectant dans `explorer.exe`, ce qui revient à patcher le système : refusé par tes règles, donc non utilisé.
- **Solution livrée** : la barre native est masquée automatiquement (API officielle) et remplacée par une barre Zebar flottante en haut, plus fine (36 px), avec icônes Nerd Font.
- **Tiling** : GlazeWM, marges de 12 px entre fenêtres et vers les bords, 54 px en haut pour la barre ; les fenêtres en plein écran n'ont pas de marge.
- Vérifié par capture d'écran en pleine résolution : barre visible, 4 fenêtres tilées avec espaces, bordure verte sur la fenêtre active, éléments réseau/RAM/CPU/batterie affichés.

## 5. Problèmes rencontrés et corrigés

1. Étape 00 : `reg query` sur clé absente levait une erreur fatale → `Test-Path` avant export. Le garde-fou a bloqué tout le reste tant que la sauvegarde n'était pas valide.
2. Étape 08 : variable `$path` en collision avec le paramètre `$Path` (insensibilité à la casse) → renommée.
3. **Sysinternals** : échec winget sur le hash du ZIP (code -1978335215). Hash **non contourné** ; installation via le Microsoft Store officiel.
4. Étape 09 : le script annonçait « Widgets disabled by policy » alors que l'écriture avait été refusée → message corrigé. La clé `HKLM\...\Policies\Microsoft\Dsh` est protégée sur cette machine (probablement par le durcissement antérieur), **non forcée**.
5. Détection de la Nerd Font trop stricte (faux avertissement) → corrigée.
6. Zebar : l'identifiant de pack local est `windows-geek-theme`, sans préfixe `local.` → corrigé après lecture des journaux.
7. Profil PowerShell : erreurs bénignes (`btop4win` introuvable) → `-ErrorAction Ignore`.

## 5b. Corrections après retour utilisateur

1. **Fond d'écran rogné** : image 3840x2160 (16:9) sur écran 2560x1600 (16:10), le mode Remplir coupait les bords et les coins HUD. Régénéré à la résolution exacte de l'écran, marges proportionnelles.
2. **Écran de verrouillage inchangé** : erreur de ma part, la stratégie `LockScreenImage` n'est pas honorée sur Pro, et Spotlight était actif. Corrigé (voir étape 09).
3. **Lanceur** : premier test en échec car GlazeWM, démarré avant l'installation de fzf, avait un `PATH` périmé ; le script relit maintenant le `PATH` depuis le registre. Le test a aussi montré qu'`Start-Process -ArgumentList` ne met pas de guillemets automatiquement (problème de mon test, pas du raccourci).

## 5c. Réglages demandés ensuite

- **Focus au survol** : `focus_follows_cursor: true`.
- **Lanceur sur `win+d`** : testé avec des frappes réalistes (le lanceur s'ouvre). `win+d` remplace « Afficher le bureau » tant que GlazeWM tourne ; `alt+d` reste en secours. Test physique au clavier à faire par l'utilisateur.

## 5d. Apps hors tiling (WhatsApp, Claude)

Diagnostic : `glazewm query windows` ne listait que 2 fenêtres ; WhatsApp et Claude étaient `cloaked=2` (cachées par le shell : autre bureau virtuel, l'utilisateur en avait 4). Après rapatriement sur un seul bureau (étape 12, choix validé), elles sont apparues avec l'état `fullscreen` (taille exacte de l'écran). Correction : règle `set-tiling` à la création de chaque fenêtre. Résultat vérifié : 5 fenêtres gérées, toutes en `tiling`, à l'intérieur des marges.

Le test de `win+d` avec frappes simulées ouvre le lanceur en ~1 s sans menu Démarrer ; le cas d'une pression non maintenue (Win puis D séparément) ouvre le menu Démarrer, comportement Windows normal.

## 5e. Tremblement de Chrome

- **Chrome qui « tremble »** : mesure à chaud, 2 changements de taille en 40 ms (taille mémorisée de Chrome, puis tiling). Comportement attendu d'un tiling WM ; un démarrage à froid avec plusieurs fenêtres restaurées peut en produire plusieurs.

## 5f. Intervention du 2026-11-10 : verre, animation, démarrage

| Demande | Ce qui a été fait | Vérification |
|---|---|---|
| Fenêtres translucides / glass | Opacité native via GlazeWM : 93 % (active), 86 % (autres). `alt+shift+o` / `alt+shift+g` pour la fenêtre active | Alpha lu sur la fenêtre : 237/255. Capture : le fond et le HUD se voient à travers |
| Flou généralisé | **Non fait, volontairement** : impossible sans injection dans DWM ou dans chaque processus. Seules les apps qui le gèrent elles-mêmes sont floutées (Terminal en acrylique) | — |
| Animation du portfolio | Graphe réseau (nœuds, liens, paquets) porté depuis le script du hero : widget `hud` sous les fenêtres + bandeau dans la barre. Carte `status.json` en direct, texte tapé à la machine, point « pulse », curseur clignotant | Captures sur workspace vide et occupé ; deux images successives diffèrent |
| Design de la barre | Logo `~/yannel▌`, fenêtre active, débits réseau, sparklines CPU/RAM, apparition échelonnée, rendu sans reconstruction du DOM | Capture en pleine résolution |
| Lenteur au démarrage | Cause mesurée : GlazeWM lancé par la clé `Run` **43 s** après Explorer (22:29:57 → 22:30:40). Remplacé par une tâche planifiée à l'ouverture de session (+2 s). Bibliothèque Zebar servie en local au lieu d'`esm.sh` | Tâche exécutée à la main : code 0, GlazeWM et Zebar non élevés. **Le gain réel reste à constater au prochain redémarrage** |

Problèmes rencontrés :

1. **Erreur 740 dans la tâche planifiée** : `glazewm.exe` est un binaire `uiAccess`, que `CreateProcess` refuse de lancer. Passage par `ShellExec_RunDLL`.
2. **Coût de la première version de l'animation** : 87 % d'un cœur (boucle à la fréquence de l'écran, `box-shadow` animé, canevas en pixels physiques). Après correction : 18 % d'un cœur, soit 0,6 % de la machine.
3. **Variable `$script:` vide dans les étapes** : les étapes s'exécutent dans une portée enfant de `install.ps1` ; remplacée par une fonction.
4. Le script `boot-priority.ps1` (baisse de priorité des apps lourdes pendant 180 s) est retiré : il démarrait lui aussi par la clé `Run`, donc après les applications qu'il devait ralentir. Les priorités de lancement restent posées par `set-geek-admin-priority.ps1`.
5. Lancer GlazeWM une seconde fois affiche une boîte « Fatal error » : il ne faut donc qu'un seul mécanisme de démarrage (la tâche), pas de doublon dans la clé `Run`.

## 5g. Suite du 2026-11-10 : verrouillage, geste, vérification des applications

- **Écran de verrouillage / connexion** : image régénérée avec une image fixe du graphe réseau et un prompt `$ whoami` ; flou de l'écran de connexion retiré par stratégie. Image posée et stratégie écrite, **rendu à vérifier avec `Win+L`**.
- **Balayage à quatre doigts** : il pilotait les bureaux virtuels Windows, pas les workspaces GlazeWM. Raccourcis `ctrl+alt+droite/gauche` ajoutés (testés : 1 → 2 → 1) ; l'association au geste se fait dans les Paramètres (voir README), Windows ne documentant aucune valeur de registre pour les raccourcis personnalisés.
- **Logo de la barre** : `~/windyam yannel`.
- **Ouverture des applications** : Bloc-notes, Explorateur, Calculatrice, Paramètres, Paint, Terminal, VS Code et Gestionnaire des tâches (élevé) ouverts sur un workspace vide. Les 8 sont gérées en `tiling`, dans les marges, sous la barre, avec l'opacité 93 %. Le lanceur s'ouvre flottant et centré (900x520).

## 6. Ce qu'il te reste à faire

1. **Se déconnecter/reconnecter** : couleur d'accent et alignement de la barre des tâches.
2. **Écran de verrouillage** : `Win+L` pour vérifier l'image ; sur l'écran de connexion, seule l'image est personnalisable (limite assumée).
3. **Widgets natifs** (optionnel) : à désactiver à la main dans Paramètres > Personnalisation > Barre des tâches.
4. **Associer le balayage à quatre doigts** aux raccourcis `ctrl+alt+droite/gauche` dans les Paramètres (README, « Balayage à quatre doigts »).
5. **Redémarrer une fois** pour constater le nouveau temps de lancement. Si la barre n'apparaît pas : lancer GlazeWM depuis le menu Démarrer, puis regarder l'historique de la tâche `\windows-geek-theme\GlazeWM` dans le Planificateur de tâches.

## 7. Raccourcis GlazeWM à connaître

`alt+h/j/k/l` focus · `alt+shift+h/j/k/l` déplacer · `alt+1..9` workspaces · `alt+f` plein écran · `alt+shift+space` flottant · `alt+enter` Terminal · **`alt+shift+p` pause · `alt+shift+e` quitter** (liste complète : README et `config/glazewm/config.yaml`).

## 8. Annuler

`powershell -ExecutionPolicy Bypass -File .\revert.ps1` : arrête GlazeWM/Zebar, rend la barre native, restaure registre et fichiers. Paquets conservés par défaut (`-RemovePackages` pour les retirer) ; Debian jamais supprimée automatiquement. Filet de secours : point de restauration + `backup/reg/*.reg`.
