/* =====================================================================
   Script 15 : couche GOLD — tables PRÉ-CALCULÉES pour les visuels
   ---------------------------------------------------------------------
   Principe : tout le calcul « lourd » est fait ici, en SQL. Le modèle
   sémantique Direct Lake ne fait que des SOMMES et des DIVISIONS.
     • cumuls, YTD, même mois l'an passé  → fenêtres SQL (SUM OVER, jointure N-1)
     • âge des comptes, retards, santé    → calculés à la date de référence
/* ================================================================== DDL */
IF OBJECT_ID('gold.projet_synthese') IS NULL
CREATE TABLE gold.projet_synthese (
    projet_id int NOT NULL, division_id int NOT NULL, client_maitre_id int NOT NULL, statut varchar(20) NOT NULL,
    valeur_contrat decimal(16,2) NOT NULL, oc_approuves decimal(16,2) NOT NULL, valeur_revisee decimal(16,2) NOT NULL,
    budget_original decimal(16,2) NOT NULL, budget_revise decimal(16,2) NOT NULL, marge_prevue decimal(16,2) NOT NULL,
    cout_main_oeuvre decimal(16,2) NOT NULL, cout_fournisseurs decimal(16,2) NOT NULL, cout_equipement decimal(16,2) NOT NULL,
    cout_total decimal(16,2) NOT NULL, heures_total decimal(12,2) NOT NULL, nb_employes int NOT NULL,
    pct_avancement_cout decimal(9,4) NOT NULL, pct_avancement_saisi decimal(9,4) NULL,
    valeur_acquise decimal(16,2) NOT NULL, facture_ht_cumul decimal(16,2) NOT NULL, retenues_detenues decimal(16,2) NOT NULL,
    encaisse_cumul decimal(16,2) NOT NULL, solde_a_recevoir decimal(16,2) NOT NULL,
    sur_sous_facturation decimal(16,2) NOT NULL,   -- > 0 : surfacturé (facturé plus que le travail fait)
    cout_projete_fin decimal(16,2) NOT NULL, marge_projetee decimal(16,2) NOT NULL, ecart_budget_projete decimal(16,2) NOT NULL,
    ecart_echeancier_jours int NULL, sante varchar(10) NOT NULL, sante_ordre int NOT NULL,
    date_derniere_activite date NULL, date_ref date NOT NULL,
    prevision_a_valider bit NOT NULL);   -- 1 = % d'avancement saisi absent ou en retard sur les coûts : à confirmer par le chargé de projet
IF OBJECT_ID('gold.projet_mensuel') IS NULL
CREATE TABLE gold.projet_mensuel (
    projet_id int NOT NULL, mois date NOT NULL, cout_main_oeuvre decimal(16,2) NOT NULL, cout_fournisseurs decimal(16,2) NOT NULL,
    cout_equipement decimal(16,2) NOT NULL, cout_mois decimal(16,2) NOT NULL, cout_cumul decimal(16,2) NOT NULL,
    facture_ht_mois decimal(16,2) NOT NULL, facture_ht_cumul decimal(16,2) NOT NULL, budget_revise decimal(16,2) NOT NULL,
    valeur_revisee decimal(16,2) NOT NULL, no_mois_projet int NOT NULL);
IF OBJECT_ID('gold.projet_code_cout') IS NULL
CREATE TABLE gold.projet_code_cout (
    projet_id int NOT NULL, code_cout_id int NOT NULL, budget_original decimal(16,2) NOT NULL, budget_revise decimal(16,2) NOT NULL,
    cout_reel decimal(16,2) NOT NULL, ecart decimal(16,2) NOT NULL, est_depassement bit NOT NULL);
IF OBJECT_ID('gold.division_mensuel') IS NULL
CREATE TABLE gold.division_mensuel (
    division_id int NOT NULL, mois date NOT NULL, exercice varchar(12) NOT NULL,
    revenus decimal(16,2) NOT NULL, couts decimal(16,2) NOT NULL, marge_brute decimal(16,2) NOT NULL,
    objectif_ca decimal(16,2) NOT NULL, objectif_marge decimal(16,2) NOT NULL,
    revenus_cumul_exercice decimal(16,2) NOT NULL, objectif_cumul_exercice decimal(16,2) NOT NULL,
    marge_cumul_exercice decimal(16,2) NOT NULL,
    revenus_meme_mois_an_passe decimal(16,2) NULL, revenus_cumul_exercice_an_passe decimal(16,2) NULL,
    heures_projets decimal(14,2) NOT NULL, nb_projets_actifs int NOT NULL, est_mois_futur bit NOT NULL,
    est_mois_complet bit NULL);   -- 1 = mois terminé à la date de référence (le mois en cours est incomplet : facturation en fin de mois)
IF OBJECT_ID('gold.main_oeuvre_hebdo') IS NULL
CREATE TABLE gold.main_oeuvre_hebdo (
    debut_semaine date NOT NULL, division_id int NOT NULL, code_metier varchar(5) NOT NULL, nom_metier varchar(100) NOT NULL,
    categorie varchar(20) NOT NULL, heures_reg decimal(14,2) NOT NULL, heures_supp decimal(14,2) NOT NULL,
    heures_total decimal(14,2) NOT NULL, heures_imputables decimal(14,2) NOT NULL, cout_main_oeuvre decimal(16,2) NOT NULL,
    nb_employes int NOT NULL);
IF OBJECT_ID('gold.employe_mensuel') IS NULL
CREATE TABLE gold.employe_mensuel (
    employe_id int NOT NULL, mois date NOT NULL, division_id int NOT NULL, heures_total decimal(10,2) NOT NULL,
    heures_imputables decimal(10,2) NOT NULL, heures_supp decimal(10,2) NOT NULL, cout_main_oeuvre decimal(14,2) NOT NULL,
    nb_jours_travailles int NOT NULL, nb_projets int NOT NULL);
IF OBJECT_ID('gold.comptes_recevables') IS NULL
CREATE TABLE gold.comptes_recevables (
    facture_client_id int NOT NULL, no_facture varchar(12) NOT NULL, client_maitre_id int NOT NULL, projet_id int NOT NULL,
    division_id int NOT NULL, date_facture date NOT NULL, date_echeance date NOT NULL, montant_ttc decimal(16,2) NOT NULL,
    solde decimal(16,2) NOT NULL, jours_depuis_facture int NOT NULL, jours_retard int NOT NULL,
    tranche_age varchar(20) NOT NULL, tranche_ordre int NOT NULL, date_ref date NOT NULL);
IF OBJECT_ID('gold.comptes_payables') IS NULL
CREATE TABLE gold.comptes_payables (
    facture_fourn_id int NOT NULL, fournisseur_maitre_id int NOT NULL, date_facture date NOT NULL, date_echeance date NOT NULL,
    montant_ttc decimal(16,2) NOT NULL, statut varchar(15) NOT NULL, jours_retard int NOT NULL,
    tranche_age varchar(20) NOT NULL, tranche_ordre int NOT NULL, date_ref date NOT NULL);
IF OBJECT_ID('gold.fournisseur_annuel') IS NULL
CREATE TABLE gold.fournisseur_annuel (
    fournisseur_maitre_id int NOT NULL, annee int NOT NULL, montant_ht decimal(16,2) NOT NULL, nb_factures int NOT NULL,
    nb_projets int NOT NULL, rang int NOT NULL, part_pct decimal(9,6) NOT NULL, part_cumul_pct decimal(9,6) NOT NULL,
    classe_abc char(1) NOT NULL);
IF OBJECT_ID('gold.equipement_mensuel') IS NULL
CREATE TABLE gold.equipement_mensuel (
    equipement_id int NOT NULL, mois date NOT NULL, heures decimal(10,2) NOT NULL, jours_utilises int NOT NULL,
    jours_ouvrables int NOT NULL, heures_disponibles decimal(10,2) NOT NULL, revenu_interne decimal(14,2) NOT NULL);
IF OBJECT_ID('gold.client_synthese') IS NULL
CREATE TABLE gold.client_synthese (
    client_maitre_id int NOT NULL, nb_projets int NOT NULL, nb_projets_actifs int NOT NULL, revenus_total decimal(16,2) NOT NULL,
    revenus_12_mois decimal(16,2) NOT NULL, valeur_projets_termines decimal(16,2) NOT NULL, cout_projets_termines decimal(16,2) NOT NULL,
    montant_paye decimal(16,2) NOT NULL, jours_paiement_ponderes decimal(20,2) NOT NULL,   -- Σ(montant × jours) : DSO pondéré = ÷ montant_paye
    solde_ouvert decimal(16,2) NOT NULL, premiere_facture date NULL, derniere_facture date NULL);
IF OBJECT_ID('gold.kpi_mensuel') IS NULL
CREATE TABLE gold.kpi_mensuel (
    mois date NOT NULL, revenus decimal(16,2) NOT NULL, couts decimal(16,2) NOT NULL, marge_brute decimal(16,2) NOT NULL,
    revenus_12_mois_glissants decimal(16,2) NOT NULL, marge_12_mois_glissants decimal(16,2) NOT NULL,
    carnet_commandes decimal(16,2) NOT NULL, comptes_recevables_fin_mois decimal(16,2) NOT NULL,
    facturation_ttc_3_mois decimal(16,2) NOT NULL,   -- dénominateur du DSO
    effectif_actif int NOT NULL, heures_total decimal(14,2) NOT NULL, heures_supp decimal(14,2) NOT NULL,
    nb_projets_actifs int NOT NULL, est_mois_complet bit NULL);
GO

/* ================================================================== CHARGEMENT */
CREATE OR ALTER PROCEDURE gold.usp_charger_projets
AS
BEGIN
    DECLARE @date_ref date = (SELECT MAX(date_ref) FROM audit.date_reference);

    /* ---------- 1. Synthèse par projet (1 ligne / projet) */
    TRUNCATE TABLE gold.projet_synthese;
    INSERT INTO gold.projet_synthese (projet_id, division_id, client_maitre_id, statut, valeur_contrat, oc_approuves, valeur_revisee,
        budget_original, budget_revise, marge_prevue, cout_main_oeuvre, cout_fournisseurs, cout_equipement, cout_total, heures_total,
        nb_employes, pct_avancement_cout, pct_avancement_saisi, valeur_acquise, facture_ht_cumul, retenues_detenues, encaisse_cumul,
        solde_a_recevoir, sur_sous_facturation, cout_projete_fin, marge_projetee, ecart_budget_projete, ecart_echeancier_jours,
        sante, sante_ordre, date_derniere_activite, date_ref, prevision_a_valider)
    SELECT z.projet_id, z.division_id, z.client_maitre_id, z.statut, z.valeur_contrat, z.oc_approuves, z.valeur_revisee,
           z.budget_original, z.budget_revise, z.valeur_contrat - z.budget_original,
           z.cout_mo, z.cout_fourn, z.cout_eq, z.cout_total, z.heures, z.nb_employes,
           z.pct_cout, z.pct_saisi, z.valeur_acquise, z.facture_ht, z.retenues, z.encaisse, z.solde,
           z.facture_ht - z.valeur_acquise,
           z.eac, z.valeur_revisee - z.eac, z.budget_revise - z.eac, z.ecart_jours,
           CASE WHEN z.statut NOT IN ('En cours', 'Suspendu') THEN 'N/A'
                WHEN z.valeur_revisee > 0 AND (z.valeur_revisee - z.eac) / z.valeur_revisee < 0 THEN 'Rouge'
                WHEN z.ecart_jours > 60 THEN 'Rouge'
                WHEN z.valeur_revisee > 0 AND z.valeur_contrat > 0
                     AND (z.valeur_revisee - z.eac) / z.valeur_revisee < (z.valeur_contrat - z.budget_original) / z.valeur_contrat - 0.03 THEN 'Jaune'
                WHEN z.ecart_jours > 0 THEN 'Jaune'
                ELSE 'Vert' END,
           CASE WHEN z.statut NOT IN ('En cours', 'Suspendu') THEN 4
                WHEN z.valeur_revisee > 0 AND (z.valeur_revisee - z.eac) / z.valeur_revisee < 0 THEN 1
                WHEN z.ecart_jours > 60 THEN 1
                WHEN z.valeur_revisee > 0 AND z.valeur_contrat > 0
                     AND (z.valeur_revisee - z.eac) / z.valeur_revisee < (z.valeur_contrat - z.budget_original) / z.valeur_contrat - 0.03 THEN 2
                WHEN z.ecart_jours > 0 THEN 2
                ELSE 3 END,
           z.derniere_activite, @date_ref, z.a_valider
    FROM (
        SELECT y.*,
               y.valeur_revisee * y.pct_cout AS valeur_acquise,
               -- Coût projeté à la fin (EAC) : coût réel ÷ % d'avancement physique saisi par le chargé de projet.
               -- Règle révisée : le % saisi (mis à jour en fin de mois) n'est utilisé que s'il n'a pas plus de
               -- 10 points de retard sur l'avancement mesuré par les coûts. Sinon il est jugé périmé, on prend
               -- le plus grand entre le budget révisé et le coût réel, et la prévision est marquée « à valider ».
               CASE WHEN y.statut IN ('Terminé', 'Annulé') THEN y.cout_total
                    WHEN y.pct_saisi BETWEEN 0.10 AND 0.999 AND y.pct_cout - y.pct_saisi <= 0.10
                         AND y.cout_total / y.pct_saisi > y.cout_total THEN y.cout_total / y.pct_saisi
                    WHEN y.cout_total > y.budget_revise THEN y.cout_total
                    ELSE y.budget_revise END AS eac,
               CAST(CASE WHEN y.statut IN ('En cours', 'Suspendu')
                          AND (y.pct_saisi IS NULL OR y.pct_saisi NOT BETWEEN 0.10 AND 0.999 OR y.pct_cout - y.pct_saisi > 0.10)
                         THEN 1 ELSE 0 END AS bit) AS a_valider
        FROM (
            SELECT p.projet_id, p.division_id, p.client_maitre_id, p.statut, p.valeur_contrat, p.oc_approuves, p.valeur_revisee,
                   ISNULL(b.bo, 0) AS budget_original, ISNULL(b.br, 0) AS budget_revise,
                   ISNULL(c.mo, 0) AS cout_mo, ISNULL(c.fourn, 0) AS cout_fourn, ISNULL(c.eq, 0) AS cout_eq, ISNULL(c.total, 0) AS cout_total,
                   ISNULL(h.heures, 0) AS heures, ISNULL(h.nb_employes, 0) AS nb_employes,
                   CAST(CASE WHEN p.statut = 'Terminé' THEN 1
                             WHEN ISNULL(b.br, 0) = 0 THEN 0
                             WHEN ISNULL(c.total, 0) / b.br > 1 THEN 1
                             ELSE ISNULL(c.total, 0) / b.br END AS decimal(9,4)) AS pct_cout,
                   CAST(p.pct_avancement_saisi / 100.0 AS decimal(9,4)) AS pct_saisi,
                   ISNULL(f.facture_ht, 0) AS facture_ht, ISNULL(f.retenues, 0) AS retenues,
                   ISNULL(f.encaisse, 0) AS encaisse, ISNULL(f.solde, 0) AS solde,
                   CASE WHEN p.statut = 'Terminé' THEN DATEDIFF(day, p.date_fin_prevue, p.date_fin_reelle)
                        WHEN p.statut IN ('En cours', 'Suspendu') AND @date_ref > p.date_fin_prevue THEN DATEDIFF(day, p.date_fin_prevue, @date_ref)
                        WHEN p.statut IN ('En cours', 'Suspendu') THEN 0 END AS ecart_jours,
                   c.derniere_activite
            FROM dw.dim_projet p
            LEFT JOIN (SELECT projet_id, SUM(budget_original) AS bo, SUM(budget_revise) AS br FROM dw.fait_budget GROUP BY projet_id) b
                   ON b.projet_id = p.projet_id
            LEFT JOIN (SELECT projet_id,
                              SUM(CASE WHEN source_cout = 'Main-d''œuvre' THEN montant ELSE 0 END) AS mo,
                              SUM(CASE WHEN source_cout = 'Fournisseurs' THEN montant ELSE 0 END) AS fourn,
                              SUM(CASE WHEN source_cout = 'Équipement interne' THEN montant ELSE 0 END) AS eq,
                              SUM(montant) AS total, MAX([date]) AS derniere_activite
                       FROM dw.fait_cout_projet GROUP BY projet_id) c ON c.projet_id = p.projet_id
            LEFT JOIN (SELECT projet_id, SUM(heures_total) AS heures, COUNT(DISTINCT employe_id) AS nb_employes
                       FROM dw.fait_heures WHERE projet_id <> -1 GROUP BY projet_id) h ON h.projet_id = p.projet_id
            LEFT JOIN (SELECT projet_id, SUM(montant_ht) AS facture_ht, SUM(retenue) AS retenues,
                              SUM(montant_encaisse) AS encaisse, SUM(solde) AS solde
                       FROM dw.fait_facture_client GROUP BY projet_id) f ON f.projet_id = p.projet_id
            WHERE p.projet_id <> -1
        ) y
    ) z;

    /* ---------- 2. Courbe en S : projet × mois avec cumuls (fenêtre SUM OVER) */
    TRUNCATE TABLE gold.projet_mensuel;
    INSERT INTO gold.projet_mensuel (projet_id, mois, cout_main_oeuvre, cout_fournisseurs, cout_equipement, cout_mois, cout_cumul,
                                     facture_ht_mois, facture_ht_cumul, budget_revise, valeur_revisee, no_mois_projet)
    SELECT m.projet_id, m.mois, m.mo, m.fourn, m.eq, m.mo + m.fourn + m.eq,
           SUM(m.mo + m.fourn + m.eq) OVER (PARTITION BY m.projet_id ORDER BY m.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
           m.facture,
           SUM(m.facture) OVER (PARTITION BY m.projet_id ORDER BY m.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
           ps.budget_revise, ps.valeur_revisee,
           ROW_NUMBER() OVER (PARTITION BY m.projet_id ORDER BY m.mois)
    FROM (
        SELECT projet_id, mois, SUM(mo) AS mo, SUM(fourn) AS fourn, SUM(eq) AS eq, SUM(facture) AS facture
        FROM (
            SELECT projet_id, DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois,
                   CASE WHEN source_cout = 'Main-d''œuvre' THEN montant ELSE 0 END AS mo,
                   CASE WHEN source_cout = 'Fournisseurs' THEN montant ELSE 0 END AS fourn,
                   CASE WHEN source_cout = 'Équipement interne' THEN montant ELSE 0 END AS eq,
                   0 AS facture
            FROM dw.fait_cout_projet
            UNION ALL
            SELECT projet_id, DATEFROMPARTS(YEAR([date]), MONTH([date]), 1), 0, 0, 0, montant_ht
            FROM dw.fait_facture_client
        ) u
        GROUP BY projet_id, mois
    ) m
    JOIN gold.projet_synthese ps ON ps.projet_id = m.projet_id;

    /* ---------- 3. Budget vs réel par code de coût (FULL OUTER JOIN : budget sans coût et coût sans budget) */
    TRUNCATE TABLE gold.projet_code_cout;
    INSERT INTO gold.projet_code_cout (projet_id, code_cout_id, budget_original, budget_revise, cout_reel, ecart, est_depassement)
    SELECT COALESCE(b.projet_id, c.projet_id), COALESCE(b.code_cout_id, c.code_cout_id),
           ISNULL(b.budget_original, 0), ISNULL(b.budget_revise, 0), ISNULL(c.cout, 0),
           ISNULL(b.budget_revise, 0) - ISNULL(c.cout, 0),
           CASE WHEN ISNULL(c.cout, 0) > ISNULL(b.budget_revise, 0) THEN 1 ELSE 0 END
    FROM dw.fait_budget b
    FULL OUTER JOIN (SELECT projet_id, code_cout_id, SUM(montant) AS cout FROM dw.fait_cout_projet GROUP BY projet_id, code_cout_id) c
         ON c.projet_id = b.projet_id AND c.code_cout_id = b.code_cout_id;
END
GO

CREATE OR ALTER PROCEDURE gold.usp_charger_divisions
AS
BEGIN
    DECLARE @date_ref date = (SELECT MAX(date_ref) FROM audit.date_reference);
    DECLARE @fin_exercice date = (SELECT MAX([date]) FROM dw.dim_date
                                  WHERE exercice = (SELECT exercice FROM dw.dim_date WHERE [date] = @date_ref));

    /* ---------- 4. Division × mois : réel, objectifs, cumul d'exercice (YTD) et an passé — en SQL, pas en DAX */
    TRUNCATE TABLE gold.division_mensuel;
    INSERT INTO gold.division_mensuel (division_id, mois, exercice, revenus, couts, marge_brute, objectif_ca, objectif_marge,
        revenus_cumul_exercice, objectif_cumul_exercice, marge_cumul_exercice, revenus_meme_mois_an_passe,
        revenus_cumul_exercice_an_passe, heures_projets, nb_projets_actifs, est_mois_futur, est_mois_complet)
    SELECT x.division_id, x.mois, x.exercice, x.revenus, x.couts, x.revenus - x.couts, x.objectif_ca, x.objectif_ca * x.marge_cible,
           x.revenus_cumul, x.objectif_cumul, x.marge_cumul,
           -- la grille division × mois est COMPLÈTE (aucun mois manquant) : LAG(…, 12) = même mois l'an passé
           LAG(x.revenus, 12) OVER (PARTITION BY x.division_id ORDER BY x.mois),
           LAG(x.revenus_cumul, 12) OVER (PARTITION BY x.division_id ORDER BY x.mois),
           x.heures, x.nb_projets, CASE WHEN x.mois > @date_ref THEN 1 ELSE 0 END,
           CASE WHEN EOMONTH(x.mois) < @date_ref THEN 1 ELSE 0 END
    FROM (
        SELECT b.*,
               SUM(b.revenus) OVER (PARTITION BY b.division_id, b.exercice ORDER BY b.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS revenus_cumul,
               SUM(b.objectif_ca) OVER (PARTITION BY b.division_id, b.exercice ORDER BY b.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS objectif_cumul,
               SUM(b.revenus - b.couts) OVER (PARTITION BY b.division_id, b.exercice ORDER BY b.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS marge_cumul
        FROM (
            SELECT g.division_id, g.mois, g.exercice,
                   ISNULL(r.revenus, 0) AS revenus, ISNULL(c.couts, 0) AS couts, ISNULL(o.objectif_ca, 0) AS objectif_ca,
                   ISNULL(om.marge_cible, 0) AS marge_cible, ISNULL(h.heures, 0) AS heures, ISNULL(c.nb_projets, 0) AS nb_projets
            FROM (SELECT dv.division_id, dd.[date] AS mois, dd.exercice
                  FROM dw.dim_division dv
                  CROSS JOIN dw.dim_date dd
                  WHERE dv.est_division_operationnelle = 1 AND dd.[date] = dd.debut_mois
                    AND dd.[date] BETWEEN '2018-01-01' AND @fin_exercice) g
            LEFT JOIN (SELECT p.division_id, DATEFROMPARTS(YEAR(f.[date]), MONTH(f.[date]), 1) AS mois, SUM(f.montant_ht) AS revenus
                       FROM dw.fait_facture_client f JOIN dw.dim_projet p ON p.projet_id = f.projet_id
                       GROUP BY p.division_id, DATEFROMPARTS(YEAR(f.[date]), MONTH(f.[date]), 1)) r
                   ON r.division_id = g.division_id AND r.mois = g.mois
            LEFT JOIN (SELECT p.division_id, DATEFROMPARTS(YEAR(c.[date]), MONTH(c.[date]), 1) AS mois,
                              SUM(c.montant) AS couts, COUNT(DISTINCT c.projet_id) AS nb_projets
                       FROM dw.fait_cout_projet c JOIN dw.dim_projet p ON p.projet_id = c.projet_id
                       GROUP BY p.division_id, DATEFROMPARTS(YEAR(c.[date]), MONTH(c.[date]), 1)) c
                   ON c.division_id = g.division_id AND c.mois = g.mois
            LEFT JOIN (SELECT p.division_id, DATEFROMPARTS(YEAR(h.[date]), MONTH(h.[date]), 1) AS mois, SUM(h.heures_total) AS heures
                       FROM dw.fait_heures h JOIN dw.dim_projet p ON p.projet_id = h.projet_id
                       WHERE h.projet_id <> -1
                       GROUP BY p.division_id, DATEFROMPARTS(YEAR(h.[date]), MONTH(h.[date]), 1)) h
                   ON h.division_id = g.division_id AND h.mois = g.mois
            LEFT JOIN dw.fait_objectif_ca o     ON o.division_id = g.division_id AND o.mois = g.mois
            LEFT JOIN dw.fait_objectif_marge om ON om.division_id = g.division_id AND om.exercice = g.exercice
        ) b
    ) x;
    -- on ne garde l'année 2018 que pour calculer « l'an passé » de 2019
    DELETE FROM gold.division_mensuel WHERE mois < '2019-01-01';

    /* ---------- 5. Main-d'œuvre par semaine, division et métier */
    TRUNCATE TABLE gold.main_oeuvre_hebdo;
    INSERT INTO gold.main_oeuvre_hebdo (debut_semaine, division_id, code_metier, nom_metier, categorie, heures_reg, heures_supp,
                                        heures_total, heures_imputables, cout_main_oeuvre, nb_employes)
    SELECT d.debut_semaine, h.division_employe_id, e.code_metier, e.nom_metier, e.categorie,
           SUM(h.heures_reg), SUM(h.heures_supp), SUM(h.heures_total),
           SUM(CASE WHEN h.est_imputable = 1 THEN h.heures_total ELSE 0 END), SUM(h.cout_mo), COUNT(DISTINCT h.employe_id)
    FROM dw.fait_heures h
    JOIN dw.dim_date d ON d.date_key = h.date_key
    JOIN dw.dim_employe_courant e ON e.employe_id = h.employe_id
    GROUP BY d.debut_semaine, h.division_employe_id, e.code_metier, e.nom_metier, e.categorie;

    /* ---------- 6. Employé × mois (taux d'utilisation = imputables ÷ total) */
    TRUNCATE TABLE gold.employe_mensuel;
    INSERT INTO gold.employe_mensuel (employe_id, mois, division_id, heures_total, heures_imputables, heures_supp, cout_main_oeuvre,
                                      nb_jours_travailles, nb_projets)
    SELECT h.employe_id, DATEFROMPARTS(YEAR(h.[date]), MONTH(h.[date]), 1), MAX(h.division_employe_id),
           SUM(h.heures_total), SUM(CASE WHEN h.est_imputable = 1 THEN h.heures_total ELSE 0 END), SUM(h.heures_supp), SUM(h.cout_mo),
           COUNT(DISTINCT h.[date]), COUNT(DISTINCT CASE WHEN h.projet_id <> -1 THEN h.projet_id END)
    FROM dw.fait_heures h
    GROUP BY h.employe_id, DATEFROMPARTS(YEAR(h.[date]), MONTH(h.[date]), 1);
END
GO

CREATE OR ALTER PROCEDURE gold.usp_charger_finances
AS
BEGIN
    DECLARE @date_ref date = (SELECT MAX(date_ref) FROM audit.date_reference);

    /* ---------- 7. Comptes recevables ouverts, âgés à la date de référence */
    TRUNCATE TABLE gold.comptes_recevables;
    INSERT INTO gold.comptes_recevables (facture_client_id, no_facture, client_maitre_id, projet_id, division_id, date_facture,
        date_echeance, montant_ttc, solde, jours_depuis_facture, jours_retard, tranche_age, tranche_ordre, date_ref)
    SELECT f.facture_client_id, f.no_facture, f.client_maitre_id, f.projet_id, p.division_id, f.[date], f.date_echeance,
           f.montant_ttc, f.solde, DATEDIFF(day, f.[date], @date_ref), t.jr,
           CASE WHEN t.jr <= 0 THEN 'Non échu' WHEN t.jr <= 30 THEN '1-30 jours' WHEN t.jr <= 60 THEN '31-60 jours'
                WHEN t.jr <= 90 THEN '61-90 jours' ELSE 'Plus de 90 jours' END,
           CASE WHEN t.jr <= 0 THEN 1 WHEN t.jr <= 30 THEN 2 WHEN t.jr <= 60 THEN 3 WHEN t.jr <= 90 THEN 4 ELSE 5 END,
           @date_ref
    FROM dw.fait_facture_client f
    JOIN dw.dim_projet p ON p.projet_id = f.projet_id
    JOIN (SELECT facture_client_id, DATEDIFF(day, date_echeance, @date_ref) AS jr FROM dw.fait_facture_client) t
         ON t.facture_client_id = f.facture_client_id
    WHERE f.solde > 0.01;

    /* ---------- 8. Comptes payables ouverts (hors doublons) */
    TRUNCATE TABLE gold.comptes_payables;
    INSERT INTO gold.comptes_payables (facture_fourn_id, fournisseur_maitre_id, date_facture, date_echeance, montant_ttc, statut,
                                       jours_retard, tranche_age, tranche_ordre, date_ref)
    SELECT f.facture_fourn_id, f.fournisseur_maitre_id, f.[date], f.date_echeance, f.montant_ttc, f.statut, t.jr,
           CASE WHEN t.jr <= 0 THEN 'Non échu' WHEN t.jr <= 30 THEN '1-30 jours' WHEN t.jr <= 60 THEN '31-60 jours'
                WHEN t.jr <= 90 THEN '61-90 jours' ELSE 'Plus de 90 jours' END,
           CASE WHEN t.jr <= 0 THEN 1 WHEN t.jr <= 30 THEN 2 WHEN t.jr <= 60 THEN 3 WHEN t.jr <= 90 THEN 4 ELSE 5 END,
           @date_ref
    FROM dw.fait_facture_fournisseur f
    JOIN (SELECT facture_fourn_id, DATEDIFF(day, date_echeance, @date_ref) AS jr FROM dw.fait_facture_fournisseur) t
         ON t.facture_fourn_id = f.facture_fourn_id
    WHERE f.statut IN ('À payer', 'En litige') AND f.est_doublon = 0;

    /* ---------- 9. Fournisseurs : classement annuel et analyse ABC (Pareto) */
    TRUNCATE TABLE gold.fournisseur_annuel;
    INSERT INTO gold.fournisseur_annuel (fournisseur_maitre_id, annee, montant_ht, nb_factures, nb_projets, rang, part_pct,
                                         part_cumul_pct, classe_abc)
    SELECT s.fournisseur_maitre_id, s.annee, s.montant, s.nb_factures, s.nb_projets, s.rang, s.part, s.part_cumul,
           CASE WHEN s.part_cumul - s.part < 0.80 THEN 'A' WHEN s.part_cumul - s.part < 0.95 THEN 'B' ELSE 'C' END
    FROM (
        SELECT a.*,
               DENSE_RANK() OVER (PARTITION BY a.annee ORDER BY a.montant DESC) AS rang,
               CAST(a.montant / SUM(a.montant) OVER (PARTITION BY a.annee) AS decimal(9,6)) AS part,
               CAST(SUM(a.montant) OVER (PARTITION BY a.annee ORDER BY a.montant DESC, a.fournisseur_maitre_id
                                         ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                    / SUM(a.montant) OVER (PARTITION BY a.annee) AS decimal(9,6)) AS part_cumul
        FROM (SELECT fournisseur_maitre_id, YEAR([date]) AS annee, SUM(montant_ht) AS montant,
                     COUNT(DISTINCT facture_fourn_id) AS nb_factures, COUNT(DISTINCT projet_id) AS nb_projets
              FROM dw.fait_cout_fournisseur
              GROUP BY fournisseur_maitre_id, YEAR([date])) a
        WHERE a.montant > 0
    ) s;

    /* ---------- 10. Équipements × mois : taux d'utilisation = heures ÷ heures disponibles */
    TRUNCATE TABLE gold.equipement_mensuel;
    INSERT INTO gold.equipement_mensuel (equipement_id, mois, heures, jours_utilises, jours_ouvrables, heures_disponibles, revenu_interne)
    SELECT g.equipement_id, g.mois, ISNULL(u.heures, 0), ISNULL(u.jours, 0), g.jours_ouvrables, g.jours_ouvrables * 8.0,
           ISNULL(u.revenu, 0)
    FROM (SELECT e.equipement_id, d.debut_mois AS mois, SUM(CAST(d.est_jour_ouvrable AS int)) AS jours_ouvrables
          FROM dw.dim_equipement e
          JOIN dw.dim_date d ON d.[date] BETWEEN CASE WHEN e.date_acquisition > '2019-01-01' THEN e.date_acquisition ELSE '2019-01-01' END
                                             AND ISNULL(e.date_disposition, @date_ref)
          WHERE d.[date] <= @date_ref
          GROUP BY e.equipement_id, d.debut_mois) g
    LEFT JOIN (SELECT equipement_id, DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois, SUM(heures) AS heures,
                      COUNT(DISTINCT [date]) AS jours, SUM(cout_interne) AS revenu
               FROM dw.fait_utilisation_equipement
               GROUP BY equipement_id, DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) u
           ON u.equipement_id = g.equipement_id AND u.mois = g.mois;

    /* ---------- 11. Clients (fiche maîtresse) : valeur, rentabilité, délai de paiement */
    TRUNCATE TABLE gold.client_synthese;
    INSERT INTO gold.client_synthese (client_maitre_id, nb_projets, nb_projets_actifs, revenus_total, revenus_12_mois,
        valeur_projets_termines, cout_projets_termines, montant_paye, jours_paiement_ponderes, solde_ouvert, premiere_facture, derniere_facture)
    SELECT c.client_maitre_id, ISNULL(p.nb, 0), ISNULL(p.nb_actifs, 0), ISNULL(f.revenus, 0), ISNULL(f.revenus_12, 0),
           ISNULL(p.valeur_term, 0), ISNULL(p.cout_term, 0), ISNULL(f.paye, 0), ISNULL(f.jours_pond, 0), ISNULL(f.solde, 0),
           f.premiere, f.derniere
    FROM dw.dim_client c
    LEFT JOIN (SELECT client_maitre_id, COUNT(*) AS nb,
                      SUM(CASE WHEN statut IN ('En cours', 'Suspendu') THEN 1 ELSE 0 END) AS nb_actifs,
                      SUM(CASE WHEN statut = 'Terminé' THEN valeur_revisee ELSE 0 END) AS valeur_term,
                      SUM(CASE WHEN statut = 'Terminé' THEN cout_total ELSE 0 END) AS cout_term
               FROM gold.projet_synthese GROUP BY client_maitre_id) p ON p.client_maitre_id = c.client_maitre_id
    LEFT JOIN (SELECT client_maitre_id, SUM(montant_ht) AS revenus,
                      SUM(CASE WHEN [date] > DATEADD(month, -12, @date_ref) THEN montant_ht ELSE 0 END) AS revenus_12,
                      SUM(CASE WHEN jours_pour_payer IS NOT NULL THEN montant_ttc ELSE 0 END) AS paye,
                      SUM(CASE WHEN jours_pour_payer IS NOT NULL THEN montant_ttc * jours_pour_payer ELSE 0 END) AS jours_pond,
                      SUM(solde) AS solde, MIN([date]) AS premiere, MAX([date]) AS derniere
               FROM dw.fait_facture_client GROUP BY client_maitre_id) f ON f.client_maitre_id = c.client_maitre_id
    WHERE c.client_maitre_id <> -1;

    /* ---------- 12. KPI d'entreprise par mois : 12 mois glissants, carnet de commandes, recevables, DSO */
    TRUNCATE TABLE gold.kpi_mensuel;
    INSERT INTO gold.kpi_mensuel (mois, revenus, couts, marge_brute, revenus_12_mois_glissants, marge_12_mois_glissants,
        carnet_commandes, comptes_recevables_fin_mois, facturation_ttc_3_mois, effectif_actif, heures_total, heures_supp, nb_projets_actifs, est_mois_complet)
    SELECT m.mois, m.revenus, m.couts, m.revenus - m.couts,
           SUM(m.revenus) OVER (ORDER BY m.mois ROWS BETWEEN 11 PRECEDING AND CURRENT ROW),
           SUM(m.revenus - m.couts) OVER (ORDER BY m.mois ROWS BETWEEN 11 PRECEDING AND CURRENT ROW),
           ISNULL(bl.carnet, 0),
           SUM(m.facture_ttc - m.encaisse) OVER (ORDER BY m.mois ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) + m.ar_initial,
           SUM(m.facture_ttc) OVER (ORDER BY m.mois ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
           m.effectif, m.heures, m.heures_supp, m.nb_projets,
           CASE WHEN EOMONTH(m.mois) < @date_ref THEN 1 ELSE 0 END
    FROM (
        SELECT g.mois,
               ISNULL(r.revenus, 0) AS revenus, ISNULL(r.facture_ttc, 0) AS facture_ttc, ISNULL(e.encaisse, 0) AS encaisse,
               ISNULL(c.couts, 0) AS couts, ISNULL(c.nb_projets, 0) AS nb_projets,
               ISNULL(h.effectif, 0) AS effectif, ISNULL(h.heures, 0) AS heures, ISNULL(h.heures_supp, 0) AS heures_supp,
               -- solde des factures émises avant 2019 et encaissées après (point de départ du cumul)
               (SELECT ISNULL(SUM(montant_ttc), 0) FROM dw.fait_facture_client WHERE [date] < '2019-01-01')
               - (SELECT ISNULL(SUM(montant), 0) FROM dw.fait_encaissement WHERE [date] < '2019-01-01') AS ar_initial
        FROM (SELECT [date] AS mois FROM dw.dim_date WHERE [date] = debut_mois AND [date] BETWEEN '2019-01-01' AND @date_ref) g
        LEFT JOIN (SELECT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois, SUM(montant_ht) AS revenus, SUM(montant_ttc) AS facture_ttc
                   FROM dw.fait_facture_client GROUP BY DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) r ON r.mois = g.mois
        LEFT JOIN (SELECT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois, SUM(montant) AS encaisse
                   FROM dw.fait_encaissement GROUP BY DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) e ON e.mois = g.mois
        LEFT JOIN (SELECT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois, SUM(montant) AS couts, COUNT(DISTINCT projet_id) AS nb_projets
                   FROM dw.fait_cout_projet GROUP BY DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) c ON c.mois = g.mois
        LEFT JOIN (SELECT DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) AS mois, COUNT(DISTINCT employe_id) AS effectif,
                          SUM(heures_total) AS heures, SUM(heures_supp) AS heures_supp
                   FROM dw.fait_heures GROUP BY DATEFROMPARTS(YEAR([date]), MONTH([date]), 1)) h ON h.mois = g.mois
    ) m
    -- carnet de commandes à la fin du mois : valeur révisée restant à facturer des projets démarrés et non terminés
    LEFT JOIN (SELECT pm.mois,
                      SUM(CASE WHEN pm.valeur_revisee - pm.facture_cumul > 0 THEN pm.valeur_revisee - pm.facture_cumul ELSE 0 END) AS carnet
               FROM (SELECT g2.mois, p.projet_id, p.valeur_revisee, ISNULL(SUM(f.montant_ht), 0) AS facture_cumul
                     FROM (SELECT [date] AS mois, EOMONTH([date]) AS fin_mois FROM dw.dim_date
                           WHERE [date] = debut_mois AND [date] BETWEEN '2019-01-01' AND @date_ref) g2
                     JOIN dw.dim_projet p
                       ON p.projet_id <> -1 AND p.statut <> 'Annulé'
                      AND COALESCE(p.date_debut_reelle, p.date_debut_prevue) <= g2.fin_mois
                      AND (p.date_fin_reelle IS NULL OR p.date_fin_reelle > g2.fin_mois)
                     LEFT JOIN dw.fait_facture_client f ON f.projet_id = p.projet_id AND f.[date] <= g2.fin_mois
                     GROUP BY g2.mois, p.projet_id, p.valeur_revisee) pm
               GROUP BY pm.mois) bl
           ON bl.mois = m.mois;
END
GO

CREATE OR ALTER PROCEDURE gold.usp_charger_tout @execution_id varchar(40)
AS
BEGIN
    DECLARE @t datetime2(6);
    SET @t = SYSDATETIME(); EXEC gold.usp_charger_projets;   EXEC audit.usp_journaliser @execution_id, 'gold.projets', @t;
    SET @t = SYSDATETIME(); EXEC gold.usp_charger_divisions; EXEC audit.usp_journaliser @execution_id, 'gold.divisions', @t;
    SET @t = SYSDATETIME(); EXEC gold.usp_charger_finances;  EXEC audit.usp_journaliser @execution_id, 'gold.finances', @t;
END
GO
