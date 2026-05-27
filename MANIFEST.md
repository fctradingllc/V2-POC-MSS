# 🚀 Development Manifest — guard_security Module (Odoo 19 Community)

**Project:** Module custom `guard_security` pour KINGS-MRT  
**Platform:** Odoo 19 Community / GitHub Codespace  
**Duration:** Phase 1 (PC Bureau) — Planning & Pointage  
**Status:** Ready for autonomous development with Claude Code

---

## 📋 Table des matières

1. [Environnement & Setup](#environnement--setup)
2. [Architecture des modèles](#architecture-des-modèles)
3. [Modèles à implémenter](#modèles-à-implémenter)
4. [Vues & Formulaires](#vues--formulaires)
5. [Wizards](#wizards)
6. [Données initiales](#données-initiales)
7. [Tests & Validation](#tests--validation)
8. [Checklist développement](#checklist-développement)

---

## Environnement & Setup

### GitHub Codespace Configuration

**Pré-requis** :
- Python 3.10+
- PostgreSQL 12+
- Git

**Étapes installation** :

```bash
# 1. Clone repo (si applicable)
git clone <REPO_URL> guard_security
cd guard_security

# 2. Create virtual environment
python3 -m venv venv
source venv/bin/activate

# 3. Install Odoo 19 & dependencies
pip install odoo==19.0.1.0
pip install psycopg2-binary python-dateutil pytz requests

# 4. PostgreSQL setup (local or via service)
# Ensure PostgreSQL is running
createdb guard_security_db

# 5. Initialize Odoo
odoo -d guard_security_db --addons-path=<ADDONS_PATH> --init=guard_security

# 6. Start server
odoo -d guard_security_db --addons-path=<ADDONS_PATH> --dev=all
```

**Odoo credentials** : 
- URL: http://localhost:8069
- Default user: admin / admin
- Default password: admin

### Module Structure

```
guard_security/
├── __init__.py
├── __manifest__.py
├── models/
│   ├── __init__.py
│   ├── sec_poste_type.py
│   ├── sec_shift_pattern.py
│   ├── sec_site.py
│   ├── sec_poste.py
│   ├── sec_planning_ligne.py
│   ├── sec_planning_periode.py
│   ├── sec_pointage.py
│   ├── sec_code_vacation.py
│   ├── sec_main_courante.py
│   ├── sec_redeploiement_log.py
│   ├── sec_at_proposition.py
│   └── sec_incident.py
├── views/
│   ├── sec_poste_type_view.xml
│   ├── sec_shift_pattern_view.xml
│   ├── sec_site_view.xml
│   ├── sec_poste_view.xml
│   ├── sec_planning_view.xml
│   ├── sec_pointage_view.xml
│   ├── sec_code_vacation_view.xml
│   ├── sec_main_courante_view.xml
│   └── menu.xml
├── wizards/
│   ├── __init__.py
│   └── export_audit_wizard.py
├── data/
│   ├── code_vacation_data.xml
│   ├── shift_pattern_data.xml
│   ├── poste_type_data.xml
│   ├── zone_data.xml
│   └── brigade_data.xml
├── static/
│   └── description/
│       └── icon.png
└── tests/
    ├── __init__.py
    ├── test_models.py
    └── test_wizards.py
```

---

## Architecture des modèles

### Hiérarchie métier

```
res.partner (Client)
  ↓
sec.site (Lieu géographique à sécuriser)
  ├─ Champs : code, name, client_id, zone_id, brigade_id, GPS, is_centrale, is_facturable
  ↓
sec.poste (Affectation Type + Pattern sur un Site)
  ├─ site_id (M2O sec.site)
  ├─ poste_type_id (M2O sec.poste_type)
  ├─ shift_pattern_id (M2O sec.shift_pattern)
  ├─ nb_agents_required (Int)
  ↓
sec.planning_ligne (Affectation agent/site/date/code_vacation)
  ├─ agent_id (M2O hr.employee)
  ├─ site_id (M2O sec.site)
  ├─ date_assignment (Date)
  ├─ code_vacation_id (M2O sec.code_vacation)
  ├─ statut (Fixe / Remplaçant / Flotteur)
  ├─ redeploiement_actif_id (M2O sec.redeploiement_log, nullable)
  ↓
sec.pointage (Réalisation effective agent/site/date)
  ├─ planning_ligne_id (M2O sec.planning_ligne, nullable)
  ├─ agent_id (M2O hr.employee)
  ├─ site_id (M2O sec.site)
  ├─ date_pointage (Date)
  ├─ code_vacation_realise_id (M2O sec.code_vacation)
  ├─ statut (valide / propose)
  ├─ ecart_prevu_realise (Char)
```

---

## Modèles à implémenter

### 1. sec.poste_type — Type de poste

**Champs** :
- `code` (Char, required, unique) : ADS, SUP, CP, etc.
- `name` (Char, required) : Libellé
- `description` (Text, optional)
- `is_active` (Boolean, default=True)
- `created_date` (Datetime, readonly)

**Contraintes** :
- Code unique (SQL constraint)
- Pas de suppression si affectations existantes

**Données initiales** : ADS, SUP, CP, DVN, SC

---

### 2. sec.shift_pattern — Pattern horaires

**Champs** :
- `code` (Char, required, unique) : H24-S12-7/7, H12-S12-5/7, etc.
- `name` (Char, required)
- `shift_duration_hours` (Int, required) : 8, 12, 24
- `days_per_week` (Int, required) : 5, 7
- `nb_agents_required` (Int, required) : nombre d'agents couvrant ce pattern
- `is_active` (Boolean, default=True)

**Données initiales** : 8 patterns KINGS-MRT

---

### 3. sec.site — Lieu géographique

**Champs** :
- `code` (Char, required, unique)
- `name` (Char, required)
- `client_id` (M2O res.partner, required)
- `zone_id` (M2O sec.zone, optional)
- `brigade_id` (M2O sec.brigade, optional)
- `latitude` (Float, optional)
- `longitude` (Float, optional)
- `is_centrale` (Boolean, default=False) : site virtuel (pool réserve)
- `is_facturable` (Boolean, default=True)
- `notes` (Text, optional)

**Contraintes** :
- Code unique par client
- Si is_centrale, zone/brigade nullable

---

### 4. sec.poste — Affectation Type+Pattern sur Site

**Champs** :
- `site_id` (M2O sec.site, required)
- `poste_type_id` (M2O sec.poste_type, required)
- `shift_pattern_id` (M2O sec.shift_pattern, required)
- `nb_agents_required` (Int, computed from shift_pattern_id)
- `notes` (Text, optional)

**Méthodes** :
- `compute_nb_agents_required()` : récupère nb_agents_required de shift_pattern_id
- `name_get()` : return f"{site_code}/{poste_type_code}/{pattern_code}"

**Contraintes** :
- Une seule affectation (Type+Pattern) par Site (SQL unique constraint)

---

### 5. sec.code_vacation — 25 codes RH

**Champs** :
- `code` (Char, required, unique) : J, S, N, EJ, SE, JE, CSP, MS, etc.
- `name` (Char, required)
- `category` (Selection, required) : 'travail', 'absence', 'sanction', 'indicateur'
- `coefficient_tst` (Float, required) : 1.0 (J/S/N/etc), 2.0 (MS/JN), 0.0 (absence/sanction/indicateur)
- `is_billable` (Boolean, required)
- `is_active` (Boolean, default=True)
- `color_hex` (Char, optional) : couleur affichage UI

**Données initiales** : 25 codes (cf. section données)

---

### 6. sec.planning_ligne — Affectation agent/site/date/code

**Champs** :
- `agent_id` (M2O hr.employee, required)
- `site_id` (M2O sec.site, required)
- `date_assignment` (Date, required)
- `code_vacation_id` (M2O sec.code_vacation, required) — code PRÉVU
- `statut` (Selection, required) : 'Fixe', 'Remplaçant', 'Flotteur'
- `redeploiement_actif_id` (M2O sec.redeploiement_log, nullable) : si redéploiement, lien au log
- `notes` (Text, optional)
- `created_date` (Datetime, readonly)
- `last_modified_date` (Datetime, readonly)

**Contraintes** :
- Verrou anti-doublon : agent ne peut apparaître qu'une fois "active" par jour, SAUF si `redeploiement_actif_id` est set
- SQL constraint : UNIQUE(agent_id, date_assignment) WHERE code_vacation != 'A' AND redeploiement_actif_id IS NULL

**Méthodes** :
- `check_agent_availability(agent_id, date)` : vérifie doublon et règles RH
- `get_tst_coefficient()` : retourne coefficient TST du code_vacation_id

---

### 7. sec.pointage — Réalisation effective

**Champs** :
- `planning_ligne_id` (M2O sec.planning_ligne, nullable) : lien au planning
- `agent_id` (M2O hr.employee, required)
- `site_id` (M2O sec.site, required)
- `date_pointage` (Date, required)
- `code_vacation_realise_id` (M2O sec.code_vacation, required) — code RÉALISÉ
- `statut` (Selection, required) : 'valide', 'propose'
- `ecart_prevu_realise` (Char, optional) : description écart (si code_prevu ≠ code_realise)
- `created_by` (M2O res.users, readonly)
- `created_date` (Datetime, readonly)

**Contraintes** :
- Champ `planning_ligne_id` peut être null (pointage manuel)

**Méthodes** :
- `compute_tst()` : retourne coefficient TST du code_vacation_realise_id
- `validate_pointage()` : passe statut de 'propose' à 'valide' (J+1 planificateur)

---

### 8. sec.main_courante — Journal d'événements

**Champs** :
- `event_type` (Selection, required) : 'note', 'redéploiement', 'incident', 'absence_constatee', 'presence_constatee', 'pointage_propose', 'auto_pointage'
- `agent_id` (M2O hr.employee, optional)
- `site_id` (M2O sec.site, optional)
- `date_event` (Datetime, required)
- `description` (Text, required)
- `created_by` (M2O res.users, readonly)
- `related_pointage_id` (M2O sec.pointage, nullable)
- `related_incident_id` (M2O sec.incident, nullable)

---

### 9. sec.redeploiement_log — Historique redéploiements

**Champs** :
- `agent_id` (M2O hr.employee, required)
- `site_origin_id` (M2O sec.site, required)
- `site_destination_id` (M2O sec.site, required)
- `date_redeploiement` (Date, required)
- `raison` (Text, required)
- `statut` (Selection, required) : 'proposed', 'executed', 'cancelled'
- `created_by` (M2O res.users, readonly)
- `created_date` (Datetime, readonly)

---

### 10. sec.at_proposition — Proposition AT auto-détection

**Champs** :
- `agent_id` (M2O hr.employee, required)
- `date_debut_sequence` (Date, required)
- `nombre_jours_consecutifs_a` (Int, required) : 2, 3, etc.
- `seuil_config` (Int, readonly) : seuil configuré
- `statut` (Selection, required) : 'proposition', 'approuvee', 'rejetee'
- `created_by` (M2O res.users, readonly) : cron system user
- `created_date` (Datetime, readonly)

---

### 11. sec.incident — Signalements incidents

**Champs** :
- `code` (Char, readonly, auto-generated) : INC-001, INC-002, etc.
- `agent_id` (M2O hr.employee, required)
- `site_id` (M2O sec.site, required)
- `date_incident` (Datetime, required)
- `description` (Text, required)
- `severite` (Selection, required) : 'low', 'medium', 'high', 'critical'
- `statut` (Selection, required) : 'new', 'in_progress', 'resolved', 'closed'
- `created_by` (M2O res.users, readonly)
- `assigned_to` (M2O res.users, optional)

---

### 12. sec.planning_periode — Cycle planning

**Champs** :
- `name` (Char, required) : "Planning Mai 2026"
- `date_start` (Date, required)
- `date_end` (Date, required)
- `statut` (Selection, required) : 'draft', 'open', 'closed', 'exported'
- `notes` (Text, optional)

---

## Vues & Formulaires

### Champs additionnels hr.employee (onglets custom)

**Onglet 1 : Gardiennage**
- `type_poste_id` (M2O sec.poste_type) : type de poste agent
- `sites_interdits_ids` (M2M sec.site) : sites interdits + motif
- `formations_requises` (One2many, custom model sec.agent_formation)
- Statut sanction RH (L, MP, D, AT) : champs read-only alimentés automatiquement

**Onglet 2 : Historique** (read-only)
- Planning 30 derniers jours (liste sec.planning_ligne)
- Pointage 10 derniers jours (graphique codes)
- Incidents (liste sec.incident)

### Formulaires Odoo

**1. sec.poste_type — Form/List**
- Colonnes LIST : Code, Libellé, Statut
- Form : Code + Libellé + Description + Active (checkbox)

**2. sec.shift_pattern — Form/List**
- Colonnes LIST : Code, Libellé, Agents requis, Statut
- Form : Code + Libellé + Shift duration + Days/week + Agents requis + Active

**3. sec.site — Form/List**
- Colonnes LIST : Code, Nom, Client, Zone, Brigade, Facturable
- Form : 6 onglets (Identité, Postes, Planning, Contacts, SLA, Agents interdits)

**4. sec.poste — Form/List**
- Colonnes LIST : Site, Type, Pattern, Agents requis
- Form : Site + Type + Pattern + Agents requis (auto) + Notes

**5. sec.planning_ligne — Form/List (Vue Planning unifiée)**
- Grille horizontale : dates (colonnes) × agents (lignes)
- Code vacation affiché, couleurs par catégorie
- Frontière temporelle bleue pour jour J
- Bandeau contextuel dynamique

**6. sec.pointage — Form/List**
- Colonnes LIST : Agent, Site, Date, Code Prévu, Code Réalisé, Écart, Statut
- Form : Affectation + Code réalisé + Écart description + Valider (button)

**7. sec.code_vacation — Form/List**
- Colonnes LIST : Code, Libellé, Catégorie, Coefficient TST, Facturable
- Form : Code + Libellé + Catégorie + **Coefficient TST** (éditable) + Facturable + Active
- Info-box explicative TST dans form

**8. sec.main_courante — Form/List**
- Colonnes LIST : Date, Type événement, Agent, Site, Description
- Form : Type + Agent + Site + Date + Description + Lien incident (si applicable)

---

## Wizards

### Wizard Export Audit

**Fichier** : `wizards/export_audit_wizard.py`

**Étapes** :
1. **Paramètres export** : Période (de/à) + Client (opt) + Site (opt) + Filtre agents
2. **Sélection données** : Inclure agents actifs / inactifs, exclure licenciés
3. **Aperçu & export** : 
   - Tableau par agent (Travail 11 codes + TST + Absence 5 codes + Sanction 4 + Indicateurs 4)
   - Colonnes Absence/Sanction affichées ssi total > 0
   - Format CSV ou XLSX

**Formule TST (Python)** :
```python
def compute_tst(planning_lines):
    travail_codes = ['J', 'S', 'N', 'EJ', 'SE', 'JE', 'CSP', 'REMPL,C', 'REMPL,PIP']
    tst = sum(coeff for code, coeff in planning_lines if code in travail_codes)
    # MS et JN comptent pour 2
    tst += sum(2 for code, _ in planning_lines if code in ['MS', 'JN'])
    return tst
```

---

## Données initiales

### Code Vacation (25 codes)

```xml
<!-- data/code_vacation_data.xml -->
<record model="sec.code_vacation" id="code_j">
    <field name="code">J</field>
    <field name="name">Jour</field>
    <field name="category">travail</field>
    <field name="coefficient_tst">1.0</field>
    <field name="is_billable">True</field>
    <field name="color_hex">#1D9E75</field>
</record>
<!-- ... 24 autres codes ... -->
```

### Shift Patterns (8 patterns)

```xml
<!-- data/shift_pattern_data.xml -->
<record model="sec.shift_pattern" id="pattern_h24_s12_7_7">
    <field name="code">H24-S12-7/7</field>
    <field name="name">24h/jour, shift 12h, 7j/7</field>
    <field name="shift_duration_hours">12</field>
    <field name="days_per_week">7</field>
    <field name="nb_agents_required">3</field>
</record>
<!-- ... 7 autres patterns ... -->
```

### Poste Types (5 types)

```xml
<!-- data/poste_type_data.xml -->
<record model="sec.poste_type" id="type_ads">
    <field name="code">ADS</field>
    <field name="name">Agent de Sécurité</field>
    <field name="description">Agent responsable sécurité sites</field>
</record>
<!-- ... SUP, CP, DVN, SC ... -->
```

---

## Tests & Validation

### Structure test

```python
# tests/test_models.py

from odoo.tests import TransactionCase, tagged

@tagged('guard_security', 'models')
class TestSecPosteType(TransactionCase):
    def setUp(self):
        super().setUp()
        self.poste_type = self.env['sec.poste_type'].create({
            'code': 'ADS',
            'name': 'Agent de Sécurité'
        })
    
    def test_create_poste_type(self):
        """Test création type de poste"""
        self.assertEqual(self.poste_type.code, 'ADS')
        self.assertTrue(self.poste_type.is_active)
    
    def test_unique_code(self):
        """Test contrainte unique code"""
        with self.assertRaises(IntegrityError):
            self.env['sec.poste_type'].create({
                'code': 'ADS',
                'name': 'Autre'
            })
```

### Cas de test critiques

1. **Verrou anti-doublon** : agent ne peut apparaître 2x active/jour sauf redéploiement
2. **Redéploiement atomique** : 3 étapes ou rollback complet
3. **TST computation** : J + S + N + EJ + SE + JE + CSP + (MS×2) + REMPL,C + REMPL,PIP + (JN×2)
4. **Coefficient TST éditable** : champ code_vacation peut avoir coefficient custom
5. **Règles RH Phase 2** : Agent L/MP/AT/C ne peut être planifié selon règles

---

## Checklist développement

### Phase 1 : Modèles (2-3 jours)

- [ ] Créer `__manifest__.py` (name, version, depends, data)
- [ ] Implémenter 12 modèles (models/*.py)
- [ ] Migrations SQL (unique constraints, indexes)
- [ ] Tests unitaires models
- [ ] Données initiales (25 codes + 8 patterns + 5 types)

### Phase 2 : Vues & UI (2-3 jours)

- [ ] Formulaires sec.poste_type, sec.shift_pattern, etc.
- [ ] Vues LIST avec colonnes appropriées
- [ ] Onglets custom hr.employee (Gardiennage, Historique)
- [ ] Menu navigation (menu.xml)
- [ ] Styles/couleurs codes vacation

### Phase 3 : Vues avancées (2-3 jours)

- [ ] Vue Planning unifiée (grille dates × agents)
- [ ] Dashboards (Opérateur, Planificateur, RH)
- [ ] Fiche Redéploiement
- [ ] Main courante

### Phase 4 : Wizards & Exports (1-2 jours)

- [ ] Wizard Export Audit (paramètres, aperçu, export CSV/XLSX)
- [ ] Tests wizard

### Phase 5 : Tests & Recette (1 jour)

- [ ] Tests complets (models, vues, wizards)
- [ ] Recette critères validation (verrou anti-doublon, TST, etc.)
- [ ] Documentation utilisateur

---

## Success Criteria

**Phase 1 terminée quand** :
✅ Tous 12 modèles implémentés et testés
✅ 25 codes vacation chargés en BD
✅ Contraintes (unique, foreign keys) en place
✅ Anti-doublon agent fonctionne
✅ Formule TST correcte

**Phase 2 terminée quand** :
✅ Formulaires sec.poste_type, sec.site, sec.poste créés
✅ Onglets custom hr.employee visibles
✅ Menus navigation OK

**Phase 3 terminée quand** :
✅ Grille Planning interactive (éditable)
✅ Dashboards affichent données correctement

**Phase 4 terminée quand** :
✅ Export Audit exporte CSV/XLSX correct
✅ Colonnes Absence/Sanction filtrées ssi > 0

**Phase 5 terminée quand** :
✅ Tous tests passent
✅ Critères recette validés

---

## GitHub Workflow

```bash
# Branches
main ← stable
  ← develop (default)
    ← feature/models (Phase 1)
    ← feature/views (Phase 2)
    ← feature/dashboards (Phase 3)
    ← feature/exports (Phase 4)

# Commits
git commit -m "feat(models): implement sec.poste_type model"
git commit -m "fix(planning): correct TST computation formula"
git commit -m "test(models): add unit tests for anti-doublon lock"
git commit -m "docs(readme): add development setup guide"
```

---

## Documentation attendue

1. **README.md** : Setup local + usage
2. **MODELS.md** : Description 12 modèles + champs + contraintes
3. **VIEWS.md** : Liste vues + screenshots + workflows
4. **WIZARD.md** : Export Audit spec + formules
5. **API.md** : Méthodes publiques modèles (compute_tst, validate_pointage, etc.)

---

**Ready for autonomous development. Good luck!** 🚀

