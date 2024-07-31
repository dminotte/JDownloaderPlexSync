param (
    [string]$LocalFilePath
)

# ========================================
# Configuration de Plex
# ========================================
$PlexToken = ''  # Token d'authentification pour Plex
$PlexServerAddress = ''  # Adresse de votre serveur Plex

# ========================================
# Configuration SFTP
# ========================================
$SftpHost = ''  # Adresse de l'hôte SFTP
$Port = 22  # Port de connexion SFTP
$Username = ''  # Nom d'utilisateur pour la connexion SFTP
$Password = ''  # Mot de passe pour la connexion SFTP

# ========================================
# Clés de Bibliothèque Plex
# ========================================
$FilmsLibraryKey = '1'  # Clé de la bibliothèque pour les films dans Plex
$SeriesLibraryKey = '2'  # Clé de la bibliothèque pour les séries dans Plex
# Dictionnaire des noms des bibliothèques Plex
$LibraryNames = @{
    '1' = 'Films'
    '2' = 'Series'
}
# ========================================
# Chemins Distants pour le SFTP
# ========================================
$MoviesRemotePath = '/var/lib/plexmediaserver/films/'  # Chemin distant pour les films
$SeriesRemotePath = '/var/lib/plexmediaserver/series/'  # Chemin distant pour les séries

# ========================================
# Chemin de la Bibliothèque WinSCP
# ========================================
$WinSCPLibPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"  # Chemin vers WinSCPnet.dll

# ========================================
# Configuration de la Gestion des Logs
# ========================================
# Mode de rétention des logs : "nombre" ou "jours"
$RetentionMode = "jours"  # Choix entre "nombre" et "jours"
# Nombre maximal de fichiers de log à conserver (si RetentionMode est "nombre")
$MaxLogFiles = 10  # Conserver jusqu'à 10 fichiers de log
# Nombre de jours pour conserver les fichiers de log (si RetentionMode est "jours")
$MaxLogDays = 7  # Conserver les fichiers de log pendant 7 jours
# Nombre de jours pour conserver les fichiers compressés avant suppression
$CompressedRetentionDays = 30  # Conserver les fichiers compressés pendant 30 jours
# Chemin du répertoire de logs
$LogDir = "C:\Users\XXXX\Downloads\plex\logs"  # Répertoire de stockage des fichiers de log
$LogFilePath = Join-Path -Path $LogDir -ChildPath "TransferFile-$(get-date -f dd.MM.yyyy-HH.mm.ss).log"  # Chemin du fichier log actuel

# Fonction pour écrire dans un fichier log avec gestion de compression et suppression
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] - $Message"

    # Ajouter le message au fichier de log actuel
    Add-Content -Path $LogFilePath -Value $logMessage

    # Gestion de la rétention des logs
    $logFiles = Get-ChildItem -Path $LogDir -Filter "TransferFile-*.log"

    if ($RetentionMode -eq "nombre") {
        # Compresser les anciens fichiers si le nombre dépasse la limite
        if ($logFiles.Count -ge $MaxLogFiles) {
            $filesToCompress = $logFiles | Sort-Object -Property LastWriteTime | Select-Object -First ($logFiles.Count - $MaxLogFiles)
            foreach ($file in $filesToCompress) {
                $zipFile = "$($file.FullName).zip"
                if (-not (Test-Path $zipFile)) {
                    Compress-Archive -Path $file.FullName -DestinationPath $zipFile
                    Remove-Item -Path $file.FullName -Force
                }
            }
        }
    } elseif ($RetentionMode -eq "jours") {
        # Compresser les anciens fichiers si la date de création dépasse la limite
        $expirationDate = (Get-Date).AddDays(-$MaxLogDays)
        $filesToCompress = $logFiles | Where-Object { $_.LastWriteTime -lt $expirationDate }
        foreach ($file in $filesToCompress) {
            $zipFile = "$($file.FullName).zip"
            if (-not (Test-Path $zipFile)) {
                Compress-Archive -Path $file.FullName -DestinationPath $zipFile
                Remove-Item -Path $file.FullName -Force
            }
        }
    }

    # Gestion des fichiers compressés : suppression après X jours
    $compressedFiles = Get-ChildItem -Path $LogDir -Filter "TransferFile-*.log.zip"
    $expirationDate = (Get-Date).AddDays(-$CompressedRetentionDays)
    foreach ($file in $compressedFiles) {
        if ($file.LastWriteTime -lt $expirationDate) {
            Remove-Item -Path $file.FullName -Force
        }
    }
}

# Fonction pour créer un répertoire distant
function Create-RemoteDirectory {
    param (
        [string]$RemoteDirPath
    )
    
    if ($session -ne $null) {
        Write-Log -Message "Vérification ou création du répertoire distant : $RemoteDirPath" -Level "DEBUG"
        try {
            if (-not $session.FileExists($RemoteDirPath)) {
                Write-Log -Message "Tentative de création du répertoire distant" -Level "INFO"
                $session.CreateDirectory($RemoteDirPath)
                Write-Log -Message "Répertoire distant créé: $RemoteDirPath" -Level "INFO"
            } else {
                Write-Log -Message "Le répertoire distant existe déjà: $RemoteDirPath" -Level "INFO"
            }
        } catch {
            Write-Log -Message "Problème lors de la création du répertoire distant: $_" -Level "ERROR"
            exit 1
        }
    } else {
        Write-Log -Message "La session WinSCP n'est pas initialisée." -Level "ERROR"
        exit 1
    }
}

# Fonction pour initialiser la session WinSCP
function Initialize-Session {
    $sessionOptions = New-Object WinSCP.SessionOptions
    $sessionOptions.Protocol = [WinSCP.Protocol]::Sftp
    $sessionOptions.HostName = $SftpHost
    $sessionOptions.PortNumber = $Port
    $sessionOptions.UserName = $Username
    $sessionOptions.Password = $Password

    $sessionOptions.GiveUpSecurityAndAcceptAnySshHostKey = $true
    Write-Log -Message "Configuration SFTP : Hôte=$SftpHost, Port=$Port, Utilisateur=$Username" -Level "DEBUG"
    $global:session = New-Object WinSCP.Session

    try {
        Write-Log -Message "Tentative de connexion au SFTP : $SftpHost." -Level "INFO"
        $session.Open($sessionOptions)
        Write-Log -Message "Session WinSCP ouverte avec succès." -Level "INFO"
    } catch {
        Write-Log -Message "Echec de la connexion SFTP. Hôte : $SftpHost, Port : $Port" -Level "ERROR"
        Write-Log -Message "Erreur lors de l'ouverture de la session WinSCP: $_" -Level "ERROR"
        exit 1
    }
}

# Fonction pour transférer un fichier
function Transfer-File {
    param (
        [string]$LocalFilePath,
        [string]$RemoteFilePath
    )

    if ($session -eq $null) {
        Write-Log -Message "La session WinSCP n'est pas initialisée." -Level "ERROR"
        exit 1
    }

    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    try {
        Write-Log -Message "Vérification de l'existence du fichier distant : $RemoteFilePath" -Level "DEBUG"
        if ($session.FileExists($RemoteFilePath)) {
            Write-Log -Message "Le fichier distant existe déjà: $RemoteFilePath" -Level "ERROR"
            exit 1
        }
        Write-Log -Message "Le fichier distant n'existe pas, prêt à démarrer le transfert." -Level "DEBUG"
        Write-Log -Message "Début du transfert du fichier local : $LocalFilePath vers $RemoteFilePath" -Level "INFO"
        $transferResult = $session.PutFiles($LocalFilePath, $RemoteFilePath, $False, $transferOptions)
        $transferResult.Check()
        Write-Log -Message "Transfert du fichier terminé avec succès : $RemoteFilePath" -Level "INFO"
    } catch {
        Write-Log -Message "Erreur de transfert: $_" -Level "ERROR"
        exit 1
    }
}

# Fonction pour scanner la bibliothèque Plex
function Scan-PlexLibrary {
    param (
        [string]$LibraryKey
    )
    $libraryName = $LibraryNames[$LibraryKey]
    Write-Log -Message "Configuration du serveur Plex : $PlexServerAddress avec le token fourni." -Level "DEBUG"
    $plexUrl = "$PlexServerAddress/library/sections/$LibraryKey/refresh?X-Plex-Token=$PlexToken"
    try {
        Write-Log -Message "Connexion au serveur Plex : $PlexServerAddress" -Level "INFO"
        $response = Invoke-RestMethod -Uri $plexUrl -Method Get
        Write-Log -Message "Scan de la bibliothèque Plex ($libraryName) lancé pour la clé $LibraryKey." -Level "INFO"
    } catch {
        Write-Log -Message "Erreur lors de la demande de scan Plex pour la bibliothèque $libraryName : $_" -Level "ERROR"
        exit 1
    }
}

# Fonction pour supprimer un fichier local
function Remove-LocalFile {
    param (
        [string]$LocalFilePath
    )

    if (Test-Path $LocalFilePath) {
        Remove-Item -Path $LocalFilePath -Force
        Write-Log -Message "Fichier local supprimé: $LocalFilePath" -Level "INFO"
    } else {
        Write-Log -Message "Le fichier local n'existe pas: $LocalFilePath" -Level "WARNING"
    }
}

# Exécution du script
try {
    Write-Log -Message "Variables de configuration : $($PlexToken), $($SftpHost), $($Port), $($Username)" -Level "DEBUG"
    # Charger la bibliothèque WinSCP
    Add-Type -Path $WinSCPLibPath

    # Initialiser la session
    Initialize-Session

    # Déterminer le type de fichier et le chemin distant
    if ($LocalFilePath -match "films") {
        Write-Log -Message "Construction des variables pour la catégories Films" -Level "INFO"
        $RemoteFilePath = $MoviesRemotePath + (Get-Item $LocalFilePath).Name
        $LibraryKey = $FilmsLibraryKey
    } elseif ($LocalFilePath -match "series") {
        Write-Log -Message "Construction des variables pour la catégories Series" -Level "INFO"
        # Extraire le chemin relatif pour les séries
        $LocalFileDir = Split-Path -Path $LocalFilePath -Parent
        $SeriesRelativePath = $LocalFileDir -replace [regex]::Escape((Split-Path -Path $LocalFileDir -Leaf) + "\"), ""
        $RemoteDirPath = $SeriesRemotePath + [System.IO.Path]::GetFileName($SeriesRelativePath)
        $RemoteFilePath = $RemoteDirPath + "/" + (Get-Item $LocalFilePath).Name
        $LibraryKey = $SeriesLibraryKey

        # Créer le répertoire distant pour les séries si nécessaire
        Create-RemoteDirectory -RemoteDirPath $RemoteDirPath
    } else {
        Write-Log -Message "Type de fichier inconnu pour $LocalFilePath" -Level "ERROR"
        exit 1
    }

    # Afficher les valeurs des variables pour débogage
    Write-Log -Message "Chemin local du fichier: $LocalFilePath" -Level "DEBUG"
    Write-Log -Message "Chemin distant du fichier: $RemoteFilePath" -Level "DEBUG"

    # Vérifier si le fichier local existe
    if (-not (Test-Path $LocalFilePath)) {
        Write-Log -Message "Le fichier local n'existe pas: $LocalFilePath" -Level "ERROR"
        exit 1
    }

    # Transférer le fichier
    Transfer-File -LocalFilePath $LocalFilePath -RemoteFilePath $RemoteFilePath

    # Scanner la bibliothèque Plex
    Scan-PlexLibrary -LibraryKey $LibraryKey

    # Suppression du fichier local après un transfert réussi
    Remove-LocalFile -LocalFilePath $LocalFilePath

} catch {
    Write-Log -Message "Erreur: $_" -Level "ERROR"
    exit 1
} finally {
    # Fermer la session
    if ($session -ne $null) {
        $session.Dispose()
        Write-Log -Message "Session WinSCP fermée." -Level "INFO"
        Write-Log -Message "Le script s'est terminé avec succès." -Level "INFO"
    }
}
