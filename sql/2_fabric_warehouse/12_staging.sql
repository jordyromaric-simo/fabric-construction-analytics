/* =====================================================================
   Script 12 : couche STAGING (stg)
   ---------------------------------------------------------------------
   Rôle : transformer le brut en données FIABLES.
     • garder la DERNIÈRE version de chaque ligne (le Copy job incrémental
       en mode « Append » empile les versions : ROW_NUMBER sur ModifiedAt)
     • retirer les lignes supprimées logiquement (IsDeleted = 1)
     • typer et normaliser (statuts, téléphones, codes postaux, noms)
     • isoler les lignes invalides dans des tables de rejet (quarantaine)
   ===================================================================== */

/* ------------------------------------------------------------------ RÉFÉRENCE */
CREATE OR ALTER PROCEDURE stg.usp_charger_reference
AS
BEGIN
    DROP TABLE IF EXISTS stg.region;
    CREATE TABLE stg.region AS
    SELECT CAST(RegionID AS int) AS region_id, CAST(TRIM(NomRegion) AS varchar(80)) AS nom_region
    FROM bronze.ref_region;

    DROP TABLE IF EXISTS stg.ville;
    CREATE TABLE stg.ville AS
    SELECT CAST(VilleID AS int) AS ville_id, CAST(TRIM(NomVille) AS varchar(100)) AS nom_ville, CAST(RegionID AS int) AS region_id
    FROM bronze.ref_ville;

    DROP TABLE IF EXISTS stg.division;
    CREATE TABLE stg.division AS
    SELECT CAST(DivisionID AS int) AS division_id, CAST(CodeDivision AS varchar(5)) AS code_division,
           CAST(NomDivision AS varchar(80)) AS nom_division
    FROM bronze.ref_division;

    DROP TABLE IF EXISTS stg.metier;
    CREATE TABLE stg.metier AS
    SELECT CAST(MetierID AS int) AS metier_id, CAST(CodeMetier AS varchar(5)) AS code_metier,
           CAST(NomMetier AS varchar(100)) AS nom_metier, CAST(Categorie AS varchar(20)) AS categorie,
           CAST(EstSyndique AS bit) AS est_syndique
    FROM bronze.ref_metier;

    DROP TABLE IF EXISTS stg.code_cout;
    CREATE TABLE stg.code_cout AS
    SELECT CAST(CodeCoutID AS int) AS code_cout_id, CAST(CodeCout AS varchar(10)) AS code_cout,
           CAST(Description AS varchar(200)) AS description, CAST(TypeCout AS varchar(40)) AS type_cout,
           CAST(CodeSection AS varchar(2)) AS code_section, CAST(NomSection AS varchar(100)) AS nom_section
    FROM bronze.ref_codecout;

    DROP TABLE IF EXISTS stg.parametre_cout;
    CREATE TABLE stg.parametre_cout AS
    SELECT CAST(Annee AS int) AS annee, CAST(TauxChargesSociales AS decimal(6,4)) AS taux_charges_sociales,
           CAST(TauxTPS AS decimal(6,5)) AS taux_tps, CAST(TauxTVQ AS decimal(6,5)) AS taux_tvq,
           CAST(TauxRetenue AS decimal(6,4)) AS taux_retenue
    FROM bronze.ref_parametrecout;
END
GO

/* ------------------------------------------------------------------ EMPLOYÉS ET TAUX */
CREATE OR ALTER PROCEDURE stg.usp_charger_employe
AS
BEGIN
    DROP TABLE IF EXISTS stg.employe;
    CREATE TABLE stg.employe AS
    SELECT CAST(EmployeID AS int)                 AS employe_id,
           CAST(Matricule AS varchar(10))         AS matricule,
           CAST(TRIM(Prenom) AS varchar(80))      AS prenom,
           -- certains noms sont saisis TOUT EN MAJUSCULES : on les remet en casse normale
           CAST(CASE WHEN Nom = UPPER(Nom)   -- la collation par défaut de Fabric est sensible à la casse
                     THEN CONCAT(UPPER(LEFT(TRIM(Nom), 1)), LOWER(SUBSTRING(TRIM(Nom), 2, 80)))
                     ELSE TRIM(Nom) END AS varchar(80)) AS nom,
           CAST(LOWER(Courriel) AS varchar(150))  AS courriel,
           CAST(MetierID AS int)                  AS metier_id,
           CAST(DivisionID AS int)                AS division_id,
           CAST(VilleID AS int)                   AS ville_id,
           CAST(DateEmbauche AS date)             AS date_embauche,
           CAST(DateDepart AS date)               AS date_depart,
           CAST(Statut AS varchar(15))            AS statut,
           CAST(TypeEmploi AS varchar(15))        AS type_emploi,
           CAST(SuperviseurID AS int)             AS superviseur_id,
           CAST(ModifiedAt AS datetime2(6))       AS modified_at
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY EmployeID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.paie_employe) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.taux_horaire;
    CREATE TABLE stg.taux_horaire AS
    SELECT CAST(TauxID AS int)            AS taux_id,
           CAST(EmployeID AS int)         AS employe_id,
           CAST(DateDebut AS date)        AS date_debut,
           CAST(DateFin AS date)          AS date_fin,
           CAST(TauxHoraire AS decimal(8,2)) AS taux_horaire
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY TauxID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.paie_tauxhoraire) d
    WHERE rn = 1;
END
GO

/* ------------------------------------------------------------------ CLIENTS ET FOURNISSEURS
   cle_nom = clé d'appariement : majuscules, sans accents, abréviations
   développées, sans ponctuation, sans espaces ni suffixe juridique.
   (Les REPLACE imbriqués remplacent TRANSLATE/fonctions : 100 % compatibles Fabric.)
   Elle sert à la couche MDM pour reconnaître « V. de Granby » et
   « Ville de Granby » comme la même organisation.                        */
CREATE OR ALTER PROCEDURE stg.usp_charger_client
AS
BEGIN
    DROP TABLE IF EXISTS stg.client;
    CREATE TABLE stg.client AS
    SELECT c.client_id, c.no_client, c.nom_client, c.type_client, c.segment, c.neq, c.adresse, c.ville_id,
           c.code_postal,
           -- téléphone : on garde les 10 chiffres puis on reformate (819) 555-1234
           CAST(CASE WHEN LEN(c.chiffres) = 10
                     THEN CONCAT('(', LEFT(c.chiffres, 3), ') ', SUBSTRING(c.chiffres, 4, 3), '-', RIGHT(c.chiffres, 4))
                END AS varchar(14)) AS telephone,
           c.courriel, c.conditions_paiement, c.limite_credit, c.created_at, c.modified_at,
           CAST(CASE WHEN RIGHT(c.k2, 3) = 'INC' THEN LEFT(c.k2, LEN(c.k2) - 3)
                     WHEN RIGHT(c.k2, 4) = 'LTEE' THEN LEFT(c.k2, LEN(c.k2) - 4)
                     ELSE c.k2 END AS varchar(200)) AS cle_nom
    FROM (
        SELECT CAST(ClientID AS int) AS client_id,
               CAST(NoClient AS varchar(10)) AS no_client,
               CAST(TRIM(REPLACE(REPLACE(NomClient, '   ', ' '), '  ', ' ')) AS varchar(200)) AS nom_client,
               CAST(TypeClient AS varchar(10)) AS type_client,
               CAST(Segment AS varchar(30)) AS segment,
               CAST(NULLIF(TRIM(NEQ), '') AS varchar(10)) AS neq,
               CAST(Adresse AS varchar(200)) AS adresse,
               CAST(VilleID AS int) AS ville_id,
               -- code postal : G9A5H3 / g9a 5h3 → G9A 5H3
               CAST(CASE WHEN LEN(REPLACE(REPLACE(UPPER(CodePostal), ' ', ''), '-', '')) = 6
                         THEN CONCAT(LEFT(REPLACE(REPLACE(UPPER(CodePostal), ' ', ''), '-', ''), 3), ' ',
                                     RIGHT(REPLACE(REPLACE(UPPER(CodePostal), ' ', ''), '-', ''), 3))
                    END AS varchar(7)) AS code_postal,
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Telephone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', '') AS chiffres,
               CAST(LOWER(TRIM(Courriel)) AS varchar(150)) AS courriel,
               CAST(ConditionsPaiement AS int) AS conditions_paiement,
               CAST(LimiteCredit AS decimal(14,2)) AS limite_credit,
               CAST(CreatedAt AS datetime2(6)) AS created_at,
               CAST(ModifiedAt AS datetime2(6)) AS modified_at,
               -- clé d'appariement : majuscules, sans accents, abréviations développées, sans ponctuation ni espaces
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CONCAT(' ', REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(NomClient), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Ç', 'C')), ' V. DE ', ' VILLE DE '), ' MUN. ', ' MUNICIPALITE DE '), ' CSS ', ' CENTRE DE SERVICES SCOLAIRE '), ' MTQ ', ' MINISTERE DES TRANSPORTS '), '.', ''), ',', ''), '-', ''), '''', ''), '—', ''), '&', ''), '(', ''), ')', ''), ' ', '') AS k2
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY ClientID ORDER BY ModifiedAt DESC) AS rn
              FROM bronze.vente_client) b
        WHERE rn = 1
    ) c;
END
GO

CREATE OR ALTER PROCEDURE stg.usp_charger_fournisseur
AS
BEGIN
    DROP TABLE IF EXISTS stg.fournisseur;
    CREATE TABLE stg.fournisseur AS
    SELECT f.fournisseur_id, f.no_fournisseur, f.nom_fournisseur, f.categorie, f.code_section, f.neq, f.ville_id,
           CAST(CASE WHEN LEN(f.chiffres) = 10
                     THEN CONCAT('(', LEFT(f.chiffres, 3), ') ', SUBSTRING(f.chiffres, 4, 3), '-', RIGHT(f.chiffres, 4))
                END AS varchar(14)) AS telephone,
           f.courriel, f.conditions_paiement, f.created_at, f.modified_at,
           CAST(CASE WHEN RIGHT(f.k2, 3) = 'INC' THEN LEFT(f.k2, LEN(f.k2) - 3)
                     WHEN RIGHT(f.k2, 4) = 'LTEE' THEN LEFT(f.k2, LEN(f.k2) - 4)
                     ELSE f.k2 END AS varchar(200)) AS cle_nom
    FROM (
        SELECT CAST(FournisseurID AS int) AS fournisseur_id,
               CAST(NoFournisseur AS varchar(10)) AS no_fournisseur,
               CAST(TRIM(REPLACE(REPLACE(NomFournisseur, '   ', ' '), '  ', ' ')) AS varchar(200)) AS nom_fournisseur,
               CAST(Categorie AS varchar(30)) AS categorie,
               CAST(CodeSectionPrincipale AS varchar(2)) AS code_section,
               CAST(NULLIF(TRIM(NEQ), '') AS varchar(10)) AS neq,
               CAST(VilleID AS int) AS ville_id,
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Telephone, '(', ''), ')', ''), '-', ''), '.', ''), ' ', '') AS chiffres,
               CAST(LOWER(TRIM(Courriel)) AS varchar(150)) AS courriel,
               CAST(ConditionsPaiement AS int) AS conditions_paiement,
               CAST(CreatedAt AS datetime2(6)) AS created_at,
               CAST(ModifiedAt AS datetime2(6)) AS modified_at,
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(NomFournisseur), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Ç', 'C'), '.', ''), ',', ''), '-', ''), '''', ''), '—', ''), '&', ''), '(', ''), ')', ''), ' ', '') AS k2
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY FournisseurID ORDER BY ModifiedAt DESC) AS rn
              FROM bronze.achat_fournisseur) b
        WHERE rn = 1
    ) f;
END
GO

/* ------------------------------------------------------------------ PROJETS, BUDGETS, OC */
CREATE OR ALTER PROCEDURE stg.usp_charger_projet
AS
BEGIN
    DROP TABLE IF EXISTS stg.projet;
    CREATE TABLE stg.projet AS
    SELECT CAST(ProjetID AS int) AS projet_id,
           CAST(NoProjet AS varchar(12)) AS no_projet,
           CAST(TRIM(NomProjet) AS varchar(250)) AS nom_projet,
           CAST(ClientID AS int) AS client_id,
           CAST(DivisionID AS int) AS division_id,
           CAST(VilleID AS int) AS ville_id,
           CAST(ChargeProjetID AS int) AS charge_projet_id,
           CAST(TypeContrat AS varchar(20)) AS type_contrat,
           CAST(ValeurContrat AS decimal(14,2)) AS valeur_contrat,
           CAST(DateDebutPrevue AS date) AS date_debut_prevue,
           CAST(DateFinPrevue AS date) AS date_fin_prevue,
           CAST(DateDebutReelle AS date) AS date_debut_reelle,
           -- une date de fin antérieure au début est une erreur de saisie : on la neutralise et on la signale
           CAST(CASE WHEN DateFinReelle < DateDebutReelle THEN NULL ELSE DateFinReelle END AS date) AS date_fin_reelle,
           CAST(CASE WHEN DateFinReelle < DateDebutReelle THEN 1 ELSE 0 END AS bit) AS est_date_fin_invalide,
           -- statut saisi à la main (« en cours », « TERMINÉ ») → valeur canonique
           CAST(CASE REPLACE(UPPER(TRIM(Statut)), 'É', 'E')
                    WHEN 'SOUMISSION' THEN 'Soumission'
                    WHEN 'EN COURS'   THEN 'En cours'
                    WHEN 'TERMINE'    THEN 'Terminé'
                    WHEN 'ANNULE'     THEN 'Annulé'
                    WHEN 'SUSPENDU'   THEN 'Suspendu'
                    ELSE 'Inconnu' END AS varchar(20)) AS statut,
           CAST(PourcentageAvancement AS decimal(5,1)) AS pct_avancement_saisi,
           CAST(ModifiedAt AS datetime2(6)) AS modified_at
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY ProjetID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.projet_projet) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.budget;
    CREATE TABLE stg.budget AS
    SELECT CAST(BudgetID AS int) AS budget_id, CAST(ProjetID AS int) AS projet_id, CAST(CodeCoutID AS int) AS code_cout_id,
           CAST(Version AS varchar(20)) AS version, CAST(Montant AS decimal(14,2)) AS montant,
           CAST(CreatedAt AS datetime2(6)) AS created_at
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY BudgetID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.projet_budget) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.ordre_changement;
    CREATE TABLE stg.ordre_changement AS
    SELECT CAST(OrdreChangementID AS int) AS ordre_changement_id, CAST(ProjetID AS int) AS projet_id,
           CAST(NoOC AS varchar(25)) AS no_oc, CAST(DateOC AS date) AS date_oc,
           CAST(Description AS varchar(250)) AS description, CAST(Montant AS decimal(14,2)) AS montant,
           CAST(Statut AS varchar(15)) AS statut
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY OrdreChangementID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.projet_ordrechangement) d
    WHERE rn = 1;
END
GO

/* ------------------------------------------------------------------ FEUILLES DE TEMPS
   La table la plus volumineuse et la plus « sale ». Règles :
     1. dernière version (ModifiedAt) ; 2. IsDeleted = 0 ; 3. Statut <> Rejeté
     4. doublons exacts (double saisie) → on garde la 1re ligne
     5. heures < 0 ou > 16, date absurde → table de rejet avec la raison  */
CREATE OR ALTER PROCEDURE stg.usp_charger_feuille_temps
AS
BEGIN
    DROP TABLE IF EXISTS stg.feuille_temps_tmp;
    CREATE TABLE stg.feuille_temps_tmp AS
    SELECT CAST(FeuilleTempsID AS bigint) AS feuille_temps_id,
           CAST(EmployeID AS int) AS employe_id,
           CAST(DateTravail AS date) AS date_travail,
           CAST(ProjetID AS int) AS projet_id,
           CAST(CodeCoutID AS int) AS code_cout_id,
           CAST(HeuresReg AS decimal(5,2)) AS heures_reg,
           CAST(HeuresSupp AS decimal(5,2)) AS heures_supp,
           CAST(Statut AS varchar(15)) AS statut,
           CAST(ModifiedAt AS datetime2(6)) AS modified_at,
           ROW_NUMBER() OVER (PARTITION BY EmployeID, DateTravail, ProjetID, CodeCoutID, HeuresReg, HeuresSupp
                              ORDER BY FeuilleTempsID) AS no_occurrence
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY FeuilleTempsID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.paie_feuilletemps) d
    WHERE rn = 1 AND IsDeleted = 0 AND Statut <> 'Rejeté';

    DROP TABLE IF EXISTS stg.rejet_feuille_temps;
    CREATE TABLE stg.rejet_feuille_temps AS
    SELECT feuille_temps_id, employe_id, date_travail, projet_id, heures_reg, heures_supp,
           CAST(CASE WHEN no_occurrence > 1 THEN 'Doublon exact'
                     WHEN heures_reg < 0 OR heures_supp < 0 THEN 'Heures négatives'
                     WHEN heures_reg + heures_supp > 16 THEN 'Plus de 16 h dans une journée'
                     WHEN heures_reg + heures_supp = 0 THEN 'Aucune heure'
                     WHEN date_travail > DATEADD(year, 1, CAST(SYSDATETIME() AS date)) OR date_travail < '2018-01-01' THEN 'Date de travail invalide'
                END AS varchar(60)) AS raison_rejet,
           CAST(SYSDATETIME() AS datetime2(6)) AS rejete_le   -- Fabric : précision maximale 6
    FROM stg.feuille_temps_tmp
    WHERE no_occurrence > 1 OR heures_reg < 0 OR heures_supp < 0 OR heures_reg + heures_supp > 16
       OR heures_reg + heures_supp = 0
       OR date_travail > DATEADD(year, 1, CAST(SYSDATETIME() AS date)) OR date_travail < '2018-01-01';

    DROP TABLE IF EXISTS stg.feuille_temps;
    CREATE TABLE stg.feuille_temps AS
    SELECT t.feuille_temps_id, t.employe_id, t.date_travail, t.projet_id,
           t.code_cout_id, t.heures_reg, t.heures_supp, t.statut, t.modified_at
    FROM stg.feuille_temps_tmp t
    WHERE NOT EXISTS (SELECT 1 FROM stg.rejet_feuille_temps r WHERE r.feuille_temps_id = t.feuille_temps_id);

    DROP TABLE IF EXISTS stg.feuille_temps_tmp;

    /* date de référence = dernier jour travaillé présent dans les données */
    DELETE FROM audit.date_reference;
    INSERT INTO audit.date_reference (date_ref, calculee_le)
    SELECT MAX(date_travail), SYSDATETIME() FROM stg.feuille_temps;
END
GO

/* ------------------------------------------------------------------ ACHATS
   Une facture saisie deux fois (même fournisseur, même numéro, même
   montant) est marquée est_doublon = 1 : la 2e ne doit pas compter.       */
CREATE OR ALTER PROCEDURE stg.usp_charger_achat
AS
BEGIN
    DROP TABLE IF EXISTS stg.bon_commande;
    CREATE TABLE stg.bon_commande AS
    SELECT CAST(BonCommandeID AS int) AS bon_commande_id, CAST(NoBC AS varchar(12)) AS no_bc, CAST(ProjetID AS int) AS projet_id,
           CAST(FournisseurID AS int) AS fournisseur_id, CAST(DateBC AS date) AS date_bc, CAST(AcheteurID AS int) AS acheteur_id,
           CAST(Statut AS varchar(15)) AS statut, CAST(MontantTotal AS decimal(14,2)) AS montant_total
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY BonCommandeID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.achat_boncommande) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.facture_fournisseur;
    CREATE TABLE stg.facture_fournisseur AS
    SELECT f.*,
           CAST(CASE WHEN ROW_NUMBER() OVER (PARTITION BY f.fournisseur_id, f.no_facture_fourn, f.montant_ttc
                                             ORDER BY f.created_at, f.facture_fourn_id) > 1 THEN 1 ELSE 0 END AS bit) AS est_doublon
    FROM (
        SELECT CAST(FactureFournID AS int) AS facture_fourn_id, CAST(TRIM(NoFactureFourn) AS varchar(30)) AS no_facture_fourn,
               CAST(FournisseurID AS int) AS fournisseur_id, CAST(BonCommandeID AS int) AS bon_commande_id,
               CAST(DateFacture AS date) AS date_facture, CAST(DateEcheance AS date) AS date_echeance,
               CAST(DatePaiement AS date) AS date_paiement, CAST(MontantHT AS decimal(14,2)) AS montant_ht,
               CAST(TPS AS decimal(14,2)) AS tps, CAST(TVQ AS decimal(14,2)) AS tvq, CAST(MontantTTC AS decimal(14,2)) AS montant_ttc,
               CAST(Statut AS varchar(15)) AS statut, CAST(CreatedAt AS datetime2(6)) AS created_at
        FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY FactureFournID ORDER BY ModifiedAt DESC) AS rn
              FROM bronze.achat_facturefournisseur) d
        WHERE rn = 1
    ) f;

    DROP TABLE IF EXISTS stg.facture_fournisseur_ligne;
    CREATE TABLE stg.facture_fournisseur_ligne AS
    SELECT CAST(l.LigneID AS bigint) AS ligne_id, CAST(l.FactureFournID AS int) AS facture_fourn_id, CAST(l.NoLigne AS int) AS no_ligne,
           CAST(l.ProjetID AS int) AS projet_id,
           CAST(ISNULL(l.CodeCoutID, -1) AS int) AS code_cout_id,          -- -1 = « Non classé »
           CAST(l.Description AS varchar(250)) AS description, CAST(l.Quantite AS decimal(12,2)) AS quantite,
           CAST(l.Unite AS varchar(15)) AS unite, CAST(l.PrixUnitaire AS decimal(14,4)) AS prix_unitaire,
           CAST(l.MontantLigne AS decimal(14,2)) AS montant_ligne
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY LigneID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.achat_facturefournisseurligne) l
    WHERE l.rn = 1;
END
GO

/* ------------------------------------------------------------------ VENTES */
CREATE OR ALTER PROCEDURE stg.usp_charger_vente
AS
BEGIN
    DROP TABLE IF EXISTS stg.facture_client;
    CREATE TABLE stg.facture_client AS
    SELECT CAST(FactureClientID AS int) AS facture_client_id, CAST(NoFacture AS varchar(12)) AS no_facture,
           CAST(ProjetID AS int) AS projet_id, CAST(ClientID AS int) AS client_id, CAST(TypeFacture AS varchar(30)) AS type_facture,
           CAST(NoDecompte AS int) AS no_decompte, CAST(DateFacture AS date) AS date_facture, CAST(DateEcheance AS date) AS date_echeance,
           CAST(MontantHT AS decimal(14,2)) AS montant_ht, CAST(Retenue AS decimal(14,2)) AS retenue,
           CAST(MontantNet AS decimal(14,2)) AS montant_net, CAST(TPS AS decimal(14,2)) AS tps, CAST(TVQ AS decimal(14,2)) AS tvq,
           CAST(MontantTTC AS decimal(14,2)) AS montant_ttc, CAST(Statut AS varchar(25)) AS statut
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY FactureClientID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.vente_factureclient) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.encaissement;
    CREATE TABLE stg.encaissement AS
    SELECT CAST(EncaissementID AS int) AS encaissement_id, CAST(FactureClientID AS int) AS facture_client_id,
           CAST(DateEncaissement AS date) AS date_encaissement, CAST(Montant AS decimal(14,2)) AS montant,
           CAST(ModePaiement AS varchar(15)) AS mode_paiement
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY EncaissementID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.vente_encaissement) d
    WHERE rn = 1;
END
GO

/* ------------------------------------------------------------------ ÉQUIPEMENTS */
CREATE OR ALTER PROCEDURE stg.usp_charger_equipement
AS
BEGIN
    DROP TABLE IF EXISTS stg.equipement;
    CREATE TABLE stg.equipement AS
    SELECT CAST(EquipementID AS int) AS equipement_id, CAST(NoUnite AS varchar(10)) AS no_unite,
           CAST(Description AS varchar(150)) AS description, CAST(Categorie AS varchar(40)) AS categorie,
           CAST(Marque AS varchar(40)) AS marque, CAST(Modele AS varchar(40)) AS modele, CAST(Annee AS int) AS annee,
           CAST(DateAcquisition AS date) AS date_acquisition, CAST(DateDisposition AS date) AS date_disposition,
           CAST(TauxHoraireInterne AS decimal(8,2)) AS taux_horaire_interne, CAST(Statut AS varchar(15)) AS statut
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY EquipementID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.equip_equipement) d
    WHERE rn = 1;

    DROP TABLE IF EXISTS stg.utilisation_equipement;
    CREATE TABLE stg.utilisation_equipement AS
    SELECT CAST(UtilisationID AS bigint) AS utilisation_id, CAST(EquipementID AS int) AS equipement_id,
           CAST(ProjetID AS int) AS projet_id, CAST(DateUtilisation AS date) AS date_utilisation,
           CAST(Heures AS decimal(5,2)) AS heures, CAST(OperateurID AS int) AS operateur_id
    FROM (SELECT *, ROW_NUMBER() OVER (PARTITION BY UtilisationID ORDER BY ModifiedAt DESC) AS rn
          FROM bronze.equip_utilisationequipement) d
    WHERE rn = 1;
END
GO

/* ------------------------------------------------------------------ SOURCES EXTERNES (Dataflow Gen2)
   Le Dataflow a déjà typé les colonnes et renommé en snake_case.            */
CREATE OR ALTER PROCEDURE stg.usp_charger_externes
AS
BEGIN
    DROP TABLE IF EXISTS stg.crm_compagnie;
    CREATE TABLE stg.crm_compagnie AS
    SELECT c.crm_id, c.nom_crm, c.neq, c.industrie, c.responsable_compte, c.cycle_vie, c.ville,
           c.score_satisfaction, c.date_derniere_activite, c.date_creation_crm,
           CAST(CASE WHEN RIGHT(c.k2, 3) = 'INC' THEN LEFT(c.k2, LEN(c.k2) - 3)
                     WHEN RIGHT(c.k2, 4) = 'LTEE' THEN LEFT(c.k2, LEN(c.k2) - 4)
                     ELSE c.k2 END AS varchar(200)) AS cle_nom
    FROM (
        SELECT CAST(record_id AS bigint) AS crm_id,
               CAST(TRIM(company_name) AS varchar(200)) AS nom_crm,
               CAST(NULLIF(TRIM(CAST(neq AS varchar(20))), '') AS varchar(10)) AS neq,
               CAST(industry AS varchar(60)) AS industrie,
               CAST(company_owner AS varchar(100)) AS responsable_compte,
               CAST(lifecycle_stage AS varchar(30)) AS cycle_vie,
               CAST(city AS varchar(100)) AS ville,
               CAST(satisfaction AS int) AS score_satisfaction,
               CAST(last_activity_date AS date) AS date_derniere_activite,
               CAST(create_date AS date) AS date_creation_crm,
               REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(CONCAT(' ', REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(UPPER(company_name), 'À', 'A'), 'Â', 'A'), 'Ä', 'A'), 'É', 'E'), 'È', 'E'), 'Ê', 'E'), 'Ë', 'E'), 'Î', 'I'), 'Ï', 'I'), 'Ô', 'O'), 'Ö', 'O'), 'Ù', 'U'), 'Û', 'U'), 'Ü', 'U'), 'Ç', 'C')), ' V. DE ', ' VILLE DE '), ' MUN. ', ' MUNICIPALITE DE '), ' CSS ', ' CENTRE DE SERVICES SCOLAIRE '), ' MTQ ', ' MINISTERE DES TRANSPORTS '), '.', ''), ',', ''), '-', ''), '''', ''), '—', ''), '&', ''), '(', ''), ')', ''), ' ', '') AS k2
        FROM bronze.ext_crm_companies
    ) c;

    DROP TABLE IF EXISTS stg.objectif_ca;
    CREATE TABLE stg.objectif_ca AS
    SELECT CAST(TRIM(code_division) AS varchar(5)) AS code_division,
           CAST(DATEFROMPARTS(YEAR(mois), MONTH(mois), 1) AS date) AS mois,
           CAST(objectif_ca AS decimal(14,2)) AS objectif_ca
    FROM bronze.ext_objectifs_ca
    WHERE objectif_ca IS NOT NULL;

    DROP TABLE IF EXISTS stg.objectif_marge;
    CREATE TABLE stg.objectif_marge AS
    SELECT CAST(TRIM(code_division) AS varchar(5)) AS code_division,
           CAST(TRIM(exercice) AS varchar(15)) AS exercice,
           CAST(marge_cible AS decimal(6,4)) AS marge_cible
    FROM bronze.ext_objectifs_marge;
END
GO

/* ------------------------------------------------------------------ PROCÉDURE MAÎTRE DE LA COUCHE */
CREATE OR ALTER PROCEDURE stg.usp_charger_tout @execution_id varchar(40)
AS
BEGIN
    DECLARE @t datetime2(6);
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_reference;     EXEC audit.usp_journaliser @execution_id, 'stg.reference', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_employe;       EXEC audit.usp_journaliser @execution_id, 'stg.employe', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_client;        EXEC audit.usp_journaliser @execution_id, 'stg.client', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_fournisseur;   EXEC audit.usp_journaliser @execution_id, 'stg.fournisseur', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_projet;        EXEC audit.usp_journaliser @execution_id, 'stg.projet', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_feuille_temps; EXEC audit.usp_journaliser @execution_id, 'stg.feuille_temps', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_achat;         EXEC audit.usp_journaliser @execution_id, 'stg.achat', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_vente;         EXEC audit.usp_journaliser @execution_id, 'stg.vente', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_equipement;    EXEC audit.usp_journaliser @execution_id, 'stg.equipement', @t;
    SET @t = SYSDATETIME(); EXEC stg.usp_charger_externes;      EXEC audit.usp_journaliser @execution_id, 'stg.externes', @t;
END
GO
