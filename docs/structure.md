# PowerPack Structure

## Introduction
This document explains the local folder structure of a PowerPack, including its files, directories, and how it interacts with the CapaInstaller environment.
It is intended as a practical reference for both developers and the custom ChatGPT assistant.

PowerPacks are stored and managed through CapaInstaller but also exist locally on the file system when created, modified, or executed.
While the **Install** and **Uninstall** scripts are stored in the database, supporting files and logs are managed locally.

## Folder Overview
A typical PowerPack directory follows this structure:

```txt
PowerPackName/PowerPackVersion/
├── Kit/
│   └── (optional supporting files, such as binaries, scripts, or configuration data)
├── Scripts/
│   └── (empty – Install and Uninstall scripts are stored in the CapaInstaller database)
└── Zip/
    └── CapaInstaller.kit
```


## Kit Folder

Contains optional supporting content required by the PowerPack during execution.
This can include external tools, configuration files, or other assets used by the script.
These files are packaged as part of the .kit archive when the PowerPack is exported or deployed.

## Scripts Folder
This folder is typically empty, as PowerPack scripts (Install.ps1, Uninstall.ps1) are stored in the CapaInstaller database.
The file is only temporarily stored in a temp folder during editing.

## Zip Folder
Contains the compiled PowerPack package (CapaInstaller.kit).
This archive represents the zip of the kit folder and is used for deployment.

## Logs and History
PowerPack log files are generated on the client endpoint during execution.

Default log location on Windows:

```txt
C:\Program Files\CapaInstaller\Client\Logs
```
Example:
```txt
SDK - Delete Users Older Than X Days.log
```

If the main log appears outdated, open the corresponding PowerPack subfolder:
```txt
C:\Program Files\CapaInstaller\Client\Logs\SDK - Delete Users Older Than X Days\
```

Inside this folder you will find:
```
History/
CapaOne.ScriptingLibrary.log
Install.log or Uninstall.log
PowerPackClient.log
PowerPackServer.log
```

Note: There is no version number in the path structure.
All logs from PowerPack executions are automatically uploaded to the CapaInstaller database after completion.
They can be viewed directly in the CapaInstaller Console by right-clicking a unit and selecting View installation logs.

If you place additional logs inside the PowerPack log folder, they will also be uploaded to the database and become visible within CapaInstaller.

## Requirements and Dependencies
To execute a PowerPack, the endpoint must have:

- .NET 8 installed (required for the CapaInstaller agent and the PowerPack runspace)
- The CapaInstaller Agent and BaseAgent services (handle job execution, scheduling, and reporting)
- Access to PSLib and the $cs object for logging, error handling, and job context

All other runtime dependencies are handled automatically by CapaInstaller.

## Templates
When creating new PowerPacks, use the provided templates to maintain a consistent structure.

```txt
templates/
└── PowerPack-template/
    ├── Kit/
    ├── Scripts/
    ├── Zip/
    └── README.md
```

Shared helper functions used across PowerPacks can be found in:
```txt
templates/
└── PowerPack-functions/
```

These functions make it easier to execute code in user context and handle common automation patterns (logging, registry updates, Active Setup, etc.).

## Versioning
Each PowerPack is stored under a version-specific directory:

```txt
PowerPackName/PowerPackVersion/
```
This ensures that multiple versions can coexist during testing or phased rollout.
The version number is defined when the PowerPack is published or exported.

## GPT Usage Context
This document is part of the repository’s knowledge base used by the custom ChatGPT assistant.
It helps the GPT understand:
- How a PowerPack is organised locally
- Where logs are stored and how they are uploaded
- How templates and folders relate to CapaInstaller’s execution model

The GPT may refer to this file when explaining folder layout, PowerPack packaging, or troubleshooting issues related to missing logs or structure errors.