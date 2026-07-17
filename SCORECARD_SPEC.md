# Diagnostic d'automatisation FGC Média — Spécification complète

> Document de référence pour le questionnaire d'auto-évaluation
> (lead magnet + pré-qualification). À passer à Claude Code pour l'implémentation.
>
> _Créé : 2026-06-27 · Mis à jour : 2026-07-17 (retrait génération IA, score seul + audit)_

---

## 1. Objectif & principe

Permettre à un dirigeant de TPE/PME de s'auto-évaluer en ~3 minutes, sans réserver
d'appel, et :

- **Pour le visiteur** : obtenir immédiatement un **niveau d'automatisation actuel /100**
  (avec une jauge montrant le potentiel inexploité), présenté honnêtement comme un
  premier indicateur automatique, puis être invité à un audit offert pour le
  transformer en plan d'action.
- **Pour Grégory** : capturer un **lead pré-qualifié** (email dès l'étape 1) avec tout
  le contexte métier stocké en base, et **maximiser les réservations d'audit**.

**Positionnement retenu : jouer sur la confiance, pas sur la frustration.** Le score
est donné franchement (pas verrouillé pour forcer l'appel), et l'audit est proposé
comme la suite naturelle — sans rétention artificielle d'information.

### Historique des arbitrages de conception

- **Logique d'affichage = maturité, pas opportunité.** Un score d'opportunité /100
  (haut = beaucoup à automatiser) créait une dissonance (réflexe scolaire « score
  élevé = bonne note »). On affiche donc la **maturité** (`100 - opportunité`),
  intuitive, avec une jauge en deux parties (niveau actuel + potentiel à exploiter).
  Le score d'opportunité reste calculé en interne et stocké pour le tri commercial.
- **Retrait de la génération IA (2026-07).** À l'origine, un node OpenAI générait 3
  priorités personnalisées + une estimation d'heures récupérables, livrées par email.
  Constat après lecture des emails réels : le contenu était trop **générique** (le
  questionnaire ne capte pas assez de contexte pour un conseil vraiment spécifique —
  le vrai contexte naît dans la conversation, pas dans un formulaire). La « démonstration
  de compétence » attendue était donc faible. Décision : **retirer entièrement la
  génération IA** (priorités + estimation d'heures). Le diagnostic qualifie et amorce ;
  l'audit approfondit. Bonus : workflow plus léger, moins cher, moins de latence, une
  pièce de moins qui peut casser.

---

## 2. Parcours en 5 étapes

L'email est capturé à l'**étape 1** : même en cas d'abandon, le lead est acquis.

### Étape 1 — Contact
- Objectif affiché + temps estimé (**3 min**)
- Champs : **Nom complet*** · **Email*** · **case de consentement nLPD/RGPD***

### Étape 2 — Votre entreprise (qualification)
- **Nom de l'entreprise*** · **Site web*** · **Secteur / activité***
- **Nombre de personnes*** : `1-9` · `10-19` · `20-49` · `50-99` · `100+`
- **CA annuel (CHF)*** : `< 250k` · `250k-1M` · `1M-5M` · `5M-10M` · `> 10M` · `Je préfère ne pas répondre`

### Étape 3 — Opérations & organisation (douleur)
- **Comment gérez-vous vos opérations / projets ?** (choix multiple) :
  A. Tableurs Excel & email · B. Outils de gestion de projet · C. Systèmes internes / sur-mesure · D. Mélange d'outils avec étapes manuelles
- **Zones les plus inefficaces ?** (choix multiple) :
  A. Ventes & CRM · B. Onboarding client · C. Finance / facturation / devis · D. Opérations terrain / planification · E. Conformité / documentation · F. Reporting / tableaux de bord · G. Communication interne
- **Combien d'outils distincts par jour ?** : `1-3` · `4-6` · `7-10` · `Plus de 10`

### Étape 4 — Automatisation & maturité (scoring)
- **Quels outils utilisez-vous ?** (choix multiple) :
  A. Zapier / Make / n8n · B. Airtable / Google Sheets · C. Notion / Smartsheet · D. Logiciel comptable (Banana, Winbiz, Crésus, Bexio…) · E. Slack / Teams · F. APIs / tableaux de bord internes · G. Autre
- **Processus documentés (procédures écrites) ?** — échelle 1-5 (1 = aucune → 5 = tout)
- **Processus automatisés ?** — échelle 1-5 (1 = tout manuel → 5 = entièrement automatisé)

### Étape 5 — Points de blocage & objectifs (contexte + qualification)
- **Principaux maux opérationnels à éliminer (6-12 mois) ?** — texte libre
- **Si on doublait l'efficacité en 12 mois, à quoi ressemblerait le succès ?** — texte libre

> Note : ces deux champs libres ne nourrissent plus de génération IA. Ils restent
> utiles comme **contexte de qualification** (stockés en base, lus par Grégory avant
> l'audit) et pour amorcer la conversation.

Bouton final : **Obtenir mon score →**

---

## 3. Logique de calcul

> ⚠️ **Hypothèses métier, modifiables.** Pondérations de départ, pas des vérités.

### 3.1 Score d'opportunité (calcul interne, /100)

Mesure le gisement potentiel : plus l'entreprise est manuelle / dispersée / peu
documentée, plus l'opportunité est élevée.

| Composante | Poids | Calcul |
|---|---|---|
| Maturité automatisation | 35 | `(5 - valeur_auto) / 4 * 35` |
| Documentation (SOPs) | 15 | `(5 - valeur_sops) / 4 * 15` |
| Dispersion des outils | 20 | `1-3→5` · `4-6→12` · `7-10→18` · `>10→20` |
| Surface d'inefficacité | 20 | `min(nb_zones, 5) / 5 * 20` |
| Mode de gestion | 10 | `+5 si A (tableurs)` · `+5 si D (mélange manuel)` · plafonné à 10 |

`opportunite = round(borne(A + B + C + D + E, 0, 100))`

### 3.2 Maturité (valeur affichée à l'écran, /100)

```
maturite = 100 - opportunite
```

Intuitive : un chiffre bas = peu automatisé = beaucoup à gagner. C'est la valeur
renvoyée au front et affichée en grand.

### 3.3 Paliers (formulés côté gain)

Déterminé par l'**opportunité** (le manque), libellé en termes de bénéfice.

| Opportunité | Palier affiché | Message |
|---|---|---|
| 0-30 | **Déjà bien outillé** | « Votre organisation est déjà bien automatisée. Quelques optimisations ciblées restent possibles. » |
| 31-60 | **Des gains à portée de main** | « Plusieurs zones peuvent être fluidifiées : il y a du temps concret à récupérer. » |
| 61-100 | **Beaucoup à gagner** | « Une large part de vos processus reste manuelle. Le temps récupérable est important, et rapidement. » |

### 3.4 Sous-scores : supprimés

Les trois sous-jauges (Documentation / Automatisation / Intégration) ont été retirées
(lecture alourdie sans valeur ajoutée claire). Les valeurs brutes `sops` et `auto`
restent stockées en base pour analyse.

---

## 4. Affichage écran vs email

### À l'écran (immédiat, après submit)
- Le **niveau d'automatisation actuel /100** (= `maturite`) en grand
- Une **jauge en deux parties** : partie pleine (`maturite`%) = « Niveau actuel » ;
  partie vide = « Potentiel à exploiter »
- Le **libellé de palier** + sa phrase de diagnostic
- Un **cadrage honnête** : le score est un premier indicateur automatique ; un vrai
  diagnostic demande de comprendre le contexte → d'où l'audit
- **CTA** : « Réserver mon audit offert (30 min) → » vers Calendly
- Ligne discrète : « Vous recevez aussi une copie de votre score par email. »

### Dans l'email (envoi automatique)
- Rappel du score + palier
- Cadrage « premier indicateur automatique »
- Lien Calendly (audit offert)
- **Plus de 3 priorités, plus d'estimation d'heures.** Email court, identique pour
  tous (rappel du score + invitation à l'audit). Sert de capture/trace + relance passive.

---

## 5. Architecture technique

```
┌──────────────────┐   POST réponses     ┌──────────────────┐
│  diagnostic.html  │ ──────────────────► │  n8n (webhook)   │
│  (HTML/JS vanilla)│                     │                  │
│  site statique    │ ◄────────────────── │  1. Calcul score │
│  Render           │  { maturite,        │  2. Insert SB    │
│  Affiche maturité │    palier, message }│  3. Email (Resend)│
│  + jauge + CTA    │                     │  4. Respond      │
└──────────────────┘                      └──────────────────┘
```

- **Front** : page autonome HTML/JS vanilla (pas de framework), POST vers le webhook,
  affiche `maturite` + jauge + cadrage + CTA audit. Charte du site (tokens oklch,
  Schibsted Grotesk).
- **n8n** : webhook → Function (score) → Supabase (insert) → Email → Respond.
  **Plus de node OpenAI.** Voir `WORKFLOW_N8N.md`.
- **Supabase** : table `leads_diagnostic` (base « fgcmedia.ch »). La colonne `score`
  stocke l'**opportunité** (tri commercial : score desc = leads les plus chauds).

---

## 6. Envoi de l'email : Resend (transactionnel)

**Choix : Resend via SMTP** (compte déjà configuré sur n8n), plutôt que l'envoi
automatique via Gmail.

**Pourquoi** : Gmail n'est pas fait pour l'envoi transactionnel programmatique (risque
spam + risque pour le compte). Resend est bâti pour ça (authentification propre,
réputation gérée). La délivrabilité = directement le taux de conversion (un email en
spam = un lead perdu, sans score ni lien Calendly).

**Prérequis pour que Resend soit réellement supérieur** :
- Domaine `fgcmedia.ch` **vérifié dans Resend** (enregistrements DNS SPF + DKIM, idéalement DMARC).
- Envoi depuis une adresse du domaine (ex. `diagnostic@fgcmedia.ch`), pas une adresse générique.
- `reply-to` configuré vers une adresse réellement consultée (si l'adresse d'envoi est technique).
- Test réel vers Gmail ET Outlook pour vérifier l'arrivée en inbox.

---

## 7. Décisions verrouillées

- ✅ Pondérations du score : en l'état pour démarrer
- ✅ Devise : CHF · Route : `/diagnostic` · Calendly : `https://calendly.com/fgcmedia/rdv`
- ✅ Consentement nLPD/RGPD : case à l'étape 1
- ✅ Stockage : Supabase, table `leads_diagnostic`
- ✅ Affichage : maturité /100 + jauge deux parties
- ✅ Sous-scores : supprimés
- ✅ **Génération IA (priorités + estimation d'heures) : supprimée** — contenu trop générique
- ✅ **Écran & email : score seul + cadrage honnête + CTA audit** (jouer la confiance, pas la frustration)
- ✅ **Envoi email : Resend** (sous réserve domaine authentifié)
- ✅ Terminologie : « Diagnostic d'automatisation » · accroche « Découvrez votre potentiel d'automatisation »
- 🔲 Enrichissement via site web fourni : v2

---

## 8. Fichiers liés

| Fichier | Rôle |
|---|---|
| `diagnostic.html` | Page front (formulaire 5 étapes + écran résultat), déployée sur le site |
| `WORKFLOW_N8N.md` | Construction node par node du workflow n8n + SQL Supabase + CORS |
| `SCORECARD_SPEC.md` | Ce document — spécification de référence |
