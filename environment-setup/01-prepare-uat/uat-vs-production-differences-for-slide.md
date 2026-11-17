# UAT against production: exact lists behind the slide "Why UAT alone is not the source of truth"

Source: saved read-only comparison data from 6 Nov 2026 (`parity-L1.md`, `parity-L3.md`, the content check, `findings-*.md`). Nothing was run on UAT or production to make this list.

## 1. 31 production solutions missing from UAT
- Source environment is shown in brackets. Version note: LCAssembly is 1.0.0.2 in production; PREPROD is one version behind (1.0.0.1).
- Solutions with no UAT copy: Crca6de (PREPROD), OOBProcessesDeactivation (PREPROD), ENT_AutonumberingSetup (PREPROD), LCAssembly (production), Utility (dev DNL).
- 17 ENT patches (dev): ENT_CodeBaseSolution_Patch_c4d6a361, _94c07e0e, _902500bd, _a89649d1; ENT_SchemaBaseSolution_Patch_0d602da3, _95a66bca, _aaf85fee; ENT_SecurityRoleSolution_Patch_e43d9f7e; ENT_ConfigBaseSolution_Patch_75265258, _0fed5467, _92df7df2, _f47c7557, _6c409b61; ENT_PowerAutomateSolution_Patch_796c821f, _620194e9, _2665fcfc, _c148a0a5.
- 9 from SIT: DNL_ProductionDeployment_SIT, OrderField, DNL_ProductionDeployment_SIT_Patch_9d17cbeb, _073235c8, _3d42d13c, _13a96515, _26946e48, _f6b77821, and DPL_APP_HOTFIX_1.
- Separate point, HotFixCommissionMasterTable: it exists in UAT but with 1 component; production has 60 (managed pwc package).

## 2. UAT holds work never released
Scripts (web resources), 43 differ. Recomputed from the saved copies ignoring `debugger;` lines:
- 15 differ only by a `debugger;` line (production has it active, UAT has it commented out).
- 7 are purely UAT ahead (UAT has extra lines, production has none extra): dg_LockOrderScheduleonLoad, dg_PricelistItemJS_DNL_Enddate (functions ProductFilter, ProductPresearch), dg_QuoteProduct/main/dpl (setDescriptionDPL), dg_SalescontractDNL (LockFieldsOnSC), dg_createorderlineinsap, dg_notifyquoteDNL (showactivate), dg_orderapproval/main.js.
- 21 are mixed (each side has lines the other lacks). Of these, UAT has functions production lacks in:
  - dg_JS/quote/main.js: HideTab, ShowTab, ShowTabDNL, ShowTabOnAdmin, LockUnlockFormquote, MSMEindicator (UAT 102 lines extra, production 12; the earlier whole-file count was 252 more lines in UAT)
  - dg_JS/salescontract/main.js: AMSFeilds
  - dg_SampleRequestDNL: FetchIncoterms, HideSalesArea, Makequotepaymenttermmandatory, UpdateSalesArea, salesareaSRDNL1, showSalesAreaDNL1
  - dg_SampleRequestline: SetSalesArea
  - dg_JS/SCApproval/main.js: onreadystatechange
- The other mixed scripts: dg_BulkApprovalHTML, dg_CommissionMasterApproval, dg_Enddatepricelistitem, dg_HideSplitQuantityButton, dg_LockOrderScheduleApprovalonLoad, dg_OnchangeofProductPopulateRevenue, dg_Order/shortclose, dg_OrderScheduleSampleRequest, dg_OrderSchedulequickcreate, dg_SampleOrder, dg_SampleRequest_Opportunity, dg_addCustomViewToFreightMasterLookup, dg_cancel, dg_js_sendQuoteProductforDomesticReport, dg_orderapproval/ribbon.js, dg_orderscheduleApprovallineReadonly.
- The slide's "12 scripts ahead" came from an earlier, looser read of the 6 Nov data. By the stricter count above it is 7 purely ahead plus the mixed ones with UAT-only functions.

Plugin assemblies, 9 differ (both are version 1.0.0.0, so the version does not show which is newer): UpdateFields_Opp_Quote, DN.SourceCodePluginAssemply, DNL_Project, DO Cancellation, DiscountDuplicate, Lead Duplication, MultiOrderline_Integration_CRMtoSAP_DCTL, Multi_OrderLine_Creation, Quote_Opp_StatusUpdate. UAT was modified later for 7 of 9 (examples: UpdateFields_Opp_Quote UAT 16 Feb 2026 vs production 18 Dec 2025; DNL_Project 27 Feb 2026 vs 28 Jan 2026). "Ahead" for plugins is therefore likely, not proved; confirm against source control.

## 3. UAT is also behind production
Only in production:
- 58 flows and rules (names in `parity-L1.md` lines 369-428, for example Company Code, Lock Fields, Price Override on Approval, Rebooked Order, SLA1 to SLA3, crm_website_integration, ImportDataRunAction).
- 21 forms: Contact Us Personal Web Form, Contact Us Personal Web Form - Japanese, Information (3), Join Web Form, Lead, Lead Dashboard, Lead Quick Create, Leads Dashboard (3), New Form, Order, Original Order Details, PriceLevel_1_DG_DNL, Sales Insights, Test Dashboard, Web Form, Web Form - Japanese, pricelistitem_DG_DNL.
- 18 plugin steps: Credit_Limit_Request_statusupdate, CustomerCreationIntegration_CRM_to_SAP, DG_Websitre_CRM_Integration, QuantityDiscountAPISyncSAP, Masters_Approvals (CashDiscount, LocationDiscount, PackagingMaster, QuantityDiscount, Route_Master_Integration_SAPtoCRM, SpecialDiscount, WarehousePremium), OrderScheduleApproval, Price_List_SAP_API, SC_Approval, UpdateFields_Opp_Quote (ImportDataReport, OpportunityProductEndDateValidation, SendEmailToPrimaryContact, SetHSCodeName).
- Also only in production (not on the slide): 12 views, 9 web resources, 1 plugin assembly (DG_Websitre_CRM Integration), 4 tables (leadtoopportunitysalesprocess, msdyn_linkedentityattributevalidity, msdyn_taggedrecord, team), 2 roles (Decision Document, Decision Document Approvals), 9 columns.

Only in UAT: 120 views and 75 columns (full lists in `parity-L1.md` lines 33 to 109 and 199 to 320), plus 53 forms, 6 tables (dg_alpanatestentity, dg_customexchangeratemaster, dg_soldtoparty, msdyn_recurringsalesaction, msdyn_recurringsalesactionv2, msdyn_saruninstance).

## 4. Quote Product and Order Product differ
- Only in production (Quote Product): dg_discountnote, dg_freight, dg_freightname.
- Only in production (Order Product): dg_commission, dg_commissionvalue, dg_unitprice, dg_unitprice_base.
- Only in UAT: salesorderdetail.dg_noofdetentiondays, dg_pricereferenceregion, dg_pricereferenceregionname.
- Precision: salesorderdetail.dg_commissioncurrency and its _base column have precision 4 (precision source 2) in UAT and precision 2 (source 0) in production.
- Note: the slide names "dg_freight, dg_unitprice, dg_commission". dg_unitprice is the money field that was missing from the 4 Nov list (the 251st field in the currency assessment).
