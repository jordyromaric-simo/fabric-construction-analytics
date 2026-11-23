/* =====================================================================
   Script 04 : comptes SQL utilisés par Fabric (via la passerelle)
   ===================================================================== */
USE master;
GO
/* A. Compte en LECTURE SEULE pour le Copy job / Dataflow Gen2 / pipeline */
IF SUSER_ID(N'fabric_lecteur') IS NULL
    CREATE LOGIN fabric_lecteur WITH PASSWORD = N'<MotDePasseFort_1!>', CHECK_POLICY = ON;
GO
USE BorealERP;
GO
IF USER_ID(N'fabric_lecteur') IS NULL
    CREATE USER fabric_lecteur FOR LOGIN fabric_lecteur;
ALTER ROLE db_datareader ADD MEMBER fabric_lecteur;
GO

/* B. (MODULE OPTIONNEL) Compte pour la mise en miroir (Mirroring) de SQL Server.
      Permissions minimales indiquées par la documentation Microsoft.
      Vérifie la page « Tutorial: Configure Microsoft Fabric mirrored databases
      from SQL Server » avant de lancer : les prérequis varient selon la
      version (2016-2022 = CDC, 2025 = flux de modifications).                 */
USE master;
GO
IF SUSER_ID(N'fabric_login') IS NULL
    CREATE LOGIN fabric_login WITH PASSWORD = N'<MotDePasseFort_2!>', CHECK_POLICY = ON;
GO
USE BorealERP;
GO
IF USER_ID(N'fabric_user') IS NULL
    CREATE USER fabric_user FOR LOGIN fabric_login;
GRANT SELECT, ALTER ANY EXTERNAL MIRROR, VIEW DATABASE PERFORMANCE STATE, VIEW DATABASE SECURITY STATE TO fabric_user;
GO
/* Le permission « ALTER ANY EXTERNAL MIRROR » n'existe pas sur certaines
   anciennes versions : si la ligne échoue, saute le module miroir et reste
   sur le Copy job, qui couvre tout le projet.                              */
