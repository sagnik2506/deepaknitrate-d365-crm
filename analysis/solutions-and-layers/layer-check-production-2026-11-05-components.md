# Production: components with an Active (unmanaged) layer, Quote Product and Order Product

Run of 5 Nov 2026 (UTC). Ids are shortened. "Layers" counts the stack including Active. See the report for method and conclusions.

| Type | Table | Name | Id | Layers | Managed layer under Active | What the Active layer changes | Reading |
|---|---|---|---|---|---|---|---|
| Column | salesorderdetail | dg_remarksforshortclose | 60df8158… | 2 | DNL_Base_Entities | maxlength,formuladefinition,modifiedon | REAL edit of the column definition (length and formula). Overrides the managed definition |
| Form | quotedetail | Quote product DG | dfcec06d… | 2 | ENT_SchemaBaseSolution | formxml | REAL form edit (formxml). A managed form change will not show until this is dealt with |
| Form | quotedetail | Quote product DG | b16a131c… | 7 | ProductionDeployment_Patch_9f3275ef | formxmlmanaged,formxml,formjson | REAL form edit (formxml). A managed form change will not show until this is dealt with |
| WebResource | (web resource) | dg_js/ordermain_DNL | f96539aa… | 25 | ProductionDeployment_Patch_9f3275ef | webresourceidunique,content | REAL content edit in the Active layer. Compare with the managed layer before any change |
| WebResource | (web resource) | dg_PriceListForm | abee9150… | 4 | DCTL_Entities_Solution | webresourceidunique,content | REAL content edit in the Active layer. Compare with the managed layer before any change |
| Form | quotedetail | Information | 1ff13845… | 7 | DNL_Base_Entities | formxmlmanaged,formjson | Form metadata only (formxmlmanaged, formjson). Probably technical, verify |
| Form | quotedetail | New Form | 84fd8757… | 3 | DNL_Base_Entities | (none readable) | Change list not readable (empty). Treat as a hand edit |
| Form | quotedetail | Quote Product web view | be1f25ca… | 3 | DNL_Base_Entities | (none readable) | Change list not readable (empty). Treat as a hand edit |
| Form | quotedetail | Quote product_DG (deprecated) | 8843fa31… | 3 | DNL_Base_Entities | (none readable) | Change list not readable (empty). Treat as a hand edit |
| WebResource | (web resource) | dg_addCustomViewToFreightMasterLookup | 24c6bfaa… | 15 | ProductionDeployment_Patch_9f3275ef | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_cancel | ffdfe237… | 11 | ProductionDeployment_Patch_a17d2926 | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_CreateDoinSapbutton | b29ecf1a… | 6 | DCTL_Production | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_js/CreateOrderfromQuote/ribbon | 9e34a70d… | 4 | DCTL_Entities_Solution | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_js/LockQuoteLineOnActivationDnl | f368985e… | 2 | DNL_Base_WebResources | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_JS/quote/main.js | 9ca3e829… | 5 | DNL_FEB_2025 | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_js/quoteProduct/main/dnl | e256a6c9… | 26 | ProductionDeployment_JUNE | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_LockOrderScheduleonLoad | f1bebbf4… | 15 | ProductionDeployment_JUNE | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_notifyquoteDNL | 923a26fa… | 3 | DNL_Production_Deployment_Patch_2e38712a | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_orderscheduleApprovallineReadonly | d80ba542… | 5 | ProductionDeployment_Patch_3e564b01 | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_OrderScheduleFetchDetails | b99ec225… | 16 | ProductionDeployment_JUNE | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_OrderScheduleOnload.js | afb66a9d… | 10 | ProductionDeployment_JUNE | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_QuoteCreationDate | 92e413ad… | 2 | ENT_CodeBaseSolution_Patch_c4d6a361 | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_SampleRequest_Opportunity | 652f623b… | 4 | ProductionDeployment_Patch_24df1d26 | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
| WebResource | (web resource) | dg_ShowPhenolorderButton | dfdeffb5… | 2 | ENT_CodeBaseSolution | webresourceidunique,contentfileref | Technical only (file reference). No code edit. Not a blocker |
