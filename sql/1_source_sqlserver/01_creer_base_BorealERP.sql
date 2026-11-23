/* =====================================================================
   PROJET FABRIC — Construction Boréal inc. (entreprise fictive)
   Script 01 : création de la base source « BorealERP » (SQL Server local)
   ---------------------------------------------------------------------
   Simule l'ERP d'un entrepreneur général québécois (paie, projets,
   achats, facturation, équipements).
   ===================================================================== */
USE master;
GO
IF DB_ID(N'BorealERP') IS NOT NULL
BEGIN
    ALTER DATABASE BorealERP SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BorealERP;
END
GO
CREATE DATABASE BorealERP;
GO
ALTER DATABASE BorealERP SET RECOVERY SIMPLE;
GO
USE BorealERP;
GO
CREATE SCHEMA ref;    -- tables de référence
GO
CREATE SCHEMA paie;   -- employés, taux, feuilles de temps
GO
CREATE SCHEMA projet; -- projets, budgets, ordres de changement
GO
CREATE SCHEMA achat;  -- fournisseurs, bons de commande, factures fournisseurs
GO
CREATE SCHEMA vente;  -- clients, factures clients, encaissements
GO
CREATE SCHEMA equip;  -- parc d'équipements et utilisation
GO
CREATE SCHEMA util;   -- procédures utilitaires (simulation)
GO

/* ---------------------------------------------------------------- RÉFÉRENCE */
CREATE TABLE ref.Region (
    RegionID      int           NOT NULL CONSTRAINT PK_Region PRIMARY KEY,
    NomRegion     nvarchar(60)  NOT NULL
);
CREATE TABLE ref.Ville (
    VilleID       int           NOT NULL CONSTRAINT PK_Ville PRIMARY KEY,
    NomVille      nvarchar(80)  NOT NULL,
    RegionID      int           NOT NULL CONSTRAINT FK_Ville_Region REFERENCES ref.Region(RegionID)
);
CREATE TABLE ref.Division (
    DivisionID    int           NOT NULL CONSTRAINT PK_Division PRIMARY KEY,
    CodeDivision  nvarchar(5)   NOT NULL,
    NomDivision   nvarchar(60)  NOT NULL
);
CREATE TABLE ref.Metier (
    MetierID      int           NOT NULL CONSTRAINT PK_Metier PRIMARY KEY,
    CodeMetier    nvarchar(5)   NOT NULL,
    NomMetier     nvarchar(80)  NOT NULL,
    Categorie     nvarchar(20)  NOT NULL,          -- Chantier / Bureau
    EstSyndique   bit           NOT NULL
);
CREATE TABLE ref.CodeCout (
    CodeCoutID    int           NOT NULL CONSTRAINT PK_CodeCout PRIMARY KEY,
    CodeCout      nvarchar(10)  NOT NULL,          -- ex. 03-MAT
    Description   nvarchar(120) NOT NULL,
    TypeCout      nvarchar(30)  NOT NULL,          -- Main-d'œuvre, Matériaux, Sous-traitance, Équipement, Frais généraux
    CodeSection   nvarchar(2)   NOT NULL,
    NomSection    nvarchar(60)  NOT NULL
);
CREATE TABLE ref.ParametreCout (
    Annee               int          NOT NULL CONSTRAINT PK_ParametreCout PRIMARY KEY,
    TauxChargesSociales decimal(5,4) NOT NULL,      -- charges ajoutées au taux horaire (CCQ, vacances, CNESST…)
    TauxTPS             decimal(6,5) NOT NULL,
    TauxTVQ             decimal(6,5) NOT NULL,
    TauxRetenue         decimal(5,4) NOT NULL       -- retenue contractuelle sur la facturation client
);

/* ---------------------------------------------------------------- VENTE : CLIENTS */
CREATE TABLE vente.Client (
    ClientID            int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Client PRIMARY KEY,
    NoClient            nvarchar(10)  NOT NULL,
    NomClient           nvarchar(150) NOT NULL,
    TypeClient          nvarchar(10)  NOT NULL,     -- Public / Privé
    Segment             nvarchar(30)  NOT NULL,
    NEQ                 nvarchar(10)  NULL,         -- numéro d'entreprise du Québec
    Adresse             nvarchar(150) NULL,
    VilleID             int           NULL CONSTRAINT FK_Client_Ville REFERENCES ref.Ville(VilleID),
    CodePostal          nvarchar(10)  NULL,
    Telephone           nvarchar(20)  NULL,
    Courriel            nvarchar(150) NULL,
    ConditionsPaiement  int           NOT NULL,     -- jours
    LimiteCredit        decimal(14,2) NOT NULL,
    CreatedAt           datetime2(0)  NOT NULL,
    ModifiedAt          datetime2(0)  NOT NULL
);

/* ---------------------------------------------------------------- PAIE */
CREATE TABLE paie.Employe (
    EmployeID       int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Employe PRIMARY KEY,
    Matricule       nvarchar(10)  NOT NULL,
    Prenom          nvarchar(60)  NOT NULL,
    Nom             nvarchar(60)  NOT NULL,
    Courriel        nvarchar(150) NULL,
    MetierID        int           NOT NULL CONSTRAINT FK_Employe_Metier REFERENCES ref.Metier(MetierID),
    DivisionID      int           NOT NULL CONSTRAINT FK_Employe_Division REFERENCES ref.Division(DivisionID),
    VilleID         int           NULL CONSTRAINT FK_Employe_Ville REFERENCES ref.Ville(VilleID),
    DateEmbauche    date          NOT NULL,
    DateDepart      date          NULL,
    Statut          nvarchar(15)  NOT NULL,         -- Actif / Inactif / Congé
    TypeEmploi      nvarchar(15)  NOT NULL,         -- Permanent / Saisonnier / Temporaire
    SuperviseurID   int           NULL CONSTRAINT FK_Employe_Superviseur REFERENCES paie.Employe(EmployeID),
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
CREATE TABLE paie.TauxHoraire (
    TauxID          int IDENTITY(1,1) NOT NULL CONSTRAINT PK_TauxHoraire PRIMARY KEY,
    EmployeID       int           NOT NULL CONSTRAINT FK_Taux_Employe REFERENCES paie.Employe(EmployeID),
    DateDebut       date          NOT NULL,
    DateFin         date          NULL,             -- NULL = taux en vigueur
    TauxHoraire     decimal(8,2)  NOT NULL,
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);

/* ---------------------------------------------------------------- PROJETS */
CREATE TABLE projet.Projet (
    ProjetID              int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Projet PRIMARY KEY,
    NoProjet              nvarchar(12)  NOT NULL,
    NomProjet             nvarchar(200) NOT NULL,
    ClientID              int           NOT NULL CONSTRAINT FK_Projet_Client REFERENCES vente.Client(ClientID),
    DivisionID            int           NOT NULL CONSTRAINT FK_Projet_Division REFERENCES ref.Division(DivisionID),
    VilleID               int           NOT NULL CONSTRAINT FK_Projet_Ville REFERENCES ref.Ville(VilleID),
    ChargeProjetID        int           NULL CONSTRAINT FK_Projet_ChargeProjet REFERENCES paie.Employe(EmployeID),
    TypeContrat           nvarchar(20)  NOT NULL,   -- Forfaitaire / Coût plus / Prix unitaire
    ValeurContrat         decimal(14,2) NOT NULL,
    DateDebutPrevue       date          NOT NULL,
    DateFinPrevue         date          NOT NULL,
    DateDebutReelle       date          NULL,
    DateFinReelle         date          NULL,
    Statut                nvarchar(20)  NOT NULL,   -- saisi à la main : la casse varie !
    PourcentageAvancement decimal(5,1)  NULL,       -- saisi par le chargé de projet (parfois pas à jour)
    CreatedAt             datetime2(0)  NOT NULL,
    ModifiedAt            datetime2(0)  NOT NULL
);
CREATE TABLE projet.Budget (
    BudgetID        int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Budget PRIMARY KEY,
    ProjetID        int           NOT NULL CONSTRAINT FK_Budget_Projet REFERENCES projet.Projet(ProjetID),
    CodeCoutID      int           NOT NULL CONSTRAINT FK_Budget_CodeCout REFERENCES ref.CodeCout(CodeCoutID),
    Version         nvarchar(20)  NOT NULL,         -- Original / Révisé 1
    Montant         decimal(14,2) NOT NULL,
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
CREATE TABLE projet.OrdreChangement (
    OrdreChangementID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrdreChangement PRIMARY KEY,
    ProjetID          int           NOT NULL CONSTRAINT FK_OC_Projet REFERENCES projet.Projet(ProjetID),
    NoOC              nvarchar(20)  NOT NULL,
    DateOC            date          NOT NULL,
    Description       nvarchar(200) NULL,
    Montant           decimal(14,2) NOT NULL,
    Statut            nvarchar(15)  NOT NULL,       -- Approuvé / En attente / Refusé
    CreatedAt         datetime2(0)  NOT NULL,
    ModifiedAt        datetime2(0)  NOT NULL
);

/* ---------------------------------------------------------------- FEUILLES DE TEMPS */
CREATE TABLE paie.FeuilleTemps (
    FeuilleTempsID  bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FeuilleTemps PRIMARY KEY,
    EmployeID       int           NOT NULL CONSTRAINT FK_FT_Employe REFERENCES paie.Employe(EmployeID),
    DateTravail     date          NOT NULL,
    ProjetID        int           NULL CONSTRAINT FK_FT_Projet REFERENCES projet.Projet(ProjetID),  -- NULL = temps administratif
    CodeCoutID      int           NOT NULL CONSTRAINT FK_FT_CodeCout REFERENCES ref.CodeCout(CodeCoutID),
    HeuresReg       decimal(5,2)  NOT NULL,
    HeuresSupp      decimal(5,2)  NOT NULL,         -- payées à temps et demi
    Statut          nvarchar(15)  NOT NULL,         -- Soumis / Approuvé / Rejeté
    Commentaire     nvarchar(200) NULL,
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL,
    IsDeleted       bit           NOT NULL CONSTRAINT DF_FT_IsDeleted DEFAULT (0)   -- suppression logique
);

/* ---------------------------------------------------------------- ACHATS */
CREATE TABLE achat.Fournisseur (
    FournisseurID          int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Fournisseur PRIMARY KEY,
    NoFournisseur          nvarchar(10)  NOT NULL,
    NomFournisseur         nvarchar(150) NOT NULL,
    Categorie              nvarchar(30)  NOT NULL,  -- Matériaux / Sous-traitant / Location équipement / Services
    CodeSectionPrincipale  nvarchar(2)   NULL,
    NEQ                    nvarchar(10)  NULL,
    VilleID                int           NULL CONSTRAINT FK_Fournisseur_Ville REFERENCES ref.Ville(VilleID),
    Telephone              nvarchar(20)  NULL,
    Courriel               nvarchar(150) NULL,
    ConditionsPaiement     int           NOT NULL,
    CreatedAt              datetime2(0)  NOT NULL,
    ModifiedAt             datetime2(0)  NOT NULL
);
CREATE TABLE achat.BonCommande (
    BonCommandeID   int IDENTITY(1,1) NOT NULL CONSTRAINT PK_BonCommande PRIMARY KEY,
    NoBC            nvarchar(12)  NOT NULL,
    ProjetID        int           NOT NULL CONSTRAINT FK_BC_Projet REFERENCES projet.Projet(ProjetID),
    FournisseurID   int           NOT NULL CONSTRAINT FK_BC_Fournisseur REFERENCES achat.Fournisseur(FournisseurID),
    DateBC          date          NOT NULL,
    AcheteurID      int           NULL CONSTRAINT FK_BC_Acheteur REFERENCES paie.Employe(EmployeID),
    Statut          nvarchar(15)  NOT NULL,         -- Ouvert / Fermé / Annulé
    MontantTotal    decimal(14,2) NOT NULL,
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
CREATE TABLE achat.FactureFournisseur (
    FactureFournID  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactureFournisseur PRIMARY KEY,
    NoFactureFourn  nvarchar(30)  NOT NULL,         -- numéro inscrit par le fournisseur
    FournisseurID   int           NOT NULL CONSTRAINT FK_FF_Fournisseur REFERENCES achat.Fournisseur(FournisseurID),
    BonCommandeID   int           NULL CONSTRAINT FK_FF_BC REFERENCES achat.BonCommande(BonCommandeID),
    DateFacture     date          NOT NULL,
    DateEcheance    date          NOT NULL,
    DatePaiement    date          NULL,
    MontantHT       decimal(14,2) NOT NULL,
    TPS             decimal(14,2) NOT NULL,
    TVQ             decimal(14,2) NOT NULL,
    MontantTTC      decimal(14,2) NOT NULL,
    Statut          nvarchar(15)  NOT NULL,         -- À payer / Payée / En litige
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
CREATE TABLE achat.FactureFournisseurLigne (
    LigneID         bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactureFournisseurLigne PRIMARY KEY,
    FactureFournID  int           NOT NULL CONSTRAINT FK_FFL_Facture REFERENCES achat.FactureFournisseur(FactureFournID),
    NoLigne         int           NOT NULL,
    ProjetID        int           NOT NULL CONSTRAINT FK_FFL_Projet REFERENCES projet.Projet(ProjetID),
    CodeCoutID      int           NULL CONSTRAINT FK_FFL_CodeCout REFERENCES ref.CodeCout(CodeCoutID),  -- parfois oublié !
    Description     nvarchar(200) NULL,
    Quantite        decimal(12,2) NOT NULL,
    Unite           nvarchar(15)  NULL,
    PrixUnitaire    decimal(14,4) NOT NULL,
    MontantLigne    decimal(14,2) NOT NULL,
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);

/* ---------------------------------------------------------------- VENTE : FACTURATION */
CREATE TABLE vente.FactureClient (
    FactureClientID int IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactureClient PRIMARY KEY,
    NoFacture       nvarchar(12)  NOT NULL,
    ProjetID        int           NOT NULL CONSTRAINT FK_FC_Projet REFERENCES projet.Projet(ProjetID),
    ClientID        int           NOT NULL CONSTRAINT FK_FC_Client REFERENCES vente.Client(ClientID),
    TypeFacture     nvarchar(30)  NOT NULL,         -- Décompte progressif / Décompte final / Libération de retenue
    NoDecompte      int           NULL,
    DateFacture     date          NOT NULL,
    DateEcheance    date          NOT NULL,
    MontantHT       decimal(14,2) NOT NULL,         -- valeur des travaux facturés
    Retenue         decimal(14,2) NOT NULL,         -- 10 % retenu ; négatif = libération
    MontantNet      decimal(14,2) NOT NULL,         -- HT - Retenue
    TPS             decimal(14,2) NOT NULL,
    TVQ             decimal(14,2) NOT NULL,
    MontantTTC      decimal(14,2) NOT NULL,
    Statut          nvarchar(25)  NOT NULL,         -- Émise / Partiellement payée / Payée / En litige
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
CREATE TABLE vente.Encaissement (
    EncaissementID   int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Encaissement PRIMARY KEY,
    FactureClientID  int           NOT NULL CONSTRAINT FK_Enc_Facture REFERENCES vente.FactureClient(FactureClientID),
    DateEncaissement date          NOT NULL,
    Montant          decimal(14,2) NOT NULL,
    ModePaiement     nvarchar(15)  NOT NULL,
    NoReference      nvarchar(20)  NULL,
    CreatedAt        datetime2(0)  NOT NULL,
    ModifiedAt       datetime2(0)  NOT NULL
);

/* ---------------------------------------------------------------- ÉQUIPEMENTS */
CREATE TABLE equip.Equipement (
    EquipementID        int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Equipement PRIMARY KEY,
    NoUnite             nvarchar(10)  NOT NULL,
    Description         nvarchar(120) NOT NULL,
    Categorie           nvarchar(40)  NOT NULL,
    Marque              nvarchar(40)  NULL,
    Modele              nvarchar(40)  NULL,
    Annee               int           NULL,
    DateAcquisition     date          NOT NULL,
    DateDisposition     date          NULL,
    TauxHoraireInterne  decimal(8,2)  NOT NULL,     -- taux facturé aux projets
    Statut              nvarchar(15)  NOT NULL,
    CreatedAt           datetime2(0)  NOT NULL,
    ModifiedAt          datetime2(0)  NOT NULL
);
CREATE TABLE equip.UtilisationEquipement (
    UtilisationID   bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_UtilisationEquipement PRIMARY KEY,
    EquipementID    int           NOT NULL CONSTRAINT FK_UE_Equipement REFERENCES equip.Equipement(EquipementID),
    ProjetID        int           NOT NULL CONSTRAINT FK_UE_Projet REFERENCES projet.Projet(ProjetID),
    DateUtilisation date          NOT NULL,
    Heures          decimal(5,2)  NOT NULL,
    OperateurID     int           NULL CONSTRAINT FK_UE_Operateur REFERENCES paie.Employe(EmployeID),
    CreatedAt       datetime2(0)  NOT NULL,
    ModifiedAt      datetime2(0)  NOT NULL
);
GO

/* ---------------------------------------------------------------- INDEX
   Les index sur ModifiedAt servent à l'extraction incrémentale (filigrane /
   « watermark ») que fera le Copy job de Fabric.                          */
CREATE INDEX IX_FT_ModifiedAt       ON paie.FeuilleTemps (ModifiedAt);
CREATE INDEX IX_FT_Employe_Date     ON paie.FeuilleTemps (EmployeID, DateTravail);
CREATE INDEX IX_FT_Projet           ON paie.FeuilleTemps (ProjetID) INCLUDE (HeuresReg, HeuresSupp);
CREATE INDEX IX_FF_ModifiedAt       ON achat.FactureFournisseur (ModifiedAt);
CREATE INDEX IX_FFL_ModifiedAt      ON achat.FactureFournisseurLigne (ModifiedAt);
CREATE INDEX IX_FFL_Facture         ON achat.FactureFournisseurLigne (FactureFournID);
CREATE INDEX IX_FC_ModifiedAt       ON vente.FactureClient (ModifiedAt);
CREATE INDEX IX_Enc_ModifiedAt      ON vente.Encaissement (ModifiedAt);
CREATE INDEX IX_UE_ModifiedAt       ON equip.UtilisationEquipement (ModifiedAt);
CREATE INDEX IX_BC_ModifiedAt       ON achat.BonCommande (ModifiedAt);
CREATE INDEX IX_Projet_ModifiedAt   ON projet.Projet (ModifiedAt);
GO
PRINT N'Base BorealERP créée. Lance maintenant 02_charger_donnees.sql.';
