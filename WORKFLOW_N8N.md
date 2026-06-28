# Workflow n8n — Diagnostic FGC Média

> Guide de construction node par node du workflow qui traite les soumissions
> du formulaire `/diagnostic`, calcule le score, génère le rapport IA, crée un
> brouillon Gmail et enregistre le lead dans Supabase.
>
> _Créé : 2026-06-27_

---

## Vue d'ensemble

```
Webhook (POST /diagnostic)
   │
   ▼
Function — Calcul du score
   │
   ▼
OpenAI — Génération des 3 priorités (gpt-4o-mini)
   │
   ├──────────────► Supabase — Insert lead
   │
   ▼
Gmail — Create Draft
   │
   ▼
Respond to Webhook — renvoie { score, palier, message, souscores }
```

Le **Respond to Webhook** clôt l'appel synchrone du navigateur : la page affiche
le score immédiatement. L'insert Supabase et le draft Gmail se font dans le même
flux, avant la réponse.

---

## 0. Table Supabase (à créer AVANT le workflow)

Dans le SQL Editor de la base **fgcmedia.ch** :

```sql
create table public.leads_diagnostic (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  -- Contact & qualification (colonnes propres pour filtrer/trier)
  nom text not null,
  email text not null,
  entreprise text,
  site text,
  secteur text,
  taille text,
  ca text,

  -- Résultat
  score int,
  palier text,
  score_sops int,
  score_auto int,
  score_integration int,

  -- Réponses détaillées complètes
  reponses jsonb not null,

  -- Suivi commercial
  rapport_genere text,        -- le texte des 3 priorités généré par l'IA
  statut text default 'nouveau' -- nouveau | contacté | converti | perdu
);

-- Index pour trier les leads chauds
create index idx_leads_score on public.leads_diagnostic (score desc);
create index idx_leads_created on public.leads_diagnostic (created_at desc);
```

> RLS : cette table n'est écrite que par n8n via la **service_role key** (qui
> bypasse RLS). Pas besoin de policy pour le formulaire public, puisque c'est
> n8n — pas le navigateur — qui écrit. Ne jamais exposer la service_role key côté
> front.

---

## 1. Node : Webhook

- **Type** : Webhook
- **HTTP Method** : `POST`
- **Path** : `diagnostic` (→ URL finale `https://n8n.fgcmedia.ch/webhook/diagnostic`)
- **Respond** : `Using 'Respond to Webhook' node`
- **Options → Response Headers** — ajouter les en-têtes CORS :
  | Name | Value |
  |---|---|
  | `Access-Control-Allow-Origin` | `https://fgcmedia.ch` |
  | `Access-Control-Allow-Methods` | `POST, OPTIONS` |
  | `Access-Control-Allow-Headers` | `Content-Type` |

> **Preflight CORS** : voir section CORS en fin de doc. Le navigateur envoie un
> OPTIONS avant le POST ; selon ta version de n8n il faut peut-être le gérer.

Le payload reçu est accessible via `{{ $json.body }}` (nom, email, gestion[], etc.).

---

## 2. Node : Function — Calcul du score

- **Type** : Code (Function)
- **Mode** : Run Once for All Items
- **Langage** : JavaScript

```javascript
// Récupère le payload du formulaire
const b = $input.first().json.body;

// --- Helpers ---
const toInt = (v) => parseInt(v, 10) || 0;
const arr = (v) => Array.isArray(v) ? v : [];

// --- A. Maturité automatisation (35 pts) : plus c'est manuel, plus le gisement ---
const auto = toInt(b.auto); // 1..5
const pA = ((5 - auto) / 4) * 35;

// --- B. Documentation / SOPs (15 pts) ---
const sops = toInt(b.sops); // 1..5
const pB = ((5 - sops) / 4) * 15;

// --- C. Dispersion des outils (20 pts) ---
const dispMap = { "1-3": 5, "4-6": 12, "7-10": 18, "Plus de 10": 20 };
const pC = dispMap[b.nbOutils] ?? 0;

// --- D. Surface d'inefficacité (20 pts), plafonnée à 5 zones ---
const nbZones = Math.min(arr(b.zones).length, 5);
const pD = (nbZones / 5) * 20;

// --- E. Mode de gestion (10 pts) ---
const g = arr(b.gestion);
let pE = 0;
if (g.includes("A")) pE += 5; // tableurs & email
if (g.includes("D")) pE += 5; // mélange + étapes manuelles
pE = Math.min(pE, 10);

// --- Score final ---
const score = Math.round(Math.max(0, Math.min(100, pA + pB + pC + pD + pE)));

// --- Palier ---
let palier, message;
if (score <= 30) {
  palier = "Gisement faible";
  message = "Votre organisation est déjà bien outillée. Quelques optimisations ciblées restent possibles.";
} else if (score <= 60) {
  palier = "Gisement modéré";
  message = "Il y a de vraies poches d'efficacité à récupérer, sur 2-3 zones prioritaires.";
} else {
  palier = "Gisement élevé";
  message = "Votre potentiel d'automatisation est important : plusieurs processus-clés peuvent être fluidifiés rapidement.";
}

// --- Sous-scores de maturité (/5) ---
const integration = { "1-3": 5, "4-6": 4, "7-10": 2, "Plus de 10": 1 }[b.nbOutils] ?? 3;
const souscores = {
  "Documentation": sops || 1,
  "Automatisation": auto || 1,
  "Intégration": integration,
};

// On transmet tout au node suivant
return [{
  json: {
    ...b,               // réponses brutes conservées
    score,
    palier,
    message,
    souscores,
    score_sops: sops,
    score_auto: auto,
    score_integration: integration,
  }
}];
```

---

## 3. Node : OpenAI — Génération des 3 priorités

- **Type** : OpenAI (ou HTTP Request vers l'API si tu préfères piloter finement)
- **Resource** : Chat / Message
- **Model** : `gpt-4o-mini`
- **Temperature** : `0.6`
- **Prompt (System ou User)** — coller, avec les expressions n8n `{{ }}` :

```
Tu es un consultant en automatisation pour PME. À partir des réponses ci-dessous
d'un dirigeant à un questionnaire d'auto-évaluation, rédige un court rapport en
français, ton professionnel et bienveillant (vouvoiement), SANS survente.

Contexte de l'entreprise :
- Secteur : {{ $json.secteur }}
- Taille : {{ $json.taille }} personnes
- Gestion actuelle (codes) : {{ $json.gestion }}
- Zones inefficaces (codes) : {{ $json.zones }}
- Nombre d'outils : {{ $json.nbOutils }}
- Outils en place (codes) : {{ $json.outils }}
- Documentation (1-5) : {{ $json.score_sops }}
- Automatisation (1-5) : {{ $json.score_auto }}
- Maux opérationnels : {{ $json.douleurs }}
- Vision de succès : {{ $json.vision }}

Score d'opportunité calculé : {{ $json.score }}/100 ({{ $json.palier }})

Rédige EXACTEMENT cette structure :
1. Un paragraphe de 2-3 phrases qui reformule leur situation avec empathie et
   relie leur vision de succès au potentiel identifié.
2. "Vos 3 priorités :" suivi de 3 points concrets, chacun avec un titre court et
   1-2 phrases (gain attendu + piste d'approche). Les priorités doivent être
   tirées de LEURS réponses, pas génériques.
3. Une phrase de clôture invitant à en discuter, sans pression.

Contraintes :
- Pas de jargon (éviter "SOP" → dire "procédures documentées").
- Reste honnête : si le gisement est faible, propose des optimisations ciblées
  plutôt que d'inventer des problèmes.
- Maximum ~250 mots.
- Ne promets aucun chiffre de ROI précis ; parle de "potentiel" et de "fourchette".
```

> Le texte généré sera dans `{{ $json.message.content }}` ou
> `{{ $json.choices[0].message.content }}` selon le node utilisé — vérifier la
> sortie réelle et ajuster la référence dans les nodes suivants.

---

## 4. Node : Supabase — Insert lead

- **Type** : Supabase
- **Operation** : Insert
- **Table** : `leads_diagnostic`
- **Credentials** : URL du projet + **service_role key** (Settings → API)
- **Champs** (mapping) :
  | Colonne | Valeur (expression n8n) |
  |---|---|
  | `nom` | `{{ $('Function').item.json.nom }}` |
  | `email` | `{{ $('Function').item.json.email }}` |
  | `entreprise` | `{{ $('Function').item.json.entreprise }}` |
  | `site` | `{{ $('Function').item.json.site }}` |
  | `secteur` | `{{ $('Function').item.json.secteur }}` |
  | `taille` | `{{ $('Function').item.json.taille }}` |
  | `ca` | `{{ $('Function').item.json.ca }}` |
  | `score` | `{{ $('Function').item.json.score }}` |
  | `palier` | `{{ $('Function').item.json.palier }}` |
  | `score_sops` | `{{ $('Function').item.json.score_sops }}` |
  | `score_auto` | `{{ $('Function').item.json.score_auto }}` |
  | `score_integration` | `{{ $('Function').item.json.score_integration }}` |
  | `reponses` | `{{ JSON.stringify($('Function').item.json) }}` |
  | `rapport_genere` | (référence à la sortie OpenAI, ex. `{{ $json.choices[0].message.content }}`) |

> Utiliser `$('Function')` pour pointer la sortie du node de calcul de façon
> fiable quel que soit l'ordre d'exécution.

---

## 5. Node : Gmail — Create Draft

- **Type** : Gmail
- **Resource** : Draft
- **Operation** : Create
- **Credentials** : compte `fgcmedia.sarl@gmail.com` (OAuth2)
- **To** : `{{ $('Function').item.json.email }}`
- **Subject** : `Votre diagnostic d'efficacité — {{ $('Function').item.json.entreprise }}`
- **Message** (corps, HTML ou texte) :

```
Bonjour {{ $('Function').item.json.nom }},

Merci d'avoir rempli le diagnostic d'efficacité.

Votre score d'opportunité : {{ $('Function').item.json.score }}/100
({{ $('Function').item.json.palier }})

{{ (référence à la sortie OpenAI — le texte des 3 priorités) }}

Si vous souhaitez en discuter, réservons un échange :
https://calendly.com/fgcmedia/rdv

Grégory Cardinale
FGC Média Sàrl
```

> C'est un **brouillon** (`Create`, pas `Send`). Il apparaît dans Gmail, tu le
> relis, ajustes, complètes, puis envoies manuellement. C'est le garde-fou humain.

---

## 6. Node : Respond to Webhook

- **Type** : Respond to Webhook
- **Respond With** : JSON
- **Response Body** :

```json
{
  "score": {{ $('Function').item.json.score }},
  "palier": "{{ $('Function').item.json.palier }}",
  "message": "{{ $('Function').item.json.message }}",
  "souscores": {{ JSON.stringify($('Function').item.json.souscores) }}
}
```

- **Options → Response Headers** : ajouter à nouveau `Access-Control-Allow-Origin: https://fgcmedia.ch`
  (les headers du webhook ne sont pas toujours hérités par le Respond node selon
  la version — les remettre ici est plus sûr).

Ce JSON correspond exactement au format attendu par `diagnostic.html` :
`{ score, palier, message, souscores }`.

---

## 7. CORS — gérer le preflight OPTIONS

Le navigateur envoie une requête `OPTIONS` avant le `POST` (preflight). Trois cas :

**A. Ta version de n8n gère le preflight automatiquement.**
Si les headers CORS sont dans les Options du Webhook (section 1), teste directement : si le
POST passe depuis fgcmedia.ch, rien à faire de plus.

**B. Le preflight échoue → second Webhook OPTIONS.**
Créer un **2e node Webhook** :
- Method : `OPTIONS`
- Path : `diagnostic` (même path)
- Suivi d'un **Respond to Webhook** renvoyant un statut 204 avec les headers :
  - `Access-Control-Allow-Origin: https://fgcmedia.ch`
  - `Access-Control-Allow-Methods: POST, OPTIONS`
  - `Access-Control-Allow-Headers: Content-Type`

**C. Gérer le CORS au niveau du reverse proxy (le plus propre).**
Comme n8n est sur `n8n.fgcmedia.ch`, il y a probablement un proxy (Nginx /
Traefik / Caddy) devant. Y ajouter les headers CORS une fois pour toutes évite de
les gérer dans chaque workflow. Exemple Caddy :
```
header {
  Access-Control-Allow-Origin "https://fgcmedia.ch"
  Access-Control-Allow-Methods "POST, OPTIONS"
  Access-Control-Allow-Headers "Content-Type"
}
@options method OPTIONS
respond @options 204
```

> Commence par A (le plus simple). Si le navigateur bloque avec une erreur CORS,
> passe à B ou C.

---

## 8. Ordre de construction & test

1. Créer la table Supabase (section 0)
2. Monter les nodes 1→6 dans l'ordre
3. **Tester d'abord depuis n8n** (bouton "Test workflow" + données fictives dans le webhook)
4. Vérifier : score cohérent, brouillon Gmail créé, ligne insérée dans Supabase
5. **Tester depuis le formulaire** en ligne (fgcmedia.ch/diagnostic) → c'est là que le CORS se révèle
6. Si erreur CORS dans la console navigateur → appliquer section 7 B ou C
7. Activer le workflow (toggle "Active" en haut à droite)

---

## 9. Vérifications de sécurité

- [ ] La **service_role key** Supabase est uniquement dans les credentials n8n, jamais dans le HTML/front
- [ ] Le webhook n'accepte que le POST (pas de méthode ouverte involontairement)
- [ ] L'email du draft pointe bien vers l'adresse du **prospect**, pas la tienne
- [ ] Le workflow est **activé** (sinon l'URL de prod renvoie 404)
- [ ] Tester un cas "gisement faible" ET un cas "gisement élevé" pour valider les paliers
```
