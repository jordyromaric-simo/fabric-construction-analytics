# -*- coding: utf-8 -*-
"""Données de référence pour Construction Boréal inc. (fictif)."""
import datetime as dt

TODAY = dt.date(2026, 10, 22)
START = dt.date(2019, 1, 1)

DIVISIONS = [
    (1, 'RES', 'Résidentiel'),
    (2, 'COM', 'Commercial'),
    (3, 'INS', 'Institutionnel'),
    (4, 'IND', 'Industriel'),
    (5, 'GEN', 'Génie civil'),
    (6, 'ADM', 'Administration / Siège social'),
]
DIV_CODE = {d[0]: d[1] for d in DIVISIONS}

REGIONS = [
    (1, 'Capitale-Nationale'), (2, 'Montréal'), (3, 'Laval'), (4, 'Montérégie'),
    (5, 'Mauricie'), (6, 'Centre-du-Québec'), (7, 'Estrie'), (8, 'Lanaudière'),
    (9, 'Chaudière-Appalaches'),
]

# VilleID, Nom, RegionID, FSA possibles, indicatifs, poids projets
VILLES = [
    (1, 'Québec', 1, ['G1K', 'G1R', 'G1S', 'G1V', 'G2C', 'G2E', 'G1M'], ['418', '581'], 14),
    (2, 'Lévis', 9, ['G6V', 'G6W', 'G6X', 'G6Z'], ['418', '581'], 4),
    (3, 'Montréal', 2, ['H1N', 'H2J', 'H3B', 'H4N', 'H1B', 'H2X'], ['514', '438'], 13),
    (4, 'Laval', 3, ['H7L', 'H7N', 'H7T', 'H7V'], ['450', '579'], 6),
    (5, 'Longueuil', 4, ['J4G', 'J4K', 'J4N'], ['450', '579'], 5),
    (6, 'Saint-Hyacinthe', 4, ['J2S', 'J2T'], ['450', '579'], 3),
    (7, 'Trois-Rivières', 5, ['G8T', 'G8Y', 'G8Z', 'G9A', 'G9B'], ['819', '873'], 8),
    (8, 'Shawinigan', 5, ['G9N', 'G9P', 'G9T'], ['819', '873'], 3),
    (9, 'Drummondville', 6, ['J2A', 'J2B', 'J2C'], ['819', '873'], 6),
    (10, 'Victoriaville', 6, ['G6P', 'G6S', 'G6T'], ['819', '873'], 4),
    (11, 'Bécancour', 6, ['G9H'], ['819', '873'], 2),
    (12, 'Sherbrooke', 7, ['J1E', 'J1G', 'J1H', 'J1J', 'J1L'], ['819', '873'], 9),
    (13, 'Magog', 7, ['J1X'], ['819', '873'], 2),
    (14, 'Granby', 4, ['J2G', 'J2H', 'J2J'], ['450', '579'], 3),
    (15, 'Joliette', 8, ['J6E'], ['450', '579'], 3),
    (16, 'Terrebonne', 8, ['J6W', 'J6X', 'J6Y'], ['450', '579'], 4),
    (17, 'Saint-Georges', 9, ['G5Y', 'G5Z'], ['418', '581'], 2),
    (18, 'Thetford Mines', 9, ['G6G', 'G6H'], ['418', '581'], 1),
    (19, 'Saint-Jean-sur-Richelieu', 4, ['J2W', 'J3A', 'J3B'], ['450', '579'], 3),
    (20, 'Repentigny', 8, ['J5Y', 'J6A'], ['450', '579'], 2),
]

# MetierID, Code, Nom, Categorie, taux 2019 min, max, syndiqué
METIERS = [
    (1, 'CHM', 'Charpentier-menuisier', 'Chantier', 38.0, 44.5, 1),
    (2, 'ELE', 'Électricien', 'Chantier', 40.0, 46.5, 1),
    (3, 'PLO', 'Plombier / tuyauteur', 'Chantier', 40.0, 46.5, 1),
    (4, 'OPM', 'Opérateur de machinerie lourde', 'Chantier', 37.5, 43.0, 1),
    (5, 'MAN', 'Manœuvre spécialisé', 'Chantier', 30.0, 34.5, 1),
    (6, 'CIM', 'Cimentier-applicateur', 'Chantier', 37.0, 42.0, 1),
    (7, 'FER', 'Ferrailleur', 'Chantier', 38.0, 43.0, 1),
    (8, 'GRU', 'Grutier', 'Chantier', 42.0, 47.5, 1),
    (9, 'SOU', 'Soudeur', 'Chantier', 39.0, 44.5, 1),
    (10, 'CON', 'Contremaître', 'Chantier', 46.0, 54.0, 1),
    (11, 'SUR', 'Surintendant', 'Chantier', 52.0, 62.0, 0),
    (12, 'CPJ', 'Chargé de projet', 'Bureau', 44.0, 60.0, 0),
    (13, 'EST', 'Estimateur', 'Bureau', 38.0, 50.0, 0),
    (14, 'TEC', 'Technicien en génie civil', 'Bureau', 29.0, 37.0, 0),
    (15, 'DIR', 'Directeur de division', 'Bureau', 62.0, 80.0, 0),
    (16, 'ACH', 'Acheteur', 'Bureau', 28.0, 36.0, 0),
    (17, 'CPT', 'Technicien comptable', 'Bureau', 25.0, 32.0, 0),
    (18, 'CTL', 'Contrôleur financier', 'Bureau', 55.0, 68.0, 0),
    (19, 'RHC', 'Conseiller ressources humaines', 'Bureau', 33.0, 42.0, 0),
]
MET = {m[1]: m for m in METIERS}

# Sections (style MasterFormat simplifié) + fenêtre d'activité dans la vie du projet
SECTIONS = [
    ('01', 'Conditions générales', (0.00, 1.00)),
    ('02', 'Terrassement et excavation', (0.00, 0.28)),
    ('03', 'Béton', (0.05, 0.50)),
    ('04', 'Maçonnerie', (0.35, 0.75)),
    ('05', 'Métaux', (0.18, 0.58)),
    ('06', 'Bois et plastiques', (0.22, 0.72)),
    ('07', 'Isolation et étanchéité', (0.42, 0.82)),
    ('08', 'Portes et fenêtres', (0.52, 0.88)),
    ('09', 'Finitions', (0.62, 1.00)),
    ('15', 'Mécanique (plomberie, CVAC)', (0.28, 0.96)),
    ('16', 'Électricité', (0.28, 0.96)),
    ('32', 'Aménagements extérieurs et pavage', (0.78, 1.00)),
]
SEC_WIN = {s[0]: s[2] for s in SECTIONS}
TYPES_COUT = [('MO', "Main-d'œuvre"), ('MAT', 'Matériaux'), ('ST', 'Sous-traitance'), ('EQ', 'Équipement')]

def build_codes_cout():
    rows = [(1, '00-ADM', 'Administration et frais généraux (non imputable)', 'Frais généraux', '00', 'Administration')]
    i = 2
    for sec, nom, _ in SECTIONS:
        for t, tnom in TYPES_COUT:
            rows.append((i, f'{sec}-{t}', f'{nom} — {tnom.lower()}', tnom, sec, nom))
            i += 1
    return rows
CODES_COUT = build_codes_cout()
CODE_ID = {c[1]: c[0] for c in CODES_COUT}

# Répartition du coût par type selon la division
MIX_TYPE = {
    'RES': {'MO': .28, 'MAT': .33, 'ST': .30, 'EQ': .03, 'CG': .06},
    'COM': {'MO': .18, 'MAT': .22, 'ST': .48, 'EQ': .04, 'CG': .08},
    'INS': {'MO': .16, 'MAT': .20, 'ST': .52, 'EQ': .03, 'CG': .09},
    'IND': {'MO': .22, 'MAT': .25, 'ST': .40, 'EQ': .06, 'CG': .07},
    'GEN': {'MO': .20, 'MAT': .30, 'ST': .20, 'EQ': .25, 'CG': .05},
}
# Poids des sections par division (hors 01)
SEC_W = {
    'RES': {'02': .06, '03': .12, '04': .04, '06': .26, '07': .10, '08': .10, '09': .16, '15': .08, '16': .07, '32': .01},
    'COM': {'02': .05, '03': .14, '04': .05, '05': .10, '06': .06, '07': .08, '08': .08, '09': .14, '15': .15, '16': .12, '32': .03},
    'INS': {'02': .05, '03': .15, '04': .07, '05': .09, '06': .05, '07': .08, '08': .08, '09': .13, '15': .17, '16': .11, '32': .02},
    'IND': {'02': .07, '03': .18, '05': .20, '06': .03, '07': .07, '08': .04, '09': .05, '15': .18, '16': .15, '32': .03},
    'GEN': {'02': .45, '03': .18, '05': .05, '15': .07, '16': .05, '32': .20},
}

# Métiers de chantier par division
MIX_METIER = {
    'RES': {'CHM': .45, 'MAN': .15, 'PLO': .05, 'ELE': .05, 'CIM': .06, 'CON': .10, 'SUR': .04, 'OPM': .05, 'SOU': .02, 'FER': .03},
    'COM': {'CHM': .30, 'MAN': .14, 'ELE': .08, 'PLO': .06, 'CIM': .10, 'FER': .06, 'SOU': .06, 'GRU': .03, 'OPM': .04, 'CON': .09, 'SUR': .04},
    'INS': {'CHM': .28, 'MAN': .14, 'ELE': .08, 'PLO': .08, 'CIM': .10, 'FER': .07, 'SOU': .06, 'GRU': .04, 'OPM': .03, 'CON': .08, 'SUR': .04},
    'IND': {'CHM': .18, 'MAN': .14, 'SOU': .14, 'ELE': .10, 'PLO': .10, 'CIM': .08, 'FER': .06, 'GRU': .06, 'OPM': .04, 'CON': .07, 'SUR': .03},
    'GEN': {'OPM': .35, 'MAN': .25, 'CIM': .08, 'FER': .04, 'CHM': .06, 'SOU': .03, 'CON': .12, 'SUR': .05, 'GRU': .02},
}
# Sections préférées par métier (pour les codes de coût des heures)
METIER_SEC = {
    'CHM': ['06', '03', '09', '08'], 'ELE': ['16'], 'PLO': ['15'], 'OPM': ['02', '32', '03'],
    'MAN': ['02', '03', '06', '09', '32', '01'], 'CIM': ['03', '04'], 'FER': ['03', '05'], 'GRU': ['01', '05'],
    'SOU': ['05', '15'], 'CON': ['01'], 'SUR': ['01'],
}

NOMS = ("Tremblay Gagnon Roy Côté Bouchard Gauthier Morin Lavoie Fortin Gagné Ouellet Pelletier Bélanger Lévesque "
        "Bergeron Leblanc Paquette Girard Simard Boucher Caron Beaulieu Cloutier Dubé Poirier Fournier Lapointe "
        "Leclerc Lefebvre Poulin Thibault St-Pierre Nadeau Martin Landry Martel Bédard Grenier Lessard Bernier "
        "Richard Michaud Hébert Desjardins Couture Turcotte Lachance Parent Blais Gosselin Savard Proulx Beaudoin "
        "Demers Perreault Boudreau Lemieux Cyr Perron Dufour Dion Mercier Bolduc Bérubé Boisvert Langlois Ménard "
        "Thériault Lacroix Dumont Vallée Labbé Charron Gingras Rousseau Champagne Sirois Brassard Vachon Allard "
        "Marcoux Plante Labrecque Paradis Moreau Lebel Rioux Dupuis Larouche Gilbert Racine Laflamme Lamontagne "
        "Beauchemin Trudel Gervais Bourassa Lord Veilleux Doyon Chabot Audet Fecteau Pouliot Lemay").split()
NOMS_DIV = "Nguyen Diallo Haddad Mendoza Kouassi Benali Petrovic Silva Traoré Joseph Pierre-Louis Hernandez Chen Ndiaye Rahman Kamga Mbarga Fotso Saint-Fleur Bouzid".split()
PRENOMS_H = ("Jean Marc Pierre Luc Martin Simon Mathieu Alexandre Maxime Olivier Jonathan Kevin Patrick Éric Stéphane "
             "Sébastien François Guillaume Philippe Nicolas David Benoît Michel Daniel Steve Dave Jérémie Samuel Gabriel "
             "William Félix Antoine Vincent Yannick Carl Mohamed Karim Moussa Carlos Diego Thanh Jean-François "
             "Marc-André Pier-Luc Jean-Philippe Dominic Frédéric Hugo Louis Raphaël Christian Sylvain Mario Denis Réjean").split()
PRENOMS_F = ("Marie Julie Isabelle Nathalie Sophie Catherine Mélanie Annie Karine Valérie Émilie Audrey Geneviève "
             "Caroline Amélie Fatou Aïcha Laura Josée Chantal Marie-Ève Stéphanie Andréanne Kim Vanessa").split()

RUES = ["rue Principale", "boulevard Industriel", "rue Notre-Dame", "rue Saint-Jean", "boulevard Laurier",
        "rue King Ouest", "avenue du Parc", "rue de l'Église", "rue Commerciale", "chemin du Lac", "rang Saint-Joseph",
        "boulevard des Entreprises", "rue Saint-Laurent", "rue Wellington", "boulevard Saint-Joseph", "rue des Érables",
        "avenue Royale", "rue du Pont", "boulevard Lebourgneuf", "rue de la Gare", "montée Masson", "rue Racine"]

# Équipement : catégorie, modèles, taux interne $/h, divisions où il travaille
EQUIP_CAT = [
    ('Excavatrice', ['Caterpillar 320', 'Komatsu PC210', 'John Deere 210G', 'Volvo EC220E'], 145, ['GEN', 'IND', 'COM', 'INS'], 16),
    ('Mini-excavatrice', ['Kubota KX040', 'Takeuchi TB240', 'Bobcat E35'], 75, ['RES', 'COM', 'GEN'], 10),
    ('Chargeuse sur roues', ['Caterpillar 950M', 'Volvo L90H', 'John Deere 644L'], 130, ['GEN', 'IND'], 8),
    ('Rétrocaveuse', ['JCB 3CX', 'Caterpillar 420', 'Case 580SN'], 85, ['GEN', 'RES', 'COM'], 9),
    ('Bouteur', ['Caterpillar D6', 'Komatsu D61'], 160, ['GEN'], 5),
    ('Camion 10 roues', ['Mack Granite', 'Kenworth T880', 'Western Star 4700'], 110, ['GEN', 'IND'], 14),
    ('Grue mobile', ['Liebherr LTM 1060', 'Grove GMK3060'], 260, ['COM', 'INS', 'IND'], 3),
    ('Nacelle articulée', ['Genie Z-45', 'JLG 600AJ', 'Skyjack SJ45'], 45, ['COM', 'INS', 'IND', 'RES'], 12),
    ('Chariot télescopique', ['JLG 1055', 'Genie GTH-1056', 'Manitou MT1440'], 70, ['COM', 'INS', 'IND', 'RES'], 10),
    ('Compacteur', ['Bomag BW 211', 'Dynapac CA2500'], 70, ['GEN'], 6),
    ('Génératrice', ['Honda EU7000', 'Generac XD5000'], 25, ['RES', 'COM', 'INS', 'IND', 'GEN'], 8),
    ('Camionnette de service', ['Ford F-250', 'RAM 2500', 'Chevrolet Silverado 2500'], 28, ['RES', 'COM', 'INS', 'IND', 'GEN'], 14),
]

TPS, TVQ = 0.05, 0.09975
