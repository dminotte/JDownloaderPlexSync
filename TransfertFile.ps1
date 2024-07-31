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
$MoviesLibraryKey = '1'  # Clé de la bibliothèque pour les films dans Plex
$SeriesLibraryKey = '2'  # Clé de la bibliothèque pour les séries dans Plex

# ========================================
# Chemins Distants pour le SFTP
# ========================================
$MoviesRemotePath = ''  # Chemin distant pour les films
$SeriesRemotePath = ''  # Chemin distant pour les séries

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
$LogDir = ""  # Répertoire de stockage des fichiers de log
$LogFilePath = Join-Path -Path $LogDir -ChildPath "TransferFile-$(get-date -f dd.MM.yyyy-HH.mm.ss).log"  # Chemin du fichier log actuel

# Fonction pour écrire dans un fichier log avec gestion de compression et suppression
function Write-Log {
    param (
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $Message"

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
        try {
            if (-not $session.FileExists($RemoteDirPath)) {
                $session.CreateDirectory($RemoteDirPath)
                Write-Log "Répertoire distant créé: $RemoteDirPath"
            } else {
                Write-Log "Le répertoire distant existe déjà: $RemoteDirPath"
            }
        } catch {
            Write-Log "Erreur lors de la création du répertoire distant: $_"
            exit 1
        }
    } else {
        Write-Log "Erreur: La session WinSCP n'est pas initialisée."
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

    $global:session = New-Object WinSCP.Session

    try {
        $session.Open($sessionOptions)
        Write-Log "Session WinSCP ouverte avec succès."
    } catch {
        Write-Log "Erreur lors de l'ouverture de la session WinSCP: $_"
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
        Write-Log "Erreur: La session WinSCP n'est pas initialisée."
        exit 1
    }

    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    try {
        if ($session.FileExists($RemoteFilePath)) {
            Write-Log "Erreur: Le fichier distant existe déjà: $RemoteFilePath"
            exit 1
        }
        $transferResult = $session.PutFiles($LocalFilePath, $RemoteFilePath, $False, $transferOptions)
        $transferResult.Check()
        Write-Log "Fichier transféré avec succès: $RemoteFilePath"
    } catch {
        Write-Log "Erreur de transfert: $_"
        exit 1
    }
}

# Fonction pour scanner la bibliothèque Plex
function Scan-PlexLibrary {
    param (
        [string]$LibraryKey
    )

    $plexUrl = "$PlexServerAddress/library/sections/$LibraryKey/refresh?X-Plex-Token=$PlexToken"
    try {
        $response = Invoke-RestMethod -Uri $plexUrl -Method Get
        Write-Log "Scan de la bibliothèque Plex lancé."
    } catch {
        Write-Log "Erreur lors de la demande de scan Plex: $_"
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
        Write-Log "Fichier local supprimé: $LocalFilePath"
    } else {
        Write-Log "Le fichier local n'existe pas: $LocalFilePath"
    }
}

# Exécution du script
try {
    # Charger la bibliothèque WinSCP
    Add-Type -Path $WinSCPLibPath

    # Initialiser la session
    Initialize-Session

    # Déterminer le type de fichier et le chemin distant
    if ($LocalFilePath -match "films") {
        $RemoteFilePath = $MoviesRemotePath + (Get-Item $LocalFilePath).Name
        $LibraryKey = $MoviesLibraryKey
    } elseif ($LocalFilePath -match "series") {
        # Extraire le chemin relatif pour les séries
        $LocalFileDir = Split-Path -Path $LocalFilePath -Parent
        $SeriesRelativePath = $LocalFileDir -replace [regex]::Escape((Split-Path -Path $LocalFileDir -Leaf) + "\"), ""
        $RemoteDirPath = $SeriesRemotePath + [System.IO.Path]::GetFileName($SeriesRelativePath)
        $RemoteFilePath = $RemoteDirPath + "/" + (Get-Item $LocalFilePath).Name
        $LibraryKey = $SeriesLibraryKey

        # Créer le répertoire distant pour les séries si nécessaire
        Create-RemoteDirectory -RemoteDirPath $RemoteDirPath
    } else {
        Write-Log "Erreur: Type de fichier inconnu pour $LocalFilePath"
        exit 1
    }

    # Afficher les valeurs des variables pour débogage
    Write-Log "Chemin local du fichier: $LocalFilePath"
    Write-Log "Chemin distant du fichier: $RemoteFilePath"

    # Vérifier si le fichier local existe
    if (-not (Test-Path $LocalFilePath)) {
        Write-Log "Le fichier local n'existe pas: $LocalFilePath"
        exit 1
    }

    # Transférer le fichier
    Transfer-File -LocalFilePath $LocalFilePath -RemoteFilePath $RemoteFilePath

    # Scanner la bibliothèque Plex
    Scan-PlexLibrary -LibraryKey $LibraryKey

    # Suppression du fichier local après un transfert réussi
    Remove-LocalFile -LocalFilePath $LocalFilePath

} catch {
    Write-Log "Erreur: $_"
    exit 1
} finally {
    # Fermer la session
    if ($session -ne $null) {
        $session.Dispose()
        Write-Log "Session WinSCP fermée."
    }
}
