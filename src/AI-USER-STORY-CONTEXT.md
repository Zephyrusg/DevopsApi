# AI-context: Azure DevOps User Stories

Gebruik deze richtlijnen wanneer je een Azure DevOps User Story opstelt of bijwerkt.

## Template

**Als** [doelgroep of rol]
**Wil ik** [behoefte of gewenste verandering]
**Zodat** [waarde of beoogd resultaat]

**Aanleiding van de story (waarom):** context en reden voor het werk.

**Beschrijving (wat):** gewenste scope, systemen of onderdelen, en wat wel of niet wordt aangepast.

**Stakeholders:** partijen die nodig zijn voor besluitvorming, toegang, infrastructuur of uitvoering. Noem het uitvoerende team niet automatisch als stakeholder.

**Oplossingsrichting (hoe):** beknopte, genummerde stappen op hoofdlijnen. Vermijd onnodige implementatiedetails als de gebruiker die alleen ter context gaf.

## Schrijf- en werkafspraken

- Schrijf als een ervaren IAM/DevOps-engineer: helder, zakelijk en concreet.
- Gebruik voor alle Azure DevOps-acties uitsluitend de PowerShell-module in deze repository. Verbind met `Connect-AzureDevOps` en gebruik de beschikbare modulefuncties voor lezen en wijzigen.
- Gebruik geen losse `az`-commando's, REST-aanroepen, `Invoke-RestMethod` of andere routes buiten de module. Ontbreekt een benodigde functie, meld dit en vraag toestemming om de module uit te breiden; omzeil de beperking niet.
- Behandel PATs en andere credentials als geheimen: toon ze niet en schrijf ze niet naar bestanden of uitvoer.
- Houd de wens en waarde kort; zet context in de aanleiding en scope in de beschrijving.
- Gebruik alleen feiten die de gebruiker of bestaande work items bevestigen. Verzin geen namen, omgevingen, afhankelijkheden, stakeholders of technische details.
- Vraag gericht naar ontbrekende informatie, vooral naar wie de story nodig heeft en waarom. Benoem aannames expliciet.
- Maak afhankelijkheden duidelijk. Gebruik een parent voor hiërarchie en predecessor/successor voor uitvoervolgorde; controleer de bedoelde richting.
- Gebruik `Needs Refinement` alleen als daarom is gevraagd of als de gebruiker dit als werkafspraak heeft bevestigd.
- Geef bij een nieuwe of inhoudelijk gewijzigde story eerst de volledige concepttekst ter review. Pas daarna de work item aan, tenzij de gebruiker expliciet vraagt om direct uit te voeren.
- Na een wijziging: lees de story terug en controleer tekst, tags en links.
