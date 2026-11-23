/* =====================================================================
   Script 17 : tests de qualité et de réconciliation
   ===================================================================== */

/* T1. Les heures ne se perdent pas entre stg et dw */
SELECT 'T1 heures stg = dw' AS test,
       (SELECT SUM(heures_reg + heures_supp) FROM stg.feuille_temps) AS stg,
       (SELECT SUM(heures_total) FROM dw.fait_heures) AS dw,
       CASE WHEN ABS((SELECT SUM(heures_reg + heures_supp) FROM stg.feuille_temps) - (SELECT SUM(heures_total) FROM dw.fait_heures)) < 0.01
            THEN 'OK' ELSE 'ÉCART' END AS resultat
UNION ALL
/* T2. Lignes de factures fournisseurs (hors doublons) = coûts fournisseurs dw */
SELECT 'T2 lignes fournisseurs stg = dw',
       (SELECT SUM(l.montant_ligne) FROM stg.facture_fournisseur_ligne l
          JOIN stg.facture_fournisseur f ON f.facture_fourn_id = l.facture_fourn_id WHERE f.est_doublon = 0),
       (SELECT SUM(montant_ht) FROM dw.fait_cout_fournisseur),
       CASE WHEN ABS((SELECT SUM(l.montant_ligne) FROM stg.facture_fournisseur_ligne l
                        JOIN stg.facture_fournisseur f ON f.facture_fourn_id = l.facture_fourn_id WHERE f.est_doublon = 0)
                   - (SELECT SUM(montant_ht) FROM dw.fait_cout_fournisseur)) < 0.01 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T3. Le coût unifié = somme des 3 sources */
SELECT 'T3 coût unifié = MO + fournisseurs + équipement',
       (SELECT SUM(cout_mo) FROM dw.fait_heures WHERE projet_id <> -1)
       + (SELECT SUM(montant_ht) FROM dw.fait_cout_fournisseur) + (SELECT SUM(cout_interne) FROM dw.fait_utilisation_equipement),
       (SELECT SUM(montant) FROM dw.fait_cout_projet),
       CASE WHEN ABS((SELECT SUM(cout_mo) FROM dw.fait_heures WHERE projet_id <> -1)
                   + (SELECT SUM(montant_ht) FROM dw.fait_cout_fournisseur) + (SELECT SUM(cout_interne) FROM dw.fait_utilisation_equipement)
                   - (SELECT SUM(montant) FROM dw.fait_cout_projet)) < 1 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T4. Gold projets = dw (coûts) */
SELECT 'T4 gold.projet_synthese = dw',
       (SELECT SUM(cout_total) FROM gold.projet_synthese), (SELECT SUM(montant) FROM dw.fait_cout_projet),
       CASE WHEN ABS((SELECT SUM(cout_total) FROM gold.projet_synthese) - (SELECT SUM(montant) FROM dw.fait_cout_projet)) < 1
            THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T5. Gold divisions = facturation dw (depuis 2019) */
SELECT 'T5 revenus division_mensuel = dw',
       (SELECT SUM(revenus) FROM gold.division_mensuel),
       (SELECT SUM(montant_ht) FROM dw.fait_facture_client WHERE [date] >= '2019-01-01'),
       CASE WHEN ABS((SELECT SUM(revenus) FROM gold.division_mensuel)
                   - (SELECT SUM(montant_ht) FROM dw.fait_facture_client WHERE [date] >= '2019-01-01')) < 1 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T6. Chaque fait trouve son employé (clé SCD 2) */
SELECT 'T6 heures sans employe_sk', NULL, (SELECT COUNT(*) FROM dw.fait_heures WHERE employe_sk IS NULL),
       CASE WHEN (SELECT COUNT(*) FROM dw.fait_heures WHERE employe_sk IS NULL) = 0 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T7. Une seule version courante par employé */
SELECT 'T7 versions courantes multiples', NULL,
       (SELECT COUNT(*) FROM (SELECT employe_id FROM dw.dim_employe WHERE est_courant = 1 GROUP BY employe_id HAVING COUNT(*) > 1) x),
       CASE WHEN (SELECT COUNT(*) FROM (SELECT employe_id FROM dw.dim_employe WHERE est_courant = 1 GROUP BY employe_id HAVING COUNT(*) > 1) x) = 0
            THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T8. Unicité des clés de dimension (Direct Lake exige des clés uniques côté « un ») */
SELECT 'T8 doublons dim_projet', NULL,
       (SELECT COUNT(*) - COUNT(DISTINCT projet_id) FROM dw.dim_projet),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT projet_id) FROM dw.dim_projet) = 0 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
SELECT 'T8 doublons dim_client', NULL,
       (SELECT COUNT(*) - COUNT(DISTINCT client_maitre_id) FROM dw.dim_client),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT client_maitre_id) FROM dw.dim_client) = 0 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
SELECT 'T8 doublons dim_date', NULL,
       (SELECT COUNT(*) - COUNT(DISTINCT [date]) FROM dw.dim_date),
       CASE WHEN (SELECT COUNT(*) - COUNT(DISTINCT [date]) FROM dw.dim_date) = 0 THEN 'OK' ELSE 'ÉCART' END
UNION ALL
/* T9. Orphelins : faits sans projet connu */
SELECT 'T9 coûts sans projet', NULL,
       (SELECT COUNT(*) FROM dw.fait_cout_projet c WHERE NOT EXISTS (SELECT 1 FROM dw.dim_projet p WHERE p.projet_id = c.projet_id)),
       CASE WHEN (SELECT COUNT(*) FROM dw.fait_cout_projet c WHERE NOT EXISTS (SELECT 1 FROM dw.dim_projet p WHERE p.projet_id = c.projet_id)) = 0
            THEN 'OK' ELSE 'ÉCART' END;

/* ------------------------------------------------------------------ Ce que le nettoyage a trouvé */
SELECT raison_rejet, COUNT(*) AS nb_lignes, SUM(heures_reg + heures_supp) AS heures
FROM stg.rejet_feuille_temps GROUP BY raison_rejet ORDER BY nb_lignes DESC;

SELECT 'Factures fournisseurs saisies en double' AS constat, COUNT(*) AS nb, SUM(montant_ttc) AS montant_ttc
FROM stg.facture_fournisseur WHERE est_doublon = 1
UNION ALL SELECT 'Lignes fournisseurs sans code de coût', COUNT(*), SUM(montant_ligne) FROM stg.facture_fournisseur_ligne WHERE code_cout_id = -1
UNION ALL SELECT 'Projets avec date de fin invalide', COUNT(*), NULL FROM stg.projet WHERE est_date_fin_invalide = 1
UNION ALL SELECT 'Fiches clients ERP fusionnées par le MDM', COUNT(*), NULL FROM mdm.client_xref WHERE source_systeme = 'ERP' AND regle <> 'Fiche maîtresse'
UNION ALL SELECT 'Fiches CRM rattachées à un client', COUNT(*), NULL FROM mdm.client_xref WHERE source_systeme = 'CRM' AND client_maitre_id IS NOT NULL
UNION ALL SELECT 'Prospects CRM sans fiche ERP', COUNT(*), NULL FROM mdm.client_xref WHERE source_systeme = 'CRM' AND client_maitre_id IS NULL
UNION ALL SELECT 'Fiches fournisseurs fusionnées par le MDM', COUNT(*), NULL FROM mdm.fournisseur_xref WHERE regle <> 'Fiche maîtresse';

/* Écart d'arrondi entre l'entête et la somme des lignes de factures fournisseurs */
SELECT f.facture_fourn_id, f.no_facture_fourn, f.montant_ht AS entete, SUM(l.montant_ligne) AS somme_lignes,
       f.montant_ht - SUM(l.montant_ligne) AS ecart
FROM stg.facture_fournisseur f JOIN stg.facture_fournisseur_ligne l ON l.facture_fourn_id = f.facture_fourn_id
GROUP BY f.facture_fourn_id, f.no_facture_fourn, f.montant_ht
HAVING ABS(f.montant_ht - SUM(l.montant_ligne)) >= 0.01;
