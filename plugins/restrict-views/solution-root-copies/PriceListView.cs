using Microsoft.Crm.Sdk.Messages;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Restrict_Views
{
    public class PriceListView : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            try
            {
                IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));

                IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));

                IOrganizationService service = serviceFactory.CreateOrganizationService(context.UserId);
                ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
                if ((context.MessageName.Equals("RetrieveMultiple")))
                {
                    string SecurityXML = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='true'>" +
"  <entity name='role'>" +
"    <attribute name='name' />" +
"    <attribute name='businessunitid' />" +
"    <attribute name='roleid' />" +
"    <order attribute='name' descending='false' />" +
"    <filter type='and'>" +
"      <condition attribute='name' operator='eq' value='System Administrator' />" +
"    </filter>" +
"    <link-entity name='systemuserroles' from='roleid' to='roleid' visible='false' intersect='true'>" +
"      <link-entity name='systemuser' from='systemuserid' to='systemuserid' alias='af'>" +
"        <filter type='and'>" +
"          <condition attribute='systemuserid' operator='eq' value='" + context.InitiatingUserId.ToString() + "' />" +
"        </filter>" +
"      </link-entity>" +
"    </link-entity>" +
"  </entity>" +
"</fetch>";
                    EntityCollection Roles = service.RetrieveMultiple(new FetchExpression(SecurityXML));
                    tracingService.Trace("Roles Count " + Roles.Entities.Count());
                    bool advancefind = false;
                    if (Roles.Entities.Count == 0)
                    {
                        bool lookup = false;
                        QueryExpression PPI = new QueryExpression();
                        if (context.InputParameters["Query"] is QueryExpression)
                        {
                            advancefind = true;
                        }
                        else if (context.InputParameters["Query"] is FetchExpression)
                        {
                            FetchExpression fetch = context.InputParameters["Query"] as FetchExpression;
                            FetchXmlToQueryExpressionRequest conversionRequest = new FetchXmlToQueryExpressionRequest()
                            {
                                FetchXml = fetch.Query
                            };
                            FetchXmlToQueryExpressionResponse conversionResponse = (service.Execute(conversionRequest) as FetchXmlToQueryExpressionResponse);
                            PPI = conversionResponse.Query;
                            if (context.InputParameters.Contains("x-ms-app-name"))
                            {
                                if (context.InputParameters["x-ms-app-name"].ToString().ToLower() == "dg_dnlsalesmanagement")
                                {
                                    if (PPI.Criteria.Filters.Count > 0)
                                    {
                                        foreach (var link in PPI.Criteria.Filters)
                                        {
                                            if (link.Conditions.Count == 0)
                                            {
                                                foreach (var LINKF in link.Filters)
                                                {
                                                    if (LINKF.Conditions.Count == 0)
                                                    {
                                                        foreach (var linkfe in LINKF.Filters)
                                                        {
                                                            if (linkfe.Conditions[0].AttributeName == "dg_salesorganization" && linkfe.Conditions[0].Values[0].ToString() == "1000")
                                                            {
                                                                lookup = true;
                                                                break;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                else if(context.InputParameters["x-ms-app-name"].ToString().ToLower() == "dg_dplsalesmanagement")
                                {
                                    if (PPI.Criteria.Filters.Count > 0)
                                    {
                                        foreach(var link in PPI.Criteria.Filters)
                                        {
                                            if(link.Conditions.Count > 0)
                                            {
                                                foreach(var linkcon in link.Conditions)
                                                {
                                                    if(linkcon.AttributeName == "dg_salesorganization" && linkcon.Values[0].ToString() == "2000")
                                                    {
                                                        lookup = true;
                                                        break;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        if (lookup == false || advancefind == true)
                        {
                            if (context.InputParameters.Contains("x-ms-app-name"))
                            {
                                tracingService.Trace(context.InputParameters["x-ms-app-name"].ToString());
                                if (context.InputParameters["x-ms-app-name"].ToString().ToLower() == "dg_dnlsalesmanagement")
                                {
                                    string fetchxml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
    "  <entity name='pricelevel'>" +
    "    <attribute name='name' />" +
    "    <attribute name='transactioncurrencyid' />" +
    "    <attribute name='enddate' />" +
    "    <attribute name='begindate' />" +
    "    <attribute name='pricelevelid' />" +
    "    <attribute name='dg_divisiom' />" +
    "    <attribute name='dg_salesorganization' />" +
    "    <attribute name='dg_pricelisttype' />" +
    "    <attribute name='dg_ordertype' />" +
    "    <attribute name='statecode' />" +
    "    <attribute name='dg_distributionchannel' />" +
    "    <order attribute='name' descending='false' />" +
    "    <filter type='and'>" +
    "      <condition attribute='statecode' operator='eq' value='0' />" +
    "      <condition attribute='dg_salesorganization' operator='eq' value='1000' />" +
    "    </filter>" +
    "  </entity>" +
    "</fetch>";
                                    context.InputParameters["Query"] = new FetchExpression(fetchxml);

                                }
                                else if (context.InputParameters["x-ms-app-name"].ToString().ToLower() == "dg_dplsalesmanagement")
                                {
                                    tracingService.Trace("1 into dpl place");
                                    string fetchxml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
    "  <entity name='pricelevel'>" +
    "    <attribute name='name' />" +
    "    <attribute name='transactioncurrencyid' />" +
    "    <attribute name='enddate' />" +
    "    <attribute name='begindate' />" +
    "    <attribute name='pricelevelid' />" +
    "    <attribute name='dg_divisiom' />" +
    "    <attribute name='dg_salesorganization' />" +
    "    <order attribute='name' descending='false' />" +
    "    <filter type='and'>" +
    "      <condition attribute='statecode' operator='eq' value='0' />" +
    "      <condition attribute='dg_salesorganization' operator='eq' value='2000' />" +
    "    </filter>" +
    "  </entity>" +
    "</fetch>";
                                    context.InputParameters["Query"] = new FetchExpression(fetchxml);

                                }
                                else
                                {
                                    string fetchxml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
    "  <entity name='pricelevel'>" +
    "    <attribute name='name' />" +
    "    <attribute name='transactioncurrencyid' />" +
    "    <attribute name='enddate' />" +
    "    <attribute name='begindate' />" +
    "    <attribute name='pricelevelid' />" +
    "    <attribute name='dg_divisiom' />" +
    "    <attribute name='dg_salesorganization' />" +
    "    <order attribute='name' descending='false' />" +
    "    <filter type='and'>" +
    "      <condition attribute='statecode' operator='eq' value='0' />" +
    "      <condition attribute='dg_salesorganization' operator='eq' value='2000' />" +
    "    </filter>" +
    "  </entity>" +
    "</fetch>";
                                    context.InputParameters["Query"] = new FetchExpression(fetchxml);
                                }

                            }
                            if (advancefind == true)
                            {
                                string fetchxml = "<fetch version='1.0' output-format='xml-platform' mapping='logical' distinct='false'>" +
    "  <entity name='pricelevel'>" +
    "    <attribute name='name' />" +
    "    <attribute name='transactioncurrencyid' />" +
    "    <attribute name='enddate' />" +
    "    <attribute name='begindate' />" +
    "    <attribute name='pricelevelid' />" +
    "    <attribute name='dg_divisiom' />" +
    "    <attribute name='dg_salesorganization' />" +
    "    <order attribute='name' descending='false' />" +
    "    <filter type='and'>" +
    "      <condition attribute='statecode' operator='eq' value='0' />" +
    "    </filter>" +
    "  </entity>" +
    "</fetch>";
                                context.InputParameters["Query"] = new FetchExpression(fetchxml);
                            }
                        }

                    }
                }
            }
            catch(Exception ex)
            {
                throw new InvalidPluginExecutionException(ex.Message);
            }
        }
    }
}
