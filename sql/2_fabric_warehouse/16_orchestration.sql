/* =====================================================================
   Script 16 : procédure d'orchestration
   ---------------------------------------------------------------------
   Une seule procédure enchaîne stg → mdm → dw → gold avec journalisation.
   Dans le pipeline Fabric, tu peux :
     • soit appeler cette procédure (1 activité « Procédure stockée »),
     • soit appeler stg/mdm/dw/gold séparément (4 activités enchaînées) —
       plus pédagogique : on voit chaque couche réussir ou échouer.
   ===================================================================== */
CREATE OR ALTER PROCEDURE audit.usp_executer_chargement_complet
AS
BEGIN
    DECLARE @execution_id varchar(40) = CONVERT(varchar(40), NEWID());
    DECLARE @debut datetime2(6) = SYSDATETIME();
    DECLARE @etape varchar(100) = 'démarrage';
    BEGIN TRY
        SET @etape = 'stg';  EXEC stg.usp_charger_tout  @execution_id;
        SET @etape = 'mdm';  EXEC mdm.usp_charger_tout  @execution_id;
        SET @etape = 'dw';   EXEC dw.usp_charger_tout   @execution_id;
        SET @etape = 'gold'; EXEC gold.usp_charger_tout @execution_id;
        EXEC audit.usp_journaliser @execution_id, 'CHARGEMENT COMPLET', @debut, NULL, 'Succès';
    END TRY
    BEGIN CATCH
        DECLARE @msg varchar(4000) = CONCAT('Échec à l''étape ', @etape, ' : ', ERROR_MESSAGE());
        EXEC audit.usp_journaliser @execution_id, 'CHARGEMENT COMPLET', @debut, NULL, 'Échec', @msg;
        THROW;   -- relance l'erreur : l'activité du pipeline passe en échec (et peut déclencher une alerte)
    END CATCH
    SELECT etape, statut, DATEDIFF(millisecond, debut, fin) / 1000.0 AS secondes, message
    FROM audit.journal_execution WHERE execution_id = @execution_id ORDER BY debut;
END
GO

/* Premier chargement (ou rechargement manuel) :
EXEC audit.usp_executer_chargement_complet;

Historique :
SELECT TOP 50 * FROM audit.journal_execution ORDER BY debut DESC;
*/
