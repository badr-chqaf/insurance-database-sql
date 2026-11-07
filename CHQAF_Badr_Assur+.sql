--Projet Assur+ - UE Bases de données SQL - CHQAF Badr - M1 DS

PRAGMA foreign_keys=ON; --Activation du contrôle des clés étrangères 





--1) Création des tables dans le bonne ordre, une table qui en réference une autre doit être crée après elle, un ordre possible serait : 
--Courtier / Client / Compagnie / Risque / Contrat / Expert / Sinistre / Objectif

--Mais d'abord suppression des tables si elles existent déjà (ordre inverse de la création car il y a des clés étrangères), pour pouvoir relancer le script plusieurs fois
DROP TABLE IF EXISTS Objectif;
DROP TABLE IF EXISTS Sinistre;
DROP TABLE IF EXISTS Expert;
DROP TABLE IF EXISTS Contrat;
DROP TABLE IF EXISTS Risque;
DROP TABLE IF EXISTS Compagnie;
DROP TABLE IF EXISTS Client;
DROP TABLE IF EXISTS Courtier;

--Les contraintes sur chaque attribut sont justifiées dans le rapport (Partie I - Justification des contraintes du dictionnaire) ainsi que les règles de gestion et hypothèses


CREATE TABLE Courtier(
    NumCourtier INTEGER PRIMARY KEY,  --clé primaire de la table 
    NomCourtier TEXT NOT NULL,
    PrenomCourtier TEXT NOT NULL
);

CREATE TABLE Client(
    NumClient INTEGER PRIMARY KEY, 
    NomClient TEXT NOT NULL,
    PrenomClient TEXT NOT NULL,
    NumCourtier INTEGER NOT NULL REFERENCES Courtier(NumCourtier)  -- NOT NULL car dans notre association Accompagner, la cardinalité est (1,1) donc NumCourtier ne doit pas être manquant (R1)

);

CREATE TABLE Compagnie(
    NumCompagnie INTEGER PRIMARY KEY,
    NomCompagnie TEXT NOT NULL
);

CREATE TABLE Risque(
    TypeRisque TEXT PRIMARY KEY CHECK(TypeRisque IN  ('HAB','AUTO','SANTE'))
);

CREATE TABLE Contrat(
    NumContrat INTEGER PRIMARY KEY,
    Prime REAL NOT NULL CHECK(Prime >=0),
    CommissionTaux REAL NOT NULL CHECK(CommissionTaux BETWEEN 0 and 1),
    DateDebutContrat DATE NOT NULL,  
    --ici la date de début de contrat avant la date de sinistre (R11) sera vérifier par une requête de contrôle car DateSinistre n'est pas dans la même table
    DateFinContrat DATE CHECK(DateFinContrat IS NULL OR DateFinContrat >= DateDebutContrat),
    NumClient INTEGER NOT NULL REFERENCES Client(NumClient), -- car cardinalité dans Souscrire est (1,1) (R3)
    TypeRisque TEXT NOT NULL REFERENCES Risque(TypeRisque),  -- Couvrir (1,1) (R5)
    NumCompagnie INTEGER NOT NULL REFERENCES Compagnie(NumCompagnie) -- Assurer (1,1) (R6)

);

CREATE TABLE Expert(
    NumExpert INTEGER PRIMARY KEY,
    NomExpert TEXT NOT NULL,
    PrenomExpert TEXT NOT NULL
);

CREATE TABLE Sinistre(
    NumSinistre INTEGER PRIMARY KEY,
    DateSinistre DATE NOT NULL, --même chose la contrainte qui vérifie que la date de sinistre vient entre une date de début de contrat de fin (ou juste après le début contrat si fin est vide)
    DateDecla DATE NOT NULL CHECK (DateDecla >= DateSinistre), --c'est le check de la règle de gestion R10
    Etat TEXT NOT NULL CHECK(ETAT in ('declare','en_expertise','refuse','indemnise')), --sans accents ni apostrophes ni espaces, pour bien éviter les erreurs de syntaxe
    NumExpert INTEGER REFERENCES Expert(NumExpert) CHECK((Etat = 'declare'AND NumExpert IS NULL) OR (Etat<>'declare' AND NumExpert IS NOT NULL)), -- Evaluer (0,1) (R7) et peut être vide (H11)
    NumContrat INTEGER NOT NULL REFERENCES Contrat(NumContrat),     -- Déclarer (1,1) (R4)
    MontantDommage REAL CHECK(MontantDommage >=0)
    CHECK((Etat IN ('declare','en_expertise') AND MontantDommage IS NULL) OR (Etat IN ('indemnise','refuse') AND MontantDommage IS NOT NULL))
    --MontantDommage peut être vide si aucun expert n'a encore été envoyé ou n'a pas encore évalué, cela correspond bien à Etat ='declare' ou 'en expertise (H12)
);

CREATE TABLE Objectif(
    Annee INTEGER NOT NULL,
    TypeRisque TEXT NOT NULL REFERENCES Risque(TypeRisque),
    NumCourtier INTEGER NOT NULL REFERENCES Courtier(NumCourtier),
    NbObjectif INTEGER NOT NULL CHECK(NbObjectif >=0), 
    PRIMARY KEY(Annee,TypeRisque,NumCourtier)

);


--2) Jeu d'essai :


-- Livail Ackerman n'a encore aucun objectif (H14)
INSERT INTO Courtier (NumCourtier, NomCourtier, PrenomCourtier) VALUES
(1, 'Ducaruge', 'Arthur'),
(2, 'Ackerman', 'Livail'),
(3, 'Zidane', 'Zinedine');

INSERT INTO Compagnie (NumCompagnie, NomCompagnie) VALUES
(1, 'TigreAssure'),
(2, 'DirectAssurance');

INSERT INTO Risque (TypeRisque) VALUES ('AUTO'), ('HAB'), ('SANTE');

INSERT INTO Expert (NumExpert, NomExpert, PrenomExpert) VALUES
(1, 'Chan', 'Jackie'),
(2, 'Lee', 'Bruce');

-- Ferrari Porsche n'a souscrit aucun contrat (H9)
INSERT INTO Client (NumClient, NomClient, PrenomClient, NumCourtier) VALUES
(1, 'Anderson', 'Elliot', 1),
(2, 'Ronaldo', 'Cristiano', 1),
(3, 'Ferrari', 'Porsche', 2);

--Contrat 4 offert au client donc prime à 0 (H5)

INSERT INTO Contrat (NumContrat, Prime, CommissionTaux, DateDebutContrat, DateFinContrat, NumClient, TypeRisque, NumCompagnie) VALUES
(1, 60.0, 0.10, '2025-01-01', NULL, 1, 'AUTO', 1),
(2, 25.0, 0.12, '2025-03-01', '2026-02-28', 1, 'HAB', 2),
(3, 120.0, 0.08, '2026-02-01', NULL, 2, 'AUTO', 2),
(4, 0.0, 0.10, '2026-05-01', NULL, 2, 'SANTE', 1);

--Les quatre états sont représentés (R8)
--Sinistres 1 et 2  indemnisés, Anderson doit avoir reçu 1500 + 800 = 2300 (pour bien tester la requête 2)
--Sinistre 3  montant évalué mais rien n'est versé car refusé après expertise (H1 et H12)
--Sinistre 4  en cours d'expertise et pas encore de montant
--Sinistre 5  seulement déclaré, ni expert ni montant (H11)
--Cristiano Ronaldo n'a aucun sinistre indemnisé donc la requête 2 doit afficher 0
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage) VALUES
(1, '2025-06-10', '2025-06-12', 'indemnise', 1, 1, 1500.0),
(2, '2025-12-28', '2026-01-04', 'indemnise', 1, 2, 800.0),
(3, '2026-03-15', '2026-03-16', 'refuse', 1, 1, 400.0),
(4, '2026-09-20', '2026-09-21', 'en_expertise', 1, 3, NULL),
(5, '2026-10-25', '2026-10-26', 'declare', NULL, 3, NULL);

--Objectifs de Ducaruge Arthur sur deux années avec un objectif nul en AUTO pour 2025 
INSERT INTO Objectif (Annee, TypeRisque, NumCourtier, NbObjectif) VALUES
(2025, 'AUTO',1,0),
(2026, 'AUTO', 1, 67),
(2026, 'HAB', 1, 20),
(2026, 'SANTE', 1,7);


--3) Tests des contraintes :
--Chaque insertion ci-dessous ne respecte pas une contrainte et doit logiquement être refusée avec un message d'erreur


--Client avec un courtier qui n'existe pas : 
INSERT INTO Client (NumClient, NomClient, PrenomClient, NumCourtier) VALUES (99, 'Tigre', 'Saillant', 999);
---> Error : FOREIGN KEY constraint failed

--Client sans courtier
INSERT INTO Client (NumClient, NomClient, PrenomClient, NumCourtier) VALUES (99, 'Beau', 'Gosse', NULL);
---> Error: NOT NULL constraint failed: Client.NumCourtier

-- Type de risque hors des trois valeurs de l'énoncé
INSERT INTO Risque (TypeRisque) VALUES ('MOTO');
---> Error: CHECK constraint failed: TypeRisque IN  ('HAB','AUTO','SANTE')

--Taux de commission hors borne [0,1]
INSERT INTO Contrat (NumContrat, Prime, CommissionTaux, DateDebutContrat, DateFinContrat, NumClient, TypeRisque, NumCompagnie)
VALUES (99, 110.9, 1.5, '2026-01-01', NULL, 1, 'AUTO', 1);
---> Error: CHECK constraint failed: CommissionTaux BETWEEN 0 and 1

--Contrat qui se finie avant d'avoir commencé
INSERT INTO Contrat (NumContrat, Prime, CommissionTaux, DateDebutContrat, DateFinContrat, NumClient, TypeRisque, NumCompagnie)
VALUES (99, 50.0, 0.10, '2026-01-01', '2025-12-31', 1, 'AUTO', 1);
---> Error: CHECK constraint failed: DateFinContrat IS NULL OR DateFinContrat >= DateDebutContrat

--Sinistre déclaré avant d'être survenu
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage)
VALUES (99, '2026-04-10', '2026-04-05', 'declare', NULL, 1, NULL);
-- ---> Error: CHECK constraint failed: DateDecla >= DateSinistre

--Etat inconnu
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage)
VALUES (99, '2026-04-10', '2026-04-11', 'perdu', 1, 1, NULL);
---> Error: CHECK constraint failed: ETAT in ('declare','en_expertise','refuse','indemnise')

--Sinistre seulement déclaré mais avec un expert envoyé
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage)
VALUES (99, '2026-04-10', '2026-04-11', 'declare', 1, 1, NULL);
---> Error: CHECK constraint failed: (Etat = 'declare'AND NumExpert IS NULL) OR (Etat<>'declare' AND NumExpert IS NOT NULL)

--Sinistre indemnisé mais sans montant évalué
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage)
VALUES (99, '2026-04-10', '2026-04-11', 'indemnise', 1, 1, NULL);
---> Error: CHECK constraint failed: (Etat IN ('declare','en_expertise') AND MontantDommage IS NULL) OR (Etat IN ('indemnise','refuse') AND MontantDommage IS NOT NULL)

--Second objectif pour le même courtier même risque et même année
INSERT INTO Objectif (Annee, TypeRisque, NumCourtier, NbObjectif) VALUES (2026, 'AUTO', 1, 12);
---> Error: UNIQUE constraint failed: Objectif.Annee, Objectif.TypeRisque, Objectif.NumCourtier

--Requête de contrôle R11 :
--Comme elle compare des dates de deux tables (Sinistre et Contrat) donc un CHECK ne peut pas la vérifier
--à la place on utilise une requête qui doit renvoyer vide en cherchant les sinistres survenus hors de la période de leur contrat :

--pour l'exemple prenons un sinistre survenu le 20/01/2026 sur le contrat 3, qui ne commence que le 01/02/2026, la base l'accepte car aucune contrainte de la table ne peut le refuser.
INSERT INTO Sinistre (NumSinistre, DateSinistre, DateDecla, Etat, NumExpert, NumContrat, MontantDommage)
VALUES (98, '2026-01-20', '2026-02-01', 'declare', NULL, 3, NULL); 

--la requête à tester :
SELECT s.NumSinistre, s.DateSinistre, c.NumContrat, c.DateDebutContrat, c.DateFinContrat
FROM Sinistre s
JOIN Contrat c ON c.NumContrat = s.NumContrat
WHERE s.DateSinistre < c.DateDebutContrat OR (c.DateFinContrat IS NOT NULL AND s.DateSinistre > c.DateFinContrat);
-- ╭─────────────┬──────────────┬────────────┬──────────────────┬────────────────╮
-- │ NumSinistre │ DateSinistre │ NumContrat │ DateDebutContrat │ DateFinContrat │
-- ╞═════════════╪══════════════╪════════════╪══════════════════╪════════════════╡
-- │          98 │ 2026-01-20   │          3 │ 2026-02-01       │                │
-- ╰─────────────┴──────────────┴────────────┴──────────────────┴────────────────╯

--Pour garder un jeu d'essai cohérent on supprime ce sinistre de test avec :
DELETE FROM Sinistre WHERE NumSinistre = 98;


--Requêtes de test :

--1)Pour un client donné : la liste des contrats qu'il a souscrits, avec le risque couvert et le montant de la prime :

SELECT NumContrat, TypeRisque, Prime 
FROM Contrat
WHERE NumClient=1;   --Client 1 pris pour le test

--╭────────────┬────────────┬───────╮
--│ NumContrat │ TypeRisque │ Prime │  Ce résultat est obtenu tout simplement en copiant et collant la sortie sur sqlite3 avec .mode box et .headers on puis ctrl+K et ctrl+C pour mettre '--' sur chaque ligne
--╞════════════╪════════════╪═══════╡  
--│          1 │ AUTO       │  60.0 │
--│          2 │ HAB        │  25.0 │
--╰────────────┴────────────┴───────╯ 


--2) Pour un client donné : le montant total qui lui a été versé au titre des sinistres indemnisés :
--Ici Client n'est pas directement relié à Sinistre donc il faut une jointure
SELECT COALESCE(SUM(s.MontantDommage),0)    --pour renvoyer 0 dans le cas où un client n'a pas de sinistre
FROM Sinistre s 
JOIN Contrat c ON s.NumContrat=c.NumContrat  --ici je fais un JOIN normal car j'ai uniquement besoin des NumSinistre qui corresponde au NumContrat du client donné
WHERE NumClient=1 AND Etat = 'indemnise';
-- ╭──────────────────────╮
-- │ COALESCE(SUM(s.Mo... │
-- ╞══════════════════════╡
-- │               2300.0 │
-- ╰──────────────────────╯


--3) Pour chaque type de risque : le nombre de sinistres déclarés au cours d'une année donnée : prenons 2026 pour l'exemple
--TypeRisque n'est pas dans la table Sinistre donc on doit faire une jointure
--même si toutes TypeRisque est dans Contrat, un LEFT JOIN est quand même nécessaire pour garder les types de risque sans sinistre (dans notre exemple SANTE)

SELECT r.TypeRisque, COUNT(NumSinistre) as NbSinistre
FROM Risque r LEFT JOIN Contrat c ON r.TypeRisque =c.TypeRisque
LEFT JOIN Sinistre s ON s.NumContrat = c.NumContrat AND  strftime('%Y',s.DateDecla) = '2026'  --pour écarter directement les sinistres hors 2026
GROUP BY r.TypeRisque;
-- ╭────────────┬────────────╮
-- │ TypeRisque │ NbSinistre │
-- ╞════════════╪════════════╡
-- │ AUTO       │          3 │
-- │ HAB        │          1 │
-- │ SANTE      │          0 │
-- ╰────────────┴────────────╯


--Requêtes de test supplémentaires au projet :
--4) Pour chaque compagnie d'assurance, le nombre de contrats souscrits chez elle et le total de leurs primes pour voir avec quelle compagnie le cabinet travaille le plus
--LEFT JOIN et COALESCE pour garder quand même une compagnie sans contrat (affichée avec 0)
SELECT co.NomCompagnie, COUNT(c.NumContrat) AS NbContrats, COALESCE(SUM(c.Prime), 0) AS TotalPrimes
FROM Compagnie co LEFT JOIN Contrat c ON c.NumCompagnie = co.NumCompagnie
GROUP BY co.NumCompagnie, co.NomCompagnie
ORDER BY TotalPrimes DESC;
-- ╭─────────────────┬────────────┬─────────────╮
-- │  NomCompagnie   │ NbContrats │ TotalPrimes │
-- ╞═════════════════╪════════════╪═════════════╡
-- │ DirectAssurance │          2 │       145.0 │
-- │ TigreAssure     │          2 │        60.0 │
-- ╰─────────────────┴────────────┴─────────────╯


--5) Pour chaque objectif d'une année, comparer le nombre de contrats fixé et le nombre de contrats réellement vendus par le courtier sur ce risque.
--prenons pour l'exemple l'année 2026
SELECT o.NumCourtier, o.TypeRisque, o.NbObjectif, COUNT(c.NumContrat) AS NbContratVendu
FROM Objectif o LEFT JOIN Client cl ON cl.NumCourtier = o.NumCourtier
LEFT JOIN Contrat c ON c.NumClient = cl.NumClient AND c.TypeRisque = o.TypeRisque AND strftime('%Y', c.DateDebutContrat) = '2026'
WHERE o.Annee = 2026
GROUP BY o.NumCourtier, o.TypeRisque, o.NbObjectif;
-- ╭─────────────┬────────────┬────────────┬────────────────╮
-- │ NumCourtier │ TypeRisque │ NbObjectif │ NbContratVendu │
-- ╞═════════════╪════════════╪════════════╪════════════════╡
-- │           1 │ AUTO       │         67 │              1 │
-- │           1 │ HAB        │         20 │              0 │
-- │           1 │ SANTE      │          7 │              1 │
-- ╰─────────────┴────────────┴────────────┴────────────────╯


--6) Pour chaque courtier son nombre de clients y compris ceux qui n’en ont aucun.
--on part de Courtier comme on veut afficher le nombre de clients
SELECT cou.NumCourtier, cou.NomCourtier, cou.PrenomCourtier, COUNT(cl.NumClient) AS NbClient
FROM Courtier cou LEFT JOIN Client cl ON cl.NumCourtier=cou.NumCourtier 
GROUP BY cou.NumCourtier, cou.NomCourtier, cou.PrenomCourtier;
-- ╭─────────────┬─────────────┬────────────────┬──────────╮
-- │ NumCourtier │ NomCourtier │ PrenomCourtier │ NbClient │
-- ╞═════════════╪═════════════╪════════════════╪══════════╡
-- │           1 │ Ducaruge    │ Arthur         │        2 │
-- │           2 │ Ackerman    │ Livail         │        1 │
-- │           3 │ Zidane      │ Zinedine       │        0 │
-- ╰─────────────┴─────────────┴────────────────┴──────────╯

