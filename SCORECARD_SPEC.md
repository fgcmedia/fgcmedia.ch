# Scorecard FGC Média — Spécification complète

> Document de référence pour le développement du questionnaire d'auto-évaluation
> (lead magnet + pré-qualification). À passer à Claude Code pour l'implémentation.
>
> _Créé : 2026-06-27_

---

## 1. Objectif & principe

Permettre à un dirigeant de TPE/PME de s'auto-évaluer en ~3 minutes, sans réserver d'appel, et :

- **Pour le visiteur** : obtenir immédiatement un **score d'opportunité /100** + une phrase de diagnostic à l'écran, puis recevoir par email un rapport détaillé (3 priorités + recommandations).
- **Pour Grégory** : capturer un **lead pré-qualifié** (email dès l'étape 1) avec tout le contexte métier, et un **brouillon d'email** prêt à valider dans Gmail.

**Règle de transparence** : le score d'opportunité est une **estimation indicative**, assumée comme telle (jamais un chiffre faussement précis). Cohérent avec le principe « honnêteté sur les gaps ».

---

## 2. Parcours en 5 étapes

L'email est capturé à l'**étape 1** : même en cas d'abandon, le lead est acquis.

### Étape 1 — Contact
- Objectif affiché : « Identifiez vos inefficacités, votre potentiel d'automatisation et le ROI possible dans vos systèmes actuels. »
- Temps estimé affiché : **3 min**
- Champs : **Nom complet*** · **Email***

### Étape 2 — Votre entreprise (qualification)
- **Nom de l'entreprise***
- **Site web*** (peut servir à enrichir le lead)
- **Secteur / activité***
- **Nombre de personnes (salariés + indépendants)*** — select :
  `1-9` · `10-19` · `20-49` · `50-99` · `100+`
- **Chiffre d'affaires annuel*** — select (fourchettes en CHF) :
  `< 250k` · `250k-1M` · `1M-5M` · `5M-10M` · `> 10M` · `Je préfère ne pas répondre`

### Étape 3 — Opérations & organisation (douleur)
- **Comment gérez-vous vos opérations / projets au quotidien ?** (choix multiple) :
  - A. Tableurs Excel & email
  - B. Outils de gestion de projet (Asana, ClickUp, Monday, Trello…)
  - C. Systèmes internes / sur-mesure
  - D. Un mélange d'outils avec des étapes manuelles
- **Quelles zones vous semblent les plus inefficaces aujourd'hui ?** (choix multiple) :
  - A. Ventes & relation client (CRM)
  - B. Onboarding client
  - C. Finance / facturation / devis
  - D. Opérations terrain / planification
  - E. Conformité / documentation
  - F. Reporting / tableaux de bord
  - G. Communication interne
- **Combien d'outils / plateformes distincts vos équipes utilisent-elles chaque jour ?** — select :
  `1-3` · `4-6` · `7-10` · `Plus de 10`

### Étape 4 — Automatisation & maturité (scoring)
- **Quels outils utilisez-vous actuellement ?** (choix multiple) :
  - A. Zapier / Make / n8n
  - B. Airtable / Google Sheets
  - C. Notion / Smartsheet
  - D. Logiciel comptable (Banana, Winbiz, Crésus, Bexio…)
  - E. Slack / Teams
  - F. APIs ou tableaux de bord internes sur-mesure
  - G. Autre
- **Combien de vos processus sont documentés (procédures écrites) ?** — échelle 1-5
  `1 = aucune procédure` → `5 = tout est documenté`
- **À quel point vos processus sont-ils automatisés ?** — échelle 1-5
  `1 = tout est manuel` → `5 = entièrement automatisé entre services`

### Étape 5 — Points de blocage & objectifs (or pour le suivi)
- **Quels sont les principaux maux opérationnels que vous aimeriez éliminer dans les 6-12 prochains mois ?** — texte libre
  _Placeholder : « ex : trop de saisie manuelle, les rapports prennent des jours, aucune visibilité sur la charge de l'équipe… »_
- **Si on doublait l'efficacité de votre équipe en 12 mois, à quoi ressemblerait le succès pour vous ?** — texte libre
  _Placeholder : « ex : gérer plus de projets à effectif constant, réduire le travail admin, meilleure visibilité des données… »_

Bouton final : **Obtenir mon score →**

---

## 3. Logique de score d'opportunité /100

> ⚠️ **Hypothèses métier à valider/ajuster par Grégory.** Ce ne sont pas des
> vérités universelles : ce sont des pondérations de départ, modifiables.

Le score d'opportunité mesure **le potentiel** (combien il y a à gagner),
pas la maturité. Plus l'entreprise est manuelle/dispersée/peu documentée, plus le
potentiel est élevé → score élevé = forte opportunité d'automatisation.

### 3.1 Composantes (total 100 points)

| Composante | Poids | Logique |
|---|---|---|
| **Maturité automatisation** | 35 | Plus c'est manuel, plus le potentiel est grand |
| **Documentation (SOPs)** | 15 | Peu de procédures = friction élevée = potentiel |
| **Dispersion des outils** | 20 | Plus d'outils = plus d'intégrations manquantes |
| **Surface d'inefficacité** | 20 | Plus de zones inefficaces cochées = plus de potentiel |
| **Mode de gestion** | 10 | Tableurs/manuel = potentiel ; outils intégrés = moins |

### 3.2 Calcul détaillé

**A. Maturité automatisation (35 pts)** — depuis l'échelle 1-5 « automatisation »
`points = (5 - valeur) / 4 * 35`
- 1 (tout manuel) → 35 pts
- 3 → 17,5 pts
- 5 (tout automatisé) → 0 pt

**B. Documentation (15 pts)** — depuis l'échelle 1-5 « SOPs »
`points = (5 - valeur) / 4 * 15`

**C. Dispersion des outils (20 pts)** — depuis « combien d'outils distincts »
- `1-3` → 5 pts
- `4-6` → 12 pts
- `7-10` → 18 pts
- `Plus de 10` → 20 pts

**D. Surface d'inefficacité (20 pts)** — depuis les zones inefficaces cochées
`points = min(nb_zones_cochées, 5) / 5 * 20`
(plafonné à 5 zones pour éviter qu'un « je coche tout » sature le score)

**E. Mode de gestion (10 pts)** — depuis « comment gérez-vous vos opérations »
- Contient A (tableurs & email) → +5
- Contient D (mélange + étapes manuelles) → +5
- Contient C (systèmes internes) seul → +0
- Plafonné à 10
(B = outils de PM structurés → 0 pt de potentiel sur cette composante)

**Score final** = A + B + C + D + E, arrondi à l'entier, borné 0-100.

### 3.3 Paliers d'interprétation

| Score | Libellé | Phrase à l'écran (exemple) |
|---|---|---|
| 0-30 | potentiel faible | « Votre organisation est déjà bien outillée. Quelques optimisations ciblées restent possibles. » |
| 31-60 | potentiel modéré | « Il y a de vraies poches d'efficacité à récupérer, sur 2-3 zones prioritaires. » |
| 61-100 | potentiel élevé | « Votre potentiel d'automatisation est important : plusieurs processus-clés peuvent être fluidifiés rapidement. » |

### 3.4 Sous-scores de maturité (affichés en complément)

Trois mini-jauges, calculées séparément du /100 :
- **Documentation** : valeur 1-5 brute → affichée en /5
- **Automatisation** : valeur 1-5 brute → affichée en /5
- **Intégration des outils** : inverse de la dispersion → `1-3 outils = 5/5`, `>10 = 1/5`

---

## 4. Affichage écran vs email

### À l'écran (immédiat, après submit)
- Le **score d'opportunité /100** en grand
- Le **libellé de palier** + sa phrase de diagnostic
- Les **3 sous-jauges de maturité** (/5)
- Message : « Votre rapport détaillé avec vos 3 priorités vous arrive par email. »

### Dans l'email (rapport complet, validé par Grégory avant envoi)
- Rappel du score + paliers
- **3 priorités personnalisées** générées par IA à partir des réponses
- Lien pour réserver un appel (CTA)
- Ton : conseil, pas vente

---

## 5. Architecture technique

```
┌─────────────────┐     POST réponses      ┌──────────────────┐
│  Formulaire     │ ─────────────────────► │  n8n (webhook)   │
│  React (site)   │                         │                  │
│                 │ ◄───────────────────── │  1. Calcul score │
│  Affiche score  │   { score, souscores } │  2. Appel OpenAI │
└─────────────────┘     réponse synchrone   │  3. Crée draft   │
                                            │     Gmail        │
                                            └──────────────────┘
                                                     │
                                                     ▼
                                          Brouillon dans Gmail
                                          (fgcmedia.sarl@gmail.com)
                                          → Grégory valide & envoie
```

### 5.1 Frontend React
- Formulaire multi-étapes (5 steps), state local (pas de localStorage — non supporté en artifacts, et inutile ici)
- Validation par étape (champs requis)
- POST du payload complet vers le webhook n8n en fin de parcours
- **Le calcul du score peut être fait côté n8n** (recommandé : logique centralisée, modifiable sans redéploiement front) **et renvoyé en réponse synchrone** pour affichage immédiat
- Affiche score + sous-jauges + message « rapport par email »

### 5.2 n8n (cœur logique)
1. **Webhook** reçoit le payload
2. **Function node** : calcule le score /100 + sous-scores (logique section 3)
3. **OpenAI node** : génère les 3 priorités personnalisées (prompt section 6)
4. **Gmail node** (`createDraft`) : crée le brouillon sur le compte connecté
5. **Respond to Webhook** : renvoie `{ score, souscores, palier }` au front

> Architecture cohérente avec le principe « toute la logique de traitement reste
> dans n8n, hors de l'app React ».

### 5.3 Gmail — brouillon plutôt qu'envoi
- Node Gmail `Create Draft` (pas `Send`)
- Le brouillon est créé sur `fgcmedia.sarl@gmail.com`
- Grégory ouvre Gmail, relit, ajuste, complète, puis envoie manuellement
- **Argument vendeur** : « le système prépare, vous validez » — démontre une
  automatisation avec garde-fou humain, vendable telle quelle à un client

---

## 6. Prompt OpenAI (génération des 3 priorités)

> À placer dans le node OpenAI de n8n. Les variables `{{ }}` sont injectées
> depuis les réponses du formulaire et le score calculé.

```
Tu es un consultant en automatisation pour PME. À partir des réponses ci-dessous
d'un dirigeant à un questionnaire d'auto-évaluation, rédige un court rapport en
français, ton professionnel et bienveillant (vouvoiement), SANS survente.

Contexte de l'entreprise :
- Secteur : {{secteur}}
- Taille : {{taille}} personnes
- Gestion actuelle : {{mode_gestion}}
- Zones inefficaces déclarées : {{zones_inefficaces}}
- Nombre d'outils utilisés : {{nb_outils}}
- Outils en place : {{outils}}
- Documentation (1-5) : {{score_sops}}
- Automatisation (1-5) : {{score_auto}}
- Maux opérationnels (texte libre) : {{douleurs}}
- Vision de succès (texte libre) : {{vision}}

Score d'opportunité calculé : {{score}}/100 ({{palier}})

Rédige EXACTEMENT cette structure :
1. Un paragraphe de 2-3 phrases qui reformule leur situation avec empathie et
   relie leur vision de succès au potentiel identifié.
2. "Vos 3 priorités :" suivi de 3 points concrets, chacun avec :
   - un titre court
   - 1-2 phrases expliquant le gain attendu et une piste d'approche
   Les priorités doivent être tirées de LEURS réponses (zones inefficaces,
   outils, douleurs déclarées), pas génériques.
3. Une phrase de clôture invitant à en discuter, sans pression.

Contraintes :
- Pas de jargon technique inutile (éviter "SOP", dire "procédures documentées").
- Reste honnête : si le potentiel est faible, dis-le et propose des optimisations
  ciblées plutôt que d'inventer des problèmes.
- Maximum ~250 mots.
- Ne promets aucun chiffre de ROI précis ; parle de "potentiel" et de "fourchette".
```

---

## 7. Points à décider / affiner par Grégory

- [ ] **Valider les pondérations** de la section 3 (poids des composantes, fourchettes)
- [ ] **CHF vs EUR** pour les fourchettes de CA (CHF retenu par défaut, cible Suisse)
- [ ] **Réserver un nom de page** : `/scorecard`, `/evaluation`, `/diagnostic` ?
- [ ] **CTA de fin d'email** : lien Calendly / réservation d'appel à intégrer
- [ ] **RGPD / nLPD** : mention de consentement sur l'usage de l'email (case à cocher étape 1)
- [ ] **Enrichissement** : exploiter le site web fourni pour pré-remplir le contexte ? (v2)

---

## 8. Prochaines étapes suggérées

1. Grégory valide/ajuste les pondérations (section 3) et les décisions (section 7)
2. Construction du formulaire React multi-étapes (Claude Code)
3. Construction du workflow n8n (webhook → score → OpenAI → draft Gmail)
4. Test bout-en-bout avec un cas fictif
5. Intégration sur le site (section dédiée + lien dans la nav)
6. (v2) Score affiné, enrichissement via site web, A/B test de l'accroche
