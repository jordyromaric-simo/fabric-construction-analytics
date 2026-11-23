/* =====================================================================
   FABRIC — Entrepôt WH_Boreal
   Script 10 : schémas (couches) et journal d'exécution
   ---------------------------------------------------------------------
   Exécute ces scripts depuis SSMS connecté au point de terminaison SQL
   de l'entrepôt (Paramètres de WH_Boreal > Chaîne de connexion SQL).
   SSMS gère les séparateurs GO ; l'éditeur web de Fabric, non.

   Les couches :
     bronze : vues vers les tables brutes du lakehouse LH_Bronze
     stg    : données nettoyées, typées, dernière version de chaque ligne
     mdm    : données maîtres (clients et fournisseurs dédoublonnés)
     dw     : modèle en étoile (dimensions + faits)
     gold   : tables PRÉ-CALCULÉES qui alimentent directement les visuels
     audit  : journal d'exécution et date de référence
   ===================================================================== */
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stg')    EXEC('CREATE SCHEMA stg');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'mdm')    EXEC('CREATE SCHEMA mdm');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')     EXEC('CREATE SCHEMA dw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')   EXEC('CREATE SCHEMA gold');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'audit')  EXEC('CREATE SCHEMA audit');
GO

/* Journal : une ligne par étape exécutée. IDENTITY = clé auto (bigint obligatoire dans Fabric) */
IF OBJECT_ID('audit.journal_execution') IS NULL
CREATE TABLE audit.journal_execution (
    journal_id   bigint IDENTITY,
    execution_id varchar(40)   NOT NULL,
    etape        varchar(100)  NOT NULL,
    debut        datetime2(6)  NOT NULL,
    fin          datetime2(6)  NULL,
    nb_lignes    bigint        NULL,
    statut       varchar(20)   NOT NULL,
    message      varchar(4000) NULL
);
GO

/* Date de référence des données (« aujourd'hui » du point de vue de l'ERP).
   Les données s'arrêtent le 2026-10-22, puis avancent avec la simulation :
   on ne peut donc pas utiliser GETDATE() pour les calculs d'âge, de retard… */
IF OBJECT_ID('audit.date_reference') IS NULL
CREATE TABLE audit.date_reference (date_ref date NOT NULL, calculee_le datetime2(6) NOT NULL);
GO

CREATE OR ALTER PROCEDURE audit.usp_journaliser
    @execution_id varchar(40), @etape varchar(100), @debut datetime2(6),
    @nb_lignes bigint = NULL, @statut varchar(20) = 'Succès', @message varchar(4000) = NULL
AS
BEGIN
    INSERT INTO audit.journal_execution (execution_id, etape, debut, fin, nb_lignes, statut, message)
    VALUES (@execution_id, @etape, @debut, SYSDATETIME(), @nb_lignes, @statut, @message);
END
GO
