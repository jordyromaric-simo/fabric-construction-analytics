/* =====================================================================
   Script 02 : chargement des données (≈ 1,4 million de lignes)
   ===================================================================== */
USE BorealERP;
GO
SET NOCOUNT ON;
DECLARE @Dossier nvarchar(260) = N'C:\BorealERP\donnees\';   -- <<< À ADAPTER

DECLARE @fichiers TABLE (Ordre int, NomTable nvarchar(128), Fichier nvarchar(128));
INSERT @fichiers VALUES
 ( 1, N'ref.Region',                    N'ref_Region.csv'),
 ( 2, N'ref.Ville',                     N'ref_Ville.csv'),
 ( 3, N'ref.Division',                  N'ref_Division.csv'),
 ( 4, N'ref.Metier',                    N'ref_Metier.csv'),
 ( 5, N'ref.CodeCout',                  N'ref_CodeCout.csv'),
 ( 6, N'ref.ParametreCout',             N'ref_ParametreCout.csv'),
 ( 7, N'vente.Client',                  N'vente_Client.csv'),
 ( 8, N'paie.Employe',                  N'paie_Employe.csv'),
 ( 9, N'paie.TauxHoraire',              N'paie_TauxHoraire.csv'),
 (10, N'projet.Projet',                 N'projet_Projet.csv'),
 (11, N'projet.Budget',                 N'projet_Budget.csv'),
 (12, N'projet.OrdreChangement',        N'projet_OrdreChangement.csv'),
 (13, N'paie.FeuilleTemps',             N'paie_FeuilleTemps.csv'),
 (14, N'achat.Fournisseur',             N'achat_Fournisseur.csv'),
 (15, N'achat.BonCommande',             N'achat_BonCommande.csv'),
 (16, N'achat.FactureFournisseur',      N'achat_FactureFournisseur.csv'),
 (17, N'achat.FactureFournisseurLigne', N'achat_FactureFournisseurLigne.csv'),
 (18, N'vente.FactureClient',           N'vente_FactureClient.csv'),
 (19, N'vente.Encaissement',            N'vente_Encaissement.csv'),
 (20, N'equip.Equipement',              N'equip_Equipement.csv'),
 (21, N'equip.UtilisationEquipement',   N'equip_UtilisationEquipement.csv');

DECLARE @i int = 1, @t nvarchar(128), @f nvarchar(128), @sql nvarchar(max), @n bigint;
WHILE @i <= 21
BEGIN
    SELECT @t = NomTable, @f = Fichier FROM @fichiers WHERE Ordre = @i;
    SET @sql = N'BULK INSERT ' + @t + N' FROM ''' + @Dossier + @f + N'''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'', FIELDTERMINATOR = '','',
              ROWTERMINATOR = ''0x0a'', CODEPAGE = ''65001'', KEEPIDENTITY, KEEPNULLS, TABLOCK);';
    EXEC sys.sp_executesql @sql;
    SET @sql = N'SELECT @n = COUNT_BIG(*) FROM ' + @t;
    EXEC sys.sp_executesql @sql, N'@n bigint OUTPUT', @n = @n OUTPUT;
    PRINT CONCAT(RIGHT(N'  ' + CAST(@i AS nvarchar(3)), 2), N'. ', @t, N' : ', FORMAT(@n, N'N0'), N' lignes');
    SET @i += 1;
END
GO

/* BULK INSERT ne valide pas les clés étrangères : on les revalide pour que
   SQL Server les considère « fiables » (trusted).                         */
DECLARE @sql nvarchar(max) = N'';
SELECT @sql += N'ALTER TABLE ' + QUOTENAME(SCHEMA_NAME(schema_id)) + N'.' + QUOTENAME(name) + N' WITH CHECK CHECK CONSTRAINT ALL;' + CHAR(10)
FROM sys.tables WHERE SCHEMA_NAME(schema_id) IN (N'ref', N'paie', N'projet', N'achat', N'vente', N'equip');
EXEC sys.sp_executesql @sql;
GO

/* Contrôle final */
SELECT s.name AS SchemaNom, t.name AS TableNom, SUM(p.rows) AS NbLignes
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY s.name, t.name
ORDER BY s.name, t.name;
PRINT N'Chargement terminé. Optionnel : 03_simulation_quotidienne.sql pour générer de nouvelles journées.';
