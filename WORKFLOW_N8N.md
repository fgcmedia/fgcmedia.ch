# Workflow n8n — Diagnostic d'automatisation FGC Média

> Guide de construction node par node du workflow qui traite les soumissions
> du formulaire `/diagnostic`, calcule le score, enregistre le lead dans Supabase
> et envoie un email récap (score + invitation à l'audit).
>
> _Créé : 2026-06-27 · Mis à jour : 2026-07-24 (audit 15 min)_

---

## Vue d'ensemble

```
Webhook (POST /diagnostic)
   │
   ▼
Function — Calcul du score (opportunité interne + maturité affichée)
   │
   ├──────────────► Supabase — Insert lead
   │
   ▼
Email (Resend) — récap score + lien audit
   │
   ▼
Respond to Webhook — renvoie { maturite, palier, message }
```

> **Changement 2026-07** : le node OpenAI (génération de 3 priorités + estimation
> d'heures) a été **supprimé** — contenu trop générique faute de contexte suffisant.
> Le workflow est désormais plus court, moins cher, sans latence IA. L'email est un
> simple récap identique pour tous. Voir `SCORECARD_SPEC.md` §1 et §4.

---

## 0. Table Supabase

Déjà créée. Rappel de structure (base **fgcmedia.ch**) :

```sql
create table public.leads_diagnostic (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nom text not null,
  email text not null,
  entreprise text,
  site text,
  secteur text,
  taille text,
  ca text,
  score int,            -- score d'opportunité 0-100 (haut = lead chaud)
  palier text,
  score_sops int,
  score_auto int,
  reponses jsonb not null,
  statut text default 'nouveau'   -- nouveau | contacté | converti | perdu
);

create index idx_leads_score on public.leads_diagnostic (score desc);
create index idx_leads_created on public.leads_diagnostic (created_at desc);
```

> La colonne `rapport_genere` n'est plus utilisée (plus de génération IA). Elle peut
> rester vide sans souci, ou être supprimée :
> `alter table public.leads_diagnostic drop column rapport_genere;`
>
> `score` stocke l'**opportunité** → `order by score desc` remonte les prospects les
> plus chauds. Écrit par n8n via la **service_role key** (bypasse RLS).

---

## 1. Node : Webhook

- **Type** : Webhook · **Method** : `POST` · **Path** : `diagnostic`
- **Respond** : `Using 'Respond to Webhook' node`
- **Options → Response Headers** (CORS) :
  | Name | Value |
  |---|---|
  | `Access-Control-Allow-Origin` | `https://fgcmedia.ch` |
  | `Access-Control-Allow-Methods` | `POST, OPTIONS` |
  | `Access-Control-Allow-Headers` | `Content-Type` |

Payload accessible via `{{ $json.body }}`.

---

## 2. Node : Function — Calcul du score

- **Type** : Code (Function) · **Mode** : Run Once for All Items · **JS**

```javascript
const b = $input.first().json.body;

const toInt = (v) => parseInt(v, 10) || 0;
const arr = (v) => Array.isArray(v) ? v : [];

// A. Maturité automatisation (35) : plus c'est manuel, plus le gisement
const auto = toInt(b.auto);
const pA = ((5 - auto) / 4) * 35;

// B. Documentation / SOPs (15)
const sops = toInt(b.sops);
const pB = ((5 - sops) / 4) * 15;

// C. Dispersion des outils (20)
const dispMap = { "1-3": 5, "4-6": 12, "7-10": 18, "Plus de 10": 20 };
const pC = dispMap[b.nbOutils] ?? 0;

// D. Surface d'inefficacité (20), plafonnée à 5 zones
const nbZones = Math.min(arr(b.zones).length, 5);
const pD = (nbZones / 5) * 20;

// E. Mode de gestion (10)
const g = arr(b.gestion);
let pE = 0;
if (g.includes("A")) pE += 5;
if (g.includes("D")) pE += 5;
pE = Math.min(pE, 10);

// Score d'opportunité (interne, stocké pour le tri commercial)
const opportunite = Math.round(Math.max(0, Math.min(100, pA + pB + pC + pD + pE)));

// Maturité = valeur affichée (intuitive : bas = peu automatisé)
const maturite = 100 - opportunite;

// Palier basé sur l'opportunité, formulé côté gain
let palier, message;
if (opportunite <= 30) {
  palier = "Déjà bien outillé";
  message = "Votre organisation est déjà bien automatisée. Quelques optimisations ciblées restent possibles.";
} else if (opportunite <= 60) {
  palier = "Des gains à portée de main";
  message = "Plusieurs zones peuvent être fluidifiées : il y a du temps concret à récupérer.";
} else {
  palier = "Beaucoup à gagner";
  message = "Une large part de vos processus reste manuelle. Le temps récupérable est important, et rapidement.";
}

return [{
  json: {
    ...b,
    opportunite,
    maturite,
    score: opportunite,
    palier,
    message,
    score_sops: sops,
    score_auto: auto,
  }
}];
```

---

## 3. Node : Supabase — Insert lead

- **Type** : Supabase · **Operation** : Insert · **Table** : `leads_diagnostic`
- **Credentials** : URL projet + **service_role key**
- **Mapping** :
  | Colonne | Valeur |
  |---|---|
  | `nom` | `{{ $('Function').item.json.nom }}` |
  | `email` | `{{ $('Function').item.json.email }}` |
  | `entreprise` | `{{ $('Function').item.json.entreprise }}` |
  | `site` | `{{ $('Function').item.json.site }}` |
  | `secteur` | `{{ $('Function').item.json.secteur }}` |
  | `taille` | `{{ $('Function').item.json.taille }}` |
  | `ca` | `{{ $('Function').item.json.ca }}` |
  | `score` | `{{ $('Function').item.json.opportunite }}` |
  | `palier` | `{{ $('Function').item.json.palier }}` |
  | `score_sops` | `{{ $('Function').item.json.score_sops }}` |
  | `score_auto` | `{{ $('Function').item.json.score_auto }}` |
  | `reponses` | `{{ JSON.stringify($('Function').item.json) }}` |

> Plus de champ `rapport_genere` (génération IA supprimée).

---

## 4. Node : Email via Resend (SMTP)

- **Type** : node Email / SMTP configuré sur les credentials **Resend**
- **From** : une adresse du domaine authentifié, ex. `diagnostic@fgcmedia.ch`
- **Reply-To** : adresse réellement consultée (si le From est technique)
- **To** : `{{ $('Function').item.json.email }}`
- **Subject** : `Votre diagnostic d'automatisation — {{ $('Function').item.json.entreprise }}`
- **Body** :

```
Bonjour {{ $('Function').item.json.nom }},

Merci d'avoir rempli le diagnostic d'automatisation.

Votre niveau d'automatisation actuel : {{ $('Function').item.json.maturite }}/100 ({{ $('Function').item.json.palier }})

Ce score est un premier indicateur automatique. Pour en discuter et voir concrètement ce qui est automatisable chez vous, réservons un audit offert de 15 min :
https://calendly.com/fgcmedia/rdv

Grégory Cardinale
FGC Média Sàrl
```

> **Prérequis délivrabilité** : domaine `fgcmedia.ch` vérifié dans Resend (SPF + DKIM,
> idéalement DMARC). Tester l'arrivée en inbox vers Gmail ET Outlook. Voir
> `SCORECARD_SPEC.md` §6.

---

## 5. Node : Respond to Webhook

- **Type** : Respond to Webhook · **Respond With** : JSON
- **Response Body** :

```json
{
  "maturite": {{ $('Function').item.json.maturite }},
  "palier": "{{ $('Function').item.json.palier }}",
  "message": "{{ $('Function').item.json.message }}"
}
```

- **Options → Response Headers** : remettre `Access-Control-Allow-Origin: https://fgcmedia.ch`.

> Format attendu par `diagnostic.html` : `{ maturite, palier, message }`.

---

## 6. CORS — preflight OPTIONS

Le navigateur envoie un `OPTIONS` avant le `POST`. Trois cas :

- **A.** n8n gère le preflight automatiquement (headers CORS dans les Options du Webhook) → tester directement.
- **B.** Si échec : 2e node Webhook `OPTIONS` sur le même path + Respond 204 avec headers CORS.
- **C.** Le plus propre : CORS au niveau du reverse proxy (`n8n.fgcmedia.ch`). Exemple Caddy :
```
header {
  Access-Control-Allow-Origin "https://fgcmedia.ch"
  Access-Control-Allow-Methods "POST, OPTIONS"
  Access-Control-Allow-Headers "Content-Type"
}
@options method OPTIONS
respond @options 204
```

---

## 7. Ordre de construction & test

1. Table Supabase (déjà en place)
2. Nodes 1→5 dans l'ordre (Webhook → Function → Supabase → Email Resend → Respond)
3. Tester depuis n8n (données fictives) : score cohérent, ligne insérée, email reçu
4. Vérifier l'arrivée de l'email **en inbox** (Gmail + Outlook), pas en spam
5. Tester depuis le formulaire en ligne → révèle le CORS
6. Erreur CORS → section 6 B ou C
7. Activer le workflow

---

## 8. Vérifications

- [ ] **service_role key** Supabase uniquement dans n8n, jamais dans le front
- [ ] Domaine `fgcmedia.ch` authentifié dans Resend (SPF/DKIM/DMARC)
- [ ] `reply-to` vers une adresse consultée
- [ ] Email testé en inbox Gmail + Outlook
- [ ] Webhook en POST seul · workflow **activé**
- [ ] La page affiche `maturite` (pas l'opportunité) + jauge deux parties
- [ ] Tester un cas peu automatisé (maturité basse, « Beaucoup à gagner ») ET un cas mûr (« Déjà bien outillé »)
