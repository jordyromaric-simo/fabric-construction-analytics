/* =====================================================================
   Script 13 : MASTER DATA (mdm) — « golden records »
   ---------------------------------------------------------------------
   Problème réel : le même client existe plusieurs fois dans l'ERP
   (fiche recréée par un commis : « V. de Granby », « VILLE DE GRANBY »)
   et une 3e fois dans le CRM, avec un autre nom et d'autres infos.

   Solution en 3 temps :
     1. APPARIEMENT : relier chaque fiche source à une fiche maîtresse
        - règle 1 : même NEQ (numéro d'entreprise du Québec)
        - règle 2 : à défaut, même clé de nom normalisée (stg.cle_nom)
     2. TABLE DE CORRESPONDANCE (xref) : source + id source → id maître
        (MERGE : on met à jour sans tout effacer — historique conservé)
     3. SURVIE (survivorship) : on construit UNE fiche par client en
        prenant la meilleure valeur de chaque attribut.
   L'id maître = l'id ERP de la fiche la plus ancienne → stable dans le temps.
   ===================================================================== */

IF OBJECT_ID('mdm.client_xref') IS NULL
CREATE TABLE mdm.client_xref (
    source_systeme   varchar(10)  NOT NULL,   -- ERP / CRM
    source_id        varchar(20)  NOT NULL,
    client_maitre_id int          NULL,       -- NULL = prospect CRM sans fiche ERP
    regle            varchar(30)  NOT NULL,
    date_maj         datetime2(6) NOT NULL
);
GO
IF OBJECT_ID('mdm.client') IS NULL
CREATE TABLE mdm.client (
    client_maitre_id        int           NOT NULL,
    no_client               varchar(10)   NOT NULL,
    nom_client              varchar(200)  NOT NULL,
    type_client             varchar(10)   NULL,
    segment                 varchar(30)   NULL,
    neq                     varchar(10)   NULL,
    adresse                 varchar(200)  NULL,
    ville_id                int           NULL,
    code_postal             varchar(7)    NULL,
    telephone               varchar(14)   NULL,
    courriel                varchar(150)  NULL,
    conditions_paiement     int           NULL,
    limite_credit           decimal(14,2) NULL,
    responsable_compte      varchar(100)  NULL,   -- vient du CRM
    score_satisfaction      int           NULL,   -- vient du CRM
    date_derniere_activite  date          NULL,   -- vient du CRM
    nb_fiches_erp           int           NOT NULL,
    nb_fiches_crm           int           NOT NULL,
    date_maj                datetime2(6)  NOT NULL
);
GO
IF OBJECT_ID('mdm.fournisseur_xref') IS NULL
CREATE TABLE mdm.fournisseur_xref (
    fournisseur_id         int          NOT NULL,
    fournisseur_maitre_id  int          NOT NULL,
    regle                  varchar(30)  NOT NULL,
    date_maj               datetime2(6) NOT NULL
);
GO
IF OBJECT_ID('mdm.fournisseur') IS NULL
CREATE TABLE mdm.fournisseur (
    fournisseur_maitre_id  int          NOT NULL,
    no_fournisseur         varchar(10)  NOT NULL,
    nom_fournisseur        varchar(200) NOT NULL,
    categorie              varchar(30)  NULL,
    code_section           varchar(2)   NULL,
    neq                    varchar(10)  NULL,
    ville_id               int          NULL,
    telephone              varchar(14)  NULL,
    courriel               varchar(150) NULL,
    conditions_paiement    int          NULL,
    nb_fiches              int          NOT NULL,
    date_maj               datetime2(6) NOT NULL
);
GO

/* ------------------------------------------------------------------ CLIENTS */
CREATE OR ALTER PROCEDURE mdm.usp_charger_client
AS
BEGIN
    /* 1a. Appariement des fiches ERP */
    DROP TABLE IF EXISTS mdm.wrk_client_map;
    CREATE TABLE mdm.wrk_client_map AS
    SELECT c.client_id,
           CAST(COALESCE(n.maitre_neq, k.maitre_nom) AS int) AS client_maitre_id,
           CAST(CASE WHEN COALESCE(n.maitre_neq, k.maitre_nom) = c.client_id THEN 'Fiche maîtresse'
                     WHEN n.maitre_neq IS NOT NULL THEN 'NEQ identique'
                     ELSE 'Nom normalisé' END AS varchar(30)) AS regle
    FROM stg.client c
    LEFT JOIN (SELECT neq, MIN(client_id) AS maitre_neq FROM stg.client WHERE neq IS NOT NULL GROUP BY neq) n
           ON n.neq = c.neq
    LEFT JOIN (SELECT x.cle_nom, MIN(COALESCE(nn.maitre_neq, x.client_id)) AS maitre_nom
               FROM stg.client x
               LEFT JOIN (SELECT neq, MIN(client_id) AS maitre_neq FROM stg.client WHERE neq IS NOT NULL GROUP BY neq) nn
                      ON nn.neq = x.neq
               GROUP BY x.cle_nom) k
           ON k.cle_nom = c.cle_nom;

    /* 1b. Appariement des fiches CRM sur les fiches maîtresses */
    DROP TABLE IF EXISTS mdm.wrk_crm_map;
    CREATE TABLE mdm.wrk_crm_map AS
    SELECT r.crm_id,
           CAST(COALESCE(vn.client_maitre_id, vk.client_maitre_id) AS int) AS client_maitre_id,
           CAST(CASE WHEN vn.client_maitre_id IS NOT NULL THEN 'NEQ identique'
                     WHEN vk.client_maitre_id IS NOT NULL THEN 'Nom normalisé'
                     ELSE 'Aucune correspondance' END AS varchar(30)) AS regle
    FROM stg.crm_compagnie r
    LEFT JOIN (SELECT c.neq, MIN(m.client_maitre_id) AS client_maitre_id
               FROM stg.client c JOIN mdm.wrk_client_map m ON m.client_id = c.client_id
               WHERE c.neq IS NOT NULL GROUP BY c.neq) vn ON vn.neq = r.neq
    LEFT JOIN (SELECT c.cle_nom, MIN(m.client_maitre_id) AS client_maitre_id
               FROM stg.client c JOIN mdm.wrk_client_map m ON m.client_id = c.client_id
               GROUP BY c.cle_nom) vk ON vk.cle_nom = r.cle_nom;

    /* 2. Table de correspondance : MERGE = insère les nouveaux, met à jour les changements */
    MERGE INTO mdm.client_xref AS cible
    USING (SELECT 'ERP' AS source_systeme, CAST(client_id AS varchar(20)) AS source_id, client_maitre_id, regle FROM mdm.wrk_client_map
           UNION ALL
           SELECT 'CRM', CAST(crm_id AS varchar(20)), client_maitre_id, regle FROM mdm.wrk_crm_map) AS src
       ON cible.source_systeme = src.source_systeme AND cible.source_id = src.source_id
    WHEN MATCHED AND (ISNULL(cible.client_maitre_id, -1) <> ISNULL(src.client_maitre_id, -1) OR cible.regle <> src.regle) THEN
        UPDATE SET client_maitre_id = src.client_maitre_id, regle = src.regle, date_maj = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (source_systeme, source_id, client_maitre_id, regle, date_maj)
        VALUES (src.source_systeme, src.source_id, src.client_maitre_id, src.regle, SYSDATETIME());

    /* 3. Fiche maîtresse : règles de survie
          - identité (nom, type, segment, adresse, conditions) : fiche ERP la plus ancienne
          - téléphone, courriel, code postal : valeur non vide la plus RÉCENTE parmi les fiches ERP
          - responsable, satisfaction : fiche CRM la plus récemment active                  */
    MERGE INTO mdm.client AS cible
    USING (
        SELECT m.client_id AS client_maitre_id, m.no_client, m.nom_client, m.type_client, m.segment,
               g.neq, m.adresse, m.ville_id, cp.code_postal, tel.telephone, crl.courriel,
               m.conditions_paiement, m.limite_credit,
               crm.responsable_compte, crm.score_satisfaction, crm.date_derniere_activite,
               g.nb_fiches_erp, ISNULL(crm.nb_fiches_crm, 0) AS nb_fiches_crm
        FROM stg.client m
        JOIN (SELECT map.client_maitre_id, MAX(c.neq) AS neq, COUNT(*) AS nb_fiches_erp
              FROM mdm.wrk_client_map map JOIN stg.client c ON c.client_id = map.client_id
              GROUP BY map.client_maitre_id) g ON g.client_maitre_id = m.client_id
        LEFT JOIN (SELECT map.client_maitre_id, c.telephone,
                          ROW_NUMBER() OVER (PARTITION BY map.client_maitre_id ORDER BY c.modified_at DESC) AS rn
                   FROM mdm.wrk_client_map map JOIN stg.client c ON c.client_id = map.client_id
                   WHERE c.telephone IS NOT NULL) tel ON tel.client_maitre_id = m.client_id AND tel.rn = 1
        LEFT JOIN (SELECT map.client_maitre_id, c.courriel,
                          ROW_NUMBER() OVER (PARTITION BY map.client_maitre_id ORDER BY c.modified_at DESC) AS rn
                   FROM mdm.wrk_client_map map JOIN stg.client c ON c.client_id = map.client_id
                   WHERE c.courriel IS NOT NULL) crl ON crl.client_maitre_id = m.client_id AND crl.rn = 1
        LEFT JOIN (SELECT map.client_maitre_id, c.code_postal,
                          ROW_NUMBER() OVER (PARTITION BY map.client_maitre_id ORDER BY c.modified_at DESC) AS rn
                   FROM mdm.wrk_client_map map JOIN stg.client c ON c.client_id = map.client_id
                   WHERE c.code_postal IS NOT NULL) cp ON cp.client_maitre_id = m.client_id AND cp.rn = 1
        LEFT JOIN (SELECT x.client_maitre_id, r.responsable_compte, r.score_satisfaction, r.date_derniere_activite,
                          COUNT(*) OVER (PARTITION BY x.client_maitre_id) AS nb_fiches_crm,
                          ROW_NUMBER() OVER (PARTITION BY x.client_maitre_id
                                             ORDER BY CASE WHEN r.score_satisfaction IS NULL THEN 1 ELSE 0 END, r.date_derniere_activite DESC) AS rn
                   FROM mdm.wrk_crm_map x JOIN stg.crm_compagnie r ON r.crm_id = x.crm_id
                   WHERE x.client_maitre_id IS NOT NULL) crm ON crm.client_maitre_id = m.client_id AND crm.rn = 1
    ) AS src
       ON cible.client_maitre_id = src.client_maitre_id
    WHEN MATCHED THEN UPDATE SET
        no_client = src.no_client, nom_client = src.nom_client, type_client = src.type_client, segment = src.segment,
        neq = src.neq, adresse = src.adresse, ville_id = src.ville_id, code_postal = src.code_postal,
        telephone = src.telephone, courriel = src.courriel, conditions_paiement = src.conditions_paiement,
        limite_credit = src.limite_credit, responsable_compte = src.responsable_compte,
        score_satisfaction = src.score_satisfaction, date_derniere_activite = src.date_derniere_activite,
        nb_fiches_erp = src.nb_fiches_erp, nb_fiches_crm = src.nb_fiches_crm, date_maj = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (client_maitre_id, no_client, nom_client, type_client, segment, neq, adresse, ville_id, code_postal, telephone,
                courriel, conditions_paiement, limite_credit, responsable_compte, score_satisfaction, date_derniere_activite,
                nb_fiches_erp, nb_fiches_crm, date_maj)
        VALUES (src.client_maitre_id, src.no_client, src.nom_client, src.type_client, src.segment, src.neq, src.adresse, src.ville_id,
                src.code_postal, src.telephone, src.courriel, src.conditions_paiement, src.limite_credit, src.responsable_compte,
                src.score_satisfaction, src.date_derniere_activite, src.nb_fiches_erp, src.nb_fiches_crm, SYSDATETIME());

    DROP TABLE IF EXISTS mdm.wrk_crm_map;
END
GO

/* ------------------------------------------------------------------ FOURNISSEURS (même logique, sans CRM) */
CREATE OR ALTER PROCEDURE mdm.usp_charger_fournisseur
AS
BEGIN
    DROP TABLE IF EXISTS mdm.wrk_fourn_map;
    CREATE TABLE mdm.wrk_fourn_map AS
    SELECT f.fournisseur_id,
           CAST(COALESCE(n.maitre_neq, k.maitre_nom) AS int) AS fournisseur_maitre_id,
           CAST(CASE WHEN COALESCE(n.maitre_neq, k.maitre_nom) = f.fournisseur_id THEN 'Fiche maîtresse'
                     WHEN n.maitre_neq IS NOT NULL THEN 'NEQ identique'
                     ELSE 'Nom normalisé' END AS varchar(30)) AS regle
    FROM stg.fournisseur f
    LEFT JOIN (SELECT neq, MIN(fournisseur_id) AS maitre_neq FROM stg.fournisseur WHERE neq IS NOT NULL GROUP BY neq) n
           ON n.neq = f.neq
    LEFT JOIN (SELECT x.cle_nom, MIN(COALESCE(nn.maitre_neq, x.fournisseur_id)) AS maitre_nom
               FROM stg.fournisseur x
               LEFT JOIN (SELECT neq, MIN(fournisseur_id) AS maitre_neq FROM stg.fournisseur WHERE neq IS NOT NULL GROUP BY neq) nn
                      ON nn.neq = x.neq
               GROUP BY x.cle_nom) k
           ON k.cle_nom = f.cle_nom;

    MERGE INTO mdm.fournisseur_xref AS cible
    USING mdm.wrk_fourn_map AS src
       ON cible.fournisseur_id = src.fournisseur_id
    WHEN MATCHED AND (cible.fournisseur_maitre_id <> src.fournisseur_maitre_id OR cible.regle <> src.regle) THEN
        UPDATE SET fournisseur_maitre_id = src.fournisseur_maitre_id, regle = src.regle, date_maj = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (fournisseur_id, fournisseur_maitre_id, regle, date_maj)
        VALUES (src.fournisseur_id, src.fournisseur_maitre_id, src.regle, SYSDATETIME());

    MERGE INTO mdm.fournisseur AS cible
    USING (
        SELECT m.fournisseur_id AS fournisseur_maitre_id, m.no_fournisseur, m.nom_fournisseur, m.categorie, m.code_section,
               g.neq, m.ville_id, tel.telephone, m.courriel, m.conditions_paiement, g.nb_fiches
        FROM stg.fournisseur m
        JOIN (SELECT map.fournisseur_maitre_id, MAX(f.neq) AS neq, COUNT(*) AS nb_fiches
              FROM mdm.wrk_fourn_map map JOIN stg.fournisseur f ON f.fournisseur_id = map.fournisseur_id
              GROUP BY map.fournisseur_maitre_id) g ON g.fournisseur_maitre_id = m.fournisseur_id
        LEFT JOIN (SELECT map.fournisseur_maitre_id, f.telephone,
                          ROW_NUMBER() OVER (PARTITION BY map.fournisseur_maitre_id ORDER BY f.modified_at DESC) AS rn
                   FROM mdm.wrk_fourn_map map JOIN stg.fournisseur f ON f.fournisseur_id = map.fournisseur_id
                   WHERE f.telephone IS NOT NULL) tel ON tel.fournisseur_maitre_id = m.fournisseur_id AND tel.rn = 1
    ) AS src
       ON cible.fournisseur_maitre_id = src.fournisseur_maitre_id
    WHEN MATCHED THEN UPDATE SET
        no_fournisseur = src.no_fournisseur, nom_fournisseur = src.nom_fournisseur, categorie = src.categorie,
        code_section = src.code_section, neq = src.neq, ville_id = src.ville_id, telephone = src.telephone,
        courriel = src.courriel, conditions_paiement = src.conditions_paiement, nb_fiches = src.nb_fiches, date_maj = SYSDATETIME()
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (fournisseur_maitre_id, no_fournisseur, nom_fournisseur, categorie, code_section, neq, ville_id, telephone,
                courriel, conditions_paiement, nb_fiches, date_maj)
        VALUES (src.fournisseur_maitre_id, src.no_fournisseur, src.nom_fournisseur, src.categorie, src.code_section, src.neq,
                src.ville_id, src.telephone, src.courriel, src.conditions_paiement, src.nb_fiches, SYSDATETIME());
END
GO

CREATE OR ALTER PROCEDURE mdm.usp_charger_tout @execution_id varchar(40)
AS
BEGIN
    DECLARE @t datetime2(6);
    SET @t = SYSDATETIME(); EXEC mdm.usp_charger_client;      EXEC audit.usp_journaliser @execution_id, 'mdm.client', @t;
    SET @t = SYSDATETIME(); EXEC mdm.usp_charger_fournisseur; EXEC audit.usp_journaliser @execution_id, 'mdm.fournisseur', @t;
END
GO

/* Pour voir le travail du MDM :
SELECT regle, COUNT(*) FROM mdm.client_xref GROUP BY regle;
SELECT c.nom_client AS fiche_source, m.nom_client AS fiche_maitresse, x.regle
FROM mdm.client_xref x JOIN stg.client c ON CAST(c.client_id AS varchar(20)) = x.source_id
JOIN mdm.client m ON m.client_maitre_id = x.client_maitre_id
WHERE x.source_systeme = 'ERP' AND x.regle <> 'Fiche maîtresse';
*/
