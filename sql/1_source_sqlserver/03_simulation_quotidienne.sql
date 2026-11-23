/* =====================================================================
   Script 03 : simulation d'activité quotidienne dans l'ERP
   ---------------------------------------------------------------------
   Pourquoi ? Pour pratiquer le chargement INCRÉMENTAL dans Fabric : chaque
   exécution ajoute une journée de travail (heures, factures, paiements…)
   et modifie des lignes existantes (approbations, paiements) en mettant
   à jour ModifiedAt — exactement ce que le Copy job détecte.

   Utilisation :
       EXEC util.usp_SimulerJournee;           -- avance d'un jour
       EXEC util.usp_SimulerPeriode @NbJours = 7;  -- avance d'une semaine
   Les données d'origine s'arrêtent le 2026-10-22 ; l'horloge démarre là.
   ===================================================================== */
USE BorealERP;
GO
IF OBJECT_ID(N'util.Horloge') IS NULL
BEGIN
    CREATE TABLE util.Horloge (DernierJour date NOT NULL);
    INSERT util.Horloge VALUES ('2026-10-22');
END
GO
CREATE OR ALTER PROCEDURE util.usp_SimulerJournee
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Jour date, @ts datetime2(0), @EstOuvrable bit, @n int;
    SELECT @Jour = DATEADD(day, 1, DernierJour) FROM util.Horloge;
    SET @ts = DATEADD(hour, 17, CAST(@Jour AS datetime2(0)));
    -- 1900-01-01 était un lundi : 0 = lundi … 5 = samedi, 6 = dimanche (indépendant de DATEFIRST)
    SET @EstOuvrable = CASE WHEN DATEDIFF(day, '19000101', @Jour) % 7 < 5 THEN 1 ELSE 0 END;

    BEGIN TRAN;

    /* 1. Projets : démarrage des soumissions arrivées à échéance, fermeture de projets en retard */
    UPDATE projet.Projet
       SET Statut = N'En cours', DateDebutReelle = @Jour, ModifiedAt = @ts
     WHERE UPPER(TRIM(Statut)) = N'SOUMISSION' AND DateDebutPrevue <= @Jour;

    UPDATE projet.Projet
       SET Statut = N'Terminé', DateFinReelle = @Jour, PourcentageAvancement = 100, ModifiedAt = @ts
     WHERE UPPER(TRIM(Statut)) = N'EN COURS'
       AND DateFinPrevue < DATEADD(day, -20, @Jour)
       AND ABS(CHECKSUM(NEWID())) % 100 < 25;

    IF @EstOuvrable = 1
    BEGIN
        /* 2a. Heures de chantier : chacun continue sur son dernier projet actif */
        WITH dernier AS (
            SELECT ft.EmployeID, ft.ProjetID, ft.CodeCoutID,
                   ROW_NUMBER() OVER (PARTITION BY ft.EmployeID ORDER BY ft.DateTravail DESC, ft.FeuilleTempsID DESC) AS rn
            FROM paie.FeuilleTemps ft
            WHERE ft.DateTravail BETWEEN DATEADD(day, -30, @Jour) AND @Jour
              AND ft.ProjetID IS NOT NULL AND ft.IsDeleted = 0
        )
        INSERT paie.FeuilleTemps (EmployeID, DateTravail, ProjetID, CodeCoutID, HeuresReg, HeuresSupp, Statut, Commentaire, CreatedAt, ModifiedAt, IsDeleted)
        SELECT e.EmployeID, @Jour, d.ProjetID, d.CodeCoutID, 8.0,
               CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 20 THEN 2.0 ELSE 0 END,
               N'Soumis', NULL,
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts),
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts), 0
        FROM paie.Employe e
        JOIN ref.Metier m     ON m.MetierID = e.MetierID AND m.Categorie = N'Chantier'
        JOIN dernier d        ON d.EmployeID = e.EmployeID AND d.rn = 1
        JOIN projet.Projet p  ON p.ProjetID = d.ProjetID AND UPPER(TRIM(p.Statut)) = N'EN COURS'
        WHERE e.Statut = N'Actif'
          AND ABS(CHECKSUM(NEWID())) % 100 >= 4;           -- ≈ 4 % d'absences

        /* 2b. Les ouvriers sans projet actif sont réaffectés (la moitié ; les autres sont en mise à pied temporaire) */
        INSERT paie.FeuilleTemps (EmployeID, DateTravail, ProjetID, CodeCoutID, HeuresReg, HeuresSupp, Statut, Commentaire, CreatedAt, ModifiedAt, IsDeleted)
        SELECT e.EmployeID, @Jour, pr.ProjetID, cc.CodeCoutID, 8.0, 0, N'Soumis', N'Nouvelle affectation',
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts),
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts), 0
        FROM paie.Employe e
        JOIN ref.Metier m ON m.MetierID = e.MetierID AND m.Categorie = N'Chantier'
        CROSS APPLY (SELECT TOP (1) p.ProjetID
                     FROM projet.Projet p
                     WHERE p.DivisionID = e.DivisionID AND UPPER(TRIM(p.Statut)) = N'EN COURS'
                     ORDER BY NEWID()) pr
        JOIN ref.CodeCout cc ON cc.CodeCout = CASE m.CodeMetier
                                    WHEN N'CHM' THEN N'06-MO' WHEN N'ELE' THEN N'16-MO' WHEN N'PLO' THEN N'15-MO'
                                    WHEN N'OPM' THEN N'02-MO' WHEN N'CIM' THEN N'03-MO' WHEN N'FER' THEN N'03-MO'
                                    WHEN N'SOU' THEN N'05-MO' ELSE N'01-MO' END
        WHERE e.Statut = N'Actif'
          AND NOT EXISTS (SELECT 1 FROM paie.FeuilleTemps f WHERE f.EmployeID = e.EmployeID AND f.DateTravail = @Jour)
          AND ABS(CHECKSUM(NEWID())) % 100 < 50;

        /* 2c. Personnel de bureau : temps administratif */
        INSERT paie.FeuilleTemps (EmployeID, DateTravail, ProjetID, CodeCoutID, HeuresReg, HeuresSupp, Statut, Commentaire, CreatedAt, ModifiedAt, IsDeleted)
        SELECT e.EmployeID, @Jour, NULL, cc.CodeCoutID, 7.5, 0, N'Soumis', NULL,
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts),
               DATEADD(second, ABS(CHECKSUM(NEWID())) % 7200, @ts), 0
        FROM paie.Employe e
        JOIN ref.Metier m ON m.MetierID = e.MetierID AND m.Categorie = N'Bureau'
        JOIN ref.CodeCout cc ON cc.CodeCout = N'00-ADM'
        WHERE e.Statut = N'Actif' AND ABS(CHECKSUM(NEWID())) % 100 >= 3;

        /* 2d. Utilisation d'équipements */
        INSERT equip.UtilisationEquipement (EquipementID, ProjetID, DateUtilisation, Heures, OperateurID, CreatedAt, ModifiedAt)
        SELECT TOP (40) eq.EquipementID, pr.ProjetID, @Jour, CAST(4 + (ABS(CHECKSUM(NEWID())) % 11) * 0.5 AS decimal(5,2)), NULL, @ts, @ts
        FROM equip.Equipement eq
        CROSS APPLY (SELECT TOP (1) p.ProjetID FROM projet.Projet p
                     WHERE UPPER(TRIM(p.Statut)) = N'EN COURS' AND eq.EquipementID > 0
                     ORDER BY NEWID()) pr
        WHERE eq.Statut = N'Actif'
        ORDER BY NEWID();

        /* 2e. Quelques nouvelles factures fournisseurs (≈ 30 % des projets en cours) */
        CREATE TABLE #nf (Rn int IDENTITY(1,1), ProjetID int, FournisseurID int, CodeCoutID int, Description nvarchar(200),
                          Unite nvarchar(15), PrixUnitaire decimal(14,4), Quantite decimal(12,2), BonCommandeID int, Termes int);
        WITH src AS (
            SELECT l.ProjetID, ff.FournisseurID, l.CodeCoutID, l.Description, l.Unite, l.PrixUnitaire, l.Quantite, ff.BonCommandeID,
                   ROW_NUMBER() OVER (PARTITION BY l.ProjetID ORDER BY NEWID()) AS rn
            FROM achat.FactureFournisseurLigne l
            JOIN achat.FactureFournisseur ff ON ff.FactureFournID = l.FactureFournID
            JOIN projet.Projet p ON p.ProjetID = l.ProjetID AND UPPER(TRIM(p.Statut)) = N'EN COURS'
            WHERE ff.DateFacture >= DATEADD(day, -120, @Jour) AND l.CodeCoutID IS NOT NULL
        )
        INSERT #nf (ProjetID, FournisseurID, CodeCoutID, Description, Unite, PrixUnitaire, Quantite, BonCommandeID, Termes)
        SELECT s.ProjetID, s.FournisseurID, s.CodeCoutID, s.Description, s.Unite, s.PrixUnitaire,
               CAST(s.Quantite * (0.5 + (ABS(CHECKSUM(NEWID())) % 100) / 100.0) AS decimal(12,2)),
               s.BonCommandeID, f.ConditionsPaiement
        FROM src s JOIN achat.Fournisseur f ON f.FournisseurID = s.FournisseurID
        WHERE s.rn = 1 AND ABS(CHECKSUM(NEWID())) % 100 < 30;

        INSERT achat.FactureFournisseur (NoFactureFourn, FournisseurID, BonCommandeID, DateFacture, DateEcheance, DatePaiement,
                                         MontantHT, TPS, TVQ, MontantTTC, Statut, CreatedAt, ModifiedAt)
        SELECT CONCAT(N'INV-', FORMAT(@Jour, 'yyMMdd'), N'-', RIGHT(CONCAT(N'000', Rn), 3)), FournisseurID, BonCommandeID,
               @Jour, DATEADD(day, Termes, @Jour), NULL,
               ROUND(Quantite * PrixUnitaire, 2), ROUND(Quantite * PrixUnitaire * 0.05, 2), ROUND(Quantite * PrixUnitaire * 0.09975, 2),
               ROUND(Quantite * PrixUnitaire, 2) + ROUND(Quantite * PrixUnitaire * 0.05, 2) + ROUND(Quantite * PrixUnitaire * 0.09975, 2),
               N'À payer', @ts, @ts
        FROM #nf;

        INSERT achat.FactureFournisseurLigne (FactureFournID, NoLigne, ProjetID, CodeCoutID, Description, Quantite, Unite, PrixUnitaire, MontantLigne, CreatedAt, ModifiedAt)
        SELECT ff.FactureFournID, 1, n.ProjetID, n.CodeCoutID, n.Description, n.Quantite, n.Unite, n.PrixUnitaire, ROUND(n.Quantite * n.PrixUnitaire, 2), @ts, @ts
        FROM #nf n
        JOIN achat.FactureFournisseur ff
          ON ff.FournisseurID = n.FournisseurID
         AND ff.NoFactureFourn = CONCAT(N'INV-', FORMAT(@Jour, 'yyMMdd'), N'-', RIGHT(CONCAT(N'000', n.Rn), 3));
        DROP TABLE #nf;
    END

    /* 3. Approbation des heures soumises depuis plus de 4 jours (lignes MODIFIÉES → ModifiedAt change) */
    UPDATE paie.FeuilleTemps
       SET Statut = N'Approuvé', ModifiedAt = @ts
     WHERE Statut = N'Soumis' AND IsDeleted = 0 AND DateTravail <= DATEADD(day, -4, @Jour);

    /* 4. Une ou deux erreurs de saisie supprimées logiquement */
    UPDATE TOP (2) paie.FeuilleTemps
       SET IsDeleted = 1, ModifiedAt = @ts
     WHERE DateTravail = DATEADD(day, -1, @Jour) AND Statut = N'Soumis';

    /* 5. Paiement des factures fournisseurs échues (≈ 60 % par jour) */
    UPDATE achat.FactureFournisseur
       SET Statut = N'Payée', DatePaiement = @Jour, ModifiedAt = @ts
     WHERE Statut = N'À payer' AND DateEcheance <= @Jour AND ABS(CHECKSUM(NEWID())) % 100 < 60;

    /* 6. Encaissements clients */
    CREATE TABLE #pay (FactureClientID int, Montant decimal(14,2));
    INSERT #pay (FactureClientID, Montant)
    SELECT fc.FactureClientID, fc.MontantTTC - ISNULL(e.Paye, 0)
    FROM vente.FactureClient fc
    OUTER APPLY (SELECT SUM(x.Montant) AS Paye FROM vente.Encaissement x WHERE x.FactureClientID = fc.FactureClientID) e
    WHERE fc.Statut IN (N'Émise', N'Partiellement payée')
      AND fc.DateEcheance <= DATEADD(day, 10, @Jour)
      AND ABS(CHECKSUM(NEWID())) % 100 < 12;
    INSERT vente.Encaissement (FactureClientID, DateEncaissement, Montant, ModePaiement, NoReference, CreatedAt, ModifiedAt)
    SELECT FactureClientID, @Jour, Montant, N'TEF', CONCAT(N'VIR-', 100000 + ABS(CHECKSUM(NEWID())) % 900000), @ts, @ts
    FROM #pay WHERE Montant > 0;
    UPDATE fc SET Statut = N'Payée', ModifiedAt = @ts
    FROM vente.FactureClient fc JOIN #pay p ON p.FactureClientID = fc.FactureClientID;
    DROP TABLE #pay;

    /* 7. Fin de mois : décomptes progressifs (coût du mois × 1,11) */
    DECLARE @FinMois date = EOMONTH(@Jour);
    WHILE DATEDIFF(day, '19000101', @FinMois) % 7 >= 5 SET @FinMois = DATEADD(day, -1, @FinMois);
    IF @Jour = @FinMois
    BEGIN
        DECLARE @Debut date = DATEFROMPARTS(YEAR(@Jour), MONTH(@Jour), 1);
        WITH cout AS (
            SELECT ft.ProjetID,
                   SUM((ft.HeuresReg + 1.5 * ft.HeuresSupp) * th.TauxHoraire * (1 + pc.TauxChargesSociales)) AS Montant
            FROM paie.FeuilleTemps ft
            JOIN paie.TauxHoraire th ON th.EmployeID = ft.EmployeID AND ft.DateTravail >= th.DateDebut
                                    AND (th.DateFin IS NULL OR ft.DateTravail <= th.DateFin)
            JOIN ref.ParametreCout pc ON pc.Annee = YEAR(ft.DateTravail)
            WHERE ft.DateTravail BETWEEN @Debut AND @Jour AND ft.ProjetID IS NOT NULL AND ft.IsDeleted = 0
            GROUP BY ft.ProjetID
            UNION ALL
            SELECT l.ProjetID, SUM(l.MontantLigne)
            FROM achat.FactureFournisseurLigne l
            JOIN achat.FactureFournisseur ff ON ff.FactureFournID = l.FactureFournID
            WHERE ff.DateFacture BETWEEN @Debut AND @Jour
            GROUP BY l.ProjetID
        ), parProjet AS (
            SELECT c.ProjetID, SUM(c.Montant) * 1.11 AS HT
            FROM cout c JOIN projet.Projet p ON p.ProjetID = c.ProjetID AND UPPER(TRIM(p.Statut)) = N'EN COURS'
            GROUP BY c.ProjetID
        ), base AS (
            SELECT ISNULL(MAX(CAST(RIGHT(NoFacture, 5) AS int)), 0) AS DernierNo
            FROM vente.FactureClient WHERE LEFT(NoFacture, 4) = CONCAT(N'FC', FORMAT(@Jour, 'yy'))
        )
        INSERT vente.FactureClient (NoFacture, ProjetID, ClientID, TypeFacture, NoDecompte, DateFacture, DateEcheance,
                                    MontantHT, Retenue, MontantNet, TPS, TVQ, MontantTTC, Statut, CreatedAt, ModifiedAt)
        SELECT CONCAT(N'FC', FORMAT(@Jour, 'yy'), N'-', RIGHT(CONCAT(N'00000', b.DernierNo + ROW_NUMBER() OVER (ORDER BY pp.ProjetID)), 5)),
               pp.ProjetID, p.ClientID, N'Décompte progressif',
               ISNULL((SELECT MAX(NoDecompte) FROM vente.FactureClient x WHERE x.ProjetID = pp.ProjetID), 0) + 1,
               @Jour, DATEADD(day, c.ConditionsPaiement, @Jour),
               ROUND(pp.HT, 2), ROUND(pp.HT * 0.10, 2), ROUND(pp.HT * 0.90, 2),
               ROUND(pp.HT * 0.90 * 0.05, 2), ROUND(pp.HT * 0.90 * 0.09975, 2),
               ROUND(pp.HT * 0.90, 2) + ROUND(pp.HT * 0.90 * 0.05, 2) + ROUND(pp.HT * 0.90 * 0.09975, 2),
               N'Émise', @ts, @ts
        FROM parProjet pp
        CROSS JOIN base b
        JOIN projet.Projet p ON p.ProjetID = pp.ProjetID
        JOIN vente.Client c  ON c.ClientID = p.ClientID
        WHERE pp.HT > 500;
        SET @n = @@ROWCOUNT;
        PRINT CONCAT(N'   Facturation de fin de mois : ', @n, N' décomptes émis.');
    END

    /* 8. Une fiche client mise à jour de temps en temps */
    IF ABS(CHECKSUM(NEWID())) % 100 < 30
        UPDATE vente.Client
           SET Telephone = CONCAT(N'(819) 555-', RIGHT(CONCAT(N'000', ABS(CHECKSUM(NEWID())) % 10000), 4)), ModifiedAt = @ts
         WHERE ClientID = 1 + ABS(CHECKSUM(NEWID())) % 300;

    UPDATE util.Horloge SET DernierJour = @Jour;
    COMMIT;

    SELECT @Jour AS JourSimule,
           (SELECT COUNT(*) FROM paie.FeuilleTemps WHERE ModifiedAt >= @ts) AS FeuillesTempsModifiees,
           (SELECT COUNT(*) FROM achat.FactureFournisseur WHERE ModifiedAt >= @ts) AS FacturesFournModifiees,
           (SELECT COUNT(*) FROM vente.Encaissement WHERE CreatedAt >= @ts) AS NouveauxEncaissements;
END
GO

CREATE OR ALTER PROCEDURE util.usp_SimulerPeriode @NbJours int = 7
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @i int = 0;
    WHILE @i < @NbJours
    BEGIN
        EXEC util.usp_SimulerJournee;
        SET @i += 1;
    END
END
GO
PRINT N'Procédures de simulation créées. Exemple : EXEC util.usp_SimulerJournee;';
