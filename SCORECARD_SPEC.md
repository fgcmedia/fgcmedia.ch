# Diagnostic d'automatisation FGC Média — Spécification complète

> Document de référence pour le questionnaire d'auto-évaluation
> (lead magnet + pré-qualification). À passer à Claude Code pour l'implémentation.
>
> _Créé : 2026-06-27 · Mis à jour : 2026-06-27 (logique maturité)_

---

## 1. Objectif & principe

Permettre à un dirigeant de TPE/PME de s'auto-évaluer en ~3 minutes, sans réserver
d'appel, et :

- **Pour le visiteur** : obtenir immédiatement un **niveau d'automatisation actuel /100**
  (avec une jauge montrant le potentiel inexploité) + une phrase de diagnostic à
  l'écran, puis recevoir par email un rapport détaillé (3 priorités + recommandations).
- **Pour Grégory** : capturer un **lead pré-qualifié** (email dès l'étape 1) avec tout
  le contexte métier, et un **brouillon d'email** prêt à valider dans Gmail.

**Règle de transparence** : le résultat est une **estimation indicative**, assumée comme
telle (jamais un chiffre faussement précis). Cohérent avec le principe « honnêteté
sur les gaps ».

### Note importante sur la logique d'affichage (maturité, pas opportunité)

Le test terrain a montré qu'afficher un **score d'opportunité /100** (haut = beaucoup
à automatiser) crée une dissonance : le réflexe scolaire lit « score élevé = bonne
note », à l'inverse du sens voulu. **On affiche donc la maturité** (`100 - opportunité`),
intuitive (bas = peu automatisé), tout en rendant le manque visible par une **jauge en
deux parties** (niveau actuel + potentiel à exploiter). Le score d'opportunité reste
calculé en interne et stocké pour le tri commercial.

---

## 2. Parcours en 5 étapes

L'email est capturé à l'**étape 1** : même en cas d'abandon, le lead est acquis.

### Étape 1 — Contact
- Objectif affiché + temps estimé (**3 min**)
- Champs : **Nom complet*** · **Email*** · **case de consentement nLPD/RGPD***

### Étape 2 — Votre entreprise (qualification)
- **Nom de l'entreprise*** · **Site web*** · **Secteur / activité***
- **Nombre de personnes*** : `1-9` · `10-19` · `20-49` · `50-99` · `100+`
- **Chiffre d'affaires annuel (CHF)*** : `< 250k` · `250k-1M` · `1M-5M` · `5M-10M` · `> 10M` · `Je préfère ne pas répondre`

### Étape 3 — Opérations & organisation (douleur)
- **Comment gérez-vous vos opérations / projets ?** (choix multiple) :
  A. Tableurs Excel & email · B. Outils de gestion de projet (Asana, ClickUp, Monday…) ·
  C. Systèmes internes / sur-mesure · D. Mélange d'outils avec étapes manuelles
- **Zones les plus inefficaces ?** (choix multiple) :
  A. Ventes & CRM · B. Onboarding client · C. Finance / facturation / devis ·
  D. Opérations terrain / planification · E. Conformité / documentation ·
  F. Reporting / tableaux de bord · G. Communication interne
- **Combien d'outils distincts par jour ?** : `1-3` · `4-6` · `7-10` · `Plus de 10`

### Étape 4 — Automatisation & maturité (scoring)
- **Quels outils utilisez-vous ?** (choix multiple) :
  A. Zapier / Make / n8n · B. Airtable / Google Sheets · C. Notion / Smartsheet ·
  D. Logiciel comptable (Banana, Winbiz, Crésus, Bexio…) · E. Slack / Teams ·
  F. APIs / tableaux de bord internes · G. Autre
- **Processus documentés (procédures écrites) ?** — échelle 1-5 (1 = aucune → 5 = tout)
- **Processus automatisés ?** — échelle 1-5 (1 = tout manuel → 5 = entièrement automatisé)

### Étape 5 — Points de blocage & objectifs (or pour le suivi)
- **Principaux maux opérationnels à éliminer (6-12 mois) ?** — texte libre
- **Si on doublait l'efficacité en 12 mois, à quoi ressemblerait le succès ?** — texte libre

Bouton final : **Obtenir mon score →**

---

## 3. Logique de calcul

> ⚠️ **Hypothèses métier, modifiables.** Pondérations de départ, pas des vérités.

### 3.1 Score d'opportunité (calcul interne, /100)

Mesure le **gisement potentiel** : plus l'entreprise est manuelle / dispersée / peu
documentée, plus l'opportunité est élevée.

| Composante | Poids | Logique |
|---|---|---|
| Maturité automatisation | 35 | Plus c'est manuel, plus le gisement est grand |
| Documentation (SOPs) | 15 | Peu de procédures = friction = gisement |
| Dispersion des outils | 20 | Plus d'outils = plus d'intégrations manquantes |
| Surface d'inefficacité | 20 | Plus de zones cochées = plus de potentiel |
| Mode de gestion | 10 | Tableurs/manuel = gisement ; outils intégrés = moins |

**Calcul** :
- **A. Automatisation (35)** : `(5 - valeur_auto) / 4 * 35`
- **B. Documentation (15)** : `(5 - valeur_sops) / 4 * 15`
- **C. Dispersion (20)** : `1-3 → 5` · `4-6 → 12` · `7-10 → 18` · `>10 → 20`
- **D. Inefficacité (20)** : `min(nb_zones, 5) / 5 * 20`
- **E. Gestion (10)** : `+5 si A (tableurs)` · `+5 si D (mélange manuel)` · plafonné à 10

`opportunite = round(borne(A + B + C + D + E, 0, 100))`

### 3.2 Maturité (valeur affichée à l'écran, /100)

```
maturite = 100 - opportunite
```

Intuitive : un chiffre bas = peu automatisé = beaucoup à gagner.
C'est cette valeur qui est renvoyée au front et affichée en grand.

### 3.3 Paliers (formulés côté gain)

Le palier est déterminé par l'**opportunité** (le manque), mais **libellé en termes
de bénéfice** pour rester motivant sans culpabiliser.

| Opportunité | Palier affiché | Message |
|---|---|---|
| 0-30 | **Déjà bien outillé** | « Votre organisation est déjà bien automatisée. Quelques optimisations ciblées restent possibles. » |
| 31-60 | **Des gains à portée de main** | « Plusieurs zones peuvent être fluidifiées : il y a du temps concret à récupérer. » |
| 61-100 | **Beaucoup à gagner** | « Une large part de vos processus reste manuelle. Le temps récupérable est important, et rapidement. » |

### 3.4 Sous-scores : supprimés

Les trois sous-jauges (Documentation / Automatisation / Intégration) ont été
**retirées** : elles alourdissaient la lecture sans valeur ajoutée claire pour le
visiteur. Les valeurs brutes `sops` et `auto` restent stockées en base pour analyse.

---

## 4. Affichage écran vs email

### À l'écran (immédiat, après submit)
- Le **niveau d'automatisation actuel /100** (= `maturite`) en grand
- Une **jauge horizontale en deux parties** :
  - partie pleine (largeur = `maturite`%) = « Niveau actuel »
  - partie vide (largeur = `100 - maturite`%) = « Potentiel à exploiter »
- Le **libellé de palier** + sa phrase de diagnostic
- Message : « Votre rapport détaillé avec vos 3 priorités vous arrive par email. »
- Bouton **Calendly** (réserver un échange)

### Dans l'email (rapport complet, en brouillon validé par Grégory)
- Rappel du résultat + palier
- **3 priorités personnalisées** générées par IA à partir des réponses
- Lien Calendly (CTA)
- Ton : conseil, pas vente

---

## 5. Architecture technique

```
┌─────────────────┐   POST réponses     ┌──────────────────┐
│  diagnostic.html │ ──────────────────► │  n8n (webhook)   │
│  (HTML/JS vanilla)│                     │                  │
│  site statique    │ ◄────────────────── │  1. Calcul score │
│  Render           │  { maturite,        │  2. OpenAI       │
│  Affiche maturité │    palier, message }│  3. Insert SB    │
│  + jauge          │                     │  4. Draft Gmail  │
└─────────────────┘                       └──────────────────┘
                                                   │
                                                   ▼
                                        Brouillon Gmail
                                        (fgcmedia.sarl@gmail.com)
                                        → Grégory valide & envoie
```

- **Front** : page autonome HTML/JS vanilla (pas de framework), POST vers le webhook,
  affiche `maturite` + jauge deux parties. Charte du site (tokens oklch, Schibsted Grotesk).
- **n8n** : webhook → Function (score) → OpenAI (gpt-4o-mini) → Supabase (insert) →
  Gmail (draft) → Respond. Voir `WORKFLOW_N8N.md` pour le détail node par node.
- **Supabase** : table `leads_diagnostic` (base « fgcmedia.ch »), colonnes de
  qualification + `reponses` jsonb. La colonne `score` stocke l'**opportunité** (tri
  commercial : score desc = leads les plus chauds).

---

## 6. Livraison de l'email : draft (actuel) → envoi auto (évolution possible)

**État actuel : brouillon Gmail.** Le workflow crée un draft que Grégory relit et
envoie manuellement. Garde-fou pendant la phase d'observation.

**Pourquoi garder le draft au début** :
1. **Qualité du rapport IA** : tant qu'un échantillon de 15-20 rapports réels n'a pas
   été observé, le draft protège contre une sortie hors-sujet ou maladroite.
2. **Personnalisation à valeur** : permet d'ajouter une phrase sur-mesure (référence au
   site du prospect, à son secteur) qui peut faire la différence sur un lead chaud.

**Évolution possible : envoi automatique via Resend**, une fois la qualité validée sur
un échantillon. Option : conditionner dans n8n (IF sur le score) — draft pour les leads
à fort potentiel, envoi auto pour les autres. À ne mettre en place qu'après la phase
d'observation, sans complexifier prématurément.

---

## 7. Décisions verrouillées

- ✅ Pondérations du score : en l'état pour démarrer
- ✅ Devise : CHF
- ✅ Route : `/diagnostic`
- ✅ Calendly : `https://calendly.com/fgcmedia/rdv`
- ✅ Consentement nLPD/RGPD : case à l'étape 1
- ✅ Modèle IA : gpt-4o-mini
- ✅ Stockage : Supabase, table `leads_diagnostic`
- ✅ Affichage : maturité /100 + jauge deux parties (pas le score d'opportunité brut)
- ✅ Sous-scores : supprimés
- ✅ Email : brouillon Gmail (envoi auto Resend = évolution future)
- ✅ Terminologie : « Diagnostic d'automatisation » (nom) · « Découvrez votre potentiel
  d'automatisation » (accroche home)
- 🔲 Enrichissement via site web fourni : v2

---

## 8. Fichiers liés

| Fichier | Rôle |
|---|---|
| `diagnostic.html` | Page front (formulaire 5 étapes + écran résultat), déployée sur le site |
| `WORKFLOW_N8N.md` | Construction node par node du workflow n8n + SQL Supabase + CORS |
| `SCORECARD_SPEC.md` | Ce document — spécification de référence |
