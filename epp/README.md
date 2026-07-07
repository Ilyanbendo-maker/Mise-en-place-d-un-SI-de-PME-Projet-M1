# Protection des postes : ESET Protect (EPP / EDR)

## Role dans l'infrastructure

La brique EPP protege le parc de cercueil.fun contre les menaces logicielles connues. Elle repose sur ESET Protect : un serveur central administre a distance des agents installes sur les postes de travail et sur les serveurs, Windows comme Debian. Le meme canal sert a deployer deux modules de securite sur chaque machine : la protection de terminal EPP (antivirus, protection du systeme de fichiers en temps reel) et le module EDR de detection et de reponse.

Le serveur est place dans le VLAN 50, la zone Securite du LAN, aux cotes du SIEM Graylog, derriere le pare-feu interne FW_2. Ce positionnement isole les outils de securite des VLAN utilisateurs et serveurs qu'ils surveillent. La solution retenue est le bundle ESET Protect Entry (licence 390 euros/an pour le parc), obtenu aupres de l'editeur pour la maquette.

Les deux fonctions sont complementaires et volontairement portees par le meme editeur :

- EPP (Endpoint Protection Platform) : protection preventive de chaque terminal contre les menaces connues (signatures, analyse du systeme de fichiers, protection en temps reel) ;
- EDR (Endpoint Detection and Response) : detection de comportements suspects a l'echelle du parc et capacite d'investigation et de reponse depuis la console.

## Machine

| VM | Role | IP | VLAN |
|----|------|----|------|
| ESET-Protect | Serveur d'administration ESET Protect (console web) | non figee dans la documentation (plage 10.0.50.0/24) | 50 |

La VM fonctionne en continu et consomme environ 3,91 Go de RAM en regime etabli, ce qui en fait l'une des machines les plus consommatrices de la zone Securite dans le bilan d'eco-conception du projet.

## Architecture et fonctionnement

### Modele serveur central / agents

L'administration se fait exclusivement depuis la console web du serveur ESET Protect. Chaque machine protegee execute un agent de management qui etablit la liaison vers le serveur : l'inventaire, l'etat de protection, les detections et les taches de deploiement transitent par ce canal. Une interface graphique locale ESET reste disponible sur chaque client pour consultation ; une politique poussee depuis la console permet de la desactiver afin d'empecher toute manipulation locale de la protection.

### Enrolement et deploiement des modules

L'agent est diffuse sous forme de script d'installation genere par la console (section Programme d'installation), identique dans son principe pour Windows et pour Debian. Une fois l'agent en place, la machine remonte automatiquement dans la console ; une machine absente de l'inventaire signale en pratique un flux bloque au niveau des pare-feux. Les modules de securite sont ensuite pousses depuis la console, sans intervention locale : menu Ordinateur, Modules de plateforme, Deployer, qui installe EPP et EDR sur la cible selectionnee.

### Cas des serveurs Debian avec Secure Boot

Sur Debian, la protection du systeme de fichiers en temps reel d'ESET Server Security s'appuie sur des modules noyau. Avec Secure Boot actif, ces modules doivent etre signes par une cle enregistree dans le firmware UEFI, faute de quoi l'agent remonte l'erreur "File System Protection not activated". Le produit fournit un script de signature qui genere une paire de cles MOK (Machine Owner Key) et prepare son enrolement :

```bash
# Signature des modules noyau ESET (ESET Server Security pour Linux)
sudo /opt/eset/efs/lib/install_scripts/sign_modules.sh
# Do you have your own keys?                     -> N   (pas de PKI de signature dediee)
# Generate new keys?                             -> Y   (paire MOK generee localement)
# Enroll the generated public key semiautomatically? -> Y
# Password :                                     mot de passe a usage unique, defini a cette etape
# Save keys to hard drive?                       -> N   (la cle privee n'est pas conservee)
# Reboot now?                                    -> Y
```

Au redemarrage, le firmware ouvre le menu MOK Management : l'enrolement de la cle publique y est confirme avec le mot de passe a usage unique defini ci-dessus, puis la machine redemarre avec les modules ESET charges. La cle privee n'etant pas conservee sur le disque, une regeneration complete est necessaire en cas de mise a jour majeure des modules.

## Interactions avec les autres briques

- Pare-feux : les agents des VLAN utilisateurs et serveurs doivent joindre le serveur ESET-Protect en VLAN 50 a travers FW_2. Ce flux inter-VLAN est la premiere cause verifiee quand un agent ne remonte pas dans la console.
- Proxy : les machines internes n'ont pas d'acces direct a Internet. Le proxy Squid autorise explicitement le domaine .eset.com dans sa liste de depots (`no_connection.conf`, aux cotes des depots Debian, Fedora et Veeam), ce qui permet aux clients et au serveur de recuperer signatures et modules sans ouverture de flux generale.
- Active Directory : un compte de service `svc_eset_auth` est reserve en tier T0 dans l'annuaire cercueil.local, au meme niveau que le compte de sauvegarde Veeam. Son role precis (synchronisation de l'inventaire ou authentification sur la console) n'est pas documente.
- SIEM : le serveur partage le VLAN 50 avec Graylog, conformement au decoupage par criticite retenu lors de la conception (zone Securite regroupant SIEM, EPP et EDR).

## Etat et limites

- Le serveur ESET Protect est installe et sous licence, les agents remontent dans la console et les modules EPP et EDR se deploient depuis celle-ci sur les deux familles d'OS du parc.
- L'adresse IP du serveur n'a pas ete figee dans le tableau d'adressage du projet, qui ne retient que son VLAN.
- Le compte de service `svc_eset_auth` est cree mais son usage n'est pas decrit dans la documentation AD ; l'integration annuaire reste donc a l'etat d'ebauche.
- La documentation ne decrit ni les politiques de detection appliquees ni de raccordement des alertes ESET vers le SIEM ; la partie EDR est operee avec les reglages par defaut du produit.
- La procedure MOK est necessaire sur chaque serveur Debian a Secure Boot actif ; elle exige une intervention en console au redemarrage et reste donc manuelle, machine par machine.
