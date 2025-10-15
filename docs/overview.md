# PowerPacks Overview

## Introduction
PowerPacks are modular PowerShell scripts designed to run within a specialised PowerShell runspace.
They are primarily used to manage Windows endpoints through **CapaInstaller**, but can technically execute any form of PowerShell code.

Each PowerPack runs in the **System context**, which allows administrative operations such as software installation, patching, configuration changes, and system maintenance.
When a script needs to execute in the **user context**, this can be achieved by calling one of the predefined helper functions located under `templates\PowerPack-functions`.

---

## Purpose of this Repository
This repository serves as a **knowledge base for a custom ChatGPT assistant**.
The GPT uses the information stored here to:
- Explain PowerPack concepts and terminology
- Provide guidance on structure, naming, and conventions
- Suggest solutions to common PowerPack development issues
- Reference examples and templates for building new PowerPacks

The goal is to make PowerPack development easier to understand, document, and extend — both for new developers and for automation tasks where GPT support is integrated.

---

## Core Concepts

### 1. PowerPack Execution
- PowerPacks run within a **dedicated PowerShell runspace** provided by CapaInstaller.
- Scripts typically run in **System context** by default.
- To perform actions in **User context**, use the helper functions in `templates\PowerPack-functions`.

### 2. Modularity
A PowerPack is designed as a **self-contained automation unit**.
It can be deployed independently or as part of a larger configuration flow.
Each PowerPack typically includes:
- A main script (e.g., `Install.ps1` or `Uninstall.ps1`)
- Optional supporting files in the Kit folder
- Logging through the `$cs` object

### 3. Integration with CapaInstaller
CapaInstaller provides the environment in which PowerPacks execute.
It handles job orchestration, logging, error handling, and reporting.
Developers can use CapaInstaller to deploy PowerPacks across managed endpoints or trigger their execution through endpoint-linked jobs

---

## Technical Dependencies
PowerPacks rely on several core components provided by CapaSystems:
- **PSLib** – internal PowerShell library offering logging, error handling, and utility functions.
- **CapaInstaller Agent** and **CapaInstaller BaseAgent** – the services responsible for job execution and communication.
- **$cs object** – runtime object used for logging and job context.

---

## Folder Structure
A typical PowerPack directory contains:
```txt
PowerPackName/PowerPackVersion/
├── Kit/
│   └── (optional supporting files)
├── Scripts/
│   ├── (empty – the install and uninstall scripts are stored in the database)
├── Zip/
│   └── CapaInstaller.kit
```

Templates and shared helper functions can be found under:
```txt
templates/
└── PowerPack-functions/
```

---

## GPT Usage Context
This repository is actively used as a **knowledge source for a custom ChatGPT assistant**.
When queried, the GPT refers to this repository to provide:
- Explanations of PowerPack structure and workflow
- Code examples or troubleshooting guidance
- Best practices and naming conventions

Developers can extend this repository by adding new documentation files, code samples, or updates to `index.json`, which acts as the GPT’s reference map to the stored information.

> **Note:** The `index.json` file should be placed in the **root** of the repository.
> It provides a structured overview of all available documentation and example files so the GPT can efficiently locate relevant content.

---

## About CapaInstaller
**CapaInstaller**, developed by **CapaSystems A/S**, is an endpoint management and automation platform used to deploy software, manage updates, and enforce configuration across enterprise environments.
PowerPacks act as the scripting and automation layer within this ecosystem, enabling flexible, PowerShell-based management of Windows devices under both local and centralised control.