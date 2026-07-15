# Workflow n8n — Diagnostic d'automatisation FGC Média

> Guide de construction node par node du workflow qui traite les soumissions
> du formulaire `/diagnostic`, calcule le score, génère le rapport IA, crée un
> brouillon Gmail et enregistre le lead dans Supabase.
>
> _Créé : 2026-06-27 · Mis à jour : 2026-06-27 (logique maturité)_

---

## Vue d'ensemble

```
Webhook (POST /diagnostic)
   │
   ▼
Function — Calcul du score (opportunité interne + maturité affichée)
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
Respond to Webhook — renvoie { maturite, palier, message }
```

Le **Respond to Webhook** clôt l'appel synchrone du navigateur : la page affiche
la maturité + la jauge immédiatement. L'insert Supabase et le draft Gmail se font
dans le même flux, avant la réponse.

> **Logique d'affichage** : on calcule le **score d'opportunité** en interne (plus
> c'est manuel, plus il est élevé) mais on **affiche la maturité** (`100 - opportunité`),
> plus intuitive. Voir `SCORECARD_SPEC.md` §1 et §3 pour le raisonnement.

---

## 0. Table Supabase (à créer AVANT le workflow)

Dans le SQL Editor de la base **fgcmedia.ch** :

```sql
create table public.leads_diagnostic (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),

  -- Contact & qualification
  nom text not null,
  email text not null,
  entreprise text,
  site text,
  secteur text,
  taille text,
  ca text,

  -- Résultat (score = opportunité, pour le tri commercial)
  score int,            -- score d'opportunité 0-100 (haut = lead chaud)
  palier text,
  score_sops int,
  score_auto int,

  -- Réponses détaillées complètes
  reponses jsonb not null,

  -- Suivi commercial
  rapport_genere text,            -- texte des 3 priorités généré par l'IA
  statut text default 'nouveau'   -- nouveau | contacté | converti | perdu
);

create index idx_leads_score on public.leads_diagnostic (score desc);
create index idx_leads_created on public.leads_diagnostic (created_at desc);
```

> La colonne `score` stocke l'**opportunité** (pas la maturité affichée) : ainsi
> `order by score desc` remonte les prospects les plus chauds (= les moins
> automatisés, ceux qui ont le plus à gagner).
>
> RLS : écrit uniquement par n8n via la **service_role key** (bypasse RLS). Ne
> jamais exposer cette clé côté front.

---

## 1. Node : Webhook

- **Type** : Webhook
- **HTTP Method** : `POST`
- **Path** : `diagnostic` (→ `https://n8n.fgcmedia.ch/webhook/diagnostic`)
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
// Récupère le payload du formulaire
const b = $input.first().json.body;

const toInt = (v) => parseInt(v, 10) || 0;
const arr = (v) => Array.isArray(v) ? v : [];

// --- A. Maturité automatisation (35 pts) : plus c'est manuel, plus le gisement ---
const auto = toInt(b.auto);                 // 1..5
const pA = ((5 - auto) / 4) * 35;

// --- B. Documentation / SOPs (15 pts) ---
const sops = toInt(b.sops);                 // 1..5
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
if (g.some(v => v.startsWith("Tableurs")))   pE += 5; // ex-code A
if (g.some(v => v.startsWith("Un mélange"))) pE += 5; // ex-code D
pE = Math.min(pE, 10);

// --- Score d'opportunité (interne, stocké pour le tri commercial) ---
const opportunite = Math.round(Math.max(0, Math.min(100, pA + pB + pC + pD + pE)));

// --- Maturité = valeur affichée (intuitive : bas = peu automatisé) ---
const maturite = 100 - opportunite;

// --- Palier basé sur l'opportunité (le manque), formulé côté gain ---
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
    ...b,               // réponses brutes conservées
    opportunite,        // pour Supabase (colonne score) et analyse
    maturite,           // affiché à l'écran
    score: opportunite, // compat colonne Supabase 'score'
    palier,
    message,
    score_sops: sops,
    score_auto: auto,
  }
}];
```

> Les sous-scores (Documentation / Automatisation / Intégration) ont été retirés :
> ils ne sont plus calculés ni renvoyés. Les valeurs brutes `sops` et `auto`
> restent stockées en base pour analyse.

---

## 3. Node : OpenAI — Génération des 3 priorités

- **Type** : OpenAI · **Model** : `gpt-4o-mini` · **Temperature** : `0.6`
- **Prompt** (expressions n8n `{{ }}`) :

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

Niveau de potentiel identifié : {{ $json.palier }}

Rédige EXACTEMENT cette structure :
1. Un paragraphe de 2-3 phrases qui reformule leur situation avec empathie et
   relie leur vision de succès au potentiel identifié.
2. "Vos 3 priorités :" suivi de 3 points concrets, chacun avec un titre court et
   1-2 phrases (gain attendu + piste d'approche). Les priorités doivent être
   tirées de LEURS réponses, pas génériques.
3. Une phrase de clôture invitant à en discuter, sans pression.

Contraintes :
- Pas de jargon (éviter "SOP" → dire "procédures documentées").
- Reste honnête : si le potentiel est faible, propose des optimisations ciblées
  plutôt que d'inventer des problèmes.
- Maximum ~250 mots.
- Ne promets aucun chiffre de ROI précis ; parle de "potentiel" et de "fourchette".
```

> Texte généré dans `{{ $json.message.content }}` ou `{{ $json.choices[0].message.content }}`
> selon le node — vérifier la sortie réelle et ajuster la référence en aval.

---

## 4. Node : Supabase — Insert lead

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
  | `rapport_genere` | (sortie OpenAI, ex. `{{ $json.choices[0].message.content }}`) |

> `score` reçoit `opportunite` (le manque) → tri commercial cohérent.

---

## 5. Node : Gmail — Create Draft

- **Type** : Gmail · **Resource** : Draft · **Operation** : Create
- **Credentials** : `fgcmedia.sarl@gmail.com` (OAuth2)
- **To** : `{{ $('Function').item.json.email }}`
- **Subject** : `Votre diagnostic d'automatisation — {{ $('Function').item.json.entreprise }}`
- **Message** :

```
Bonjour {{ $('Function').item.json.nom }},

Merci d'avoir rempli le diagnostic d'automatisation.

Niveau d'automatisation actuel : {{ $('Function').item.json.maturite }}/100
({{ $('Function').item.json.palier }})

{{ (sortie OpenAI — le texte des 3 priorités) }}

Si vous souhaitez en discuter, réservons un échange :
https://calendly.com/fgcmedia/rdv

Grégory Cardinale
FGC Média Sàrl
```

> **Brouillon** (`Create`, pas `Send`) : garde-fou humain. Évolution possible vers
> envoi auto (Resend) une fois la qualité validée — voir `SCORECARD_SPEC.md` §6.

---

## 6. Node : Respond to Webhook

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

> Ce JSON correspond exactement au format attendu par `diagnostic.html` :
> `{ maturite, palier, message }`. Les sous-scores ne sont plus renvoyés.

---

## 7. CORS — gérer le preflight OPTIONS

Le navigateur envoie un `OPTIONS` avant le `POST`. Trois cas :

**A. n8n gère le preflight automatiquement.**
Headers CORS dans les Options du Webhook (section 1) → tester directement. Si le
POST passe depuis fgcmedia.ch, rien de plus à faire.

**B. Le preflight échoue → 2e Webhook OPTIONS.**
Node Webhook `OPTIONS` sur le même path `diagnostic`, suivi d'un Respond renvoyant
204 + les headers CORS.

**C. CORS au niveau du reverse proxy (le plus propre).**
n8n étant sur `n8n.fgcmedia.ch`, ajouter les headers une fois dans le proxy
(Nginx / Traefik / Caddy). Exemple Caddy :
```
header {
  Access-Control-Allow-Origin "https://fgcmedia.ch"
  Access-Control-Allow-Methods "POST, OPTIONS"
  Access-Control-Allow-Headers "Content-Type"
}
@options method OPTIONS
respond @options 204
```

> Commencer par A, basculer vers B ou C si le navigateur bloque.

---

## 8. Ordre de construction & test

1. Créer la table Supabase (section 0)
2. Monter les nodes 1→6 dans l'ordre
3. **Tester depuis n8n** (bouton Test + données fictives)
4. Vérifier : maturité cohérente (= 100 − opportunité), brouillon Gmail créé, ligne en base
5. **Tester depuis le formulaire** en ligne → c'est là que le CORS se révèle
6. Erreur CORS en console → section 7 B ou C
7. Activer le workflow (toggle "Active")

---

## 9. Vérifications

- [ ] **service_role key** uniquement dans n8n, jamais dans le front
- [ ] Webhook en POST seul
- [ ] L'email du draft pointe vers le **prospect**
- [ ] Workflow **activé**
- [ ] La page affiche bien `maturite` (pas l'opportunité) : tester un cas peu
      automatisé (maturité basse, palier « Beaucoup à gagner ») ET un cas mûr
      (maturité haute, palier « Déjà bien outillé »)
- [ ] La jauge montre la partie pleine (niveau actuel) + vide (potentiel)
```
