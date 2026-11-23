/* =====================================================================
   Script 18 : correctif « mois complet »
   ---------------------------------------------------------------------
   Problème : le mois en cours est incomplet (coûts saisis chaque jour,
   facturation en fin de mois). L'inclure dans une marge ou un cumul
   écrase les résultats (marge brute ~1 % au lieu de ~10 %).
   Correctif : une colonne est_mois_complet dans les 2 tables gold
   mensuelles, recalculée à chaque chargement à partir de la date de
   référence. Les mesures DAX ne retiennent que les mois complets.
   ===================================================================== */

-- 1. Ajouter la colonne (nullable : seul type d'ajout permis sur une table existante)
-- (COL_LENGTH n'existe pas dans Fabric : on interroge INFORMATION_SCHEMA.COLUMNS)
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'gold' AND TABLE_NAME = 'division_mensuel' AND COLUMN_NAME = 'est_mois_complet')
    ALTER TABLE gold.division_mensuel ADD est_mois_complet bit NULL;
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = 'gold' AND TABLE_NAME = 'kpi_mensuel' AND COLUMN_NAME = 'est_mois_complet')
    ALTER TABLE gold.kpi_mensuel ADD est_mois_complet bit NULL;
GO

-- 2. → ré-exécuter maintenant 15_gold.sql en entier, puis revenir ici.

-- 3. Recharger les deux tables et vérifier
EXEC gold.usp_charger_divisions;
EXEC gold.usp_charger_finances;

SELECT TOP (4) mois, est_mois_futur, est_mois_complet, SUM(revenus) AS revenus, SUM(couts) AS couts
FROM gold.division_mensuel
WHERE mois BETWEEN '2026-08-01' AND '2026-11-01'
GROUP BY mois, est_mois_futur, est_mois_complet
ORDER BY mois;

SELECT TOP (3) mois, est_mois_complet, revenus_12_mois_glissants, carnet_commandes
FROM gold.kpi_mensuel
ORDER BY mois DESC;
