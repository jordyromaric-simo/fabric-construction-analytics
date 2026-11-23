/* =====================================================================
   Script 11 : vues de la couche BRONZE
   ---------------------------------------------------------------------
   Une vue par table brute du lakehouse LH_Bronze (requête inter-bases :
   l'entrepôt lit le point de terminaison SQL du lakehouse du même espace).
   ===================================================================== */

CREATE OR ALTER VIEW bronze.ref_region AS SELECT * FROM LH_Bronze.dbo.erp_ref_region;
GO
CREATE OR ALTER VIEW bronze.ref_ville AS SELECT * FROM LH_Bronze.dbo.erp_ref_ville;
GO
CREATE OR ALTER VIEW bronze.ref_division AS SELECT * FROM LH_Bronze.dbo.erp_ref_division;
GO
CREATE OR ALTER VIEW bronze.ref_metier AS SELECT * FROM LH_Bronze.dbo.erp_ref_metier;
GO
CREATE OR ALTER VIEW bronze.ref_codecout AS SELECT * FROM LH_Bronze.dbo.erp_ref_codecout;
GO
CREATE OR ALTER VIEW bronze.ref_parametrecout AS SELECT * FROM LH_Bronze.dbo.erp_ref_parametrecout;
GO
CREATE OR ALTER VIEW bronze.vente_client AS SELECT * FROM LH_Bronze.dbo.erp_vente_client;
GO
CREATE OR ALTER VIEW bronze.paie_employe AS SELECT * FROM LH_Bronze.dbo.erp_paie_employe;
GO
CREATE OR ALTER VIEW bronze.paie_tauxhoraire AS SELECT * FROM LH_Bronze.dbo.erp_paie_tauxhoraire;
GO
CREATE OR ALTER VIEW bronze.projet_projet AS SELECT * FROM LH_Bronze.dbo.erp_projet_projet;
GO
CREATE OR ALTER VIEW bronze.projet_budget AS SELECT * FROM LH_Bronze.dbo.erp_projet_budget;
GO
CREATE OR ALTER VIEW bronze.projet_ordrechangement AS SELECT * FROM LH_Bronze.dbo.erp_projet_ordrechangement;
GO
CREATE OR ALTER VIEW bronze.paie_feuilletemps AS SELECT * FROM LH_Bronze.dbo.erp_paie_feuilletemps;
GO
CREATE OR ALTER VIEW bronze.achat_fournisseur AS SELECT * FROM LH_Bronze.dbo.erp_achat_fournisseur;
GO
CREATE OR ALTER VIEW bronze.achat_boncommande AS SELECT * FROM LH_Bronze.dbo.erp_achat_boncommande;
GO
CREATE OR ALTER VIEW bronze.achat_facturefournisseur AS SELECT * FROM LH_Bronze.dbo.erp_achat_facturefournisseur;
GO
CREATE OR ALTER VIEW bronze.achat_facturefournisseurligne AS SELECT * FROM LH_Bronze.dbo.erp_achat_facturefournisseurligne;
GO
CREATE OR ALTER VIEW bronze.vente_factureclient AS SELECT * FROM LH_Bronze.dbo.erp_vente_factureclient;
GO
CREATE OR ALTER VIEW bronze.vente_encaissement AS SELECT * FROM LH_Bronze.dbo.erp_vente_encaissement;
GO
CREATE OR ALTER VIEW bronze.equip_equipement AS SELECT * FROM LH_Bronze.dbo.erp_equip_equipement;
GO
CREATE OR ALTER VIEW bronze.equip_utilisationequipement AS SELECT * FROM LH_Bronze.dbo.erp_equip_utilisationequipement;
GO
CREATE OR ALTER VIEW bronze.ext_crm_companies AS SELECT * FROM LH_Bronze.dbo.ext_crm_companies;
GO
CREATE OR ALTER VIEW bronze.ext_objectifs_ca AS SELECT * FROM LH_Bronze.dbo.ext_objectifs_ca;
GO
CREATE OR ALTER VIEW bronze.ext_objectifs_marge AS SELECT * FROM LH_Bronze.dbo.ext_objectifs_marge;
GO

/* Vérification : nombre de lignes par vue bronze */
SELECT 'erp_paie_feuilletemps' AS table_bronze, COUNT_BIG(*) AS nb FROM bronze.paie_feuilletemps
UNION ALL SELECT 'erp_achat_facturefournisseurligne', COUNT_BIG(*) FROM bronze.achat_facturefournisseurligne
UNION ALL SELECT 'erp_projet_projet', COUNT_BIG(*) FROM bronze.projet_projet
UNION ALL SELECT 'ext_crm_companies', COUNT_BIG(*) FROM bronze.ext_crm_companies;
