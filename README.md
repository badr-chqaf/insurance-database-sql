# Assur+ : base de données d'un cabinet de courtage en assurance

Conception d'une base de données relationnelle (méthode Merise, SQLite) pour un cabinet de courtage : contrats, sinistres, experts, courtiers et objectifs commerciaux, avec un accent sur l'**intégrité des données**.

Projet réalisé dans le cadre de l'UE Bases de données du M1 Data Science (Aix-Marseille Université, 2026).

## Contexte

Le cabinet Assur+ met en relation ses clients avec des compagnies d'assurance (automobile, habitation, santé). Il souhaite :

- suivre l'état de chaque sinistre : déclaré, en cours d'expertise, indemnisé ou refusé ;
- connaître à tout moment le montant total versé à un client ;
- compter, pour chaque type de risque, le nombre de sinistres d'une année, afin d'ajuster ses tarifs ;
- fixer chaque année à chaque courtier un objectif de contrats à vendre, par type de risque.

L'énoncé (détaillées dans le rapport) étant volontairement ambigu, une partie du travail a consisté à expliciter les hypothèses retenues. 

## Démarche

1. **Dictionnaire des données** : inventaire et typage des propriétés.
2. **Règles de gestion et hypothèses** : levée des ambiguïtés de l'énoncé.
3. **Modèle conceptuel (MCD)** en notation Merise.
4. **Passage au modèle relationnel**, puis implémentation SQL avec contraintes.

## Schéma relationnel

Clés primaires en **gras**, clés étrangères précédées de `#`.

- Courtier (**NumCourtier**, NomCourtier, PrenomCourtier)
- Client (**NumClient**, NomClient, PrenomClient, #NumCourtier)
- Compagnie (**NumCompagnie**, NomCompagnie)
- Risque (**TypeRisque**)
- Contrat (**NumContrat**, Prime, CommissionTaux, DateDebutContrat, DateFinContrat, #NumClient, #TypeRisque, #NumCompagnie)
- Expert (**NumExpert**, NomExpert, PrenomExpert)
- Sinistre (**NumSinistre**, DateSinistre, DateDecla, Etat, MontantDommage, #NumExpert, #NumContrat)
- Objectif (**Annee, #TypeRisque, #NumCourtier**, NbObjectif)

## Choix d'intégrité

L'objectif est que la base **refuse d'elle-même** les données incohérentes, plutôt que de compter sur l'application qui l'alimente.

| Règle métier | Implémentation |
|---|---|
| Tout client est suivi par un courtier | `NumCourtier NOT NULL` + clé étrangère |
| Un sinistre est déclaré après être survenu | `CHECK (DateDecla >= DateSinistre)` |
| Un sinistre seulement déclaré n'a pas encore d'expert ; à partir de l'expertise, il en a un | `CHECK` liant `Etat` et `NumExpert` |
| Le montant n'existe qu'une fois l'expertise terminée (indemnisé ou refusé) | `CHECK` liant `Etat` et `MontantDommage` |
| Taux de commission compris entre 0 et 1, primes et montants positifs | `CHECK` sur les bornes |
| Un seul objectif par courtier, par risque et par année | Clé primaire composée `(Annee, TypeRisque, NumCourtier)` |
| Un sinistre survient pendant la période de son contrat | Règle portant sur deux tables, donc impossible à vérifier par un `CHECK` : contrôlée par une **requête de contrôle** qui doit renvoyer un résultat vide |

**Tests des contraintes** : le script contient une série d'insertions volontairement invalides (courtier inexistant, état inconnu, sinistre déclaré avant d'être survenu, objectif en double…). Chacune doit être rejetée par la base, ce qui prouve que la contrainte correspondante fonctionne.

## Jeu de données

Le jeu d'essai couvre volontairement les cas limites : les quatre états de sinistre, un sinistre refusé après expertise (montant évalué mais rien de versé), un client sans contrat, un courtier sans objectif, un contrat à prime nulle.

## Requêtes

**Demandées par l'énoncé**

1. Les contrats d'un client, avec le risque couvert et la prime.
2. Le montant total versé à un client au titre des sinistres indemnisés (0 s'il n'en a aucun).
3. Le nombre de sinistres déclarés par type de risque sur une année donnée, y compris les risques sans sinistre.

**Ajoutées**

4. Nombre de contrats et total des primes par compagnie, pour voir avec qui le cabinet travaille le plus.
5. Objectif fixé vs contrats réellement vendus par courtier et par risque sur une année.
6. Nombre de clients par courtier, y compris les courtiers sans client.

Les résultats attendus sont indiqués en commentaire sous chaque requête dans le script.

## Lancer le projet

Avec SQLite installé, depuis le dossier du projet :

```
sqlite3 assurplus.db
.mode box
.headers on
.read CHQAF_Badr_Assur+.sql
```

Les **messages d'erreur** affichés après execution, correspondent aux insertions invalides de la partie « Tests des contraintes », que la base doit rejeter.

Le script supprime et recrée les tables à chaque exécution : il peut être relancé autant de fois que nécessaire.

## Limites et pistes d'amélioration

Le modèle découle d'hypothèses simplificatrices, détaillées dans le rapport. Plusieurs évolutions permettraient de le rendre plus fidèle à la réalité :

- **Paiements** : les versements de primes ne sont pas enregistrés (hypothèse H2). Une entité `Paiement` reliée au contrat, avec la date et le montant de chaque versement, permettrait de suivre les mensualités, les impayés et les remboursements après résiliation.
- **Délai de déclaration** : un sinistre survenu pendant le contrat peut aujourd'hui être déclaré des années plus tard. On pourrait imposer un délai maximal, par exemple six mois après la survenance.
- **Déclarations suspectes** : rien n'empêche de souscrire un contrat, de déclarer un sinistre le jour même, puis de résilier. Une période de carence (par exemple un mois après la souscription) limiterait ce risque.
- **Plusieurs titulaires** : un contrat n'a qu'un titulaire (hypothèse H8). Couvrir un bien partagé, comme une voiture pour un couple, demanderait de transformer l'association `Souscrire` en association plusieurs-à-plusieurs, donc en table à part entière.
- **Historique des états** : seul l'état courant d'un sinistre est conservé. Une entité `HistoriqueEtat`, datant chaque changement d'état, permettrait de mesurer les délais de traitement.
- **Changement de courtier** : un client garde le même courtier. S'il pouvait en changer, il faudrait conserver l'historique daté des courtiers, pour savoir qui a vendu chaque contrat et perçu la commission.

La plupart de ces évolutions (paiements, délais, carence, historique des états) s'ajoutent au modèle sans modifier les tables existantes. Les deux dernières remplaceraient une association simple par une table d'historique ou de liaison, une transformation locale qui ne remet pas en cause le reste du découpage.

**Côté implémentation** : la règle « un sinistre survient pendant la période de son contrat » est vérifiée par une requête de contrôle, car un `CHECK` ne peut pas comparer deux tables. Un trigger permettrait de la faire respecter automatiquement à chaque insertion.

## Fichiers

| Fichier | Contenu |
|---|---|
| `CHQAF_Badr_Assur+.sql` | Création des tables, jeu de données, tests des contraintes, requêtes |
| `Rapport_Projet_SQL_CHQAF_Badr.pdf` | Rapport complet : dictionnaire des données, règles de gestion, hypothèses, MCD, schéma relationnel |

## Auteur

Chqaf Badr, M1 Data Science, Aix-Marseille Université
