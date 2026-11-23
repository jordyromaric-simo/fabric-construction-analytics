/* =====================================================================
   Script 14 : ENTREPÔT (dw) — modèle en étoile
   ---------------------------------------------------------------------
   Dimensions : date, division, géographie, code de coût, client (maître),
                fournisseur (maître), projet, employé (SCD type 2), équipement
   Faits      : heures, coûts fournisseurs, utilisation d'équipement,
                coût de projet unifié, budget, facturation, encaissements,
                ordres de changement, objectifs
   Les tables sont créées UNE fois (DDL) puis rechargées par TRUNCATE +
   INSERT : leur identité ne change pas, ce qui est important pour
   Direct Lake (le modèle sémantique pointe toujours vers la même table).
   Exception : dim_employe est chargée en INCRÉMENTAL (SCD 2).
   ===================================================================== */

/* ================================================================== DDL */
IF OBJECT_ID('dw.dim_date') IS NULL
CREATE TABLE dw.dim_date (
    date_key                  int          NOT NULL,
    [date]                    date         NOT NULL,
    annee                     int          NOT NULL,
    trimestre                 int          NOT NULL,
    libelle_trimestre         varchar(10)  NOT NULL,
    mois                      int          NOT NULL,
    nom_mois                  varchar(12)  NOT NULL,
    nom_mois_court            varchar(6)   NOT NULL,
    annee_mois                varchar(7)   NOT NULL,
    debut_mois                date         NOT NULL,
    semaine_iso               int          NOT NULL,
    debut_semaine             date         NOT NULL,
    jour_semaine              int          NOT NULL,   -- 1 = lundi
    nom_jour                  varchar(10)  NOT NULL,
    est_fin_semaine           bit          NOT NULL,
    est_ferie                 bit          NOT NULL,
    est_vacances_construction bit          NOT NULL,
    est_jour_ouvrable         bit          NOT NULL,
    exercice                  varchar(12)  NOT NULL,   -- exercice financier mai → avril : « EF 2025-2026 »
    annee_exercice            int          NOT NULL,   -- 2026 pour EF 2025-2026
    mois_exercice             int          NOT NULL    -- mai = 1 … avril = 12
);
IF OBJECT_ID('dw.dim_division') IS NULL
CREATE TABLE dw.dim_division (division_id int NOT NULL, code_division varchar(5) NOT NULL, nom_division varchar(80) NOT NULL,
                              est_division_operationnelle bit NOT NULL);
IF OBJECT_ID('dw.dim_geographie') IS NULL
CREATE TABLE dw.dim_geographie (ville_id int NOT NULL, nom_ville varchar(100) NOT NULL, region_id int NOT NULL, nom_region varchar(80) NOT NULL);
IF OBJECT_ID('dw.dim_code_cout') IS NULL
CREATE TABLE dw.dim_code_cout (code_cout_id int NOT NULL, code_cout varchar(10) NOT NULL, description varchar(200) NOT NULL,
                               type_cout varchar(40) NOT NULL, code_section varchar(2) NOT NULL, nom_section varchar(100) NOT NULL);
IF OBJECT_ID('dw.dim_client') IS NULL
CREATE TABLE dw.dim_client (client_maitre_id int NOT NULL, no_client varchar(10) NOT NULL, nom_client varchar(200) NOT NULL,
                            type_client varchar(10) NULL, segment varchar(30) NULL, nom_ville varchar(100) NULL, nom_region varchar(80) NULL,
                            responsable_compte varchar(100) NULL, score_satisfaction int NULL, nb_fiches_sources int NOT NULL);
IF OBJECT_ID('dw.dim_fournisseur') IS NULL
CREATE TABLE dw.dim_fournisseur (fournisseur_maitre_id int NOT NULL, no_fournisseur varchar(10) NOT NULL, nom_fournisseur varchar(200) NOT NULL,
                                 categorie varchar(30) NULL, code_section varchar(2) NULL, nom_ville varchar(100) NULL, nb_fiches_sources int NOT NULL);
IF OBJECT_ID('dw.dim_projet') IS NULL
CREATE TABLE dw.dim_projet (
    projet_id int NOT NULL, no_projet varchar(12) NOT NULL, nom_projet varchar(250) NOT NULL, libelle_projet varchar(270) NOT NULL,
    client_maitre_id int NOT NULL, division_id int NOT NULL, ville_id int NOT NULL, charge_projet varchar(170) NULL,
    type_contrat varchar(20) NULL, statut varchar(20) NOT NULL, valeur_contrat decimal(14,2) NOT NULL,
    oc_approuves decimal(14,2) NOT NULL, valeur_revisee decimal(14,2) NOT NULL,
    date_debut_prevue date NULL, date_fin_prevue date NULL, date_debut_reelle date NULL, date_fin_reelle date NULL,
    annee_debut int NULL, tranche_valeur varchar(20) NOT NULL, pct_avancement_saisi decimal(5,1) NULL);
IF OBJECT_ID('dw.dim_employe') IS NULL
CREATE TABLE dw.dim_employe (
    employe_sk          bigint IDENTITY,          -- clé de substitution générée par Fabric
    employe_id          int          NOT NULL,    -- clé d'affaires (ERP)
    matricule           varchar(10)  NOT NULL,
    nom_complet         varchar(170) NOT NULL,
    code_metier         varchar(5)   NOT NULL,
    nom_metier          varchar(100) NOT NULL,
    categorie           varchar(20)  NOT NULL,    -- Chantier / Bureau
    division_id         int          NOT NULL,
    type_emploi         varchar(15)  NULL,
    statut              varchar(15)  NULL,
    date_embauche       date         NULL,
    date_depart         date         NULL,
    taux_horaire        decimal(8,2) NOT NULL,    -- attribut SCD 2 : historisé
    date_debut_validite date         NOT NULL,
    date_fin_validite   date         NOT NULL,    -- 9999-12-31 = version courante
    est_courant         bit          NOT NULL);
IF OBJECT_ID('dw.dim_employe_courant') IS NULL
CREATE TABLE dw.dim_employe_courant (employe_id int NOT NULL, employe_sk bigint NOT NULL, matricule varchar(10) NOT NULL,
    nom_complet varchar(170) NOT NULL, code_metier varchar(5) NOT NULL, nom_metier varchar(100) NOT NULL, categorie varchar(20) NOT NULL,
    division_id int NOT NULL, type_emploi varchar(15) NULL, statut varchar(15) NULL, taux_horaire decimal(8,2) NOT NULL,
    date_embauche date NULL, date_depart date NULL, anciennete_annees decimal(5,1) NULL);
IF OBJECT_ID('dw.dim_equipement') IS NULL
CREATE TABLE dw.dim_equipement (equipement_id int NOT NULL, no_unite varchar(10) NOT NULL, description varchar(150) NOT NULL,
    categorie varchar(40) NOT NULL, marque varchar(40) NULL, annee int NULL, age_annees int NULL, taux_horaire_interne decimal(8,2) NOT NULL,
    statut varchar(15) NULL, date_acquisition date NULL, date_disposition date NULL);

IF OBJECT_ID('dw.fait_heures') IS NULL
CREATE TABLE dw.fait_heures (date_key int NOT NULL, [date] date NOT NULL, employe_sk bigint NOT NULL, employe_id int NOT NULL,
    projet_id int NOT NULL, code_cout_id int NOT NULL, division_employe_id int NOT NULL, heures_reg decimal(7,2) NOT NULL,
    heures_supp decimal(7,2) NOT NULL, heures_total decimal(7,2) NOT NULL, taux_horaire decimal(8,2) NOT NULL,
    cout_mo decimal(14,2) NOT NULL, est_imputable bit NOT NULL);
IF OBJECT_ID('dw.fait_cout_fournisseur') IS NULL
CREATE TABLE dw.fait_cout_fournisseur (date_key int NOT NULL, [date] date NOT NULL, ligne_id bigint NOT NULL, facture_fourn_id int NOT NULL,
    fournisseur_maitre_id int NOT NULL, projet_id int NOT NULL, code_cout_id int NOT NULL, description varchar(250) NULL,
    quantite decimal(12,2) NULL, unite varchar(15) NULL, prix_unitaire decimal(14,4) NULL, montant_ht decimal(14,2) NOT NULL);
IF OBJECT_ID('dw.fait_utilisation_equipement') IS NULL
CREATE TABLE dw.fait_utilisation_equipement (date_key int NOT NULL, [date] date NOT NULL, equipement_id int NOT NULL, projet_id int NOT NULL,
    code_cout_id int NOT NULL, heures decimal(7,2) NOT NULL, cout_interne decimal(14,2) NOT NULL);
IF OBJECT_ID('dw.fait_cout_projet') IS NULL
CREATE TABLE dw.fait_cout_projet (date_key int NOT NULL, [date] date NOT NULL, projet_id int NOT NULL, code_cout_id int NOT NULL,
    source_cout varchar(30) NOT NULL, montant decimal(16,2) NOT NULL);
IF OBJECT_ID('dw.fait_budget') IS NULL
CREATE TABLE dw.fait_budget (projet_id int NOT NULL, code_cout_id int NOT NULL, budget_original decimal(14,2) NOT NULL,
    budget_revise decimal(14,2) NOT NULL);
IF OBJECT_ID('dw.fait_ordre_changement') IS NULL
CREATE TABLE dw.fait_ordre_changement (ordre_changement_id int NOT NULL, date_key int NOT NULL, [date] date NOT NULL, projet_id int NOT NULL,
    no_oc varchar(25) NOT NULL, description varchar(250) NULL, statut varchar(15) NOT NULL, montant decimal(14,2) NOT NULL);
IF OBJECT_ID('dw.fait_facture_client') IS NULL
CREATE TABLE dw.fait_facture_client (facture_client_id int NOT NULL, no_facture varchar(12) NOT NULL, date_key int NOT NULL, [date] date NOT NULL,
    date_echeance date NOT NULL, projet_id int NOT NULL, client_maitre_id int NOT NULL, type_facture varchar(30) NOT NULL,
    montant_ht decimal(14,2) NOT NULL, retenue decimal(14,2) NOT NULL, montant_net decimal(14,2) NOT NULL,
    taxes decimal(14,2) NOT NULL, montant_ttc decimal(14,2) NOT NULL, montant_encaisse decimal(14,2) NOT NULL,
    solde decimal(14,2) NOT NULL, date_dernier_paiement date NULL, jours_pour_payer int NULL, statut varchar(25) NOT NULL);
IF OBJECT_ID('dw.fait_encaissement') IS NULL
CREATE TABLE dw.fait_encaissement (encaissement_id int NOT NULL, date_key int NOT NULL, [date] date NOT NULL, facture_client_id int NOT NULL,
    projet_id int NOT NULL, client_maitre_id int NOT NULL, montant decimal(14,2) NOT NULL, mode_paiement varchar(15) NULL);
IF OBJECT_ID('dw.fait_facture_fournisseur') IS NULL
CREATE TABLE dw.fait_facture_fournisseur (facture_fourn_id int NOT NULL, date_key int NOT NULL, [date] date NOT NULL, date_echeance date NOT NULL,
    date_paiement date NULL, fournisseur_maitre_id int NOT NULL, montant_ht decimal(14,2) NOT NULL, montant_ttc decimal(14,2) NOT NULL,
    statut varchar(15) NOT NULL, est_doublon bit NOT NULL);
IF OBJECT_ID('dw.fait_objectif_ca') IS NULL
CREATE TABLE dw.fait_objectif_ca (division_id int NOT NULL, mois date NOT NULL, objectif_ca decimal(14,2) NOT NULL);
IF OBJECT_ID('dw.fait_objectif_marge') IS NULL
CREATE TABLE dw.fait_objectif_marge (division_id int NOT NULL, exercice varchar(12) NOT NULL, marge_cible decimal(6,4) NOT NULL);
GO

/* ================================================================== DIMENSION DATE
   Générée sans boucle ni CTE récursive (non supportée dans Fabric). */
CREATE OR ALTER PROCEDURE dw.usp_charger_dim_date @debut date = '2018-01-01', @fin date = '2028-12-31'
AS
BEGIN
    TRUNCATE TABLE dw.dim_date;
    INSERT INTO dw.dim_date
    SELECT YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d), d, YEAR(d), DATEPART(quarter, d),
           CONCAT('T', DATEPART(quarter, d), ' ', YEAR(d)), MONTH(d),
           CASE MONTH(d) WHEN 1 THEN 'janvier' WHEN 2 THEN 'février' WHEN 3 THEN 'mars' WHEN 4 THEN 'avril' WHEN 5 THEN 'mai'
                         WHEN 6 THEN 'juin' WHEN 7 THEN 'juillet' WHEN 8 THEN 'août' WHEN 9 THEN 'septembre' WHEN 10 THEN 'octobre'
                         WHEN 11 THEN 'novembre' ELSE 'décembre' END,
           CASE MONTH(d) WHEN 1 THEN 'janv.' WHEN 2 THEN 'févr.' WHEN 3 THEN 'mars' WHEN 4 THEN 'avr.' WHEN 5 THEN 'mai'
                         WHEN 6 THEN 'juin' WHEN 7 THEN 'juil.' WHEN 8 THEN 'août' WHEN 9 THEN 'sept.' WHEN 10 THEN 'oct.'
                         WHEN 11 THEN 'nov.' ELSE 'déc.' END,
           CONCAT(YEAR(d), '-', RIGHT(CONCAT('0', MONTH(d)), 2)),
           DATEFROMPARTS(YEAR(d), MONTH(d), 1),
           DATEPART(iso_week, d),
           DATEADD(day, -(js - 1), d),
           js,
           CASE js WHEN 1 THEN 'lundi' WHEN 2 THEN 'mardi' WHEN 3 THEN 'mercredi' WHEN 4 THEN 'jeudi'
                   WHEN 5 THEN 'vendredi' WHEN 6 THEN 'samedi' ELSE 'dimanche' END,
           CASE WHEN js >= 6 THEN 1 ELSE 0 END,
           ferie,
           vac,
           CASE WHEN js < 6 AND ferie = 0 AND vac = 0 THEN 1 ELSE 0 END,
           CASE WHEN MONTH(d) >= 5 THEN CONCAT('EF ', YEAR(d), '-', YEAR(d) + 1) ELSE CONCAT('EF ', YEAR(d) - 1, '-', YEAR(d)) END,
           CASE WHEN MONTH(d) >= 5 THEN YEAR(d) + 1 ELSE YEAR(d) END,
           CASE WHEN MONTH(d) >= 5 THEN MONTH(d) - 4 ELSE MONTH(d) + 8 END
    FROM (
        SELECT d, js,
               -- fériés principaux (Pâques non calculé) : 1er janv., patriotes, 24 juin, 1er juillet, fête du Travail, Action de grâce, Noël
               CASE WHEN (MONTH(d) = 1 AND DAY(d) = 1) OR (MONTH(d) = 6 AND DAY(d) = 24) OR (MONTH(d) = 7 AND DAY(d) = 1)
                         OR (MONTH(d) = 12 AND DAY(d) IN (25, 26))
                         OR (MONTH(d) = 9 AND js = 1 AND DAY(d) <= 7)
                         OR (MONTH(d) = 10 AND js = 1 AND DAY(d) BETWEEN 8 AND 14)
                         OR (MONTH(d) = 5 AND js = 1 AND DAY(d) BETWEEN 18 AND 24)
                    THEN 1 ELSE 0 END AS ferie,
               -- vacances de la construction : 2 semaines dès l'avant-dernier dimanche de juillet + 21 déc. → 3 janv.
               CASE WHEN d BETWEEN DATEADD(day, -7 - (DATEDIFF(day, '19000107', DATEFROMPARTS(YEAR(d), 7, 31)) % 7), DATEFROMPARTS(YEAR(d), 7, 31))
                               AND DATEADD(day, 6 - (DATEDIFF(day, '19000107', DATEFROMPARTS(YEAR(d), 7, 31)) % 7), DATEFROMPARTS(YEAR(d), 7, 31))
                         OR (MONTH(d) = 12 AND DAY(d) >= 21) OR (MONTH(d) = 1 AND DAY(d) <= 3)
                    THEN 1 ELSE 0 END AS vac
        FROM (
            SELECT d, (DATEDIFF(day, '19000101', d) % 7) + 1 AS js      -- 1900-01-01 était un lundi
            -- suite de nombres 0..N : on « emprunte » les lignes d'une grosse table (astuce classique)
            FROM (SELECT DATEADD(day, n, @debut) AS d
                  FROM (SELECT TOP (DATEDIFF(day, @debut, @fin) + 1)
                               CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS int) AS n
                        FROM stg.feuille_temps) nums) jours
        ) j
    ) x;
END
GO

/* ================================================================== DIMENSIONS SIMPLES */
CREATE OR ALTER PROCEDURE dw.usp_charger_dimensions
AS
BEGIN
    TRUNCATE TABLE dw.dim_division;
    INSERT INTO dw.dim_division
    SELECT division_id, code_division, nom_division, CASE WHEN code_division = 'ADM' THEN 0 ELSE 1 END FROM stg.division
    UNION ALL SELECT -1, 'N/D', 'Non déterminé', 0;

    TRUNCATE TABLE dw.dim_geographie;
    INSERT INTO dw.dim_geographie
    SELECT v.ville_id, v.nom_ville, r.region_id, r.nom_region FROM stg.ville v JOIN stg.region r ON r.region_id = v.region_id
    UNION ALL SELECT -1, 'Inconnue', -1, 'Inconnue';

    TRUNCATE TABLE dw.dim_code_cout;
    INSERT INTO dw.dim_code_cout
    SELECT code_cout_id, code_cout, description, type_cout, code_section, nom_section FROM stg.code_cout
    UNION ALL SELECT -1, 'NC', 'Non classé (code manquant sur la facture)', 'Non classé', '99', 'Non classé';

    TRUNCATE TABLE dw.dim_client;
    INSERT INTO dw.dim_client
    SELECT c.client_maitre_id, c.no_client, c.nom_client, c.type_client, c.segment, g.nom_ville, g.nom_region,
           c.responsable_compte, c.score_satisfaction, c.nb_fiches_erp + c.nb_fiches_crm
    FROM mdm.client c LEFT JOIN dw.dim_geographie g ON g.ville_id = c.ville_id
    UNION ALL SELECT -1, 'N/D', 'Client inconnu', NULL, NULL, NULL, NULL, NULL, NULL, 0;

    TRUNCATE TABLE dw.dim_fournisseur;
    INSERT INTO dw.dim_fournisseur
    SELECT f.fournisseur_maitre_id, f.no_fournisseur, f.nom_fournisseur, f.categorie, f.code_section, g.nom_ville, f.nb_fiches
    FROM mdm.fournisseur f LEFT JOIN dw.dim_geographie g ON g.ville_id = f.ville_id
    UNION ALL SELECT -1, 'N/D', 'Fournisseur inconnu', NULL, NULL, NULL, 0;

    TRUNCATE TABLE dw.dim_projet;
    INSERT INTO dw.dim_projet
    SELECT p.projet_id, p.no_projet, p.nom_projet, CONCAT(p.no_projet, ' — ', p.nom_projet),
           ISNULL(x.client_maitre_id, -1), p.division_id, ISNULL(p.ville_id, -1),
           CONCAT(e.prenom, ' ', e.nom), p.type_contrat, p.statut, p.valeur_contrat,
           ISNULL(oc.montant, 0), p.valeur_contrat + ISNULL(oc.montant, 0),
           p.date_debut_prevue, p.date_fin_prevue, p.date_debut_reelle, p.date_fin_reelle,
           YEAR(COALESCE(p.date_debut_reelle, p.date_debut_prevue)),
           CASE WHEN p.valeur_contrat < 500000 THEN '1. < 0,5 M$'
                WHEN p.valeur_contrat < 2000000 THEN '2. 0,5 à 2 M$'
                WHEN p.valeur_contrat < 10000000 THEN '3. 2 à 10 M$'
                ELSE '4. 10 M$ et +' END,
           p.pct_avancement_saisi
    FROM stg.projet p
    LEFT JOIN mdm.client_xref x ON x.source_systeme = 'ERP' AND x.source_id = CAST(p.client_id AS varchar(20))
    LEFT JOIN stg.employe e ON e.employe_id = p.charge_projet_id
    LEFT JOIN (SELECT projet_id, SUM(montant) AS montant FROM stg.ordre_changement WHERE statut = 'Approuvé' GROUP BY projet_id) oc
           ON oc.projet_id = p.projet_id
    UNION ALL
    SELECT -1, 'ADM', 'Temps administratif (non imputable)', 'ADM — Temps administratif', -1, 6, -1, NULL, NULL, 'N/A',
           0, 0, 0, NULL, NULL, NULL, NULL, NULL, 'N/A', NULL;

    TRUNCATE TABLE dw.dim_equipement;
    INSERT INTO dw.dim_equipement
    SELECT equipement_id, no_unite, description, categorie, marque, annee,
           YEAR((SELECT MAX(date_ref) FROM audit.date_reference)) - annee,
           taux_horaire_interne, statut, date_acquisition, date_disposition
    FROM stg.equipement;
END
GO

/* ================================================================== DIMENSION EMPLOYÉ — SCD TYPE 2
   Le taux horaire change chaque 1er mai : on garde une VERSION par période
   pour que les heures de 2021 soient valorisées au taux de 2021.
   Les autres attributs (nom, statut, métier) sont en type 1 : écrasés.   */
CREATE OR ALTER PROCEDURE dw.usp_charger_dim_employe
AS
BEGIN
    /* a) Type 1 : mise à jour des attributs descriptifs sur toutes les versions */
    UPDATE d
       SET nom_complet = CONCAT(e.prenom, ' ', e.nom), matricule = e.matricule, code_metier = m.code_metier,
           nom_metier = m.nom_metier, categorie = m.categorie, division_id = e.division_id, type_emploi = e.type_emploi,
           statut = e.statut, date_embauche = e.date_embauche, date_depart = e.date_depart
      FROM dw.dim_employe d
      JOIN stg.employe e ON e.employe_id = d.employe_id
      JOIN stg.metier m  ON m.metier_id = e.metier_id;

    /* b) Type 2 : fermer les versions dont la période de taux est maintenant terminée */
    UPDATE d
       SET date_fin_validite = t.date_fin, est_courant = 0
      FROM dw.dim_employe d
      JOIN stg.taux_horaire t ON t.employe_id = d.employe_id AND t.date_debut = d.date_debut_validite
     WHERE d.est_courant = 1 AND t.date_fin IS NOT NULL;

    /* c) Type 2 : insérer les nouvelles versions (nouvelle période de taux, nouvel employé) */
    INSERT INTO dw.dim_employe (employe_id, matricule, nom_complet, code_metier, nom_metier, categorie, division_id,
                                type_emploi, statut, date_embauche, date_depart, taux_horaire,
                                date_debut_validite, date_fin_validite, est_courant)
    SELECT e.employe_id, e.matricule, CONCAT(e.prenom, ' ', e.nom), m.code_metier, m.nom_metier, m.categorie, e.division_id,
           e.type_emploi, e.statut, e.date_embauche, e.date_depart, t.taux_horaire,
           t.date_debut, ISNULL(t.date_fin, '9999-12-31'), CASE WHEN t.date_fin IS NULL THEN 1 ELSE 0 END
    FROM stg.taux_horaire t
    JOIN stg.employe e ON e.employe_id = t.employe_id
    JOIN stg.metier m  ON m.metier_id = e.metier_id
    WHERE NOT EXISTS (SELECT 1 FROM dw.dim_employe d WHERE d.employe_id = t.employe_id AND d.date_debut_validite = t.date_debut);

    /* d) Vue « à plat » de la version courante (1 ligne / employé) pour les rapports RH */
    TRUNCATE TABLE dw.dim_employe_courant;
    INSERT INTO dw.dim_employe_courant
    SELECT employe_id, employe_sk, matricule, nom_complet, code_metier, nom_metier, categorie, division_id, type_emploi, statut,
           taux_horaire, date_embauche, date_depart,
           CAST(DATEDIFF(day, date_embauche, ISNULL(date_depart, (SELECT MAX(date_ref) FROM audit.date_reference))) / 365.25 AS decimal(5,1))
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY employe_id ORDER BY date_debut_validite DESC) AS rn FROM dw.dim_employe) v
    WHERE rn = 1;
END
GO

/* ================================================================== FAITS */
CREATE OR ALTER PROCEDURE dw.usp_charger_faits
AS
BEGIN
    /* ---- Heures : valorisées au taux EN VIGUEUR à la date travaillée (grâce au SCD 2) */
    TRUNCATE TABLE dw.fait_heures;
    INSERT INTO dw.fait_heures
    SELECT YEAR(f.date_travail) * 10000 + MONTH(f.date_travail) * 100 + DAY(f.date_travail),
           f.date_travail,
           COALESCE(v.employe_sk, c.employe_sk),
           f.employe_id,
           ISNULL(f.projet_id, -1),
           f.code_cout_id,
           ISNULL(c.division_id, -1),
           f.heures_reg, f.heures_supp, f.heures_reg + f.heures_supp,
           COALESCE(v.taux_horaire, c.taux_horaire),
           CAST((f.heures_reg + 1.5 * f.heures_supp) * COALESCE(v.taux_horaire, c.taux_horaire) * (1 + ISNULL(pc.taux_charges_sociales, 0.45)) AS decimal(14,2)),
           CASE WHEN f.projet_id IS NULL THEN 0 ELSE 1 END
    FROM stg.feuille_temps f
    JOIN dw.dim_employe_courant c ON c.employe_id = f.employe_id
    LEFT JOIN dw.dim_employe v    ON v.employe_id = f.employe_id
                                 AND f.date_travail BETWEEN v.date_debut_validite AND v.date_fin_validite
    LEFT JOIN stg.parametre_cout pc ON pc.annee = YEAR(f.date_travail);

    /* ---- Factures fournisseurs (entêtes) : on garde les doublons mais marqués */
    TRUNCATE TABLE dw.fait_facture_fournisseur;
    INSERT INTO dw.fait_facture_fournisseur
    SELECT ff.facture_fourn_id, YEAR(ff.date_facture) * 10000 + MONTH(ff.date_facture) * 100 + DAY(ff.date_facture), ff.date_facture,
           ff.date_echeance, ff.date_paiement, ISNULL(x.fournisseur_maitre_id, -1), ff.montant_ht, ff.montant_ttc, ff.statut, ff.est_doublon
    FROM stg.facture_fournisseur ff
    LEFT JOIN mdm.fournisseur_xref x ON x.fournisseur_id = ff.fournisseur_id;

    /* ---- Coûts fournisseurs (lignes) : SANS les factures en double */
    TRUNCATE TABLE dw.fait_cout_fournisseur;
    INSERT INTO dw.fait_cout_fournisseur
    SELECT YEAR(ff.date_facture) * 10000 + MONTH(ff.date_facture) * 100 + DAY(ff.date_facture), ff.date_facture,
           l.ligne_id, l.facture_fourn_id, ISNULL(x.fournisseur_maitre_id, -1), l.projet_id, l.code_cout_id,
           l.description, l.quantite, l.unite, l.prix_unitaire, l.montant_ligne
    FROM stg.facture_fournisseur_ligne l
    JOIN stg.facture_fournisseur ff ON ff.facture_fourn_id = l.facture_fourn_id AND ff.est_doublon = 0
    LEFT JOIN mdm.fournisseur_xref x ON x.fournisseur_id = ff.fournisseur_id;

    /* ---- Équipements internes : règle d'imputation à un code de coût selon la catégorie */
    TRUNCATE TABLE dw.fait_utilisation_equipement;
    INSERT INTO dw.fait_utilisation_equipement
    SELECT YEAR(u.date_utilisation) * 10000 + MONTH(u.date_utilisation) * 100 + DAY(u.date_utilisation), u.date_utilisation,
           u.equipement_id, u.projet_id, ISNULL(cc.code_cout_id, -1), u.heures,
           CAST(u.heures * e.taux_horaire_interne AS decimal(14,2))
    FROM stg.utilisation_equipement u
    JOIN stg.equipement e ON e.equipement_id = u.equipement_id
    LEFT JOIN stg.code_cout cc ON cc.code_cout =
         CASE WHEN e.categorie IN ('Excavatrice', 'Bouteur', 'Chargeuse sur roues', 'Rétrocaveuse', 'Mini-excavatrice', 'Camion 10 roues') THEN '02-EQ'
              WHEN e.categorie = 'Compacteur' THEN '32-EQ'
              WHEN e.categorie IN ('Grue mobile', 'Chariot télescopique') THEN '03-EQ'
              WHEN e.categorie = 'Nacelle articulée' THEN '05-EQ'
              ELSE '01-EQ' END;

    /* ---- Coût de projet UNIFIÉ (jour × projet × code × source) : la table de faits centrale */
    TRUNCATE TABLE dw.fait_cout_projet;
    INSERT INTO dw.fait_cout_projet
    SELECT date_key, [date], projet_id, code_cout_id, 'Main-d''œuvre', SUM(cout_mo)
    FROM dw.fait_heures WHERE projet_id <> -1 GROUP BY date_key, [date], projet_id, code_cout_id
    UNION ALL
    SELECT date_key, [date], projet_id, code_cout_id, 'Fournisseurs', SUM(montant_ht)
    FROM dw.fait_cout_fournisseur GROUP BY date_key, [date], projet_id, code_cout_id
    UNION ALL
    SELECT date_key, [date], projet_id, code_cout_id, 'Équipement interne', SUM(cout_interne)
    FROM dw.fait_utilisation_equipement GROUP BY date_key, [date], projet_id, code_cout_id;

    /* ---- Budget : version originale et dernière version révisée */
    TRUNCATE TABLE dw.fait_budget;
    INSERT INTO dw.fait_budget
    SELECT b.projet_id, b.code_cout_id,
           SUM(CASE WHEN b.version = 'Original' THEN b.montant ELSE 0 END),
           SUM(CASE WHEN b.version = d.derniere_version THEN b.montant ELSE 0 END)
    FROM stg.budget b
    JOIN (SELECT projet_id, MAX(version) AS derniere_version FROM stg.budget GROUP BY projet_id) d ON d.projet_id = b.projet_id
    GROUP BY b.projet_id, b.code_cout_id;
    -- NB : MAX(version) fonctionne parce que « Révisé 1 » > « Original » ; une vraie version numérotée serait plus robuste.

    TRUNCATE TABLE dw.fait_ordre_changement;
    INSERT INTO dw.fait_ordre_changement
    SELECT ordre_changement_id, YEAR(date_oc) * 10000 + MONTH(date_oc) * 100 + DAY(date_oc), date_oc, projet_id, no_oc, description, statut, montant
    FROM stg.ordre_changement;

    /* ---- Facturation client + encaissements */
    TRUNCATE TABLE dw.fait_facture_client;
    INSERT INTO dw.fait_facture_client
    SELECT f.facture_client_id, f.no_facture, YEAR(f.date_facture) * 10000 + MONTH(f.date_facture) * 100 + DAY(f.date_facture),
           f.date_facture, f.date_echeance, f.projet_id, ISNULL(x.client_maitre_id, -1), f.type_facture,
           f.montant_ht, f.retenue, f.montant_net, f.tps + f.tvq, f.montant_ttc,
           ISNULL(e.encaisse, 0), f.montant_ttc - ISNULL(e.encaisse, 0), e.dernier_paiement,
           CASE WHEN f.montant_ttc - ISNULL(e.encaisse, 0) <= 0.01 THEN DATEDIFF(day, f.date_facture, e.dernier_paiement) END,
           f.statut
    FROM stg.facture_client f
    LEFT JOIN mdm.client_xref x ON x.source_systeme = 'ERP' AND x.source_id = CAST(f.client_id AS varchar(20))
    LEFT JOIN (SELECT facture_client_id, SUM(montant) AS encaisse, MAX(date_encaissement) AS dernier_paiement
               FROM stg.encaissement GROUP BY facture_client_id) e ON e.facture_client_id = f.facture_client_id;

    TRUNCATE TABLE dw.fait_encaissement;
    INSERT INTO dw.fait_encaissement
    SELECT e.encaissement_id, YEAR(e.date_encaissement) * 10000 + MONTH(e.date_encaissement) * 100 + DAY(e.date_encaissement),
           e.date_encaissement, e.facture_client_id, f.projet_id, f.client_maitre_id, e.montant, e.mode_paiement
    FROM stg.encaissement e
    JOIN dw.fait_facture_client f ON f.facture_client_id = e.facture_client_id;

    /* ---- Objectifs (fichier Excel de la direction, via Dataflow Gen2) */
    TRUNCATE TABLE dw.fait_objectif_ca;
    INSERT INTO dw.fait_objectif_ca
    SELECT d.division_id, o.mois, SUM(o.objectif_ca)
    FROM stg.objectif_ca o JOIN stg.division d ON d.code_division = o.code_division
    GROUP BY d.division_id, o.mois;

    TRUNCATE TABLE dw.fait_objectif_marge;
    INSERT INTO dw.fait_objectif_marge
    SELECT d.division_id, o.exercice, o.marge_cible
    FROM stg.objectif_marge o JOIN stg.division d ON d.code_division = o.code_division;
END
GO

CREATE OR ALTER PROCEDURE dw.usp_charger_tout @execution_id varchar(40)
AS
BEGIN
    DECLARE @t datetime2(6);
    IF NOT EXISTS (SELECT 1 FROM dw.dim_date) EXEC dw.usp_charger_dim_date;
    SET @t = SYSDATETIME(); EXEC dw.usp_charger_dimensions;  EXEC audit.usp_journaliser @execution_id, 'dw.dimensions', @t;
    SET @t = SYSDATETIME(); EXEC dw.usp_charger_dim_employe; EXEC audit.usp_journaliser @execution_id, 'dw.dim_employe (SCD2)', @t;
    SET @t = SYSDATETIME(); EXEC dw.usp_charger_faits;       EXEC audit.usp_journaliser @execution_id, 'dw.faits', @t;
END
GO
