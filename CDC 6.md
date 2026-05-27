# 🛡️ CAHIER DES CHARGES TECHNIQUE & FONCTIONNEL
## Module Odoo 19 — Gestion du Gardiennage (`guard_security`)

**Version :** 6.6a-rev15 — Mise à jour §2.22 codes vacation avec structure complète KINGS-MRT (25 codes, 5 catégories, coefficients TST)
**Plateforme :** Odoo 19 Community / Odoo.sh
**Environnement POC :** GitHub Codespaces (Branche `dev-pure`)
**Client final :** KINGS-MRT, Nouakchott, Mauritanie
**Date :** 21 mai 2026

---

## 1. Contexte, Objectifs et Évolutivité Mobile

### 1.1 Présentation de l'entreprise
KINGS-MRT est une société de gardiennage opérant en Mauritanie, gérant plus de **570 agents de sécurité** déployés sur plusieurs dizaines de sites clients. La gestion actuelle repose sur des fichiers Excel, ce qui engendre des risques d'erreurs, des lourdeurs de saisie et un manque d'auditabilité.

### 1.2 Objectif du projet (Phase 1 — POC)
Développer un module Odoo 19 custom (`guard_security`) pour centraliser la planification et le pointage au bureau, en mettant l'accent sur une ergonomie **"PC First"** pour une saisie de masse ultra-rapide.

### 1.3 Évolutivité Mobile et Architecture Robuste (Impératif)
Bien que la Phase 1 soit concentrée sur l'interface PC pour les équipes de bureau, l'architecture backend doit être conçue dès le départ de manière robuste et ouverte. Les modèles, services et contrôleurs de données devront préparer techniquement le terrain pour l'intégration transparente des phases futures :

- L'application mobile **"Kiosk"** sur tablette/smartphone d'entreprise.
- Le **pointage mobile automatisé** par les superviseurs sur le terrain.
- Le **signalement des incidents en temps réel** avec synchronisation immédiate sur le tableau de bord opérateur.

### 1.4 Exigences concrètes Phase 2 mobile (à implémenter dès Phase 1)
Pour éviter toute refonte backend lors de la Phase 2, les développeurs implémenteront dès maintenant :

- **Méthode `to_dict()`** sur tous les modèles métier (`sec.site`, `sec.poste`, `sec.planning_ligne`, `sec.pointage`, `sec.planning_periode`) pour une sérialisation JSON propre et stable.
- **Contrôleurs Odoo `@http.route`** exposant des endpoints versionnés sous `/api/v1/` (ex : `/api/v1/sites`, `/api/v1/pointages`, `/api/v1/agents`, `/api/v1/incidents`).
- **Authentification par token Bearer** (pas seulement par session web), pour permettre l'auth depuis une app mobile.
- **Champ `external_id` (UUID)** sur `sec.pointage` et `sec.incident` (modèle Phase 2) pour permettre la **synchro offline-first** : le mobile crée des enregistrements avec un UUID local, le serveur les déduplique côté backend lors du push.
- **Documentation OpenAPI/Swagger** des endpoints exposés.

---

## 2. Architecture de Données & Modèles Métier

### 2.1 Modèles existants réutilisés (Zéro champ custom inutile)
- **`hr.employee`** : L'agent (Matricule via `barcode`, Nom, Fonction via `job_id`).
- **`res.partner`** : L'entité Client (Société).
- **`hr.job`** : La qualification du poste (ex : ADS, Superviseur, CPO).

### 2.2 Extension Agent & Sécurité d'Affectation (`hr.employee`)
Ajout d'un onglet dédié au **Gardiennage** incluant :

- **Restrictions d'affectation (Sites interdits)** : Champ Many2Many `site_interdit_ids` représenté sous forme de tags rouges. Il liste les sites où l'agent ne doit jamais être déployé (demande du client, sanction, incompatibilité).
- **Statut Flotteur structurel** *(nouveau)* : Champ booléen `is_flotteur` + champ Many2one `brigade_flotteur_id` indiquant que l'agent est rattaché comme flotteur à une brigade donnée. **Indépendant** du tag de statut posé ponctuellement sur `sec.planning_ligne` (cf §2.5).
- **Verrou de sécurité** : Toute tentative de planification ou d'affectation d'un agent sur un site interdit déclenchera immédiatement un blocage serveur.
- **Compteurs de la période** : Calculés à la volée (TST, C, RM, A, P, MP), reflétant le **réalisé** (issu de `sec.pointage`), pas le prévisionnel.

### 2.3 Modèle `sec.poste_type` *(nouveau — refactorisation v6.6a-rev10)*

Référentiel des **types de postes** (rôles/qualifications).

**Champs :**
- `code` : Code unique (ex : `ADS`, `SUP`, `CP`, `DVN`, etc.)
- `name` : Libellé (ex : `Agent de Sécurité`, `Superviseur`, `Chef de Poste`)
- `job_id` : Lien vers `hr.job` pour compatibilité RH
- `description` : Détail du rôle
- `is_active` : Booléen (statut actif/inactif)

**Données de référence :**
Géré administrateur. Exemples typiques : ADS (Agent de Sécurité), SUP (Superviseur), CP (Chef de Poste), DVN (Directeur de Nuit).

---

### 2.4 Modèle `sec.shift_pattern` *(nouveau — refactorisation v6.6a-rev10)*

Référentiel des **patterns de travail** (horaires, rotations, fréquences).

**Champs :**
- `code` : Code unique (ex : `H24-S12-7/7`, `H12-S12-5/7`, `H8-S12-7/7`)
- `name` : Libellé lisible (ex : `24h/jour, shift 12h, 7j/7`)
- `total_hours_per_cycle` : Total d'heures dans le cycle (ex : 24 pour H24, 12 pour H12)
- `shift_duration_hours` : Durée d'un shift en heures (8, 12)
- `days_per_week` : Fréquence par semaine (5 ou 7)
- `cycle_days` : Nombre de jours du cycle (ex : 12 pour S12)
- `composition_template` : Structure JSON décrivant la composition jour-par-jour (ex : `{lun: {J:1, N:1}, ..., dim: {J:1, N:1}}`)
- `nb_agents_required` : Nombre d'agents requis (calculé automatiquement)
- `is_active` : Booléen

**Données de référence (8 patterns KINGS-MRT) :**

| Code | Nom | Heures/cycle | Shift | Jours/sem | Cycle | Agents requis |
|------|-----|------|-------|-----------|-------|-----|
| `H24-S12-7/7` | 24h/jour, 12h, 7j/7 | 24 | 12 | 7 | 12 | 3 |
| `H12-S12-7/7-J` | 12h Jour, 7j/7 | 12 | 12 | 7 | 12 | 2 |
| `H12-S12-7/7-N` | 12h Nuit, 7j/7 | 12 | 12 | 7 | 12 | 2 |
| `H12-S12-5/7-J` | 12h Jour, 5j/7 | 12 | 12 | 5 | 12 | 1 |
| `H12-S12-5/7-N` | 12h Nuit, 5j/7 | 12 | 12 | 5 | 12 | 2 |
| `H24-S8-7/7` | 24h/jour, 8h, 7j/7 | 24 | 8 | 7 | 8 | 4 |
| `H8-S8-5/7-J` | 8h Jour, 5j/7 | 8 | 8 | 5 | 12 | 1 |
| `H8-S8-5/7-N` | 8h Nuit, 5j/7 | 8 | 8 | 5 | 12 | 2 |

---

### 2.5 Modèle `sec.site`

Représente les lieux géographiques à sécuriser.

**Champs :**
- Code unique (ex : `AFD1`), Nom, Client associé (`res.partner`), Ville, Zone géographique, Brigade
- Géolocalisation (latitude, longitude)
- Statut (Actif / Suspendu / Fermé)
- **Type de période comptable** : sélection entre `"Période glissante 24→23"` (par défaut) ou `"Mois civil 1→31"`
- **`is_centrale`** *(booléen)* : marque un site comme étant la Centrale (pool interne de réserve). Cf §2.13.
- **`is_facturable`** *(booléen, défaut True)* : indique si le site est facturable au client. Mis à `False` pour la Centrale. Utilisé par l'export "Audit Client" (§6.2) pour exclure les sites internes des facturations clients.

---

### 2.6 Modèle `sec.poste` *(refactorisé v6.6a-rev10)*

Définit l'**affectation d'un type de poste avec un pattern de travail sur un site spécifique**.

**Champs :**
- `site_id` — Lien Many2one vers `sec.site` (chaque site peut avoir plusieurs postes)
- `poste_type_id` — Lien Many2one vers `sec.poste_type` (ex : ADS, SUP, CP)
- `shift_pattern_id` — Lien Many2one vers `sec.shift_pattern` (ex : H24-S12-7/7)
- `nb_agents_required` — Nombre d'agents requis (dénormalisé depuis `shift_pattern_id.nb_agents_required` pour rapidité)
- `is_active` — Booléen (statut actif/inactif)
- `notes` — Champ texte libre pour conditions spéciales (ex : "Double équipe mardis", "Formation obligatoire")

**Exemple :**
- Site: AFD1, Type: ADS, Pattern: H24-S12-7/7 → requiert 3 agents en rotation (1 Jour, 1 Nuit, 1 remplaçant)

---

### 2.7 Modèle `sec.planning_ligne`
L'enregistrement des **affectations prévisionnelles journalières**.

**Champs :**
- Agent (`hr.employee`), Site (`sec.site`), Date, Code vacation (référence à `sec.code_vacation`, cf §2.8)
- **`job_id_snapshot`** : Copie dénormalisée du `job_id` de l'agent au moment de la création de la ligne. Permet l'audit historique même si l'agent change de fonction en cours de période.
- **Tag de Statut** : indicateur coloré + icône définissant le statut de l'agent sur ce poste :
  - **Fixe** (Vert, icône 📌) — affectation pérenne
  - **Remplaçant** (Orange, icône 🔄) — remplacement ponctuel
  - **Flotteur** (Bleu, icône 🌊) — agent volant de réserve appelé en renfort (typiquement issu de la Centrale après redéploiement)
- **`redeploiement_actif_id`** *(nouveau — Many2one `sec.redeploiement_log`, optionnel)* : si renseigné, indique que cette ligne planning a été **redéployée vers un autre site** (lien vers le journal qui contient tous les détails). La ligne reste intacte côté Centrale (la planification d'origine est préservée pour audit) mais elle n'est plus comptée pour la couverture Centrale du jour (cf §2.13).
- Lien vers `sec.planning_periode` pour gestion du cycle de vie.

➡️ La gestion des redéploiements se fait via un **modèle dédié** `sec.redeploiement_log` (cf §2.14), pas par modification destructive de cette ligne. Cela préserve l'historique de la planification originale et facilite le reporting.

### 2.8 Modèle `sec.planning_periode`
Gère le **cycle de vie** d'une période de planning par site.

**Champs :**
- `site_id` (Many2one `sec.site`)
- `date_debut`, `date_fin` (calculées selon le type de période du site)
- `state` : sélection (`draft` → `open` → `closed` → `exported`)
- `export_user_id`, `export_date` : audit de l'export Sage
- `reopen_reason` : motif obligatoire en cas de réouverture après clôture (audité via chatter)

**Règles serveur :**
- Une période en état `closed` ou `exported` interdit toute modification de `sec.planning_ligne` et `sec.pointage` rattachés (sauf utilisateur du groupe **Administrateur**, avec motif).
- La transition `exported → draft` n'existe pas ; seul un retour à `open` est possible, et reste tracé.

### 2.9 Modèle `sec.pointage`
Enregistrement de la **présence réelle**, historisé pour l'auditabilité.

**Champs :**
- Agent, Site, Date, Heure d'arrivée (optionnel Phase 1, automatisé Phase 2 Kiosk)
- **`code_planifie`** : copie du code de `sec.planning_ligne` au moment du pointage (lecture seule, dénormalisé pour audit)
- **`code_realise`** : code effectivement constaté par l'opérateur (J, N, A, RM, C, P, MP)
- `external_id` (UUID) pour synchro mobile offline-first
- Chatter natif Odoo activé (audit trail intégré : qui a modifié, quand, depuis quel terminal)

**Règle de synchronisation pointage → planning :**
Quand `code_realise` diffère du `code_planifie`, le système **écrase la case planning** correspondante avec le code réalisé. L'audit trail natif d'Odoo (`mail.thread`) conserve l'historique complet de la valeur précédente — garantissant la traçabilité sans complexifier l'UI.

### 2.10 Modèle `sec.code_vacation` *(refondu v6.6 — référentiel complet KINGS-MRT)*
Référentiel **configurable par l'admin** des codes de vacation. Source : référentiel officiel KINGS-MRT remis par la Direction (image annexe). **25 codes** chargés en données initiales.

**Champs :**
- `code` — identifiant court (ex : `J`, `N`, `S`, `EJ`, `EN`, `REMPL,C`, `REMPL,PIP`...)
- `libelle` — nom long (ex : "Shift Jour")
- `couleur_bg` — couleur de fond du badge (hex)
- `couleur_fg` — couleur du texte du badge (hex)
- `icone` — symbole d'accessibilité daltonienne (optionnel)
- `heures` (décimal) — durée comptable (12.0 pour J/N S12, 8.0 pour J/S/N S8, 6.0 pour EJ/EN, 0.0 pour absences)
- `est_travaille` (booléen) — compte dans le TST ?
- `est_remunere` (booléen) — apparaît dans l'export Sage Paie ?
- `est_facturable` (booléen) — apparaît dans l'export Audit Client ?
- `categorie` : sélection (`travail`, `travail_partiel`, `repos`, `absence_justifiee`, `absence_non_justifiee`, `sanction`, `etat_site`, `etat_rh`, `mouvement`)
- **`is_actif`** *(nouveau — booléen, défaut True)* — détermine si le code apparaît dans la grille de saisie. L'admin peut désactiver des codes peu utilisés sans les supprimer, pour alléger l'UI. Les codes désactivés restent visibles dans les données historiques.

**Référentiel des 25 codes (chargés via `data/code_vacation_data.xml`) :**

| Code | Libellé | BG | FG | Heures | Trav. | Rém. | Fact. | Catégorie |
|------|---------|-----|-----|--------|-------|------|-------|-----------|
| **J** | Shift Jour | #2ECC71 vert | #FFF | 12.0 | ✓ | ✓ | ✓ | travail |
| **N** | Shift Nuit | #F39C12 orange | #FFF | 12.0 | ✓ | ✓ | ✓ | travail |
| **S** | Shift Soir | #D35400 orange foncé | #FFF | 8.0 | ✓ | ✓ | ✓ | travail |
| **EJ** | Demi shift Jour | #FAD7A0 beige | #6E2C00 | 6.0 | ✓ | ✓ | ✓ | travail_partiel |
| **EN** | Demi shift Nuit | #FAD7A0 beige | #6E2C00 | 6.0 | ✓ | ✓ | ✓ | travail_partiel |
| **P** | Permission | #AED6F1 bleu clair | #1B4F72 | 0.0 | ✗ | ✓ | ✗ | absence_justifiee |
| **PL** | Permission légale | #1F618D bleu foncé | #FFF | 0.0 | ✗ | ✓ | ✗ | absence_justifiee |
| **RM** | Repos médical | #5DADE2 bleu cyan | #FFF | 0.0 | ✗ | ✓ | ✗ | absence_justifiee |
| **A** | Absent | #E74C3C rouge | #FFF | 0.0 | ✗ | ✗ | ✗ | absence_non_justifiee |
| **JE** | Jour + HS | #F9E79F jaune pâle | #6E5A0F | 12.0 | ✓ | ✓ | ✓ | travail |
| **SE** | Soir + HS | #F5B7B1 saumon | #6E2C00 | 8.0 | ✓ | ✓ | ✓ | travail |
| **PF** | Poste Fermé | #BB8FCE mauve | #FFF | 0.0 | ✗ | ✗ | ✗ | etat_site |
| **PS** | Poste Suspendu | #BB8FCE mauve | #FFF | 0.0 | ✗ | ✗ | ✗ | etat_site |
| **MP** | Mise à pied | #7D6608 ocre | #FFF | 0.0 | ✗ | ✗ | ✗ | sanction |
| **AT** | Arrêt de travail | #A04000 brun | #FFF | 0.0 | ✗ | ✗ | ✗ | sanction |
| **C** | Congé | #F4D03F jaune | #6E5A0F | 0.0 | ✗ | ✓ | ✗ | repos |
| **L** | Licencié | #E74C3C rouge | #FFF | 0.0 | ✗ | ✗ | ✗ | etat_rh |
| **D** | Démission | #C0392B rouge | #FFF | 0.0 | ✗ | ✗ | ✗ | etat_rh |
| **CSP** | Changement site planifié | #BDC3C7 gris | #2C3E50 | 0.0 | ✗ | ✗ | ✗ | mouvement |
| **CF** | Confinement | #BDC3C7 gris | #2C3E50 | 0.0 | ✗ | ✓ | ✗ | absence_justifiee |
| **MS** | Mission | #ABEBC6 vert clair | #145A32 | 12.0 | ✓ | ✓ | ✗ | travail |
| **SB** | Stand by | #FCF3CF jaune clair | #7D6608 | 0.0 | ✗ | ✓ | ✗ | repos |
| **AP** | Abandon poste | #C0392B rouge foncé | #FFF | 0.0 | ✗ | ✗ | ✗ | absence_non_justifiee |
| **F** | Formation | #1B2631 noir | #FFF | 8.0 | ✓ | ✓ | ✗ | travail |
| **REMPL,C** | Remplacement de congé | #BDC3C7 gris | #2C3E50 | 0.0 | ✗ | ✗ | ✗ | mouvement |
| **REMPL,PIP** | Remplacement pipeline (site eau) | #BDC3C7 gris | #2C3E50 | 0.0 | ✗ | ✗ | ✗ | mouvement |
| **M** | Malade sur site | #E74C3C rouge | #FFF | 0.0 | ✗ | ✗ | ✗ | absence_non_justifiee |

**Notes métier sur certains codes :**
- **`PF` / `PS`** *(état du site)* : pour la Phase 1 (décision Q3 = γ), ces codes restent **saisissables case par case** dans la grille comme tous les autres. L'opérateur les pose manuellement quand un site est fermé/suspendu un jour donné. Une **action de masse** "Appliquer PF/PS sur une période complète d'un site" sera ajoutée en Phase 2 si l'usage le justifie.
- **`REMPL,PIP`** : `PIP` désigne les **stations de contrôle de pipeline d'eau**, sites particuliers nécessitant un type de remplacement spécifique (à distinguer dans le reporting des autres remplacements).
- **`L` / `D`** *(état RH terminal)* : un agent en `L` (Licencié) ou `D` (Démission) ne devrait normalement plus apparaître dans les plannings futurs. Une **règle de validation** doit alerter le planificateur s'il tente de planifier un agent dans cet état (cf §3.5 verrous serveurs à enrichir).
- **`AT` Arrêt de travail (sens KINGS-MRT spécifique)** : ⚠️ **À ne pas confondre avec un arrêt maladie** (qui est codé `RM`). `AT` est un **statut RH suspensif** déclenché quand un agent **ne se présente pas à son poste pendant un nombre de jours consécutifs paramétrable** (défaut KINGS-MRT : 2 jours), **sans donner signe de vie** (ni certificat médical, ni demande de permission, ni démission formalisée). Les premiers jours sont notés `A` (Absent) ; à partir du jour-seuil + 1, l'agent bascule en `AT`. Non rémunéré, non facturable, classé en sanction. Sa résolution nécessite une **décision RH explicite** (réintégration, licenciement `L`, ou démission constatée `D`). Le mécanisme de détection automatique est décrit en §2.15.
- **`MP` Mise à pied** : sanction disciplinaire formelle (décision RH). À distinguer du `AT` qui est un constat d'absence prolongée non justifiée.
- **`AP` / `M`** *(absences non justifiées)* : `AP` (Abandon poste) et `M` (Malade sur site sans justificatif fourni) sont classés en absences non justifiées : ni rémunérées, ni facturables. Un agent constaté `M` sur site sans justificatif médical ultérieur reste en `M` (s'il fournit un certificat dans les délais, le code peut être corrigé en `RM` par l'admin, avec audit trail).
- **Codes "HS" (`JE`, `SE`)** : les heures supplémentaires sont traitées en Phase 1 comme des codes plats indépendants (Q2 = α). Une modélisation fine avec modificateur viendra en Phase 2 si nécessaire.
- **`MS` Mission ajustée à 12h** : conformément au choix Direction v6.6, une journée de mission compte pour 12h travaillées (et non 8h comme en première version), alignée sur la durée d'un shift Jour standard.

### 2.11 Modèle `sec.mass_pointage_log` *(nouveau)*
Journal léger des opérations de pointage en masse (cf §4.4), pour audit et reporting des pratiques.

**Champs :**
- `operator_id` (Many2one `res.users`) — qui a déclenché l'opération
- `date_operation` (Datetime) — horodatage précis
- `site_id` (Many2one `sec.site`) — périmètre concerné (toujours un seul site)
- `date_pointage` (Date) — jour pointé
- `nb_agents_concernes` (Integer) — nombre de pointages générés en lot
- `pointage_ids` (One2many vers `sec.pointage`) — pour traçabilité ascendante

**Vue dédiée** (accès Administrateur) : `Reporting → Opérations de pointage en masse`, filtrable par opérateur / site / période. Utile pour identifier les opérateurs qui pointent toujours "Tout présent" sans vérification réelle (signal de risque).

### 2.12 Règle métier : Date comptable d'un shift *(nouveau — règle structurante)*

**Convention** : pour toute vacation, **la date comptable correspond à la date de prise de poste**, pas à la date de fin de poste.

**Exemples concrets :**
- Shift Jour `J` du 27 mai (07h → 19h) → `sec.pointage.date = 27 mai`. Trivial.
- Shift Nuit `N` du 27 mai (19h → 07h le 28) → `sec.pointage.date = 27 mai` (et **non** le 28, malgré le franchissement de minuit).

**Conséquences techniques à implémenter strictement :**
- Le calcul de la couverture jour-par-jour (cf §3.5) considère qu'un `N` posé sur la colonne du 27 couvre la nuit du 27 au 28.
- L'écran Pointage bureau du 28 mai matin n'affiche **pas** les shifts de nuit du 27→28 (ils sont déjà rattachés au 27).
- Le verrou anti-doublon (cf §3.5) interdit un même agent sur deux sites au 27 même si l'un est `J` (07→19) et l'autre `N` (19→07). Ces deux vacations partagent la date comptable 27.
- L'export Sage Paie agrège par date comptable : la rémunération du shift de nuit du 27→28 apparaît sur le 27.

**Pourquoi ce choix :** convention standard du gardiennage français et africain francophone, alignée avec les pratiques métier de KINGS-MRT. Évite les ambiguïtés de l'export paie (un shift = un jour de comptabilité, pas deux).

### 2.13 Modèle `sec.dashboard_view` *(nouveau)*

Stocke les **préférences personnalisées** d'affichage du dashboard par utilisateur (widgets visibles, ordre, filtres mémorisés).

**Champs :**
- `user_id` (Many2one `res.users`, unique)
- `dashboard_type` : sélection (`accueil_direction`, `accueil_planificateur`, `accueil_operateur`, `accueil_superviseur`)
- `widgets_config` (JSON) : structure `[{id, visible, order, filters}]` pour chaque widget du dashboard
- `default_period` : sélection (`today`, `week`, `month`) — période par défaut des KPI

Un dashboard par défaut est fourni par profil. L'utilisateur peut masquer ou réordonner les widgets ; sa configuration est persistante.

### 2.14 Modèle `sec.incident` *(nouveau — amorcé Phase 1, exploité Phase 2)*

Représente un événement terrain méritant signalement, catégorisé pour reporting. Saisie via le Dashboard opérateurs en Phase 1 ; saisie mobile par les superviseurs terrain en Phase 2.

**Champs :**
- `site_id` (Many2one `sec.site`)
- `agent_id` (Many2one `hr.employee`, optionnel — incident peut être lié au site sans agent identifié)
- `date_incident` (Datetime)
- `type_incident` : sélection (`intrusion`, `agression`, `degats_materiels`, `manquement_agent`, `conflit_client`, `medical`, `autre`)
- `severite` : sélection (`info`, `mineur`, `majeur`, `critique`)
- `description` (Text)
- `reporter_id` (Many2one `res.users`) — qui a saisi
- `external_id` (UUID) — pour synchro mobile offline-first Phase 2
- `pieces_jointes` (Attachments Odoo natifs — photos, rapports)
- `statut` : sélection (`ouvert`, `en_traitement`, `clos`)
- Chatter natif Odoo activé (audit trail intégré, commentaires).

**Phase 1 :** saisie depuis le Dashboard opérateurs (cf §3.9) et depuis la fiche d'un site. Vue liste filtrable. Pas de workflow avancé.

**Phase 2 :** saisie mobile par superviseurs avec géolocalisation, photo, push temps réel via bus.bus, notification au planificateur de garde.

### 2.15 La Centrale : pool interne de réserve *(refondu v6.5)*

KINGS-MRT maintient en permanence un **pool d'agents en réserve** appelé la **Centrale**. Ces agents sont payés comme s'ils étaient sur un site client, mais leur rôle est de constituer une force de réaction immédiate pour combler les défaillances de dernière minute sur le terrain (agent malade, retard, no-show).

**Caractéristiques techniques :**
- La Centrale est représentée comme un **site `sec.site` particulier** :
  - `is_centrale = True` (un seul enregistrement de ce type dans la base — vérifié par contrainte SQL unique)
  - `is_facturable = False` (jamais facturée à un client, c'est un coût interne KINGS-MRT)
  - `partner_id` = KINGS-MRT (la société est cliente d'elle-même)
- Elle a une `sec.poste` configurée avec **composition différenciée semaine / week-end** (paramétrable par l'admin) :
  - Semaine (Lun-Ven) : **6 ADS Jour + 6 ADS Nuit** par défaut
  - Week-end (Sam-Dim) : **8 ADS Jour + 8 ADS Nuit** par défaut
- Les agents y sont planifiés comme sur tout autre site (J ou N), via la grille standard.

**Contrôle de couverture strict — identique aux sites clients** *(décision Q4 validée)* :
- Le contrôle de couverture ✓/⚠️/✖ jour-par-jour (§3.5) s'applique à la Centrale comme à tout autre site, en se basant sur la composition semaine/week-end.
- Quand un agent Centrale est redéployé via `sec.redeploiement_log` (cf §2.14), **sa ligne `sec.planning_ligne` Centrale ne compte plus pour la couverture Centrale du jour** *(décision Q-bis-2 validée — option δ)*. La Centrale apparaît donc en sous-effectif si elle n'est pas reconstituée.
- Conséquence pratique : chaque redéploiement crée mécaniquement un découvert Centrale (passage du compteur 6/6 à 5/6, puis 4/6...). Le planificateur voit en temps réel l'érosion du pool dans le widget d'alertes.
- **Alerte spéciale "Centrale vide"** : cas particulier du contrôle standard, déclenchée quand 100% du pool d'un shift (J ou N) a été redéployé. Remontée en priorité maximale dans le bandeau d'alertes Direction et Planificateur. Signifie : *plus aucune capacité de réaction immédiate*.

**Mécanique du redéploiement (vue d'ensemble — détails §2.14 et §4.5) :**
- Quand un agent défaille sur un site client, l'opérateur déclenche un redéploiement depuis l'écran Pointage bureau.
- Le système crée un enregistrement `sec.redeploiement_log` qui lie : la ligne planning Centrale d'origine, le site cible, l'opérateur, l'horodatage, le motif.
- La `sec.planning_ligne` Centrale reçoit le lien `redeploiement_actif_id` (la ligne reste intacte, juste flaggée).
- Le pointage à AFD1 est créé via le journal, avec statut Flotteur.

**Affichage dans la grille de planning** *(décision Q-bis-1 validée — option α)* :
- L'agent redéployé est **visible uniquement sur la carte du site cible** (AFD1) ce jour-là, avec badge Flotteur 🌊 et infobulle "Redéployé depuis Centrale à HH:MM par [Opérateur]".
- Sur la carte Centrale, la case correspondante est **grisée/barrée** avec un libellé compact "→ AFD1" (pour que le planificateur voie d'un coup d'œil où est passé son agent).
- Cliquer sur la case grisée Centrale ouvre la fiche du redéploiement.

**Facturation et paie :**
- Le shift réalisé sur le site cible est rattaché à AFD1 pour la paie (CSV Sage §6.2) et pour la facturation client (CSV "Audit Client" §6.2) avec la colonne `REDEPLOYE_DEPUIS = Centrale`.
- C'est ainsi que la Centrale devient **rentable** pour KINGS-MRT : les agents redéployés sont facturés au site bénéficiaire.

**Reporting dédié (cf §6.3) :**
Un rapport d'activité Centrale agrège tous les `sec.redeploiement_log` pour mesurer l'efficacité du pool, les sites consommateurs, les agents les plus mobilisés, et les jours de "Centrale vide".

### 2.16 Modèle `sec.redeploiement_log` *(nouveau)*

Journal dédié des opérations de redéploiement Centrale → site client. Source unique de vérité pour le reporting (§6.3) et l'audit.

**Champs :**
- `agent_id` (Many2one `hr.employee`) — agent redéployé
- `date_redeploiement` (Date) — date comptable du shift (cf §2.10)
- `datetime_action` (Datetime) — horodatage exact du déclenchement
- `site_origine_id` (Many2one `sec.site`) — typiquement la Centrale
- `site_cible_id` (Many2one `sec.site`) — site bénéficiaire (AFD1, BCM2, etc.)
- `shift` : sélection (`J`, `N`)
- `planning_ligne_origine_id` (Many2one `sec.planning_ligne`) — la ligne Centrale flaggée
- `pointage_cible_id` (Many2one `sec.pointage`, optionnel) — le pointage créé sur le site cible (renseigné dès que pointage effectué)
- `redeploye_par_id` (Many2one `res.users`) — opérateur ou planificateur déclencheur
- `motif` (Text, optionnel) — texte libre ("Mamadou Ba absent — RM", "Renfort demandé par client")
- `statut` : sélection (`en_cours`, `termine`, `annule`)
- `external_id` (UUID) — pour synchro mobile Phase 2 (cf §1.4)
- Chatter natif Odoo activé (audit complet auteur/date/valeurs).

**Règles serveur :**
- Création uniquement via le **mécanisme dédié §4.5** (jamais en accès direct via le formulaire).
- Un agent ne peut faire l'objet que d'**un seul redéploiement actif par jour** (contrainte unique sur `agent_id` + `date_redeploiement` + `statut != 'annule'`).
- L'annulation (`statut = 'annule'`) est réservée à l'Administrateur, tant qu'aucun pointage n'est effectif sur le site cible. Tracée dans le chatter.
- Le passage `en_cours → termine` est automatique dès qu'un pointage `Présent` ou `Absent` est enregistré sur le site cible pour cet agent ce jour.

**Vue dédiée :** `Reporting → Redéploiements Centrale`, filtrable par période, site cible, agent, opérateur. Export CSV disponible.

### 2.17 Mécanisme de détection automatique du code `AT` *(nouveau v6.6)*

Conformément à la définition métier KINGS-MRT (cf §2.8 note `AT`), le code `AT` n'est **jamais saisi manuellement** par les opérateurs ou planificateurs. Il résulte d'un **mécanisme semi-automatique** combinant détection serveur et validation RH humaine.

**Paramètre de configuration (admin) :**

| Paramètre | Type | Défaut KINGS-MRT | Description |
|---|---|---|---|
| `at_seuil_jours_consecutifs` | Integer | **2** | Nombre de jours `A` consécutifs déclenchant la proposition de bascule en `AT`. Configurable via `Configuration → Paramètres guard_security`. |

**Workflow de détection :**

1. **Détection (cron quotidien)** : un cron Odoo `_cron_detecter_at_candidats` tourne chaque matin (par défaut 06h00, configurable). Il scanne tous les `sec.pointage` validés des `at_seuil_jours_consecutifs` derniers jours et identifie les agents ayant le code réalisé `A` (Absent) sur tous ces jours consécutifs, sans interruption (ni `J`, ni `RM`, ni autre code de justification).

2. **Création d'enregistrements de proposition** : pour chaque agent détecté, le cron crée un enregistrement dans un nouveau modèle léger `sec.at_proposition` :
   - `agent_id` (Many2one `hr.employee`)
   - `date_detection` (Date) — jour où la proposition a été générée
   - `jours_absents_ids` (One2many vers `sec.pointage`) — les pointages `A` concernés
   - `nb_jours_consecutifs` (Integer) — toujours `>= at_seuil_jours_consecutifs`
   - `statut` : sélection (`a_traiter`, `validee`, `refusee`, `expiree`)
   - `traite_par_id` (Many2one `res.users`, optionnel) — admin RH ayant statué
   - `date_traitement` (Datetime, optionnel)
   - `motif_refus` (Text, optionnel) — si le RH refuse la bascule (ex : "Agent en mission terrain non saisie, à régulariser")

3. **Alerte RH** : les propositions en `statut = 'a_traiter'` remontent immédiatement dans :
   - Le **bandeau d'alertes** du Dashboard Direction (nouvelle catégorie 🟫 **AT à traiter**, cf §3.8.2)
   - Une **vue liste dédiée** `Administration RH → Propositions AT à traiter`

4. **Validation RH (manuelle)** : l'administrateur RH (ou son adjoint) ouvre la proposition et choisit :
   - **Valider** → le système met à jour les `sec.pointage` concernés en bascule de `A` vers `AT` sur les jours `> at_seuil_jours_consecutifs`, ainsi que pour les jours suivants tant qu'aucune décision de clôture n'est prise. Audit complet via chatter natif (qui, quand, état précédent).
   - **Refuser** → la proposition passe en `statut = 'refusee'` avec motif obligatoire. Les `A` restent en `A`. Pas de bascule.

5. **Continuation du statut AT** : tant qu'un agent reste en `AT` sans décision RH de clôture, le cron quotidien continue de poser `AT` sur chaque nouveau jour ouvré (et non plus `A`). Pas de nouvelle proposition à valider — c'est un état stable.

6. **Sortie du statut AT (décision Q3 = γ — action RH explicite obligatoire)** :
Quand l'agent finit par revenir au travail ou que les RH décident de son sort, **l'administrateur doit explicitement clôturer** le statut AT via un wizard `Clôturer un Arrêt de travail` proposant trois issues :
   - **Réintégration** : le code des jours futurs revient à la planification normale (J, N, etc.). L'historique de AT reste auditable.
   - **Licenciement** : un code `L` est posé sur le jour de la décision, et l'agent est désactivé (`hr.employee.active = False`).
   - **Démission constatée** : un code `D` est posé sur le jour de la décision, et l'agent est désactivé.

Le système ne **réintègre jamais silencieusement** un agent en AT, même s'il se présente à son poste : seule la décision RH explicite réactive la planification.

**Vue dédiée :** `Administration RH → Propositions AT` (admin seul) + `Reporting → Historique des AT` (admin + planificateur en lecture).

**Performance :**
- Le cron tourne hors heures de bureau (06h00 par défaut).
- Détection bornée sur les agents actifs uniquement (`hr.employee.active = True`).
- Volumétrie estimée : pour 570 agents, scan de 2 jours = ~1140 lignes `sec.pointage` à vérifier, < 1 seconde.

### 2.18 Modèle `sec.main_courante` *(nouveau v6.6a-rev5)*

Journal universel des événements opérationnels. Centralise l'activité quotidienne du bureau (opérateur) et terrain (superviseur en phase 2, agent en phase 3). C'est l'**écran principal de l'Opérateur** en phase 1.

**Champs :**
- `date_evenement` (Datetime) — horodatage de l'événement
- `type_evenement` (sélection) — extensible selon les phases :
  - `note` *(phase 1)* — note libre de l'opérateur
  - `redeploiement` *(phase 1)* — mouvement d'agent Centrale → site, lié à un `sec.redeploiement_log`
  - `incident` *(phase 1)* — signalement, lié à un `sec.incident`
  - `absence_constatee` *(phase 2)* — remontée superviseur mobile
  - `presence_constatee` *(phase 2)* — remontée superviseur mobile
  - `pointage_propose` *(phase 2)* — pointage à valider par le planificateur
  - `auto_pointage` *(phase 3)* — pointage par l'agent lui-même via mobile
- `site_id` (Many2one `sec.site`, optionnel) — site concerné si applicable
- `agent_id` (Many2one `hr.employee`, optionnel) — agent concerné si applicable
- `auteur_id` (Many2one `res.users`) — qui a créé l'événement
- `contenu` (Text) — message libre ou structuré selon le type
- `severite` (sélection, optionnel) — `info` / `attention` / `urgent` / `critique` — utilisé surtout pour les incidents et alertes
- `redeploiement_log_id` (Many2one `sec.redeploiement_log`, optionnel)
- `incident_id` (Many2one `sec.incident`, optionnel)
- `pointage_id` (Many2one `sec.pointage`, optionnel) — pour phases 2/3
- `external_id` (UUID) — pour synchro mobile offline-first phase 2/3
- Chatter natif Odoo activé.

**Phase 1 — Types réellement utilisés** : `note`, `redeploiement`, `incident` uniquement. Les autres types sont **techniquement créables** dans le schéma mais ne seront alimentés qu'en phases 2 et 3.

**Performance et volumétrie :**
- Volumétrie cible : ~50 à 200 entrées par jour (selon activité).
- Pagination de l'affichage : 50 entrées par page, chargement progressif (infinite scroll).
- Index SQL sur `date_evenement` (DESC), `site_id`, `type_evenement` pour des requêtes performantes.

**Visibilité par profil :**
- **Opérateur** : voit **toute la main courante** (tous sites, toutes zones par défaut), peut créer des notes, redéploiements, incidents. Filtres optionnels pour zoomer sur un périmètre.
- **Planificateur** : voit toute la main courante (panneau latéral sur la grille planning), création limitée.
- **Administrateur** : visibilité totale et édition possible (avec audit).
- **Superviseur** *(phase 2)* : voit la main courante de sa brigade uniquement (`record rules`).

### 2.19 Règles et contrôles RH *(Phase 2 — backlog)*

Ensemble de règles métier et de contrôles automatisés pour éviter les incohérences planning ↔ RH. **Phase 1** : détection manuelle via le Dashboard Planificateur (anomalies planning §3.8.4). **Phase 2** : implémentation des contrôles et alertes automatiques ci-dessous.

**Règle 1 — Agent licencié (L) après date de licenciement**
- **Comportement** : ne doit pas et ne peut pas être planifié après `date_licenciement` sur `hr.employee`
- **Détection** : système scanne chaque jour la grille ; si un agent L a une ligne planning future après sa date, crée une alerte
- **Action** : alerte envoyée au Planificateur dans le Dashboard (§3.8.4 catégorie anomalie) + possibilité de corriger directement via le bouton contextuel
- **Implémentation** : validateur serveur sur `sec.planning_ligne` + cron quotidien de détection

**Règle 2 — Agent en mise à pied (MP) pendant sanction**
- **Comportement** : ne doit pas et ne peut pas être planifié pendant la période de sanction (MP = suspensif)
- **Détection** : si agent a statut MP et code MP appliqué sur une période [date_debut_MP, date_fin_MP], toute ligne planning en chevauchement déclenche une alerte
- **Action** : alerte Planificateur + correction possible
- **Implémentation** : champ `date_fin_mp` sur `hr.employee` + validateur planning

**Règle 3 — Agent en arrêt de travail (AT)**
- **Comportement** : ne doit pas et ne peut pas être planifié pendant toute la durée de l'AT (état suspensif)
- **Détection** : dès qu'un AT est validé (bascule d'une `sec.at_proposition` en AT confirmé), tout planning futures pendant [date_debut_AT, date_fin_AT] déclenche alerte
- **Action** : alerte Planificateur + correction possible
- **Implémentation** : relation `sec.at_proposition` ↔ planning_ligne + validateur

**Règle 4 — Agent en congé (C)**
- **Comportement** : validation OK (l'agent est bien en congé, c'est prévu), MAIS ne doit pas être compté dans la couverture du poste
- **Détection** : calcul automatique de la couverture (§3.6) : exclure les agents avec code C de la comptabilisation
- **Calcul de couverture** : `couverture = (agents_J avec code J ou Flotteur) + (agents_N avec code N) - (agents_C avec code C) = non comptés`
- **Implémentation** : logique d'exclusion dans le calcul `sec.planning_ligne.couverture_calcul()`

**Règle 5 — Agent sans qualification pour un site**
- **Comportement** : alerte si agent assigné à un site qui l'a déclaré non-qualifié ou interdit
- **Détection** : avant validation planning, vérifier champ `site_interdit_ids` sur agent ; si site_id ∈ site_interdit_ids, alerte
- **Action** : notification au Planificateur (warning, pas bloquant) + suggestion d'agent remplaçant du même profil
- **Implémentation** : validateur + recommandation par scoring (agents avec même statut, sans site_interdit pour ce site)

**Scope Phase 2** : implémentation de ces 5 règles comme validateurs serveur (côté ORM Odoo) + alertes Dashboard + crons de détection nuit (hors heures bureau)

**Extensibilité** : modèle `sec.rh_rule` à créer si d'autres règles s'ajoutent ultérieurement (phase 3/4)

---

## 2.20 Configuration Sites & Postes *(v6.6a-rev10 — Architecture refactorisée)*

Interface administrative pour gérer la hiérarchie Client → Site → Poste.

**Composition :**

**Vue LIST Sites**
- Grille des sites avec colonnes : Code, Nom, Client, Zone, Brigade, Nombre postes (badge), Statut, Actions
- Filtres : Client, Zone, Statut
- Bouton "Nouveau site"
- Actions Edit/Delete par site

**Fiche Site** (6 onglets)
- **Identité** : Code (lecture seule), Nom, Client (lecture seule), Zone, Brigade, Adresse, Géolocalisation (lat/lng), Flags is_centrale, is_facturable
- **Postes** : Tableau récapitulatif des postes du site (Type · Pattern · Agents requis · Statut · Édition). Bouton "Ajouter un poste"
- **Planning** : Heures d'ouverture (De/À), Jours de fermeture (checkboxes), Jours fériés fermés
- **Contacts** : Contact principal client (nom, tél, email)
- **SLA** : Couverture minimale (%), Temps de réaction redéploiement (min), Notes accords
- **Agents interdits** : Tags cliquables avec motifs d'interdiction (textarea)

**Fiche Poste** (formulaire simple — pas d'onglets)
- **Site** : Sélection disabled (héritée de la fiche site)
- **Type de poste** : Dropdown vers `sec.poste_type` (ADS, SUP, CP, etc.)
- **Pattern horaires** : Dropdown vers `sec.shift_pattern` (H24-S12-7/7, H12-S12-5/7, etc. — 8 patterns KINGS-MRT)
- **Agents requis** : Calculé automatiquement depuis le pattern (lecture seule)
- **Statut** : Dropdown Actif/Inactif
- **Notes** : Textarea pour conditions spéciales (double équipe certains jours, renforts événementiels, formations requises)

**Flux de création d'un service client :**
1. Créer un **Site** : remplir Identité + Planning + Contacts + SLA
2. Ajouter un **Poste** au site : sélectionner Type (ADS) + Pattern (H24-S12-7/7) → Agents requis calculés
3. Planifier le personnel : affectation d'agents aux shifts du poste dans la grille planning (§3)

---

## 2.21 Fiche Agent enrichie — Onglets Gardiennage & Historique *(v6.6a-rev12 — Architecture Odoo 19 native)*

Extension de `hr.employee` (Odoo standard) avec 2 onglets custom pour guard_security.

**Onglets Odoo natifs conservés** (accès inchangé) :
- Travail (Fonction, Manager, Lieu, Organigramme)
- CV (Curriculum Vitae)
- Personnel (État civil, Citoyenneté, Lieu, Famille, Éducation, Documents, Coordonnées privées, Contact urgence, Visa/Permis)
- Paie (Contrat, Horaire, Ajustements de salaire)
- Ajustements de salaire (Tableau ajustements)
- Paramètres (Utilisateur, Validateurs, Présence/Point de vente, Évaluation)

**2 onglets CUSTOM guard_security** (ajoutés) :

**1. Onglet "Gardiennage"**
- **Type de poste** : sélection parmi sec.poste_type (ADS, SUP, CP, etc.)
- **Accès sites** : liste des sites interdits (multi-select avec motif d'interdiction)
- **Formations requises** : checkboxes pour chaque formation (SSI, Premiers secours, Manutention, etc.) + dates de validité
- **Sanction RH** : statuts en lecture seule (Licence/L, Mise à pied/MP, Démission/D, Arrêt travail/AT) — alimentés automatiquement par cron AT ou action manuelle RH

**2. Onglet "Historique"**
- **Historique planning (30 derniers jours)** : liste avec code vacation + site + durée shift
- **Pointage (10 derniers jours)** : graphique mini codes (J/S/N/C/A/etc.) avec counts
- **Incidents (dernier mois)** : liste événements incidents liés à cet agent

**Actions disponibles dans header** :
- Bouton "Signaler un incident" (crée `sec.incident` pour cet agent)
- Bouton "Marquer absent" (pré-remplit une absence dans le pointage)

**Intégration Odoo native** :
- Fonction, Manager, Département, Société, Type contrat, Date embauche → depuis onglet Travail natif
- Email, Téléphone, Adresse → depuis onglet Personnel natif
- Salaire brut, Type salaire, Horaire → depuis onglet Paie natif
- Données gardiennage (Type poste, Sites interdits, Formations, Historique) → onglets custom Gardiennage + Historique

---

## 2.22 Wizard Export Audit *(v6.6a-rev13 — Export par agent avec TST + codes filtrés)*

Interface d'export pour audit client : données par agent avec codes groupés et totaux sur la période.

**Paramètres export** :
- Période (de/à)
- Client (optionnel — tous par défaut)
- Site (optionnel — tous par défaut)
- Filtre agents (actifs/inactifs, exclusion licenciés)

**Structure export — 2 groupes de codes** :

**25 codes vacation KINGS-MRT organisés par catégorie** :

| Catégorie | Code | Libellé | Coefficient TST |
|-----------|------|---------|-----------------|
| **Travail** | J | Jour | 1 |
| | S | Soir | 1 |
| | N | Nuit | 1 |
| | EJ | Jour + HS | 1 |
| | SE | Soir + HS | 1 |
| | JE | Jour Extra | 1 |
| | CSP | Changement site planifié | 1 |
| | MS | Mission | **2** |
| | REMPL,C | Remplacement de congé | 1 |
| | REMPL,PIP | Remplacement de pipeline | 1 |
| | JN | Jour+Nuit (2 shifts) | **2** |
| **Absence** | A | Absent | 0 |
| | AP | Abandon post | 0 |
| | M | Malade sur site | 0 |
| | C | Congé | 0 |
| | F | Formation | 0 |
| **Sanction** | MP | Mise à pied | 0 |
| | AT | Arrêt de travail | 0 |
| | L | Licencié | 0 |
| | D | Démission | 0 |
| **Indicateurs** | PF | Poste fermé | 0 |
| | PS | Poste suspendu | 0 |
| | CF | Confinement | 0 |
| | SB | Stand by | 0 |

**TST (Total Shifts Travaillés) — Calcul automatique** :
```
TST = J + S + N + EJ + SE + JE + CSP + (MS × 2) + REMPL,C + REMPL,PIP + (JN × 2)
```

**Colonnes export** :
- Codes Travail (11 codes) : colonnes fixes, somme = TST
- **TST** : colonne totale calculée
- Codes Absence (5 codes) : colonnes si total > 0
- Codes Sanction (4 codes) : colonnes si total > 0
- Codes Indicateurs (4 codes) : colonnes si total > 0

**Données exportées — Par agent** :
- Matricule + Nom + Site
- 8 codes Travail (colonnes fixes)
- **TST** (colonne totale, toujours affichée)
- 9 codes Absence/Sanction (colonnes conditionnelles si > 0 ; sinon "—")

**Format export** :
- CSV (UTF-8, séparateur point-virgule) ou XLSX (Excel)
- Feuille 1 : Export par agent (structure ci-dessus)
- Feuille 2 (optionnel) : Synthèse par site (sites facturables, couverture %, agents affectés)
- Feuille 3 (optionnel) : Détail journalier (1 ligne = 1 jour agent + code réalisé)

**Cas d'usage** :
- Audit client : vérifier présence agents et couverture sites
- Réconciliation pointage : valider codes réalisés vs planning
- Facturation : base de calcul pour facture client (jours réels travaillés par site)

---

## 3. Espace Paramètres & Configuration *(v6.6a-rev11 — Gestion des constantes globales)*

Interface administrative centralisée pour gérer toutes les constantes et référentiels de garde_security.

**Structure :**
- **Menu latéral** : 6 sections (Types de postes, Patterns horaires, Codes vacation, Zones, Brigades, Configuration métier)
- **Chaque section** : Grille LIST avec filtres, tri, et actions
- **Création/Édition** : Modale dédiée par section (formulaire adapté)

**Sections du référentiel :**

**1. Types de postes** (`sec.poste_type`)
- Colonnes : Code, Libellé, Statut
- Actions : Edit / Delete
- Exemples : ADS (Agent de Sécurité), SUP (Superviseur), CP (Chef de Poste)
- Champs fiche : Code, Libellé, Description, Statut (Actif/Inactif)

**2. Patterns horaires** (`sec.shift_pattern`)
- Colonnes : Code, Libellé, Agents requis, Statut
- Actions : Edit / Delete
- 8 patterns KINGS-MRT standardisés (H24-S12-7/7, H12-S12-5/7, H8-S8-5/7-J, etc.)
- Champs fiche : Code, Libellé, Durée shift (h), Agents requis (auto-calculé), Statut

**3. Codes vacation** (`sec.code_vacation`)
- Colonnes : Code, Libellé, Catégorie (Travail/Absence/Sanction), Facturable
- Actions : Edit
- 25 codes RH officiels KINGS-MRT (J, S, N, EJ, EN, JE, SE, A, M, AT, MP, P, PL, RM, C, L, D, PF, PS, CSP, CF, MS, SB, AP, F, REMPL)
- Champs fiche : Code (max 4 caractères), Libellé, Catégorie (dropdown), Facturable (checkbox), Actif (checkbox)

**4. Zones géographiques**
- Colonnes : Code, Nom, Statut
- Actions : Edit / Delete
- Exemples : NK-N (Nouakchott Nord), NK-S (Nouakchott Sud), NK-C (Nouakchott Centre)
- Champs fiche : Code, Nom, Statut

**5. Brigades**
- Colonnes : Code, Nom, Statut
- Actions : Edit / Delete
- Exemples : A, B, C (3 brigades standard)
- Champs fiche : Code, Nom, Statut

**6. Configuration métier**
- **Seuil AT** : Nombre de jours consécutifs d'absence avant détection automatique (défaut 2). Éditable via bouton.
- **Cron détection AT** : Heure quotidienne du cron (défaut 06:00 UTC). Éditable via bouton.
- Format : Cards affichant la valeur + bouton "Éditer" donnant accès à une modale simple

**Modalités d'édition :**
- Création/modification : Modale dédiée par section (formulaire vertical)
- Destruction : Confirmation avant suppression
- Validation serveur : Champs requis, unicité clés (Code), contrôles métier

---

## 4. Grille de Planning Interactive (Composant OWL Sur Mesure)

L'outil principal est un tableau matriciel interactif construit avec le **framework JavaScript OWL natif d'Odoo 19**, garantissant une réactivité immédiate sans rechargement de page.

### 3.1 Mode "Vue Globale" pour le Planificateur

- **Affichage par cartes empilées** : Les sites actifs s'affichent sous forme de cartes distinctes empilées verticalement sur une seule page déroulante.
- **Période affichée alignée sur le site** : Pour un site en mode `24→23`, la grille affiche exactement la période 24 du mois M → 23 du mois M+1. Un sélecteur en haut de chaque carte indique clairement la période en cours et permet de naviguer entre périodes (précédente / courante / suivante).
- **Super-barre de filtres** : En haut de la grille, l'utilisateur dispose d'une barre de filtres riche permettant un focus instantané (côté client, sans appel serveur). La barre comprend :
  - **Filtres de visibilité temporelle** : `Voir tout` (défaut) · `Pointage J-1` (atténue les colonnes futures à 25% d'opacité pour focus sur la veille à valider)
  - **Filtres de périmètre (multi-sélection)** : `Client`, `Site`, `Zone géographique`, `Brigade`, `Agent` (recherche par nom/matricule avec autocomplete). **Chaque filtre accepte plusieurs valeurs simultanées** (ex : voir AFD + BCM, ou Nouakchott Nord + Nouakchott Centre).
  - **Filtre de statut** : Tous / Fixe / Remplaçant / Flotteur (multi-sélection aussi).
  - Les filtres se combinent en ET logique entre eux ; au sein d'un filtre, les valeurs sélectionnées sont en OU logique (ex : Client = [AFD, BCM] signifie "AFD ou BCM").
  - Un compteur "X / Y sites visibles · X / Y agents visibles" se met à jour en temps réel.
  - Action `Effacer tous les filtres` accessible en un clic.
  - Les préférences de filtres sont **mémorisées par utilisateur** via `sec.dashboard_view` (cf §2.11) pour rappel à la prochaine session.

➡️ **Règle UI globale (v6.6a-rev5)** : la multi-sélection est **disponible (optionnelle) sur tous les filtres de l'application** (vue unifiée, dashboards, carte interactive, vues reporting...). L'utilisateur peut sélectionner une seule valeur (mode classique) ou plusieurs selon son besoin. Implémentation technique : composants type "tag picker" Odoo ou équivalent OWL avec chips/badges visualisant les valeurs sélectionnées. Une croix sur chaque chip permet le retrait individuel. Un menu déroulant permet l'ajout avec recherche.
- **Ajout d'Agent intelligent** : Bouton `[+ Ajouter]` associé à un champ de recherche par matricule. La liste déroulante indique la disponibilité en temps réel (ex : `"S0103 - Binta Sy (Dispo)"`). L'action génère une ligne vierge.
- **Bouton de suppression de ligne** : Icône 🗑️ en fin de ligne pour retirer immédiatement l'agent de la grille de ce site.

### 3.2 Widget "Alertes" en haut du Dashboard Planning *(nouveau)*
Au-dessus des cartes de sites, un panneau d'alertes proactif liste **tous les sites/jours en sous-effectif**, triés par urgence :

- **🔴 J+0** : découverts pour aujourd'hui (priorité maximale)
- **🟠 J+1 à J+2** : découverts imminents
- **🟡 J+3 à J+7** : découverts à anticiper sur la semaine

Chaque alerte est cliquable et amène directement à la cellule concernée dans la grille. Le compteur global est visible dans le menu principal (ex : `Planning (3)`) pour que le planificateur voie les urgences dès l'ouverture d'Odoo.

### 3.3 Saisie de masse et Ergonomie "PC First"

- **Navigation fluide** : Déplacement de case en case via les flèches directionnelles (← → ↑ ↓) ou la touche `Tab`.
- **Saisie directe au clavier** : L'utilisateur tape une lettre pour poser un **badge coloré épuré centré dans la cellule blanche** (pas de coloration complète de la case). Chaque badge porte **à la fois sa couleur ET sa lettre/icône** pour garantir l'accessibilité daltonienne.
- **Codes** chargés dynamiquement depuis `sec.code_vacation` (configurable, cf §2.8).
- Les touches `Suppr` ou `Backspace` vident instantanément la case.
- **Autosave transparent** : Sauvegarde automatique en arrière-plan avec un debounce de **800ms** (indicateur discret ✓ Enregistré), sans jamais faire perdre le focus du curseur.

### 3.4 Performance et Rendu Virtualisé *(spécification explicite)*
Compte tenu de la volumétrie (**570 agents × 31 jours ≈ 17 670 cellules par mois**), le composant OWL devra impérativement :

- Utiliser un **rendu virtualisé** : seuls les sites et lignes visibles dans le viewport sont montés en DOM ; les autres sont rendus à la volée lors du scroll.
- Garantir les **benchmarks cibles suivants** (à vérifier en recette) :
  - Filtrage instantané : **< 100 ms** pour une vue 50 sites × 30 jours.
  - Rendu initial : **< 1,5 s** pour 50 sites × 30 jours.
  - Autosave : **< 300 ms** entre saisie et confirmation visuelle.
  - Navigation clavier de cellule à cellule : **< 50 ms** (perçu comme instantané).
- Utiliser des techniques de **memoization** côté OWL pour éviter les re-renders inutiles lors d'une saisie isolée.

### 3.5 Règles de Validation et Verrous Serveurs

**Pied de carte — Contrôle de Couverture jour-par-jour :**
Le système analyse **chaque jour (colonne)** de la carte du site et la compare au besoin contractuel défini sur `sec.poste` (composition `J` + `N` requise par jour) :

- ✓ (Vert) : Nombre et type de shifts conformes au besoin contractuel ce jour-là.
- ⚠️ X jour découvert (Texte rouge sur fond rose) : Sous-effectif opérationnel ce jour-là.
- ✖ (Croix rouge sur fond rose) : Sur-effectif / Trop d'agents planifiés ce jour-là (sécurité anti-surfacturation).

⚠️ Le contrôle est **strictement jour-par-jour**, pas en volume hebdomadaire ou mensuel. Un site sans agent à 14h le mardi est non-sécurisé, même si la semaine est "globalement OK".

**Verrou Anti-Doublon (avec exception redéploiement) :** Interdiction stricte de planifier un même agent sur deux sites différents à la même date. Le serveur bloque instantanément via une `UserError` explicite indiquant le site en conflit.

⚠️ **Exception unique : le redéploiement Centrale → site cible (cf §4.5)**. Dans ce cas particulier, l'agent apparaît légitimement sur deux sites le même jour :
- Sa ligne `sec.planning_ligne` d'origine sur la Centrale est **conservée intacte** (pour audit historique), mais reçoit un flag `redeploiement_actif_id` qui la neutralise (case vidée à l'affichage avec libellé "→ Site cible", non comptée dans la couverture Centrale).
- Une nouvelle ligne `sec.planning_ligne` est créée sur le **site cible** (statut Flotteur), avec son pointage associé.

Le verrou serveur détecte cette exception via la présence du `redeploiement_actif_id` sur la ligne d'origine : si elle est neutralisée, la création d'une seconde ligne le même jour sur un autre site est autorisée. Toute autre tentative de "doublon" hors mécanisme `sec.redeploiement_log` reste strictement bloquée.

**Test à automatiser (priorité haute en recette) :** vérifier que l'agent ne peut apparaître qu'une seule fois "active" par jour, sauf si la première occurrence est neutralisée par un redéploiement. Inversement, vérifier qu'on ne peut **jamais** poser deux planning_lignes actives sur deux sites différents le même jour sans passer par le bouton "Marquer un redéploiement".

**Verrou Restriction Site :** Blocage immédiat si l'agent est planifié sur un site listé dans ses `site_interdit_ids`.

**Verrou Période Clôturée :** Si la `sec.planning_periode` est en état `closed` ou `exported`, toute modification est refusée sauf pour les administrateurs (avec motif obligatoire).

### 3.6 Politique sur les cases vides
Le planning **ne doit pas présenter de cases vides** sur des jours où le site requiert une couverture. Une cellule vide pour un jour où le site est actif est traitée comme un découvert et **signalée par un badge ⚠️ (point d'exclamation)** au pied de la colonne de date concernée.

➡️ Conséquence : **un agent qui se présente sans avoir été planifié n'entraîne pas la création rétroactive d'une ligne de planning**. Le pointage `Présent` ne peut s'enregistrer que sur une ligne de planning préexistante. Si une présence "fantôme" doit être saisie, le planificateur doit d'abord créer la ligne dans la grille (action explicite, traçable).

### 3.7 Suppression d'une ligne agent dans la grille *(nouveau)*
Le bouton 🗑️ en fin de ligne déclenche une procédure en **trois étapes vérifiées côté serveur** avant toute modification de la base :

**Étape 1 — Vérification de pointages existants (verrou strict)**
Si au moins un `sec.pointage` est associé à cette ligne agent/site sur la période en cours, **la suppression est refusée**. Une modale informe l'utilisateur :
> *« [Agent] a [N] pointage(s) enregistré(s) sur ce site. La suppression est bloquée pour préserver l'intégrité de la paie. Pour retirer cet agent, annulez d'abord ses pointages via l'écran Pointage bureau. »*

Ce verrou est non contournable, même pour le profil Administrateur, afin de garantir la cohérence comptable.

**Étape 2 — Confirmation si vacations planifiées**
Si la ligne ne porte pas de pointage mais contient au moins une vacation saisie (J, N, C, etc.), une modale de confirmation s'affiche :
> *« [Agent] a [N] vacation(s) planifiée(s) qui seront désactivées. Les jours concernés repasseront en découvert si la couverture n'est plus assurée. »*

Boutons : `Annuler` / `Confirmer le retrait`.

**Étape 3 — Désactivation logique (`active = False`)**
Si l'utilisateur confirme (ou si la ligne est vierge), la ligne `sec.planning_ligne` est **désactivée logiquement** (pas supprimée physiquement) :
- Le champ natif Odoo `active` passe à `False`.
- Toutes les vacations associées sont également désactivées.
- L'opération est tracée dans le chatter natif (`mail.thread`) : qui, quand, contexte.
- La ligne disparaît de la grille mais reste consultable via filtre « Inclure les inactifs » par les administrateurs.
- Possibilité de réactivation (`active = True`) en cas d'erreur, également auditée.

**Conséquence sur la couverture (Étape 4 — recalcul automatique) :**
Le retrait d'une ligne déclenche immédiatement le recalcul de la couverture du site :
- Les jours qui passent en sous-effectif sont marqués ⚠️ dans le pied de carte.
- Les nouveaux découverts remontent immédiatement dans le **widget d'alertes** en haut du dashboard Planning (cf §3.2).
- Aucune notification email/push en Phase 1 (le widget suffit). La notification proactive pourra être ajoutée en Phase 2.

### 3.8 Dashboards d'accueil personnalisés par profil *(nouveau)*

À l'ouverture d'Odoo, chaque utilisateur arrive sur **son propre dashboard d'accueil** adapté à son métier et à son périmètre d'action. Cela fait gagner un temps considérable comparé à un dashboard générique.

#### 3.8.1 Principes communs aux 4 dashboards
- **Auto-refresh** : rafraîchissement automatique toutes les **30 secondes** en Phase 1 (auto-refresh côté client). Migration vers bus.bus en Phase 2 (cf §1.4).
- **Performance** : tous les KPI doivent se charger en **< 500 ms** au premier affichage. Calculs SQL agrégés côté serveur, jamais en boucle Python.
- **Persistance des préférences** via `sec.dashboard_view` (cf §2.11) : widgets affichés, ordre, filtres mémorisés.
- **Trends** : tous les KPI à variation affichent une **flèche directionnelle** (↑ vert, ↓ rouge, → gris) suivie d'un pourcentage de variation vs période précédente. Pas de sparkline en Phase 1.
- **Visibilité des données** : chaque dashboard respecte strictement les `record rules` du profil (un Superviseur ne voit que sa brigade, un Opérateur que sa zone).

#### 3.8.2 Dashboard Direction (profil Administrateur) *(refondu v6.6a-rev9)*

**Vue RH synthétique et factuelle.** Objectif : tableau d'ensemble de la santé des 570 agents sur 3 horizons temporels (jour / semaine précédente / mois).

**Format** : rapport RH (pas de dashboard graphique). Trois sections de données brutes + pas d'analyse interprétative ni recommandations (celles-ci seront dressées par un système de monitoring automatisé ultérieur en Phase 2).

**En-tête KPI** :
- **Sites actifs** : nombre de sites en exploitation (ex : `18 sur 20 total`)
- **ADS actifs** : nombre d'agents Actifs, Disponibles ou Spécialisés en poste/activités ce jour (ex : `428 agents`)
- **Sites incomplets** : nombre de sites avec couverture < 100% (ex : `5 sites`)

**Section 1 — Snapshot du jour** (format tableau) :
- Affiche les 25 codes RH officiels KINGS-MRT : J, S, N, EJ, EN, JE, SE, A, M, AT, MP, P, PL, RM, C, L, D, PF, PS, CSP, CF, MS, SB, AP, F, REMPL
- **Filtrage** : affiche uniquement les codes avec effectif > 0 (pour éviter le bruit des codes non utilisés ce jour)
- Colonnes : Code · Effectif · Détail (libellé)
- Codes en alerte (AT, M, AP, A) mis en évidence couleur (fond rose)

**Section 2 — Tendance semaine précédente · 27 mai - 2 juin** (format tableau) :
- Codes majeurs sur 7 jours : AT, M, A, MP, AP, C
- Colonnes : Code · Lun · Mar · Mer · Jeu · Ven · Auj · Δ (variation jour 1 → jour 7)
- Codes en alerte colorisés

**Section 3 — Tendance mois · mai 2026** (format tableau) :
- Codes majeurs par décade (1-10 mai, 11-20 mai, 21-31 mai)
- Colonnes : Code · Décade1 · Décade2 · Décade3 · Moyenne mois · Δ (variation début → fin)
- Inclut un dernier indicateur : couverture globale (%) pour mesurer la capacité opérationnelle

**Pas d'analyse, recommandation ou conclusion.** Les données brutes suffisent. Le système de monitoring RH Phase 2 se chargera d'interpréter et d'alerter.

**Mise à jour** : automatique via cron quotidien à 07h00. Historique conservé (au minimum 13 mois) pour tendances longues terme.

---- 🟡 **PHASE 2 — Documents expirés** *(placeholder)* : exploitable Phase 2 quand `sec.agent_document` sera créé.

#### 3.8.3 Dashboard Planificateur

**Vue opérationnelle hebdomadaire.** L'objectif : « où sont les trous à boucher sur les 7 prochains jours ? ».

**Contenu identique au Direction sur le bandeau d'alertes** (J+0, J+1-J+2, J+3-J+7 — cf §3.2), mais focalisé sur l'**action** :
- Bouton d'accès direct à la grille de planning préfiltrée sur les sites en alerte.
- **Liste des agents sans affectation** avec leur disponibilité (déjà sur quel site cette semaine, qualifications `hr.job`).
- **Sites avec sur-effectif** : remontée des cas où il y a plus d'agents que nécessaire (sécurité anti-surfacturation, cf §3.5).

**Pas de KPI de pilotage haut niveau** (taux de couverture global, etc.) — pas utile pour ce profil.

#### 3.8.4 Dashboard Opérateur *(refondu v6.6a-rev7)*

**Vue de pilotage global** complémentaire à la Main Courante §3.9. Tandis que la Main Courante est l'écran "deep work" du quotidien (flux chronologique d'événements), le Dashboard Opérateur est l'écran "pulse check" : vue d'ensemble en 5 secondes en arrivant le matin ou entre deux actions.

**Visibilité par défaut : globale** (tous sites, toutes zones, toutes brigades). L'opérateur peut **zoomer** sur un périmètre via une barre de filtres optionnels (Zone, Client, Brigade, État). Les opérateurs ne sont pas rattachés à une zone géographique particulière — plusieurs opérateurs peuvent travailler en rotation sur le même périmètre global.

**Composition en 3 zones horizontales :**

**Zone 1 — Bandeau filtres + Légende d'état**
- Filtres optionnels (Zone, Client, Brigade, État) avec compteur dynamique "X / Y sites visibles · vue globale|filtrée"
- Légende des codes couleurs des sites : 🟢 OK · 🟠 Tendu · 🔴 Critique · 🔵 Centrale (réserve)

**Zone 2 — Pilotage du jour + Carte OpenStreetMap (split horizontal)**

*Panneau gauche — KPI synthétiques* (6 cards en pile verticale) :
- Sites surveillés (X / Y)
- Pointages J-1 à valider (déclenché par planificateur)
- Réserve Centrale (J / N)
- Redéploiements actifs (du jour)
- Incidents ouverts (avec sévérité)
- *(Phase 2 anticipée)* Tournées superviseurs — en pointillés, opacifié 55%

*Panneau droit — Carte mini OpenStreetMap résumée* :
- Markers colorés synchronisés avec les filtres actifs
- Centrale visible avec icône bouclier bleue
- Infobulles au clic avec bouton "Ouvrir dans la grille"
- **Bouton "Ouvrir en plein écran"** en overlay (haut droit) qui renvoie vers la carte interactive complète §3.10
- Pas d'interactivité avancée (zoom léger, déplacement basique) — pour l'interaction approfondie, basculer vers la vue Carte plein écran

**Zone 3 — Aperçu Main Courante + Raccourcis d'action (split 2/3 vs 1/3)**

*Panneau gauche — Aperçu Main Courante* :
- 5 derniers événements en mini-cards (icône, horodatage, type, site, contenu condensé)
- Clic sur une carte → ouvre l'événement (fiche incident, fiche redéploiement, etc.)
- Bouton "Voir tout →" en haut à droite → ouvre la Main Courante complète §3.9

*Panneau droit — Raccourcis d'action* :
- **Signaler un incident** (bouton primaire rouge)
- Marquer un redéploiement
- Ajouter une note rapide
- Voir la grille (lecture seule, l'opérateur n'a pas le droit d'édition)
- Main courante complète
- *(Phase 2 anticipée)* Appeler superviseur — en pointillés

**Auto-refresh** : 30 secondes en Phase 1 (cf §3.8.1). En Phase 2, passage à temps réel via `bus.bus` pour les remontées superviseurs mobiles.

**Conservation explicite** : pas de "mosaïque de tuiles des sites" comme initialement envisagée. L'opérateur dispose déjà de la **carte géographique** pour le scan visuel rapide et de la **Main Courante** pour le suivi détaillé. Une troisième vue redondante (mosaïque) surchargeait inutilement le dashboard.

#### 3.8.5 Dashboard Superviseur (Phase 2)

**Phase 2 uniquement.** Vue terrain mobile-first : agents de sa brigade, statut de pointage en temps réel, signalement d'incident en un tap, photos géolocalisées. Mentionné ici pour cohérence d'architecture, non développé en Phase 1.

### 3.9 Vue Main Courante *(nouveau v6.6a-rev5)*

La main courante est l'**écran principal de l'Opérateur** en phase 1. Elle constitue à la fois :
- Un **outil de pilotage temps réel** (bandeau supérieur de KPI)
- Un **journal universel des événements opérationnels** (panneau inférieur chronologique filtrable)

Elle est aussi accessible en **panneau latéral** depuis la grille planning pour le Planificateur (cf §3.8.3 : il a besoin de voir la main courante en validant J+1 pour comprendre les redéploiements et événements terrain de la veille).

#### 3.9.1 Architecture de l'écran (approche "dashboard hybride" — choix Q1=b)

L'écran est divisé en **deux zones** distinctes :

**Zone supérieure — Pilotage temps réel** :
- **KPI cards** synthétiques : Sites en alerte / Redéploiements actifs / Incidents ouverts / Centrale (J / N) / Notes du jour
- **Alertes contextuelles** : agents manquants J+0, incidents critiques non traités, Centrale vide
- **Indicateur live dot** confirmant que le rafraîchissement temps réel est actif (auto-refresh 30s en phase 1, bus.bus en phase 2 — cf §3.8.1)
- Évolution phase 2/3 anticipée (cf §1.4) : badges discrets "phase 2" sur les zones préparées (ex : "Pousser une alerte au superviseur", "Voir les pointages mobiles à valider"). Ces zones existent visuellement mais ne sont pas fonctionnelles en phase 1.

**Zone inférieure — Journal chronologique** :
- Liste des événements `sec.main_courante` triés en ordre antéchronologique (le plus récent en haut)
- Pagination par 50 entrées avec chargement progressif (infinite scroll)
- Chaque événement est une **carte expansible en place** (choix Q5=ι) : un clic déplie pour voir le détail complet sans naviguer hors de l'écran
- Filtres en en-tête (cf §3.9.3)
- Zones de saisie en bas (cf §3.9.4)

#### 3.9.2 Types d'événements affichés (phase 1 — choix Q2=α)

En phase 1, seuls **3 types** sont actifs et alimentent la main courante :

| Type | Source | Icône | Couleur |
|---|---|---|---|
| `note` | Opérateur (saisie manuelle) | 📝 ti-notebook | Gris neutre |
| `redeploiement` | Opérateur via bouton dédié → matérialisé J+1 par planificateur | 🔁 ti-route | Orange (action) |
| `incident` | Opérateur via formulaire incident | ⚠️ ti-alert-triangle | Rouge ou orange selon sévérité |

Les autres types (`absence_constatee`, `presence_constatee`, `pointage_propose`, `auto_pointage`) sont préparés dans le modèle (cf §2.16) mais ne sont alimentés qu'en phases 2 et 3. Aucun affichage spécial en phase 1.

**Préparation visuelle phase 2/3 (choix Q6=λ)** : la maquette intègre des **badges discrets "Phase 2"** sur les fonctionnalités à venir (ex : "Voir les pointages mobiles", "Alertes auto agents"), pour préparer mentalement les utilisateurs sans introduire de bug ou friction.

#### 3.9.3 Filtres du journal (choix Q4=ζ — filtres de base)

Filtres disponibles, **multi-sélection optionnelle** sur chacun :
- **Type d'événement** : Note / Redéploiement / Incident
- **Site** : sélection multi-sites (cf règle multi-sélection optionnelle)
- **Date/période** : `Aujourd'hui` (défaut) · `Hier` · `7 derniers jours` · `Période personnalisée`

Un compteur "X événements sur Y" se met à jour en temps réel.

#### 3.9.4 Saisie de nouveaux événements (choix Q3=ε — double système)

L'opérateur dispose de **deux modes de saisie** complémentaires :

**Mode 1 — Champ rapide en bas de l'écran (zone de saisie style chat)**
- Toujours visible, ancré en pied d'écran
- Pour les **notes courantes** sans structure (ex : "Appel de M. Diop client AFD à 10h15, RAS")
- Validation par `Entrée` → crée automatiquement un `sec.main_courante` de type `note`, avec auteur = utilisateur courant, date = `now()`, sans site/agent associé (sauf si tags `@AFD1` ou `#S0103` détectés dans le texte → liaison auto)
- Édition impossible après envoi (immuabilité comme pour les pointages, cf §4.3) — mais ajout de commentaires possible via clic sur la carte

**Mode 2 — Bouton "+ Nouvel événement" qui ouvre une modale structurée**
- Pour les événements importants nécessitant des champs précis
- 3 options dans le menu déroulant du bouton :
  - **Redéploiement** → ouvre la modale `Marquer un redéploiement` (cf §4.5 — workflow standard)
  - **Incident** → ouvre la modale `Signaler un incident` (cf §2.12 `sec.incident`)
  - **Note structurée** → modale avec champs site, agent, sévérité, message long, pièces jointes

#### 3.9.5 Expansion en place des événements (choix Q5=ι)

Un clic sur une carte d'événement la **déplie en place** dans le journal pour révéler :
- Le détail complet du contenu
- Les liens vers les objets associés (fiche redéploiement, fiche incident, note de pointage liée...)
- Les commentaires/chatter de l'événement (réponses, mises à jour ultérieures)
- Les actions possibles selon le profil utilisateur :
  - **Opérateur** : ajouter un commentaire
  - **Planificateur** : ajouter un commentaire, marquer comme traité
  - **Administrateur** : tout précédent + modifier/clôturer

L'expansion ne navigue pas vers un autre écran — l'opérateur garde son contexte.

➡️ Exception : si l'opérateur **veut explicitement ouvrir la fiche complète** (par exemple pour exporter en PDF), un bouton `Ouvrir en plein écran` dans la carte dépliée permet la navigation vers la fiche dédiée (cf fiche redéploiement validée comme patron de référence).

#### 3.9.6 Évolutions anticipées Phase 2 / Phase 3

**Phase 2** — Activation des types `absence_constatee`, `presence_constatee`, `pointage_propose` :
- Les remontées superviseurs apparaîtront en temps réel via bus.bus
- L'opérateur pourra valider/refuser un redéploiement proposé directement depuis la carte d'événement
- Notifications push à l'opérateur

**Phase 3** — Activation du type `auto_pointage` :
- Détection automatique d'absence (agent qui n'a pas auto-pointé à H+ε)
- Proposition automatique de remplaçant du pool Centrale
- L'opérateur valide ou modifie le choix automatique

---

### 3.10 Carte interactive des sites actifs *(nouveau)*

Une **carte cartographique interactive** complète les dashboards textuels en offrant une vue géographique de l'ensemble des sites de KINGS-MRT. Accessible depuis le menu principal `Cartographie` (visible Direction et Planificateur).

**Spécifications techniques :**
- **Provider** : OpenStreetMap (gratuit, open-source). Aucun coût d'API, autonomie maximale.
- **Bibliothèque** : Leaflet.js intégrée à un composant OWL dédié (compatibilité Odoo 19).
- **Source des coordonnées** : champ `geolocalisation` (latitude, longitude) de `sec.site` (cf §2.3).
- Sites sans coordonnées géolocalisées : signalés dans une liste à part avec un bouton "Géolocaliser" pour saisie manuelle.

**Fonctionnalités de filtrage :**
Une barre de filtres en haut de la carte permet de trier par :
- **Client** (`res.partner`) — affiche uniquement les sites d'un client donné
- **Zone géographique** — Nouakchott Nord, Nouakchott Sud, Nouadhibou, etc.
- **Brigade** — sélection de la brigade opérationnelle
- **Statut de couverture** : tous / OK / Tendus / Découverts

Les filtres se combinent et la carte se rafraîchit instantanément (recalcul côté client, pas de rechargement).

**Affichage des markers :**
Chaque site est représenté par un **marker coloré** dont la couleur reflète son **statut de couverture du jour** :
- 🟢 **Vert** : couverture OK (besoin contractuel rempli)
- 🟠 **Orange** : tendu (couverture partielle, au moins un shift manquant)
- 🔴 **Rouge** : découvert (sous-effectif critique, action immédiate requise)
- ⚫ **Gris** : site Suspendu ou Fermé

Un marker spécial 🔵 distingue la **Centrale**.

**Infobulle au clic sur un marker :**
- Code et nom du site (ex : `AFD1 — Agence Française de Développement`)
- Client, zone, brigade
- Statut de couverture du jour avec détail (ex : `Couverture : 70% — 1 jour manquant`)
- Effectif planifié actuel
- 2 boutons d'action :
  - `Ouvrir planning` → redirige vers la grille de planning du site
  - `Voir pointage` → redirige vers l'écran Pointage bureau filtré sur ce site

**Vue globale :**
- Compteurs résumés en haut : `28 sites · 22 OK · 4 tendus · 2 découverts`
- Centrage initial : sur Nouakchott (capitale de KINGS-MRT)
- Zoom adaptatif selon les filtres appliqués

**Performance :**
- Rendu cible : **< 1,5 s** pour afficher 50 markers.
- Pas de clustering nécessaire en Phase 1 (volume de sites raisonnable), à ajouter si KINGS-MRT dépasse 100 sites.

---

## 4. Pointage Bureau & Synchronisation Automatique

Cet écran permet aux opérateurs de bureau d'acter quotidiennement la réalité du terrain.

### 4.1 Interface

- **Vue Liste filtrée & triée** : Interface claire, filtrable et triable par : Date, Site, Client, Zone géographique, Brigade.
- **Saisie graphique ultra-rapide** : Bouton à bascule (Toggle) graphique **"Présent / Absent" (Vert/Rouge)** permet de pointer un agent en un seul clic.
- **Horodatage (Prêt pour Phase 2)** : Le champ "Heure d'arrivée exacte" (ex : `07:55`) est visible mais non requis en Phase 1 (sera automatisé par le mode Kiosk mobile).

### 4.2 Règles de synchronisation Pointage ↔ Planning *(consolidées)*

| Cas | Code planifié | Action opérateur | Résultat |
|---|---|---|---|
| 1 | `J` | Pointe **Présent** | La case planning reste `J`. Aucune modification. Pointage enregistré. |
| 2 | `N` | Pointe **Présent** | La case planning reste `N`. Aucune modification. Pointage enregistré. |
| 3 | `J` ou `N` | Pointe **Absent** + sélectionne motif (A/RM/C/P/MP) | **Écrasement** de la case planning avec le nouveau code. Audit trail natif Odoo conserve la valeur précédente. |
| 4 | *(vide)* | Tentative de pointage | **Refus** avec message : "Aucune ligne de planning ne couvre ce jour. Créez d'abord la ligne dans la grille de planning." |

L'écrasement (cas 3) ouvre un **menu déroulant strict** listant les codes d'absence configurés dans `sec.code_vacation` (catégories `absence_justifiee`, `absence_non_justifiee`, `sanction`).

➡️ **Zéro double saisie** : la modification du pointage déclenche automatiquement la mise à jour de la grille de planning. L'auditabilité est garantie par le chatter natif d'Odoo, qui trace l'auteur, la date et la valeur précédente.

### 4.3 Cycle de vie d'un pointage : modifiable, jamais supprimable *(nouveau)*

Pour garantir l'intégrité de l'audit paie et éviter toute manipulation a posteriori, les pointages enregistrés suivent une règle stricte d'**immuabilité partielle** :

**✅ Ce qui est autorisé (Opérateur, tant que la période est ouverte) :**
- Modifier le `code_realise` : Présent ↔ Absent, ou changement de motif d'absence (A → RM, par exemple).
- Modifier l'heure d'arrivée (Phase 2 Kiosk).
- Ajouter un commentaire dans le chatter du pointage.

Chaque modification est tracée dans le chatter natif (`mail.thread`) : auteur, date, ancienne valeur, nouvelle valeur.

**❌ Ce qui est interdit (à tous les profils, Administrateur compris) :**
- **Supprimer physiquement** un pointage existant.
- **Désactiver** un pointage via `active = False` (le champ `active` n'est pas exposé sur `sec.pointage`).
- Modifier rétroactivement un pointage rattaché à une `sec.planning_periode` en état `closed` ou `exported`.

**Conséquences fonctionnelles :**
- L'opérateur qui veut "annuler" un pointage erroné doit en réalité le **corriger** (ex : passer de Présent → Absent avec motif `A`). La trace de l'erreur reste visible dans le chatter.
- Pour retirer un agent d'un site (cf §3.7), il faut d'abord **corriger** tous ses pointages en cohérence avec l'absence ; la suppression de la ligne planning reste impossible tant que des pointages existent — mais comme ils sont immuables, ils continueront à exister même après désactivation de la ligne planning.
- Si un pointage a été créé par erreur sur le mauvais agent (cas rare : confusion de matricule), seul un **Administrateur** peut effectuer une **opération de correction comptable** : créer un pointage compensatoire sur le bon agent et marquer le pointage erroné via un commentaire explicite dans le chatter. Aucune suppression physique n'est jamais effectuée.

Cette règle est conforme aux exigences de traçabilité comptable pour les sociétés de gardiennage soumises à audit (Inspection du Travail, contrôles clients).

### 4.4 Pointage en masse par site *(nouveau)*

Pour répondre au cas d'usage réel — un opérateur peut avoir 150+ agents à pointer le matin et 90% d'entre eux sont effectivement présents — un mécanisme de **pointage en masse limité au périmètre d'un site** est proposé.

**Bouton `[✓ Tout présent]` en en-tête de chaque carte/groupe site :**
- Marque tous les agents de **ce site uniquement** (ceux affichés sous l'en-tête concerné) comme `Présent` en une seule action.
- N'agit **jamais** sur la liste complète, même filtrée. Le périmètre est strictement le site visible. Cela force l'opérateur à valider site par site, en pleine conscience de ce qu'il actionne.
- Ne s'applique qu'aux pointages en état `pending` (non encore saisis) ; les pointages déjà enregistrés (Présent ou Absent) ne sont **jamais écrasés**.
- Affiche un **récapitulatif de confirmation** avant exécution :
  > *« Vous allez pointer N agent(s) du site [AFD1] comme Présents. Cette action est tracée. Confirmer ? »*

**Workflow type :**
1. L'opérateur clique sur `[✓ Tout présent]` du site AFD1 → confirme.
2. Les agents pending de ce site passent en Présent (90% des cas).
3. L'opérateur passe en revue les **exceptions** et bascule manuellement les Absents avec leur motif.
4. Il répète pour les sites suivants (BCM2, etc.).

**Auditabilité (importante) :**
Chaque pointage de masse génère :
- Une entrée dans le **chatter de chaque pointage individuel concerné** : *« Pointage créé via opération de masse par [Opérateur] le [Date Heure] »*.
- Une entrée dans un **journal d'opérations de masse** (modèle léger `sec.mass_pointage_log` : opérateur, date/heure, site_id, nb_agents_concernés) pour permettre le reporting des pratiques de pointage. Utile pour la Direction (suivi qualité) et l'audit interne.

**Sécurité (droits) :**
- Disponible pour les profils **Opérateur** et **Planificateur** (limité à leurs périmètres respectifs).
- Désactivé si la `sec.planning_periode` est en état `closed` ou `exported`.
- Pas de bouton "Tout présent global" (multi-sites) : volontairement absent, pour éviter tout pointage automatique aveugle.

### 4.5 Redéploiement d'un agent Centrale vers un site client *(refondu v6.5)*

Quand un agent défaille sur un site client (absent, retard critique, no-show), le système permet de **redéployer un agent de la Centrale** (cf §2.13) pour combler la défaillance en temps réel, via un **mécanisme dédié** s'appuyant sur le modèle `sec.redeploiement_log` (cf §2.14).

**Workflow type :**
1. L'opérateur constate l'absence sur l'écran Pointage bureau (ex : Mamadou Ba absent à AFD1).
2. Il pointe Mamadou Ba en `Absent` avec motif (ex : `A` ou `RM`).
3. Le système détecte le trou de couverture créé et propose un bouton **"🔁 Redéployer depuis la Centrale"** à côté de la ligne d'absence.
4. Le clic ouvre une **modale de sélection** listant les agents Centrale du jour disponibles :
   - Planifiés sur le même shift (J ou N) que le poste à combler
   - Non encore redéployés ce jour (un agent = un redéploiement max par jour)
   - Qualification compatible (`hr.job` matching `sec.poste.job_id` du site cible)
   - Pas dans `site_interdit_ids` du site cible (cf §2.2)
5. L'opérateur sélectionne un agent, saisit optionnellement un motif texte, confirme.
6. Le système exécute en transaction :
   - Crée un nouveau `sec.redeploiement_log` (statut = `en_cours`, lien vers la ligne Centrale d'origine).
   - Pose le `redeploiement_actif_id` sur la `sec.planning_ligne` Centrale (la ligne reste intacte mais est désormais "neutralisée" côté Centrale).
   - Crée un `sec.pointage` sur le site cible (état `pending`, prêt à être validé) avec lien vers le log.
   - Recalcule les couvertures Centrale et site cible.
7. La grille planning est resynchronisée :
   - Sur la carte Centrale : case du jour grisée/barrée avec libellé "→ AFD1".
   - Sur la carte AFD1 : nouvelle ligne agent avec badge Flotteur 🌊.

**Verrous serveurs :**
- Refus si aucun agent Centrale disponible pour le shift demandé (J ou N) → message contextuel : *"Aucun agent Centrale disponible pour ce shift. Soit la Centrale est vide, soit tous les candidats ont une qualification ou une restriction incompatible. Solution : appeler un agent de repos ou ajuster manuellement le planning."*
- Refus si la `sec.planning_periode` du site cible est `closed` ou `exported`.
- Refus si l'agent sélectionné a déjà un `sec.redeploiement_log` actif (`statut != 'annule'`) ce même jour.

**Cycle de vie du redéploiement :**
- À la création : `statut = 'en_cours'`.
- Dès qu'un pointage `Présent` ou `Absent` est enregistré sur le site cible pour cet agent ce jour : passage automatique à `statut = 'termine'`.
- Annulation (`statut = 'annule'`) : réservée à l'Administrateur, possible uniquement tant qu'aucun pointage effectif n'a été saisi. L'annulation :
  - Retire le `redeploiement_actif_id` de la ligne Centrale (qui redevient comptante pour la couverture Centrale).
  - Supprime le pointage `pending` créé sur le site cible.
  - Tracé dans le chatter avec motif obligatoire.

**Alerte "Centrale vide" :**
Dès qu'un redéploiement fait basculer le compteur Centrale d'un shift à 0 agents disponibles, une alerte spéciale remonte dans le bandeau d'alertes (Direction + Planificateur) : *"Centrale vide (Jour)"* ou *"Centrale vide (Nuit)"*. Signifie : plus aucune capacité de réaction immédiate pour ce shift.

---

## 5. Groupes d'Accès et Sécurité (5 Profils) *(refondu v6.6)*

KINGS-MRT structure ses utilisateurs en **5 profils** correspondant à sa hiérarchie organisationnelle. Chaque profil bénéficie d'un **dashboard d'accueil dédié** (cf §3.8) et de droits d'accès strictement délimités via `record rules` Odoo.

| Profil | Description métier | Périmètre fonctionnel |
|---|---|---|
| **Administrateur** | Directeur RH ou son adjoint direct. Garant de la cohérence globale du système. | Accès total à l'application, configuration des paramètres (`sec.code_vacation`, `sec.poste`, sites, rythmes, composition Centrale), gestion des utilisateurs et des profils, export de la paie, réouverture de périodes clôturées (avec motif obligatoire), accès complet aux journaux d'audit et reporting. |
| **Planificateur** | Personnel qui **crée les plannings** et **valide les pointages**. Dépend directement de l'Administrateur. | Accès complet (CRUD) à la Grille de Planning globale, affectation des agents, gestion des filtres, gestion des redéploiements Centrale, validation des pointages remontés par les Superviseurs, lecture complète des dashboards et alertes, accès à la carte interactive. Pas d'accès à la config des codes ni à la réouverture de périodes. |
| **Opérateur** | Personnel qui **suit les événements en temps réel** via la main courante (§3.9) et la gestion des incidents bureau. **Visibilité globale par défaut** (tous sites, toutes zones, toutes brigades). Plusieurs opérateurs peuvent travailler en rotation. | Vue temps réel de **l'ensemble des sites** (filtres optionnels pour zoomer sur une zone, un client ou une brigade), lecture de la main courante, saisie de notes manuelles, déclenchement d'incidents bureau, déclenchement de redéploiements Centrale en urgence, vue Centrale (pas de Sans affectation pure). **Vue en lecture seule** sur la grille de planning. |
| **Superviseur** | Personnel **terrain** qui effectue les **rondes** sur les sites, **pointe les agents** (constate la présence conformément au planning) et **signale les anomalies** (incidents). | Phase 1 : visibilité restreinte aux sites de sa brigade, saisie de pointages depuis poste fixe en lecture/écriture sur sa brigade uniquement. Phase 2 : saisie mobile sur tablette/smartphone avec géolocalisation, pointage par scan QR/badge, signalement d'incident en temps réel via bus.bus. |
| **Agent** *(nouveau v6.6)* | **Personnel terrain** qui effectue le service de gardiennage sur les sites. À terme (Phase 2), pourra s'auto-pointer et remonter des alertes depuis son téléphone. | Phase 1 : **groupe technique créé** mais sans interface dédiée. Accès strict en **lecture seule** à ses propres données : son planning prévisionnel, ses pointages réalisés, son historique de période, ses compteurs (TST, congés, absences). Aucune visibilité sur les autres agents ni sites où il n'est pas affecté. Phase 2 : application mobile dédiée pour auto-pointage, signalement d'incident, notes d'information, demandes particulières (à définir précisément en Phase 2). |

**Hiérarchie organisationnelle :**
```
Administrateur (Directeur RH ou adjoint)
    └── Planificateur (équipe planning)
    └── Opérateur (suivi bureau temps réel)
    └── Superviseur (rondes terrain)
            └── Agent (gardiennage sur site)
```

**Règles techniques d'accès :**
- Conformité Odoo 19 : les groupes utilisent le champ `group_ids` et `privilege_id` (et non plus `groups_id` / `category_id`, obsolètes).
- `record rules` strictes pour le Superviseur (`brigade_id = user.brigade_id`) et l'Agent (`agent_id = user.employee_id`) : ces deux profils ne voient **rien** au-delà de leur périmètre, même par accès direct à une URL.
- Le profil Agent étant créé dès la Phase 1 pour anticiper la Phase 2 (Q3 v6.6 = a), les 570 agents existants seront tous rattachés au groupe Agent lors du script de migration depuis Excel. Cela évite une opération RH lourde de masse en Phase 2.

---

## 6. Fin de Période & Exports

### 6.1 Calculateurs de fin de ligne
En bout de grille de planning, calcul automatique à la volée :
- **TST** (Total Shifts Travaillés) : somme des codes dont `est_travaille = True` (typiquement J + N).
- Compteur **C** (Congés), **A** (Absences non justifiées), **RM**, **P**, **MP**.
- Tous ces compteurs sont **basés sur le réalisé** (issu de `sec.pointage`), pas sur le prévisionnel initial.

### 6.2 Wizard d'export — Deux formats disponibles

**Format 1 : CSV "Sage Paie"** (usage interne RH)
Fichier CSV formaté pour Sage Paie selon la période définie sur la fiche du site (ex : du 24 au 23). Colonnes :
```
MATRICULE, NOM, PRENOM, TST, NB_CONGES, NB_RM, NB_ABSENCES, NB_PERMISSIONS, NB_MP
```

**Format 2 : CSV "Audit Client"** *(nouveau — usage facturation / réponse client)*
Détail jour par jour des vacations facturées sur un site, pour répondre aux questions client type *« vous nous facturez quoi ce mois-ci ? »*. Colonnes :
```
DATE, SITE_CODE, SITE_NOM, AGENT_MATRICULE, AGENT_NOM, CODE_VACATION, HEURES, STATUT (Fixe/Remplaçant/Flotteur), REDEPLOYE_DEPUIS
```

⚠️ **Règle de facturation Centrale** : ce CSV **exclut automatiquement les sites avec `is_facturable = False`** (typiquement la Centrale elle-même). En revanche, les agents Centrale **redéployés sur un site client** apparaissent normalement dans le CSV de ce site client, avec :
- Statut = `Flotteur`
- `REDEPLOYE_DEPUIS` = `Centrale` (colonne dédiée pour transparence client)

C'est ainsi que la Centrale devient un poste rentable : les agents redéployés sont facturés au site bénéficiaire (cf §2.13).

Le wizard d'export verrouille automatiquement la `sec.planning_periode` correspondante en état `exported` après génération réussie du fichier.

### 6.3 Reporting des redéploiements Centrale *(refondu v6.5)*

Un rapport dédié à la Direction permet de mesurer l'**activité de la Centrale** sur une période donnée. Accessible depuis `Reporting → Activité Centrale`. **Source unique de données** : le modèle `sec.redeploiement_log` (cf §2.14), interrogé par agrégation SQL pour performance.

**Indicateurs clés :**
- **Nombre total de redéploiements** sur la période, segmenté Jour / Nuit, statuts `termine` vs `annule`.
- **Top 10 des sites bénéficiaires** (qui consomme le plus de la Centrale → indicateur de fragilité d'un contrat ou d'une équipe).
- **Top 10 des agents Centrale les plus mobilisés** (utile pour le management RH : un agent Centrale redéployé quotidiennement mérite peut-être une promotion en titulaire).
- **Jours de "Centrale vide"** : périodes où le pool a atteint zéro disponible (Jour ou Nuit), avec durée — indicateur de risque opérationnel critique.
- **Heures travaillées par agents Centrale sur sites clients** (volume facturable généré par le pool → indicateur de rentabilité de la Centrale).
- **Délai moyen entre absence constatée et redéploiement effectué** (réactivité opérationnelle des équipes pointage).

**Export CSV disponible** pour analyse externe (Excel, BI tools).

---

## 7. Notes Techniques d'Architecture (Normes Odoo 19)

Les développeurs devront impérativement respecter les changements de syntaxe de la version 19 d'Odoo :

- Les vues listes doivent utiliser la balise `<list>` (et non plus `<tree>`).
- Le mode d'affichage dans les actions doit être écrit `view_mode='list,form'`.
- Les contraintes serveurs doivent utiliser la nouvelle syntaxe `models.Constraint('...', '...')` avec un nom commençant obligatoirement par un underscore `_`.
- Les groupes d'accès doivent utiliser le champ `group_ids` (et non plus `groups_id`), et les privilèges se configurent via `privilege_id` (la balise `category_id` étant obsolète).
- L'intégration du fil de discussion et de l'historique d'audit se fait via la nouvelle balise simplifiée `<chatter/>`.
- Les attributs conditionnels utilisent la syntaxe directe `invisible="..."`, `readonly="..."`, `required="..."` (et non plus le dict `attrs`).
- `name_get()` est remplacé par `_compute_display_name()`.

---

## 8. Récapitulatif des arbitrages v6.0 (par rapport à v5.0)

| # | Sujet | Décision v6.0 |
|---|---|---|
| 1 | Pointage Présent sur ligne planifiée J/N | Conserve le code planifié, pas de modification. |
| 2 | Pointage sans ligne de planning | **Refusé.** Pas de case vide tolérée. Badge ⚠️ en bas de colonne. |
| 3 | Pointage Absent sur ligne J/N | **Écrasement** avec audit trail natif Odoo (chatter). |
| 4 | Contrôle couverture | **Jour-par-jour**, pas en volume période. |
| 5 | Statut Flotteur | **Hybride** : rôle structurel sur `hr.employee` ET tag ponctuel sur `sec.planning_ligne`. |
| 6 | Période glissante 24→23 | Grille **alignée sur la période du site**. |
| 7 | Changement de `job_id` en cours de période | **Dénormalisation `job_id_snapshot`** sur `sec.planning_ligne`. |
| 8 | Performance OWL | **Rendu virtualisé obligatoire** + benchmarks cibles formalisés. |
| 9 | Cycle de vie période | Nouveau modèle **`sec.planning_periode`** avec états et verrous. |
| 10 | Découverts | Nouveau **widget d'alertes** trié par urgence (J+0, J+1, J+2). |
| 11 | Codes de vacation | Nouveau modèle **`sec.code_vacation`** configurable, fini le hardcoding. |
| 12 | Anti-fatigue N→J | **Non retenu** en Phase 1 (peut être ajouté en Phase 2). |
| 13 | Exports Sage | **Deux formats** : Sage Paie + Audit Client. |
| 14 | Accessibilité daltonienne | **Icône + lettre** sur chaque badge, en plus de la couleur. |
| 15 | Préparation Phase 2 mobile | **Exigences concrètes** formalisées dès Phase 1 (API REST, UUID, token). |
| 16 | Suppression d'une ligne agent | **Verrou strict** si pointage existant ; **confirmation** si vacations planifiées ; **désactivation logique** (`active=False`) ; **recalcul couverture** immédiat. |
| 17 | Cycle de vie d'un pointage | **Modifiable** (Présent ↔ Absent, motif) tant que période ouverte ; **jamais supprimable** ni désactivable. Correction comptable réservée à l'Administrateur via pointage compensatoire. |
| 18 | Pointage en masse | Bouton `[✓ Tout présent]` **par site uniquement** (pas global) ; agit sur pending uniquement ; confirmation obligatoire ; audit chatter + journal `sec.mass_pointage_log`. |
| 19 | Date comptable shift de nuit | **Date de prise de poste** (un N le 27→28 est rattaché au 27). Convention gardiennage standard. |
| 20 | Dashboards par profil | **4 dashboards distincts** (Direction, Planificateur, Opérateur, Superviseur). Auto-refresh 30s en Phase 1, bus.bus en Phase 2. |
| 21 | KPI Sites incomplets | **Vue agrégée** du widget d'alertes §3.2 (pas de redondance de logique). |
| 22 | Trends KPI | **Flèche ↑↓→ + %** vs période précédente (pas de sparkline Phase 1). |
| 23 | Incidents terrain | Modèle `sec.incident` **amorcé Phase 1** (saisie bureau), exploité pleinement Phase 2 (mobile + bus.bus). |
| 24 | Concept Centrale | **Site interne unique** (`is_centrale=True`, `is_facturable=False`), pool de réserve KINGS-MRT, payé en interne mais facturable au client après redéploiement. |
| 25 | Composition Centrale | **6J + 6N en semaine, 8J + 8N le week-end** (configurable admin). |
| 26 | Contrôle couverture Centrale | **Strict comme tout site client** (✓/⚠️/✖ jour-par-jour). Alerte spéciale "Centrale vide" quand 100% redéployé. |
| 27 | Mécanisme redéploiement | **Modèle dédié `sec.redeploiement_log`** (option Q-bis-3). Ligne planning Centrale **non détruite**, flaggée via `redeploiement_actif_id`. Audit complet. |
| 28 | Affichage agent redéployé | **Visible uniquement sur site cible** (option α). Case Centrale grisée avec libellé "→ AFD1". |
| 29 | Couverture Centrale post-redéploiement | Agent redéployé **ne compte plus** pour la couverture Centrale (option δ). Découvert visible immédiatement. |
| 30 | Carte interactive sites | **OpenStreetMap + Leaflet.js**, markers colorés par couverture (vert/orange/rouge), filtres client/zone/brigade, infobulle avec actions. |
| 31 | KPI Sites incomplets — période ciblée | Sélecteur de période (par défaut **prochaine période en élaboration**, pas mois en cours) — plus pertinent métier. |
| 32 | Donut Pointage J-1 | **Date affichée explicitement** (ex : "Pointage du mardi 26 mai") pour éviter confusion tant que pointage manuel. |
| 33 | Pool de réserve | **Décomposé en 2 blocs** : 🟦 Centrale (planifiés réserve), ⬜ Sans affectation pure (banc). |
| 34 | Alertes du jour | **4 catégories** (Urgent / Attention / Incidents / Centrale vide) + placeholder Phase 2 documents. |
| 35 | Référentiel codes vacation | **25 codes** chargés en données initiales (référentiel officiel KINGS-MRT). Flag `is_actif` pour activation/désactivation sans suppression. |
| 36 | Code Shift Soir `S` | Nouveau code pour rythme S8 (3 shifts de 8h Jour/Soir/Nuit). Heures = 8.0 vs 12.0 pour J/N S12. |
| 37 | Demi-shifts EJ/EN | Codes distincts pour demi-shift Jour et demi-shift Nuit (6h chacun). |
| 38 | États site `PF`/`PS` | Phase 1 : saisis case par case dans la grille (Q3 = γ). Action de masse en Phase 2. |
| 39 | Rythmes standardisés | **8 rythmes** standardisés (`H24 7/7 S12`, `H12 7/7 S12 J`, `H12 7/7 S12 N`, `H12 5/7 S12 J`, `H12 5/7 S12 N`, `H24 7/7 S8`, `H8 5/7 S8 J`, `H8 5/7 S8 N`). Convention de nommage : volume / fréquence / shift. |
| 40 | Couverture week-end 5/7 | **Case neutre grise** "Non couvert (5/7)" pour Sam-Dim sur rythmes 5/7 — ni ✓ ni ⚠️ (Q2 v6.6). |
| 41 | 5ème profil "Agent" | Groupe technique créé en Phase 1 (lecture seule sur ses propres données), interface mobile dédiée en Phase 2. Tous les 570 agents rattachés via script de migration. |
| 42 | Hiérarchie organisationnelle | Admin → Planificateur / Opérateur / Superviseur → Agent. Précisions métier par profil intégrées au §5. |
| 43 | Définition AT KINGS-MRT | **N'est PAS un arrêt maladie** (qui est codé `RM`). C'est un statut RH suspensif déclenché par absence prolongée sans signe de vie. Non rémunéré. |
| 44 | Détection automatique AT | **Cron quotidien** détecte 2+ jours `A` consécutifs (seuil configurable via `at_seuil_jours_consecutifs`). Crée des propositions à valider par les RH. Semi-automatique (Q1=b). |
| 45 | Seuil AT configurable | Paramètre admin `at_seuil_jours_consecutifs`, défaut 2 (Q2). |
| 46 | Sortie du statut AT | **Action RH explicite obligatoire** (Q3=γ) via wizard `Clôturer un Arrêt de travail` : Réintégration / Licenciement (`L`) / Démission constatée (`D`). Pas de retour silencieux à la planification. |
| 47 | Alerte AT au dashboard | **5ème catégorie d'alerte** 🟫 "AT à traiter" sur le bandeau Direction (Q4=oui). Catégorie "Congés simultanés" supprimée (non pertinente). |
| 48 | Modèle `sec.at_proposition` | Nouveau modèle léger pour gérer les propositions AT en attente de décision RH. Cf §2.15. |
| 49 | Filtres multi-sélection disponible partout | **Règle UI globale** : tous les filtres de l'application acceptent **plusieurs valeurs simultanément** (tag picker / chips) **en option**. Mono ou multi-sélection au choix de l'utilisateur. Combinaison ET entre filtres, OU au sein d'un même filtre. |
| 50 | Verrou anti-doublon : exception redéploiement | Un agent peut apparaître sur 2 sites le même jour **uniquement** si la ligne d'origine est neutralisée par un `redeploiement_actif_id`. Tout autre doublon reste strictement bloqué. Test recette prioritaire. |
| 51 | Dashboard Opérateur sans mosaïque | Composition finale validée : KPI + carte OSM + aperçu main courante + raccourcis. Pas de mosaïque de tuiles (redondant avec la carte). Visibilité globale par défaut, filtres optionnels pour zoomer. |
| 52 | Architecture Poste refactorisée (v6.6a-rev10) | Séparation métier : `sec.poste_type` (ADS, SUP, CP) + `sec.shift_pattern` (H24-S12-7/7, etc.) + `sec.poste` (lien site + type + pattern). Élimine la confusion entre qualification et horaires. |

---

## 9. Livrables Phase 1 attendus

1. Module Odoo 19 `guard_security` installable sur instance fresh.
2. Données initiales (`sec.code_vacation`) chargées via XML.
3. Tests unitaires Python couvrant les verrous serveurs (anti-doublon, restriction site, période clôturée).
4. Tests d'intégration sur la synchro pointage ↔ planning.
5. Composant OWL `GuardPlanningGrid` virtualisé, avec benchmark mesuré.
6. Documentation utilisateur (PDF) : 1 manuel par profil (Planificateur, Opérateur, Admin).
7. Documentation API OpenAPI des endpoints `/api/v1/*`.
8. Script de migration depuis Excel (one-shot, pour reprise des données existantes KINGS-MRT).

---

*Document validé le 21 mai 2026 — prêt pour kickoff développement.*
