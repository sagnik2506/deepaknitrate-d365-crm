/* =====================================================================================================
   STEP 1 REFACTOR (DRAFT FOR UAT) of dg_js/quoteProduct/main/dnl
   Base file : production = UAT copy, 184,264 bytes, sha256 starts 31a31837f15c
               (layer ProductionDeployment_Patch_23c258e6 v1.0.0.34). Untouched copy: *.ORIGINAL-v1.0.0.34.js
   Search for "STEP1-CHANGE" to find every change. Everything else is the original, line for line.

   WHAT CHANGED
   1. NEW dnlGetQuoteData(): one shared (synchronous) read of the parent quote with the 6 columns the four functions need.
   2. OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI, OnLoadQuoteStatus use it instead of making one request each.
   RESULT: 4 blocking requests to the same quote become 1 (3 round trips saved on every form open).

   WHAT DID NOT CHANGE
   - Function names, parameters and the form registrations (no form has to be changed or shipped with this file).
   - The order in which the effects happen (all work is still done in the same place, in the same order).
   - The price list request inside ShowHideOnFSBI and all other requests in the file (planned for later steps).

   WHY THE READ IS NOT ASYNCHRONOUS YET
   On the DNL and DCTL forms UpdateQuoteProductSalesOrd is the FIRST OnLoad handler and about 49 handlers run after it, many of them
   reading dg_division and dg_salesorganization. ShowHideOnFSBI runs before ShowHideFormulaPricing and ppandfs, which also show/hide
   dg_voc. Making these reads asynchronous would change the order of effects. A safe asynchronous design needs one OnLoad
   entry point that runs the functions in order (a form change), which is a later step.
   ===================================================================================================== */
var productid = "";
var account = "";
var oldQuote = "";

// STEP1-CHANGE-START  (NEW CODE: shared reader for the parent quote)
// Before step 1, four OnLoad functions (OldQuoteProduct, UpdateQuoteProductSalesOrd, ShowHideOnFSBI, OnLoadQuoteStatus) each made their own
// SYNCHRONOUS request to the same quote. They now share ONE request. It is still synchronous (see the notes inside each function).
//  - dnlGetQuoteData(quoteId)        returns the cached quote data if it is for the same quote and younger than DNL_QUOTE_CACHE_TTL_MS
//  - dnlGetQuoteData(quoteId, true)  always reads fresh (used by UpdateQuoteProductSalesOrd, the first handler of every load)
// Returns null when the read fails. A failed read is never cached.
// The cache is also protected by the time limit, so a later form refresh or a form without the first handler never sees old data.
var DNL_QUOTE_CACHE_TTL_MS = 10000;
var DNL_QUOTE_SELECT = "_customerid_value,effectiveto,dg_division,dg_salesoragnizationsingle,dg_isitacontract,dg_customstatus";
var _dnlQuoteCache = { id: null, ts: 0, data: null };
function dnlGetQuoteData(quoteId, forceRefresh) {
    var now = new Date().getTime();
    if (!forceRefresh && _dnlQuoteCache.data && _dnlQuoteCache.id === quoteId && (now - _dnlQuoteCache.ts) < DNL_QUOTE_CACHE_TTL_MS) {
        return _dnlQuoteCache.data;
    }
    var data = null;
    // No try/catch on purpose: like the original code, a network error is NOT swallowed here (it escapes to the form as before).
    var req = new XMLHttpRequest();
    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotes(" + quoteId + ")?$select=" + DNL_QUOTE_SELECT, false);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Accept", "application/json");
    req.send();
    if (req.status === 200) {
        data = JSON.parse(req.responseText);
    } else {
        console.log(req.responseText);   // the original logged the response text the same way
    }
    _dnlQuoteCache = data ? { id: quoteId, ts: now, data: data } : { id: null, ts: 0, data: null };
    return data;
}
// STEP1-CHANGE-END

function OldQuoteProduct(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var quoteprod = formContext.getAttribute("quoteid").getValue();
    var quoteprodid = quoteprod[0].id.replace("{", "").replace("}", "");
    var product = formContext.getAttribute("productid").getValue();
    productid = product[0].id.replace("{", "").replace("}", "");
    // STEP1-CHANGE-START
    // ORIGINAL (v1.0.0.34 lines 11-35): a synchronous XMLHttpRequest to quotes(<id>)?$select=_customerid_value,
    //   whose callback stored the customer id in the global variable "account".
    // NOW: the customer id comes from the shared quote read (dnlGetQuoteData). Same global variable, same value.
    // NOTE: the original code is kept above and below this block unchanged (including the TypeError it throws when
    //   "quoteid" or "productid" is empty). Behaviour is meant to be identical.
    var quoteData = dnlGetQuoteData(quoteprodid);
    if (quoteData) {
        account = quoteData["_customerid_value"];
    }
    // STEP1-CHANGE-END

    //old quote

    formContext.getControl("dg_oldquoteproduct").addPreSearch(oldquote);

}
///old quote not in use--need modification
function oldquote() {
    //var Addressfilter2 = "<filter type='and'><condition attribute='productid' operator='eq' uitype='product' value='{"+productid+"}'/> </filter> <link-entity name='quote' from='quoteid' to='quoteid' link-type='inner' alias='ak'> <filter type='and'> <condition attribute='customerid' operator='eq' uitype='account' value='{"+account+"}'/> </filter> </link-entity>";
    var Addressfilter2 = `<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>
    <entity name='quotedetail'>
    <attribute name='productid'/>
    <attribute name='productdescription'/>
    <attribute name='priceperunit'/>
    <attribute name='quantity'/>
    <attribute name='extendedamount'/>
    <attribute name='quotedetailid'/>
    <attribute name='createdon'/>
    <attribute name='dg_statusline'/>
    <order attribute='createdon' descending='true'/>
    <filter type='and'>
    <condition attribute='productid' operator='eq' uitype='product' value='{`+ productid + `}'/>
    <condition attribute='dg_statusline' operator='in'>
    <value>2</value>
    <value>4</value>
    <value>3</value>
    </condition>
    </filter>
    <link-entity name='quote' from='quoteid' to='quoteid' link-type='inner' alias='af'>
    <filter type='and'>
    <condition attribute='customerid' operator='eq' uitype='account' value='{`+ account + `}'/>
    </filter>
    </link-entity>
    </entity>
    </fetch>`;
    //Xrm.Page.getControl("dg_oldquoteproduct").addCustomView(Addressfilter2);
    //var layout="<grid name=&quot;quotedetails&quot; object=&quot;1085&quot; jump=&quot;&quot; select=&quot;1&quot; icon=&quot;1&quot; preview=&quot;1&quot;><row name=&quot;quotedetail&quot; id=&quot;quotedetailid&quot;><cell name=&quot;productid&quot; width=&quot;200&quot; /><cell name=&quot;productdescription&quot; width=&quot;200&quot; /><cell name=&quot;priceperunit&quot; width=&quot;100&quot; /><cell name=&quot;quantity&quot; width=&quot;100&quot; /><cell name=&quot;extendedamount&quot; width=&quot;125&quot; /></row></grid>";
    var layout = `<grid name='quotedetails' object='1085' jump='' select='1' icon='1' preview='1'>" +  
    "<row name='quotedetail' id='quotedetailid'>" +  
    "<cell name='productid' width='200' />" +  
    "<cell name='createdon' width='200' />" +  
    "<cell name='priceperunit' width='100' />" +  
    "<cell name='quantity' width='100' />" +  
    "<cell name='dg_statusline' width='200' />" + 
    "</row>" +  
    "</grid>`;
    Xrm.Page.getControl("dg_oldquoteproduct").addCustomView("{00000000-0000-0000-0000-000000000001}", "quotedetail", "display", Addressfilter2, layout, false);
    Xrm.Page.getControl("dg_oldquoteproduct").setDefaultView("{00000000-0000-0000-0000-000000000001}");
    Xrm.Page.getControl("dg_oldquoteproduct1").addCustomView("{00000000-0000-0000-0000-000000000001}", "quotedetail", "display", Addressfilter2, layout, false);
    Xrm.Page.getControl("dg_oldquoteproduct1").setDefaultView("{00000000-0000-0000-0000-000000000001}");
    //""
}


function NotifyCOnotuse(primaryControl) {
    //debugger;
    var formContext = primaryControl;

    // Check if the form has unsaved changes
    if (formContext.data.entity.getIsDirty()) {
        alert("Please save the record before performing this action.");
        return;
    }

    // App id
    var globalContext = Xrm.Utility.getGlobalContext();
    var appId = globalContext.getCurrentAppUrl();

    // Get costing owner
    var emailId = null;
    var url = null;
    var recordId = formContext.data.entity.getId().replace("{", "").replace("}", "");
    var entityName = formContext.data.entity.getEntityName();
    var recordUrl = appId + "&forceUCI=1&pagetype=entityrecord&etn=" + entityName + "&id=" + recordId;

    // Retrieve Notify CO Power Automate URL
    var req = new XMLHttpRequest();
    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_crmsettings?$select=dg_value&$filter=dg_name eq 'Notify CO Power Automate DNL'", false);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Accept", "application/json");
    req.setRequestHeader("Prefer", "odata.include-annotations=*");
    req.onreadystatechange = function () {
        if (this.readyState === 4) {
            req.onreadystatechange = null;
            if (this.status === 200) {
                var results = JSON.parse(this.response);
                if (results.value.length > 0) {
                    url = results.value[0]["dg_value"];
                }
            } else {
                console.log(this.responseText);
            }
        }
    };
    req.send();

    // Retrieve Costing Owner email
    req = new XMLHttpRequest();
    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_crmsettings?$select=dg_value&$filter=(statecode eq 0 and dg_name eq 'Costing Owner')", false);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Accept", "application/json");
    req.setRequestHeader("Prefer", "odata.include-annotations=*");
    req.onreadystatechange = function () {
        if (this.readyState === 4) {
            req.onreadystatechange = null;
            if (this.status === 200) {
                var results = JSON.parse(this.response);
                if (results.value.length > 0) {
                    emailId = results.value[0]["dg_value"];
                }
            } else {
                console.log(this.responseText);
            }
        }
    };
    req.send();

    // Trigger Power Automate to send Email
    if (url && emailId) {
        req = new XMLHttpRequest();
        req.open("POST", url, true);
        req.setRequestHeader('Content-Type', 'application/json');
        req.send(JSON.stringify({ "recordurl": recordUrl, "EmailId": emailId }));
        alert("Mail Sent to Costing Owner!!");
    }
}

///update Sales org and division
function UpdateQuoteProductSalesOrd(executionContext) {
    // debugger;
    var formContext = executionContext.getFormContext();
    var quote = formContext.getAttribute("quoteid").getValue();
    var quoteid = quote[0].id.replace("{", "").replace("}", "");
    let date = new Date();

    var division;
    var salesorg;
    ///fetch quote fields
    // STEP1-CHANGE-START
    // ORIGINAL (v1.0.0.34 lines 178-207): a synchronous XMLHttpRequest to
    //   quotes(<id>)?$select=effectiveto,dg_division,dg_salesoragnizationsingle, whose callback set "division", "date" and "salesorg".
    // NOW: same three values from the shared quote read. This is the FIRST OnLoad handler on both the DNL and DCTL forms, so it asks for a
    //   FRESH read (second argument true) and the other three functions reuse it (one request instead of four).
    // WHY IT IS STILL SYNCHRONOUS: about 49 handlers run after this one and read dg_division / dg_salesorganization.
    //   If these fields were filled later (asynchronously) those handlers would see empty values on new lines.
    // The code below this block (setting the 3 fields when empty) is the ORIGINAL code and is unchanged, including
    //   new Date(null) = 1 Jan 1970 when the quote has no effective-to date (existing behaviour, flagged for the business).
    var quoteData = dnlGetQuoteData(quoteid, true);
    if (quoteData) {
        division = quoteData["dg_division"];
        date = quoteData["effectiveto"];
        salesorg = quoteData["dg_salesoragnizationsingle"];
    }
    // STEP1-CHANGE-END
    if (formContext.getAttribute("dg_salesorganization").getValue() == null) {
        formContext.getAttribute("dg_salesorganization").setValue(salesorg);
    }
    if (formContext.getAttribute("dg_division").getValue() == null) {
        formContext.getAttribute("dg_division").setValue(division);
    }
    date = new Date(date);

    var effectiveto = formContext.getAttribute("dg_effectivetodnl").getValue();
    if (effectiveto == null) {
        formContext.getAttribute("dg_effectivetodnl").setValue(date);


    }

    //Update Warehouse

}

function SubGridFilterExecution(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var quoteProdId = formContext.data.entity.getId();
    var gridContext = formContext.getControl("competitoranalysis");//Competitor Analysis

    var QuoteProdID = formContext.getAttribute("dg_quoteproductid").getValue();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();

    var req = new XMLHttpRequest();
    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_competitoranalysises?$select=dg_competitoranalysisid,_dg_competitor_value&$filter=_dg_quoteproduct_value eq " + quoteProdId + "", true);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Accept", "application/json");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Prefer", "odata.include-annotations=\"*\"");
    req.onreadystatechange = function () {
        if (this.readyState === 4) {
            req.onreadystatechange = null;
            if (this.status === 200) {
                var result = JSON.parse(this.response);
                var competitorid = result.value[0]["_dg_competitor_value"];
                set(executionContext, competitorid, SalesOrg, gridContext)
            }
        }
    };
    req.send();

}
function set(executionContext, competitorid, SalesOrg, gridContext) {
    var formContext = executionContext.getFormContext();
    if ((SalesOrg == 1000 || SalesOrg == 3000) && competitorid != null) {
        if (gridContext == null) {
            setTimeout(SubGridFilterExecution, 3000);
            return;
        }
        else {
            var FetchXmlA = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
                "  <entity name='dg_importorexportdata'>" +
                "    <attribute name='dg_importorexportdataid' />" +
                "    <attribute name='dg_name' />" +
                "    <attribute name='createdon' />" +
                "    <attribute name='dg_weightedprice' />" +
                "    <attribute name='dg_uploadmonth' />" +
                "    <attribute name='dg_typeofdata' />" +
                "    <attribute name='dg_sumofquantity' />" +
                "    <attribute name='dg_product' />" +
                "    <attribute name='dg_fgrm' />" +
                "    <attribute name='dg_destinationcountry' />" +
                "    <attribute name='dg_competitor' />" +
                "    <order attribute='dg_name' descending='false' />" +
                "    <filter type='and'>" +
                "      <condition attribute='dg_competitor' operator='eq' uiname='Mannu�Chemicals' uitype='competitor' value='" + competitorid + "' />" +
                "    </filter>" +
                "  </entity>" +
                "</fetch>";
            gridContext.setFilterXml(FetchXmlA);
            formContext.getControl("competitoranalysis").refresh();
        }
    }
}
function convertToIST(date) {
    // Create a new Date object from the input date
    let utcDate = new Date(date);

    // IST is UTC + 5:30
    let istOffset = 5.5 * 60 * 60 * 1000; // 5.5 hours in milliseconds

    // Convert the UTC date to IST
    let istDate = new Date(utcDate.getTime() + istOffset);

    return istDate;
}
function DisableApprovalStatusDnl(executionContext) {
    //debugger;
    var customQuoteStatus = null;
    var formContext = executionContext.getFormContext();
    var approveOnCustomer = formContext.getAttribute("dg_approverejectoncustomerbehalf").getValue();
    var effective_to = formContext.getAttribute("dg_effectivetodnl").getValue();
    var Effective = new Date(effective_to);

    //Effective = convertToIST(Effective);
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    var currentDate = new Date();
    currentDate.setHours(0, 0, 0, 0);
    //currentDate = convertToIST(currentDate);

    if (approveOnCustomer == 140110001 || approveOnCustomer == 140110002) {
        var quoteIdString = formContext.getAttribute("quoteid").getValue()[0].id;
        var quoteId = quoteIdString.replace('{', '').replace('}', '');
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotes(" + quoteId + ")?$select=dg_customstatus,name", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    customQuoteStatus = result["dg_customstatus"];
                }
            }
        };
        req.send();
    }
    if (currentDate <= Effective) {//&& statusline==1 && approveOnCustomer!=140110000
        if (statusline == 1 || statusline == 140110000) {//|| statusline == 4
            if (approveOnCustomer == 140110001 || approveOnCustomer == 140110002) {
                if (customQuoteStatus != 140110004 && customQuoteStatus != 140110002 && customQuoteStatus != 140110001) {
                    formContext.getAttribute("dg_approverejectoncustomerbehalf").setValue(140110000);
                    alert("Cannot Approve Quote Line as Parent Quote is not Activated!!!");
                    //executionContext.getEventArgs().preventDefault();
                }
                else if (customQuoteStatus == 140110004 || customQuoteStatus == 140110002 || customQuoteStatus == 140110001) {
                    if (approveOnCustomer == 140110001 || approveOnCustomer == 140110002) {
                        formContext.getAttribute("dg_approvalstatus").setValue(approveOnCustomer);//dg_approverejectoncustomerbehalf
                        formContext.getAttribute("dg_statusline").setValue(1);
                        //Save and refresh
                        // formContext.data.entity.save();
                        //formContext.data.refresh();  

                    }
                }
            }
        }

        // else if (approveOnCustomer == 140110002) {
        //     formContext.getAttribute("dg_approvalstatus").setValue(approveOnCustomer);
        // }
    }
    else {
        if (approveOnCustomer == 140110001 || approveOnCustomer == 140110002) {
            if (statusline == 1 || statusline == 140110000) {//|| statusline == 4 
                alert("Quote Product expired, kindly extend it before Approving/Rejecting");
                //executionContext.getEventArgs().preventDefault();
                formContext.getAttribute("dg_approverejectoncustomerbehalf").setValue(140110000);
                formContext.getAttribute("dg_remarks").setValue(null);
            }
        }
    }
    // else if(currentDate > Effective && (customQuoteStatus==140110000 || customQuoteStatus==140110004)) {
    //     alert("Quote Product Expired!!");
    //     formContext.getAttribute("dg_approverejectoncustomerbehalf").setValue(140110000);
    // }

}
///////////////////////////////////////////////////////////////////////////////////////
function QPstatus(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var approvereject = formContext.getAttribute("dg_approverejectoncustomerbehalf").getValue();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    if (SalesOrg == 1000 || SalesOrg == 3000) {
        if (approvereject == 140110001) {
            formContext.getAttribute("dg_approvalstatus").setValue(140110001);
        }
    }
}
function setDescription(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var productdesc = formContext.getAttribute("dg_productdescription").getValue();
    if (productdesc != null) {
        var prod = productdesc[0].id;
        var productdescId = prod.replace('{', '').replace('}', '');
        var name = null;
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_descriptions(" + productdescId + ")?$select=dg_name", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var dg_descriptionid = result["dg_descriptionid"]; // Guid
                    var dg_name = result["dg_name"]; // Text
                    name = dg_name;
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
        formContext.getAttribute("dg_productdescriptiondnl").setValue(name);

    }
    else {
        formContext.getAttribute("description").setValue(null);
    }
}

function ShowHideOnBasisOfIncoterm(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var incoterm = formContext.getAttribute("dg_incoterms").getValue();
    if (incoterm == 140110001 || incoterm == 140110000 || incoterm == 140110019 || incoterm == 140110020) {
        //formContext.getControl("dg_seafreight").setVisible(true);
        //formContext.getControl("dg_airfreight").setVisible(true);
        //formContext.getControl("dg_freightamount").setVisible(true);
        //formContext.getControl("quantity").setVisible(true);

    }
    else {
        //formContext.getControl("dg_seafreight").setVisible(false);
        //formContext.getControl("dg_airfreight").setVisible(false);
        //formContext.getControl("dg_freightamount").setVisible(false);
        //formContext.getControl("quantity").setVisible(false);
        //formContext.getAttribute("dg_seafreight").setValue(null);
        //formContext.getAttribute("dg_airfreight").setValue(null);
        //formContext.getAttribute("dg_freightamount").setValue(null);
        //formContext.getAttribute("quantity").setValue(null);
    }
    if (incoterm == 140110019 || incoterm == 140110020) {
        //formContext.getControl("dg_agencycharges").setVisible(true);
        //formContext.getControl("dg_inlandhaulages").setVisible(true);
        //formContext.getControl("dg_storagecharges").setVisible(true);
        //formContext.getControl("dg_detentioncharges").setVisible(true);
        //formContext.getControl("dg_demmerrages").setVisible(true);
    }
    else {
        //formContext.getControl("dg_agencycharges").setVisible(false);
        // formContext.getControl("dg_inlandhaulages").setVisible(false);
        //formContext.getControl("dg_storagecharges").setVisible(false);
        //formContext.getControl("dg_detentioncharges").setVisible(false);
        //formContext.getControl("dg_demmerrages").setVisible(false);
        //formContext.getAttribute("dg_agencycharges").setValue(null);
        //formContext.getAttribute("dg_inlandhaulages").setValue(null);
        //formContext.getAttribute("dg_storagecharges").setValue(null);
        //formContext.getAttribute("dg_detentioncharges").setValue(null);
        //formContext.getAttribute("dg_demmerrages").setValue(null);
    }
    if (incoterm == 140110020) {
        //formContext.getControl("dg_customduty").setVisible(true);
    }
    else {
        // formContext.getControl("dg_customduty").setVisible(false);
        //formContext.getAttribute("dg_customduty").setValue(null);
    }
    if (incoterm == 140110001 || incoterm == 140110000 || incoterm == 140110019 || incoterm == 140110020 || incoterm == 140110003) {
        //formContext.getControl("dg_origincharges").setVisible(true);
    }
    else {
        // formContext.getControl("dg_origincharges").setVisible(false);
        //formContext.getAttribute("dg_origincharges").setValue(null);
    }
    if (incoterm == 140110012) {
        //formContext.getControl("dg_freightcharges").setDisabled(true);
    }
    else {
        //formContext.getControl("dg_freightcharges").setDisabled(false);
    }
}

function ShowHideOnFSBI(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var division = formContext.getAttribute("dg_division").getValue();
    var quote = formContext.getAttribute("quoteid").getValue()[0].id;
    var contract = null;
    if (quote != null) {
        quoteid = quote.replace('{', '').replace('}', '');
        //fetch contract type
        // STEP1-CHANGE-START
        // ORIGINAL (v1.0.0.34 lines 499-522): a synchronous XMLHttpRequest to quotes(<id>)?$select=dg_isitacontract,
        //   whose callback set the variable "contract".
        // NOW: "contract" comes from the shared quote read. The SECOND request in this function (price list type) is NOT changed in step 1.
        // ORDER NOTE: this handler runs BEFORE ShowHideFormulaPricing and ppandfs/ppandfsDCTL, which also show/hide dg_voc.
        //   That is why the read stays synchronous: an asynchronous version would hide dg_voc AFTER those handlers and could change the result.
        var quoteData = dnlGetQuoteData(quoteid);
        if (quoteData) {
            contract = quoteData["dg_isitacontract"];
        }
        // STEP1-CHANGE-END

        //check for domestic
        if (contract != 140110000) {
            var pricelist = formContext.getAttribute("dg_pricelist").getValue();
            if (division == 30 || division == 40 || division == 95) {

                var prod = pricelist[0].id;
                var productdescId = prod.replace('{', '').replace('}', '');
                //fetch price list
                var type = null;
                var req = new XMLHttpRequest();
                req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/pricelevels(" + productdescId + ")?$select=dg_pricelisttype", false);
                req.setRequestHeader("OData-MaxVersion", "4.0");
                req.setRequestHeader("OData-Version", "4.0");
                req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
                req.setRequestHeader("Accept", "application/json");
                req.setRequestHeader("Prefer", "odata.include-annotations=*");
                req.onreadystatechange = function () {
                    if (this.readyState === 4) {
                        req.onreadystatechange = null;
                        if (this.status === 200) {
                            var result = JSON.parse(this.response);
                            console.log(result);
                            // Columns
                            var pricelevelid = result["pricelevelid"]; // Guid
                            var dg_pricelisttype = result["dg_pricelisttype"]; // Choice
                            type = dg_pricelisttype;
                            var dg_pricelisttype_formatted = result["dg_pricelisttype@OData.Community.Display.V1.FormattedValue"];
                        } else {
                            console.log(this.responseText);
                        }
                    }
                };
                req.send();
                if (type == 140110001) {
                    formContext.getControl("dg_voc").setVisible(false);
                    //formContext.getControl("dg_contributionmargin").setVisible(false);
                }
            }
        }
    }
}

function EnableEffectiveto(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var effectiveTo = formContext.getControl("header_dg_effectivetodnl");
    if (effectiveTo) {
        effectiveTo.setDisabled(false);
    }
}

function avlquantity(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var quantity = formContext.getAttribute("quantity").getValue();
    var avlquantity = formContext.getAttribute("dg_availablequantity").getValue();
    if (avlquantity == null) {
        formContext.getAttribute("dg_availablequantity").setValue(quantity);
    }
}

function filterPackagingTypeDnl(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var pdt = formContext.getAttribute("productid").getValue();
    var packagingtype = formContext.getAttribute("dg_typeofpackaging").getValue();
    var dg_packagingtype_formatted = null;
    var purityd = formContext.getAttribute("dg_purity").getValue();
    if (pdt != null) {
        var packaging;
        var purity;
        var pdtId = pdt[0].id;
        pdtId = pdtId.replace('{', '').replace('}', '');
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/products(" + pdtId + ")?$select=dg_packagingtype,dg_purity", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var productid = result["productid"]; // Guid
                    var dg_packagingtype = result["dg_packagingtype"]; // Choice
                    packaging = dg_packagingtype;
                    var dg_packagingtype_formatted = result["dg_packagingtype@OData.Community.Display.V1.FormattedValue"];
                    var dg_purity = result["dg_purity"]; // Decimal
                    purity = dg_purity;
                    var dg_purity_formatted = result["dg_purity@OData.Community.Display.V1.FormattedValue"];
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
        if (packaging == 1) {

            formContext.getAttribute("dg_typeofpackaging").setValue(1);
        }

        if (packaging == 140110002) {

            formContext.getAttribute("dg_typeofpackaging").setValue(2);
        }
        if (packaging == 140110004) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110004);
        }
        if (packaging == 140110005) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110005);
        }
        if (packaging == 140110006) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110006);
        }
        if (packaging == "Bulk") {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110000);
        }
        if (packaging == 140110003) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110001);
        }
        if (packaging == 2) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110002);
        }
        if (packaging == 140110001) {

            formContext.getAttribute("dg_typeofpackaging").setValue(140110003);
        }
        if (purityd == null) {
            formContext.getAttribute("dg_purity").setValue(purity);
        }

    }
}
function ShowHideICISPriceList(executionContext) {
    //debugger;
    formContext = executionContext.getFormContext();
    var salesorg = formContext.getAttribute("dg_salesorganization").getValue();
    if (salesorg == 100) {
        formContext.getControl("dg_pricelist").setVisible(false);
        formContext.getControl("dg_icispremium").setVisible(false);
        formContext.getControl("dg_rbiipremium").setVisible(false);
    }
}

function ShowHideFormulaPricingDCTL(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    //var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract");
    if (salesContract != null) {
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractScheme = formContext.getAttribute("dg_icisperiods").getValue();
        var hidefields = ["priceperunit2", "dg_interestrateset1", "dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_agencycharges1", "dg_discount1", "dg_exworks1price", "dg_exworks1pricetotal", "dg_billingprice_new", "dg_billingpricedifference", "dg_contractdiscount", "dg_billingpricescdec", "dg_exworks2price", "dg_exworks2pricetotal", "dg_icisratednl", "dg_icisratednl1", "dg_conversionnorms", "dg_rbiexchangerate", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_baseprice1", "dg_cashdiscount1", "dg_traderdiscountvalue1", "dg_warehousepremium1", "dg_freightpershipmentpertrip2", "dg_freightamount2", "dg_freightcharges2", "dg_quantitydiscount1", "dg_exworkscharges1", "dg_ex_worksprice1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_adjustmentadder1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_specialdiscount1", "dg_commissionvalue2", "dg_tradediscount", "dg_traderdiscountpercentage1", "dg_traderdiscountvalue2", "dg_paymenttermdiscountinpercent1", "dg_paymenttermdiscountvalue1", "dg_forpricewithoutcommission1", "dg_fobcostwithcontributionmargin1", "dg_invoiceprice2", "dg_priceexcludingdiscount1", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_benchmarkpricedomestic1", "dg_benchmarkpriceexport1", "dg_deltap1", "dg_deltapexportpercent1", "dg_netrealization1", "dg_exporttotalprice1",
            "dg_paymentdays", "dg_basisofrbi", "dg_monthlycontractedquantity", "dg_quantitytolerance1", "dg_icisrate", "dg_exworks1price1", "dg_exworks1pricetotal1", "dg_exworks1price2", "dg_exworks2price1", "dg_exworks2pricetotal1", "dg_conversionnorms1", "dg_norm11", "dg_norm21", "dg_icispremium1", "dg_icispremiumvalue", "dg_icispremiumrate", "dg_rbiexchangerate1", "dg_rbiipremium1", "dg_rbipremiumvalue", "dg_rbiexchangeratewithpremium", "dg_contributionmarginpermt1", "dg_dutyfactor1", "dg_billingprice", "dg_dutyfactoramount1", "dg_otherexpenses", "dg_noofdrums", "dg_noofdays2", "dg_billingprice_new1", "dg_freightrecovered", "dg_freightincurred", "dg_quantitydiscountmonthly2", "dg_quantitydiscount2", "dg_quantitydiscountquarterly2", "dg_quantitydiscountyearly2", "dg_billingpricesc2", "dg_billingpricescdec1", "dg_commissionvaluepermt3", "dg_previousbillingprice2", "dg_initialbillingprice2", "dg_contractednsr1", "dg_benchmarkpricemd", "dg_deltapsc", "dg_rebookedorder1", "dg_rebookedfrom1"]
        for (var i = 0; i < hidefields.length; i++) {
            formContext.getControl(hidefields[i]).setVisible(false);
        }
        if (pricing != null && pricing != 140110006) {
            if (pricing == 140110005) {
                var showotpt = ["dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_conversionnorms", "dg_usdtosc", "dg_norm1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]
                for (var i = 0; i < showotpt.length; i++) {

                    formContext.getControl(showotpt[i]).setVisible(true);

                }
            }
            else if (pricing == 140110004) {
                var showehnexport = ["dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_ex_worksprice1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

                for (var i = 0; i < showehnexport.length; i++) {
                    formContext.getControl(showehnexport[i]).setVisible(true);
                }
            }
            else if (pricing == 140110002) {
                var showcontract = ["dg_pershipmentqtymt2", "dg_icisratednl1", "dg_conversionnorms", "dg_usdtosc", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

                for (var i = 0; i < showcontract.length; i++) {
                    formContext.getControl(showcontract[i]).setVisible(true);
                }
            }
            else if (pricing == 140110003) {
                var showehndomestic = ["dg_interestrateset1", "dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_rbiexchangerate", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_fixedcomponentprice", "dg_baseprice1", "dg_cashdiscount1", "dg_traderdiscountvalue1", "dg_warehousepremium1", "dg_freightpershipmentpertrip2", "dg_freightamount2", "dg_freightcharges2", "dg_quantitydiscount1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_commissionvaluepermt2", "dg_specialdiscount1", "dg_commissionvalue2", "dg_invoiceprice2", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_benchmarkpricedomestic1", "dg_deltap1", "dg_netrealization1"]

                for (var i = 0; i < showehndomestic.length; i++) {
                    formContext.getControl(showehndomestic[i]).setVisible(true);
                }
            }
            else if (pricing == 140110001) {
                var show4nox = ["dg_pershipmentqtymt2", "dg_agencycharges1", "dg_discount1", "dg_exworks1price", "dg_exworks1pricetotal", "dg_billingprice_new", "dg_billingpricedifference", "dg_contractdiscount", "dg_billingpricescdec", "dg_exworks2price", "dg_exworks2pricetotal", "dg_conversionnorms", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_discountpermt1", "dg_ex_worksprice1", "dg_freightamount2", "dg_freightpershipmentpertrip2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1"]
                for (var i = 0; i < show4nox.length; i++) {
                    formContext.getControl(show4nox[i]).setVisible(true);
                }
            }
            else if (pricing == 140110000) {
                if (contractScheme != null && contractScheme == 140110004) {
                    var showfiedexport = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_fobcostwithcontributionmargin1", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_benchmarkpriceexport1", "dg_deltapexportpercent1", "dg_exporttotalprice1"]
                    for (var i = 0; i < showfiedexport.length; i++) {
                        formContext.getControl(showfiedexport[i]).setVisible(true);
                    }
                }
                else if (contractScheme != null && contractScheme == 140110005) {
                    var showfieddomestic = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_warehousepremium1", "dg_freightpershipmentpertrip2", "dg_freightamount2", "dg_freightcharges2", "dg_ex_worksprice1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adjustmentadder1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_commissionvalue2", "dg_tradediscount", "dg_traderdiscountpercentage1", "dg_traderdiscountvalue2", "dg_paymenttermdiscountinpercent1", "dg_paymenttermdiscountvalue1", "dg_forpricewithoutcommission1", "dg_invoiceprice2", "dg_priceexcludingdiscount1", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_benchmarkpricedomestic1", "dg_deltap1", "dg_netrealization1"]
                    for (var i = 0; i < showfieddomestic.length; i++) {
                        formContext.getControl(showfieddomestic[i]).setVisible(true);
                    }
                }
            }
            ShowHideBasedOnIncoterms(executionContext);
            ShowHideContribution(executionContext);
            ShowHideCommission(executionContext);
            ShowHideTrade(executionContext);
            MakeFeildNonMandatoryDCTL1(executionContext, contractScheme, pricing);
            MakeFeildsReadOnly(executionContext, pricing);
        }
        else if (pricing != null && pricing == 140110006) {
            var show = ["dg_paymentdays", "dg_basisofrbi", "dg_monthlycontractedquantity", "dg_quantitytolerance1"];
            for (var i = 0; i < show.length; i++) {
                formContext.getControl(show[i]).setVisible(true);
            }
            if (contractScheme != 140110006 && contractScheme != 140110007 && contractScheme != 140110008 && contractScheme != 140110009 && contractScheme != 140110010) {
                var showfeilds = ["dg_icisrate", "dg_icispremium1", "dg_icispremiumvalue", "dg_icispremiumrate", "dg_rbiexchangerate1", "dg_rbiipremium1", "dg_rbipremiumvalue", "dg_rbiexchangeratewithpremium", "dg_dutyfactor1", "dg_dutyfactoramount1", "dg_otherexpenses", "dg_freightrecovered", "dg_freightincurred", "dg_quantitydiscoun2", "dg_quantitydiscountmonthly2", "dg_quantitydiscountquarterly2", "dg_quantitydiscountyearly2", "dg_billingpricesc2", "dg_billingpricescdec1", "dg_previousbillingprice2", "dg_initialbillingprice2", "dg_contractednsr1", "dg_benchmarkpricemd", "dg_deltapsc", "dg_rebookedorder1", "dg_rebookedfrom1"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }
            else if (contractScheme == 140110006) {
                showfeilds = ["dg_exworks1price1", "dg_exworks1pricetotal1", "dg_conversionnorms1", "dg_norm11", "dg_norm21", "dg_rbiexchangerate1", "dg_billingpricesc2", "dg_commissionvaluepermt2"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }
            else if (contractScheme == 140110007) {
                showfeilds = ["dg_exworks1price2", "dg_noofdays2", "dg_noofdrums", "dg_icispremiumrate", "dg_rbiexchangerate1", "dg_rbiexchangeratewithpremium", "dg_otherexpenses", "dg_billingpricesc2"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }
            else if (contractScheme == 140110008) {
                showfeilds = ["dg_exworks1price2", "dg_noofdrums", "dg_exworks2price1", "dg_exworks2pricetotal1", "dg_billingpricesc2"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }
            else if (contractScheme == 140110009) {
                showfeilds = ["dg_exworks1price2", "dg_icispremium1", "dg_icispremiumvalue", "dg_icispremiumrate", "dg_rbiexchangerate1", "dg_rbiipremium1", "dg_rbipremiumvalue", "dg_rbiexchangeratewithpremium", "dg_dutyfactor1", "dg_otherexpenses", "dg_billingpricesc2", "dg_commissionvaluepermt3", "dg_billingprice", "dg_contributionmarginpermt1"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }
            else if (contractScheme == 140110010) {
                showfeilds = ["dg_exworks1price2", "dg_icispremium1", "dg_icispremiumvalue", "dg_icispremiumrate", "dg_rbiexchangerate1", "dg_rbiipremium1", "dg_rbipremiumvalue", "dg_rbiexchangeratewithpremium", "dg_dutyfactor1", "dg_otherexpenses", "dg_billingpricesc2", "dg_commissionvaluepermt3", "dg_billingprice", "dg_freightrecovered", "dg_noofdays2", "dg_billingprice_new1", "dg_noofdrums"]
                for (var i = 0; i < showfeilds.length; i++) {
                    formContext.getControl(showfeilds[i]).setVisible(true);
                }
            }

        }
    }
}
function MakeFeildNonMandatoryDCTL1(econtext, contractScheme, pricing) {
    var formContext = econtext.getFormContext();
    var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var salesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    if (pricing != null && pricing == 140110000 && salesOrg == 3000) {
        if (incoterms != null && incoterms == 140110012) {
            formContext.getAttribute("dg_vehicletype").setRequiredLevel("none");
            formContext.getControl("dg_freightpershipmentpertrip2").setDisabled(true);
            formContext.getControl("dg_freightamount2").setDisabled(true);
            formContext.getControl("dg_freightcharges2").setDisabled(true);
        }
        else {
            formContext.getAttribute("dg_vehicletype").setRequiredLevel("required");
            formContext.getControl("dg_freightpershipmentpertrip2").setDisabled(false);
            formContext.getControl("dg_freightamount2").setDisabled(false);
            formContext.getControl("dg_freightcharges2").setDisabled(false);
        }
    }
}
function ShowHideFormulaPricing(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    //var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract");
    if (salesContract != null) {
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractScheme = formContext.getAttribute("dg_icisperiods").getValue();
        var hidefields = ["priceperunit2", "dg_interestrateset1", "dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_agencycharges1", "dg_discount1", "dg_exworks1price", "dg_exworks1pricetotal", "dg_billingprice_new", "dg_billingpricedifference", "dg_contractdiscount", "dg_billingpricescdec", "dg_exworks2price", "dg_exworks2pricetotal", "dg_icisratednl", "dg_icisratednl1", "dg_conversionnorms", "dg_rbiexchangerate", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_baseprice1", "dg_cashdiscount1", "dg_traderdiscountvalue1", "dg_warehousepremium1", "dg_freightpershipmentpertrip1", "dg_freightamount1", "dg_freightcharges1", "dg_quantitydiscount1", "dg_exworkscharges1", "dg_ex_worksprice1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_adjustmentadder1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_specialdiscount1", "dg_commissionvalue2", "dg_tradediscount", "dg_traderdiscountpercentage1", "dg_traderdiscountvalue2", "dg_paymenttermdiscountinpercent1", "dg_paymenttermdiscountvalue1", "dg_forpricewithoutcommission1", "dg_fobcostwithcontributionmargin1", "dg_invoiceprice2", "dg_priceexcludingdiscount1", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_benchmarkpricedomestic1", "dg_benchmarkpriceexport1", "dg_deltap1", "dg_deltapexportpercent1", "dg_netrealization1", "dg_exporttotalprice1"]
        for (var i = 0; i < hidefields.length; i++) {
            formContext.getControl(hidefields[i]).setVisible(false);
        }
        if (pricing == 140110005) {
            var showotpt = ["dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_conversionnorms", "dg_usdtosc", "dg_norm1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]
            for (var i = 0; i < showotpt.length; i++) {

                formContext.getControl(showotpt[i]).setVisible(true);

            }
        }
        else if (pricing == 140110004) {
            var showehnexport = ["dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_ex_worksprice1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

            for (var i = 0; i < showehnexport.length; i++) {
                formContext.getControl(showehnexport[i]).setVisible(true);
            }
        }
        else if (pricing == 140110002) {
            var showcontract = ["dg_pershipmentqtymt2", "dg_icisratednl1", "dg_conversionnorms", "dg_usdtosc", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

            for (var i = 0; i < showcontract.length; i++) {
                formContext.getControl(showcontract[i]).setVisible(true);
            }
        }
        else if (pricing == 140110003) {
            var showehndomestic = ["dg_interestrateset1", "dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_rbiexchangerate", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_fixedcomponentprice", "dg_baseprice1", "dg_cashdiscount1", "dg_traderdiscountvalue1", "dg_warehousepremium1", "dg_freightpershipmentpertrip1", "dg_freightamount1", "dg_freightcharges1", "dg_quantitydiscount1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_commissionvaluepermt2", "dg_specialdiscount1", "dg_commissionvalue2", "dg_invoiceprice2", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_benchmarkpricedomestic1", "dg_deltap1", "dg_netrealization1"]

            for (var i = 0; i < showehndomestic.length; i++) {
                formContext.getControl(showehndomestic[i]).setVisible(true);
            }
        }
        else if (pricing == 140110001) {
            var show4nox = ["dg_pershipmentqtymt2", "dg_agencycharges1", "dg_discount1", "dg_exworks1price", "dg_exworks1pricetotal", "dg_billingprice_new", "dg_billingpricedifference", "dg_contractdiscount", "dg_billingpricescdec", "dg_exworks2price", "dg_exworks2pricetotal", "dg_conversionnorms", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_discountpermt1", "dg_ex_worksprice1", "dg_freightamount1", "dg_freightpershipmentpertrip1", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1"]
            for (var i = 0; i < show4nox.length; i++) {
                formContext.getControl(show4nox[i]).setVisible(true);
            }
        }
        else if (pricing == 140110000) {
            if (contractScheme != null && contractScheme == 140110004) {
                var showfiedexport = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_fobcostwithcontributionmargin1", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_benchmarkpriceexport1", "dg_deltapexportpercent1", "dg_exporttotalprice1"]
                for (var i = 0; i < showfiedexport.length; i++) {
                    formContext.getControl(showfiedexport[i]).setVisible(true);
                }
            }
            else if (contractScheme != null && contractScheme == 140110005) {
                var showfieddomestic = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_warehousepremium1", "dg_freightpershipmentpertrip1", "dg_freightamount1", "dg_freightcharges1", "dg_ex_worksprice1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adjustmentadder1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_commissionvalue2", "dg_tradediscount", "dg_traderdiscountpercentage1", "dg_traderdiscountvalue2", "dg_paymenttermdiscountinpercent1", "dg_paymenttermdiscountvalue1", "dg_forpricewithoutcommission1", "dg_invoiceprice2", "dg_priceexcludingdiscount1", "dg_netprice1", "dg_difference1", "dg_systemprice1", "dg_cgst1", "dg_sgst1", "dg_igst1", "dg_pricewithtax1", "dg_priceafterdiscountwithquantity1", "dg_totalpricewithtax1", "dg_benchmarkpricedomestic1", "dg_deltap1", "dg_netrealization1"]
                for (var i = 0; i < showfieddomestic.length; i++) {
                    formContext.getControl(showfieddomestic[i]).setVisible(true);
                }
            }
        }
        ShowHideBasedOnIncoterms(executionContext);
        ShowHideContribution(executionContext);
        ShowHideCommission(executionContext);
        ShowHideTrade(executionContext);
        MakeFeildNonMandatory(executionContext, contractScheme, pricing);
        MakeFeildsReadOnly(executionContext, pricing);
    }
}
function MakeFeildsReadOnly(econtext, pricing) {
    var formContext = econtext.getFormContext();
    if (pricing == 140110000) {
        formContext.getControl("priceperunit2").setDisabled(true);
        formContext.getControl("dg_vocincludingpacking1").setDisabled(true);
        formContext.getControl("dg_packaging2").setDisabled(true);
        formContext.getControl("dg_secondarypackagingcharges1").setDisabled(true);
        formContext.getControl("dg_contributionmargin2").setDisabled(true);
        formContext.getControl("dg_priceexcludingdiscount1").setDisabled(true);
        formContext.getControl("dg_difference1").setDisabled(true);
        formContext.getControl("dg_systemprice1").setDisabled(true);
        formContext.getControl("dg_othercharges1").setDisabled(true);
        formContext.getControl("dg_discountpermt1").setDisabled(true);

    }
}
function MakeFeildNonMandatory(econtext, contractScheme, pricing) {
    var formContext = econtext.getFormContext();
    var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    if (pricing != null && pricing == 140110000) {
        if (incoterms != null && incoterms == 140110012) {
            formContext.getAttribute("dg_vehicletype").setRequiredLevel("none");
            formContext.getControl("dg_freightpershipmentpertrip1").setDisabled(true);
            formContext.getControl("dg_freightamount1").setDisabled(true);
            formContext.getControl("dg_freightcharges1").setDisabled(true);
        }
        else {
            formContext.getAttribute("dg_vehicletype").setRequiredLevel("required");
            formContext.getControl("dg_freightpershipmentpertrip1").setDisabled(false);
            formContext.getControl("dg_freightamount1").setDisabled(false);
            formContext.getControl("dg_freightcharges1").setDisabled(false);
        }
    }
}
function ShowHideBasedOnIncoterms(econtext) {
    var formContext = econtext.getFormContext();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract");
    if (salesContract != null) {
        var incoterms = formContext.getAttribute("dg_incoterms").getValue();
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractscheme = formContext.getAttribute("dg_icisperiods").getValue();
        if (pricing != null && incoterms != null) {
            if (pricing == 140110005) {
                var showotpt = ["dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_conversionnorms", "dg_usdtosc", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]
                for (var i = 0; i < showotpt.length; i++) {

                    formContext.getControl(showotpt[i]).setVisible(true);

                }
                if (incoterms == 140110001 || incoterms == 140110000) {
                    var hidefields = ["dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110019 || incoterms == 140110023) {
                    var hidefields = ["dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110020) {
                }
                else {
                    var hidefields = ["dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
            }
            else if (pricing == 140110004) {
                var showehnexport = ["dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_ex_worksprice1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

                for (var i = 0; i < showehnexport.length; i++) {
                    formContext.getControl(showehnexport[i]).setVisible(true);
                }
                if (incoterms == 140110001 || incoterms == 140110000) {
                    var hidefields = ["dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110019 || incoterms == 140110023) {
                    var hidefields = ["dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110020) {
                }
                else {
                    var hidefields = ["dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_dutyforeignportpermt1", "dg_competitorprice3", "dg_customduty", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
            }
            else if (pricing == 140110002) {
                var showcontract = ["dg_pershipmentqtymt2", "dg_icisratednl1", "dg_conversionnorms", "dg_usdtosc", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_exporttotalprice1"]

                for (var i = 0; i < showcontract.length; i++) {
                    formContext.getControl(showcontract[i]).setVisible(true);
                }
                if (incoterms == 140110001 || incoterms == 140110000) {
                    var hidefields = ["dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110019 || incoterms == 140110023) {
                    var hidefields = ["dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110020) {
                }
                else {
                    var hidefields = ["dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
            }
            else if (pricing == 140110000 && contractscheme != null && contractscheme == 140110004) {
                var showfiedexport = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_exworkscharges1", "dg_originchargespershipment1", "dg_origincharges1", "dg_discountpermt1", "dg_fobcost1", "dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvalue2", "dg_commissionvaluepermt2", "dg_fobcostwithcontributionmargin1", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_destinatioincharges1", "dg_benchmarkpriceexport1", "dg_deltapexportpercent1", "dg_exporttotalprice1"]
                for (var i = 0; i < showfiedexport.length; i++) {
                    formContext.getControl(showfiedexport[i]).setVisible(true);
                }
                if (incoterms == 140110001 || incoterms == 140110000) {
                    var hidefields = ["dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110019 || incoterms == 140110023) {
                    var hidefields = ["dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
                else if (incoterms == 140110020) {
                }
                else {
                    var hidefields = ["dg_oceanfreightpershipment1", "dg_oceanfreightpermt1", "dg_airfreight", "dg_cifcostpermt1", "dg_inlandhaulagepershipment1", "dg_inlandhaulages1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_storagecharges1", "dg_detentionpershipmentperday1", "dg_detentioncharges1", "dg_dapcostpermt1", "dg_dutyforeignport1", "dg_dutyforeignportpermt1", "dg_ddpcostpermt1"];
                    for (var i = 0; i < hidefields.length; i++) {
                        formContext.getControl(hidefields[i]).setVisible(false);
                    }
                }
            }
        }


    }
}

function ShowHideContribution(econtext) {
    var formContext = econtext.getFormContext();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    if (salesContract != null && (statusline == 1 || statusline == 140110000)) {
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractScheme = formContext.getAttribute("dg_icisperiods").getValue();
        if (pricing != null && pricing == 140110000) {
            var bool = formContext.getAttribute("dg_contributionmarginorvalue2").getValue();
            if (bool == false) {
                formContext.getControl("dg_contributionmargin2").setDisabled(true);
                formContext.getControl("dg_contributionmarginpercentage2").setVisible(true);
            }
            else if (bool == true) {
                formContext.getControl("dg_contributionmarginpercentage2").setVisible(false);
                formContext.getControl("dg_contributionmargin2").setDisabled(false);
            }

        }
    }
}
function ShowHideCommission(econtext) {
    var formContext = econtext.getFormContext();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    if (salesContract != null && (statusline == 1 || statusline == 140110000)) {
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractScheme = formContext.getAttribute("dg_icisperiods").getValue();
        if (pricing != null && (pricing == 140110000 || pricing == 140110002 || pricing == 140110004 || pricing == 140110005)) {
            var bool = formContext.getAttribute("dg_commissionorvalue2").getValue();
            if (bool == false) {
                formContext.getControl("dg_commissionvalue2").setDisabled(true);
                formContext.getControl("dg_commissionorvalue3").setVisible(true);
            }
            else if (bool == true) {
                formContext.getControl("dg_commissionorvalue3").setVisible(false);
                formContext.getControl("dg_commissionvalue2").setDisabled(false);
            }
        }
    }
}
function ShowHideTrade(econtext) {
    var formContext = econtext.getFormContext();
    var salesContract = null;
    salesContract = formContext.getAttribute("dg_salescontract").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    if (salesContract != null && (statusline == 1 || statusline == 140110000)) {
        var pricing = formContext.getAttribute("dg_formulapricing").getValue();
        var contractScheme = formContext.getAttribute("dg_icisperiods").getValue();
        if (pricing != null && pricing == 140110000 && contractScheme == 140110005) {
            var bool = formContext.getAttribute("dg_tradediscount").getValue();
            if (bool == false) {
                formContext.getControl("dg_traderdiscountpercentage1").setVisible(true);
                formContext.getControl("dg_traderdiscountvalue2").setDisabled(true);
            }
            else if (bool == true) {
                formContext.getControl("dg_traderdiscountpercentage1").setVisible(false);
                formContext.getControl("dg_traderdiscountvalue2").setDisabled(false);
            }
        }
    }
}
function RefreshFormOnApprovalDnl(executionContext) {
    //debugger;
    //debugger;
    var formContext = executionContext.getFormContext();
    var currentId = formContext.data.entity.getId();
    var quote = formContext.getAttribute("quoteid").getValue();
    var status = formContext.getAttribute("dg_approverejectoncustomerbehalf").getValue();
    var quoteid = quote[0].id;
    var statusLine = formContext.getAttribute("dg_statusline").getValue();
    var quoteIdfilter = quoteid.replace('{', '').replace('}', '');
    if (statusLine != 140110000) {
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotes(" + quoteIdfilter + ")?$select=dg_customstatus", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var customStatus = result["dg_customstatus"];
                    if (customStatus == 140110004 || customStatus == 140110002) {
                        if (status == 140110000) { ///Quote is active or partial won  and quoteline is pending
                            var cs = Xrm.Page.ui.controls.get();
                            for (var i in cs) {
                                var c = cs[i];
                                if ((c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf1") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf2") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf3") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf4") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf5") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf6") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf7") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf8") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf9") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf10") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf11") || (c.getName() != "" && c.getName() != null && c.getName() == "dg_approverejectoncustomerbehalf12")) {
                                    c.setDisabled(false);
                                }
                                else {
                                    c.setDisabled(true);
                                }
                            }
                        }

                        else { ///Quote is active and quoteline is rejected
                            var cs = Xrm.Page.ui.controls.get();
                            for (var i in cs) {
                                var c = cs[i];
                                if (c.getName() != "" && c.getName() != null) {
                                    if (!c.getDisabled()) {
                                        c.setDisabled(true);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        };
        req.send();
        var effectiveto = formContext.getControl("header_dg_effectivetodnl");
        if (effectiveto) {
            effectiveto.setDisabled(false);


        }
    }
}


function ppandfs(executionContext) {
    var formContext = executionContext.getFormContext();
    var dgDivision = formContext.getAttribute("dg_division").getValue();

    // Fields to show if dg_division is 40 or 50  
    var fieldsToShowFor40And50 = [
        "dg_voc", "dg_exworksprice", "dg_forpricewithoutcommission", "dg_commissionorvalue",
        "dg_commissionvalue", "dg_traderdiscount",
        "dg_paymenttermdiscountinpercent", "dg_paymenttermdiscountvalue",
        "dg_productpaymentterms",
        "dg_quotepaymentterms", "dg_priceexcludingdiscount", "dg_netprice",
    ];

    // Fields to hide if dg_division is 40 or 50  
    var fieldsToHideFor40And50 = [
        "dg_interestrateset", "dg_interestamount",
        "dg_paymenttermadjustment", "dg_baseprice", "dg_cashdiscount",
        "dg_specialdiscount", "dg_quantitydiscountmonthly",
        "dg_quantitydiscountquarterly", "dg_quantitydiscounthalfyearly",
        "dg_quantitydiscountyearly", "dg_quantitydiscount",
    ];

    // Fields to show if dg_division is 30  
    var fieldsToShowFor30 = [
        "dg_voc",
        "dg_interestrateset", "dg_productpaymentterms", "dg_interestamount",
        "dg_paymenttermadjustment", "dg_baseprice", "dg_cashdiscount",
        "dg_specialdiscount", "dg_quantitydiscountmonthly",
        "dg_quantitydiscountquarterly", "dg_quantitydiscounthalfyearly",
        "dg_quantitydiscountyearly", "dg_commissionvalue",
    ];

    // Fields to hide if dg_division is 30  
    var fieldsToHideFor30 = [
        "dg_exworksprice", "dg_forpricewithoutcommission", "dg_commissionorvalue",
        "dg_paymenttermdiscountinpercent", "dg_paymenttermdiscountvalue", "dg_priceexcludingdiscount",
    ];

    function setFieldVisibility(fieldsToShow, fieldsToHide) {
        fieldsToShow.forEach(function (field) {
            var control = formContext.getControl(field);
            if (control) {
                control.setVisible(true);
            }
        });

        fieldsToHide.forEach(function (field) {
            var control = formContext.getControl(field);
            if (control) {
                control.setVisible(false);
            }
        });
    }

    if (dgDivision === 40 || dgDivision === 50) {
        setFieldVisibility(fieldsToShowFor40And50, fieldsToHideFor40And50);
    } else if (dgDivision === 30 || dgDivision === 95) {
        setFieldVisibility(fieldsToShowFor30, fieldsToHideFor30);
    }

    // Ensure the function is attached to the OnChange event of the dg_division field  
    formContext.getAttribute("dg_division").removeOnChange(ppandfs);
    formContext.getAttribute("dg_division").addOnChange(ppandfs);
}

function ppandfsDCTL(executionContext) {
    var formContext = executionContext.getFormContext();
    var dgDivision = formContext.getAttribute("dg_division").getValue();

    // Fields to show if dg_division is 40 or 50  
    var fieldsToShowFor40And50 = [
        "dg_voc", "dg_exworksprice", "dg_forpricewithoutcommission", "dg_commissionorvalue",
        "dg_commissionvalue", "dg_traderdiscount",
        "dg_paymenttermdiscountinpercent", "dg_paymenttermdiscountvalue",
        "dg_productpaymentterms",
        "dg_quotepaymentterms", "dg_priceexcludingdiscount", "dg_netprice",
    ];

    // Fields to hide if dg_division is 40 or 50  
    var fieldsToHideFor40And50 = [
        "dg_interestrateset", "dg_contractdiscountmonthly", "dg_airfreightpershipment", "dg_interestamount",
        "dg_paymenttermadjustment", "dg_baseprice", "dg_cashdiscount",
        "dg_specialdiscount", "dg_quantitydiscountmonthly",
        "dg_quantitydiscountquarterly", "dg_quantitydiscounthalfyearly",
        "dg_quantitydiscountyearly", "dg_quantitydiscount", "dg_dutyfactor", "dg_freightcharges1", "dg_freightamount1", "dg_freightadder", "dg_otherexpense", "dg_otherexpense2", "dg_airfreightpermt", "dg_freightpershipmentpertrip1",
    ];

    // Fields to show if dg_division is 30  
    var fieldsToShowFor30 = [
        "dg_voc",
        "dg_interestrateset", "dg_productpaymentterms", "dg_interestamount",
        "dg_paymenttermadjustment", "dg_baseprice", "dg_cashdiscount",
        "dg_specialdiscount", "dg_quantitydiscountmonthly",
        "dg_quantitydiscountquarterly", "dg_quantitydiscounthalfyearly",
        "dg_quantitydiscountyearly", "dg_commissionvalue",
    ];

    // Fields to hide if dg_division is 30  
    var fieldsToHideFor30 = [
        "dg_exworksprice", "dg_contractdiscountmonthly", "dg_airfreightpershipment", "dg_forpricewithoutcommission", "dg_commissionorvalue",
        "dg_paymenttermdiscountinpercent", "dg_paymenttermdiscountvalue", "dg_priceexcludingdiscount", "dg_dutyfactor", "dg_freightcharges1", "dg_freightamount1", "dg_freightadder", "dg_otherexpense", "dg_otherexpense2", "dg_airfreightpermt", "dg_freightpershipmentpertrip1",
    ];
    var feildsroshow20 = ["priceperunit", "dg_freightmaster", "dg_contractdiscountmonthly", "dg_airfreightpershipment", "dg_packaging", "dg_packagingservices", "dg_baseprice", "dg_dutyfactor", "dg_warehousepremium", "dg_freightcharges1", "dg_freightamount1", "dg_freightadder", "dg_freightpershipmentpertrip1", "dg_otherexpense", "dg_otherexpense2", "dg_commissionorvalue2", "dg_commissionorvalue", "dg_commissionvalue", "dg_specialdiscount", "dg_quantitydiscountmonthly"];
    var feildstohide20 = ["dg_commissionvaluepermt", "dg_freightpershipmentpertrip", "dg_voc", "dg_contributionmarginorvalue2", "dg_contributionmarginpercentage", "dg_contributionmargin", "baseamount", "dg_newbillingprice", "dg_interestrateset", "dg_paymenttermadjustment", "dg_interestamount", "dg_airfreightpermt", "dg_daysdifference", "dg_daysdifference", "dg_freightamount", "dg_freightcharges", "dg_freighttolerance", "dg_exworksprice", "dg_forpricewithoutcommission", "dg_cashdiscount", "dg_priceafterdiscount", "dg_traderdiscount", "dg_traderdiscountpercentage", "dg_traderdiscountvalue", "dg_paymenttermdiscountinpercent", "dg_paymenttermdiscountinpercent"];

    var exportfeildsshow = ["dg_commissionvaluepermt1", "priceperunit1", "dg_pershipmentqtymt1", "dg_vocincludingpacking", "dg_drumcost", "dg_packaging1", "dg_secondarypackagingcharges", "dg_othercharges", "dg_exworkscharges", "dg_originchargespershipment", "dg_origincharges", "dg_discountpermt", "dg_fobcost", "dg_oceanfreightpershipment", "dg_oceanfreightpermt", "dg_airfreightpermt1", "dg_cifcostpermt", "dg_inlandhaulagepershipment", "dg_inlandhaulages", "dg_dthcpershipment", "dg_dthcpermt", "dg_noofdays", "dg_storagechargespershipmentperday", "dg_storagecharges", "dg_storagecharges", "dg_drumfreight", "dg_drumfreight", "dg_dapcostpermt", "dg_exportlocalcharges", "dg_domesticcharges", "dg_dutydrawback", "dg_exportincentive", "dg_exporttotallineamount", "dg_moneybillingprice1", "dg_hiddenbillingprice1", "dg_hiddenbillingprice1", "dg_dutyforeignportpermt", "dg_ddpcostpermt", "dg_contributionmarginorvalue21", "dg_contributionmarginpercentage1", "dg_contributionmargin1", "dg_adderpermt", "dg_commissionorvalue21", "dg_commissionorvalue1", "dg_commissionvalue1", "dg_commissionvalue1", "dg_fobfreeonrailpricepermt", "dg_fobfreeonrailpricepermt", "dg_invoiceprice1", "dg_ex_worksprice", "dg_netrealizationexport", "dg_exporttotalprice", "dg_benchmarkpriceexport", "dg_deltapexportpercent", "dg_destinatioincharges", "dg_exportunitrate"];
    var exportfeildshide = ["dg_seafreight", "dg_routeselected1", "dg_packagingcharges", "dg_cifpricepermt", "dg_drummingcost", "dg_commissioncurrency", "dg_contributionmarginvalue", "dg_transportationcharges", "dg_fobprice", "dg_dutydrawback1", "dg_contributionmarginpermt"];

    var exportsolvenshow = ["priceperunit1", "dg_seafreight", "dg_routeselected1", "dg_packagingcharges", "dg_packaging1", "dg_cifpricepermt", "dg_drummingcost", "dg_commissioncurrency", "dg_contributionmarginvalue", "dg_transportationcharges", "dg_othercharges", "dg_commissionorvalue21", "dg_commissionorvalue1", "dg_commissionvalue1", "dg_commissionvaluepermt1", "dg_invoiceprice1", "dg_netrealizationexport", "dg_fobprice", "dg_dutydrawback1", "dg_contributionmarginpermt"];
    var exportsolventhide = ["dg_detentionpershipmentperday", "dg_dutyforeignport", "dg_detentioncharges", "dg_contributionmarginpercentage1", "dg_contributionmargin1", "dg_fobcostwithcontributionmargin", "dg_cifcfrpricepermt", "dg_pershipmentqtymt1", "dg_vocincludingpacking", "dg_drumcost", "dg_secondarypackagingcharges", "dg_exworkscharges", "dg_originchargespershipment", "dg_origincharges", "dg_discountpermt", "dg_fobcost", "dg_oceanfreightpershipment", "dg_oceanfreightpermt", "dg_airfreightpermt1", "dg_cifcostpermt", "dg_inlandhaulagepershipment", "dg_inlandhaulages", "dg_dthcpershipment", "dg_dthcpermt", "dg_noofdays", "dg_storagechargespershipmentperday", "dg_storagecharges", "dg_storagecharges", "dg_drumfreight", "dg_drumfreight", "dg_dapcostpermt", "dg_exportlocalcharges", "dg_domesticcharges", "dg_dutydrawback", "dg_exportincentive", "dg_exporttotallineamount", "dg_moneybillingprice1", "dg_hiddenbillingprice1", "dg_hiddenbillingprice1", "dg_dutyforeignportpermt", "dg_ddpcostpermt", "dg_contributionmarginorvalue21", "dg_contributionmarginpercentage1", "dg_contributionmargin1", "dg_adderpermt", "dg_commissionvalue1", "dg_fobfreeonrailpricepermt", "dg_fobfreeonrailpricepermt", "dg_ex_worksprice", "dg_exporttotalprice", "dg_benchmarkpriceexport", "dg_deltapexportpercent", "dg_destinatioincharges", "dg_exportunitrate"];

    function setFieldVisibility(fieldsToShow, fieldsToHide) {
        fieldsToShow.forEach(function (field) {
            var control = formContext.getControl(field);
            if (control) {
                control.setVisible(true);
            }
        });

        fieldsToHide.forEach(function (field) {
            var control = formContext.getControl(field);
            if (control) {
                control.setVisible(false);
            }
        });
    }

    if (dgDivision === 40 || dgDivision === 50) {
        setFieldVisibility(fieldsToShowFor40And50, fieldsToHideFor40And50);
        setFieldVisibility(exportfeildsshow, exportfeildshide);
    } else if (dgDivision === 30 || dgDivision == 95) {
        setFieldVisibility(fieldsToShowFor30, fieldsToHideFor30);
        setFieldVisibility(exportfeildsshow, exportfeildshide);
    } else if (dgDivision == 20) {
        setFieldVisibility(feildsroshow20, feildstohide20);
        setFieldVisibility(exportsolvenshow, exportsolventhide);
        LockCommisionFeild(executionContext);
        ShowHidePackingDrum(executionContext);
        NonMandatetoryPershipmentQuantity(executionContext);
    }

    // Ensure the function is attached to the OnChange event of the dg_division field  
    // formContext.getAttribute("dg_division").removeOnChange(ppandfs);
    // formContext.getAttribute("dg_division").addOnChange(ppandfs);
}
function NonMandatetoryPershipmentQuantity(econtext) {
    var formContext = econtext.getFormContext();
    var dgDivision = formContext.getAttribute("dg_division").getValue();
    var salesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    if (salesOrg != null && salesOrg == 3000 && dgDivision != null && dgDivision == 20) {
        formContext.getAttribute("dg_pershipmentqtymt").setRequiredLevel("none");
    }
}
function LockCommisionFeild(econtext) {
    var formContext = econtext.getFormContext();
    var dgDivision = formContext.getAttribute("dg_division").getValue();
    var salesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    if (salesOrg != null && dgDivision != null && dgDivision == 20 && salesOrg == 3000) {
        formContext.getControl("dg_commissionorvalue21").setDisabled(true);
    }
}
function ShowHidePackingDrum(econtext) {
    var formContext = econtext.getFormContext();
    var TypeOfPackaging = formContext.getAttribute("dg_typeofpackaging").getValue();
    var dgDivision = formContext.getAttribute("dg_division").getValue();
    if (dgDivision == 20 && TypeOfPackaging != null && TypeOfPackaging == 140110002) {
        formContext.getControl("dg_packaging1").setVisible(false);
        formContext.getControl("dg_cifpricepermt").setVisible(false);
        formContext.getControl("dg_drummingcost").setVisible(false);
    }
}
function mandate(executionContext) {
    MakeFieldMandatory("dg_pershipmentqtymt", executionContext);
}
function MakeFieldMandatory(fieldName, executionContext) {
    var formContext = executionContext.getFormContext();
    if (formContext.getAttribute(fieldName) != null) {
        ShowField(fieldName, executionContext);
        formContext.getAttribute(fieldName).setRequiredLevel("required");
    }
}

function OnchangeOfProduct(executionContext) {
    var formContext = executionContext.getFormContext();
    var product = formContext.getAttribute("productid").getValue();
    if (product == null) {
        formContext.getAttribute("dg_warehouse").setValue(null);
    }
}
var productinWH = "";
var salesOrgOption = "";
var formatGetCreatedOn = "";
function FilterWarehouse(executionContext) {
    //er;
    var formContext = executionContext.getFormContext();
    var salesArea = formContext.getAttribute("dg_salesarea").getValue();
    var attribute = formContext.getAttribute("dg_warehouse");
    productinWH = formContext.getAttribute("productid").getValue();
    if (productinWH != null) {
        productinWH = productinWH[0].id.replace("{", "").replace("}", "");
        if (salesArea !== null) {
            try {
                salesArea = salesArea[0].id.replace("{", "").replace("}", "");
                var req = new XMLHttpRequest();
                req.open("GET", Xrm.Page.context.getClientUrl() + "/api/data/v9.1/dg_salesareas(" + salesArea + ")?$select=dg_salesorganization", false);
                req.setRequestHeader("OData-MaxVersion", "4.0");
                req.setRequestHeader("OData-Version", "4.0");
                req.setRequestHeader("Accept", "application/json");
                req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
                req.setRequestHeader("Prefer", "odata.include-annotations=\"*\"");
                req.onreadystatechange = function () {
                    if (this.readyState === 4) {
                        req.onreadystatechange = null;
                        if (this.status === 200) {
                            var result = JSON.parse(this.response);
                            salesOrgOption = result["dg_salesorganization"];
                            dg_salesorganization_formatted = result["dg_salesorganization@OData.Community.Display.V1.FormattedValue"];
                        } else {
                            Xrm.Utility.alertDialog(this.statusText);
                        }
                    }
                };
                req.send();
            }
            catch (error) {
                console.log(error.message);
            }
        }
        formatGetCreatedOn = formContext.getAttribute("createdon").getValue();
        if (productinWH != null) {
            if (formatGetCreatedOn) {
                var dateObject = new Date(formatGetCreatedOn);
                formatGetCreatedOn = dateObject.getFullYear() + "-" + (dateObject.getMonth() + 1) + "-" + dateObject.getDate();
            }
        }
        addCustomView(executionContext, productinWH, formatGetCreatedOn)
        //attribute.controls.forEach(control => control.addPreSearch(myPreSearchCallBack));
    }
}

function myPreSearchCallBack(executionContext) {
    var control = executionContext.getEventSource();
    addCustomView(control);
}

function addCustomView(econtext, productinWH, formatGetCreatedOn) {
    var formContext = econtext.getFormContext();
    var viewId = "{00000000-0000-0000-0000-000000000002}";
    var entityName = "dg_warehousepremiummaster";
    var viewDisplayName = "Warehouse View";

    var fetchXml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
        "<entity name='dg_warehousepremiummaster'>" +
        "<attribute name='dg_warehousepremiummasterid'/>" +
        "<attribute name='dg_name'/>" +
        "<attribute name='createdon'/>" +
        "<order attribute='dg_name' descending='false'/>" +
        "<filter type='and'>" +
        "<condition attribute='dg_product' operator='eq' uitype='product' value='{" + productinWH + "}'/>" +
        "<condition attribute='dg_todate' operator='on-or-after' value='" + formatGetCreatedOn + "'/>" +
        "<condition attribute='dg_fromdate' operator='on-or-before' value='" + formatGetCreatedOn + "'/>" +
        "<condition attribute='dg_salesorganization' operator='eq' value='1000'/>" +
        "<condition attribute='statecode' operator='eq' value='0'/>" +
        "</filter>" +
        "</entity>" +
        "</fetch>";
    var layoutXml = "<grid name='resultset' object='10841' jump='dg_name' select='1' icon='1' preview='1'><row name='result' id='dg_warehousepremiummasterid'><cell name='dg_name' width='300' /><cell name='createdon' width='125' /></row></grid>";
    formContext.getControl("dg_warehouse").addCustomView(viewId, entityName, viewDisplayName, fetchXml, layoutXml, true);
    //var layoutXml = "<grid name=&quot;resultset&quot; jump=&quot;dg_name&quot; select=&quot;1&quot; preview=&quot;1&quot; icon=&quot;1&quot; object=&quot;10841&quot;><row name=&quot;result&quot; id=&quot;dg_warehousepremiummasterid&quot;><cell name=&quot;dg_name&quot; width=&quot;100&quot; imageproviderfunctionname=&quot;&quot; imageproviderwebresource=&quot;$webresource:&quot;/><cell name=&quot;dg_salesorganization&quot; width=&quot;146&quot;/><cell name=&quot;dg_product&quot; width=&quot;100&quot; imageproviderfunctionname=&quot;&quot; imageproviderwebresource=&quot;$webresource:&quot;/><cell name=&quot;dg_plant&quot; width=&quot;100&quot; imageproviderfunctionname=&quot;&quot; imageproviderwebresource=&quot;$webresource:&quot;/><cell name=&quot;dg_locationcode&quot; width=&quot;100&quot; imageproviderfunctionname=&quot;&quot; imageproviderwebresource=&quot;$webresource:&quot;/></row></grid>";
    //control.addCustomView(viewId, entityName, viewDisplayName, fetchXml, layoutXml, true);  
}

function InterestaarteMandatory(executionContext) {
    // debugger;
    var formContext = executionContext.getFormContext();
    var division = formContext.getAttribute("dg_division").getValue();
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();

    if (pricelist != null) {
        var Plid = pricelist[0].id.replace('{', '').replace('}', '');
        if (division == 30 || division == 95) {
            var type = "";
            // Fetch type
            var req = new XMLHttpRequest();
            req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/pricelevels(" + Plid + ")?$select=dg_pricelisttype", false);
            req.setRequestHeader("OData-MaxVersion", "4.0");
            req.setRequestHeader("OData-Version", "4.0");
            req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
            req.setRequestHeader("Accept", "application/json");
            req.setRequestHeader("Prefer", "odata.include-annotations=*");
            req.onreadystatechange = function () {
                if (this.readyState === 4) {
                    req.onreadystatechange = null;
                    if (this.status === 200) {
                        var result = JSON.parse(this.response);
                        console.log(result);
                        var dg_pricelisttype = result["dg_pricelisttype"]; // Choice
                        type = dg_pricelisttype;
                    } else {
                        console.log(this.responseText);
                    }
                }
            };
            req.send();

            if (type == 140110001) {
                formContext.getAttribute("dg_interestrateset").setRequiredLevel("required");
            }
        }
    }

    // Check if the interest rate lookup field is null
    var interestRateLookup = formContext.getAttribute("dg_interestrateset").getValue();
    if (interestRateLookup == null) {
        // Fetch the interest rate record GUID dynamically
        Xrm.WebApi.retrieveMultipleRecords("dg_generalmaster", "?$filter=dg_name eq 'Interest Rate: 0'&$select=dg_generalmasterid,dg_interest").then(
            function success(results) {
                if (results.entities.length > 0) {
                    var interestRateRecord = results.entities[0]; // Assuming there is only one record
                    var interestRateId = interestRateRecord["dg_generalmasterid"]; // Guid

                    // Use the retrieved ID to get the specific interest rate record
                    Xrm.WebApi.retrieveRecord("dg_generalmaster", interestRateId, "?$select=dg_interest,dg_name,dg_type").then(
                        function success(result) {
                            console.log(result);
                            var lookupValue = new Array();
                            lookupValue[0] = new Object();
                            lookupValue[0].id = interestRateId;
                            lookupValue[0].name = "Interest Rate: 0"; // Set default value
                            lookupValue[0].entityType = "dg_generalmaster";
                            formContext.getAttribute("dg_interestrateset").setValue(lookupValue);
                        },
                        function (error) {
                            console.log(error.message);
                        }
                    );
                } else {
                    console.log("No interest rate record found with dg_name 'Interest Rate: 0'.");
                }
            },
            function (error) {
                console.log(error.message);
            }
        );
    } else {
        console.log("Interest rate lookup field already has a value.");
    }
}


//////////////////////////////////////////////////////////////////////////////////////
function OrderCancel(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var OrderCancelflag = formContext.getAttribute("dg_ordercancelflag").getValue();
    var QPstatus = formContext.getAttribute("dg_statusline").getValue();

    if (OrderCancelflag != null && OrderCancelflag == 140110001 && QPstatus == 4) {
        formContext.getAttribute("dg_ordercancelflag").setValue(140110000);
        formContext.getAttribute("dg_statusline").setValue(4);
    }

}
function exworks(executionContext) {
    //er;
    var formContext = executionContext.getFormContext(); // Get the form context
    var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var salescontract = formContext.getAttribute("dg_salescontract").getValue();

    if (salescontract == null) {
        var division = formContext.getAttribute("dg_division").getValue();
        if (division != null && (division == 30 || division == 40 || division == 50 || division == 95)) {
            // Check if dg_incoterms equals 140110012
            if (incoterms === 140110012) {
                // Lock dg_freightamount and dg_freightcharges
                formContext.getControl("dg_freightamount").setDisabled(true);
                formContext.getControl("dg_freightcharges").setDisabled(true);
                formContext.getControl("dg_freightmaster").setDisabled(true);
                formContext.getControl("dg_freightpershipmentpertrip").setDisabled(true);
                formContext.getAttribute("dg_vehicletype").setRequiredLevel("none");
                formContext.getControl("dg_vehicletype1").setDisabled(true);
                formContext.getControl("dg_vehicletype").setDisabled(true);
                formContext.getControl("dg_vehicletypefreetext").setDisabled(true);
                formContext.getControl("dg_vehicletypefreetext1").setDisabled(true);
            } else {
                // Unlock dg_freightamount and dg_freightcharges
                formContext.getControl("dg_freightamount").setDisabled(false);
                formContext.getControl("dg_freightcharges").setDisabled(false);
                formContext.getControl("dg_freightmaster").setDisabled(false);
                formContext.getControl("dg_freightpershipmentpertrip").setDisabled(false);
                formContext.getAttribute("dg_vehicletype").setRequiredLevel("required");
                formContext.getControl("dg_vehicletype").setDisabled(false);
                formContext.getControl("dg_vehicletype1").setDisabled(false);
                formContext.getControl("dg_vehicletypefreetext").setDisabled(false);
                formContext.getControl("dg_vehicletypefreetext1").setDisabled(false);
            }
        }
    }
	exworksDCTL(executionContext);
}
function exworksDCTL(executionContext) {
    var formContext = executionContext.getFormContext();
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();
    //var division = formContext.getAttribute("dg_division").getValue();
    var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    //var salescontract = formContext.getAttribute("dg_salescontract").getValue();
    if (pricelist != null && pricelist.length > 0) {
        var pricelistId = pricelist[0].id;

        // Fetch the related record using OData or Web API
        Xrm.WebApi.retrieveRecord("pricelevel", pricelistId, "?$select=dg_pricelisttype").then(
            function (result) {
                var pricelistType = result.dg_pricelisttype;

                if (pricelistType === 140110001 && (SalesOrg!==null && SalesOrg == 3000) && incoterms == 140110012 && (division == 30 || division == 95 || division == 40)) {// domestic and exworks
                    formContext.getAttribute("dg_freightcharges").setRequiredLevel("none");
                }
                else if(pricelistType === 140110001 && (SalesOrg!==null && SalesOrg == 3000) && incoterms != 140110012 && (division == 30 || division == 95 || division == 40)){//domestic and non exworks
                    formContext.getAttribute("dg_freightcharges").setRequiredLevel("required");
                }
                if (pricelistType === 140110001 && (SalesOrg!==null && SalesOrg == 3000) && incoterms == 140110012 && (division == 20)) {// domestic and exworks
                    formContext.getAttribute("dg_freightpershipmentpertrip").setRequiredLevel("none");
                }
                else if(pricelistType === 140110001 && (SalesOrg!==null && SalesOrg == 3000) && incoterms != 140110012 && (division == 20)){//domestic and non exworks
                    formContext.getAttribute("dg_freightpershipmentpertrip").setRequiredLevel("required");
                }
                else if(pricelistType === 140110000 && (SalesOrg!==null && SalesOrg == 3000) && incoterms == 140110012 && division == 20){//export and exworks
                        formContext.getAttribute("dg_seafreight").setRequiredLevel("none");
                }
                else if(pricelistType === 140110000 && (SalesOrg!==null && SalesOrg == 3000) && incoterms != 140110012 && division == 20){////export and non exworks
                    formContext.getAttribute("dg_seafreight").setRequiredLevel("required");

                }
                else if(pricelistType === 140110000 && (SalesOrg!==null && SalesOrg == 3000) && incoterms == 140110012 && (division == 30 || division == 95 || division == 40)){//export and exworks
                        formContext.getAttribute("dg_oceanfreightpershipment").setRequiredLevel("none");
                }
                else if(pricelistType === 140110000 && (SalesOrg!==null && SalesOrg == 3000) && incoterms != 140110012 && (division == 30 || division == 95 || division == 40)){////export and non exworks
                    formContext.getAttribute("dg_oceanfreightpershipment").setRequiredLevel("required");

                }

            },
            function (error) {
                console.log(error.message);
            }
        );
    }
}
function setlookupValue(executionContext) {
    var formContext = executionContext.getFormContext();
    var dg_materialgroup = formContext.getAttribute("dg_materialgroup").getValue();
    //  var dg_materialgroup = GetValue("dg_materialgroup", executionContext);
    if (dg_materialgroup != null) {
        var dg_materialgroupID = dg_materialgroup[0].id.replace('{', '').replace('}', '');

        if (dg_materialgroupID != null) {


            var viewFetchXml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
                "  <entity name='product'>" +
                "    <attribute name='name' />" +
                "    <attribute name='productid' />" +
                "    <attribute name='productnumber' />" +
                "    <attribute name='description' />" +
                "    <attribute name='statecode' />" +
                "    <attribute name='productstructure' />" +
                "    <order attribute='productnumber' descending='false' />" +
                "    <filter type='and'>" +
                "      <condition attribute='dg_materialgroup' operator='eq' value='" + dg_materialgroupID + "' />" +
                "      <condition attribute='statecode' operator='eq' value='0' />" +
                "    </filter>" +
                "    <link-entity name='dg_materialgroup' from='dg_materialgroupid' to='dg_materialgroup' visible='false' link-type='outer' alias='a_4d0673bc97f8ed118f6e002248d5d779'>" +
                "      <attribute name='dg_division' />" +
                "    </link-entity>" +
                "  </entity>" +
                "</fetch>";
            var layoutXml = "<grid name='resultset' object='1024' jump='name' select='1' icon='1' preview='1'>" +
                "<row name='result' id='productid'>" +
                "<cell name= 'name' width='150' />" +
                "<cell name= 'productnumber' width='150' />" +
                "</row>" +
                "</grid>";

            var viewId = "{00000000-0000-0000-0000-000000000005}";
            formContext.getControl("productid").addCustomView(viewId, "product", "Products Custom View", viewFetchXml, layoutXml, true);
            formContext.getControl("productid1").addCustomView(viewId, "product", "Products Custom View", viewFetchXml, layoutXml, true);
            formContext.getControl("productid2").addCustomView(viewId, "product", "Products Custom View", viewFetchXml, layoutXml, true);

        }
    }

}

function commissionforbi(executionContext) {
    var formContext = executionContext.getFormContext(); // Get the form context
    var division = formContext.getAttribute("dg_division").getValue();
    var dg_incoterms = formContext.getAttribute("dg_incoterms").getValue();

    if ((division === 30 || division === 95) && dg_incoterms === null) {
        var traderDiscountAttribute = formContext.getAttribute("dg_traderdiscount");
        if (traderDiscountAttribute) {
            traderDiscountAttribute.setValue(true);
        } else {
            console.log("Field attribute dg_traderdiscount not found.");
        }
    }
}


function manageIncotermsVisibility(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var dg_incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var SalesContract = formContext.getAttribute("dg_salescontract").getValue();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    if (SalesContract == null) {
        if (division != null && (division == 30 || division == 40 || division == 50 || division == 95)) {
            // Show/Hide fields based on dg_incoterms  
            if (dg_incoterms === 140110001 || dg_incoterms === 140110019 || dg_incoterms === 140110023 || dg_incoterms === 140110020 || dg_incoterms === 140110000 || dg_incoterms === 140110022 || dg_incoterms === 140110002) {
                formContext.getControl("dg_oceanfreightpershipment").setVisible(true);
                formContext.getControl("dg_oceanfreightpermt").setVisible(true);
                //formContext.getControl("dg_airfreightpermt").setVisible(true); 
                formContext.getControl("dg_cifcostpermt").setVisible(true);
            } else {
                formContext.getControl("dg_oceanfreightpershipment").setVisible(false);
                formContext.getControl("dg_oceanfreightpermt").setVisible(false);
                //formContext.getControl("dg_airfreightpermt").setVisible(false); 
                formContext.getControl("dg_cifcostpermt").setVisible(false);
            }

            if (dg_incoterms === 140110019 || dg_incoterms === 140110020 || dg_incoterms === 140110023) {
                formContext.getControl("dg_inlandhaulagepershipment").setVisible(true);
                formContext.getControl("dg_inlandhaulages").setVisible(true);
                formContext.getControl("dg_dthcpershipment").setVisible(true);
                formContext.getControl("dg_dthcpermt").setVisible(true);
                formContext.getControl("dg_noofdays").setVisible(true);
                formContext.getControl("dg_storagechargespershipmentperday").setVisible(true);
                formContext.getControl("dg_storagecharges").setVisible(true);
                formContext.getControl("dg_detentionpershipmentperday").setVisible(true);
                formContext.getControl("dg_detentioncharges").setVisible(true);
                formContext.getControl("dg_dapcostpermt").setVisible(true);
            } else {
                formContext.getControl("dg_inlandhaulagepershipment").setVisible(false);
                formContext.getControl("dg_inlandhaulages").setVisible(false);
                formContext.getControl("dg_dthcpershipment").setVisible(false);
                formContext.getControl("dg_dthcpermt").setVisible(false);
                formContext.getControl("dg_noofdays").setVisible(false);
                formContext.getControl("dg_storagechargespershipmentperday").setVisible(false);
                formContext.getControl("dg_storagecharges").setVisible(false);
                formContext.getControl("dg_detentionpershipmentperday").setVisible(false);
                formContext.getControl("dg_detentioncharges").setVisible(false);
                formContext.getControl("dg_dapcostpermt").setVisible(false);
            }

            if (dg_incoterms === 140110020) {
                formContext.getControl("dg_dutyforeignport").setVisible(true);
                formContext.getControl("dg_dutyforeignportpermt").setVisible(true);
                formContext.getControl("dg_ddpcostpermt").setVisible(true);
            } else {
                formContext.getControl("dg_dutyforeignport").setVisible(false);
                formContext.getControl("dg_dutyforeignportpermt").setVisible(false);
                formContext.getControl("dg_ddpcostpermt").setVisible(false);
            }
            if (dg_incoterms === 140110002) {
                //formContext.getControl("dg_cifcostpermt").setVisible(true);  
                formContext.getControl("dg_inlandhaulagepershipment").setVisible(true);

            }
            if (dg_incoterms === 140110003 || dg_incoterms === 140110021 || dg_incoterms === 140110024 || dg_incoterms === 140110025 || dg_incoterms === 140110026) {
                formContext.getControl("dg_airfreightpermt").setVisible(false);
            }
        }
    }
}


function lockCommissionValue(executionContext) {
    var formContext = executionContext.getFormContext();
    var commissionOrValue = formContext.getAttribute("dg_commissionorvalue2").getValue();

    if (commissionOrValue === true) { // When equal to 1
        formContext.getControl("dg_commissionorvalue").setVisible(false);
        formContext.getControl("dg_commissionorvalue1").setVisible(false);
        formContext.getControl("dg_commissionvalue").setVisible(true);
        formContext.getControl("dg_commissionvalue1").setVisible(true);
        formContext.getControl("dg_commissionvalue").setDisabled(false);
        formContext.getControl("dg_commissionvalue1").setDisabled(false);
    } else { // When equal to 0
        formContext.getControl("dg_commissionorvalue").setVisible(true);
        formContext.getControl("dg_commissionorvalue1").setVisible(true);
        formContext.getControl("dg_commissionvalue").setVisible(true);
        formContext.getControl("dg_commissionvalue1").setVisible(true);
        formContext.getControl("dg_commissionvalue").setDisabled(true); // Lock the field
        formContext.getControl("dg_commissionvalue1").setDisabled(true);
    }
}



function freightpershipment(executionContext) {
    var formContext = executionContext.getFormContext();
    var statusLine = formContext.getAttribute("dg_statusline").getValue();

    if (statusLine === 1 || statusLine === 2 || statusLine === 3 || statusLine === 4 || statusLine === 140110000) {
        formContext.getControl("dg_freightpershipmentpertrip").setDisabled(true);
    } else {
        formContext.getControl("dg_freightpershipmentpertrip").setDisabled(false);
    }
}


function OnLoadQuoteStatus(executionContext) {
    var formcontext = executionContext.getFormContext();
    var quote = formcontext.getAttribute("quoteid").getValue();
    var status = null;
    var quoteStatus = formcontext.getAttribute("dg_quotestatus").getValue();
    if (quote != null) {
        var quoteId = quote[0].id.replace("{", "").replace("}", "");
        // STEP1-CHANGE-START
        // ORIGINAL (v1.0.0.34 lines 1791-1814): a synchronous XMLHttpRequest to quotes(<id>)?$select=dg_customstatus,
        //   whose callback set the variable "status".
        // NOW: "status" comes from the shared quote read. The code below (copying it into dg_quotestatus) is the ORIGINAL and is unchanged,
        //   including: if the read fails, "status" stays null and a non-empty dg_quotestatus is overwritten with null (existing behaviour, flagged).
        var quoteData = dnlGetQuoteData(quoteId);
        if (quoteData) {
            status = quoteData["dg_customstatus"];
        }
        // STEP1-CHANGE-END
        if (quoteStatus == null) {
            formcontext.getAttribute("dg_quotestatus").setValue(status);
        }
        else {
            if (quoteStatus != status) {
                formcontext.getAttribute("dg_quotestatus").setValue(status);
            }
        }


    }
}

function updateCA(executionContext) {

    var formContext = executionContext.getFormContext();

    var Quote = formContext.getAttribute("quoteid").getValue();
    var QuoteId = Quote[0].id.replace('{', '').replace('}', '');

    Xrm.WebApi.online.retrieveRecord("quote", QuoteId, "?$select=_customerid_value,_dg_accountnameship_value").then(
        function success(result) {
            var _customerid_value = result["_customerid_value"];
            var _customerid_value_formatted = result["_customerid_value@OData.Community.Display.V1.FormattedValue"];
            var _customerid_value_lookuplogicalname = result["_customerid_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
            var _dg_accountnameship_value = result["_dg_accountnameship_value"];
            var _dg_accountnameship_value_formatted = result["_dg_accountnameship_value@OData.Community.Display.V1.FormattedValue"];
            var _dg_accountnameship_value_lookuplogicalname = result["_dg_accountnameship_value@Microsoft.Dynamics.CRM.lookuplogicalname"];

            Xrm.WebApi.online.retrieveRecord("account", _customerid_value, "?$select=dg_commissioningagent").then(
                function success(result) {
                    var dg_commissioningagent = result["dg_commissioningagent"];

                    if (dg_commissioningagent == true) {
                        //Update CA lookup with BillTo value from Quote
                        var CALookup = new Array();
                        CALookup[0] = new Object();
                        CALookup[0].id = _dg_accountnameship_value;
                        CALookup[0].name = _dg_accountnameship_value_formatted;
                        CALookup[0].entityType = _dg_accountnameship_value_lookuplogicalname;
                        //formContext.getAttribute("dg_commissioningagent").setValue(CALookup);
                        formContext.getControl("dg_commissioningagent").setDisabled(true);
                        formContext.getAttribute("dg_commissionagent").setValue(CALookup);
                    }

                },
                function (error) {
                    Xrm.Utility.alertDialog(error.message);
                }
            );
        },
        function (error) {
            Xrm.Utility.alertDialog(error.message);
        }
    );
}
function Reactivate(primaryControl) {
    formContext = primaryControl;
    formContext.getAttribute("dg_statusline").setValue(1);
}
function setWarehousePremiumtonull(executionContext) {
    var formContext = executionContext.getFormContext();
    var warehouse = formContext.getAttribute("dg_warehouse").getValue();

    if (warehouse === null || warehouse === undefined) {
        formContext.getAttribute("dg_warehousepremium").setValue(null);
    }
}

function contributionmarginfinal(executionContext) {
    var formContext = executionContext.getFormContext();
    var division = formContext.getAttribute("dg_division").getValue();
    var contributionmargin = formContext.getAttribute("dg_contributionmarginorvalue2").getValue();
    if (division != null && (division == 30 || division == 40 || division == 50 || division == 95)) {
        if (contributionmargin === true) { // When equal to 1-value
            formContext.getControl("dg_contributionmarginpercentage").setVisible(false);
            formContext.getControl("dg_contributionmarginpercentage1").setVisible(false);
            formContext.getControl("dg_contributionmargin").setVisible(true);
            formContext.getControl("dg_contributionmargin1").setVisible(true);
            formContext.getControl("dg_contributionmargin").setDisabled(false);
            formContext.getControl("dg_contributionmargin1").setDisabled(false);
        } else { // When equal to 0-percentage
            formContext.getControl("dg_contributionmarginpercentage").setVisible(true);
            formContext.getControl("dg_contributionmarginpercentage1").setVisible(true);
            formContext.getControl("dg_contributionmargin").setVisible(true);
            formContext.getControl("dg_contributionmargin1").setVisible(true);
            formContext.getControl("dg_contributionmargin").setDisabled(true); // Lock the field
            formContext.getControl("dg_contributionmargin1").setDisabled(true);

        }
    }
}

function bidomestic(executionContext) {
    var formContext = executionContext.getFormContext();
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();
    var division = formContext.getAttribute("dg_division").getValue();

    if (pricelist != null && pricelist.length > 0) {
        var pricelistId = pricelist[0].id;

        // Fetch the related record using OData or Web API
        Xrm.WebApi.retrieveRecord("pricelevel", pricelistId, "?$select=dg_pricelisttype").then(
            function (result) {
                var pricelistType = result.dg_pricelisttype;

                if (pricelistType === 140110001 && (division === 30 || division === 95)) {
                    formContext.getControl("dg_traderdiscount").setDisabled(true);
                    formContext.getControl("dg_contributionmargin").setDisabled(true);
                    formContext.getControl("dg_contributionmarginorvalue2").setVisible(false);
                    formContext.getControl("dg_contributionmarginpercentage").setVisible(false);
                    formContext.getControl("dg_commissionorvalue").setVisible(false);
                    formContext.getControl("dg_commissionvaluepermt").setVisible(false);
                    formContext.getAttribute("dg_contributionmarginorvalue2").setValue(true);
                    formContext.getAttribute("dg_commissionorvalue2").setValue(true);
                }
            },
            function (error) {
                console.log(error.message);
            }
        );
    }
}

function incotermlocation(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var salesAreaLookup = formContext.getAttribute("dg_salesarea").getValue();
    var incotermlocation = formContext.getAttribute("dg_incotermlocation").getValue();
    var quoteclone = formContext.getAttribute("dg_commission3").getValue();
    if (salesAreaLookup != null && incotermlocation == null && (quoteclone == null || quoteclone == false)) {
        var salesAreaId = salesAreaLookup[0].id;
        Xrm.WebApi.retrieveRecord("dg_salesarea", salesAreaId, "?$select=dg_incotermslocation1").then(
            function success(result) {
                console.log(result);
                var dg_salesareaid = result["dg_salesareaid"]; // Guid
                var dg_incotermslocation1 = result["dg_incotermslocation1"]; // Text
                formContext.getAttribute("dg_incotermlocation").setValue(dg_incotermslocation1.toUpperCase());
            },
            function (error) {
                console.log(error.message);
            }
        );

    }
}
function Incotermtouppercase(executionContext) {
    var formContext = executionContext.getFormContext();
    var value = formContext.getAttribute("dg_incotermlocation").getValue();
    if (value != null) {
        formContext.getAttribute("dg_incotermlocation").setValue(value.toUpperCase());
    }
}
function incotermandincotermlocation(executionContext) {
    var formContext = executionContext.getFormContext();
    var divisionValue = formContext.getAttribute("dg_division").getValue();
    if (divisionValue === 30 || divisionValue === 40 || divisionValue === 50 || divisionValue === 95) {
        formContext.getAttribute("dg_incoterms").setRequiredLevel("required");
        formContext.getAttribute("dg_incotermlocation").setRequiredLevel("required");
    } else {
        formContext.getAttribute("dg_incoterms").setRequiredLevel("none");
        formContext.getAttribute("dg_incotermlocation").setRequiredLevel("none");
    }
}



function alertoncommissionandtradepercentage(executionContext) {
    var formContext = executionContext.getFormContext();
    var quoteid = formContext.getAttribute("quoteid").getValue();
    var traderDiscountValue = formContext.getAttribute("dg_traderdiscountvalue").getValue();
    var traderDiscountPercentage = formContext.getAttribute("dg_traderdiscountpercentage").getValue();
    var commissionValue = formContext.getAttribute("dg_commissionvalue").getValue();
    var commissionPercentage = formContext.getAttribute("dg_commissionorvalue").getValue();
    var commissionagent = formContext.getAttribute("dg_commissioningagent").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    var quoteproduct = quoteid[0].id.replace("{", "").replace("}", "");

    if (quoteid) {
        Xrm.WebApi.retrieveRecord("quote", quoteproduct, "?$select=_customerid_value").then(
            function success(result) {
                console.log(result);
                var customerid = result["_customerid_value"];

                Xrm.WebApi.retrieveRecord("account", customerid, "?$select=dg_commissioningagent").then(
                    function success(result) {
                        console.log(result);
                        var dg_commissioningagent = result["dg_commissioningagent"];

                        if (dg_commissioningagent === true && commissionPercentage == null && commissionagent != null) {
                            if (((division === 30 || division == 95) && commissionValue === null)) {
                                alert("You have not entered commission value");
                            } else if (division === 40 || division === 50) {
                                if (traderDiscountPercentage == null) {
                                    if (commissionValue === null && traderDiscountValue === null) {
                                        alert("You have not entered commission or trade discount value");
                                    }
                                }
                            }
                        }
                    },
                    function (error) {
                        console.log(error.message);
                    }
                );
            },
            function (error) {
                console.log(error.message);
            }
        );
    }
}
var commissionagent = "";

function commissionagentfilter(executionContext) {
    var formContext = executionContext.getFormContext();
    var account = formContext.getAttribute("dg_commissioncustomer").getValue();
    if (!account || account.length === 0) return;

    var accountID = account[0].id.replace("{", "").replace("}", "");

    if (typeof ($) === 'undefined') {
        $ = parent.$;
        jQuery = parent.jQuery;
    }

    var req = new XMLHttpRequest();
    var url = formContext.context.getClientUrl() +
        "/api/data/v9.1/dg_commissioningagents?$select=createdon,_dg_account_value,_dg_commissioningagent_value" +
        "&$filter=_dg_account_value eq '" + accountID + "'" +
        "&$orderby=createdon desc";

    req.open("GET", url, false);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Accept", "application/json");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Prefer", "odata.include-annotations=\"*\"");

    req.onreadystatechange = function () {
        if (this.readyState === 4) {
            req.onreadystatechange = null;

            if (this.status === 200) {
                var results = JSON.parse(this.response);
                var agentIds = [];

                if (results.value.length > 0) {
                    // Set the most recent agent as default

                    // Collect all agent IDs for filtering
                    for (var i = 0; i < results.value.length; i++) {
                        var agentId = results.value[i]["_dg_commissioningagent_value"];
                        if (agentId) {
                            agentIds.push(agentId);
                        }
                    }

                    // Build filter XML
                    if (agentIds.length > 0) {
                        var filterXml = "<filter type='and'><condition attribute='accountid' operator='in'>";
                        for (var j = 0; j < agentIds.length; j++) {
                            filterXml += "<value>" + agentIds[j] + "</value>";
                        }
                        filterXml += "</condition></filter>";
                        commissionagent = filterXml;
                    }
                } else {
                    commissionagent = "<filter><condition attribute='accountid' operator='eq' value='00000000-0000-0000-0000-000000000000' /></filter>";
                    formContext.getAttribute("dg_commissioningagent").setValue(null);
                }
            } else {
                Xrm.Utility.alertDialog(this.statusText);
                commissionagent = "<filter><condition attribute='accountid' operator='eq' value='00000000-0000-0000-0000-000000000000' /></filter>";
                formContext.getAttribute("dg_commissioningagent").setValue(null);
            }

            // Attach filter after building it
            formContext.getControl("dg_commissioningagent").addPreSearch(filterCA);
            formContext.getControl("dg_commissioningagent1").addPreSearch(filterCA);
            formContext.getControl("dg_commissioningagent2").addPreSearch(filterCA);
        }
    };

    req.send();
}

function filterCA() {
    var formContext = Xrm.Page;
    formContext.getControl("dg_commissioningagent").addCustomFilter(commissionagent);
    formContext.getControl("dg_commissioningagent1").addCustomFilter(commissionagent);
    formContext.getControl("dg_commissioningagent2").addCustomFilter(commissionagent);
}



function traderdiscoutlockunlock(executionContext) {
    var formContext = executionContext.getFormContext();
    var traderDiscount = formContext.getAttribute("dg_traderdiscount").getValue();

    if (traderDiscount == 0) {
        formContext.getControl("dg_traderdiscountvalue").setDisabled(true);
    } else {
        formContext.getControl("dg_traderdiscountvalue").setDisabled(false);
    }
}

function lostreason(executionContext) {
    var formContext = executionContext.getFormContext();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    if (SalesOrg == 1000 && statusline == 2) {
        formContext.getControl("dg_lostreasons").setVisible(true);
        formContext.getControl("dg_lostreasons1").setVisible(true);
        formContext.getControl("dg_lostreasons2").setVisible(true);

    }
    else {
        formContext.getControl("dg_lostreasons").setVisible(false);
        formContext.getControl("dg_lostreasons1").setVisible(false);
        formContext.getControl("dg_lostreasons2").setVisible(false);
    }
}

function onrevision(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var SalesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();
    var contributionrevision = formContext.getAttribute("dg_contributionmarginorvalue2").getValue();
    var incoterms = formContext.getAttribute("dg_incoterms").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    var salesContract = formContext.getAttribute("dg_salescontract").getValue();
    if (pricelist != null) {
        var prod = pricelist[0].id;
        var productdescId = prod.replace('{', '').replace('}', '');
        //fetch price list
        var type = null;
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/pricelevels(" + productdescId + ")?$select=dg_pricelisttype", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var pricelevelid = result["pricelevelid"]; // Guid
                    var dg_pricelisttype = result["dg_pricelisttype"]; // Choice
                    type = dg_pricelisttype;
                    var dg_pricelisttype_formatted = result["dg_pricelisttype@OData.Community.Display.V1.FormattedValue"];
                }
                else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
        if ((SalesOrg == 1000 || SalesOrg == 3000) && statusline == 140110000 && type == 140110000) {
            formContext.getControl("dg_destinatioincharges").setDisabled(true);
            formContext.getControl("dg_exportunitrate").setDisabled(true);
            formContext.getControl("dg_contributionmarginorvalue21").setDisabled(false);
            formContext.getControl("dg_quotetemplateremarks1").setDisabled(false);
            formContext.getControl("dg_oldquoteproduct1").setDisabled(false);
            formContext.getControl("productid").setDisabled(false);
            formContext.getControl("productid1").setDisabled(false);
            if(division==30){
                            formContext.getControl("dg_industrytype").setDisabled(true);
                            formContext.getControl("dg_industrytype1").setDisabled(true);
                           }
                           else if(division==40||division==50||division==95){
                            formContext.getControl("dg_industrytype").setDisabled(false);
                            formContext.getControl("dg_industrytype1").setDisabled(false);
                           }
            if (incoterms == 140110012) {
                formContext.getControl("dg_vehicletype1").setDisabled(true);
            }
            else if (incoterms != 140110012) {
                formContext.getControl("dg_vehicletype1").setDisabled(false);
            }
            if (contributionrevision === false) {
                formContext.getControl("dg_contributionmarginpercentage1").setDisabled(false);
                formContext.getControl("dg_contributionmargin1").setDisabled(true);
            }
            else if (contributionrevision === true) {
                formContext.getControl("dg_contributionmarginpercentage1").setDisabled(false);
                formContext.getControl("dg_contributionmargin1").setDisabled(false);
            }
            if (SalesOrg == 3000 && division == 20 && type == 140110000) {
                var exportsolvenshow = ["dg_seafreight", "dg_routeselected1", "dg_packagingcharges", "dg_packaging1", "dg_cifpricepermt", "dg_drummingcost", "dg_transportationcharges", "dg_commissionorvalue21", "dg_commissionorvalue1", "dg_commissionvalue1", "dg_dutydrawback1", "dg_contributionmarginpermt"];
                for (var i = 0; i < exportsolvenshow.length; i++) {
                    formContext.getControl(exportsolvenshow[i]).setDisabled(false);
                }
            }
        }
        else if ((SalesOrg == 1000 || SalesOrg == 3000) && statusline == 140110000 && type == 140110001) {
            formContext.getControl("dg_quotetemplateremarks").setDisabled(false);
            formContext.getControl("dg_oldquoteproduct").setDisabled(false);
            formContext.getControl("dg_freightmaster").setDisabled(false);
            formContext.getControl("dg_freightpershipmentpertrip").setDisabled(false);
            formContext.getControl("dg_freightamount").setDisabled(false);
            formContext.getControl("productid").setDisabled(false);
            formContext.getControl("productid1").setDisabled(false);
            if(division==30){
                            formContext.getControl("dg_industrytype").setDisabled(true);
                            formContext.getControl("dg_industrytype1").setDisabled(true);
                           }
                           else if(division==40||division==50||division==95){
                            formContext.getControl("dg_industrytype").setDisabled(false);
                            formContext.getControl("dg_industrytype1").setDisabled(false);
                           }
            if (incoterms == 140110012) {
                formContext.getControl("dg_vehicletype").setDisabled(true);
            }
            else if (incoterms != 140110012) {
                formContext.getControl("dg_vehicletype").setDisabled(false);
            }
            if (SalesOrg == 3000 && division == 20 && type == 140110001) {
                var feildsroshow20 = ["dg_packaging", "dg_packagingservices", "dg_freightcharges1", "dg_freightamount1", "dg_freightpershipmentpertrip1", "dg_freightadder", "dg_otherexpense", "dg_commissionorvalue2", "dg_commissionorvalue", "dg_commissionvalue"];
                for (var i = 0; i < feildsroshow20.length; i++) {
                    formContext.getControl(feildsroshow20[i]).setDisabled(false);
                }
            }
        }
    }
    if (SalesOrg == 1000 && salesContract != null && statusline == 140110000) {
        if (salesContract != null) {
            var pricing = formContext.getAttribute("dg_formulapricing").getValue();
            var contractscheme = formContext.getAttribute("dg_icisperiods").getValue();
            var feildsUnlock = ["dg_warehouse2", "quantity3", "dg_incoterms2", "dg_typeofpackaging2", "dg_incotermlocation2", "dg_industrytype2", "dg_lastdateifshipment2", "dg_vehicletype2", "dg_productdescription2", "dg_productdescriptiondnl2", "dg_commissioningagent2", "dg_commissionmaster2", "dg_commissioncurrency22","productid2"]
            for (var i = 0; i < feildsUnlock.length; i++) {
                formContext.getControl(feildsUnlock[i]).setDisabled(false);
            }
            if (pricing == 140110005) {
                var showotpt = ["priceperunit2", "dg_pershipmentqtymt2", "dg_agencycharges", "dg_discount", "dg_conversionnorms", "dg_usdtosc", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_originchargespershipment1", "dg_discountpermt1", "dg_oceanfreightpershipment1", "dg_airfreight", "dg_inlandhaulagepershipment1", "dg_dthcpershipment1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_detentionpershipmentperday1", "dg_dutyforeignport1", "dg_commissionorvalue3", "dg_commissionorvalue22", "dg_commissionvaluepermt2", "dg_commissionvalue2"]
                for (var i = 0; i < showotpt.length; i++) {

                    formContext.getControl(showotpt[i]).setDisabled(false);

                }
            } else if (pricing == 140110004) {
                var showehnexport = ["priceperunit2", "dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_usdtosc", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_usdtosccurrencyconversion", "dg_norm2", "dg_demmerrages", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_originchargespershipment1", "dg_discountpermt1", "dg_oceanfreightpershipment1", "dg_airfreight", "dg_inlandhaulagepershipment1", "dg_dthcpershipment1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_daysdifference1", "dg_detentionpershipmentperday1", "dg_dutyforeignport1", "dg_dutyfactoramount", "dg_competitorprice3", "dg_commissionorvalue3", "dg_commissionorvalue22", "dg_commissionvaluepermt2", "dg_commissionvalue2", "dg_invoiceprice2", "dg_netrealizationexport1", "dg_vocincludingpacking1"]

                for (var i = 0; i < showehnexport.length; i++) {
                    formContext.getControl(showehnexport[i]).setDisabled(false);
                }
            } else if (pricing == 140110002) {
                var showcontract = ["priceperunit2", "dg_pershipmentqtymt2", "dg_icisratednl1", "dg_conversionnorms", "dg_usdtosc", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_fixedcomponentprice", "dg_originchargespershipment1", "dg_discountpermt1", "dg_oceanfreightpershipment1", "dg_airfreight", "dg_inlandhaulagepershipment1", "dg_dthcpershipment1", "dg_dthcpermt1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_detentionpershipmentperday1", "dg_dutyforeignport1", "dg_commissionorvalue3", "dg_commissionorvalue22", "dg_commissionvaluepermt2", "dg_commissionvalue2"]

                for (var i = 0; i < showcontract.length; i++) {
                    formContext.getControl(showcontract[i]).setDisabled(false);
                }
            } else if (pricing == 140110003) {
                var showehndomestic = ["priceperunit2", "dg_interestrateset1", "dg_pershipmentqtymt2", "dg_icisratednl", "dg_conversionnorms", "dg_rbiexchangerate", "dg_2ndrmgnfcaveragelistedprice", "dg_norm1", "dg_fixedcomponentprice", "dg_cashdiscount1", "dg_traderdiscountvalue1", "dg_warehousepremium1", "dg_freightpershipmentpertrip1", "dg_freightcharges1", "dg_quantitydiscount1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_commissionvaluepermt2", "dg_specialdiscount1", "dg_commissionvalue2", "dg_benchmarkpricedomestic1", "dg_commissionvaluepermt2"]

                for (var i = 0; i < showehndomestic.length; i++) {
                    formContext.getControl(showehndomestic[i]).setDisabled(false);
                }
            } else if (pricing == 140110001) {
                var show4nox = ["priceperunit2", "dg_pershipmentqtymt2", "dg_agencycharges1", "dg_discount1", "dg_exworks1price", "dg_exworks1pricetotal", "dg_billingprice_new", "dg_billingpricedifference", "dg_contractdiscount", "dg_billingpricescdec", "dg_exworks2pricetotal", "dg_conversionnorms", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_discountpermt1", "dg_freightamount1", "dg_commissionvaluepermt2"]
                for (var i = 0; i < show4nox.length; i++) {
                    formContext.getControl(show4nox[i]).setDisabled(false);
                }
            } else if (pricing == 140110000) {
                if (contractscheme != null && contractscheme == 140110004) {
                    var showfiedexport = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_othercharges1", "dg_originchargespershipment1", "dg_discountpermt1", "dg_oceanfreightpershipment1", "dg_airfreight", "dg_inlandhaulagepershipment1", "dg_dthcpershipment1", "dg_noofdays1", "dg_storagechargespershipmentperday1", "dg_detentionpershipmentperday1", "dg_dutyforeignport1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adderpermt1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_commissionvalue2", "dg_benchmarkpriceexport1"]
                    for (var i = 0; i < showfiedexport.length; i++) {
                        formContext.getControl(showfiedexport[i]).setDisabled(false);
                    }

                } else if (contractscheme != null && contractscheme == 140110005) {
                    var showfieddomestic = ["priceperunit2", "dg_pershipmentqtymt2", "dg_vocincludingpacking1", "dg_packaging2", "dg_secondarypackagingcharges1", "dg_warehousepremium1", "dg_freightpershipmentpertrip1", "dg_freightcharges1", "dg_contributionmarginorvalue22", "dg_contributionmarginpercentage2", "dg_contributionmargin2", "dg_adjustmentadder1", "dg_commissionorvalue22", "dg_commissionorvalue3", "dg_commissionvaluepermt2", "dg_commissionvalue2", "dg_tradediscount", "dg_traderdiscountpercentage1", "dg_traderdiscountvalue2", "dg_paymenttermdiscountinpercent1", "dg_benchmarkpricedomestic1"]
                    for (var i = 0; i < showfieddomestic.length; i++) {
                        formContext.getControl(showfieddomestic[i]).setDisabled(false);
                    }
                }
            }

        }
    }
}
function PPcostingowner(executionContext) {
    //debugger;
    var formContext = executionContext.getFormContext();
    var division = formContext.getAttribute("dg_division").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    var quotestatus = formContext.getAttribute("dg_quotestatus").getValue();
    var userRoles = Xrm.Utility.getGlobalContext().userSettings.roles.getAll();
    var hasRequiredRole = false;
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();
    if (pricelist && pricelist.length > 0) {
        var pricelistId = pricelist[0].id.replace(/[{}]/g, ""); // Clean up the ID format    
        for (var i = 0; i < userRoles.length; i++) {
            var currentUserRoleName = userRoles[i].name;
            if (currentUserRoleName && (currentUserRoleName.toLowerCase() === "system admin-deepak" || currentUserRoleName.toLowerCase() === "costing owner - dnl" || currentUserRoleName.toLowerCase() === "system administrator")) {
                hasRequiredRole = true;
                break;
            }
        }
        Xrm.WebApi.retrieveRecord("pricelevel", pricelistId, "?$select=dg_pricelisttype").then(
            function (result) {
                var pricelistType = result.dg_pricelisttype;
                if (pricelistType == 140110000 && division == 50 && ((statusline == 1 && quotestatus == 140110000) || (statusline == 140110000 && quotestatus == 140110004) || (statusline == 140110000 && quotestatus == 140110002))) {
                    if (hasRequiredRole) {
                        formContext.getControl("dg_vocincludingpacking").setDisabled(false);
                        formContext.getControl("dg_packaging").setDisabled(false);
                        formContext.getControl("dg_packaging1").setDisabled(false);
                        formContext.getControl("dg_contributionmarginpercentage1").setDisabled(false);
                        //formContext.getControl("dg_commissionorvalue1").setDisabled(false);
                        formContext.getControl("dg_discountpermt").setDisabled(false);
                        formContext.getControl("dg_othercharges").setDisabled(false);
                        formContext.getControl("dg_secondarypackagingcharges").setDisabled(false);

                    } else {
                        formContext.getControl("dg_vocincludingpacking").setDisabled(true);
                        formContext.getControl("dg_packaging").setDisabled(true);
                        formContext.getControl("dg_packaging1").setDisabled(true);
                        formContext.getControl("dg_contributionmarginpercentage1").setDisabled(true);
                        formContext.getControl("dg_contributionmargin1").setDisabled(true);
                        //formContext.getControl("dg_commissionorvalue1").setDisabled(true);
                        //formContext.getControl("dg_commissionvalue1").setDisabled(true);
                        formContext.getControl("dg_discountpermt").setDisabled(true);
                        formContext.getControl("dg_othercharges").setDisabled(true);
                        formContext.getControl("dg_secondarypackagingcharges").setDisabled(true);
                    }

                }
                else if (pricelistType == 140110001 && division == 50 && ((statusline == 1 && quotestatus == 140110000) || (statusline == 140110000 && quotestatus == 140110004) || (statusline == 140110000 && quotestatus == 140110002))) {
                    if (hasRequiredRole) {
                        formContext.getControl("dg_packaging").setDisabled(false);
                        formContext.getControl("dg_packaging1").setDisabled(false);
                        formContext.getControl("dg_contributionmarginpercentage").setDisabled(false);
                        //formContext.getControl("dg_commissionvalue").setDisabled(false);
                        //ormContext.getControl("dg_traderdiscountpercentage").setDisabled(false);
                        formContext.getControl("dg_voc").setDisabled(false);
                        formContext.getControl("dg_packagingservices").setDisabled(false);

                    } else {
                        formContext.getControl("dg_packaging").setDisabled(true);
                        formContext.getControl("dg_packaging1").setDisabled(true);
                        formContext.getControl("dg_contributionmarginpercentage").setDisabled(true);
                        formContext.getControl("dg_contributionmargin").setDisabled(true);
                        //formContext.getControl("dg_commissionorvalue").setDisabled(true);
                        //formContext.getControl("dg_commissionvalue").setDisabled(true);
                        //formContext.getControl("dg_traderdiscountpercentage").setDisabled(true);
                        //formContext.getControl("dg_traderdiscountvalue").setDisabled(true);
                        formContext.getControl("dg_voc").setDisabled(true);
                        formContext.getControl("dg_packagingservices").setDisabled(true);
                    }

                }
            },
            function (error) {
                console.error("Error retrieving price list: " + error.message);
            }
        );
    } else {
        console.error("Price list is not selected.");
    }
}


function quoteclonevisibility(primaryControl) {
    // debugger;  
    var formContext = primaryControl;
    var customStatus = formContext.getAttribute("dg_customstatus").getValue();
    var salesorganization = formContext.getAttribute("dg_salesoragnizationsingle").getValue();
    if ((salesorganization == 1000 || salesorganization == 3000) && customStatus != 140110000) {
        return true;
    }
    else {
        return false;
    }
}

function partialwon(executionContext) {
    var formContext = executionContext.getFormContext();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    var quotestatus = formContext.getAttribute("dg_quotestatus").getValue();
    if (((statusline == 1 && quotestatus == 140110002) || (statusline == 4 && quotestatus == 140110002) || (statusline == 3 && quotestatus == 140110002) || (statusline == 1 && quotestatus == 140110001) || (statusline == 3 && quotestatus == 140110001) || (statusline == 4 && quotestatus == 140110001))) {
        formContext.getControl("dg_commissionvalue").setDisabled(true);
        formContext.getControl("dg_commissionvalue1").setDisabled(true);
        formContext.getControl("dg_contributionmargin").setDisabled(true);
        formContext.getControl("dg_contributionmargin1").setDisabled(true);
        formContext.getControl("dg_traderdiscountvalue").setDisabled(true);
        formContext.getControl("quantity").setDisabled(true);
        formContext.getControl("quantity1").setDisabled(true);
        formContext.getControl("dg_vehicletypefreetext").setDisabled(true);
        formContext.getControl("dg_vehicletypefreetext1").setDisabled(true);
        formContext.getControl("dg_vehicletype").setDisabled(true);
        formContext.getControl("dg_vehicletype1").setDisabled(true);
        formContext.getControl("dg_commissioningagent").setDisabled(true);
        formContext.getControl("dg_freightmaster").setDisabled(true);
        formContext.getControl("dg_freightamount").setDisabled(true);
        formContext.getControl("dg_freightcharges").setDisabled(true);
        formContext.getControl("dg_traderdiscountvalue").setDisabled(true);


    }
}


function lastdateofshipment(executionContext) {
    var formContext = executionContext.getFormContext();
    try {
        var lastDateOfShipment = formContext.getAttribute("dg_lastdateifshipment").getValue();
        var createdOn = formContext.getAttribute("dg_quotecreationdate").getValue();
        if (lastDateOfShipment && createdOn) {
            lastDateOfShipment = new Date(lastDateOfShipment);
            createdOn = new Date(createdOn);

            if (lastDateOfShipment < createdOn) {
                formContext.getControl("dg_lastdateifshipment").setNotification("Cannot be less than Created On Date", "Last Date of Shipment");
                formContext.getControl("dg_lastdateifshipment1").setNotification("Cannot be less than Created On Date", "Last Date of Shipment");
            } else {
                formContext.getControl("dg_lastdateifshipment").clearNotification("Last Date of Shipment");
                formContext.getControl("dg_lastdateifshipment1").clearNotification("Last Date of Shipment");
            }
        }
    } catch (error) {
        console.error("An error occurred:", error);
        formContext.getControl("dg_lastdateifshipment").setNotification("An error occurred: " + error.message, "Last Date of Shipment");
        formContext.getControl("dg_lastdateifshipment1").setNotification("An error occurred: " + error.message, "Last Date of Shipment");
    }
}

function bipriceadder(executionContext) {
    var formContext = executionContext.getFormContext();
    var division = formContext.getAttribute("dg_division").getValue();
    var pricelist = formContext.getAttribute("dg_pricelist").getValue();
    if (pricelist && pricelist.length > 0) {
        var pricelistId = pricelist[0].id.replace(/[{}]/g, "");
        Xrm.WebApi.retrieveRecord("pricelevel", pricelistId, "?$select=dg_pricelisttype").then(

            function (result) {
                var pricelistType = result.dg_pricelisttype;
                if ((division == 30 || division == 95) && pricelistType == 140110001) {
                    formContext.getAttribute("dg_adjustmentadder").setRequiredLevel("required");
                }
            },

            function (error) {
                console.error("Error retrieving price list: ", error.message);
            });
    }
}

function exportquotechild(executionContext) {
    var formContext = executionContext.getFormContext();
    var quotestatus = formContext.getAttribute("dg_quotestatus").getValue();
    var statusline = formContext.getAttribute("dg_statusline").getValue();
    if (((statusline == 1 && quotestatus == 140110002) || (statusline == 4 && quotestatus == 140110002) || (statusline == 3 && quotestatus == 140110002) || (statusline == 1 && quotestatus == 140110001) || (statusline == 3 && quotestatus == 140110001) || (statusline == 4 && quotestatus == 140110001) || (quotestatus == 140110004 && statusline == 1))) {
        var quickViewControl1 = formContext.getControl("dg_quoteproductchild");
        if (quickViewControl1.isLoaded()) {
            formContext.getControl("dg_quoteproductchild").data.entity.attributes.get("dg_portofdischarge").controls.forEach(control => {
                control.setDisabled(true);
            });
            formContext.getControl("dg_quoteproductchild").data.entity.attributes.get("dg_portofloading").controls.forEach(control => {
                control.setDisabled(true);
            });
            formContext.getControl("dg_quoteproductchild").data.entity.attributes.get("dg_containertype").controls.forEach(control => {
                control.setDisabled(true);
            });
            formContext.getControl("dg_quoteproductchild").data.entity.attributes.get("dg_internalmovementtype").controls.forEach(control => {
                control.setDisabled(true);
            });
        }
    }
}

function populatecontainertype(executionContext) {
    var formContext = executionContext.getFormContext();
    var vehicletype = formContext.getAttribute("dg_vehicletype").getValue();
    var quoteproductchild = formContext.getAttribute("dg_quoteproductchild").getValue();
    if (vehicletype && vehicletype.length > 0) {
        var vehicletypeid = vehicletype[0].id.replace(/[{}]/g, "");

        Xrm.WebApi.retrieveRecord("dg_meansoftransport", vehicletypeid, "?$select=dg_containertype").then(
            function success(result) {
                var dg_containertype = result["dg_containertype"];

                var entity = {};
                entity.dg_containertype = dg_containertype;

                var reqa = new XMLHttpRequest();
                reqa.open("PATCH", Xrm.Page.context.getClientUrl() + "/api/data/v9.1/dg_quoteproductchildren(" + quoteproductchild[0].id.replace('{', '').replace('}', '') + ")", false);
                reqa.setRequestHeader("OData-MaxVersion", "4.0");
                reqa.setRequestHeader("OData-Version", "4.0");
                reqa.setRequestHeader("Accept", "application/json");
                reqa.setRequestHeader("Content-Type", "application/json; charset=utf-8");
                reqa.onreadystatechange = function () {
                    if (this.readyState === 4) {
                        req.onreadystatechange = null;
                        if (this.status === 204) {
                            //Success - No Return Data - Do Something
                        } else {
                            Xrm.Utility.alertDialog(this.statusText);
                        }
                    }
                };
                reqa.send(JSON.stringify(entity));
                var quickViewControl = formContext.getControl("dg_quoteproductchild");
                if (quickViewControl) {
                    if (quickViewControl.isLoaded()) {
                        /*  if (quickViewControl && quickViewControl.getContentWindow) {
                              quickViewControl.getContentWindow().then(function (contentWindow) {
                                  contentWindow.Xrm.Page.data.refresh(false).then(function () {
                                      console.log("Child form refreshed");
                                  }, function (error) {
                                      console.error("Error refreshing child form: " + error.message);
                                  });
                              });
                          } else {
                           //   console.error("Quick view control 'dg_quoteproductchild' not found or getContentWindow not available");
                          }*/
                        quickViewControl.refresh();
                    }

                } else {
                    console.error("Quick view control 'dg_quoteproductchild' not found");
                }
            },
            function (error) {
                console.error(error.message);
            }
        );
    }
}
function preventPricePerUnitRecalculation(executionContext) {
    var formContext = executionContext.getFormContext();
    var dg_commissionorvaluednloption = formContext.getAttribute("dg_commissionorvaluednloption").getValue();
    if (dg_commissionorvaluednloption != null && dg_commissionorvaluednloption == true) {
        formContext.getAttribute("ispriceoverridden").setValue(true);
        var isPriceOverridden = formContext.getAttribute("ispriceoverridden");

        if (isPriceOverridden && isPriceOverridden.getValue() === true) {
            // Optional: Lock priceperunit field to prevent UI recalculation
            var pricePerUnit = formContext.getAttribute("priceperunit");

            if (pricePerUnit) {
                // Clear dirty flag to avoid "unsaved changes"
                pricePerUnit.setSubmitMode("never"); // Prevent it from being submitted unless changed
                //  pricePerUnit.setIsDirty(false);      // Clear dirty status
            }
        }
    }
}

function Onload(executionContext) {
    var formContext = executionContext.getFormContext();
    exportquotechild(executionContext);
    preventPricePerUnitRecalculation(executionContext);
    bipriceadder(executionContext);
    partialwon(executionContext);
    populatelatestCA(executionContext);
}
function populatelatestCA(executionContext) {
    var formContext = executionContext.getFormContext();
    var quote = formContext.getAttribute("quoteid").getValue();
    var cagent = formContext.getAttribute("dg_commissioningagent").getValue();
    var quoteid_customerid = null;
    var quoteid_dg_customstatus = null;
    var qp = Xrm.Page.data.entity.getId();
    if (qp != null && cagent == null) {
        var qpid = qp.replace('{', '').replace('}', '');
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotedetails(" + qpid + ")?$expand=quoteid($select=_customerid_value,dg_customstatus)", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var quotedetailid = result["quotedetailid"]; // Guid

                    // Many To One Relationships
                    if (result.hasOwnProperty("quoteid")) {
                        quoteid_customerid = result["quoteid"]["_customerid_value"]; // Customer
                        var quoteid_customerid_formatted = result["quoteid"]["_customerid_value@OData.Community.Display.V1.FormattedValue"];
                        var quoteid_customerid_lookuplogicalname = result["quoteid"]["_customerid_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                        quoteid_dg_customstatus = result["quoteid"]["dg_customstatus"]; // Choice
                        var quoteid_dg_customstatus_formatted = result["quoteid"]["dg_customstatus@OData.Community.Display.V1.FormattedValue"];

                    }
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_commissioningagents?$select=_dg_account_value,_dg_commissioningagent_value&$filter=_dg_account_value eq " + quoteid_customerid + "&$orderby=createdon desc", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var results = JSON.parse(this.response);
                    console.log(results);
                    for (var i = 0; i < results.value.length; i++) {
                        var result = results.value[0];
                        // Columns
                        var dg_commissioningagentid = result["dg_commissioningagentid"]; // Guid
                        var dg_account = result["_dg_account_value"]; // Lookup
                        var dg_account_formatted = result["_dg_account_value@OData.Community.Display.V1.FormattedValue"];
                        var dg_account_lookuplogicalname = result["_dg_account_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                        var dg_commissioningagent = result["_dg_commissioningagent_value"]; // Lookup
                        var dg_commissioningagent_formatted = result["_dg_commissioningagent_value@OData.Community.Display.V1.FormattedValue"];
                        var dg_commissioningagent_lookuplogicalname = result["_dg_commissioningagent_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                        var ca = [{
                            id: dg_commissioningagent,
                            name: dg_commissioningagent_formatted,
                            entityType: dg_commissioningagent_lookuplogicalname
                        }];
                        if (quoteid_dg_customstatus == 140110000) //Draft
                        {
                            // formContext.getAttribute("dg_commissioningagent").setValue(ca);
                        }
                    }
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
    }
}

function OnSave(executionContext) {
    var formContext = executionContext.getFormContext();
    CAalertonsave(executionContext);
}

function CAalertonsave(executionContext) {
    var formContext = executionContext.getFormContext();
    var CA = formContext.getAttribute("dg_commissioningagent").getValue();
    var quotedetail = Xrm.Page.data.entity.getId();
    var quotedetailid = quotedetail.replace('{', '').replace('}', '');
    if (CA == null) {
        var account = null;
        var quoteid_customerid = null;
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotedetails(" + quotedetailid + ")?$expand=quoteid($select=_customerid_value,dg_customstatus)", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var result = JSON.parse(this.response);
                    console.log(result);
                    // Columns
                    var quotedetailid = result["quotedetailid"]; // Guid

                    // Many To One Relationships
                    if (result.hasOwnProperty("quoteid")) {
                        quoteid_customerid = result["quoteid"]["_customerid_value"]; // Customer
                        var quoteid_customerid_formatted = result["quoteid"]["_customerid_value@OData.Community.Display.V1.FormattedValue"];
                        var quoteid_customerid_lookuplogicalname = result["quoteid"]["_customerid_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                        var quoteid_dg_customstatus = result["quoteid"]["dg_customstatus"]; // Choice
                        var quoteid_dg_customstatus_formatted = result["quoteid"]["dg_customstatus@OData.Community.Display.V1.FormattedValue"];
                    }
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
        var req = new XMLHttpRequest();
        req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/dg_commissioningagents?$select=_dg_account_value,_dg_commissioningagent_value&$filter=_dg_account_value eq " + quoteid_customerid + "&$orderby=createdon desc", false);
        req.setRequestHeader("OData-MaxVersion", "4.0");
        req.setRequestHeader("OData-Version", "4.0");
        req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
        req.setRequestHeader("Accept", "application/json");
        req.setRequestHeader("Prefer", "odata.include-annotations=*");
        req.onreadystatechange = function () {
            if (this.readyState === 4) {
                req.onreadystatechange = null;
                if (this.status === 200) {
                    var results = JSON.parse(this.response);
                    console.log(results);
                    var length = results.value.length;
                    if (length > 0) {
                        alert("You have not entered Commissioing Agent");
                    }
                    for (var i = 0; i < results.value.length; i++) {
                        var result = results.value[0];
                        // Columns
                        var dg_commissioningagentid = result["dg_commissioningagentid"]; // Guid
                        var dg_account = result["_dg_account_value"]; // Lookup
                        var dg_account_formatted = result["_dg_account_value@OData.Community.Display.V1.FormattedValue"];
                        var dg_account_lookuplogicalname = result["_dg_account_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                        var dg_commissioningagent = result["_dg_commissioningagent_value"]; // Lookup
                        var dg_commissioningagent_formatted = result["_dg_commissioningagent_value@OData.Community.Display.V1.FormattedValue"];
                        var dg_commissioningagent_lookuplogicalname = result["_dg_commissioningagent_value@Microsoft.Dynamics.CRM.lookuplogicalname"];
                    }
                } else {
                    console.log(this.responseText);
                }
            }
        };
        req.send();
    }
    else {
        var Commaster = formContext.getAttribute("dg_commissionmaster").getValue();
        if (Commaster == null) {
            alert("You have not entered any Commission Master although Commissioning Agent is tagged");
        }
    }

}
function TradeDiscountShowHide(econtext) {
    var formContext = econtext.getFormContext();
    var dg_traderdiscount = formContext.getAttribute("dg_traderdiscount").getValue();
    if (dg_traderdiscount == false) {
        formContext.getControl("dg_traderdiscountpercentage").setVisible(true);
        formContext.getControl("dg_traderdiscountvalue").setVisible(true);
        formContext.getControl("dg_traderdiscountvalue").setDisabled(true);
    }
    else if (dg_traderdiscount == true) {
        formContext.getControl("dg_traderdiscountpercentage").setVisible(false);
        formContext.getControl("dg_traderdiscountvalue").setVisible(true);
        formContext.getControl("dg_traderdiscountvalue").setDisabled(false);
    }
}
function MakeFeildNonMandatoryDCTL(econtext) {
    var formContext = econtext.getFormContext();
    var salesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    if (salesOrg != null && salesOrg == 3000 && division != null && division == 20) {
        formContext.getAttribute("dg_vehicletype").setRequiredLevel("none");
        formContext.getAttribute("dg_industrytype").setRequiredLevel("none");
        formContext.getAttribute("dg_productdescription").setRequiredLevel("none");
    }
}

function UpdateQuoteProductSalesOrgDPL(executionContext) {
    // debugger;
    var formContext = executionContext.getFormContext();
    var quote = formContext.getAttribute("quoteid").getValue();
    var quoteid = quote[0].id.replace("{", "").replace("}", "");
    let date = new Date();

    var division;
    var salesorg;
    ///fetch quote fields
    var req = new XMLHttpRequest();
    req.open("GET", Xrm.Utility.getGlobalContext().getClientUrl() + "/api/data/v9.2/quotes(" + quoteid + ")?$select=effectiveto,dg_division,dg_salesoragnizationsingle", false);
    req.setRequestHeader("OData-MaxVersion", "4.0");
    req.setRequestHeader("OData-Version", "4.0");
    req.setRequestHeader("Content-Type", "application/json; charset=utf-8");
    req.setRequestHeader("Accept", "application/json");
    req.setRequestHeader("Prefer", "odata.include-annotations=*");
    req.onreadystatechange = function () {
        if (this.readyState === 4) {
            req.onreadystatechange = null;
            if (this.status === 200) {
                var result = JSON.parse(this.response);
                console.log(result);
                // Columns
                var quoteid = result["quoteid"]; // Guid
                var dg_division = result["dg_division"]; // Choice
                division = dg_division;
                var effectiveto = result["effectiveto"]; // Date Time
                date = effectiveto;
                var effectiveto_formatted = result["effectiveto@OData.Community.Display.V1.FormattedValue"];
                var dg_division_formatted = result["dg_division@OData.Community.Display.V1.FormattedValue"];
                var dg_salesoragnizationsingle = result["dg_salesoragnizationsingle"]; // Choice
                salesorg = dg_salesoragnizationsingle;
                var dg_salesoragnizationsingle_formatted = result["dg_salesoragnizationsingle@OData.Community.Display.V1.FormattedValue"];
            } else {
                console.log(this.responseText);
            }
        }
    };
    req.send();
    if (formContext.getAttribute("dg_salesorganization").getValue() == null) {
        formContext.getAttribute("dg_salesorganization").setValue(salesorg);
    }
    if (formContext.getAttribute("dg_division").getValue() == null) {
        formContext.getAttribute("dg_division").setValue(division);
    }
 populateindustrytype(executionContext);
}
function populateindustrytype(executionContext) {

    var formContext = executionContext.getFormContext();

    var salesArea = formContext.getAttribute("dg_salesarea").getValue();
    var salesOrg = formContext.getAttribute("dg_salesorganization").getValue();
    var division = formContext.getAttribute("dg_division").getValue();
    var industryField = formContext.getAttribute("dg_industrytype").getValue();
	if(salesOrg==1000){
    if (salesOrg == 1000 && division == 30) {
                formContext.getControl("dg_industrytype").setDisabled(true);
                formContext.getControl("dg_industrytype1").setDisabled(true);
            } else {
                formContext.getControl("dg_industrytype").setDisabled(false);
                formContext.getControl("dg_industrytype1").setDisabled(false);
            }
	if(industryField==null){
   if (salesArea!=null ){
    var salesareaID = salesArea[0].id.replace("{", "").replace("}", "");
    Xrm.WebApi.retrieveRecord("dg_salesarea", salesareaID, "?$select=dg_distributionchannel"
    ).then(function (salesAreaResult) {
    var distChannel = salesAreaResult["dg_distributionchannel"];
        var quoteLookup = formContext.getAttribute("quoteid").getValue();
        var quoteId = quoteLookup[0].id.replace("{", "").replace("}", "");

        Xrm.WebApi.retrieveRecord(
            "quote",
            quoteId,
            "?$select=_dg_accountnameship_value,_dg_accountnamebill_value"
        ).then(function (quote) {
            var shipAcc = quote["_dg_accountnameship_value"];
            var billAcc = quote["_dg_accountnamebill_value"];
            var matched = false;
            function fetchAndSet(accountId) {

                if (!accountId) return Promise.resolve(false);

                var filter = `?$select=_dg_industrytype_value
                &$filter=_dg_accountname_value eq ${accountId}
                and dg_salesorganization eq ${salesOrg}
                and dg_division eq ${division}
                and dg_distributionchannel eq ${distChannel}`;

                return Xrm.WebApi.retrieveMultipleRecords("dg_salesarea", filter)
                    .then(function (result) {

                        if (result.entities.length > 0) {

                            var sa = result.entities[0];

                            var industryId = sa["_dg_industrytype_value"];
                            var industryName = sa["_dg_industrytype_value@OData.Community.Display.V1.FormattedValue"];
                            var industryEntity = sa["_dg_industrytype_value@Microsoft.Dynamics.CRM.lookuplogicalname"];

                            if (industryId) {

                                formContext.getAttribute("dg_industrytype").setValue([{
                                    id: industryId,
                                    name: industryName,
                                    entityType: industryEntity
                                }]);

                                console.log("✅ Industry set");
                            }

                            return true;
                        }

                        return false;
                    });
            }

            // ✅ STEP 3: Try SHIP first
            fetchAndSet(shipAcc).then(function (isFound) {

                if (!isFound) {
                    // ✅ fallback to BILL
                    fetchAndSet(billAcc);
                }

            });

            // ✅ Lock/unlock same as before
            

        });

    });
}
}
	}
else if (salesOrg == 2000 || salesOrg == null) {
    if (industryField == null) {
        if (salesArea != null) {

            var salesareaID = salesArea[0].id.replace("{", "").replace("}", "");

            Xrm.WebApi.retrieveRecord(
                "dg_salesarea",
                salesareaID,
                "?$select=_dg_industrytype_value"
            ).then(function (salesAreaResult) {

                var industryId = salesAreaResult["_dg_industrytype_value"];
                var industryName = salesAreaResult["_dg_industrytype_value@OData.Community.Display.V1.FormattedValue"];
                var industryEntity = salesAreaResult["_dg_industrytype_value@Microsoft.Dynamics.CRM.lookuplogicalname"];

                if (industryId) {
                    formContext.getAttribute("dg_industrytype").setValue([{
                        id: industryId,
                        name: industryName,
                        entityType: industryEntity
                    }]);
                }
            });
        }
    }
}
}
