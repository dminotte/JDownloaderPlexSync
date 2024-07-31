# JDownloaderPlexSync

## Description
Ce projet automatise le transfert de fichiers multimédias depuis une machine locale vers un serveur Plex en utilisant WinSCP pour les transferts de fichiers SFTP. Il gère également le scan de la bibliothèque Plex pour s'assurer que le nouveau contenu est reconnu. Le script peut différencier les films et les séries et les organiser en conséquence.

## Fonctionnalités
- Transfert Automatique de Fichiers : Télécharge les fichiers depuis un répertoire local vers un serveur Plex.
- Scan de Bibliothèque Plex : Lance un scan de la bibliothèque Plex appropriée (Films ou Séries) après le transfert de fichiers.
- Journalisation : Fournit une journalisation détaillée avec rotation des fichiers pour un suivi et un dépannage faciles.
- Gestion des Erreurs : Inclut une gestion des erreurs robuste et des notifications en cas de problèmes.
- Suppression de Fichiers Locaux : Supprime les fichiers locaux après un transfert réussi.
- Suppression du Lien JDownloader : Supprime le lien de téléchargement dans JDownloader après un transfert réussi.

## Prérequis
WinSCP : Téléchargez et installez WinSCP et assurez-vous que WinSCPnet.dll est disponible.

Serveur Plex : Accès à un serveur Plex avec un jeton API.

## Installation

### Installer WinSCP :
Téléchargez et installez WinSCP depuis le site officiel de WinSCP.

Assurez-vous que WinSCPnet.dll est installé dans C:\Program Files (x86)\WinSCP\.

### Préparer le Script PowerShell :
Enregistrez le script PowerShell TransferFile.ps1 dans un répertoire approprié.

### Configurer le Serveur Plex :
Obtenez votre jeton API Plex (voir section ci-dessous) et l'adresse du serveur.

### Configurer JDownloader :
Configurez JDownloader pour appeler le script PowerShell à la fin du téléchargement. (Voir les instructions spécifiques à JDownloader pour cette configuration).

## Trouver le Jeton API Plex
[Trouver le Jeton API](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token)

Utilisez ce jeton dans le script PowerShell en le remplaçant dans la variable $PlexToken.

## Configuration de JDownloader
### Configurer JDownloader pour Appeler le Script PowerShell :

Vous devez ajouter un script d'événement dans JDownloader pour appeler le script PowerShell lorsque le téléchargement est terminé.

### Script d'Événement JDownloader :

Voici un exemple de script JavaScript que vous pouvez utiliser dans JDownloader pour appeler le script PowerShell après un téléchargement réussi :
```javascript
// Script JDownloader pour appeler le script PowerShell

// Définissez le chemin d'accès au script
var powershellPath = "powershell.exe";
var scriptPath = "C:\\chemin\\vers\\votre\\script\\TransferFile.ps1";

// Récupérez le chemin local du fichier téléchargé
var localFilePath = link.getDownloadPath();

// Vérifiez si le téléchargement est terminé
if (link.isFinished()) {
    // Construit la commande pour appeler PowerShell avec les arguments appropriés
    var command = [
        powershellPath,
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        scriptPath,
        "-LocalFilePath",
        '"' + localFilePath + '"'
    ];

    // Appeler PowerShell avec les arguments construits
    callAsync(function(exitCode, stdOut, errOut) {
        if (exitCode === 0) {
            link.remove();
        } else {
            alert("Erreur à l'exécution du script: " + errOut);
        }
    }, command);
}
```
### Pour ajouter ce script dans JDownloader :
1. Ouvrez JDownloader.
2. Accédez à "Paramètres" > "Extensions" > "Event Scripter".
3. Cliquez sur "Ajouter" et collez le script JavaScript dans l'éditeur.
4. Sauvegardez les modifications.

## Configuration

Avant d'utiliser le script, assurez-vous de configurer les variables nécessaires dans le script PowerShell.

### Variables

- `$PlexToken` : Token d'accès pour le serveur Plex.
- `$SftpHost` : Adresse du serveur SFTP.
- `$Port` : Numéro de port pour la connexion SFTP.
- `$Username` : Nom d'utilisateur pour la connexion SFTP.
- `$Password` : Mot de passe pour la connexion SFTP.
- `$PlexServerAddress` : Adresse du serveur web Plex.
- `$MoviesLibraryName` : Nom de la bibliothèque de films sur Plex (Optionnel).
- `$MoviesLibraryKey` : Clé de la bibliothèque de films sur Plex.
- `$SeriesLibraryName` : Nom de la bibliothèque de séries sur Plex (Optionnel).
- `$SeriesLibraryKey` : Clé de la bibliothèque de séries sur Plex.
- `$MoviesRemotePath` : Chemin distant pour les films sur le serveur Plex.
- `$SeriesRemotePath` : Chemin distant pour les séries sur le serveur Plex.
- `$WinSCPLibPath` : Chemin vers la bibliothèque `WinSCPnet.dll`. (si non installer par défaut)

### Variables de Gestion des Logs
- `$LogDir` : Répertoire où les fichiers de log sont stockés. Exemple : C:\Users\XXXXX\Downloads\plex\logs.
- `$MaxLogFiles` : Nombre maximal de fichiers de log à conserver. Lorsque ce nombre est atteint, les fichiers les plus anciens seront compressés ou supprimés. Exemple : 10.
- `$MaxLogDays` : Nombre de jours pour conserver les fichiers de log avant compression ou suppression. Exemple : 7 jours.
- `$CompressedRetentionDays` : Nombre de jours pour conserver les fichiers compressés avant suppression. Exemple : 30 jours.

## Sécurité SSH
### Acceptation de Clé SSH
Lors de la connexion à un serveur SFTP, il est important de gérer correctement les clés SSH pour assurer la sécurité des transferts.(ligne 141)

### Serveur sur le Réseau Local :
Pour les connexions à des serveurs SFTP sur le même réseau local, vous pouvez configurer WinSCP pour accepter automatiquement n'importe quelle clé SSH en utilisant la variable `$sessionOptions.GiveUpSecurityAndAcceptAnySshHostKey = $true`.

### Serveur à Distance :
Pour des connexions à des serveurs SFTP distants, il est recommandé de spécifier et accepter la clé SSH de l'hôte pour éviter des risques de sécurité. Voici comment vous pouvez ajouter et accepter la clé SSH :

```powershell
$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Sftp
    HostName = $SftpHost
    PortNumber = $Port
    UserName = $Username
    Password = $Password
    SshHostKeyFingerprint = "ssh-rsa 2048 xxxxxxxxxxxxxxxxxxxxxxx="
}
```

## Exemple de Configuration

```powershell
$PlexToken = 'votre_token_plex'
$SftpHost = '168.16.1.15'
$Port = 22
$Username = 'votre_nom_utilisateur'
$Password = 'votre_mot_de_passe'
$PlexServerAddress = 'http://168.16.1.15:32400'

$MoviesLibraryName = 'Films'
$MoviesLibraryKey = '1'
$SeriesLibraryName = 'Séries'
$SeriesLibraryKey = '2'

$MoviesRemotePath = '/var/lib/plexmediaserver/films/'
$SeriesRemotePath = '/var/lib/plexmediaserver/series/'

$LogDir = "C:\Users\XXXXX\Downloads\plex\logs"
$MaxLogFiles = 10
$MaxLogDays = 7
$CompressedRetentionDays = 30

```

## Gestion des Erreurs
Si le script rencontre des problèmes, tels que des erreurs de transfert ou des problèmes de connectivité, il enregistre des messages d'erreur détaillés. Consultez le fichier journal pour les informations de dépannage.

## Contribuer
Les contributions sont les bienvenues ! Si vous avez des suggestions ou des améliorations, veuillez soumettre une demande de tirage ou ouvrir un problème sur le dépôt GitHub.

## Licence
Ce projet est sous la Licence MIT. Consultez le fichier LICENSE pour plus de détails.
