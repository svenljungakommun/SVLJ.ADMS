# SVLJ.ADMS v1.0.1.3

**Active Directory Management System (ADMS) for lifecycle automation and governance**  
Maintainer: Svenljunga kommun  

---

## Overview

`SVLJ.ADMS` is a modular identity management and governance system written in **PowerShell** and **C#**, designed for municipal and public sector environments.  

It automates the full identity lifecycle — from onboarding to deprovisioning — and enforces governance policies on Active Directory group memberships and entitlements. The system integrates with HR, education, tax authority, and cloud platforms to provide **policy-driven, auditable, and compliant access management**.  

Key roles include:  
- **Application Owners** – responsible for approving and governing system-specific access.  
- **Delegated Administrators** – manage access for teams or units via delegated rights.  
- **Users** – benefit from self-service e-services for account and access requests.  

---

## Features

- 🔄 **Identity Lifecycle Automation**  
  - Onboarding and offboarding based on HR data  
  - Automatic group membership provisioning/deprovisioning  
  - Attribute-based and role-based access control (ABAC/RBAC)  

- 📜 **Governance & Compliance**  
  - Application Owners assigned to each system  
  - Automated entitlement cleanup  
  - Full audit trail of all access changes  

- 🌐 **Integrations**  
  - *Personec P* (HR system)  
  - *Skatteverket* (national identity registry)  
  - *IST* (education management)  
  - *Microsoft 365* (Azure AD, Teams, Exchange Online, SharePoint)  
  - Other municipal and governmental services  

- 🖥️ **Self-Service & Delegation**  
  - Web-based e-services for users  
  - Delegated administration for line managers  

- ⚙️ **Technology Stack**  
  - PowerShell for orchestration and automation  
  - C# for high-performance modules and APIs  
  - SQL backend for rules, logs, and configuration  
  - ASP.NET/HTML e-services portal  

---

## Governance Model

| Role                        | Responsibility                              |
| --------------------------- | ------------------------------------------- |
| **User**                    | Uses self-service to manage own identity    |
| **Delegated Administrator** | Manages entitlements for their unit/team    |
| **Application Owner**       | Approves and governs access to applications |
| **IT Administrator**        | Operates ADMS platform and integrations     |

---

## Governance & Compliance

SVLJ.ADMS enforces governance rules across the entire identity lifecycle:
- Role-based and attribute-based access controls.  
- Automated entitlement review and cleanup.  
- Application Owners accountable for system-level access governance.  
- Full audit trail of all identity and access changes.  
- Integration with SIEM/SOAR for monitoring and incident response.  

---

## Status

SVLJ.ADMS is **incrementally released**, with selected modules and documentation made available.  
The system is under continuous development and expansion to meet modern requirements for **Zero Trust**, **NIS2**, and **ISO 27001** compliance.  
