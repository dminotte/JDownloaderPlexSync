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
