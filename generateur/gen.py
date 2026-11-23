# -*- coding: utf-8 -*-
"""Générateur de données réalistes — Construction Boréal inc. (entreprise fictive)."""
import datetime as dt, math, random, os, sys, csv, unicodedata, heapq
from collections import defaultdict
import numpy as np
from scipy.stats import beta as beta_dist
sys.path.insert(0, os.path.dirname(__file__))
from ref import *

R = random.Random(20261023)
NP = np.random.default_rng(20261023)
OUT = sys.argv[1] if len(sys.argv) > 1 else '.'

D = dt.date
def d2s(d): return d.isoformat() if d else ''
def ts(d, h=None, m=None):
    if d is None: return ''
    h = R.randint(7, 17) if h is None else h
    m = R.randint(0, 59) if m is None else m
    return f'{d.isoformat()} {h:02d}:{m:02d}:{R.randint(0,59):02d}'
def strip_acc(s): return ''.join(c for c in unicodedata.normalize('NFD', s) if unicodedata.category(c) != 'Mn')
def slug(s): return ''.join(ch for ch in strip_acc(s).lower() if ch.isalnum())[:22]
def wchoice(d):
    k = list(d.keys()); w = list(d.values()); return R.choices(k, w)[0]
def zipf_pick(lst, a=1.1):
    w = [1 / (i + 1) ** a for i in range(len(lst))]
    return R.choices(lst, w)[0]

# ------------------------------------------------------------------ calendrier
def easter(y):
    a = y % 19; b = y // 100; c = y % 100; d = b // 4; e = b % 4; f = (b + 8) // 25; g = (b - f + 1) // 3
    h = (19 * a + b - d - g + 15) % 30; i = c // 4; k = c % 4; l = (32 + 2 * e + 2 * i - h - k) % 7
    m = (a + 11 * h + 22 * l) // 451; mo = (h + l - 7 * m + 114) // 31; da = ((h + l - 7 * m + 114) % 31) + 1
    return D(y, mo, da)
def nth_weekday(y, mo, wd, n):
    d = D(y, mo, 1); d += dt.timedelta((wd - d.weekday()) % 7); return d + dt.timedelta(7 * (n - 1))
HOLI = set(); VAC = set()
for y in range(2018, 2028):
    HOLI |= {D(y, 1, 1), easter(y) - dt.timedelta(2), D(y, 6, 24), D(y, 7, 1), nth_weekday(y, 9, 0, 1),
             nth_weekday(y, 10, 0, 2), D(y, 12, 25), D(y, 12, 26)}
    d = D(y, 5, 24)
    while d.weekday() != 0: d -= dt.timedelta(1)
    HOLI.add(d)  # Journée nationale des patriotes
    # vacances de la construction : débutent l'avant-dernier dimanche de juillet, 2 semaines
    last = D(y, 7, 31)
    while last.weekday() != 6: last -= dt.timedelta(1)
    s = last - dt.timedelta(7)
    for i in range(14): VAC.add(s + dt.timedelta(i))
    for i in range(14): VAC.add(D(y, 12, 21) + dt.timedelta(i))
COVID = {D(2020, 3, 25) + dt.timedelta(i) for i in range(26)}  # arrêt des chantiers au Québec, printemps 2020
def is_work(d, chantier=True):
    if d.weekday() >= 5 or d in HOLI or d in VAC: return False
    if chantier and d in COVID: return False
    return True

def scurve(f0, f1, a=2.0, b=2.3):
    f0 = min(max(f0, 0), 1); f1 = min(max(f1, 0), 1)
    return float(beta_dist.cdf(f1, a, b) - beta_dist.cdf(f0, a, b))
def sample_frac(n, lo=0., hi=1., a=2.0, b=2.3):
    return lo + (hi - lo) * NP.beta(a, b, n)

# ------------------------------------------------------------------ villes / téléphone / adresses
VILLE = {v[0]: v for v in VILLES}
VILLE_IDS = [v[0] for v in VILLES]; VILLE_W = [v[5] for v in VILLES]
def pick_ville(): return R.choices(VILLE_IDS, VILLE_W)[0]
def phone(vid, style=0):
    ind = R.choice(VILLE[vid][4]); num = f'{R.randint(200, 989)}{R.randint(0, 9999):04d}'
    a, b = num[:3], num[3:]
    return [f'({ind}) {a}-{b}', f'{ind}-{a}-{b}', f'{ind}{a}{b}', f'{ind}.{a}.{b}', f'{ind} {a} {b}'][style]
def postal(vid):
    L = 'ABCEGHJKLMNPRSTVWXYZ'
    return f'{R.choice(VILLE[vid][3])} {R.randint(1,9)}{R.choice(L)}{R.randint(0,9)}'
def adresse(): return f'{R.randint(10, 9800)}, {R.choice(RUES)}'

# ------------------------------------------------------------------ CLIENTS
PETITES = ("Saint-Étienne-des-Grès Yamachiche Saint-Boniface Notre-Dame-du-Mont-Carmel Champlain Batiscan "
           "Sainte-Anne-de-la-Pérade Saint-Tite Warwick Kingsey Falls Saint-Cyrille-de-Wendover Wickham North-Hatley "
           "Compton Waterville Ascot-Corner Stoke Lac-Beauport Stoneham Saint-Henri Saint-Lambert-de-Lauzon Sainte-Marie "
           "Saint-Isidore Saint-Roch-de-l'Achigan L'Assomption Sainte-Julienne Rawdon Chambly Carignan Mont-Saint-Hilaire "
           "Marieville Saint-Césaire Farnham Bromont Cowansville Sutton Princeville Plessisville Daveluyville "
           "Saint-Léonard-d'Aston Sainte-Perpétue Saint-Germain-de-Grantham Pierreville Sainte-Monique Saint-Célestin "
           "Saint-Prosper Beauceville Saint-Joseph-de-Beauce Disraeli Lac-Etchemin").split()
CSS = ("des Chênes|de la Riveraine|des Sommets|de la Région-de-Sherbrooke|des Navigateurs|des Découvreurs|de la Capitale|"
       "des Premières-Seigneuries|des Affluents|des Samares|des Hautes-Rivières|de Saint-Hyacinthe|du Chemin-du-Roy|"
       "de l'Énergie|des Bois-Francs|de la Beauce-Etchemin|des Grandes-Seigneuries|Marie-Victorin").split('|')
ADJ = ("Laurentide Boréal Horizon Vallée Cap Rive-Sud Prestige Héritage Avenir Pinacle Alliance Concept Synergie Optimum "
       "Valmont Belvédère Riverain Lauriers Saint-Maurice Appalaches Estrien Fleuve Montcalm Bellevue Champlain").split()

clients = []  # dict
def neq(prefix):
    return f'{prefix}{R.randint(10000000, 99999999)}'
def add_client(nom, seg, typ, vid, prefix):
    cid = len(clients) + 1
    clients.append(dict(ClientID=cid, NoClient=f'C{cid:05d}', NomClient=nom, TypeClient=typ, Segment=seg,
                        Adresse=adresse(), VilleID=vid, CodePostal=postal(vid), Telephone=phone(vid, 0),
                        Courriel=f'comptes.payables@{slug(nom)}.exemple.ca', ConditionsPaiement=R.choice([30, 30, 45, 60]) if typ == 'Privé' else R.choice([30, 45, 60]),
                        LimiteCredit=0, NEQ=neq(prefix), EstDoublon=0, MaitreID=cid, MauvaisPayeur=int(R.random() < .1)))
used = set()
def uniq(n):
    if n in used: return None
    used.add(n); return n
for v in VILLES: add_client(f'Ville de {v[1]}', 'Municipal', 'Public', v[0], '88')
for p in R.sample(PETITES, 45): add_client(f'Municipalité de {p}', 'Municipal', 'Public', pick_ville(), '88')
for v in R.sample(VILLES, 6): add_client(f"Office municipal d'habitation de {v[1]}", 'Municipal', 'Public', v[0], '88')
for r in REGIONS: add_client(f'Ministère des Transports — Direction régionale {r[1]}', 'Gouvernemental', 'Public', R.choice([v[0] for v in VILLES if v[2] == r[0]] or [1]), '88')
for r in R.sample(REGIONS, 4): add_client(f'Société québécoise des infrastructures — {r[1]}', 'Gouvernemental', 'Public', R.choice([v[0] for v in VILLES if v[2] == r[0]] or [1]), '88')
for c in CSS: add_client(f'Centre de services scolaire {c}', 'Institutionnel', 'Public', pick_ville(), '88')
for r in R.sample(REGIONS, 7): add_client(f'CIUSSS — {r[1]}', 'Institutionnel', 'Public', R.choice([v[0] for v in VILLES if v[2] == r[0]] or [1]), '88')
for v in R.sample(VILLES, 10): add_client(f'Cégep de {v[1]}', 'Institutionnel', 'Public', v[0], '88')
for i in range(9):
    n = uniq(f'Centre de la petite enfance Les {R.choice(["Petits Bourgeons","Lucioles","Câlinours","Joyeux Lutins","Petits Pas","Coccinelles","Mésanges","Écureuils","Papillons","Hiboux"])}')
    if n: add_client(n, 'Institutionnel', 'Privé', pick_ville(), '11')
def fam(): return R.choice(NOMS) if R.random() < .75 else f'{R.choice(NOMS)}-{R.choice(NOMS)}'
tpl = {
    'Immobilier': ['Gestion {} inc.', 'Groupe immobilier {} inc.', 'Les Développements {} inc.', 'Immeubles {} ltée',
                   'Habitations {} inc.', 'Fiducie immobilière {}', 'Investissements {} inc.', 'Propriétés {} inc.'],
    'Commerce': ['Alimentation {} inc.', 'Quincaillerie {} inc.', 'Automobiles {} inc.', 'Restaurants {} inc.',
                 'Pharmacie {} et associés', 'Hôtellerie {} inc.', 'Marché {} inc.', 'Meubles {} ltée'],
    'Industriel': ['Métallurgie {} inc.', 'Plastiques {} ltée', 'Aliments {} inc.', 'Usinage {} inc.', 'Papiers {} inc.',
                   'Laiterie {} inc.', 'Composantes {} inc.', 'Transport {} inc.', 'Technologies {} inc.', 'Énergie {} inc.'],
}
for seg, n in [('Immobilier', 92), ('Commerce', 46), ('Industriel', 52)]:
    k = 0
    while k < n:
        base = fam() if R.random() < .7 else R.choice(ADJ)
        nm = uniq(R.choice(tpl[seg]).format(base))
        if nm: add_client(nm, seg, 'Privé', pick_ville(), R.choice(['11', '11', '33'])); k += 1
for c in clients:
    c['LimiteCredit'] = R.choice([250000, 500000, 1000000, 2500000, 5000000]) if c['TypeClient'] == 'Privé' else 0
N_CLIENT_MASTER = len(clients)

def messy_name(n):
    v = R.choice(['upper', 'noacc', 'inc', 'space', 'abbr', 'lower'])
    if v == 'upper': return n.upper()
    if v == 'noacc': return strip_acc(n)
    if v == 'inc': return n.replace(' inc.', ' Inc').replace(' ltée', ' Ltee') if (' inc.' in n or ' ltée' in n) else n + ' '
    if v == 'space': return '  ' + n.replace(' ', '  ', 1) + ' '
    if v == 'abbr': return n.replace('Ville de ', 'V. de ').replace('Municipalité de ', 'Mun. ').replace('Centre de services scolaire', 'CSS').replace('Ministère des Transports', 'MTQ')
    return n.lower()
dup_src = R.sample([c for c in clients if c['Segment'] != 'Gouvernemental'], 28)
for c in dup_src:
    d = dict(c); d['ClientID'] = len(clients) + 1; d['NoClient'] = f'C{d["ClientID"]:05d}'
    d['NomClient'] = messy_name(c['NomClient']); d['EstDoublon'] = 1; d['MaitreID'] = c['ClientID']
    d['Telephone'] = phone(c['VilleID'], R.randint(1, 4)); d['CodePostal'] = R.choice([c['CodePostal'].replace(' ', ''), c['CodePostal'].lower(), c['CodePostal']])
    d['Courriel'] = None if R.random() < .4 else d['Courriel'].upper()
    if R.random() < .15: d['NEQ'] = None
    clients.append(d)
# formats de téléphone/codes postaux hétérogènes sur les fiches d'origine aussi
for c in clients[:N_CLIENT_MASTER]:
    if R.random() < .25: c['Telephone'] = phone(c['VilleID'], R.randint(1, 4))
    if R.random() < .08: c['CodePostal'] = c['CodePostal'].replace(' ', '')
    if R.random() < .04: c['Courriel'] = None
CLIENTS_BY_SEG = defaultdict(list)
for c in clients[:N_CLIENT_MASTER]: CLIENTS_BY_SEG[c['Segment']].append(c['ClientID'])
for s in CLIENTS_BY_SEG: R.shuffle(CLIENTS_BY_SEG[s])
DUPS_OF = defaultdict(list)
for c in clients[N_CLIENT_MASTER:]: DUPS_OF[c['MaitreID']].append(c['ClientID'])

# ------------------------------------------------------------------ FOURNISSEURS
fourn = []
FOURN_TPL = {
    ('Matériaux', '03'): ['Béton {} inc.', 'Bétons préparés {}'], ('Matériaux', '02'): ['Agrégats {} inc.', 'Carrière {} ltée'],
    ('Matériaux', '05'): ['Acier {} inc.', 'Métaux ouvrés {}'], ('Matériaux', '06'): ['Bois {} ltée', 'Matériaux {} inc.', 'Centre de rénovation {}'],
    ('Matériaux', '07'): ['Isolation {} inc.', 'Membranes {}'], ('Matériaux', '08'): ['Portes et fenêtres {} inc.', 'Vitrerie {}'],
    ('Matériaux', '09'): ['Céramique {} inc.', 'Gypse {} distribution'], ('Matériaux', '15'): ['Plomberie {} (distribution) inc.', 'Ventilation {} distribution'],
    ('Matériaux', '16'): ['Distribution électrique {} inc.', 'Luminaires {}'], ('Matériaux', '04'): ['Briques et pierres {} inc.'],
    ('Matériaux', '32'): ['Pavés {} inc.', 'Pépinière {}'],
    ('Sous-traitant', '02'): ['Excavation {} inc.', 'Terrassement {} ltée'], ('Sous-traitant', '03'): ['Coffrages {} inc.', 'Finition de béton {}'],
    ('Sous-traitant', '04'): ['Maçonnerie {} inc.'], ('Sous-traitant', '05'): ['Structures d\'acier {} inc.', 'Soudure {} inc.'],
    ('Sous-traitant', '06'): ['Charpenterie {} inc.', 'Ébénisterie {}'], ('Sous-traitant', '07'): ['Toitures {} inc.', 'Couvreurs {} ltée'],
    ('Sous-traitant', '08'): ['Vitrage architectural {}', 'Portes de garage {}'], ('Sous-traitant', '09'): ['Peinture {} inc.', 'Plâtrier {} inc.', 'Revêtements de sol {}'],
    ('Sous-traitant', '15'): ['Plomberie {} inc.', 'Mécanique {} inc.', 'Réfrigération {} inc.'], ('Sous-traitant', '16'): ['{} Électrique inc.', 'Électricité {} ltée'],
    ('Sous-traitant', '32'): ['Asphalte {} inc.', 'Paysagement {} inc.', 'Pavage {} ltée'],
    ('Location équipement', '01'): ['Location {} inc.', 'Grues {} inc.', 'Location d\'outils {}'],
    ('Services', '01'): ['Laboratoire {} (contrôle qualité)', 'Arpenteurs-géomètres {}', 'Services sanitaires {}', 'Clôtures temporaires {}', 'Conteneurs {} inc.', 'Sécurité de chantier {}'],
}
counts = {'Matériaux': 11, 'Sous-traitant': 17, 'Location équipement': 26, 'Services': 40}
used_f = set()
for (cat, sec), tps in FOURN_TPL.items():
    n = counts[cat] if cat in ('Location équipement', 'Services') else counts[cat]
    k = 0
    while k < n:
        nm = R.choice(tps).format(fam() if R.random() < .7 else R.choice(ADJ))
        if nm in used_f: continue
        used_f.add(nm); fid = len(fourn) + 1; vid = pick_ville()
        fourn.append(dict(FournisseurID=fid, NoFournisseur=f'F{fid:05d}', NomFournisseur=nm, Categorie=cat, Specialite=sec,
                          VilleID=vid, Telephone=phone(vid, R.choice([0, 0, 0, 1, 2])), Courriel=f'facturation@{slug(nm)}.exemple.ca',
                          NEQ=neq(R.choice(['11', '33'])), ConditionsPaiement=R.choice([30, 30, 30, 45, 60]), EstDoublon=0, MaitreID=fid))
        k += 1
N_FOURN_MASTER = len(fourn)
FOURN_BY = defaultdict(list)
for f in fourn: FOURN_BY[(f['Categorie'], f['Specialite'])].append(f['FournisseurID'])
for k in FOURN_BY: R.shuffle(FOURN_BY[k])
for f in R.sample(fourn, 32):
    d = dict(f); d['FournisseurID'] = len(fourn) + 1; d['NoFournisseur'] = f'F{d["FournisseurID"]:05d}'
    d['NomFournisseur'] = messy_name(f['NomFournisseur']); d['EstDoublon'] = 1; d['MaitreID'] = f['FournisseurID']
    d['Telephone'] = phone(f['VilleID'], R.randint(1, 4))
    if R.random() < .1: d['NEQ'] = None
    fourn.append(d)
FDUPS_OF = defaultdict(list)
for f in fourn[N_FOURN_MASTER:]: FDUPS_OF[f['MaitreID']].append(f['FournisseurID'])
def pick_fourn(cat, sec, when):
    lst = FOURN_BY.get((cat, sec)) or FOURN_BY[('Matériaux', '06')]
    fid = zipf_pick(lst, 0.9)
    # fiche en doublon utilisée par certains commis à partir d'une date
    if fid in FDUPS_OF and when >= D(2021, 6, 1) and R.random() < .35: return FDUPS_OF[fid][0]
    return fid

# ------------------------------------------------------------------ PROJETS
SAINTS = ("Saint-Pie-X|Sainte-Marguerite|Saint-Louis-de-France|Sainte-Thérèse|Saint-Joseph|Notre-Dame|Saint-François-d'Assise|"
          "Sainte-Bernadette|Saint-Sacrement|Jean-XXIII|Des Pionniers|Des Explorateurs|La Source|Le Tournesol|L'Escale").split('|')
NAME_TPL = {
    'RES': ['Construction de {n} unités de condos — {rue}', 'Résidence pour aînés Les Jardins {fam}', 'Projet domiciliaire Le Domaine {adj} — phase {ph}',
            "Rénovation d'un immeuble de {nr} logements — {ville}", 'Maisons de ville {adj} — phase {ph}', "Coopérative d'habitation {adj}",
            'Immeuble locatif {fam} — {ville}'],
    'COM': ['Centre commercial {adj} — agrandissement', 'Édifice à bureaux {fam} — {ville}', 'Concession automobile {fam}', 'Épicerie {fam} — {ville}',
            'Réaménagement de bureaux — {fam}', 'Hôtel {adj} — {nh} chambres', 'Entrepôt de distribution {adj}', 'Restaurant {fam} — {ville}'],
    'INS': ["Agrandissement de l'école primaire {saint}", "Rénovation de l'école secondaire {saint}", 'Maison des aînés de {ville}',
            "Réfection de l'aile {L} — Hôpital de {ville}", 'Pavillon sportif — Cégep de {ville}', 'Bibliothèque municipale de {ville}',
            'Caserne de pompiers no {n2} — {ville}', 'CPE {saint} — nouvelle installation', 'Aréna de {ville} — mise aux normes'],
    'IND': ['Usine {fam} — agrandissement', 'Ligne de production {adj}', 'Entrepôt frigorifique {fam}', 'Bâtiment de maintenance {fam}',
            "Mise aux normes — usine de {ville}", 'Centre de distribution {adj} — {ville}'],
    'GEN': ['Réfection — {rue}, {ville}', "Remplacement de conduites d'aqueduc — secteur {saint}", 'Réfection du pont {fam} — {ville}',
            'Prolongement du boulevard {fam}', "Bassin de rétention — {ville}", 'Pavage du rang {saint}', 'Station de pompage — {ville}',
            'Piste cyclable {adj} — {ville}', 'Réfection des infrastructures — rue {fam}'],
}
DIV_PARAM = {  # projets/an, médiane valeur, sigma, durée médiane (mois), marge min/max, segments clients
    'RES': (36, 420_000, .75, 5.5, (.10, .15), {'Immobilier': .78, 'Municipal': .12, 'Commerce': .10}),
    'COM': (28, 1_300_000, .80, 9, (.07, .11), {'Immobilier': .45, 'Commerce': .45, 'Municipal': .10}),
    'INS': (20, 2_900_000, .80, 14, (.055, .095), {'Institutionnel': .70, 'Gouvernemental': .15, 'Municipal': .15}),
    'IND': (15, 1_800_000, .85, 8, (.08, .12), {'Industriel': .90, 'Commerce': .10}),
    'GEN': (28, 1_250_000, .85, 4.5, (.09, .15), {'Municipal': .65, 'Gouvernemental': .30, 'Industriel': .05}),
}
MONTH_W = {'GEN': [0, .1, .6, 2.2, 2.6, 2.0, 1.4, 1.0, .6, .3, 0, 0],
           'other': [.7, .8, 1.0, 1.25, 1.3, 1.2, .8, .9, 1.25, 1.1, .9, .5]}
GROWTH = {2018: .92, 2019: 1.0, 2020: .86, 2021: 1.08, 2022: 1.14, 2023: 1.12, 2024: 1.16, 2025: 1.22, 2026: 1.26}
projets = []; seq_year = defaultdict(int)
DIV_ID = {d[1]: d[0] for d in DIVISIONS}
for y in range(2018, 2027):
    for div, (npy, med, sig, dmed, mrg, segs) in DIV_PARAM.items():
        n = NP.poisson(npy * GROWTH[y])
        mw = MONTH_W['GEN' if div == 'GEN' else 'other']
        for _ in range(n):
            mo = R.choices(range(1, 13), mw)[0]
            start = D(y, mo, R.randint(1, 28))
            if start > TODAY + dt.timedelta(160): continue
            val = float(np.clip(med * math.exp(R.gauss(0, sig)), med * .08, med * 12))
            val = round(val / 500) * 500
            dur_m = float(np.clip(dmed * (val / med) ** .4 * math.exp(R.gauss(0, .25)), 1.3, 34))
            if div == 'GEN' and dur_m < 8:
                # les chantiers de génie civil se terminent avant l'hiver
                lim = (D(y, 11, 30) - start).days / 30.4
                if lim > 1.2: dur_m = min(dur_m, lim)
            p_end = start + dt.timedelta(int(dur_m * 30.4))
            if p_end < D(2019, 1, 15): continue
            ovr = float(np.clip(NP.lognormal(-2.9, .9) - .02 + R.gauss(0, .03), -.06, .65))
            a_start = start + dt.timedelta(R.randint(-6, 24))
            a_end = a_start + dt.timedelta(int(dur_m * 30.4 * (1 + ovr)))
            marge = R.uniform(*mrg)
            cost_ovr = .45 * ovr + R.gauss(.0, .045) + (.12 if R.random() < .04 else 0)  # quelques projets « dérapent »
            seg = wchoice(segs)
            cid = zipf_pick(CLIENTS_BY_SEG[seg], 0.8)
            vid = VILLE[clients[cid - 1]['VilleID']][0] if R.random() < .6 else pick_ville()
            seq_year[start.year] += 1
            pid = len(projets) + 1
            p = dict(ProjetID=pid, NoProjet=f'P{start.year % 100:02d}-{seq_year[start.year]:04d}', Div=div, DivisionID=DIV_ID[div],
                     ClientID=cid, VilleID=vid, DateDebutPrevue=start, DateFinPrevue=p_end, DebutReel=a_start, FinReel=a_end,
                     ValeurContrat=val, Marge=marge, CoutPrevu=val * (1 - marge), CoutReelTotal=val * (1 - marge) * (1 + cost_ovr),
                     TypeContrat=R.choices(['Forfaitaire', 'Coût plus', 'Prix unitaire'], [.72, .10, .18] if div != 'GEN' else [.35, .05, .60])[0],
                     Annule=None, Suspendu=False)
            nm = R.choice(NAME_TPL[div]).format(n=max(4, 2 * round(val / 520_000)), nr=max(6, 2 * round(val / 170_000)), nh=max(20, 5 * round(val / 900_000)), n2=R.randint(1, 9), rue=R.choice(RUES),
                                                 fam=R.choice(NOMS), adj=R.choice(ADJ), ph=R.randint(1, 4), ville=VILLE[vid][1], saint=R.choice(SAINTS),
                                                 L=R.choice('ABCDEFG'))
            p['NomProjet'] = nm
            projets.append(p)
# doublons clients : certains projets récents pointent vers la fiche en double
for p in projets:
    if p['ClientID'] in DUPS_OF and p['DateDebutPrevue'] >= D(2021, 1, 1) and R.random() < .4:
        p['ClientID'] = DUPS_OF[p['ClientID']][0]
# statuts
for p in projets:
    if p['DebutReel'] > TODAY:
        p['Statut'] = 'Soumission'
    elif R.random() < .022:
        f = R.uniform(.08, .45); cdate = p['DebutReel'] + dt.timedelta(int((p['FinReel'] - p['DebutReel']).days * f))
        if cdate < TODAY:
            p['Annule'] = cdate; p['Statut'] = 'Annulé'
        else:
            p['Statut'] = 'En cours'
    elif p['FinReel'] < TODAY:
        p['Statut'] = 'Terminé'
    else:
        p['Statut'] = 'En cours'
    if p['Statut'] == 'En cours' and R.random() < .02: p['Suspendu'] = True; p['Statut'] = 'Suspendu'
    p['CutEnd'] = min(TODAY, p['Annule'] or p['FinReel'])  # dernier jour d'activité générée
print('projets', len(projets), {s: sum(1 for p in projets if p['Statut'] == s) for s in ['Soumission', 'En cours', 'Terminé', 'Annulé', 'Suspendu']})

def frac(p, d):
    tot = (p['FinReel'] - p['DebutReel']).days or 1
    return (d - p['DebutReel']).days / tot

# ------------------------------------------------------------------ budget & montants par code
def type_amounts(p, base):
    mix = MIX_TYPE[p['Div']]; secw = SEC_W[p['Div']]
    out = {}
    for t in ['MO', 'MAT', 'ST', 'EQ']:
        for sec, w in secw.items():
            out[f'{sec}-{t}'] = base * mix[t] * w * .92
        out[f'01-{t}'] = base * mix[t] * .08
    out['01-ST'] += base * mix['CG'] * .55; out['01-MAT'] += base * mix['CG'] * .25; out['01-EQ'] += base * mix['CG'] * .20
    return out
budget = []; bid = 0
for p in projets:
    amt = type_amounts(p, p['CoutPrevu'])
    created = p['DateDebutPrevue'] - dt.timedelta(R.randint(15, 60))
    jit = {k: v * R.uniform(.85, 1.15) for k, v in amt.items() if v > 400}
    tot = sum(jit.values()); jit = {k: v * p['CoutPrevu'] / tot for k, v in jit.items()}
    for k, v in jit.items():
        bid += 1; budget.append(dict(BudgetID=bid, ProjetID=p['ProjetID'], CodeCoutID=CODE_ID[k], Version='Original', Montant=round(v, 2),
                                     CreatedAt=ts(created), ModifiedAt=ts(created)))
    p['BudgetCodes'] = jit
    if p['Statut'] in ('En cours', 'Terminé', 'Suspendu') and R.random() < .35:
        rdate = p['DebutReel'] + dt.timedelta(int((p['FinReel'] - p['DebutReel']).days * R.uniform(.3, .6)))
        if rdate < TODAY:
            ratio = p['CoutReelTotal'] / p['CoutPrevu']
            for k, v in jit.items():
                nv = v * (1 + (ratio - 1) * R.uniform(.3, 1.0)) if R.random() < .5 else v
                bid += 1; budget.append(dict(BudgetID=bid, ProjetID=p['ProjetID'], CodeCoutID=CODE_ID[k], Version='Révisé 1', Montant=round(nv, 2),
                                             CreatedAt=ts(rdate), ModifiedAt=ts(rdate)))
print('budget', len(budget))

# ------------------------------------------------------------------ ordres de changement
ocs = []
for p in projets:
    if p['Statut'] in ('Soumission',): continue
    n = NP.poisson(min(12, 1 + p['ValeurContrat'] / 900_000)) if R.random() < .65 else 0
    k = 0
    for _ in range(n):
        d = p['DebutReel'] + dt.timedelta(int((p['FinReel'] - p['DebutReel']).days * R.uniform(.1, .95)))
        if d > p['CutEnd']: continue
        k += 1
        st = R.choices(['Approuvé', 'En attente', 'Refusé'], [.78, .12, .10])[0]
        if (TODAY - d).days > 120 and st == 'En attente': st = 'Approuvé'
        amt = round(p['ValeurContrat'] * R.uniform(.004, .035) * (1 if R.random() < .9 else -1), 2)
        ocs.append(dict(OrdreChangementID=len(ocs) + 1, ProjetID=p['ProjetID'], NoOC=f'{p["NoProjet"]}-OC{k:02d}', DateOC=d,
                        Description=R.choice(['Modification demandée par le client', 'Condition de sol imprévue', 'Ajout de travaux électriques',
                                              'Changement de finition', 'Exigence réglementaire', 'Correction aux plans', 'Travaux supplémentaires — CVAC',
                                              'Retrait de travaux', 'Ajout de stationnement', 'Renforcement structural']),
                        Montant=amt, Statut=st, CreatedAt=ts(d), ModifiedAt=ts(d + dt.timedelta(R.randint(2, 40))) if st != 'En attente' else ts(d)))
print('OC', len(ocs))
for o in ocs:  # les travaux des ordres de changement coûtent aussi quelque chose
    if o['Statut'] == 'Approuvé': P0 = projets[o['ProjetID'] - 1]; P0['CoutReelTotal'] += o['Montant'] * R.uniform(.80, .97)

# ------------------------------------------------------------------ demande de main-d'œuvre hebdomadaire
CHARGES = {2018: .41, 2019: .41, 2020: .42, 2021: .42, 2022: .43, 2023: .43, 2024: .44, 2025: .44, 2026: .45, 2027: .45}
RAISE = {2019: 1.019, 2020: 1.020, 2021: 1.020, 2022: 1.023, 2023: 1.030, 2024: 1.035, 2025: 1.060, 2026: 1.040}
def cum_factor(y):
    f = 1.0
    for yy in range(2019, y + 1): f *= RAISE.get(yy, 1.04)
    return f
WEEKS = []
w = D(2018, 12, 31)
while w <= TODAY:
    WEEKS.append(w); w += dt.timedelta(7)
def wdays(w, chantier=True): return [w + dt.timedelta(i) for i in range(5) if is_work(w + dt.timedelta(i), chantier) and w + dt.timedelta(i) <= TODAY]
for p in projets:
    if p['Statut'] == 'Soumission': p['H'] = 0; continue
    mid = p['DebutReel'] + (p['FinReel'] - p['DebutReel']) / 2
    y = min(max(mid.year, 2019), 2026)
    loaded = 42.0 * cum_factor(y) * (1 + CHARGES[y]) * 1.04
    p['H'] = p['CoutReelTotal'] * MIX_TYPE[p['Div']]['MO'] / loaded
demand = defaultdict(float)  # (div, week) -> heures
for p in projets:
    if not p['H']: continue
    for w in WEEKS:
        we = w + dt.timedelta(6)
        if we < p['DebutReel'] or w > p['CutEnd']: continue
        demand[(p['Div'], w)] += p['H'] * scurve(frac(p, w), frac(p, min(we, p['CutEnd']) + dt.timedelta(1)))
target = {}
for div in MIX_METIER:
    for y in range(2019, 2027):
        vals = [demand[(div, w)] for w in WEEKS if w.year == y and len(wdays(w)) >= 4]
        mx = max(vals) if vals else 0
        vals = [v for v in vals if v > .3 * mx] or [0]
        target[(div, y)] = max(6, int(round(np.percentile(vals, 60) / 40 * 1.05)))
raw = dict(target)
for (div, y) in raw:
    nb = [raw.get((div, y - 1), raw[(div, y)]), raw[(div, y)], raw[(div, y)], raw.get((div, y + 1), raw[(div, y)])]
    target[(div, y)] = int(round(sum(nb) / 4))
print('effectif cible chantier', {k: v for k, v in target.items() if k[1] in (2019, 2023, 2026)})

# ------------------------------------------------------------------ EMPLOYÉS
employes = []
def new_emp(div, met, hire, depart=None):
    eid = len(employes) + 1
    f = R.random() < (.04 if MET[met][3] == 'Chantier' else .5)
    pre = R.choice(PRENOMS_F if f else PRENOMS_H)
    nom = R.choice(NOMS) if R.random() < .88 else R.choice(NOMS_DIV)
    e = dict(EmployeID=eid, Matricule=f'E{10000 + eid}', Prenom=pre, Nom=nom, Metier=met, MetierID=MET[met][0], Div=div, DivisionID=DIV_ID[div],
             VilleID=pick_ville(), DateEmbauche=hire, DateDepart=depart, TypeEmploi='Permanent', SuperviseurID=None)
    if MET[met][3] == 'Chantier' and R.random() < .18: e['TypeEmploi'] = 'Saisonnier' if div == 'GEN' else 'Temporaire'
    employes.append(e); return e
def active_on(e, d): return e['DateEmbauche'] <= d and (e['DateDepart'] is None or e['DateDepart'] >= d)
months = []
m = D(2019, 1, 1)
while m <= TODAY: months.append(m); m = D(m.year + (m.month == 12), m.month % 12 + 1, 1)
def rand_day_in(m):
    nxt = D(m.year + (m.month == 12), m.month % 12 + 1, 1)
    return min(m + dt.timedelta(R.randint(0, (nxt - m).days - 1)), TODAY)
for div, mix in MIX_METIER.items():
    pool = []
    for _ in range(target[(div, 2019)]):
        pool.append(new_emp(div, wchoice(mix), D(R.randint(1996, 2018), R.randint(1, 12), R.randint(1, 28))))
    for m in months:
        act = [e for e in pool if active_on(e, m)]
        for e in act:
            if R.random() < .0085: e['DateDepart'] = rand_day_in(m)
        act = [e for e in pool if active_on(e, m) and e['DateDepart'] is None]
        tg = target[(div, m.year)] if m.month > 3 else int(round(.5 * target[(div, m.year)] + .5 * target[(div, max(2019, m.year - 1))]))
        if len(act) < tg:
            for _ in range(tg - len(act)): pool.append(new_emp(div, wchoice(mix), rand_day_in(m)))
        elif len(act) > tg * 1.18:
            for e in R.sample(act, len(act) - int(tg * 1.1)): e['DateDepart'] = rand_day_in(m)
# personnel de bureau
def n_active_proj(div, d): return sum(1 for p in projets if p['Div'] == div and p['DebutReel'] <= d <= p['CutEnd'] and p['Statut'] != 'Soumission')
BUREAU_PLAN = {}
for div in MIX_METIER:
    for y in range(2019, 2027):
        ap = n_active_proj(div, D(y, 6, 15))
        BUREAU_PLAN[(div, y)] = {'CPJ': max(3, round(ap / 5.5)), 'EST': 2 + (y >= 2023), 'TEC': 2 + (div in ('GEN', 'INS')), 'DIR': 1}
for y in range(2019, 2027):
    BUREAU_PLAN[('ADM', y)] = {'ACH': 3 + (y >= 2022) + (y >= 2025), 'CPT': 4 + (y >= 2021) + (y >= 2024), 'CTL': 1, 'RHC': 1 + (y >= 2022)}
for div in list(MIX_METIER) + ['ADM']:
    pool = defaultdict(list)
    for met, n in BUREAU_PLAN[(div, 2019)].items():
        for _ in range(n): pool[met].append(new_emp(div, met, D(R.randint(1999, 2018), R.randint(1, 12), R.randint(1, 28))))
    for m in months:
        for met, n in BUREAU_PLAN[(div, m.year)].items():
            act = [e for e in pool[met] if active_on(e, m) and e['DateDepart'] is None]
            for e in act:
                if R.random() < .006: e['DateDepart'] = rand_day_in(m)
            act = [e for e in pool[met] if active_on(e, m) and e['DateDepart'] is None]
            for _ in range(n - len(act)): pool[met].append(new_emp(div, met, rand_day_in(m)))
for e in employes:
    if e['DateDepart'] and e['DateDepart'] > TODAY: e['DateDepart'] = None
    e['Statut'] = 'Actif' if e['DateDepart'] is None else 'Inactif'
    if e['Statut'] == 'Actif' and R.random() < .02: e['Statut'] = 'Congé'
print('employés', len(employes), 'actifs', sum(e['Statut'] != 'Inactif' for e in employes))
# superviseurs
for e in employes:
    if e['Metier'] in ('DIR', 'CTL'): continue
    if MET[e['Metier']][3] == 'Chantier' and e['Metier'] not in ('SUR',):
        cands = [s for s in employes if s['Div'] == e['Div'] and s['Metier'] in (('SUR',) if e['Metier'] == 'CON' else ('CON',)) and s['EmployeID'] != e['EmployeID']]
    else:
        cands = [s for s in employes if s['Div'] == e['Div'] and s['Metier'] == ('CTL' if e['Div'] == 'ADM' else 'DIR')]
    cands = [s for s in cands if active_on(s, max(e['DateEmbauche'], D(2019, 1, 1)))] or cands
    if cands: e['SuperviseurID'] = R.choice(cands)['EmployeID']
# historique des taux horaires (1er mai de chaque année)
taux = []
for e in employes:
    mm = MET[e['Metier']]
    start = max(e['DateEmbauche'], D(2018, 5, 1))
    y0 = start.year if start >= D(start.year, 5, 1) else start.year - 1
    rate = R.uniform(mm[4], mm[5]) * cum_factor(max(2018, y0)) / (1 if y0 <= 2018 else 1)
    periods = []
    cur = start
    y = y0
    while True:
        nxt = D(y + 1, 5, 1)
        end = nxt - dt.timedelta(1)
        if e['DateDepart'] and e['DateDepart'] <= end: end = e['DateDepart']
        if cur > TODAY: break
        periods.append([cur, end if end < TODAY or e['DateDepart'] else None, round(rate, 2)])
        if (e['DateDepart'] and e['DateDepart'] <= nxt - dt.timedelta(1)) or nxt > TODAY: break
        cur = nxt; y += 1
        rate *= RAISE.get(y, 1.04) if mm[6] else R.uniform(1.015, 1.055)
    for a, b, r in periods:
        taux.append(dict(TauxID=len(taux) + 1, EmployeID=e['EmployeID'], DateDebut=a, DateFin=b, TauxHoraire=r,
                         CreatedAt=ts(a), ModifiedAt=ts(a)))
    e['periods'] = periods
print('taux', len(taux))
def rate_on(e, d):
    for a, b, r in e['periods']:
        if a <= d and (b is None or d <= b): return r
    return e['periods'][-1][2]
# chargés de projet
for p in projets:
    d = max(p['DebutReel'], D(2019, 1, 1)) if p['Statut'] != 'Soumission' else min(TODAY, p['DateDebutPrevue'])
    cands = [e for e in employes if e['Div'] == p['Div'] and e['Metier'] == 'CPJ' and active_on(e, min(d, TODAY))] or \
            [e for e in employes if e['Div'] == p['Div'] and e['Metier'] == 'CPJ']
    p['ChargeProjetID'] = R.choice(cands)['EmployeID']

# ------------------------------------------------------------------ FEUILLES DE TEMPS
def sec_for(met, p, f):
    secs = [s for s in METIER_SEC.get(met, ['01']) if s == '01' or s in SEC_W[p['Div']]]
    ok = [s for s in secs if SEC_WIN[s][0] - .1 <= f <= SEC_WIN[s][1] + .1]
    if met == 'MAN':
        act = [s for s in SEC_W[p['Div']] if SEC_WIN[s][0] <= f <= SEC_WIN[s][1]]
        return R.choice(act) if act else '01'
    return (ok or secs or ['01'])[0] if R.random() < .85 else R.choice(secs or ['01'])
ft = []  # (EmployeID, date, ProjetID, CodeCoutID, HReg, HSupp)
backlog = defaultdict(float)
proj_by_div = defaultdict(list)
for p in projets:
    if p['Statut'] != 'Soumission': proj_by_div[p['Div']].append(p)
chantier = defaultdict(list)
for e in employes:
    if MET[e['Metier']][3] == 'Chantier': chantier[e['Div']].append(e)
labour_h = defaultdict(float)
sat_done = set()
for w in WEEKS:
    we = w + dt.timedelta(6)
    days = wdays(w, True)
    for div in MIX_METIER:
        needs = {}
        for p in proj_by_div[div]:
            if p['DebutReel'] > we: continue
            if w > p['CutEnd']:
                if backlog[p['ProjetID']] > 0 and (w - p['CutEnd']).days <= 21 and p['Statut'] != 'Annulé' and w <= TODAY:
                    needs[p['ProjetID']] = backlog[p['ProjetID']]
                continue
            h = p['H'] * scurve(frac(p, w), frac(p, min(we, p['CutEnd']) + dt.timedelta(1))) + backlog[p['ProjetID']]
            if h > 0: needs[p['ProjetID']] = h
        if not needs: continue
        if not days:
            for k, v in needs.items(): backlog[k] = v
            continue
        emps = [e for e in chantier[div] if active_on(e, w) and active_on(e, days[-1]) and e['Statut'] != 'Congé' or (active_on(e, w) and e['Statut'] == 'Congé' and e['DateDepart'] is None and w < TODAY - dt.timedelta(60))]
        R.shuffle(emps)
        # les contremaîtres/surintendants d'abord sur les plus gros projets
        emps.sort(key=lambda e: 0 if e['Metier'] in ('SUR', 'CON') else 1)
        heap = [(-v, k) for k, v in needs.items()]; heapq.heapify(heap)
        assigned = defaultdict(list)
        for e in emps:
            left = list(days)
            while left and heap:
                negv, pid = heapq.heappop(heap)
                need = -negv
                if need <= 4: continue
                k = min(len(left), max(1, int(math.ceil(need / 8))))
                use, left = left[:k], left[k:]
                assigned[pid].append([e, use, 0.0])
                need -= 8 * len(use)
                if need > 4: heapq.heappush(heap, (-need, pid))
            if not heap: break
        rem = {pid: -v for v, pid in heap}
        # heures supplémentaires si la demande dépasse la capacité
        for pid, r in rem.items():
            crew = assigned.get(pid, [])
            if not crew: backlog[pid] = r; continue
            per = min(2.0 * len(days), r / len(crew))
            for a in crew: a[2] = per * len(a[1]) / len(days)
            backlog[pid] = max(0.0, r - per * len(crew) * .9)
        for pid in needs:
            if pid not in rem: backlog[pid] = 0.0
        P = {p['ProjetID']: p for p in proj_by_div[div]}
        for pid, crew in assigned.items():
            p = P[pid]
            for e, use, ot in crew:
                code = CODE_ID[sec_for(e['Metier'], p, frac(p, w)) + '-MO']
                otd = round(ot / len(use) * 2) / 2 if ot else 0.0
                for d in use:
                    if R.random() < .03: continue  # absence
                    hr = 8.0 if R.random() > .06 else R.choice([4.0, 6.0, 7.0])
                    hs = otd if otd and R.random() < .85 else 0.0
                    ft.append((e['EmployeID'], d, pid, code, hr, hs))
                    labour_h[pid] += hr + hs
                if ot > 6 and R.random() < .35 and we - dt.timedelta(1) <= TODAY and (e['EmployeID'], w) not in sat_done:  # samedi en temps supplémentaire
                    sat_done.add((e['EmployeID'], w))
                    ft.append((e['EmployeID'], w + dt.timedelta(5), pid, code, 0.0, 8.0))
print('ft chantier', len(ft))
# bureau
for e in employes:
    if MET[e['Metier']][3] != 'Bureau': continue
    vac_weeks = set()
    for y in range(2019, 2027):
        cand = [w for w in WEEKS if w.year == y]
        vac_weeks |= set(R.sample(cand, min(2, len(cand))))
    mine = [p for p in projets if p.get('ChargeProjetID') == e['EmployeID'] and p['Statut'] != 'Soumission']
    divp = proj_by_div.get(e['Div'], [])
    for w in WEEKS:
        if w in vac_weeks: continue
        for d in wdays(w, False):
            if not active_on(e, d) or d < D(2019, 1, 1): continue
            if d in VAC and R.random() < .75: continue
            if R.random() < .025: continue
            hrs = 7.5
            if e['Metier'] == 'CPJ':
                act = [p for p in mine if p['DebutReel'] <= d <= p['CutEnd']]
                if act:
                    pj = R.sample(act, min(len(act), R.choice([1, 1, 2])))
                    proj_h = round(hrs * R.uniform(.45, .8) * 2) / 2
                    for i, p in enumerate(pj):
                        hh = proj_h if len(pj) == 1 else (round(proj_h / 2 * 2) / 2)
                        ft.append((e['EmployeID'], d, p['ProjetID'], CODE_ID['01-MO'], hh, 0.0)); labour_h[p['ProjetID']] += hh
                    hrs -= proj_h if len(pj) == 1 else round(proj_h / 2 * 2) / 2 * len(pj)
            elif e['Metier'] == 'TEC' and R.random() < .35:
                act = [p for p in divp if p['DebutReel'] <= d <= p['CutEnd']]
                if act:
                    p = R.choice(act); ft.append((e['EmployeID'], d, p['ProjetID'], CODE_ID['01-MO'], 7.5, 0.0)); labour_h[p['ProjetID']] += 7.5
                    continue
            if hrs > 0: ft.append((e['EmployeID'], d, None, CODE_ID['00-ADM'], hrs, 0.0))
print('ft total', len(ft))
tot_need = sum(p['H'] for p in projets if p['Statut'] == 'Terminé' and p['DebutReel'] >= D(2019, 3, 1))
tot_got = sum(labour_h[p['ProjetID']] for p in projets if p['Statut'] == 'Terminé' and p['DebutReel'] >= D(2019, 3, 1))
print(f'heures livrées / demandées (projets terminés) : {tot_got/tot_need:.3f}')

# ------------------------------------------------------------------ ÉQUIPEMENTS
equip = []
for cat, models, rate, divs, n in EQUIP_CAT:
    for i in range(n):
        year = R.randint(2008, 2025); acq = D(year, R.randint(1, 12), R.randint(1, 28))
        disp = None
        if year < 2014 and R.random() < .45: disp = D(R.randint(2020, 2026), R.randint(1, 12), R.randint(1, 28))
        if disp and disp > TODAY: disp = None
        st = 'Vendu' if disp else R.choices(['Actif', 'En réparation'], [.93, .07])[0]
        mdl = R.choice(models)
        equip.append(dict(EquipementID=len(equip) + 1, NoUnite=f'U-{len(equip) + 101}', Description=f'{cat} {mdl}', Categorie=cat,
                          Marque=mdl.split()[0], Modele=' '.join(mdl.split()[1:]), Annee=year, DateAcquisition=acq, DateDisposition=disp,
                          TauxHoraireInterne=float(rate) * R.uniform(.95, 1.05), Statut=st, Divs=divs))
SEC_EQ = {'02': ['Excavatrice', 'Bouteur', 'Chargeuse sur roues', 'Camion 10 roues', 'Rétrocaveuse', 'Mini-excavatrice', 'Compacteur'],
          '32': ['Compacteur', 'Camion 10 roues', 'Rétrocaveuse', 'Chargeuse sur roues', 'Mini-excavatrice'],
          '03': ['Chariot télescopique', 'Grue mobile', 'Génératrice', 'Mini-excavatrice'], '05': ['Grue mobile', 'Nacelle articulée', 'Chariot télescopique'],
          '01': ['Camionnette de service', 'Génératrice', 'Nacelle articulée', 'Chariot télescopique']}
busy = set(); usage = []
def equip_for(cat_list, div, d):
    c = [x for x in equip if x['Categorie'] in cat_list and div in x['Divs'] and x['DateAcquisition'] <= d and (x['DateDisposition'] is None or x['DateDisposition'] >= d)]
    R.shuffle(c)
    for x in c[:14]:
        if (x['EquipementID'], d) not in busy: return x
    return None
OPM = defaultdict(list)
for e in employes:
    if e['Metier'] == 'OPM': OPM[e['Div']].append(e)

# ------------------------------------------------------------------ ACHATS / FACTURES FOURNISSEURS
CATALOG = {
    '02': [('Pierre concassée MG-20', 'tonne', 24.5), ('Sable de remblai', 'tonne', 14.0), ('Membrane géotextile', 'm²', 2.8), ('Transport de sols contaminés', 'tonne', 38.0)],
    '03': [('Béton 32 MPa', 'm³', 238.0), ('Béton 25 MPa', 'm³', 221.0), ('Armature 15M', 'tonne', 1650.0), ('Treillis métallique', 'm²', 7.5), ('Adjuvant accélérateur', 'L', 6.2)],
    '04': [('Brique d\'argile', 'unité', 1.15), ('Bloc de béton 20 cm', 'unité', 3.4), ('Mortier type S', 'sac', 14.0)],
    '05': [('Acier de charpente W', 'tonne', 2900.0), ('Pontage métallique', 'm²', 42.0), ('Boulonnerie structurale', 'lot', 650.0)],
    '06': [('Bois d\'œuvre 2x6 SPF', 'pmp', 1.25), ('Contreplaqué 5/8', 'feuille', 48.0), ('Poutrelles ajourées', 'unité', 185.0), ('Fermes de toit', 'unité', 340.0)],
    '07': [('Isolant rigide 2 po', 'feuille', 38.0), ('Laine minérale R-24', 'paquet', 72.0), ('Membrane élastomère', 'rouleau', 165.0), ('Pare-vapeur 6 mil', 'rouleau', 95.0)],
    '08': [('Fenêtre PVC hybride', 'unité', 780.0), ('Porte d\'acier isolée', 'unité', 1150.0), ('Quincaillerie de portes', 'lot', 420.0)],
    '09': [('Panneau de gypse 1/2 po', 'feuille', 16.5), ('Peinture latex', 'gallon', 54.0), ('Céramique de plancher', 'm²', 38.0), ('Tuiles acoustiques', 'boîte', 89.0)],
    '15': [('Tuyau PEX 3/4', 'mètre', 2.9), ('Raccords cuivre', 'lot', 310.0), ('Conduit galvanisé', 'mètre', 24.0), ('Chauffe-eau 60 gal', 'unité', 1450.0)],
    '16': [('Câble NMD90 14/2', 'mètre', 1.6), ('Panneau électrique 200 A', 'unité', 890.0), ('Luminaire DEL', 'unité', 145.0), ('Conduit EMT 3/4', 'mètre', 3.9)],
    '32': [('Enrobé bitumineux ESG-10', 'tonne', 118.0), ('Bordure de béton', 'mètre', 52.0), ('Terre végétale', 'm³', 41.0), ('Pavé uni', 'm²', 64.0)],
    '01': [('Clôture temporaire', 'mois', 680.0), ('Conteneur à déchets 40 vg', 'levée', 520.0), ('Toilette chimique', 'mois', 210.0), ('Roulotte de chantier', 'mois', 1150.0)],
}
SERVICES = [('Analyse de laboratoire — béton', 'essai', 185.0), ('Arpentage — implantation', 'heure', 145.0), ('Gardiennage de chantier', 'heure', 34.0),
            ('Conteneur à déchets 40 vg', 'levée', 520.0), ('Toilette chimique', 'mois', 210.0), ('Clôture temporaire', 'mois', 680.0)]
lines = []      # dict lignes
inv_keys = {}   # (fourn, projet, period) -> facture temp id
invoices = []   # header dicts
bcs = []
bc_keys = {}
def get_bc(key, fid, pid, d, montant):
    if key not in bc_keys:
        bid = len(bcs) + 1
        div = P_ALL[pid]['Div']
        acheteurs = [e for e in employes if e['Metier'] == 'ACH' and active_on(e, d)] or [e for e in employes if e['Metier'] == 'ACH']
        bcs.append(dict(BonCommandeID=bid, NoBC=f'BC{d.year % 100:02d}-{bid:06d}', ProjetID=pid, FournisseurID=fid, DateBC=d,
                        AcheteurID=R.choice(acheteurs)['EmployeID'], Statut='Ouvert', MontantTotal=0.0, _sum=0.0, _last=d))
        bc_keys[key] = bid
    b = bcs[bc_keys[key] - 1]; b['MontantTotal'] += montant; return bc_keys[key]
def add_line(fid, p, d, period_key, code, desc, qty, unit, pu, bc_key=None, bc_amt=0.0, cat='Matériaux'):
    key = (fid, p['ProjetID'], period_key)
    if key not in inv_keys:
        inv_keys[key] = len(invoices) + 1
        bcid = get_bc(bc_key, fid, p['ProjetID'], d - dt.timedelta(R.randint(5, 25)), bc_amt) if bc_key else None
        invoices.append(dict(FactureFournID=len(invoices) + 1, FournisseurID=fid, BonCommandeID=bcid, DateFacture=d, Cat=cat, n=0, HT=0.0))
    inv = invoices[inv_keys[key] - 1]
    inv['n'] += 1
    mt = round(qty * pu, 2)
    inv['HT'] += mt
    lines.append((inv['FactureFournID'], inv['n'], p['ProjetID'], code, desc, round(qty, 2), unit, round(pu, 4), mt))
    return mt
P_ALL = {p['ProjetID']: p for p in projets}
def window_dates(p, sec, n, a=2.0, b=2.3):
    lo, hi = SEC_WIN[sec]
    fr = sample_frac(n, lo, hi, a, b)
    span = (p['FinReel'] - p['DebutReel']).days
    return [p['DebutReel'] + dt.timedelta(int(f * span)) for f in fr]
def month_end(d):
    n = D(d.year + (d.month == 12), d.month % 12 + 1, 1) - dt.timedelta(1)
    while n.weekday() >= 5: n -= dt.timedelta(1)
    return n
eq_internal = defaultdict(float)
for p in projets:
    if p['Statut'] == 'Soumission': continue
    amts = type_amounts(p, p['CoutReelTotal'])
    for key, A in amts.items():
        sec, typ = key.split('-')
        if A < 300 or typ == 'MO': continue
        code = CODE_ID[key]
        if typ == 'ST':
            cat = 'Services' if sec == '01' else 'Sous-traitant'
            nsub = 1 if A < 400_000 else 2
            subs = [pick_fourn(cat, sec if cat == 'Sous-traitant' else '01', p['DebutReel']) for _ in range(nsub)]
            lo, hi = SEC_WIN[sec]
            span = (p['FinReel'] - p['DebutReel']).days
            s0 = p['DebutReel'] + dt.timedelta(int(lo * span)); s1 = p['DebutReel'] + dt.timedelta(max(int(hi * span), int(lo * span) + 20))
            m = D(s0.year, s0.month, 1)
            k = 0
            while m <= s1:
                me = month_end(m)
                f0 = max(0, (m - s0).days / max(1, (s1 - s0).days)); f1 = min(1, ((me - s0).days + 1) / max(1, (s1 - s0).days))
                portion = scurve(f0, f1)
                d = min(me, s1) - dt.timedelta(R.randint(0, 4))
                if d <= p['CutEnd'] and portion > 0.0005:
                    for fid in subs:
                        amt = A * portion / nsub * R.uniform(.92, 1.08)
                        if amt < 150: continue
                        k += 1
                        if cat == 'Services':
                            desc, unit, pu = R.choice(SERVICES)
                            add_line(fid, p, d, ('M', m), code, desc, max(1, amt / pu), unit, pu, bc_key=('S', p['ProjetID'], fid) if R.random() < .5 else None, bc_amt=amt, cat=cat)
                        else:
                            add_line(fid, p, d, ('M', m), code, f'Décompte progressif no {k} — {dict((s[0], s[1]) for s in SECTIONS)[sec].lower()}', 1, 'forfait', amt,
                                     bc_key=('ST', p['ProjetID'], fid, sec), bc_amt=amt, cat=cat)
                            if R.random() < .06:
                                ex = amt * R.uniform(.02, .08)
                                add_line(fid, p, d, ('M', m), code, 'Travaux supplémentaires autorisés', 1, 'forfait', ex, cat=cat)
                m = D(m.year + (m.month == 12), m.month % 12 + 1, 1)
        elif typ == 'MAT':
            nsup = 1 if A < 60_000 else (2 if A < 300_000 else 3)
            sups = [pick_fourn('Matériaux', sec if ('Matériaux', sec) in FOURN_BY else '06', p['DebutReel']) for _ in range(nsup)]
            avg = R.uniform(4500, 11000)
            n = int(np.clip(A / avg, 1, 260))
            for d in window_dates(p, sec, n):
                if d > p['CutEnd']: continue
                fid = R.choices(sups, [1, .5, .3][:len(sups)])[0]
                amt = A / n * R.uniform(.55, 1.45)
                period = ('M', D(d.year, d.month, 1)) if fid % 3 == 0 else ('W', d.isocalendar()[0], d.isocalendar()[1])
                bk = ('MAT', p['ProjetID'], fid, sec) if R.random() > .08 else None
                k_items = R.choice([1, 1, 2, 2, 3, 4])
                infl = cum_factor(min(max(d.year, 2019), 2026)) ** 1.6
                for _ in range(k_items):
                    a_it = amt / k_items * R.uniform(.6, 1.4)
                    cands = [it for it in CATALOG[sec] if it[2] * infl * 1.07 <= a_it] or [min(CATALOG[sec], key=lambda t: t[2])]
                    item, unit, pu = R.choice(cands)
                    pu2 = round(pu * infl * R.uniform(.93, 1.07), 2)   # inflation des matériaux
                    qty = a_it / pu2
                    qty = max(1, round(qty)) if unit in ('unité', 'feuille', 'sac', 'paquet', 'rouleau', 'gallon', 'boîte', 'levée', 'mois', 'lot') else round(qty, 2)
                    add_line(fid, p, d + dt.timedelta(R.randint(0, 3)), period, code, item, qty, unit, pu2, bc_key=bk, bc_amt=qty * pu2)
        elif typ == 'EQ':
            eq_internal[(p['ProjetID'], sec)] += A * .6
            Arent = A * .4
            fid = pick_fourn('Location équipement', '01', p['DebutReel'])
            lo, hi = SEC_WIN[sec]
            nmon = max(1, int(round((hi - lo) * (p['FinReel'] - p['DebutReel']).days / 30)))
            for d in window_dates(p, sec, nmon, 1.5, 1.5):
                if d > p['CutEnd']: continue
                cat_eq = R.choice(SEC_EQ.get(sec, SEC_EQ['01']))
                days = R.randint(5, 22); amt = Arent / nmon * R.uniform(.7, 1.3)
                add_line(fid, p, month_end(d), ('M', D(d.year, d.month, 1)), code, f'Location — {cat_eq.lower()}', days, 'jour', amt / days,
                         bc_key=('EQ', p['ProjetID'], fid), bc_amt=amt, cat='Location équipement')
print('factures fournisseurs', len(invoices), 'lignes', len(lines), 'BC', len(bcs))

# utilisation des équipements internes
for (pid, sec), A in eq_internal.items():
    p = P_ALL[pid]
    cats = [c for c in SEC_EQ.get(sec, SEC_EQ['01']) if any(c == x[0] and p['Div'] in x[3] for x in EQUIP_CAT)] or ['Camionnette de service']
    rate = np.mean([x[2] for x in EQUIP_CAT if x[0] in cats])
    hrs_total = A / rate
    ndays = int(np.clip(hrs_total / 6.75 * 2.4, 1, 2000))
    for d in window_dates(p, sec, ndays):
        if d > p['CutEnd'] or not is_work(d) or d < D(2019, 1, 1): continue
        x = equip_for(cats, p['Div'], d)
        if not x: continue
        busy.add((x['EquipementID'], d))
        ops = [e for e in OPM[p['Div']] if active_on(e, d)] if x['Categorie'] not in ('Génératrice', 'Camionnette de service') else []
        h = round(R.uniform(4, 9.5) * 2) / 2
        usage.append(dict(UtilisationID=len(usage) + 1, EquipementID=x['EquipementID'], ProjetID=pid, DateUtilisation=d, Heures=h,
                          OperateurID=R.choice(ops)['EmployeID'] if ops and R.random() < .8 else None))
print('utilisations équipement', len(usage))

# ------------------------------------------------------------------ coûts mensuels réels (pour la facturation progressive)
EMP = {e['EmployeID']: e for e in employes}
mcost = defaultdict(float)   # (pid, YYYY-MM-01) -> coût
for (eid, d, pid, code, hr, hs) in ft:
    if pid is None: continue
    mcost[(pid, D(d.year, d.month, 1))] += (hr + 1.5 * hs) * rate_on(EMP[eid], d) * (1 + CHARGES[d.year])
inv_date = {i['FactureFournID']: i['DateFacture'] for i in invoices}
for (fid_, n, pid, code, desc, q, u, pu, mt) in lines:
    d = inv_date[fid_]; mcost[(pid, D(d.year, d.month, 1))] += mt
EQ = {x['EquipementID']: x for x in equip}
for u in usage:
    d = u['DateUtilisation']; mcost[(u['ProjetID'], D(d.year, d.month, 1))] += u['Heures'] * EQ[u['EquipementID']]['TauxHoraireInterne']
pcost = defaultdict(list)
for (pid, m), v in mcost.items(): pcost[pid].append((m, v))
for pid in pcost: pcost[pid].sort()

# ------------------------------------------------------------------ FACTURATION CLIENTS + ENCAISSEMENTS
CL = {c['ClientID']: c for c in clients}
fc = []; enc = []
SEG_DELAY = {'Municipal': 42, 'Gouvernemental': 58, 'Institutionnel': 52, 'Immobilier': 36, 'Industriel': 44, 'Commerce': 31}
oc_by_p = defaultdict(list)
for o in ocs:
    if o['Statut'] == 'Approuvé': oc_by_p[o['ProjetID']].append(o)
seqfc = defaultdict(int)
def add_fc(p, d, typ, nodec, ht, ret):
    c = CL[p['ClientID']]
    seqfc[d.year] += 1
    net = round(ht - ret, 2)
    tps = round(net * TPS, 2); tvq = round(net * TVQ, 2)
    f = dict(FactureClientID=len(fc) + 1, NoFacture=f'FC{d.year % 100:02d}-{seqfc[d.year]:05d}', ProjetID=p['ProjetID'], ClientID=p['ClientID'],
             TypeFacture=typ, NoDecompte=nodec, DateFacture=d, DateEcheance=d + dt.timedelta(c['ConditionsPaiement']),
             MontantHT=round(ht, 2), Retenue=round(ret, 2), MontantNet=net, TPS=tps, TVQ=tvq, MontantTTC=round(net + tps + tvq, 2))
    fc.append(f)
    # paiement
    seg = CL[c['MaitreID']]['Segment'] if c['EstDoublon'] else c['Segment']
    delay = max(8, int(R.gauss(SEG_DELAY[seg] + (38 if CL[c['MaitreID']]['MauvaisPayeur'] else 0), 14)))
    pay = d + dt.timedelta(delay)
    f['Statut'] = 'Émise'; f['_last'] = d
    if (TODAY - d).days > 400 and R.random() < .004:
        f['Statut'] = 'En litige'; return
    if pay > TODAY: return
    mode = R.choice(['Virement', 'TEF', 'TEF']) if c['TypeClient'] == 'Public' else R.choice(['Chèque', 'Chèque', 'Virement', 'TEF'])
    if R.random() < .05 and f['MontantTTC'] > 2000:
        a1 = round(f['MontantTTC'] * R.uniform(.5, .85), 2)
        enc.append(dict(EncaissementID=len(enc) + 1, FactureClientID=f['FactureClientID'], DateEncaissement=pay, Montant=a1, ModePaiement=mode))
        pay2 = pay + dt.timedelta(R.randint(20, 60))
        f['Statut'] = 'Partiellement payée'; f['_last'] = pay
        if pay2 <= TODAY:
            enc.append(dict(EncaissementID=len(enc) + 1, FactureClientID=f['FactureClientID'], DateEncaissement=pay2, Montant=round(f['MontantTTC'] - a1, 2), ModePaiement=mode))
            f['Statut'] = 'Payée'; f['_last'] = pay2
    else:
        enc.append(dict(EncaissementID=len(enc) + 1, FactureClientID=f['FactureClientID'], DateEncaissement=pay, Montant=f['MontantTTC'], ModePaiement=mode))
        f['Statut'] = 'Payée'; f['_last'] = pay
pct_av = {}
for p in projets:
    if p['Statut'] == 'Soumission' or p['ProjetID'] not in pcost: continue
    series = pcost[p['ProjetID']]
    total_actual = sum(v for _, v in series)
    proj_total = total_actual if p['Statut'] in ('Terminé', 'Annulé') else max(p['CoutReelTotal'], total_actual * 1.02)
    bias = R.uniform(0, .07)
    cum = 0; billed = 0; ret_tot = 0; nodec = 0
    for m, v in series:
        cum += v
        me = month_end(m)
        if me > TODAY and p['Statut'] not in ('Terminé',): break
        rev = p['ValeurContrat'] + sum(o['Montant'] for o in oc_by_p[p['ProjetID']] if o['DateOC'] <= me)
        prog = min(1, cum / proj_total)
        if p['Statut'] == 'Annulé':
            target = cum / (1 - p['Marge'])
        else:
            target = min(rev * .998, rev * prog * (1 + bias * (1 - prog)))
        final = p['Statut'] == 'Terminé' and (m.year, m.month) == (p['FinReel'].year, p['FinReel'].month)
        if final: target = rev
        ht = target - billed
        if ht < 500 and not final: continue
        d = me if not final else min(TODAY, p['FinReel'] + dt.timedelta(R.randint(3, 20)))
        if d > TODAY: break
        nodec += 1
        ret = round(ht * .10, 2)
        add_fc(p, d, 'Décompte final' if final else 'Décompte progressif', nodec, ht, ret)
        billed += ht; ret_tot += ret
        pct_av[p['ProjetID']] = round(prog * 100, 1)
    if p['Statut'] == 'Terminé' and ret_tot > 0:
        d = p['FinReel'] + dt.timedelta(R.randint(35, 75))
        if d <= TODAY: add_fc(p, d, 'Libération de retenue', None, 0.0, -ret_tot)
print('factures clients', len(fc), 'encaissements', len(enc))

# ------------------------------------------------------------------ finalisation : horodatages + défauts de qualité volontaires
NOW = TODAY
def cap(t):  # horodatage jamais dans le futur
    return min(t, f'{TODAY.isoformat()} 23:59:00')
# --- feuilles de temps
ft.sort(key=lambda r: (r[1], r[0]))
COMM = ['Pluie — arrêt en après-midi', 'Formation SST', "Bris d'équipement", 'Livraison en retard', 'Inspection municipale', 'Réunion de chantier', 'Travail de nuit']
ft_rows = []
for (eid, d, pid, code, hr, hs) in ft:
    fri = d + dt.timedelta((4 - d.weekday()) % 7) if d.weekday() <= 4 else d
    created = f'{min(fri, TODAY).isoformat()} {R.randint(15, 18):02d}:{R.randint(0, 59):02d}:{R.randint(0, 59):02d}'
    appr = fri + dt.timedelta(R.randint(3, 6))
    st = 'Approuvé' if appr <= TODAY else 'Soumis'
    mod = f'{appr.isoformat()} {R.randint(8, 11):02d}:{R.randint(0, 59):02d}:{R.randint(0, 59):02d}' if st == 'Approuvé' else created
    ft_rows.append([eid, d, pid, code, hr, hs, st, R.choice(COMM) if R.random() < .015 else None, created, cap(mod), 0])
n = len(ft_rows)
extra = []
for i in R.sample(range(n), int(n * .004)):          # doublons exacts (double saisie)
    r = list(ft_rows[i]); r[8] = cap(r[8][:11] + f'{R.randint(19, 22)}:{R.randint(0,59):02d}:00'); extra.append(r)
for i in R.sample(range(n), int(n * .002)):          # saisie rejetée puis corrigée
    r = ft_rows[i]; c = list(r); r[6] = 'Rejeté'; r[7] = 'Mauvais code de coût'
    c[3] = CODE_ID['01-MO'] if c[2] else c[3]; c[9] = cap(c[9]); extra.append(c)
for i in R.sample(range(n), int(n * .0012)):         # heures aberrantes
    ft_rows[i][4] = R.choice([-8.0, 80.0, 88.0, 0.0])
for i in R.sample(range(n), int(n * .003)):          # lignes supprimées logiquement
    r = list(ft_rows[i]); r[10] = 1; r[6] = 'Soumis'; extra.append(r)
for i in R.sample(range(n), 6):                      # dates de travail impossibles (faute de frappe)
    r = list(ft_rows[i]); r[1] = D(2062, r[1].month, min(r[1].day, 28)); extra.append(r)
ft_rows += extra
ft_rows.sort(key=lambda r: (r[8], r[0]))
print('lignes de feuilles de temps', len(ft_rows))
# --- projets
for p in projets:
    p['CreatedAt'] = ts(p['DateDebutPrevue'] - dt.timedelta(R.randint(30, 100)))
    if p['Statut'] == 'Terminé': p['ModifiedAt'] = cap(ts(p['FinReel'] + dt.timedelta(R.randint(0, 25))))
    elif p['Statut'] == 'Soumission': p['ModifiedAt'] = cap(ts(TODAY - dt.timedelta(R.randint(0, 40))))
    elif p['Statut'] == 'Annulé': p['ModifiedAt'] = cap(ts(p['Annule'] + dt.timedelta(R.randint(0, 10))))
    else: p['ModifiedAt'] = cap(ts(TODAY - dt.timedelta(R.randint(0, 25))))
    p['DateDebutReelle'] = p['DebutReel'] if p['Statut'] != 'Soumission' else None
    p['DateFinReelle'] = p['FinReel'] if p['Statut'] == 'Terminé' else (p['Annule'] if p['Statut'] == 'Annulé' else None)
    pa = pct_av.get(p['ProjetID'])
    if p['Statut'] == 'Terminé': pa = 100.0
    if p['Statut'] in ('En cours', 'Suspendu') and pa is not None and R.random() < .12: pa = round(pa * R.uniform(.6, .9), 1)  # % jamais mis à jour
    if R.random() < .03: pa = None
    p['PourcentageAvancement'] = pa
    p['StatutSaisi'] = p['Statut']
    if R.random() < .03: p['StatutSaisi'] = p['Statut'].lower()
    if R.random() < .02: p['StatutSaisi'] = p['Statut'].upper() + ' '
    p['NomSaisi'] = p['NomProjet'] + ('  ' if R.random() < .04 else '')
for p in R.sample([p for p in projets if p['Statut'] == 'Terminé'], 3):   # date de fin saisie avec la mauvaise année
    p['DateFinReelle'] = D(p['DateFinReelle'].year - 9, p['DateFinReelle'].month, min(p['DateFinReelle'].day, 28))
# --- factures fournisseurs
FRN = {f['FournisseurID']: f for f in fourn}
fseq = defaultdict(int)
for inv in invoices:
    fr = FRN[inv['FournisseurID']]; fseq[inv['FournisseurID']] += 1; k = fseq[inv['FournisseurID']] + R.randint(0, 3)
    d = inv['DateFacture']; st = inv['FournisseurID'] % 4
    inv['NoFactureFourn'] = [f'{1000 + k * 7:06d}', f'INV-{d.year}-{k:05d}', f'FA{20000 + k}', f'{d.year % 100}{k:05d}-F'][st]
    inv['MontantHT'] = round(inv['HT'], 2)
    inv['TPS'] = round(inv['MontantHT'] * TPS, 2); inv['TVQ'] = round(inv['MontantHT'] * TVQ, 2)
    inv['MontantTTC'] = round(inv['MontantHT'] + inv['TPS'] + inv['TVQ'], 2)
    inv['DateEcheance'] = d + dt.timedelta(fr['ConditionsPaiement'])
    pay = inv['DateEcheance'] + dt.timedelta(int(R.gauss(4, 11)))
    if pay < d + dt.timedelta(3): pay = d + dt.timedelta(R.randint(3, 10))
    entered = min(TODAY, d + dt.timedelta(R.randint(1, 6)))
    inv['CreatedAt'] = ts(entered)
    if R.random() < .005: inv['Statut'] = 'En litige'; inv['DatePaiement'] = None; inv['ModifiedAt'] = inv['CreatedAt']
    elif pay <= TODAY: inv['Statut'] = 'Payée'; inv['DatePaiement'] = pay; inv['ModifiedAt'] = cap(ts(pay))
    else: inv['Statut'] = 'À payer'; inv['DatePaiement'] = None; inv['ModifiedAt'] = inv['CreatedAt']
    if R.random() < .003: inv['MontantHT'] = round(inv['MontantHT'] + R.choice([-.01, .01, .02]), 2)  # écart d'arrondi entête/lignes
line_rows = [list(l) for l in lines]
for r in line_rows:
    if R.random() < .008: r[3] = None  # code de coût manquant
dup_inv = []
for inv in R.sample([i for i in invoices if i['Statut'] == 'Payée'], 45):   # même facture saisie deux fois
    c = dict(inv); c['FactureFournID'] = len(invoices) + len(dup_inv) + 1
    c['CreatedAt'] = cap(ts(inv['DateFacture'] + dt.timedelta(R.randint(15, 40))))
    c['DatePaiement'] = min(TODAY, inv['DatePaiement'] + dt.timedelta(R.randint(5, 30))); c['ModifiedAt'] = cap(ts(c['DatePaiement']))
    dup_inv.append(c)
    for r in [x for x in line_rows if x[0] == inv['FactureFournID']]:
        rr = list(r); rr[0] = c['FactureFournID']; line_rows.append(rr)
invoices += dup_inv
print('factures fournisseurs (avec doublons)', len(invoices), 'lignes', len(line_rows))
for b in bcs:
    b['MontantTotal'] = round(b['MontantTotal'] * R.uniform(.98, 1.08), 2)
    b['CreatedAt'] = ts(b['DateBC']); p = P_ALL[b['ProjetID']]
    b['Statut'] = 'Fermé' if p['Statut'] in ('Terminé', 'Annulé') else 'Ouvert'
    if R.random() < .01: b['Statut'] = 'Annulé'
    b['ModifiedAt'] = cap(ts(p['CutEnd'])) if b['Statut'] != 'Ouvert' else b['CreatedAt']
# --- employés
for e in employes:
    e['Courriel'] = f"{slug(e['Prenom'])}.{slug(e['Nom'])}@constructionboreal.exemple.ca" if R.random() > .03 else None
    if R.random() < .05: e['Nom'] = e['Nom'].upper()
    e['CreatedAt'] = ts(max(e['DateEmbauche'], D(2018, 4, 15)))
    e['ModifiedAt'] = cap(ts(e['DateDepart'])) if e['DateDepart'] else cap(ts(max(e['DateEmbauche'], D(2018, 4, 15)) + dt.timedelta(R.randint(0, 900))))
for c in clients:
    c['CreatedAt'] = ts(D(R.randint(2012, 2018), R.randint(1, 12), R.randint(1, 28))) if not c['EstDoublon'] else ts(D(R.randint(2020, 2025), R.randint(1, 12), R.randint(1, 28)))
    c['ModifiedAt'] = c['CreatedAt'] if R.random() < .6 else cap(ts(D(R.randint(2019, 2026), R.randint(1, 10), R.randint(1, 28))))
for f in fourn:
    f['CreatedAt'] = ts(D(R.randint(2010, 2018), R.randint(1, 12), R.randint(1, 28))) if not f['EstDoublon'] else ts(D(R.randint(2021, 2025), R.randint(1, 12), R.randint(1, 28)))
    f['ModifiedAt'] = f['CreatedAt'] if R.random() < .6 else cap(ts(D(R.randint(2019, 2026), R.randint(1, 10), R.randint(1, 28))))
for x in equip:
    x['CreatedAt'] = ts(max(x['DateAcquisition'], D(2015, 1, 1))); x['ModifiedAt'] = cap(ts(x['DateDisposition'])) if x['DateDisposition'] else x['CreatedAt']
for f in fc:
    f['CreatedAt'] = ts(f['DateFacture']); f['ModifiedAt'] = cap(ts(f['_last']))
for e_ in enc:
    e_['NoReference'] = f"{'CHQ' if e_['ModePaiement'] == 'Chèque' else 'VIR'}-{R.randint(100000, 999999)}"
    e_['CreatedAt'] = cap(ts(e_['DateEncaissement'] + dt.timedelta(R.randint(0, 2)))); e_['ModifiedAt'] = e_['CreatedAt']
for u in usage:
    u['CreatedAt'] = cap(ts(u['DateUtilisation'], R.randint(16, 19))); u['ModifiedAt'] = u['CreatedAt']

# ------------------------------------------------------------------ ÉCRITURE DES CSV
DDIR = os.path.join(OUT, 'source_sqlserver', 'donnees'); os.makedirs(DDIR, exist_ok=True)
def fmt(v):
    if v is None: return ''
    if isinstance(v, bool): return '1' if v else '0'
    if isinstance(v, float): return f'{v:.6f}'.rstrip('0').rstrip('.') if abs(v - round(v, 2)) > 1e-9 else f'{v:.2f}'
    if isinstance(v, (dt.date,)): return v.isoformat()
    return str(v)
COUNTS = {}
def write(name, header, rows):
    path = os.path.join(DDIR, name + '.csv')
    with open(path, 'w', newline='', encoding='utf-8') as fh:
        w = csv.writer(fh, lineterminator='\n', quoting=csv.QUOTE_MINIMAL)
        w.writerow(header)
        k = 0
        for r in rows: w.writerow([fmt(x) for x in r]); k += 1
    COUNTS[name] = k
write('ref_Region', ['RegionID', 'NomRegion'], REGIONS)
write('ref_Ville', ['VilleID', 'NomVille', 'RegionID'], [(v[0], v[1], v[2]) for v in VILLES])
write('ref_Division', ['DivisionID', 'CodeDivision', 'NomDivision'], DIVISIONS)
write('ref_Metier', ['MetierID', 'CodeMetier', 'NomMetier', 'Categorie', 'EstSyndique'], [(m[0], m[1], m[2], m[3], m[6]) for m in METIERS])
write('ref_CodeCout', ['CodeCoutID', 'CodeCout', 'Description', 'TypeCout', 'CodeSection', 'NomSection'], CODES_COUT)
write('ref_ParametreCout', ['Annee', 'TauxChargesSociales', 'TauxTPS', 'TauxTVQ', 'TauxRetenue'], [(y, CHARGES[y], TPS, TVQ, .10) for y in range(2018, 2028)])
write('paie_Employe', ['EmployeID', 'Matricule', 'Prenom', 'Nom', 'Courriel', 'MetierID', 'DivisionID', 'VilleID', 'DateEmbauche', 'DateDepart', 'Statut', 'TypeEmploi', 'SuperviseurID', 'CreatedAt', 'ModifiedAt'],
      [(e['EmployeID'], e['Matricule'], e['Prenom'], e['Nom'], e['Courriel'], e['MetierID'], e['DivisionID'], e['VilleID'], e['DateEmbauche'], e['DateDepart'], e['Statut'], e['TypeEmploi'], e['SuperviseurID'], e['CreatedAt'], e['ModifiedAt']) for e in employes])
write('paie_TauxHoraire', ['TauxID', 'EmployeID', 'DateDebut', 'DateFin', 'TauxHoraire', 'CreatedAt', 'ModifiedAt'],
      [(t['TauxID'], t['EmployeID'], t['DateDebut'], t['DateFin'], t['TauxHoraire'], t['CreatedAt'], t['ModifiedAt']) for t in taux])
write('paie_FeuilleTemps', ['FeuilleTempsID', 'EmployeID', 'DateTravail', 'ProjetID', 'CodeCoutID', 'HeuresReg', 'HeuresSupp', 'Statut', 'Commentaire', 'CreatedAt', 'ModifiedAt', 'IsDeleted'],
      [[i + 1] + r for i, r in enumerate(ft_rows)])
write('vente_Client', ['ClientID', 'NoClient', 'NomClient', 'TypeClient', 'Segment', 'NEQ', 'Adresse', 'VilleID', 'CodePostal', 'Telephone', 'Courriel', 'ConditionsPaiement', 'LimiteCredit', 'CreatedAt', 'ModifiedAt'],
      [(c['ClientID'], c['NoClient'], c['NomClient'], c['TypeClient'], c['Segment'], c['NEQ'], c['Adresse'], c['VilleID'], c['CodePostal'], c['Telephone'], c['Courriel'], c['ConditionsPaiement'], float(c['LimiteCredit']), c['CreatedAt'], c['ModifiedAt']) for c in clients])
write('projet_Projet', ['ProjetID', 'NoProjet', 'NomProjet', 'ClientID', 'DivisionID', 'VilleID', 'ChargeProjetID', 'TypeContrat', 'ValeurContrat', 'DateDebutPrevue', 'DateFinPrevue', 'DateDebutReelle', 'DateFinReelle', 'Statut', 'PourcentageAvancement', 'CreatedAt', 'ModifiedAt'],
      [(p['ProjetID'], p['NoProjet'], p['NomSaisi'], p['ClientID'], p['DivisionID'], p['VilleID'], p['ChargeProjetID'], p['TypeContrat'], float(p['ValeurContrat']), p['DateDebutPrevue'], p['DateFinPrevue'], p['DateDebutReelle'], p['DateFinReelle'], p['StatutSaisi'], p['PourcentageAvancement'], p['CreatedAt'], p['ModifiedAt']) for p in projets])
write('projet_Budget', ['BudgetID', 'ProjetID', 'CodeCoutID', 'Version', 'Montant', 'CreatedAt', 'ModifiedAt'], [(b['BudgetID'], b['ProjetID'], b['CodeCoutID'], b['Version'], b['Montant'], b['CreatedAt'], b['ModifiedAt']) for b in budget])
write('projet_OrdreChangement', ['OrdreChangementID', 'ProjetID', 'NoOC', 'DateOC', 'Description', 'Montant', 'Statut', 'CreatedAt', 'ModifiedAt'],
      [(o['OrdreChangementID'], o['ProjetID'], o['NoOC'], o['DateOC'], o['Description'], o['Montant'], o['Statut'], o['CreatedAt'], cap(o['ModifiedAt'])) for o in ocs])
write('achat_Fournisseur', ['FournisseurID', 'NoFournisseur', 'NomFournisseur', 'Categorie', 'CodeSectionPrincipale', 'NEQ', 'VilleID', 'Telephone', 'Courriel', 'ConditionsPaiement', 'CreatedAt', 'ModifiedAt'],
      [(f['FournisseurID'], f['NoFournisseur'], f['NomFournisseur'], f['Categorie'], f['Specialite'], f['NEQ'], f['VilleID'], f['Telephone'], f['Courriel'], f['ConditionsPaiement'], f['CreatedAt'], f['ModifiedAt']) for f in fourn])
write('achat_BonCommande', ['BonCommandeID', 'NoBC', 'ProjetID', 'FournisseurID', 'DateBC', 'AcheteurID', 'Statut', 'MontantTotal', 'CreatedAt', 'ModifiedAt'],
      [(b['BonCommandeID'], b['NoBC'], b['ProjetID'], b['FournisseurID'], b['DateBC'], b['AcheteurID'], b['Statut'], b['MontantTotal'], b['CreatedAt'], b['ModifiedAt']) for b in bcs])
write('achat_FactureFournisseur', ['FactureFournID', 'NoFactureFourn', 'FournisseurID', 'BonCommandeID', 'DateFacture', 'DateEcheance', 'DatePaiement', 'MontantHT', 'TPS', 'TVQ', 'MontantTTC', 'Statut', 'CreatedAt', 'ModifiedAt'],
      [(i['FactureFournID'], i['NoFactureFourn'], i['FournisseurID'], i['BonCommandeID'], i['DateFacture'], i['DateEcheance'], i['DatePaiement'], i['MontantHT'], i['TPS'], i['TVQ'], i['MontantTTC'], i['Statut'], i['CreatedAt'], i['ModifiedAt']) for i in invoices])
INV = {i['FactureFournID']: i for i in invoices}
write('achat_FactureFournisseurLigne', ['LigneID', 'FactureFournID', 'NoLigne', 'ProjetID', 'CodeCoutID', 'Description', 'Quantite', 'Unite', 'PrixUnitaire', 'MontantLigne', 'CreatedAt', 'ModifiedAt'],
      [[k + 1] + r + [INV[r[0]]['CreatedAt'], INV[r[0]]['CreatedAt']] for k, r in enumerate(line_rows)])
write('vente_FactureClient', ['FactureClientID', 'NoFacture', 'ProjetID', 'ClientID', 'TypeFacture', 'NoDecompte', 'DateFacture', 'DateEcheance', 'MontantHT', 'Retenue', 'MontantNet', 'TPS', 'TVQ', 'MontantTTC', 'Statut', 'CreatedAt', 'ModifiedAt'],
      [(f['FactureClientID'], f['NoFacture'], f['ProjetID'], f['ClientID'], f['TypeFacture'], f['NoDecompte'], f['DateFacture'], f['DateEcheance'], f['MontantHT'], f['Retenue'], f['MontantNet'], f['TPS'], f['TVQ'], f['MontantTTC'], f['Statut'], f['CreatedAt'], f['ModifiedAt']) for f in fc])
write('vente_Encaissement', ['EncaissementID', 'FactureClientID', 'DateEncaissement', 'Montant', 'ModePaiement', 'NoReference', 'CreatedAt', 'ModifiedAt'],
      [(e_['EncaissementID'], e_['FactureClientID'], e_['DateEncaissement'], e_['Montant'], e_['ModePaiement'], e_['NoReference'], e_['CreatedAt'], e_['ModifiedAt']) for e_ in enc])
write('equip_Equipement', ['EquipementID', 'NoUnite', 'Description', 'Categorie', 'Marque', 'Modele', 'Annee', 'DateAcquisition', 'DateDisposition', 'TauxHoraireInterne', 'Statut', 'CreatedAt', 'ModifiedAt'],
      [(x['EquipementID'], x['NoUnite'], x['Description'], x['Categorie'], x['Marque'], x['Modele'], x['Annee'], x['DateAcquisition'], x['DateDisposition'], round(x['TauxHoraireInterne'], 2), x['Statut'], x['CreatedAt'], x['ModifiedAt']) for x in equip])
usage.sort(key=lambda u: (u['DateUtilisation'], u['EquipementID']))
write('equip_UtilisationEquipement', ['UtilisationID', 'EquipementID', 'ProjetID', 'DateUtilisation', 'Heures', 'OperateurID', 'CreatedAt', 'ModifiedAt'],
      [(k + 1, u['EquipementID'], u['ProjetID'], u['DateUtilisation'], u['Heures'], u['OperateurID'], u['CreatedAt'], u['ModifiedAt']) for k, u in enumerate(usage)])
print(COUNTS, 'TOTAL', sum(COUNTS.values()))

# ------------------------------------------------------------------ FICHIERS EXTERNES (pour Dataflow Gen2)
XDIR = os.path.join(OUT, 'fichiers_externes'); os.makedirs(XDIR, exist_ok=True)
IND = {'Municipal': 'Government Administration', 'Gouvernemental': 'Government Administration', 'Immobilier': 'Real Estate',
       'Commerce': 'Retail', 'Industriel': 'Manufacturing'}
owners = [e for e in employes if e['Metier'] in ('CPJ', 'DIR') and e['Statut'] != 'Inactif']
crm = []
def crm_name(n):
    n2 = n.replace(' inc.', '').replace(' ltée', '').replace(' et associés', '')
    return R.choice([n2, n2, n2.title(), n]) if R.random() < .7 else n
for c in clients[:N_CLIENT_MASTER]:
    if R.random() > .86: continue
    ind = IND.get(c['Segment']) or ('Hospital & Health Care' if 'CIUSSS' in c['NomClient'] else 'Education')
    created = D(R.randint(2019, 2024), R.randint(1, 12), R.randint(1, 28))
    crm.append([None, crm_name(c['NomClient']), c['NEQ'] if R.random() > .1 else '', ind, (lambda o: f"{o['Prenom']} {o['Nom'].title()}")(R.choice(owners)),
                'Customer', VILLE[c['VilleID']][1], R.choice([None, 6, 7, 7, 8, 8, 8, 9, 9, 10, 5, 4]),
                (TODAY - dt.timedelta(R.randint(1, 400))).strftime('%m/%d/%Y'), created.strftime('%m/%d/%Y')])
for r in R.sample(crm, 8):  # doublons dans le CRM
    d2 = list(r); d2[1] = d2[1].upper(); d2[7] = None; d2[8] = (TODAY - dt.timedelta(R.randint(200, 900))).strftime('%m/%d/%Y'); crm.append(d2)
k = 0
while k < 55:   # prospects absents de l'ERP
    nm = R.choice(tpl[R.choice(list(tpl))]).format(fam() if R.random() < .7 else R.choice(ADJ))
    if nm in used: continue
    used.add(nm); k += 1
    vid = pick_ville()
    crm.append([None, nm, neq('11') if R.random() < .6 else '', R.choice(['Real Estate', 'Retail', 'Manufacturing', 'Education']),
                (lambda o: f"{o['Prenom']} {o['Nom'].title()}")(R.choice(owners)), R.choice(['Lead', 'Opportunity', 'Opportunity']), VILLE[vid][1], None,
                (TODAY - dt.timedelta(R.randint(1, 200))).strftime('%m/%d/%Y'), (TODAY - dt.timedelta(R.randint(100, 700))).strftime('%m/%d/%Y')])
R.shuffle(crm)
for i, r in enumerate(crm): r[0] = 5_000_000_000 + i * 7 + R.randint(0, 6)
with open(os.path.join(XDIR, 'crm_export_companies.csv'), 'w', newline='', encoding='utf-8-sig') as fh:
    w = csv.writer(fh, lineterminator='\r\n')
    w.writerow(['Record ID', 'Company name', 'NEQ', 'Industry', 'Company owner', 'Lifecycle Stage', 'City', 'Satisfaction (1-10)', 'Last Activity Date', 'Create Date'])
    for r in crm: w.writerow(['' if x is None else x for x in r])
print('CRM', len(crm))
# Objectifs par division (Excel de la direction financière)
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
rev_dm = defaultdict(float)
for f in fc: rev_dm[(P_ALL[f['ProjetID']]['Div'], D(f['DateFacture'].year, f['DateFacture'].month, 1))] += f['MontantHT']
wb = Workbook(); ws = wb.active; ws.title = 'Objectifs CA'
ws['A1'] = "Construction Boréal inc. — Objectifs de chiffre d'affaires par division ($ avant taxes)"; ws['A1'].font = Font(bold=True, size=14)
ws['A2'] = 'Préparé par la direction financière — version approuvée par le conseil (ne pas modifier la structure)'; ws['A2'].font = Font(italic=True, color='666666')
mlist = []; m = D(2023, 5, 1)
while m <= D(2027, 4, 1): mlist.append(m); m = D(m.year + (m.month == 12), m.month % 12 + 1, 1)
ws.cell(4, 1, 'Division')
for j, m in enumerate(mlist):
    c = ws.cell(4, j + 2, m); c.number_format = 'mmm yyyy'
for c in ws[4]: c.font = Font(bold=True, color='FFFFFF'); c.fill = PatternFill('solid', fgColor='1F4E78')
for i, (did, code, nom) in enumerate(DIVISIONS[:5]):
    ws.cell(5 + i, 1, f'{code} - {nom}')
    for j, m in enumerate(mlist):
        hist = [rev_dm.get((code, D(y, m.month, 1)), 0) for y in range(2021, min(m.year, 2026))]
        base = np.mean(hist) if hist else 0
        val = round(base * 1.07 * R.uniform(.95, 1.08) / 5000) * 5000
        ws.cell(5 + i, j + 2, val).number_format = '#,##0'
ws.cell(10, 1, 'Total').font = Font(bold=True)
for j in range(len(mlist)):
    col = ws.cell(4, j + 2).column_letter
    ws.cell(10, j + 2, f'=SUM({col}5:{col}9)').number_format = '#,##0'
ws.column_dimensions['A'].width = 28
ws2 = wb.create_sheet('Objectifs marge')
ws2.append(['Division', 'EF 2023-2024', 'EF 2024-2025', 'EF 2025-2026', 'EF 2026-2027'])
for c in ws2[1]: c.font = Font(bold=True)
MT = {'RES': .115, 'COM': .085, 'INS': .075, 'IND': .095, 'GEN': .11}
for did, code, nom in DIVISIONS[:5]:
    ws2.append([code] + [round(MT[code] + R.uniform(-.006, .006), 3) for _ in range(4)])
    for c in ws2[ws2.max_row][1:]: c.number_format = '0.0%'
ws2.column_dimensions['A'].width = 12
wb.save(os.path.join(XDIR, 'Objectifs_divisions_EF2024-EF2027.xlsx'))
print('ok')
